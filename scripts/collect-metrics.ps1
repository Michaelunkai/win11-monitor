# Windows 11 System Metrics Collector
# Collects CPU, RAM, Disk, Network, and Process data

$ErrorActionPreference = "SilentlyContinue"

function Get-SystemMetrics {
    $metrics = @{}

    # CPU Usage
    $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
    $metrics.cpu = [Math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)

    # Memory Usage
    $os = Get-CimInstance Win32_OperatingSystem
    $totalMemory = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemory = [Math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemory = [Math]::Round($totalMemory - $freeMemory, 2)
    $memoryPercent = [Math]::Round(($usedMemory / $totalMemory) * 100, 2)

    $metrics.memory = @{
        total = $totalMemory
        used = $usedMemory
        free = $freeMemory
        percent = $memoryPercent
    }

    # Disk Usage
    $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,
        @{Name="TotalGB";Expression={[Math]::Round($_.Size / 1GB, 2)}},
        @{Name="FreeGB";Expression={[Math]::Round($_.FreeSpace / 1GB, 2)}},
        @{Name="UsedGB";Expression={[Math]::Round(($_.Size - $_.FreeSpace) / 1GB, 2)}},
        @{Name="PercentUsed";Expression={[Math]::Round((($_.Size - $_.FreeSpace) / $_.Size) * 100, 2)}}

    $metrics.disks = @($disks | ForEach-Object {
        @{
            drive = $_.DeviceID
            total = $_.TotalGB
            used = $_.UsedGB
            free = $_.FreeGB
            percent = $_.PercentUsed
        }
    })

    # Network Usage
    $netAdapters = Get-NetAdapterStatistics | Where-Object { $_.ReceivedBytes -gt 0 }
    $metrics.network = @($netAdapters | ForEach-Object {
        @{
            name = $_.Name
            sentMB = [Math]::Round($_.SentBytes / 1MB, 2)
            receivedMB = [Math]::Round($_.ReceivedBytes / 1MB, 2)
        }
    })

    # Top Processes by CPU
    $topProcesses = Get-Process | Where-Object { $_.CPU -gt 0 } |
        Sort-Object CPU -Descending |
        Select-Object -First 10 Name,
            @{Name="CPUTime";Expression={[Math]::Round($_.CPU, 2)}},
            @{Name="MemoryMB";Expression={[Math]::Round($_.WorkingSet64 / 1MB, 2)}},
            Id

    $metrics.processes = @($topProcesses | ForEach-Object {
        @{
            name = $_.Name
            cpu = $_.CPUTime
            memory = $_.MemoryMB
            pid = $_.Id
        }
    })

    # System Uptime
    $bootTime = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptime = (Get-Date) - $bootTime
    $metrics.uptime = @{
        days = $uptime.Days
        hours = $uptime.Hours
        minutes = $uptime.Minutes
    }

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
