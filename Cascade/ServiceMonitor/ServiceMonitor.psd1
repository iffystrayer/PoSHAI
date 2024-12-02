@{
    RootModule = 'ServiceMonitor.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'f8b0e1c0-5c1a-4c1e-9b0a-9c1a4c1e9b0a'
    Author = 'Service Monitor'
    Description = 'Module for monitoring services across multiple servers with automatic restart and admin notifications'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Watch-ServiceStatus')
    PrivateData = @{
        PSData = @{
            Tags = @('Service', 'Monitoring', 'Administration')
            ProjectUri = ''
            LicenseUri = ''
        }
    }
}
