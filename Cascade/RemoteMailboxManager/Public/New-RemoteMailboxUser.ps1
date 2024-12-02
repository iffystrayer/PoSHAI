function New-RemoteMailboxUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [Microsoft.ActiveDirectory.Management.ADUser]$User,

        [Parameter()]
        [hashtable]$Config = (Import-PowerShellDataFile -Path "$PSScriptRoot\..\Config\config.psd1")
    )

    begin {
        # Validate Exchange connection
        if (-not (Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' })) {
            throw "No active Exchange session found. Please connect using Connect-ExchangeEnvironment first."
        }
    }

    process {
        try {
            Write-LogMessage -Message "Processing user: $($User.SamAccountName)" -Level Information

            # Add to appropriate license group
            $LicenseGroup = if ($User.Title -like '*custodian*' -or $User.Title -like '*bus driver*') {
                $Config.LicenseGroups.CustodialGroup
            }
            else {
                $Config.LicenseGroups.StandardGroup
            }

            Add-ADGroupMember -Identity $Config.LicenseGroups.DefaultGroup -Members $User.SamAccountName
            Add-ADGroupMember -Identity $LicenseGroup -Members $User.SamAccountName

            Write-LogMessage -Message "Added $($User.SamAccountName) to license groups" -Level Information

            # Check if mailbox already exists
            if (-not (Get-Mailbox $User.SamAccountName -ErrorAction SilentlyContinue) -and 
                -not (Get-RemoteMailbox $User.SamAccountName -ErrorAction SilentlyContinue)) {
                
                $RemoteMailboxParams = @{
                    Identity = $User.SamAccountName
                    RemoteRoutingAddress = "$($User.SamAccountName)$($Config.AddressSuffix)"
                    Name = $User.Name
                    Alias = $User.SamAccountName
                    OnPremisesOrganizationalUnit = $User.DistinguishedName
                }

                Enable-RemoteMailbox @RemoteMailboxParams
                Write-LogMessage -Message "Created remote mailbox for $($User.SamAccountName)" -Level Information

                # Wait for AD replication
                Start-Sleep -Seconds 5

                # Set email addresses
                $EmailAddresses = @(
                    "SMTP:$($User.SamAccountName)@kpanakon.org"
                    "smtp:$($User.SamAccountName)$($Config.AddressSuffix)"
                )

                Set-RemoteMailbox $User.SamAccountName -EmailAddresses $EmailAddresses
                Write-LogMessage -Message "Set email addresses for $($User.SamAccountName)" -Level Information
            }
            else {
                Write-LogMessage -Message "Mailbox already exists for $($User.SamAccountName)" -Level Warning
            }
        }
        catch {
            Write-LogMessage -Message "Error processing user $($User.SamAccountName): $_" -Level Error
            throw $_
        }
    }
}
