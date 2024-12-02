BeforeAll {
    # Import the module
    Import-Module "$PSScriptRoot\ServiceMonitor.psm1" -Force
}

Describe "ServiceMonitor Module Tests" {
    Context "Test-ServiceStatus Function" {
        It "Should return service status for a valid service" {
            $result = Test-ServiceStatus -ComputerName $env:COMPUTERNAME -ServiceName "Spooler"
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeIn @('Running', 'Stopped', 'StartPending', 'StopPending')
        }

        It "Should handle invalid service name gracefully" {
            $result = Test-ServiceStatus -ComputerName $env:COMPUTERNAME -ServiceName "NonExistentService"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Restart-MonitoredService Function" {
        It "Should attempt to restart a valid service" {
            $result = Restart-MonitoredService -ComputerName $env:COMPUTERNAME -ServiceName "Spooler"
            $result | Should -BeOfType [bool]
        }

        It "Should return false for invalid service" {
            $result = Restart-MonitoredService -ComputerName $env:COMPUTERNAME -ServiceName "NonExistentService"
            $result | Should -Be $false
        }
    }

    Context "Send-AdminNotification Function" {
        # Mock Send-MailMessage to avoid actual email sending
        Mock Send-MailMessage { return $true }

        It "Should attempt to send notification" {
            $result = Send-AdminNotification -Subject "Test Subject" -Message "Test Message" -AdminEmail "test@example.com"
            Should -Invoke Send-MailMessage -Times 1
        }
    }

    Context "Watch-ServiceStatus Function Parameter Validation" {
        It "Should throw when required parameters are missing" {
            { Watch-ServiceStatus } | Should -Throw
        }

        It "Should accept valid parameters" {
            # Mock the infinite loop to test parameter validation
            Mock Start-Sleep { break }
            
            $params = @{
                ComputerNames = @($env:COMPUTERNAME)
                ServiceNames = @("Spooler")
                AdminEmail = "test@example.com"
                SmtpServer = "smtp.example.com"
                FromEmail = "from@example.com"
                CheckInterval = 60
            }

            { Watch-ServiceStatus @params } | Should -Not -Throw
        }
    }
}
