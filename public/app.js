// Real-time Windows 11 Monitor Dashboard
let ws = null;
let cpuChart = null;
let memoryChart = null;
let currentFilter = 'all';
let allEvents = [];

// Initialize WebSocket connection
function connectWebSocket() {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${protocol}//${window.location.host}`;

    ws = new WebSocket(wsUrl);

    ws.onopen = () => {
        console.log('WebSocket connected');
        updateConnectionStatus(true);
    };

    ws.onmessage = (event) => {
        const message = JSON.parse(event.data);

        if (message.type === 'metrics') {
            updateMetrics(message.data);
        } else if (message.type === 'eventlogs') {
            updateEventLogs(message.data);
        }
    };

    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateConnectionStatus(false);
    };

    ws.onclose = () => {
        console.log('WebSocket disconnected');
        updateConnectionStatus(false);

        // Attempt to reconnect after 5 seconds
        setTimeout(connectWebSocket, 5000);
    };
}

// Update connection status indicator
function updateConnectionStatus(connected) {
    const statusDot = document.getElementById('statusDot');
    const statusText = document.getElementById('statusText');

    if (connected) {
        statusDot.classList.add('connected');
        statusText.textContent = 'Connected';
    } else {
        statusDot.classList.remove('connected');
        statusText.textContent = 'Disconnected';
    }
}

// Initialize Charts
function initCharts() {
    const commonOptions = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
            legend: { display: false }
        },
        scales: {
            x: { display: false },
            y: {
                display: false,
                min: 0,
                max: 100
            }
        },
        elements: {
            line: {
                tension: 0.4,
                borderWidth: 2
            },
            point: {
                radius: 0
            }
        }
    };

    // CPU Chart
    const cpuCtx = document.getElementById('cpuChart').getContext('2d');
    cpuChart = new Chart(cpuCtx, {
        type: 'line',
        data: {
            labels: Array(20).fill(''),
            datasets: [{
                data: Array(20).fill(0),
                borderColor: '#4a9eff',
                backgroundColor: 'rgba(74, 158, 255, 0.1)',
                fill: true
            }]
        },
        options: commonOptions
    });

    // Memory Chart
    const memoryCtx = document.getElementById('memoryChart').getContext('2d');
    memoryChart = new Chart(memoryCtx, {
        type: 'line',
        data: {
            labels: Array(20).fill(''),
            datasets: [{
                data: Array(20).fill(0),
                borderColor: '#4ade80',
                backgroundColor: 'rgba(74, 222, 128, 0.1)',
                fill: true
            }]
        },
        options: commonOptions
    });
}

// Update metrics display
function updateMetrics(data) {
    if (!data) return;

    // Update CPU
    if (data.cpu !== undefined) {
        document.getElementById('cpuValue').textContent = `${data.cpu.toFixed(1)}%`;
        updateChart(cpuChart, data.cpu);
    }

    // Update Memory
    if (data.memory) {
        document.getElementById('memoryValue').textContent = `${data.memory.percent.toFixed(1)}%`;
        document.getElementById('memoryDetail').textContent =
            `${data.memory.used.toFixed(1)} / ${data.memory.total.toFixed(1)} GB`;
        updateChart(memoryChart, data.memory.percent);
    }

    // Update Uptime
    if (data.uptime) {
        const uptime = `${data.uptime.days}d ${data.uptime.hours}h ${data.uptime.minutes}m`;
        document.getElementById('uptimeValue').textContent = uptime;
    }

    // Update Disks
    if (data.disks) {
        updateDisks(data.disks);
    }

    // Update Network
    if (data.network) {
        updateNetwork(data.network);
    }

    // Update Processes
    if (data.processes) {
        updateProcesses(data.processes);
    }

    // Update timestamp
    document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
}

// Update chart with new data
function updateChart(chart, newValue) {
    chart.data.datasets[0].data.shift();
    chart.data.datasets[0].data.push(newValue);
    chart.update('none');
}

// Update disk information
function updateDisks(disks) {
    const diskList = document.getElementById('diskList');
    diskList.innerHTML = '';

    disks.forEach(disk => {
        const diskItem = document.createElement('div');
        diskItem.className = 'disk-item';

        const progressClass = disk.percent > 80 ? 'warning' : '';

        diskItem.innerHTML = `
            <div class="disk-header">
                <span class="disk-label">${disk.drive}</span>
                <span class="disk-stats">${disk.used.toFixed(1)} / ${disk.total.toFixed(1)} GB (${disk.percent.toFixed(1)}%)</span>
            </div>
            <div class="progress-bar">
                <div class="progress-fill ${progressClass}" style="width: ${disk.percent}%"></div>
            </div>
        `;

        diskList.appendChild(diskItem);
    });
}

// Update network information
function updateNetwork(networks) {
    const networkInfo = document.getElementById('networkInfo');
    networkInfo.innerHTML = '';

    if (networks.length === 0) {
        networkInfo.innerHTML = '<div class="stat-detail">No active network connections</div>';
        return;
    }

    networks.slice(0, 3).forEach(net => {
        const networkItem = document.createElement('div');
        networkItem.className = 'network-item';

        networkItem.innerHTML = `
            <div class="network-name">${net.name}</div>
            <div class="network-stats">
                <span>↓ ${net.receivedMB.toFixed(2)} MB</span>
                <span>↑ ${net.sentMB.toFixed(2)} MB</span>
            </div>
        `;

        networkInfo.appendChild(networkItem);
    });
}

// Update process table
function updateProcesses(processes) {
    const tableBody = document.getElementById('processTableBody');
    tableBody.innerHTML = '';

    if (processes.length === 0) {
        tableBody.innerHTML = '<tr><td colspan="4">No process data available</td></tr>';
        return;
    }

    processes.forEach(proc => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>${proc.name}</td>
            <td>${proc.cpu.toFixed(2)}</td>
            <td>${proc.memory.toFixed(2)}</td>
            <td>${proc.pid}</td>
        `;
        tableBody.appendChild(row);
    });
}

// Update event logs
function updateEventLogs(data) {
    if (!data || !data.events) return;

    allEvents = data.events;
    filterAndDisplayEvents();
}

// Filter and display events
function filterAndDisplayEvents() {
    const eventLogsList = document.getElementById('eventLogsList');
    eventLogsList.innerHTML = '';

    let filteredEvents = allEvents;
    if (currentFilter !== 'all') {
        filteredEvents = allEvents.filter(event => event.level === currentFilter);
    }

    if (filteredEvents.length === 0) {
        eventLogsList.innerHTML = '<div class="stat-detail">No events found</div>';
        return;
    }

    filteredEvents.forEach(event => {
        const eventItem = document.createElement('div');
        eventItem.className = `event-item ${event.level}`;

        eventItem.innerHTML = `
            <div class="event-header">
                <span class="event-level ${event.level}">${event.level}</span>
                <span class="event-source">${event.source}</span>
            </div>
            <div class="event-message">${event.message}</div>
            <div class="event-footer">
                <span>Event ID: ${event.id}</span>
                <span>${event.timestamp}</span>
            </div>
        `;

        eventLogsList.appendChild(eventItem);
    });
}

// Set up event log filters
function setupEventFilters() {
    const filterButtons = document.querySelectorAll('.filter-btn');

    filterButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            filterButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            currentFilter = btn.dataset.filter;
            filterAndDisplayEvents();
        });
    });
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    console.log('Initializing Windows 11 Monitor Dashboard...');

    initCharts();
    setupEventFilters();
    connectWebSocket();

    // Fallback: Fetch data via API if WebSocket fails
    setInterval(() => {
        if (!ws || ws.readyState !== WebSocket.OPEN) {
            fetch('/api/metrics')
                .then(res => res.json())
                .then(data => updateMetrics(data))
                .catch(err => console.error('Error fetching metrics:', err));

            fetch('/api/eventlogs')
                .then(res => res.json())
                .then(data => updateEventLogs(data))
                .catch(err => console.error('Error fetching event logs:', err));
        }
    }, 5000);
});
