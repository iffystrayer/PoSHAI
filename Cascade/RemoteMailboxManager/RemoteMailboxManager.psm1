# Get all ps1 files in Public and Private folders
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($import.FullName): $_"
    }
}

# Export all public functions
Export-ModuleMember -Function $Public.BaseName
# Also export Write-LogMessage since it's needed by other functions
Export-ModuleMember -Function 'Write-LogMessage'
