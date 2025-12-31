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

    # 2. Driver Problems Detection with DETAILED information
    try {
        # Get devices with problems (Status != OK)
        $problemDevices = Get-CimInstance Win32_PnPEntity | Where-Object {
            $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne $null
        }

        foreach ($device in $problemDevices) {
            $errorDescription = switch ($device.ConfigManagerErrorCode) {
                1 { "Device not configured correctly" }
                3 { "Driver is corrupted or incompatible" }
                10 { "Device cannot start - driver issue" }
                12 { "Cannot find enough free resources for device" }
                18 { "Reinstall drivers for this device" }
                19 { "Windows registry might be corrupted" }
                21 { "Device is being removed" }
                22 { "Device is disabled by user" }
                28 { "Drivers are not installed for this device" }
                29 { "Device is disabled in BIOS/UEFI firmware" }
                31 { "Device not working properly - driver error" }
                32 { "Start type for this driver is disabled" }
                33 { "Cannot determine which resources are required" }
                34 { "Cannot determine settings automatically" }
                35 { "Computer's firmware does not include enough information" }
                36 { "Device requesting PCI interrupt but configured for ISA" }
                37 { "Failed to configure device" }
                38 { "Failed to load driver - driver file missing or corrupt" }
                39 { "Driver entry point not found" }
                40 { "Driver failed to load - incompatible or corrupted" }
                41 { "Driver failed due to missing duplicate device" }
                42 { "System failure - driver incompatible with Windows version" }
                43 { "VxD loader failure" }
                44 { "The device software is blocked from starting by Group Policy" }
                45 { "Device is not connected to computer" }
                46 { "Cannot access device (preparing to be removed)" }
                47 { "Device is prepared for removal" }
                48 { "Software for this device has been blocked from starting" }
                49 { "Registry is too large - cleanup required" }
                default { "Unknown error code: $($device.ConfigManagerErrorCode)" }
            }

            # Get driver details
            $driverInfo = ""
            try {
                $driver = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceID -eq $device.DeviceID }
                if ($driver) {
                    $driverInfo = "Driver: $($driver.DriverName) v$($driver.DriverVersion), Manufacturer: $($driver.Manufacturer)"
                }
            } catch {}

            # Detailed recommendation based on error code
            $fixRecommendation = switch ($device.ConfigManagerErrorCode) {
                3 { "1. Open Device Manager → 2. Right-click device → 3. Update Driver → 4. If fails, Uninstall Device → 5. Scan for hardware changes" }
                10 { "1. Open Device Manager → 2. Right-click '$($device.Name)' → 3. Update Driver → 4. Download latest driver from manufacturer's website" }
                22 { "1. Open Device Manager → 2. Find '$($device.Name)' → 3. Right-click → 4. Enable Device" }
                28 { "1. Download driver from manufacturer → 2. Open Device Manager → 3. Right-click device → 4. Update Driver → 5. Browse to downloaded driver" }
                29 { "1. Restart computer → 2. Enter BIOS/UEFI (press Del/F2 during startup) → 3. Find and enable this device → 4. Save and exit" }
                38 { "Driver file corrupt or missing. 1. Download fresh driver from manufacturer → 2. Uninstall device → 3. Install new driver" }
                40 { "1. Check Windows version compatibility → 2. Download compatible driver → 3. Run as Administrator to install" }
                default { "1. Open Device Manager (Win+X → Device Manager) → 2. Locate '$($device.Name)' → 3. Right-click → Update Driver or Uninstall Device → 4. Restart computer" }
            }

            $diagnostics.issues += @{
                category = "Driver"
                severity = if ($device.ConfigManagerErrorCode -in @(3,10,28,38,40)) { "High" } elseif ($device.ConfigManagerErrorCode -eq 22) { "Low" } else { "Medium" }
                title = "Driver Error Code $($device.ConfigManagerErrorCode): $($device.Name)"
                description = "$errorDescription | $driverInfo | Hardware ID: $($device.DeviceID)"
                recommendation = $fixRecommendation
                deviceName = $device.Name
                deviceId = $device.DeviceID
                errorCode = $device.ConfigManagerErrorCode
                driverDetails = $driverInfo
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

    # 3. COMPREHENSIVE Network Diagnostics - Find EVERY network problem
    try {
        # Check ALL network adapters (not just disconnected ones)
        $allNetworkAdapters = Get-NetAdapter -ErrorAction SilentlyContinue

        foreach ($adapter in $allNetworkAdapters) {
            # Check disabled adapters
            if ($adapter.Status -eq 'Disabled') {
                $diagnostics.warnings += @{
                    category = "Network"
                    severity = "Low"
                    title = "Network Adapter Disabled: $($adapter.Name)"
                    description = "Adapter '$($adapter.InterfaceDescription)' is manually disabled"
                    recommendation = "Enable in Network Connections: 1. Win+R → ncpa.cpl → 2. Right-click '$($adapter.Name)' → 3. Enable"
                    adapterName = $adapter.Name
                    adapterDescription = $adapter.InterfaceDescription
                    status = $adapter.Status
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.low++
            }

            # Check disconnected adapters (cable unplugged or no WiFi)
            if ($adapter.Status -eq 'Disconnected' -or $adapter.Status -eq 'Not Present') {
                $diagnostics.issues += @{
                    category = "Network"
                    severity = "Medium"
                    title = "Network Adapter Disconnected: $($adapter.Name)"
                    description = "Status: $($adapter.Status) | Interface: $($adapter.InterfaceDescription) | Media Type: $($adapter.MediaType)"
                    recommendation = if ($adapter.MediaType -match "802.11") {
                        "WiFi not connected. 1. Click WiFi icon in taskbar → 2. Select network → 3. Enter password"
                    } else {
                        "Ethernet cable unplugged. 1. Check cable connection → 2. Try different cable → 3. Check router port"
                    }
                    adapterName = $adapter.Name
                    mediaType = $adapter.MediaType
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.medium++
            }

            # Check for adapter errors
            if ($adapter.Status -eq 'Up') {
                $adapterStats = Get-NetAdapterStatistics -Name $adapter.Name -ErrorAction SilentlyContinue
                if ($adapterStats) {
                    # Check for errors
                    if ($adapterStats.ReceivedUnicastPackets -gt 0) {
                        $errorRate = ($adapterStats.ReceivedPacketErrors / $adapterStats.ReceivedUnicastPackets) * 100
                        if ($errorRate -gt 5) {
                            $diagnostics.issues += @{
                                category = "Network"
                                severity = "High"
                                title = "High Network Error Rate: $($adapter.Name)"
                                description = "Packet error rate: $([Math]::Round($errorRate, 2))% | Errors: $($adapterStats.ReceivedPacketErrors) | Total: $($adapterStats.ReceivedUnicastPackets)"
                                recommendation = "1. Check network cable quality → 2. Update network adapter driver → 3. Check router/switch for problems"
                                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                            }
                            $diagnostics.summary.high++
                        }
                    }
                }
            }
        }

        # Check IP Configuration Issues
        $ipConfigs = Get-NetIPConfiguration -ErrorAction SilentlyContinue
        foreach ($config in $ipConfigs) {
            if ($config.NetAdapter.Status -eq 'Up') {
                # Check for APIPA address (169.254.x.x means DHCP failed)
                $ipv4 = $config.IPv4Address.IPAddress
                if ($ipv4 -match "^169\.254\.") {
                    $diagnostics.issues += @{
                        category = "Network"
                        severity = "High"
                        title = "DHCP Failure - APIPA Address: $($config.InterfaceAlias)"
                        description = "IP Address: $ipv4 (Auto-assigned, not from DHCP server) | This means the computer cannot get an IP from the router"
                        recommendation = "1. Check router is on and working → 2. Restart router → 3. Run: ipconfig /release then ipconfig /renew → 4. Check router DHCP settings"
                        ipAddress = $ipv4
                        interfaceName = $config.InterfaceAlias
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $diagnostics.summary.high++
                }

                # Check for no default gateway (means can't reach internet)
                if (-not $config.IPv4DefaultGateway) {
                    $diagnostics.issues += @{
                        category = "Network"
                        severity = "High"
                        title = "No Default Gateway: $($config.InterfaceAlias)"
                        description = "No gateway configured - cannot reach internet or other networks | Current IP: $ipv4"
                        recommendation = "1. Check router connection → 2. Run: ipconfig /release then ipconfig /renew → 3. Manually set gateway in adapter properties"
                        interfaceName = $config.InterfaceAlias
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $diagnostics.summary.high++
                } else {
                    # Test gateway reachability
                    $gateway = $config.IPv4DefaultGateway.NextHop
                    $pingGateway = Test-Connection -ComputerName $gateway -Count 2 -Quiet -ErrorAction SilentlyContinue
                    if (-not $pingGateway) {
                        $diagnostics.issues += @{
                            category = "Network"
                            severity = "Critical"
                            title = "Cannot Reach Gateway: $gateway"
                            description = "Gateway at $gateway is unreachable | Interface: $($config.InterfaceAlias) | This means router is not responding"
                            recommendation = "1. Check router is powered on → 2. Check cable connection → 3. Restart router → 4. Check router lights"
                            gateway = $gateway
                            interfaceName = $config.InterfaceAlias
                            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                        $diagnostics.summary.critical++
                    }
                }

                # Check DNS servers
                $dnsServers = $config.DNSServer.ServerAddresses
                if ($dnsServers.Count -eq 0) {
                    $diagnostics.issues += @{
                        category = "Network"
                        severity = "High"
                        title = "No DNS Servers Configured: $($config.InterfaceAlias)"
                        description = "Cannot resolve domain names without DNS | You won't be able to browse websites"
                        recommendation = "Set DNS servers: 1. Control Panel → Network → Change adapter → Properties → IPv4 → Use: 8.8.8.8 and 8.8.4.4"
                        interfaceName = $config.InterfaceAlias
                        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $diagnostics.summary.high++
                }
            }
        }

        # Test Internet Connectivity (multiple methods)
        $internetTest = Test-NetConnection -ComputerName "8.8.8.8" -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        if (-not $internetTest) {
            $diagnostics.issues += @{
                category = "Network"
                severity = "Critical"
                title = "No Internet Connectivity"
                description = "Cannot reach Google DNS (8.8.8.8) - No internet access | Ping test failed"
                recommendation = "1. Check WiFi/Ethernet connected → 2. Restart router and modem → 3. Check if other devices have internet → 4. Contact ISP if problem persists"
                timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $diagnostics.summary.critical++
        } else {
            # Internet works but test DNS resolution
            try {
                $dnsTest = Resolve-DnsName "www.google.com" -ErrorAction Stop
            } catch {
                $diagnostics.issues += @{
                    category = "Network"
                    severity = "High"
                    title = "DNS Resolution Failed"
                    description = "Can ping 8.8.8.8 but cannot resolve www.google.com | DNS Error: $($_.Exception.Message)"
                    recommendation = "1. Change DNS to 8.8.8.8 and 8.8.4.4 → 2. Flush DNS: ipconfig /flushdns → 3. Check router DNS settings"
                    errorDetails = $_.Exception.Message
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.high++
            }
        }

        # Check for duplicate IP addresses
        $ipConflict = Get-NetIPAddress -ErrorAction SilentlyContinue | Group-Object -Property IPAddress | Where-Object { $_.Count -gt 1 }
        if ($ipConflict) {
            foreach ($conflict in $ipConflict) {
                $diagnostics.issues += @{
                    category = "Network"
                    severity = "High"
                    title = "IP Address Conflict Detected"
                    description = "IP $($conflict.Name) is assigned to multiple adapters | This causes network problems"
                    recommendation = "1. Release and renew IP: ipconfig /release then ipconfig /renew → 2. Use different IP → 3. Check for IP reservation in router"
                    ipAddress = $conflict.Name
                    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $diagnostics.summary.high++
            }
        }

        # Check WiFi signal strength (if WiFi is active)
        $wifiAdapters = Get-NetAdapter | Where-Object { $_.MediaType -match "802.11" -and $_.Status -eq "Up" }
        foreach ($wifi in $wifiAdapters) {
            try {
                $wifiInfo = netsh wlan show interfaces | Select-String "Signal"
                if ($wifiInfo -match "(\d+)%") {
                    $signalStrength = [int]$matches[1]
                    if ($signalStrength -lt 30) {
                        $diagnostics.warnings += @{
                            category = "Network"
                            severity = "Medium"
                            title = "Weak WiFi Signal: $($wifi.Name)"
                            description = "Signal strength: $signalStrength% - Very weak signal causes slow speeds and disconnections"
                            recommendation = "1. Move closer to router → 2. Remove obstacles between computer and router → 3. Check for interference → 4. Consider WiFi extender"
                            signalStrength = $signalStrength
                            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        }
                        $diagnostics.summary.medium++
                    }
                }
            } catch {}
        }

    } catch {
        $diagnostics.warnings += @{
            category = "Network"
            severity = "Low"
            title = "Cannot Complete Network Diagnostics"
            description = "Error: $($_.Exception.Message)"
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
