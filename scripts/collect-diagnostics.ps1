# Windows 11 System Diagnostics - Real Issues Detection
# Detects Windows Updates, Driver Problems, Network Issues, Disk Errors, Service Failures

$ErrorActionPreference = "SilentlyContinue"

function Get-SystemDiagnostics {
    $diagnostics = @{
        issues = @()
        warnings = @()
        info = @()
        summary = @{
            critical = 0
            high = 0
            medium = 0
            low = 0
        }
    }

    # 1. Windows Update Status and Problems
    try {
        $updateSession = New-Object -ComObject Microsoft.Update.Session
        $updateSearcher = $updateSession.CreateUpdateSearcher()

        # Check for pending updates
        $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software'")
        if ($searchResult.Updates.Count -gt 0) {
            $diagnostics.issues += @{
                category = "WindowsUpdate"
                severity = "Medium"
                title = "Pending Windows Updates"
                description = "$($searchResult.Updates.Count) update(s) are pending installation"
                recommendation = "Install pending updates to ensure system security and stability"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                count = $searchResult.Updates.Count
            }
            $diagnostics.summary.medium++
        }

        # Check for failed updates
        $failedUpdates = $updateSearcher.Search("IsInstalled=0 and RebootRequired=1")
        if ($failedUpdates.Updates.Count -gt 0) {
            $diagnostics.issues += @{
                category = "WindowsUpdate"
                severity = "High"
                title = "Failed Windows Updates Require Reboot"
                description = "$($failedUpdates.Updates.Count) update(s) failed and require system reboot"
                recommendation = "Restart your computer to complete update installation"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.high++
        }

        # Check Windows Update service status
        $wuService = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        if ($wuService.Status -ne "Running") {
            $diagnostics.warnings += @{
                category = "WindowsUpdate"
                severity = "Medium"
                title = "Windows Update Service Not Running"
                description = "The Windows Update service is $($wuService.Status)"
                recommendation = "Start the Windows Update service: Start-Service wuauserv"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.medium++
        }
    } catch {
        $diagnostics.warnings += @{
            category = "WindowsUpdate"
            severity = "Low"
            title = "Cannot Check Windows Update Status"
            description = $_.Exception.Message
            recommendation = "Verify Windows Update service is accessible"
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $diagnostics.summary.low++
    }

    # 2. Driver Problems Detection
    try {
        # Get devices with problems (Status != OK)
        $problemDevices = Get-CimInstance Win32_PnPEntity | Where-Object {
            $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne $null
        }

        foreach ($device in $problemDevices) {
            $errorDescription = switch ($device.ConfigManagerErrorCode) {
                1 { "Device not configured correctly" }
                3 { "Driver is corrupted" }
                10 { "Device cannot start" }
                12 { "Cannot find enough free resources" }
                18 { "Reinstall drivers for this device" }
                19 { "Registry might be corrupted" }
                21 { "Device is being removed" }
                22 { "Device is disabled" }
                28 { "Drivers not installed" }
                29 { "Device is disabled in firmware" }
                31 { "Device not working properly" }
                32 { "Start type for this driver is disabled" }
                33 { "Cannot determine which resources are required" }
                34 { "Cannot determine settings automatically" }
                35 { "Computer's firmware does not include enough information" }
                36 { "Device requesting PCI interrupt but configured for ISA" }
                37 { "Failed to configure device" }
                38 { "Failed to load driver" }
                39 { "Driver entry point not found" }
                40 { "Driver failed to load" }
                41 { "Driver failed due to missing duplicate device" }
                42 { "System failure (Try changing the driver)" }
                43 { "VxD loader failure" }
                44 { "The device software is blocked from starting" }
                45 { "Device is not connected to computer" }
                46 { "Cannot access device (device preparing to be removed)" }
                47 { "Device is prepared for removal" }
                48 { "Software for this device has been blocked from starting" }
                49 { "Registry is too large" }
                default { "Error code: $($device.ConfigManagerErrorCode)" }
            }

            $diagnostics.issues += @{
                category = "Driver"
                severity = if ($device.ConfigManagerErrorCode -in @(3,10,28,38,40)) { "High" } elseif ($device.ConfigManagerErrorCode -eq 22) { "Low" } else { "Medium" }
                title = "Device Driver Problem: $($device.Name)"
                description = $errorDescription
                recommendation = "Update or reinstall the device driver from Device Manager"
                deviceName = $device.Name
                deviceId = $device.DeviceID
                errorCode = $device.ConfigManagerErrorCode
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            if ($device.ConfigManagerErrorCode -in @(3,10,28,38,40)) {
                $diagnostics.summary.high++
            } elseif ($device.ConfigManagerErrorCode -eq 22) {
                $diagnostics.summary.low++
            } else {
                $diagnostics.summary.medium++
            }
        }
    } catch {
        $diagnostics.warnings += @{
            category = "Driver"
            severity = "Low"
            title = "Cannot Check Device Driver Status"
            description = $_.Exception.Message
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # 3. Network Connectivity Issues
    try {
        # Check network adapters
        $networkAdapters = Get-NetAdapter
        $downAdapters = $networkAdapters | Where-Object { $_.Status -eq 'Disabled' -or $_.Status -eq 'Disconnected' }

        foreach ($adapter in $downAdapters) {
            if ($adapter.Status -eq 'Disconnected') {
                $diagnostics.warnings += @{
                    category = "Network"
                    severity = "Medium"
                    title = "Network Adapter Disconnected: $($adapter.Name)"
                    description = "Network adapter '$($adapter.InterfaceDescription)' is disconnected"
                    recommendation = "Check cable connection or wireless signal"
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.medium++
            }
        }

        # Test internet connectivity
        $internetTest = Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -WarningAction SilentlyContinue
        if (-not $internetTest) {
            $diagnostics.issues += @{
                category = "Network"
                severity = "High"
                title = "No Internet Connectivity"
                description = "Cannot reach external network (DNS: 8.8.8.8)"
                recommendation = "Check router, modem, or network configuration"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.high++
        }

        # Check DNS resolution
        try {
            $dnsTest = Resolve-DnsName "www.google.com" -ErrorAction Stop
        } catch {
            $diagnostics.issues += @{
                category = "Network"
                severity = "Medium"
                title = "DNS Resolution Failed"
                description = "Cannot resolve domain names - DNS may be misconfigured"
                recommendation = "Check DNS settings or try using 8.8.8.8 as DNS server"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.medium++
        }
    } catch {
        $diagnostics.warnings += @{
            category = "Network"
            severity = "Low"
            title = "Cannot Complete Network Diagnostics"
            description = $_.Exception.Message
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # 4. Disk Health and Errors
    try {
        # Check disk space (critical if <10%)
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
        foreach ($disk in $disks) {
            $percentFree = if ($disk.Size -gt 0) { ($disk.FreeSpace / $disk.Size) * 100 } else { 100 }

            if ($percentFree -lt 10) {
                $diagnostics.issues += @{
                    category = "Disk"
                    severity = "Critical"
                    title = "Critical Disk Space: $($disk.DeviceID)"
                    description = "Only $([Math]::Round($percentFree, 1))% free space remaining"
                    recommendation = "Free up disk space immediately - delete unnecessary files or move data"
                    drive = $disk.DeviceID
                    freeGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.critical++
            } elseif ($percentFree -lt 20) {
                $diagnostics.warnings += @{
                    category = "Disk"
                    severity = "Medium"
                    title = "Low Disk Space: $($disk.DeviceID)"
                    description = "Only $([Math]::Round($percentFree, 1))% free space remaining"
                    recommendation = "Consider freeing up disk space"
                    drive = $disk.DeviceID
                    freeGB = [Math]::Round($disk.FreeSpace / 1GB, 2)
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.medium++
            }
        }

        # Check SMART status for physical disks
        $physicalDisks = Get-PhysicalDisk
        foreach ($disk in $physicalDisks) {
            if ($disk.HealthStatus -ne "Healthy") {
                $diagnostics.issues += @{
                    category = "Disk"
                    severity = "Critical"
                    title = "Disk Health Problem: $($disk.FriendlyName)"
                    description = "Physical disk health status is $($disk.HealthStatus)"
                    recommendation = "BACKUP DATA IMMEDIATELY - Disk may be failing"
                    healthStatus = $disk.HealthStatus
                    operationalStatus = $disk.OperationalStatus
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.critical++
            }

            if ($disk.OperationalStatus -ne "OK") {
                $diagnostics.issues += @{
                    category = "Disk"
                    severity = "High"
                    title = "Disk Operational Issue: $($disk.FriendlyName)"
                    description = "Disk operational status is $($disk.OperationalStatus)"
                    recommendation = "Check disk for errors using CHKDSK"
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.high++
            }
        }
    } catch {
        $diagnostics.warnings += @{
            category = "Disk"
            severity = "Low"
            title = "Cannot Complete Disk Health Check"
            description = $_.Exception.Message
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # 5. Critical Windows Services Status
    $criticalServices = @(
        "wuauserv",      # Windows Update
        "Dnscache",      # DNS Client
        "Dhcp",          # DHCP Client
        "EventLog",      # Windows Event Log
        "RpcSs",         # Remote Procedure Call
        "LanmanServer",  # Server (File and Printer Sharing)
        "LanmanWorkstation", # Workstation
        "Spooler",       # Print Spooler
        "Winmgmt"        # Windows Management Instrumentation
    )

    foreach ($serviceName in $criticalServices) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -ne "Running" -and $service.StartType -ne "Disabled") {
                $diagnostics.issues += @{
                    category = "Service"
                    severity = "High"
                    title = "Critical Service Not Running: $($service.DisplayName)"
                    description = "Service '$($service.DisplayName)' is $($service.Status)"
                    recommendation = "Start the service: Start-Service $serviceName"
                    serviceName = $serviceName
                    status = $service.Status
                    startType = $service.StartType
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.high++
            }
        }
    }

    # 6. System Performance Issues
    try {
        # Check CPU temperature if available
        $temp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($temp) {
            $celsius = ($temp.CurrentTemperature / 10) - 273.15
            if ($celsius -gt 85) {
                $diagnostics.issues += @{
                    category = "Performance"
                    severity = "Critical"
                    title = "CPU Temperature Critical"
                    description = "CPU temperature is $([Math]::Round($celsius, 1))°C"
                    recommendation = "Shutdown and check cooling system immediately"
                    temperature = [Math]::Round($celsius, 1)
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.critical++
            } elseif ($celsius -gt 75) {
                $diagnostics.warnings += @{
                    category = "Performance"
                    severity = "High"
                    title = "CPU Temperature High"
                    description = "CPU temperature is $([Math]::Round($celsius, 1))°C"
                    recommendation = "Check system cooling and clean dust from vents"
                    temperature = [Math]::Round($celsius, 1)
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.high++
            }
        }

        # Check memory pressure
        $os = Get-CimInstance Win32_OperatingSystem
        $totalMemory = $os.TotalVisibleMemorySize
        $freeMemory = $os.FreePhysicalMemory
        $memoryUsedPercent = (($totalMemory - $freeMemory) / $totalMemory) * 100

        if ($memoryUsedPercent -gt 95) {
            $diagnostics.issues += @{
                category = "Performance"
                severity = "High"
                title = "Critical Memory Usage"
                description = "Memory usage is $([Math]::Round($memoryUsedPercent, 1))%"
                recommendation = "Close unnecessary applications or add more RAM"
                memoryPercent = [Math]::Round($memoryUsedPercent, 1)
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.high++
        } elseif ($memoryUsedPercent -gt 85) {
            $diagnostics.warnings += @{
                category = "Performance"
                severity = "Medium"
                title = "High Memory Usage"
                description = "Memory usage is $([Math]::Round($memoryUsedPercent, 1))%"
                recommendation = "Consider closing some applications"
                memoryPercent = [Math]::Round($memoryUsedPercent, 1)
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.medium++
        }
    } catch {}

    # 7. Security Status
    try {
        # Check Windows Defender status
        $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($defenderStatus) {
            if (-not $defenderStatus.AntivirusEnabled) {
                $diagnostics.issues += @{
                    category = "Security"
                    severity = "Critical"
                    title = "Windows Defender Disabled"
                    description = "Real-time protection is turned off"
                    recommendation = "Enable Windows Defender real-time protection immediately"
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.critical++
            }

            if ($defenderStatus.AntivirusSignatureAge -gt 7) {
                $diagnostics.warnings += @{
                    category = "Security"
                    severity = "Medium"
                    title = "Outdated Antivirus Signatures"
                    description = "Virus definitions are $($defenderStatus.AntivirusSignatureAge) days old"
                    recommendation = "Update Windows Defender definitions"
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.medium++
            }
        }
    } catch {}

    # Add timestamp to diagnostics
    $diagnostics.timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $diagnostics.totalIssues = $diagnostics.issues.Count + $diagnostics.warnings.Count

    return $diagnostics
}

# Main execution
try {
    $data = Get-SystemDiagnostics
    $json = $data | ConvertTo-Json -Depth 10 -Compress

    # Save to file
    $dataPath = Join-Path $PSScriptRoot "..\data\diagnostics.json"
    $parentDir = Split-Path $dataPath -Parent
    if (-not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }
    $json | Out-File -FilePath $dataPath -Encoding UTF8 -Force

    # Output to console
    Write-Output $json

} catch {
    $errorData = @{
        error = $_.Exception.Message
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        issues = @()
        warnings = @()
        summary = @{ critical = 0; high = 0; medium = 0; low = 0 }
    }
    $errorData | ConvertTo-Json -Compress
}
