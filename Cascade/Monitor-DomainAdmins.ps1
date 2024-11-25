# Configuration
$config = @{
    SmtpServer      = "smtp.yourdomain.com"
    SmtpPort        = 587
    EmailFrom       = "monitoring@yourdomain.com"
    EmailTo         = "admin@yourdomain.com"
    CheckInterval   = 300  # 5 minutes in seconds
    LogPath         = "C:\Logs\DomainAdminMonitor.log"
}

# Function to write to log file
function Write-ToLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        
        # Create log directory if it doesn't exist
        $logDir = Split-Path -Parent $config.LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        Add-Content -Path $config.LogPath -Value $logMessage
    }
    catch {
        Write-Error "Failed to write to log: $_"
    }
}

# Function to send email notifications
function Send-AlertEmail {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        [Parameter(Mandatory = $true)]
        [string]$Body
    )
    
    try {
        $emailParams = @{
            From       = $config.EmailFrom
            To         = $config.EmailTo
            Subject    = $Subject
            Body      = $Body
            SmtpServer = $config.SmtpServer
            Port      = $config.SmtpPort
            UseSsl    = $true
            ErrorAction = 'Stop'
        }
        
        Send-MailMessage @emailParams
        Write-ToLog "Email alert sent successfully: $Subject"
    }
    catch {
        Write-ToLog "Error sending email: $_"
        throw
    }
}

# Function to get Domain Admins group members
function Get-DomainAdminsMembers {
    try {
        $members = Get-ADGroupMember -Identity "Domain Admins" -Recursive | 
                  Select-Object Name, SamAccountName, ObjectClass, DistinguishedName
        return $members
    }
    catch {
        Write-ToLog "Error getting Domain Admins members: $_"
        throw
    }
}

# Function to compare current members with previous state
function Compare-GroupMembers {
    param(
        [Parameter(Mandatory = $true)]
        $PreviousMembers,
        [Parameter(Mandatory = $true)]
        $CurrentMembers
    )
    
    $newMembers = $CurrentMembers | Where-Object {
        $member = $_
        -not ($PreviousMembers | Where-Object { $_.SamAccountName -eq $member.SamAccountName })
    }
    
    return $newMembers
}

# Main monitoring function
function Start-DomainAdminMonitoring {
    Write-ToLog "Starting Domain Admins monitoring..."
    
    try {
        $previousMembers = Get-DomainAdminsMembers
        Write-ToLog "Initial Domain Admins members captured. Count: $($previousMembers.Count)"
        
        while ($true) {
            try {
                Start-Sleep -Seconds $config.CheckInterval
                
                $currentMembers = Get-DomainAdminsMembers
                $newMembers = Compare-GroupMembers -PreviousMembers $previousMembers -CurrentMembers $currentMembers
                
                if ($newMembers) {
                    $alertSubject = "ALERT: New Domain Admin Members Detected"
                    $alertBody = "The following new members were added to the Domain Admins group:`n`n"
                    
                    foreach ($member in $newMembers) {
                        $alertBody += "Name: $($member.Name)`n"
                        $alertBody += "Username: $($member.SamAccountName)`n"
                        $alertBody += "Distinguished Name: $($member.DistinguishedName)`n`n"
                    }
                    
                    Send-AlertEmail -Subject $alertSubject -Body $alertBody
                    Write-ToLog "New members detected and alert sent"
                }
                
                $previousMembers = $currentMembers
            }
            catch {
                Write-ToLog "Error in monitoring loop: $_"
                Send-AlertEmail -Subject "ERROR: Domain Admin Monitoring Error" -Body "The following error occurred:`n$_"
                Start-Sleep -Seconds 60  # Wait a minute before retrying
            }
        }
    }
    catch {
        Write-ToLog "Critical error in monitoring: $_"
        Send-AlertEmail -Subject "CRITICAL: Domain Admin Monitoring Stopped" -Body "The monitoring service has stopped due to a critical error:`n$_"
        throw
    }
}

# Start the monitoring
try {
    # Import required module
    Import-Module ActiveDirectory -ErrorAction Stop
    Start-DomainAdminMonitoring
}
catch {
    Write-ToLog "Failed to start monitoring: $_"
    exit 1
}
