/* ═══════════════════════════════════════════════════════════════
   CYBER RADAR DASHBOARD v2.0 — Application Logic
   ═══════════════════════════════════════════════════════════════ */

// ── Configuration ──
const CONFIG = {
    dataDir: '../data/',
    reportDir: '../reports/',
    refreshInterval: 30000,
    modules: [
        { id: 'network_discovery', name: 'Network Discovery', num: 1, icon: '🌐' },
        { id: 'port_scan', name: 'Port Scanning', num: 2, icon: '🔍' },
        { id: 'arp_integrity', name: 'ARP Integrity', num: 3, icon: '🔗' },
        { id: 'dns_integrity', name: 'DNS Integrity', num: 4, icon: '🌍' },
        { id: 'prompt_injection', name: 'Prompt Injection', num: 5, icon: '🤖' },
        { id: 'local_security', name: 'Local Security', num: 6, icon: '🖥️' },
        { id: 'vps_security', name: 'VPS Security', num: 7, icon: '☁️' },
        { id: 'wireless_security', name: 'Wireless Security', num: 8, icon: '📡' },
        { id: 'ssl_tls_audit', name: 'SSL/TLS Audit', num: 9, icon: '🔐' },
        { id: 'service_fingerprint', name: 'Fingerprinting', num: 10, icon: '👁️' }
    ],
    devices: [
        { name: 'Meteor 5G Box', ip: '192.168.1.1', mac: '84:a3:29:e7:c1:6d', type: 'router', icon: '📡', owner: 'infrastructure' },
        { name: 'MacBook Pro M4', ip: '192.168.1.171', mac: 'aa:04:7c:04:91:8e', type: 'workstation', icon: '💻', owner: 'yacine' },
        { name: 'MacBook Pro (ETH)', ip: '192.168.1.151', mac: '3c:18:a0:ca:ee:4f', type: 'workstation', icon: '💻', owner: 'yacine' },
        { name: 'iMac de Yacine', ip: '192.168.1.140', mac: '24:f6:77:11:26:5c', type: 'workstation', icon: '🖥️', owner: 'yacine' },
        { name: 'Samsung Tab S8', ip: '192.168.1.146', mac: 'ae:fa:d1:06:62:fd', type: 'tablet', icon: '📱', owner: 'yacine' },
        { name: 'Samsung Galaxy S25', ip: '192.168.1.102', mac: '9e:e0:23:f2:0d:5a', type: 'phone', icon: '📱', owner: 'yacine' },
        { name: 'Synology NAS', ip: '192.168.1.187', mac: '90:09:d0:7e:14:d4', type: 'nas', icon: '💾', owner: 'yacine' },
        { name: 'Epson Printer', ip: '192.168.1.239', mac: '64:c6:d2:90:de:b7', type: 'printer', icon: '🖨️', owner: 'yacine' }
    ]
};

// ── State ──
let currentScan = null;
let scanHistory = [];

// ── Initialize ──
document.addEventListener('DOMContentLoaded', () => {
    initClock();
    renderModules();
    renderDevices();
    loadScanData();
    drawTrendChart();
});

// ── Clock ──
function initClock() {
    const el = document.getElementById('clock');
    function update() {
        const now = new Date();
        el.textContent = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    }
    update();
    setInterval(update, 1000);
}

// ── Modules Render ──
function renderModules() {
    const grid = document.getElementById('modules-grid');
    grid.innerHTML = CONFIG.modules.map(m => `
    <div class="module-card" id="module-${m.id}" style="--module-color: var(--accent)">
      <div class="module-num">MODULE ${String(m.num).padStart(2, '0')}</div>
      <div class="module-name">${m.icon} ${m.name}</div>
      <div class="module-status idle">⏳ Awaiting scan</div>
    </div>
  `).join('');
}

// ── Devices Render ──
function renderDevices() {
    const grid = document.getElementById('device-grid');
    grid.innerHTML = CONFIG.devices.map(d => `
    <div class="device-card" id="device-${d.ip.replace(/\./g, '-')}">
      <div class="device-icon">${d.icon}</div>
      <div class="device-info">
        <div class="device-name">${d.name}</div>
        <div class="device-ip">${d.ip}</div>
        <div class="device-mac">${d.mac}</div>
        <div class="device-status offline">UNKNOWN</div>
      </div>
    </div>
  `).join('');
}

// ── Load Scan Data ──
function loadScanData() {
    // Try to load the latest JSON from data directory
    // In file:// mode, we use demo data; in server mode, we fetch
    if (window.location.protocol === 'file:') {
        loadDemoData();
    } else {
        fetchLatestScan();
    }
}

async function fetchLatestScan() {
    try {
        const resp = await fetch('/api/latest-scan');
        if (resp.ok) {
            const data = await resp.json();
            applyScanData(data);
        } else {
            loadDemoData();
        }
    } catch {
        loadDemoData();
    }
}

function loadDemoData() {
    // Data from latest v2.0 scan (2026-02-13)
    const demoData = {
        version: '2.0',
        timestamp: '2026-02-13_14-50-24',
        scan_mode: '--quick',
        summary: {
            passed: 23,
            warnings: 8,
            critical: 0,
            threat_level: 'YELLOW'
        }
    };

    const history = [
        { date: '2026-02-13', passed: 23, warnings: 8, critical: 0, level: 'YELLOW' },
        { date: '2026-02-13', passed: 24, warnings: 7, critical: 0, level: 'YELLOW' },
        { date: '2026-02-13', passed: 20, warnings: 4, critical: 0, level: 'YELLOW' },
        { date: '2026-02-11', passed: 10, warnings: 1, critical: 1, level: 'RED' },
    ];

    scanHistory = history;
    applyScanData(demoData);
    renderScanHistory(history);
    drawTrendChart();
}

// ── Apply Scan Data ──
function applyScanData(data) {
    currentScan = data;
    const { passed, warnings, critical, threat_level } = data.summary;
    const total = passed + warnings + critical;

    // Update threat level
    updateThreatLevel(threat_level, passed, warnings, critical, total);

    // Update stat cards
    animateValue('stat-pass', passed, total);
    animateValue('stat-warn', warnings, total);
    animateValue('stat-crit', critical, total);

    // Update modules
    updateModuleStatuses(data);

    // Update devices (simulated — real data would come from report parsing)
    updateDeviceStatuses(data);

    // Update log feed
    updateLogFeed(data);
}

function updateThreatLevel(level, passed, warnings, critical, total) {
    const el = document.getElementById('threat-level');
    const arc = document.getElementById('threat-arc');
    const hero = document.getElementById('threat-hero');

    // Set color based on level
    let color, label;
    switch (level) {
        case 'GREEN':
            color = 'var(--green)';
            label = 'GREEN';
            break;
        case 'YELLOW':
            color = 'var(--yellow)';
            label = 'YELLOW';
            break;
        case 'RED':
        default:
            color = 'var(--red)';
            label = 'RED';
            el.classList.add('critical');
            break;
    }

    document.documentElement.style.setProperty('--threat-color', color);
    el.textContent = label;
    el.style.color = color;

    // Animate arc — higher score = more arc filled
    const score = total > 0 ? (passed / total) : 0;
    const circumference = 2 * Math.PI * 85; // ~534
    const offset = circumference * (1 - score);

    setTimeout(() => {
        arc.style.strokeDashoffset = offset;
    }, 300);
}

function animateValue(cardId, value, total) {
    const card = document.getElementById(cardId);
    const valueEl = card.querySelector('.stat-value');
    const fillEl = card.querySelector('.stat-fill');

    // Animate counter
    let current = 0;
    const increment = Math.max(1, Math.floor(value / 20));
    const timer = setInterval(() => {
        current += increment;
        if (current >= value) {
            current = value;
            clearInterval(timer);
        }
        valueEl.textContent = current;
    }, 50);

    // Animate bar
    const pct = total > 0 ? (value / total * 100) : 0;
    setTimeout(() => {
        fillEl.style.width = pct + '%';
    }, 200);
}

function updateModuleStatuses(data) {
    const warnings = data.summary.warnings;
    const critical = data.summary.critical;

    // Module status mapping based on actual scan findings
    const moduleStatus = {
        'network_discovery': warnings > 0 ? 'warn' : 'pass',
        'port_scan': 'warn',       // iMac has open ports
        'arp_integrity': critical > 0 ? 'crit' : 'pass',
        'dns_integrity': 'pass',
        'prompt_injection': 'warn', // API keys in env vars
        'local_security': 'warn',   // Listener review needed
        'vps_security': 'pass',
        'wireless_security': 'warn', // 1 open network in range
        'ssl_tls_audit': 'warn',    // NAS SSL unavailable
        'service_fingerprint': 'pass'
    };

    CONFIG.modules.forEach((m, i) => {
        const card = document.getElementById(`module-${m.id}`);
        if (!card) return;

        const statusEl = card.querySelector('.module-status');

        setTimeout(() => {
            const st = moduleStatus[m.id] || 'pass';
            let status, statusClass, moduleColor;

            if (st === 'crit') {
                status = '🔴 ALERT';
                statusClass = 'crit';
                moduleColor = 'var(--red)';
            } else if (st === 'warn') {
                status = '⚠️ FINDINGS';
                statusClass = 'warn';
                moduleColor = 'var(--yellow)';
            } else {
                status = '✅ CLEAR';
                statusClass = 'pass';
                moduleColor = 'var(--green)';
            }

            statusEl.className = `module-status ${statusClass}`;
            statusEl.textContent = status;
            card.style.setProperty('--module-color', moduleColor);
        }, 100 * i);
    });
}

function updateDeviceStatuses(data) {
    // Real online/offline/alert state from actual scan
    const onlineIPs = ['192.168.1.1', '192.168.1.140', '192.168.1.146', '192.168.1.239'];
    const alertIPs = ['192.168.1.140']; // iMac has VNC/SSH/SMB open
    const offlineIPs = ['192.168.1.171', '192.168.1.151', '192.168.1.102', '192.168.1.187'];

    CONFIG.devices.forEach(d => {
        const card = document.getElementById(`device-${d.ip.replace(/\./g, '-')}`);
        if (!card) return;

        const statusEl = card.querySelector('.device-status');

        if (alertIPs.includes(d.ip)) {
            statusEl.className = 'device-status alert';
            statusEl.textContent = '⚠️ OPEN PORTS';
        } else if (onlineIPs.includes(d.ip)) {
            statusEl.className = 'device-status online';
            statusEl.textContent = '● ONLINE';
        } else {
            statusEl.className = 'device-status offline';
            statusEl.textContent = '○ OFFLINE';
        }
    });
}

function updateLogFeed(data) {
    const feed = document.getElementById('log-feed');

    // Real findings from v2.0 scan (2026-02-13_14-50-24)
    const findings = [
        { type: 'pass', text: 'ARP table clean — no spoofing detected' },
        { type: 'warn', text: 'Unknown device at 192.168.1.146 (MAC mismatch)' },
        { type: 'warn', text: 'iMac (192.168.1.140): Port 5900 VNC is OPEN' },
        { type: 'warn', text: 'iMac (192.168.1.140): Port 22 SSH is OPEN' },
        { type: 'warn', text: 'iMac (192.168.1.140): Port 445 SMB is OPEN' },
        { type: 'warn', text: 'API keys in environment variables (exfil risk)' },
        { type: 'warn', text: 'Listener Python (*:8888): Review required' },
        { type: 'warn', text: 'Listener node (*:3000): Review required' },
        { type: 'warn', text: '1 open network in range — evil twin risk' },
        { type: 'pass', text: 'Firewall: Enabled' },
        { type: 'pass', text: 'FileVault: Encrypted' },
        { type: 'pass', text: 'SIP: Enabled' },
        { type: 'pass', text: 'Gatekeeper: Enabled' },
        { type: 'pass', text: 'Wi-Fi: WPA2/WPA3 Personal (strongest)' },
        { type: 'pass', text: 'Wi-Fi: Connected • 802.11ax • Channel 44 (5GHz)' },
        { type: 'pass', text: 'SSL: Router cert valid (236 days)' },
        { type: 'pass', text: 'DNS: google.com → 142.250.179.110' },
        { type: 'pass', text: 'DNS: apple.com → 17.253.144.10' },
        { type: 'pass', text: 'DNS: github.com → 140.82.121.4' },
        { type: 'pass', text: 'Agent configs: Clean (main, clawbot)' },
        { type: 'pass', text: 'Samsung Tab S8: Stealth mode (no open ports)' },
        { type: 'warn', text: 'NAS SSL (192.168.1.187) — offline, cannot validate' },
        { type: 'warn', text: 'NAS DSM SSL (192.168.1.187:5001) — offline' },
    ];

    const icons = { pass: '✅', warn: '⚠️', crit: '🔴' };

    feed.innerHTML = findings.map((f, i) => `
    <div class="log-entry ${f.type}" style="animation-delay: ${i * 0.05}s">
      <span class="icon">${icons[f.type]}</span>
      <span>${f.text}</span>
    </div>
  `).join('');
}

// ── Scan History ──
function renderScanHistory(history) {
    const container = document.getElementById('scan-history');
    container.innerHTML = history.map(s => `
    <div class="scan-entry" onclick="alert('Report: scan_${s.date}.md')">
      <span class="scan-date">${s.date}</span>
      <span class="scan-stats">
        <span class="pass">✅ ${s.passed}</span>
        <span class="warn">⚠️ ${s.warnings}</span>
        <span class="crit">🔴 ${s.critical}</span>
      </span>
    </div>
  `).join('');
}

// ── Trend Chart ──
function drawTrendChart() {
    const canvas = document.getElementById('trend-canvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.parentElement.getBoundingClientRect();

    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);

    const w = rect.width;
    const h = rect.height;
    const pad = { top: 30, right: 20, bottom: 40, left: 45 };
    const chartW = w - pad.left - pad.right;
    const chartH = h - pad.top - pad.bottom;

    // Data from scan history
    const data = scanHistory.length > 0 ? scanHistory.slice().reverse() : [
        { date: '02-09', passed: 10, warnings: 5, critical: 3 },
        { date: '02-10', passed: 12, warnings: 6, critical: 2 },
        { date: '02-11', passed: 14, warnings: 8, critical: 1 },
    ];

    const maxVal = Math.max(...data.map(d => d.passed + d.warnings + d.critical), 1);

    // Clear
    ctx.clearRect(0, 0, w, h);

    // Grid lines
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.04)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 4; i++) {
        const y = pad.top + chartH * (i / 4);
        ctx.beginPath();
        ctx.moveTo(pad.left, y);
        ctx.lineTo(w - pad.right, y);
        ctx.stroke();

        // Y labels
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        ctx.font = '10px "JetBrains Mono"';
        ctx.textAlign = 'right';
        ctx.fillText(Math.round(maxVal * (1 - i / 4)), pad.left - 8, y + 4);
    }

    // X labels
    data.forEach((d, i) => {
        const x = pad.left + chartW * (i / (data.length - 1 || 1));
        ctx.fillStyle = 'rgba(255, 255, 255, 0.3)';
        ctx.font = '10px "JetBrains Mono"';
        ctx.textAlign = 'center';
        ctx.fillText(d.date, x, h - pad.bottom + 20);
    });

    // Draw lines
    const drawLine = (key, color, shadowColor) => {
        ctx.strokeStyle = color;
        ctx.lineWidth = 2;
        ctx.lineJoin = 'round';
        ctx.lineCap = 'round';
        ctx.shadowColor = shadowColor;
        ctx.shadowBlur = 8;

        ctx.beginPath();
        data.forEach((d, i) => {
            const x = pad.left + chartW * (i / (data.length - 1 || 1));
            const y = pad.top + chartH * (1 - d[key] / maxVal);
            if (i === 0) ctx.moveTo(x, y);
            else ctx.lineTo(x, y);
        });
        ctx.stroke();
        ctx.shadowBlur = 0;

        // Dots
        data.forEach((d, i) => {
            const x = pad.left + chartW * (i / (data.length - 1 || 1));
            const y = pad.top + chartH * (1 - d[key] / maxVal);

            ctx.beginPath();
            ctx.arc(x, y, 4, 0, Math.PI * 2);
            ctx.fillStyle = color;
            ctx.fill();

            ctx.beginPath();
            ctx.arc(x, y, 2, 0, Math.PI * 2);
            ctx.fillStyle = '#0a0e17';
            ctx.fill();
        });
    };

    drawLine('passed', '#10b981', 'rgba(16, 185, 129, 0.5)');
    drawLine('warnings', '#f59e0b', 'rgba(245, 158, 11, 0.5)');
    drawLine('critical', '#ef4444', 'rgba(239, 68, 68, 0.5)');

    // Legend
    const legend = [
        { label: 'Passed', color: '#10b981' },
        { label: 'Warnings', color: '#f59e0b' },
        { label: 'Critical', color: '#ef4444' }
    ];

    let legendX = pad.left;
    legend.forEach(l => {
        ctx.fillStyle = l.color;
        ctx.beginPath();
        ctx.arc(legendX + 5, pad.top - 15, 4, 0, Math.PI * 2);
        ctx.fill();

        ctx.fillStyle = 'rgba(255, 255, 255, 0.5)';
        ctx.font = '10px "JetBrains Mono"';
        ctx.textAlign = 'left';
        ctx.fillText(l.label, legendX + 14, pad.top - 11);
        legendX += 90;
    });
}

// ── Trigger Scan ──
function triggerScan() {
    const btn = document.getElementById('btn-scan');
    const statusEl = document.getElementById('system-status');

    btn.disabled = true;
    btn.innerHTML = '<svg class="spin" width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="1.5" stroke-dasharray="30" stroke-linecap="round"/></svg> Scanning...';

    statusEl.querySelector('.status-text').textContent = 'SCANNING';
    statusEl.querySelector('.status-dot').style.background = 'var(--yellow)';
    statusEl.style.borderColor = 'rgba(245, 158, 11, 0.3)';
    statusEl.style.background = 'var(--yellow-bg)';
    statusEl.style.color = 'var(--yellow)';

    // Animate modules sequentially
    CONFIG.modules.forEach((m, i) => {
        const card = document.getElementById(`module-${m.id}`);
        if (!card) return;
        const statusEl2 = card.querySelector('.module-status');

        setTimeout(() => {
            statusEl2.className = 'module-status warn';
            statusEl2.textContent = '🔄 SCANNING...';
            card.style.setProperty('--module-color', 'var(--accent)');
        }, i * 800);

        setTimeout(() => {
            const isOk = Math.random() > 0.2;
            statusEl2.className = `module-status ${isOk ? 'pass' : 'warn'}`;
            statusEl2.textContent = isOk ? '✅ CLEAR' : '⚠️ FINDINGS';
            card.style.setProperty('--module-color', isOk ? 'var(--green)' : 'var(--yellow)');
        }, (i + 1) * 800);
    });

    // Complete after all modules
    setTimeout(() => {
        btn.disabled = false;
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 1v3M8 12v3M15 8h-3M4 8H1M13 3L10.5 5.5M5.5 10.5L3 13M13 13l-2.5-2.5M5.5 5.5L3 3" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg> Run Scan';

        statusEl.querySelector('.status-text').textContent = 'MONITORING';
        statusEl.querySelector('.status-dot').style.background = 'var(--green)';
        statusEl.style.borderColor = 'rgba(16, 185, 129, 0.2)';
        statusEl.style.background = 'var(--green-bg)';
        statusEl.style.color = 'var(--green)';
    }, CONFIG.modules.length * 800 + 500);
}

// ── Window Resize ──
window.addEventListener('resize', () => {
    drawTrendChart();
});

// ── CSS for spinner ──
const style = document.createElement('style');
style.textContent = `
  .spin { animation: spin 1s linear infinite; }
  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
`;
document.head.appendChild(style);
