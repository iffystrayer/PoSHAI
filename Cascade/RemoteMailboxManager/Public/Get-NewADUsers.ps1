function Get-NewADUsers {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$HoursBack = 24
    )

    try {
        # Get config
        $config = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "..\config.psd1")
        $searchBases = $config.SearchBases

        # Verify ActiveDirectory module is available
        if (!(Get-Command -Name 'Get-ADUser' -ErrorAction SilentlyContinue)) {
            Write-LogMessage -Message "ActiveDirectory module not found. Checking if it's loaded in the current session." -Level Warning
            if (Get-ADUser -Filter * -ErrorAction SilentlyContinue) {
                Write-LogMessage -Message "ActiveDirectory commands available in session." -Level Information
            }
            else {
                throw "ActiveDirectory module not available"
            }
        }

        # Calculate time threshold
        $timeThreshold = (Get-Date).AddHours(-$HoursBack)

        # Initialize results array
        $newUsers = @()

        # Search each base
        foreach ($searchBase in $searchBases) {
            Write-LogMessage -Message "Searching for new users in $searchBase" -Level Information
            
            $filter = "WhenCreated -ge '$($timeThreshold.ToString('MM/dd/yyyy HH:mm:ss'))'"
            $properties = @('Name', 'SamAccountName', 'WhenCreated', 'Title', 'DistinguishedName')
            
            $users = Get-ADUser -Filter $filter -SearchBase $searchBase -Properties $properties
            if ($users) {
                $newUsers += $users
            }
        }

        Write-LogMessage -Message "Found $($newUsers.Count) new users" -Level Information
        return $newUsers
    }
    catch {
        Write-LogMessage -Message "Error getting new AD users: $_" -Level Error
        return @()
    }
}
