function Connect-ExchangeEnvironment {
    [CmdletBinding()]
    param (
        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        [Parameter()]
        [string]$ExchangeUri = (Import-PowerShellDataFile -Path "$PSScriptRoot\..\config.psd1").ExchangeServerUri
    )

    try {
        # Remove existing sessions
        Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' } | Remove-PSSession

        # Check if Exchange commands are already available
        if (Test-ExchangeConnection) {
            Write-LogMessage -Message "Exchange connection already established" -Level Information
            return $true
        }

        Write-LogMessage -Message "Connecting to Exchange server at $ExchangeUri" -Level Information
        
        $SessionParams = @{
            ConfigurationName = 'Microsoft.Exchange'
            ConnectionUri = $ExchangeUri
            Authentication = 'Kerberos'
        }

        if ($PSBoundParameters.ContainsKey('Credential')) {
            $SessionParams['Credential'] = $Credential
        }

        try {
            $Session = New-PSSession @SessionParams -ErrorAction Stop
            if ($Session.State -eq 'Opened' -and $Session.Availability -eq 'Available') {
                Import-PSSession $Session -DisableNameChecking -AllowClobber -ErrorAction Stop | Out-Null
                Write-LogMessage -Message "Successfully connected to Exchange server" -Level Information
                return $true
            }
            else {
                Write-LogMessage -Message "Exchange session created but not in correct state (State: $($Session.State), Availability: $($Session.Availability))" -Level Error
                return $false
            }
        }
        catch {
            Write-LogMessage -Message "Failed to create Exchange session: $_" -Level Error
            return $false
        }
    }
    catch {
        Write-LogMessage -Message "Failed to connect to Exchange server: $_" -Level Error
        return $false
    }
}
