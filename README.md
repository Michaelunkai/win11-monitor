# Windows 11 System Monitor

A real-time web-based monitoring dashboard for Windows 11 systems with live metrics, event logs, and system statistics.

## 🚀 Live Demo & Deployment

**🌐 Live Demo:** [https://win11-monitor.onrender.com](https://win11-monitor.onrender.com/)

**Try it now:** Deploy your own instance in 2 minutes - 100% FREE forever!

### One-Click Deploy (FREE Forever)

Click any button below to instantly deploy your own instance:

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/Michaelunkai/win11-monitor)

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template?repo=https://github.com/Michaelunkai/win11-monitor)

**After deployment, you'll get a permanent URL like:**
- Render: `https://win11-monitor.onrender.com`
- Railway: `https://win11-monitor-production.up.railway.app`
- Vercel: `https://win11-monitor.vercel.app`

### Manual Deploy

**Render.com** (Recommended):
```bash
# Just connect your GitHub account and click deploy!
# Visit: https://render.com/deploy?repo=https://github.com/Michaelunkai/win11-monitor
```

**Railway.app**:
```bash
# Visit railway.app, connect GitHub, select this repo
# Your app will be live at: https://win11-monitor-production.up.railway.app
```

**Vercel**:
```bash
npm i -g vercel
vercel --prod
# Your app will be live at: https://win11-monitor.vercel.app
```

All platforms offer 100% free hosting with permanent URLs, automatic HTTPS, and global CDN!

## Features

### 🎯 Real-Time System Monitoring
- **Enhanced CPU Monitoring** - Multi-sample averaging for accurate CPU usage with historical charts
- **Advanced Memory Tracking** - Physical, available, and committed memory with detailed statistics
- **Disk Health Monitoring** - Drive usage, SMART status, and disk activity tracking
- **Network Diagnostics** - Live adapter status, link speed, and bandwidth monitoring
- **GPU Information** - Graphics card details and usage (when available)
- **Battery Status** - Laptop battery level and charging state
- **Temperature Monitoring** - CPU temperature tracking (when available)
- **Process Analysis** - Real-time CPU percentage per process (not just cumulative time)

### 🔍 Comprehensive System Diagnostics
- **Windows Update Detection** - Pending updates, failed installations, and service status
- **Driver Problem Detection** - Automatic detection of Device Manager errors with error codes
- **Network Connectivity Checks** - Internet connectivity, DNS resolution, and adapter status
- **Disk Health Analysis** - SMART data, low space warnings, and physical disk health
- **Critical Service Monitoring** - Windows services status and failure detection
- **Security Status** - Windows Defender status and outdated definitions alerts
- **Performance Alerts** - High CPU/memory usage and temperature warnings

### 📝 Enhanced Event Logging
- **Categorized Events** - Events grouped by type (Disk, Network, Driver, Service, etc.)
- **Priority-Based Filtering** - Critical events highlighted and prioritized
- **Actionable Error Logs** - Focus on real problems that need fixing
- **Security Events** - Failed login attempts and security policy changes
- **Application Crash Detection** - Identify and log application failures

### 🎨 User Interface
- **WebSocket Support** - Live updates every 3 seconds (metrics), 10 seconds (logs), 30 seconds (diagnostics)
- **Dark Theme UI** - Modern, responsive design
- **Interactive Diagnostics** - Color-coded severity levels with recommendations
- **Real-time Charts** - Historical data visualization

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
├── server.js                      # Main Node.js server with WebSocket
├── package.json                   # Dependencies and scripts
├── public/                        # Frontend files
│   ├── index.html                # Enhanced dashboard UI with diagnostics
│   ├── style.css                 # Modern dark theme with diagnostic styling
│   └── app.js                    # Real-time dashboard with health monitoring
├── scripts/                       # PowerShell data collectors
│   ├── collect-metrics.ps1       # Enhanced metrics (CPU, Memory, GPU, Battery, etc.)
│   ├── collect-eventlogs.ps1     # Categorized and prioritized event logs
│   └── collect-diagnostics.ps1   # Comprehensive system health diagnostics
└── data/                          # Runtime data storage (auto-created)
```

## API Endpoints

- `GET /api/metrics` - Enhanced system metrics (CPU, Memory, Disk, Network, GPU, Battery, Temperature)
- `GET /api/eventlogs` - Categorized and prioritized event logs
- `GET /api/diagnostics` - Comprehensive system health diagnostics
- `GET /api/history` - Historical metrics data
- `GET /api/status` - Server status and mode information
- `WebSocket /` - Real-time data streaming for all metrics

## Data Collection

### Enhanced Metrics (Every 3 seconds)
- **CPU**: Multi-sample average usage, core count, clock speeds, temperature
- **Memory**: Physical, available, committed memory with accurate percentages
- **Disk**: All drives with labels, usage, free space, and real-time activity
- **Network**: Active adapters with status, link speed, and bandwidth
- **GPU**: Graphics card info, driver version, and usage
- **Battery**: Charge level, charging status, estimated runtime
- **Processes**: Top 10 by actual CPU percentage (not cumulative time)
- **System**: Uptime, OS info, temperature sensors

### Comprehensive Diagnostics (Every 30 seconds)
- **Windows Updates**: Pending, failed, and required updates
- **Device Drivers**: Problem devices with specific error codes and descriptions
- **Network Issues**: Connectivity problems, disconnected adapters, DNS failures
- **Disk Health**: Low space warnings, SMART status, physical disk errors
- **Services**: Critical Windows services status and failures
- **Security**: Windows Defender status, outdated virus definitions
- **Performance**: High resource usage, temperature warnings

### Enhanced Event Logs (Every 10 seconds)
- **System Events**: Critical errors, service failures, unexpected shutdowns
- **Application Events**: Crashes, hangs, and errors with application names
- **Security Events**: Failed logins, account lockouts
- **Categorized Logs**: Disk, Network, Driver, Service, WindowsUpdate
- **Priority Levels**: Critical, High, Medium, Low with smart filtering

## Deployment

This application runs on any Linux-based free hosting platform with **Demo Mode** enabled automatically.

### Demo Mode

When deployed on Linux environments (Railway, Render, Vercel, etc.), the application automatically switches to **Demo Mode** which generates realistic random system metrics and event logs for demonstration purposes. This allows the dashboard to run on any platform without requiring Windows PowerShell.

- **Windows Local**: Real PowerShell data collection
- **Linux Cloud**: Demo mode with simulated data

### Deploy Your Own (100% Free - Takes 2 Minutes)

#### Option 1: Render.com (Recommended - Easiest)
1. Visit [render.com](https://render.com) and sign up (free)
2. Click "New +" → "Web Service"
3. Connect your GitHub account
4. Select this repository
5. Render auto-detects settings from `render.yaml`
6. Click "Create Web Service"
7. **Done!** Your URL: `https://win11-monitor.onrender.com` (or similar)

#### Option 2: Railway.app
1. Visit [railway.app](https://railway.app) and sign in with GitHub
2. Click "New Project" → "Deploy from GitHub repo"
3. Select this repository
4. Railway auto-deploys using `railway.json`
5. Click on your deployment to get the URL
6. **Done!** Your URL: `https://win11-monitor-production.up.railway.app`

#### Option 3: Vercel
1. Install Vercel CLI: `npm i -g vercel`
2. Run in this directory: `vercel`
3. Follow prompts (all defaults are fine)
4. **Done!** Your URL: `https://win11-monitor.vercel.app`

All platforms provide:
- ✅ 100% Free forever
- ✅ Automatic HTTPS
- ✅ Global CDN
- ✅ Auto-deploy on git push
- ✅ Permanent URLs

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
- System Diagnostics: 30 seconds
- Chart History: 100 data points

### Diagnostic Categories
The system monitors and reports issues in these categories:
- **WindowsUpdate**: Pending updates, failures, service status
- **Driver**: Device problems with error codes
- **Network**: Connectivity and adapter issues
- **Disk**: Space warnings and health status
- **Service**: Critical Windows services
- **Security**: Defender status and threats
- **Performance**: Resource usage and temperature

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
