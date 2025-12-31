# Windows Event Log Collector
# Collects recent system, application, and security events

$ErrorActionPreference = "SilentlyContinue"

function Get-RecentEvents {
    param(
        [int]$MaxEvents = 50
    )

    $events = @()

    # System Events (Errors and Warnings)
    $systemEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Level = 2,3
    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue

    foreach ($event in $systemEvents) {
        $events += @{
            source = "System"
            level = switch ($event.Level) {
                1 { "Critical" }
                2 { "Error" }
                3 { "Warning" }
                4 { "Information" }
                default { "Unknown" }
            }
            id = $event.Id
            message = $event.Message.Substring(0, [Math]::Min(200, $event.Message.Length))
            timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    # Application Events (Errors)
    $appEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'Application'
        Level = 2,3
    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue

    foreach ($event in $appEvents) {
        $events += @{
            source = "Application"
            level = switch ($event.Level) {
                1 { "Critical" }
                2 { "Error" }
                3 { "Warning" }
                4 { "Information" }
                default { "Unknown" }
            }
            id = $event.Id
            message = $event.Message.Substring(0, [Math]::Min(200, $event.Message.Length))
            timestamp = $event.TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        }
    }

    return $events | Sort-Object { [DateTime]$_.timestamp } -Descending | Select-Object -First $MaxEvents
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
