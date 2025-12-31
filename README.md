# Windows 11 System Monitor

A real-time web-based monitoring dashboard for Windows 11 systems with live metrics, event logs, and system statistics.

## Features

- **Real-time CPU Monitoring** - Live CPU usage with historical charts
- **Memory Tracking** - RAM usage statistics with visualization
- **Disk Usage** - Monitor all drives with usage percentages
- **Network Activity** - Track network adapter statistics
- **Process Monitoring** - View top processes by CPU and memory
- **Event Logs** - Real-time system and application event logs with filtering
- **WebSocket Support** - Live updates every 3 seconds
- **Dark Theme UI** - Modern, responsive design

## Technology Stack

- **Backend**: Node.js, Express, WebSocket
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Charts**: Chart.js
- **Data Collection**: PowerShell scripts
- **Deployment**: Railway (free tier)

## Local Installation

### Prerequisites

- Node.js (v14 or higher)
- Windows 11 (PowerShell 5.0+)
- npm

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd win11-monitor
```

2. Install dependencies:
```bash
npm install
```

3. Start the server:
```bash
npm start
```

4. Open your browser and navigate to:
```
http://localhost:3000
```

## Project Structure

```
win11-monitor/
├── server.js               # Main Node.js server with WebSocket
├── package.json            # Dependencies and scripts
├── public/                 # Frontend files
│   ├── index.html         # Main dashboard UI
│   ├── style.css          # Modern dark theme styling
│   └── app.js             # Real-time dashboard logic
├── scripts/               # PowerShell data collectors
│   ├── collect-metrics.ps1    # System metrics collector
│   └── collect-eventlogs.ps1  # Event log collector
└── data/                  # Runtime data storage (auto-created)
```

## API Endpoints

- `GET /api/metrics` - Current system metrics
- `GET /api/eventlogs` - Recent event logs
- `GET /api/history` - Historical metrics data
- `GET /api/status` - Server status
- `WebSocket /` - Real-time data streaming

## Data Collection

### Metrics Collected (Every 3 seconds)
- CPU usage percentage
- Memory (total, used, free, percentage)
- Disk usage for all drives
- Network adapter statistics
- Top 10 processes by CPU
- System uptime

### Event Logs Collected (Every 10 seconds)
- System errors and warnings
- Application errors and warnings
- Recent 30 events with filtering

## Deployment

This application is deployed on Railway's free tier with **Demo Mode** enabled.

### Demo Mode

When deployed on Railway (Linux environment), the application automatically switches to **Demo Mode** which generates realistic random system metrics and event logs for demonstration purposes. This allows the dashboard to run on any platform without requiring Windows PowerShell.

- **Windows Local**: Real PowerShell data collection
- **Railway/Linux**: Demo mode with simulated data

### Deploy Your Own

1. Fork this repository
2. Create a Railway account at [railway.app](https://railway.app)
3. Create a new project from GitHub repository
4. Railway will auto-detect and deploy
5. Access your live URL with demo data

**Note**: For real monitoring of your Windows 11 machine, run the application locally on Windows or use a Windows-based hosting solution.

## Configuration

### Port Configuration
Default port: 3000 (configurable via environment variable)
```bash
PORT=3000 npm start
```

### Data Refresh Rates
- Metrics: 3 seconds
- Event Logs: 10 seconds
- Chart History: 100 data points

## Browser Compatibility

- Chrome/Edge (recommended)
- Firefox
- Safari
- Opera

## Performance

- Lightweight: ~70 npm packages
- Low resource usage
- Efficient WebSocket connections
- Optimized PowerShell scripts

## Security Notes

- Designed for local/internal network use
- Event logs limited to errors and warnings
- No sensitive data exposure
- CORS enabled for development

## License

MIT

## Author

Built with Claude Code
