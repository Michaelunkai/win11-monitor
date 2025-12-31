# Windows Enhanced Event Log Collector
# Collects actionable errors and critical system events

$ErrorActionPreference = "SilentlyContinue"

function Get-RecentEvents {
    param(
        [int]$MaxEvents = 50
    )

    $events = @()

    # Critical Event IDs to prioritize
    $criticalEventIds = @(
        # System Critical Events
        41,    # Kernel-Power: System rebooted without cleanly shutting down
        6008,  # EventLog: Unexpected shutdown
        7000,  # Service Control Manager: Service failed to start
        7001,  # Service Control Manager: Service depends on failed service
        7022,  # Service hung on starting
        7023,  # Service terminated with error
        7024,  # Service terminated with service-specific error
        7026,  # Boot-start or system-start driver failed to load
        7031,  # Service crashed
        7034,  # Service terminated unexpectedly
        10016, # DCOM errors
        10010, # DCOM server didn't register

        # Disk Errors
        7,     # Bad block on device
        11,    # Driver detected controller error
        15,    # Device not ready
        51,    # Disk error during paging operation
        52,    # Mounted file system recovery
        55,    # File system structure corruption

        # Application Errors
        1000,  # Application Error
        1001,  # Application Hang (WER)
        1002,  # Application Error (WER)

        # Windows Update Errors
        20,    # Installation Failure
        24,    # Failed to download update
        25,    # Failed to install update

        # Network Errors
        4201,  # Network adapter disabled
        4202   # Network adapter disconnected
    )

    # System Events (Critical and Errors with priority to known issues)
    try {
        $systemEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Level = 1,2,3
        } -MaxEvents ($MaxEvents * 2) -ErrorAction SilentlyContinue

        foreach ($event in $systemEvents) {
            # Categorize event
            $category = "System"
            $priority = "Normal"

            if ($event.Id -in $criticalEventIds) {
                $priority = "High"
            }

            # Enhanced event categorization
            if ($event.ProviderName -like "*Disk*") {
                $category = "Disk"
                $priority = "High"
            } elseif ($event.ProviderName -like "*Ntfs*" -or $event.ProviderName -like "*Storage*") {
                $category = "Storage"
            } elseif ($event.ProviderName -eq "Service Control Manager") {
                $category = "Service"
            } elseif ($event.ProviderName -like "*Tcpip*" -or $event.ProviderName -like "*Network*") {
                $category = "Network"
            } elseif ($event.ProviderName -eq "Microsoft-Windows-WindowsUpdateClient") {
                $category = "WindowsUpdate"
                $priority = "High"
            } elseif ($event.ProviderName -like "*Driver*") {
                $category = "Driver"
                $priority = "High"
            }

            $messageText = if ($event.Message) {
                $event.Message.Substring(0, [Math]::Min(300, $event.Message.Length))
            } else {
                "No message available"
            }

            $events += @{
                source = $event.LogName
                category = $category
                level = switch ($event.Level) {
                    1 { "Critical" }
                    2 { "Error" }
                    3 { "Warning" }
                    4 { "Information" }
                    default { "Unknown" }
                }
                priority = $priority
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                timeAgo = (New-TimeSpan -Start $event.TimeCreated -End (Get-Date)).TotalHours
            }
        }
    } catch {
        Write-Error "Failed to collect system events: $_"
    }

    # Application Events (Focus on crashes and errors)
    try {
        $appEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            Level = 1,2,3
        } -MaxEvents ($MaxEvents * 2) -ErrorAction SilentlyContinue

        foreach ($event in $appEvents) {
            $category = "Application"
            $priority = "Normal"

            # Prioritize application crashes
            if ($event.Id -in @(1000, 1001, 1002)) {
                $priority = "High"
                $category = "AppCrash"
            } elseif ($event.ProviderName -like "*Error*" -or $event.ProviderName -like "*Crash*") {
                $priority = "High"
            }

            $messageText = if ($event.Message) {
                $event.Message.Substring(0, [Math]::Min(300, $event.Message.Length))
            } else {
                "No message available"
            }

            # Extract application name from crash events
            $appName = ""
            if ($event.Id -in @(1000, 1001, 1002) -and $event.Message -match "Application Name:\s*(\S+)") {
                $appName = $matches[1]
            }

            $events += @{
                source = $event.LogName
                category = $category
                level = switch ($event.Level) {
                    1 { "Critical" }
                    2 { "Error" }
                    3 { "Warning" }
                    4 { "Information" }
                    default { "Unknown" }
                }
                priority = $priority
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                appName = $appName
                timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                timeAgo = (New-TimeSpan -Start $event.TimeCreated -End (Get-Date)).TotalHours
            }
        }
    } catch {
        Write-Error "Failed to collect application events: $_"
    }

    # Security Events (Failed logins, policy changes)
    try {
        $securityEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4625,4740,4771  # Failed logon attempts, account lockouts
        } -MaxEvents 20 -ErrorAction SilentlyContinue

        foreach ($event in $securityEvents) {
            $messageText = if ($event.Message) {
                $event.Message.Substring(0, [Math]::Min(300, $event.Message.Length))
            } else {
                "Security event detected"
            }

            $events += @{
                source = "Security"
                category = "Security"
                level = "Warning"
                priority = "High"
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                timeAgo = (New-TimeSpan -Start $event.TimeCreated -End (Get-Date)).TotalHours
            }
        }
    } catch {}

    # Sort by priority and timestamp
    $sortedEvents = $events | Sort-Object @{Expression={$_.priority -eq "High"}; Descending=$true},
                                          @{Expression={[DateTime]$_.timestamp}; Descending=$true} |
                              Select-Object -First $MaxEvents

    return $sortedEvents
}

# Main execution
try {
    $eventData = @{
        events = @(Get-RecentEvents -MaxEvents 30)
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        count = 0
    }

    $eventData.count = $eventData.events.Count

    $json = $eventData | ConvertTo-Json -Depth 10 -Compress

    # Save to file
    $dataPath = Join-Path $PSScriptRoot "..\data\event-logs.json"
    $json | Out-File -FilePath $dataPath -Encoding UTF8 -Force

    # Output to console
    Write-Output $json

} catch {
    $errorData = @{
        error = $_.Exception.Message
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        events = @()
        count = 0
    }
    $errorData | ConvertTo-Json -Compress
}
