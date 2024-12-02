function Test-ExchangeConnection {
    [CmdletBinding()]
    param()

    try {
        # Check if Exchange commands are available
        $exchangeCommands = @('Get-Mailbox', 'Get-RemoteMailbox', 'Enable-RemoteMailbox', 'Set-RemoteMailbox')
        foreach ($command in $exchangeCommands) {
            if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
                Write-LogMessage -Message "Exchange command $command not available" -Level Warning
                return $false
            }
        }

        Write-LogMessage -Message "Exchange commands available" -Level Information
        return $true
    }
    catch {
        Write-LogMessage -Message "Error testing Exchange connection: $_" -Level Error
        return $false
    }
}
