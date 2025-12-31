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

    # System Events (ONLY Critical and Errors - NO WARNINGS unless actionable)
    try {
        $systemEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Level = 1,2  # ONLY Critical and Error - removed warnings
        } -MaxEvents ($MaxEvents * 2) -ErrorAction SilentlyContinue

        foreach ($event in $systemEvents) {
            # Skip success messages and informational events
            if ($event.Message -match "success|successfully|completed|started|stopped normally|running") {
                continue
            }

            # Categorize event
            $category = "System"
            $priority = "Normal"

            if ($event.Id -in $criticalEventIds) {
                $priority = "High"
            }

            # Enhanced event categorization with MORE DETAILS
            $detailedInfo = ""

            if ($event.ProviderName -like "*Disk*") {
                $category = "Disk"
                $priority = "High"
                # Extract disk/device name if available
                if ($event.Message -match "device (\\Device\\[^\s]+)") {
                    $detailedInfo = "Device: $($matches[1])"
                }
            } elseif ($event.ProviderName -like "*Ntfs*" -or $event.ProviderName -like "*Storage*") {
                $category = "Storage"
                $priority = "High"
            } elseif ($event.ProviderName -eq "Service Control Manager") {
                $category = "Service"
                $priority = "High"
                # Extract service name
                if ($event.Message -match "The ([^\s]+) service") {
                    $detailedInfo = "Service: $($matches[1])"
                }
            } elseif ($event.ProviderName -like "*Tcpip*" -or $event.ProviderName -like "*Network*") {
                $category = "Network"
                $priority = "High"
            } elseif ($event.ProviderName -eq "Microsoft-Windows-WindowsUpdateClient") {
                $category = "WindowsUpdate"
                $priority = "High"
            } elseif ($event.ProviderName -like "*Driver*") {
                $category = "Driver"
                $priority = "High"
                # Extract driver details
                if ($event.Message -match "driver ([^\s]+)") {
                    $detailedInfo = "Driver: $($matches[1])"
                }
            }

            # Get FULL message with ALL details (no truncation for critical errors)
            $messageText = if ($event.Message) {
                # For critical events, show full message. For others, show more detail
                if ($event.Level -eq 1) {
                    $event.Message  # Full message for critical
                } else {
                    $event.Message.Substring(0, [Math]::Min(1000, $event.Message.Length))  # 1000 chars for errors
                }
            } else {
                "No message available"
            }

            # Extract computer name
            $computerName = if ($event.MachineName) { $event.MachineName } else { $env:COMPUTERNAME }

            # Build detailed event object
            $events += @{
                source = $event.LogName
                category = $category
                level = switch ($event.Level) {
                    1 { "Critical" }
                    2 { "Error" }
                    default { "Unknown" }
                }
                priority = $priority
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                details = $detailedInfo
                computerName = $computerName
                userId = $event.UserId
                processId = $event.ProcessId
                threadId = $event.ThreadId
                timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                timeAgo = (New-TimeSpan -Start $event.TimeCreated -End (Get-Date)).TotalHours
                fullDetails = "Event ID: $($event.Id) | Source: $($event.ProviderName) | Time: $($event.TimeCreated) | Computer: $computerName"
            }
        }
    } catch {
        Write-Error "Failed to collect system events: $_"
    }

    # Application Events (ONLY crashes and errors - NO success messages)
    try {
        $appEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Application'
            Level = 1,2  # ONLY Critical and Error
        } -MaxEvents ($MaxEvents * 2) -ErrorAction SilentlyContinue

        foreach ($event in $appEvents) {
            # Skip success messages
            if ($event.Message -match "success|successfully|completed|started|running") {
                continue
            }

            $category = "Application"
            $priority = "Normal"

            # Prioritize application crashes with DETAILS
            if ($event.Id -in @(1000, 1001, 1002)) {
                $priority = "High"
                $category = "AppCrash"
            } elseif ($event.ProviderName -like "*Error*" -or $event.ProviderName -like "*Crash*") {
                $priority = "High"
            }

            # Get FULL message with ALL crash details (no truncation)
            $messageText = if ($event.Message) {
                $event.Message  # Full message for crash details
            } else {
                "No message available"
            }

            # Extract EVERY detail from crash/error message
            $appName = ""
            $faultModule = ""
            $errorCode = ""
            $appPath = ""
            $appVersion = ""
            $moduleVersion = ""
            $faultOffset = ""

            # Extract application name
            if ($event.Message -match "Faulting application name:\s*([^,\r\n]+)") {
                $appName = $matches[1].Trim()
            } elseif ($event.Message -match "Application Name:\s*(\S+)") {
                $appName = $matches[1]
            }

            # Extract application path
            if ($event.Message -match "Faulting application path:\s*([^\r\n]+)") {
                $appPath = $matches[1].Trim()
            }

            # Extract application version
            if ($event.Message -match "Faulting application version:\s*([^\r\n]+)") {
                $appVersion = $matches[1].Trim()
            }

            # Extract fault module name
            if ($event.Message -match "Faulting module name:\s*([^,\r\n]+)") {
                $faultModule = $matches[1].Trim()
            }

            # Extract module version
            if ($event.Message -match "Faulting module version:\s*([^\r\n]+)") {
                $moduleVersion = $matches[1].Trim()
            }

            # Extract exception code
            if ($event.Message -match "Exception code:\s*(0x[0-9a-fA-F]+)") {
                $errorCode = $matches[1]
            }

            # Extract fault offset
            if ($event.Message -match "Fault offset:\s*(0x[0-9a-fA-F]+)") {
                $faultOffset = $matches[1]
            }

            # Build comprehensive details string
            $crashDetails = ""
            if ($appName) { $crashDetails += "App: $appName | " }
            if ($appPath) { $crashDetails += "Path: $appPath | " }
            if ($appVersion) { $crashDetails += "Version: $appVersion | " }
            if ($faultModule) { $crashDetails += "Fault Module: $faultModule | " }
            if ($moduleVersion) { $crashDetails += "Module Ver: $moduleVersion | " }
            if ($errorCode) { $crashDetails += "Exception: $errorCode | " }
            if ($faultOffset) { $crashDetails += "Offset: $faultOffset" }

            $events += @{
                source = $event.LogName
                category = $category
                level = switch ($event.Level) {
                    1 { "Critical" }
                    2 { "Error" }
                    default { "Unknown" }
                }
                priority = $priority
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                appName = $appName
                appPath = $appPath
                appVersion = $appVersion
                faultModule = $faultModule
                moduleVersion = $moduleVersion
                errorCode = $errorCode
                faultOffset = $faultOffset
                crashDetails = $crashDetails
                timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
                timeAgo = (New-TimeSpan -Start $event.TimeCreated -End (Get-Date)).TotalHours
            }
        }
    } catch {
        Write-Error "Failed to collect application events: $_"
    }

    # Security Events (ONLY actual security problems - failed logins, lockouts)
    try {
        $securityEvents = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'
            Id = 4625,4740,4771,4776  # Failed logon, lockouts, Kerberos failures
        } -MaxEvents 20 -ErrorAction SilentlyContinue

        foreach ($event in $securityEvents) {
            # Extract account name and failure reason
            $accountName = ""
            $failureReason = ""

            if ($event.Message -match "Account Name:\s*([^\r\n]+)") {
                $accountName = $matches[1].Trim()
            }

            if ($event.Message -match "Failure Reason:\s*([^\r\n]+)") {
                $failureReason = $matches[1].Trim()
            }

            $messageText = if ($event.Message) {
                $event.Message
            } else {
                "Security event detected"
            }

            $events += @{
                source = "Security"
                category = "Security"
                level = "Error"
                priority = "High"
                id = $event.Id
                provider = $event.ProviderName
                message = $messageText
                accountName = $accountName
                failureReason = $failureReason
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
