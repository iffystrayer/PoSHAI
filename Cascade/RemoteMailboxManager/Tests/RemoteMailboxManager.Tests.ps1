BeforeAll {
    # Import test helpers
    . $PSScriptRoot\TestHelpers.ps1

    # Import module
    $script:ModulePath = Split-Path -Parent $PSScriptRoot
    $env:PSModulePath = $script:ModulePath + [System.IO.Path]::PathSeparator + $env:PSModulePath
    
    # Create config directory if it doesn't exist
    $script:ConfigPath = Join-Path $script:ModulePath "Config"
    if (-not (Test-Path $script:ConfigPath)) {
        New-Item -Path $script:ConfigPath -ItemType Directory -Force | Out-Null
    }

    # Create temporary test directory instead of using TestDrive
    $script:TestRoot = Join-Path $env:TEMP "RemoteMailboxManagerTests"
    $script:MockEDrivePath = Join-Path $script:TestRoot "EDrive"
    
    # Create test directories
    Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -Path $script:MockEDrivePath -ItemType Directory -Force | Out-Null
    New-Item -Path "$script:MockEDrivePath\StaffProv\EmployeeEmailOnline\log" -ItemType Directory -Force | Out-Null

    # Create mock config file
    $configData = @{
        LogFolderPath = Join-Path $script:MockEDrivePath "StaffProv\EmployeeEmailOnline\log"
        ExchangeServerUri = "http://aps-exch02.kpanakon.org/powershell"
        SearchBases = @(
            "OU=Staff,DC=test,DC=local"
            "OU=Students,DC=test,DC=local"
        )
    }

    # Ensure config file is created
    $configFile = Join-Path $script:ConfigPath "config.psd1"
    $configContent = "@{`n"
    foreach ($key in $configData.Keys) {
        $value = $configData[$key]
        if ($value -is [string]) {
            $configContent += "    $key = '$value'`n"
        }
        elseif ($value -is [array]) {
            $configContent += "    $key = @(`n"
            foreach ($item in $value) {
                $configContent += "        '$item'`n"
            }
            $configContent += "    )`n"
        }
    }
    $configContent += "}"
    
    Set-Content -Path $configFile -Value $configContent -Force
    
    # Verify config file exists and has content
    if (-not (Test-Path $configFile)) {
        throw "Failed to create config file at $configFile"
    }
    
    $configFileContent = Get-Content $configFile -Raw
    if (-not $configFileContent) {
        throw "Config file is empty at $configFile"
    }

    # Import module after config is created
    Import-Module (Join-Path $script:ModulePath "RemoteMailboxManager.psm1") -Force -ErrorAction Stop

    # Instead of creating a PSDrive, we'll just use the mock path directly
    $script:EDrivePath = $script:MockEDrivePath

    # Mock Get-PSDrive to return our mock drive info
    Mock Get-PSDrive {
        [PSCustomObject]@{
            Name = "E"
            Root = $script:MockEDrivePath
            Provider = [PSCustomObject]@{ Name = "FileSystem" }
        }
    } -ParameterFilter { $Name -eq "E" }

    # Create ADUser type if it doesn't exist
    if (-not ("Microsoft.ActiveDirectory.Management.ADUser" -as [type])) {
        Add-Type @"
            using System;
            namespace Microsoft.ActiveDirectory.Management {
                public class ADUser {
                    public string Name { get; set; }
                    public string SamAccountName { get; set; }
                    public DateTime WhenCreated { get; set; }
                    public string Title { get; set; }
                    public string DistinguishedName { get; set; }
                }
            }
"@
    }

    # Mock ActiveDirectory module
    function global:Get-ADUser { 
        param($Filter, $SearchBase, $Properties)
        $user = New-Object Microsoft.ActiveDirectory.Management.ADUser
        $user.Name = "Test User"
        $user.SamAccountName = "testuser"
        $user.WhenCreated = (Get-Date).AddHours(-1)
        $user.Title = "Teacher"
        $user.DistinguishedName = "CN=Test User,OU=Users,DC=test,DC=local"
        $user
    }

    function global:Add-ADGroupMember { 
        param($Identity, $Members)
        Write-Output "Added $Members to $Identity"
    }

    # Mock Exchange cmdlets
    function global:Get-Mailbox { param($Identity) }
    function global:Get-RemoteMailbox { param($Identity) }
    function global:Enable-RemoteMailbox { param($Identity, $RemoteRoutingAddress) }
    function global:Set-RemoteMailbox { param($Identity, $EmailAddresses) }

    # Remove mock config
    Remove-Item -Path (Join-Path $script:ConfigPath "config.psd1") -ErrorAction SilentlyContinue
}

AfterAll {
    # Cleanup
    Remove-Item -Path $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue

    # Remove mock functions
    Remove-Item function:Get-ADUser -ErrorAction SilentlyContinue
    Remove-Item function:Add-ADGroupMember -ErrorAction SilentlyContinue
    Remove-Item function:Get-Mailbox -ErrorAction SilentlyContinue
    Remove-Item function:Get-RemoteMailbox -ErrorAction SilentlyContinue
    Remove-Item function:Enable-RemoteMailbox -ErrorAction SilentlyContinue
    Remove-Item function:Set-RemoteMailbox -ErrorAction SilentlyContinue
    Remove-Item function:Test-ExchangeConnection -ErrorAction SilentlyContinue

    # Remove mock config
    Remove-Item -Path (Join-Path $script:ConfigPath "config.psd1") -ErrorAction SilentlyContinue
}

Describe "RemoteMailboxManager Module Tests" {
    Context "Write-LogMessage" {
        BeforeAll {
            # Use the mock path instead of E: drive
            $script:TestLogFolder = Join-Path $script:MockEDrivePath "StaffProv\EmployeeEmailOnline\log"
        }

        It "Creates log entry with correct format" {
            $Message = "Test log message"
            Write-LogMessage -Message $Message -Level Information -LogFolder $script:TestLogFolder
            $LogFile = Join-Path $script:TestLogFolder "$(Get-Date -Format 'yyyy-MM-dd').log"
            $LogFile | Should -Exist
            $LogContent = Get-Content -Path $LogFile
            $LogContent | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[Information\] $Message"
        }

        It "Creates log directory if it doesn't exist" {
            $NewLogPath = Join-Path $script:MockEDrivePath "StaffProv\EmployeeEmailOnline\log\newpath"
            $Message = "Test log message in new directory"
            Write-LogMessage -Message $Message -Level Information -LogFolder $NewLogPath
            $NewLogPath | Should -Exist
            $LogFile = Join-Path $NewLogPath "$(Get-Date -Format 'yyyy-MM-dd').log"
            $LogFile | Should -Exist
            $LogContent = Get-Content -Path $LogFile
            $LogContent | Should -Match "\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[Information\] $Message"
        }
    }

    Context "Get-NewADUsers" {
        BeforeAll {
            Mock Get-ADUser { 
                $user = New-Object Microsoft.ActiveDirectory.Management.ADUser
                $user.Name = "Test User"
                $user.SamAccountName = "testuser"
                $user.WhenCreated = (Get-Date).AddHours(-1)
                $user.Title = "Teacher"
                $user.DistinguishedName = "CN=Test User,OU=Users,DC=test,DC=local"
                @($user)
            } -ModuleName RemoteMailboxManager
        }

        It "Returns new users created within specified time" {
            Mock Get-Command { $true } -ParameterFilter { $Name -eq 'Get-ADUser' } -ModuleName RemoteMailboxManager
            $Result = Get-NewADUsers -HoursBack 2
            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 1
            $Result[0].SamAccountName | Should -Be "testuser"
        }
    }

    Context "Connect-ExchangeEnvironment" {
        BeforeAll {
            # Mock Exchange cmdlets and functions
            Mock Get-PSSession { } -ModuleName RemoteMailboxManager
            Mock Import-PSSession { } -ModuleName RemoteMailboxManager
            Mock Import-Module { } -ModuleName RemoteMailboxManager
            Mock Get-Command { $true } -ParameterFilter { $Name -eq 'Get-PSSession' } -ModuleName RemoteMailboxManager
            Mock Test-ExchangeConnection { $false } -ModuleName RemoteMailboxManager
            Mock Remove-PSSession { } -ModuleName RemoteMailboxManager

            # Mock New-PSSession to return a working session
            Mock New-PSSession {
                # Create a base object
                $session = [PSCustomObject]@{
                    ComputerName = "exchange.test"
                    ConfigurationName = "Microsoft.Exchange"
                    State = "Opened"
                    Id = 1
                    Name = "ExchangeSession"
                    Availability = "Available"
                }

                # Add type name
                $session.PSObject.TypeNames.Insert(0, "System.Management.Automation.Runspaces.PSSession")

                # Add script methods that PowerShell expects
                $session | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
                
                return $session
            } -ModuleName RemoteMailboxManager
        }

        It "Returns true when Exchange connection exists" {
            Mock Test-ExchangeConnection { $true } -ModuleName RemoteMailboxManager
            $Result = Connect-ExchangeEnvironment
            $Result | Should -Be $true
        }

        It "Creates new Exchange session when no connection exists" {
            Mock Test-ExchangeConnection { $false } -ModuleName RemoteMailboxManager
            $Result = Connect-ExchangeEnvironment
            $Result | Should -Be $true
            Should -Invoke New-PSSession -ModuleName RemoteMailboxManager -Times 1
        }
    }

    Context "New-RemoteMailboxUser" {
        BeforeAll {
            # Mock Exchange cmdlets and functions
            Mock Get-PSSession {
                # Create a base object
                $session = [PSCustomObject]@{
                    ComputerName = "exchange.test"
                    ConfigurationName = "Microsoft.Exchange"
                    State = "Opened"
                    Id = 1
                    Name = "ExchangeSession"
                    Availability = "Available"
                }

                # Add type name
                $session.PSObject.TypeNames.Insert(0, "System.Management.Automation.Runspaces.PSSession")

                # Add script methods that PowerShell expects
                $session | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
                
                return $session
            } -ModuleName RemoteMailboxManager

            Mock Add-ADGroupMember { } -ModuleName RemoteMailboxManager
            Mock Get-Mailbox { $null } -ModuleName RemoteMailboxManager
            Mock Get-RemoteMailbox { $null } -ModuleName RemoteMailboxManager
            Mock Enable-RemoteMailbox { } -ModuleName RemoteMailboxManager
            Mock Set-RemoteMailbox { } -ModuleName RemoteMailboxManager
            Mock Get-Command { $true } -ParameterFilter { $Name -eq 'Get-PSSession' } -ModuleName RemoteMailboxManager
            Mock Test-ExchangeConnection { $true } -ModuleName RemoteMailboxManager
        }

        It "Creates new remote mailbox for user" {
            $TestUser = New-Object Microsoft.ActiveDirectory.Management.ADUser
            $TestUser.SamAccountName = "testuser"
            $TestUser.Name = "Test User"
            $TestUser.Title = "Teacher"
            $TestUser.DistinguishedName = "CN=Test User,OU=Users,DC=test,DC=local"
            { New-RemoteMailboxUser -User $TestUser } | Should -Not -Throw
            Should -Invoke Enable-RemoteMailbox -ModuleName RemoteMailboxManager -Times 1
            Should -Invoke Set-RemoteMailbox -ModuleName RemoteMailboxManager -Times 1
        }
    }
}
