[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = ".\config.json",
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = ".\ADUserReset.log"
)

# Import required modules
#Requires -Modules ActiveDirectory, Microsoft.Graph.Users, Microsoft.Graph.Mail

# Initialize logging
function Initialize-Logging {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogPath
    )
    
    try {
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Start-Transcript -Path $LogPath -Append
        Write-Verbose "Logging initialized to $LogPath"
    }
    catch {
        throw "Failed to initialize logging: $_"
    }
}

# Load configuration from JSON file
function Get-ScriptConfig {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )
    
    try {
        if (Test-Path -Path $ConfigPath) {
            $config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            return $config
        }
        else {
            throw "Configuration file not found at $ConfigPath"
        }
    }
    catch {
        throw "Failed to load configuration: $_"
    }
}

# Validate AD user object
function Test-ADUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User
    )
    
    return -not [string]::IsNullOrEmpty($User.EmployeeID)
}

# Reset user password and enable account
function Reset-UserAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,
        
        [Parameter(Mandatory = $true)]
        [SecureString]$PasswordPrefix
    )
    
    try {
        # Convert SecureString to plain text only within the scope of this operation
        $prefixText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordPrefix)
        )
        $newPassword = ConvertTo-SecureString -AsPlainText -String "$prefixText$($User.EmployeeID)" -Force
        Set-ADAccountPassword -Identity $User.SamAccountName -Reset -NewPassword $newPassword
        Enable-ADAccount -Identity $User.SamAccountName
        Write-Verbose "Successfully reset password and enabled account for $($User.SamAccountName)"
        
        # Securely clear the plain text password from memory
        $prefixText = $null
        return $true
    }
    catch {
        Write-Error "Failed to reset account for $($User.SamAccountName): $_"
        return $false
    }
}

# Send notification using custom SMTP or other methods
function Send-CustomNotification {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Recipient,
        
        [Parameter(Mandatory = $true)]
        [string]$Subject,
        
        [Parameter(Mandatory = true)]
        [string]$Body,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$SmtpSettings
    )
    
    try {
        $emailParams = @{
            From = $SmtpSettings.From
            To = $Recipient
            Subject = $Subject
            Body = $Body
            SmtpServer = $SmtpSettings.Server
            Port = $SmtpSettings.Port
            UseSSL = $SmtpSettings.UseSSL
        }
        
        if ($SmtpSettings.RequiresAuth) {
            $securePassword = ConvertTo-SecureString $SmtpSettings.Password -AsPlainText -Force
            $credentials = New-Object System.Management.Automation.PSCredential($SmtpSettings.Username, $securePassword)
            $emailParams.Add('Credential', $credentials)
        }
        
        Send-MailMessage @emailParams
        Write-Verbose "Notification email sent successfully to $Recipient"
        return $true
    }
    catch {
        Write-Error "Failed to send notification: $_"
        return $false
    }
}

# Main function to process disabled users
function Reset-DisabledADUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )
    
    $processedUsers = @()
    $errorCount = 0
    
    foreach ($ouFilter in $Config.OUFilters) {
        try {
            $ous = Get-ADOrganizationalUnit -Filter $ouFilter
            foreach ($ou in $ous) {
                Write-Verbose "Processing OU: $($ou.DistinguishedName)"
                $disabledUsers = Get-ADUser -Filter {Enabled -eq $false} -SearchBase $ou.DistinguishedName -Properties EmployeeID
                
                foreach ($user in $disabledUsers) {
                    if (Test-ADUser -User $user) {
                        if (Reset-UserAccount -User $user -PasswordPrefix $Config.PasswordPrefix) {
                            $processedUsers += $user
                        }
                        else {
                            $errorCount++
                        }
                    }
                    else {
                        Write-Warning "User $($user.SamAccountName) has no EmployeeID"
                    }
                }
            }
        }
        catch {
            Write-Error "Failed to process OU filter '$ouFilter': $_"
            $errorCount++
        }
    }
    
    return @{
        ProcessedUsers = $processedUsers
        ErrorCount = $errorCount
    }
}

# Main execution block
try {
    Initialize-Logging -LogPath $LogPath
    $config = Get-ScriptConfig -ConfigPath $ConfigPath
    
    Write-Verbose "Starting user account reset process..."
    $result = Reset-DisabledADUsers -Config $config
    
    if ($result.ProcessedUsers.Count -gt 0) {
        $body = @"
Password Reset Summary:
- Total users processed: $($result.ProcessedUsers.Count)
- Errors encountered: $($result.ErrorCount)
- Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
        
        Send-CustomNotification -Recipient $config.NotificationEmail `
                              -Subject "AD User Password Reset Summary" `
                              -Body $body `
                              -SmtpSettings $config.SmtpSettings
    }
    
    Write-Verbose "Process completed. Total users processed: $($result.ProcessedUsers.Count), Errors: $($result.ErrorCount)"
}
catch {
    Write-Error "Script execution failed: $_"
}
finally {
    Stop-Transcript
}
