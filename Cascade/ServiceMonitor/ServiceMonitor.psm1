function Send-AdminNotification {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$AdminEmail
    )
    
    try {
        Send-MailMessage -To $AdminEmail -Subject $Subject -Body $Message -SmtpServer $SmtpServer -From $FromEmail -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to send notification: $_"
    }
}

function Test-ServiceStatus {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    try {
        $service = Get-Service -ComputerName $ComputerName -Name $ServiceName -ErrorAction Stop
        return $service.Status
    }
    catch {
        Write-Error "Failed to get service status: $_"
        return $null
    }
}

function Restart-MonitoredService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    try {
        Restart-Service -ComputerName $ComputerName -Name $ServiceName -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Failed to restart service: $_"
        return $false
    }
}

function Watch-ServiceStatus {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$ComputerNames,
        [Parameter(Mandatory = $true)]
        [string[]]$ServiceNames,
        [Parameter(Mandatory = $true)]
        [string]$AdminEmail,
        [Parameter(Mandatory = $true)]
        [string]$SmtpServer,
        [Parameter(Mandatory = $true)]
        [string]$FromEmail,
        [int]$CheckInterval = 300  # Default 5 minutes
    )

    # Create a hashtable to store service status history
    $serviceStatus = @{}
    foreach ($computer in $ComputerNames) {
        $serviceStatus[$computer] = @{}
        foreach ($service in $ServiceNames) {
            $serviceStatus[$computer][$service] = "Unknown"
        }
    }

    Write-Host "Starting service monitoring..."
    while ($true) {
        foreach ($computer in $ComputerNames) {
            foreach ($service in $ServiceNames) {
                $currentStatus = Test-ServiceStatus -ComputerName $computer -ServiceName $service
                $previousStatus = $serviceStatus[$computer][$service]

                if ($currentStatus -eq "Stopped" -and $previousStatus -ne "Stopped") {
                    # Service has stopped - notify admin and attempt restart
                    $subject = "Service Alert: $service stopped on $computer"
                    $message = "The service $service on $computer has stopped. Attempting to restart..."
                    Send-AdminNotification -Subject $subject -Message $message -AdminEmail $AdminEmail

                    # Attempt to restart the service
                    $restartSuccess = Restart-MonitoredService -ComputerName $computer -ServiceName $service
                    
                    if ($restartSuccess) {
                        $subject = "Service Recovery: $service restarted on $computer"
                        $message = "The service $service on $computer has been successfully restarted."
                        Send-AdminNotification -Subject $subject -Message $message -AdminEmail $AdminEmail
                    }
                    else {
                        $subject = "Service Recovery Failed: $service on $computer"
                        $message = "Failed to restart the service $service on $computer. Manual intervention required."
                        Send-AdminNotification -Subject $subject -Message $message -AdminEmail $AdminEmail
                    }
                }

                $serviceStatus[$computer][$service] = $currentStatus
            }
        }

        Start-Sleep -Seconds $CheckInterval
    }
}

# Export all functions
Export-ModuleMember -Function @('Watch-ServiceStatus', 'Test-ServiceStatus', 'Restart-MonitoredService', 'Send-AdminNotification')
