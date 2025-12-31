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
let metricsHistory = [];
const MAX_HISTORY = 100;

// Detect if running on Windows
const isWindows = process.platform === 'win32';
const DEMO_MODE = !isWindows;

// Demo data generators
function generateDemoMetrics() {
    const cpuBase = 30 + Math.random() * 40;
    const memoryBase = 50 + Math.random() * 30;

    return {
        cpu: parseFloat(cpuBase.toFixed(2)),
        memory: {
            total: 16.0,
            used: parseFloat((16 * memoryBase / 100).toFixed(2)),
            free: parseFloat((16 * (100 - memoryBase) / 100).toFixed(2)),
            percent: parseFloat(memoryBase.toFixed(2))
        },
        disks: [
            {
                drive: 'C:',
                total: 475.9,
                used: parseFloat((475.9 * (60 + Math.random() * 20) / 100).toFixed(2)),
                free: parseFloat((475.9 * (40 - Math.random() * 20) / 100).toFixed(2)),
                percent: parseFloat((60 + Math.random() * 20).toFixed(2))
            },
            {
                drive: 'D:',
                total: 931.5,
                used: parseFloat((931.5 * (40 + Math.random() * 30) / 100).toFixed(2)),
                free: parseFloat((931.5 * (60 - Math.random() * 30) / 100).toFixed(2)),
                percent: parseFloat((40 + Math.random() * 30).toFixed(2))
            }
        ],
        network: [
            {
                name: 'Ethernet',
                receivedMB: parseFloat((Math.random() * 1000).toFixed(2)),
                sentMB: parseFloat((Math.random() * 500).toFixed(2))
            },
            {
                name: 'Wi-Fi',
                receivedMB: parseFloat((Math.random() * 2000).toFixed(2)),
                sentMB: parseFloat((Math.random() * 800).toFixed(2))
            }
        ],
        processes: [
            { name: 'System', cpu: parseFloat((5 + Math.random() * 10).toFixed(2)), memory: parseFloat((200 + Math.random() * 100).toFixed(2)), pid: 4 },
            { name: 'chrome.exe', cpu: parseFloat((10 + Math.random() * 20).toFixed(2)), memory: parseFloat((500 + Math.random() * 300).toFixed(2)), pid: 1234 },
            { name: 'node.exe', cpu: parseFloat((5 + Math.random() * 15).toFixed(2)), memory: parseFloat((150 + Math.random() * 100).toFixed(2)), pid: 5678 },
            { name: 'explorer.exe', cpu: parseFloat((2 + Math.random() * 8).toFixed(2)), memory: parseFloat((100 + Math.random() * 50).toFixed(2)), pid: 9012 },
            { name: 'vscode.exe', cpu: parseFloat((8 + Math.random() * 12).toFixed(2)), memory: parseFloat((300 + Math.random() * 200).toFixed(2)), pid: 3456 }
        ],
        uptime: {
            days: 5,
            hours: 12,
            minutes: 34
        }
    };
}

function generateDemoEventLogs() {
    const eventTypes = ['Critical', 'Error', 'Warning'];
    const sources = ['System', 'Application'];
    const messages = [
        'The system has rebooted without cleanly shutting down first',
        'Application error: Failed to initialize component',
        'Disk quota threshold exceeded on volume C:',
        'Windows Update service terminated unexpectedly',
        'Network adapter driver encountered an error',
        'Security policy was applied successfully',
        'Service entered the running state',
        'User authentication completed successfully'
    ];

    const events = [];
    for (let i = 0; i < 15; i++) {
        const date = new Date(Date.now() - i * 3600000);
        events.push({
            source: sources[Math.floor(Math.random() * sources.length)],
            level: eventTypes[Math.floor(Math.random() * eventTypes.length)],
            id: 1000 + Math.floor(Math.random() * 9000),
            message: messages[Math.floor(Math.random() * messages.length)],
            timestamp: date.toISOString()
        });
    }

    return { events };
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

// Collect system metrics
async function collectMetrics() {
    if (DEMO_MODE) {
        currentMetrics = generateDemoMetrics();

        // Add to history
        metricsHistory.push({
            timestamp: new Date().toISOString(),
            cpu: currentMetrics.cpu || 0,
            memory: currentMetrics.memory ? currentMetrics.memory.percent : 0
        });

        // Keep only recent history
        if (metricsHistory.length > MAX_HISTORY) {
            metricsHistory.shift();
        }

        return currentMetrics;
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

// Collect event logs
async function collectEventLogs() {
    if (DEMO_MODE) {
        const data = generateDemoEventLogs();
        eventLogs = data.events || [];
        return data;
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

// API Routes
app.get('/api/metrics', async (req, res) => {
    const data = await collectMetrics();
    res.json(data);
});

app.get('/api/eventlogs', async (req, res) => {
    const data = await collectEventLogs();
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
        nodeVersion: process.version
    });
});

// Start HTTP server
const server = app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
    console.log('Starting periodic data collection...');

    // Initial data collection
    collectMetrics();
    collectEventLogs();
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

// Graceful shutdown
process.on('SIGINT', () => {
    console.log('Shutting down server...');
    server.close(() => {
        console.log('Server closed');
        process.exit(0);
    });
});
