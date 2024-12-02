function Set-UserMfaState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ObjectId,
        
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$UserPrincipalName,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("Disabled", "Enabled", "Enforced")]
        [string]$State
    )

    begin {
        try {
            # Check if MSOnline module is available and connected
            if (-not (Get-Module -Name MSOnline -ListAvailable)) {
                throw "MSOnline module is not installed. Please install it using: Install-Module -Name MSOnline"
            }
        }
        catch {
            Write-LogMessage -Message "Error in MFA setup: $_" -Level Error
            throw $_
        }
    }

    process {
        try {
            Write-LogMessage -Message "Setting MFA state for user '$UserPrincipalName' to '$State'" -Level Information
            
            $Requirements = @()
            if ($State -ne "Disabled") {
                $Requirement = [Microsoft.Online.Administration.StrongAuthenticationRequirement]::new()
                $Requirement.RelyingParty = "*"
                $Requirement.State = $State
                $Requirements += $Requirement
            }

            Set-MsolUser -ObjectId $ObjectId -UserPrincipalName $UserPrincipalName -StrongAuthenticationRequirements $Requirements
            Write-LogMessage -Message "Successfully set MFA state for user '$UserPrincipalName'" -Level Information
        }
        catch {
            Write-LogMessage -Message "Failed to set MFA state for user '$UserPrincipalName': $_" -Level Error
            throw $_
        }
    }
}
