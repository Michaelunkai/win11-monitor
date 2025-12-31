const express = require('express');
const { WebSocketServer } = require('ws');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Data storage
let currentMetrics = {};
let eventLogs = [];
let systemDiagnostics = { issues: [], warnings: [], summary: { critical: 0, high: 0, medium: 0, low: 0 } };
let metricsHistory = [];
const MAX_HISTORY = 100;

// Detect if running on Windows
const isWindows = process.platform === 'win32';
const DEMO_MODE = !isWindows;

// DEMO MODE - Returns message that real Windows is needed
function generateDemoMessage() {
    return {
        error: "DEMO MODE - Real Windows 11 Required",
        message: "This monitoring tool requires Windows 11 to collect real system data. Currently running on " + process.platform,
        instructions: "To see real data from your Windows 11 laptop, run this application on Windows with: npm start",
        demoMode: true
    };
}

// Helper function to execute PowerShell scripts
function executePowerShellScript(scriptPath) {
    return new Promise((resolve, reject) => {
        const ps = spawn('powershell.exe', [
            '-ExecutionPolicy', 'Bypass',
            '-File', scriptPath
        ]);

        let output = '';
        let errorOutput = '';

        ps.stdout.on('data', (data) => {
            output += data.toString();
        });

        ps.stderr.on('data', (data) => {
            errorOutput += data.toString();
        });

        ps.on('close', (code) => {
            if (code !== 0 && errorOutput) {
                reject(new Error(errorOutput));
            } else {
                try {
                    const jsonData = JSON.parse(output.trim());
                    resolve(jsonData);
                } catch (e) {
                    resolve({ error: 'Failed to parse JSON', raw: output });
                }
            }
        });
    });
}

// Collect system metrics - REAL DATA ONLY
async function collectMetrics() {
    if (DEMO_MODE) {
        return generateDemoMessage();
    }

    try {
        const metricsScript = path.join(__dirname, 'scripts', 'collect-metrics.ps1');
        const data = await executePowerShellScript(metricsScript);

        currentMetrics = data;

        // Add to history
        metricsHistory.push({
            timestamp: new Date().toISOString(),
            cpu: data.cpu || 0,
            memory: data.memory ? data.memory.percent : 0
        });

        // Keep only recent history
        if (metricsHistory.length > MAX_HISTORY) {
            metricsHistory.shift();
        }

        return data;
    } catch (error) {
        console.error('Error collecting metrics:', error);
        return { error: error.message };
    }
}

// Collect event logs - REAL ERRORS ONLY
async function collectEventLogs() {
    if (DEMO_MODE) {
        return { events: [], message: "Run on Windows 11 to see real error logs" };
    }

    try {
        const logsScript = path.join(__dirname, 'scripts', 'collect-eventlogs.ps1');
        const data = await executePowerShellScript(logsScript);

        eventLogs = data.events || [];

        return data;
    } catch (error) {
        console.error('Error collecting event logs:', error);
        return { error: error.message, events: [] };
    }
}

// Collect system diagnostics - REAL PROBLEMS ONLY
async function collectDiagnostics() {
    if (DEMO_MODE) {
        return {
            issues: [],
            warnings: [],
            info: [{
                message: "This monitoring tool requires Windows 11",
                details: "Currently running on " + process.platform + ". To see real diagnostics (Windows Updates, Driver errors, Disk problems, etc.), run this on your Windows 11 laptop."
            }],
            summary: { critical: 0, high: 0, medium: 0, low: 0 },
            totalIssues: 0,
            timestamp: new Date().toISOString()
        };
    }

    try {
        const diagnosticsScript = path.join(__dirname, 'scripts', 'collect-diagnostics.ps1');
        const data = await executePowerShellScript(diagnosticsScript);

        systemDiagnostics = data;

        return data;
    } catch (error) {
        console.error('Error collecting diagnostics:', error);
        return {
            error: error.message,
            issues: [],
            warnings: [],
            summary: { critical: 0, high: 0, medium: 0, low: 0 },
            totalIssues: 0
        };
    }
}

// API Routes
app.get('/api/metrics', async (req, res) => {
    const data = await collectMetrics();
    res.json(data);
});

app.get('/api/eventlogs', async (req, res) => {
    const data = await collectEventLogs();
    res.json(data);
});

app.get('/api/diagnostics', async (req, res) => {
    const data = await collectDiagnostics();
    res.json(data);
});

app.get('/api/history', (req, res) => {
    res.json({
        history: metricsHistory,
        count: metricsHistory.length
    });
});

app.get('/api/status', (req, res) => {
    res.json({
        status: 'online',
        timestamp: new Date().toISOString(),
        platform: process.platform,
        nodeVersion: process.version,
        demoMode: DEMO_MODE
    });
});

// Start HTTP server
const server = app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log(`Mode: ${DEMO_MODE ? 'DEMO' : 'PRODUCTION (Windows)'}`);
    console.log('Starting periodic data collection...');

    // Initial data collection
    collectMetrics();
    collectEventLogs();
    collectDiagnostics();
});

// WebSocket Server
const wss = new WebSocketServer({ server });

wss.on('connection', (ws) => {
    console.log('WebSocket client connected');

    // Send current data immediately
    ws.send(JSON.stringify({
        type: 'metrics',
        data: currentMetrics
    }));

    ws.send(JSON.stringify({
        type: 'eventlogs',
        data: { events: eventLogs }
    }));

    ws.send(JSON.stringify({
        type: 'diagnostics',
        data: systemDiagnostics
    }));

    ws.on('close', () => {
        console.log('WebSocket client disconnected');
    });
});

// Broadcast to all connected clients
function broadcastToClients(type, data) {
    wss.clients.forEach((client) => {
        if (client.readyState === 1) { // WebSocket.OPEN
            client.send(JSON.stringify({ type, data }));
        }
    });
}

// Periodic data collection and broadcast
setInterval(async () => {
    const metrics = await collectMetrics();
    broadcastToClients('metrics', metrics);
}, 3000); // Every 3 seconds

setInterval(async () => {
    const logs = await collectEventLogs();
    broadcastToClients('eventlogs', logs);
}, 10000); // Every 10 seconds

setInterval(async () => {
    const diagnostics = await collectDiagnostics();
    broadcastToClients('diagnostics', diagnostics);
}, 30000); // Every 30 seconds

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down server...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
