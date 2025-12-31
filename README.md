# Windows 11 System Monitor

A real-time web-based monitoring dashboard for Windows 11 systems with live metrics, event logs, and system statistics.

## 🚀 Live Demo & Deployment

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
