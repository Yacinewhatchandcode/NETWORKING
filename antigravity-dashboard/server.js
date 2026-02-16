/**
 * ANTIGRAVITY ENGINE — Backend Server
 * Real-time proxy to Ollama nodes + OpenClaw agent execution
 * Wired to: MacBook (localhost), iMac (192.168.1.140), VPS (31.97.52.22)
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const os = require('os');

const PORT = 3847;

// ═══ COMPUTE FABRIC TOPOLOGY ═══
const NODES = {
    macbook: {
        name: 'MacBook Pro',
        ollamaUrl: 'http://127.0.0.1:11434',
        sshTarget: null, // local
        icon: '💻',
        gpu: 'M4 Pro Metal',
        role: 'Primary'
    },
    imac: {
        name: 'iMac Engine',
        ollamaUrl: 'http://192.168.1.140:11434',
        sshTarget: 'yacinebenhamou@192.168.1.140',
        icon: '🖥️',
        gpu: 'AMD Radeon Pro 580',
        role: 'Compute'
    },
    vps: {
        name: 'VPS Hostinger',
        ollamaUrl: 'http://31.97.52.22:11434',
        sshTarget: 'root@31.97.52.22',
        icon: '☁️',
        gpu: 'CPU-Only',
        role: 'Edge'
    }
};

// ═══ HELPERS ═══

function httpFetch(url, options = {}) {
    return new Promise((resolve, reject) => {
        const parsed = new URL(url);
        const opts = {
            hostname: parsed.hostname,
            port: parsed.port || (parsed.protocol === 'https:' ? 443 : 80),
            path: parsed.pathname + parsed.search,
            method: options.method || 'GET',
            headers: options.headers || {},
            timeout: options.timeout || 8000
        };

        const req = http.request(opts, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve({ status: res.statusCode, data, headers: res.headers });
            });
        });

        req.on('error', reject);
        req.on('timeout', () => { req.destroy(); reject(new Error('timeout')); });

        if (options.body) req.write(options.body);
        req.end();
    });
}

function execAsync(cmd, timeout = 30000) {
    return new Promise((resolve, reject) => {
        exec(cmd, { timeout, maxBuffer: 1024 * 1024 }, (err, stdout, stderr) => {
            if (err) reject(err);
            else resolve({ stdout: stdout.trim(), stderr: stderr.trim() });
        });
    });
}

function jsonResponse(res, data, status = 200) {
    res.writeHead(status, {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end(JSON.stringify(data));
}

function serveStatic(res, filePath) {
    const ext = path.extname(filePath);
    const mimeTypes = {
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon'
    };
    const contentType = mimeTypes[ext] || 'application/octet-stream';

    fs.readFile(filePath, (err, content) => {
        if (err) {
            res.writeHead(404);
            res.end('Not found');
            return;
        }
        res.writeHead(200, { 'Content-Type': contentType });
        res.end(content);
    });
}

// ═══ API HANDLERS ═══

async function handleNodeHealth(nodeId) {
    const node = NODES[nodeId];
    if (!node) return { error: 'Unknown node' };

    const result = {
        id: nodeId,
        name: node.name,
        icon: node.icon,
        gpu: node.gpu,
        role: node.role,
        ollama: { status: 'offline', models: [] },
        system: {}
    };

    // Check Ollama
    try {
        const r = await httpFetch(node.ollamaUrl + '/', { timeout: 5000 });
        if (r.status === 200) {
            result.ollama.status = 'online';
            // Get models
            const m = await httpFetch(node.ollamaUrl + '/api/tags', { timeout: 5000 });
            if (m.status === 200) {
                const parsed = JSON.parse(m.data);
                result.ollama.models = (parsed.models || []).map(model => ({
                    name: model.name,
                    size: model.size,
                    family: model.details?.family || 'unknown',
                    params: model.details?.parameter_size || 'unknown',
                    quantization: model.details?.quantization_level || 'unknown'
                }));
            }
        }
    } catch (e) {
        result.ollama.status = 'offline';
        result.ollama.error = e.message;
    }

    // System info (local or SSH)
    try {
        if (nodeId === 'macbook') {
            result.system.hostname = os.hostname();
            result.system.uptime = formatUptime(os.uptime());
            result.system.memory = {
                total: formatBytes(os.totalmem()),
                free: formatBytes(os.freemem()),
                used: Math.round((1 - os.freemem() / os.totalmem()) * 100)
            };
            result.system.cpuLoad = os.loadavg()[0].toFixed(2);
            result.system.cpus = os.cpus().length;
        } else if (node.sshTarget) {
            const cmd = `ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${node.sshTarget} "echo \\"hostname:$(hostname)\\"; echo \\"uptime:$(uptime | sed 's/.*up //' | sed 's/,.*//')\\"; echo \\"memory:$(vm_stat 2>/dev/null | head -5 || free -m 2>/dev/null | head -2)\\"; echo \\"load:$(sysctl -n vm.loadavg 2>/dev/null || cat /proc/loadavg 2>/dev/null)\\"" 2>/dev/null`;
            const r = await execAsync(cmd, 8000);
            const lines = r.stdout.split('\n');
            for (const line of lines) {
                if (line.startsWith('hostname:')) result.system.hostname = line.split(':')[1];
                if (line.startsWith('uptime:')) result.system.uptime = line.split(':').slice(1).join(':').trim();
                if (line.startsWith('load:')) {
                    const loadStr = line.split(':')[1].trim();
                    const match = loadStr.match(/[\d.]+/);
                    result.system.cpuLoad = match ? match[0] : 'N/A';
                }
            }
        }
    } catch (e) {
        result.system.error = e.message;
    }

    return result;
}

async function handleAllNodesHealth() {
    const results = {};
    const promises = Object.keys(NODES).map(async (id) => {
        results[id] = await handleNodeHealth(id);
    });
    await Promise.all(promises);
    return results;
}

async function handleOllamaGenerate(nodeId, model, prompt) {
    const node = NODES[nodeId];
    if (!node) throw new Error('Unknown node');

    const startTime = Date.now();

    const r = await httpFetch(node.ollamaUrl + '/api/generate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, prompt, stream: false }),
        timeout: 300000 // 5 min for slow nodes
    });

    const elapsed = Date.now() - startTime;
    const parsed = JSON.parse(r.data);

    return {
        response: parsed.response,
        model: parsed.model || model,
        node: nodeId,
        latencyMs: elapsed,
        evalCount: parsed.eval_count,
        evalDuration: parsed.eval_duration,
        tokensPerSecond: parsed.eval_count && parsed.eval_duration
            ? (parsed.eval_count / (parsed.eval_duration / 1e9)).toFixed(1)
            : null
    };
}

async function handleOllamaChat(nodeId, model, messages) {
    const node = NODES[nodeId];
    if (!node) throw new Error('Unknown node');

    const startTime = Date.now();

    const r = await httpFetch(node.ollamaUrl + '/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model, messages, stream: false }),
        timeout: 300000
    });

    const elapsed = Date.now() - startTime;
    const parsed = JSON.parse(r.data);

    return {
        response: parsed.message?.content || parsed.response || '',
        model: parsed.model || model,
        node: nodeId,
        latencyMs: elapsed,
        evalCount: parsed.eval_count,
        tokensPerSecond: parsed.eval_count && parsed.eval_duration
            ? (parsed.eval_count / (parsed.eval_duration / 1e9)).toFixed(1)
            : null
    };
}

async function handleOpenClawAgent(nodeId, message) {
    const node = NODES[nodeId];
    if (!node) throw new Error('Unknown node');

    const sessionId = `dash-${Date.now()}`;
    let cmd;

    if (nodeId === 'macbook') {
        cmd = `export OLLAMA_API_KEY=ollama && openclaw agent --local --agent main --session-id ${sessionId} -m "${message.replace(/"/g, '\\"')}" --timeout 300 2>&1`;
    } else if (node.sshTarget) {
        cmd = `ssh -o ConnectTimeout=5 ${node.sshTarget} 'export PATH=\$HOME/.node22/bin:\$HOME/.npm-global/bin:/usr/local/bin:\$PATH && export OLLAMA_API_KEY=ollama && openclaw agent --local --agent main --session-id ${sessionId} -m "${message.replace(/"/g, '\\"')}" --timeout 300 2>&1'`;
    }

    const startTime = Date.now();
    const result = await execAsync(cmd, 310000);
    const elapsed = Date.now() - startTime;

    return {
        response: result.stdout,
        node: nodeId,
        sessionId,
        latencyMs: elapsed
    };
}

async function handlePullModel(nodeId, modelName) {
    const node = NODES[nodeId];
    if (!node) throw new Error('Unknown node');

    const r = await httpFetch(node.ollamaUrl + '/api/pull', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: modelName, stream: false }),
        timeout: 600000 // 10 min
    });

    return { status: r.status === 200 ? 'success' : 'failed', data: r.data };
}

async function handleKillSessions(nodeId) {
    const node = NODES[nodeId];
    if (!node) throw new Error('Unknown node');

    let cmd;
    if (nodeId === 'macbook') {
        cmd = 'rm -f ~/.openclaw/agents/main/sessions/*.lock 2>/dev/null && echo "cleared"';
    } else if (node.sshTarget) {
        cmd = `ssh -o ConnectTimeout=5 ${node.sshTarget} 'rm -f ~/.openclaw/agents/main/sessions/*.lock 2>/dev/null && echo "cleared"'`;
    }

    const result = await execAsync(cmd, 10000);
    return { result: result.stdout };
}

async function handleLocalMetrics() {
    const cpus = os.cpus();
    const loadAvg = os.loadavg();

    return {
        hostname: os.hostname(),
        platform: os.platform(),
        arch: os.arch(),
        uptime: formatUptime(os.uptime()),
        uptimePercent: Math.min(99, Math.round((os.uptime() / (os.uptime() + 60)) * 100)),
        memory: {
            total: os.totalmem(),
            free: os.freemem(),
            usedPercent: Math.round((1 - os.freemem() / os.totalmem()) * 100)
        },
        cpu: {
            model: cpus[0]?.model || 'Unknown',
            cores: cpus.length,
            load1m: loadAvg[0],
            load5m: loadAvg[1],
            load15m: loadAvg[2],
            usedPercent: Math.min(100, Math.round((loadAvg[0] / cpus.length) * 100))
        }
    };
}

function formatUptime(seconds) {
    const d = Math.floor(seconds / 86400);
    const h = Math.floor((seconds % 86400) / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    if (d > 0) return `${d}d ${h}h`;
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
}

function formatBytes(bytes) {
    const gb = bytes / (1024 ** 3);
    return gb.toFixed(1) + ' GB';
}

// ═══ REQUEST ROUTER ═══

const server = http.createServer(async (req, res) => {
    // CORS preflight
    if (req.method === 'OPTIONS') {
        res.writeHead(204, {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type'
        });
        res.end();
        return;
    }

    const url = new URL(req.url, `http://localhost:${PORT}`);
    const pathname = url.pathname;

    try {
        // ── API Routes ──
        if (pathname === '/api/health/all') {
            const data = await handleAllNodesHealth();
            return jsonResponse(res, data);
        }

        if (pathname.startsWith('/api/health/')) {
            const nodeId = pathname.split('/')[3];
            const data = await handleNodeHealth(nodeId);
            return jsonResponse(res, data);
        }

        if (pathname === '/api/metrics') {
            const data = await handleLocalMetrics();
            return jsonResponse(res, data);
        }

        if (pathname === '/api/generate' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const { node, model, prompt } = JSON.parse(body);
                    const data = await handleOllamaGenerate(node, model, prompt);
                    jsonResponse(res, data);
                } catch (e) {
                    jsonResponse(res, { error: e.message }, 500);
                }
            });
            return;
        }

        if (pathname === '/api/chat' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const { node, model, messages } = JSON.parse(body);
                    const data = await handleOllamaChat(node, model, messages);
                    jsonResponse(res, data);
                } catch (e) {
                    jsonResponse(res, { error: e.message }, 500);
                }
            });
            return;
        }

        if (pathname === '/api/agent' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const { node, message } = JSON.parse(body);
                    const data = await handleOpenClawAgent(node, message);
                    jsonResponse(res, data);
                } catch (e) {
                    jsonResponse(res, { error: e.message }, 500);
                }
            });
            return;
        }

        if (pathname === '/api/pull' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const { node, model } = JSON.parse(body);
                    const data = await handlePullModel(node, model);
                    jsonResponse(res, data);
                } catch (e) {
                    jsonResponse(res, { error: e.message }, 500);
                }
            });
            return;
        }

        if (pathname === '/api/kill-sessions' && req.method === 'POST') {
            let body = '';
            req.on('data', chunk => body += chunk);
            req.on('end', async () => {
                try {
                    const { node } = JSON.parse(body);
                    const data = await handleKillSessions(node);
                    jsonResponse(res, data);
                } catch (e) {
                    jsonResponse(res, { error: e.message }, 500);
                }
            });
            return;
        }

        // ── Static Files ──
        let filePath = pathname === '/' ? '/index.html' : pathname;
        filePath = path.join(__dirname, filePath);

        if (fs.existsSync(filePath) && fs.statSync(filePath).isFile()) {
            return serveStatic(res, filePath);
        }

        res.writeHead(404);
        res.end('Not found');

    } catch (e) {
        console.error(`[ERROR] ${pathname}:`, e.message);
        jsonResponse(res, { error: e.message }, 500);
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`\n╔═══════════════════════════════════════════╗`);
    console.log(`║  ANTIGRAVITY ENGINE — Command Server      ║`);
    console.log(`║  http://localhost:${PORT}                   ║`);
    console.log(`╠═══════════════════════════════════════════╣`);
    console.log(`║  Nodes:                                   ║`);
    console.log(`║    💻 MacBook  → localhost:11434           ║`);
    console.log(`║    🖥️  iMac     → 192.168.1.140:11434      ║`);
    console.log(`║    ☁️  VPS      → 31.97.52.22:11434        ║`);
    console.log(`╚═══════════════════════════════════════════╝\n`);
});
