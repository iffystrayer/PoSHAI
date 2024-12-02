# Import the module
Import-Module "$PSScriptRoot\ServiceMonitor.psm1" -Force

Write-Host "Testing Test-ServiceStatus function..."
try {
    $status = Test-ServiceStatus -ComputerName $env:COMPUTERNAME -ServiceName "W32Time"
    Write-Host "Windows Time service status: $status"
} catch {
    Write-Host "Error testing service status: $_"
}

Write-Host "`nTesting service monitoring for 30 seconds..."
try {
    $job = Start-Job -ScriptBlock {
        Import-Module "$using:PSScriptRoot\ServiceMonitor.psm1" -Force
        Watch-ServiceStatus -ComputerNames @($env:COMPUTERNAME) `
                           -ServiceNames @("W32Time") `
                           -AdminEmail "test@example.com" `
                           -SmtpServer "smtp.example.com" `
                           -FromEmail "from@example.com" `
                           -CheckInterval 5
    }

    Start-Sleep -Seconds 5
    Write-Host "Monitoring is running. You can check the Windows Time service status in Services.msc"
    Write-Host "Current job output:"
    Receive-Job $job
} catch {
    Write-Host "Error during monitoring: $_"
} finally {
    if ($job) {
        Stop-Job $job
        Remove-Job $job
    }
}

Write-Host "`nTest completed!"
