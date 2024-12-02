function Write-LogMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Error", "Warning", "Information")]
        [string]$Level = "Information",

        [Parameter(Mandatory = $false)]
        [string]$LogFolder
    )
    
    try {
        # If LogFolder is not provided, try to get it from config
        if (-not $LogFolder) {
            # Try Config directory first
            $configPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "Config\config.psd1"
            if (-not (Test-Path $configPath)) {
                # Try root directory as fallback
                $configPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "config.psd1"
            }
            
            if (Test-Path $configPath) {
                $config = Import-PowerShellDataFile -Path $configPath
                $LogFolder = $config.LogFolderPath
            }
            
            if (-not $LogFolder) {
                throw "Log folder path not provided and not found in config"
            }
        }

        # Ensure log directory exists
        if (-not (Test-Path -Path $LogFolder)) {
            $null = New-Item -Path $LogFolder -ItemType Directory -Force
        }

        $LogFile = Join-Path -Path $LogFolder -ChildPath "$(Get-Date -Format 'yyyy-MM-dd').log"
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $LogEntry = "[$TimeStamp] [$Level] $Message"
        
        # Write to log file
        Add-Content -Path $LogFile -Value $LogEntry
        
        # Also write to appropriate output stream
        switch ($Level) {
            "Error" { Write-Error $Message }
            "Warning" { Write-Warning $Message }
            "Information" { Write-Verbose $Message -Verbose }
        }
    }
    catch {
        Write-Error "Failed to write log message: $_"
        throw
    }
}
