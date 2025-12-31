# Windows 11 Enhanced System Metrics Collector
# Collects accurate CPU, RAM, Disk, Network, GPU, Battery, and Process data

$ErrorActionPreference = "SilentlyContinue"

function Get-SystemMetrics {
    $metrics = @{}

    # CPU Usage - Take multiple samples for accuracy
    $cpuSamples = @()
    for ($i = 0; $i -lt 3; $i++) {
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        if ($cpuCounter) {
            $cpuSamples += $cpuCounter.CounterSamples[0].CookedValue
        }
        Start-Sleep -Milliseconds 300
    }
    $avgCpu = if ($cpuSamples.Count -gt 0) { ($cpuSamples | Measure-Object -Average).Average } else { 0 }
    $metrics.cpu = [Math]::Round($avgCpu, 2)

    # CPU Details
    $cpuInfo = Get-CimInstance Win32_Processor
    $metrics.cpuInfo = @{
        name = $cpuInfo.Name
        cores = $cpuInfo.NumberOfCores
        logicalProcessors = $cpuInfo.NumberOfLogicalProcessors
        maxClockSpeed = $cpuInfo.MaxClockSpeed
        currentClockSpeed = $cpuInfo.CurrentClockSpeed
    }

    # Memory Usage - More accurate calculation
    $os = Get-CimInstance Win32_OperatingSystem
    $computerSystem = Get-CimInstance Win32_ComputerSystem
    $totalMemory = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
    $freeMemory = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemory = [Math]::Round($totalMemory - $freeMemory, 2)
    $memoryPercent = if ($totalMemory -gt 0) { [Math]::Round(($usedMemory / $totalMemory) * 100, 2) } else { 0 }

    # Get committed memory
    $committedBytes = (Get-Counter '\Memory\Committed Bytes' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    $committedGB = [Math]::Round($committedBytes / 1GB, 2)

    # Get available memory
    $availableBytes = (Get-Counter '\Memory\Available Bytes' -ErrorAction SilentlyContinue).CounterSamples[0].CookedValue
    $availableGB = [Math]::Round($availableBytes / 1GB, 2)

    $metrics.memory = @{
        total = $totalMemory
        used = $usedMemory
        free = $freeMemory
        available = $availableGB
        committed = $committedGB
        percent = $memoryPercent
    }

    # Disk Usage with health status
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,
        @{Name="TotalGB";Expression={[Math]::Round($_.Size / 1GB, 2)}},
        @{Name="FreeGB";Expression={[Math]::Round($_.FreeSpace / 1GB, 2)}},
        @{Name="UsedGB";Expression={[Math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)}},
        @{Name="PercentUsed";Expression={if ($_.Size -gt 0) { [Math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2) } else { 0 }}},
        VolumeName

    $metrics.disks = @($disks | ForEach-Object {
        $diskPerf = Get-Counter "\LogicalDisk($($_.DeviceID -replace ':',''))\% Disk Time" -ErrorAction SilentlyContinue
        $diskActivity = if ($diskPerf) { [Math]::Round($diskPerf.CounterSamples[0].CookedValue, 2) } else { 0 }

        @{
            drive = $_.DeviceID
            label = if ($_.VolumeName) { $_.VolumeName } else { "Local Disk" }
            total = $_.TotalGB
            used = $_.UsedGB
            free = $_.FreeGB
            percent = $_.PercentUsed
            activity = $diskActivity
        }
    })

    # Network Usage with adapter status
    $netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    $metrics.network = @($netAdapters | ForEach-Object {
        $stats = Get-NetAdapterStatistics -Name $_.Name -ErrorAction SilentlyContinue
        $linkSpeed = if ($_.LinkSpeed -match '(\d+(?:\.\d+)?)\s*([MG])bps') {
            $speed = [double]$matches[1]
            $unit = $matches[2]
            if ($unit -eq 'G') { $speed * 1000 } else { $speed }
        } else { 0 }

        @{
            name = $_.Name
            status = $_.Status
            linkSpeed = $linkSpeed
            sentMB = if ($stats) { [Math]::Round($stats.SentBytes / 1MB, 2) } else { 0 }
            receivedMB = if ($stats) { [Math]::Round($stats.ReceivedBytes / 1MB, 2) } else { 0 }
            interfaceDescription = $_.InterfaceDescription
        }
    })

    # GPU Information (if available)
    try {
        $gpuInfo = Get-CimInstance Win32_VideoController | Select-Object -First 1
        if ($gpuInfo) {
            # Try to get GPU usage via performance counter
            $gpuUsage = 0
            try {
                $gpuCounter = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue
                if ($gpuCounter) {
                    $gpuUsage = [Math]::Round(($gpuCounter.CounterSamples | Measure-Object -Property CookedValue -Sum).Sum, 2)
                }
            } catch {}

            $metrics.gpu = @{
                name = $gpuInfo.Name
                driverVersion = $gpuInfo.DriverVersion
                videoMemoryMB = if ($gpuInfo.AdapterRAM) { [Math]::Round($gpuInfo.AdapterRAM / 1MB, 2) } else { 0 }
                usage = $gpuUsage
            }
        }
    } catch {}

    # Battery Status (for laptops)
    try {
        $battery = Get-CimInstance Win32_Battery
        if ($battery) {
            $metrics.battery = @{
                status = $battery.BatteryStatus
                percentage = $battery.EstimatedChargeRemaining
                estimatedRunTime = $battery.EstimatedRunTime
                isCharging = ($battery.BatteryStatus -eq 2)
            }
        }
    } catch {}

    # Top Processes by CPU - Calculate actual CPU percentage
    $processCounter = Get-Counter '\Process(*)\% Processor Time' -ErrorAction SilentlyContinue
    $processList = @{}
    if ($processCounter) {
        foreach ($sample in $processCounter.CounterSamples) {
            $processName = $sample.InstanceName
            if ($processName -ne '_total' -and $processName -ne 'idle') {
                $processList[$processName] = [Math]::Round($sample.CookedValue / $metrics.cpuInfo.logicalProcessors, 2)
            }
        }
    }

    $topProcesses = Get-Process | Where-Object { $_.Id -ne 0 } |
        Select-Object -First 15 Name, Id,
            @{Name="WorkingSetMB";Expression={[Math]::Round($_.WorkingSet64 / 1MB, 2)}} |
        ForEach-Object {
            $cpuPercent = if ($processList.ContainsKey($_.Name)) { $processList[$_.Name] } else { 0 }
            @{
                name = $_.Name
                cpu = $cpuPercent
                memory = $_.WorkingSetMB
                pid = $_.Id
            }
        } | Sort-Object { $_.cpu } -Descending | Select-Object -First 10

    $metrics.processes = @($topProcesses)

    # System Uptime
    $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    $metrics.uptime = @{
        days = $uptime.Days
        hours = $uptime.Hours
        minutes = $uptime.Minutes
        totalSeconds = [Math]::Round($uptime.TotalSeconds, 0)
    }

    # System Temperature (if available via WMI)
    try {
        $temp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($temp) {
            $celsius = [Math]::Round(($temp.CurrentTemperature / 10) - 273.15, 1)
            $metrics.temperature = @{
                celsius = $celsius
                fahrenheit = [Math]::Round(($celsius * 9/5) + 32, 1)
            }
        }
    } catch {}

    # Timestamp
    $metrics.timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    return $metrics
}

# Main execution
try {
    $data = Get-SystemMetrics
    $json = $data | ConvertTo-Json -Depth 10 -Compress

    # Save to file
    $dataPath = Join-Path $PSScriptRoot "..\data\current-metrics.json"
    $json | Out-File -FilePath $dataPath -Encoding UTF8 -Force

    # Output to console for API consumption
    Write-Output $json

} catch {
    $errorData = @{
        error = $_.Exception.Message
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $errorData | ConvertTo-Json -Compress
}
