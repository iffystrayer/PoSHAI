BeforeAll {
    # Import the module/script to test
    . $PSScriptRoot\Manage-StudentEmails.ps1

    # Mock data for testing
    $mockStudents = @(
        @{
            SAMAccountName = "student1"
            EmailAddress = ""
            UserPrincipalName = "student1@apsk12.org"
            EmployeeID = "12345"
            Enabled = $true
            Name = "Student One"
        },
        @{
            SAMAccountName = "student2"
            EmailAddress = $null
            UserPrincipalName = "student2@apsk12.org"
            EmployeeID = "12346"
            Enabled = $true
            Name = "Student Two"
        }
    )

    $mockStudentsWithEmail = @(
        @{
            SAMAccountName = "student3"
            EmailAddress = "student3@apsk12.org"
            UserPrincipalName = "student3@apsk12.org"
            EmployeeID = "12347"
            Enabled = $true
            Name = "Student Three"
        }
    )
}

Describe 'Get-StudentsWithoutEmail' {
    BeforeAll {
        # Mock Get-ADUser
        Mock Get-ADUser {
            return $mockStudents
        } -ParameterFilter { $Filter -match "emailaddress -notlike" }
    }

    It 'Should return students without email addresses' {
        $result = Get-StudentsWithoutEmail
        $result | Should -Not -BeNullOrEmpty
        $result.Count | Should -Be 2
    }

    It 'Should use the correct filter in Get-ADUser' {
        $null = Get-StudentsWithoutEmail
        Should -Invoke Get-ADUser -Times 1 -ParameterFilter {
            $Properties -contains 'emailaddress' -and 
            $Properties -contains 'employeeid'
        }
    }

    It 'Should handle empty results' {
        Mock Get-ADUser { return $null }
        $result = Get-StudentsWithoutEmail
        $result | Should -BeNullOrEmpty
    }

    It 'Should throw on AD error' {
        Mock Get-ADUser { throw "AD Error" }
        { Get-StudentsWithoutEmail } | Should -Throw
    }
}

Describe 'Add-EmailToStudents' {
    BeforeAll {
        Mock Set-ADUser { 
            return @{
                SAMAccountName = $Identity
                EmailAddress = $EmailAddress
            }
        }
    }

    It 'Should process all students successfully when no errors' {
        $results = Add-EmailToStudents -Students $mockStudents
        $results.SuccessfulUpdates.Count | Should -Be 2
        $results.FailedUpdates.Count | Should -Be 0
    }

    It 'Should handle Set-ADUser errors' {
        Mock Set-ADUser { throw "AD Error" }
        $results = Add-EmailToStudents -Students $mockStudents
        $results.SuccessfulUpdates.Count | Should -Be 0
        $results.FailedUpdates.Count | Should -Be 2
    }

    It 'Should skip students with empty UserPrincipalName' {
        $invalidStudent = @{
            SAMAccountName = "invalid"
            UserPrincipalName = ""
            EmployeeID = "12348"
        }
        $results = Add-EmailToStudents -Students @($invalidStudent)
        $results.FailedUpdates.Count | Should -Be 1
    }

    It 'Should set correct email and proxy addresses' {
        $null = Add-EmailToStudents -Students $mockStudents[0]
        Should -Invoke Set-ADUser -Times 1 -ParameterFilter {
            $Identity -eq $mockStudents[0].SAMAccountName -and
            $EmailAddress -eq $mockStudents[0].UserPrincipalName -and
            $Add.ProxyAddresses -eq "SMTP:$($mockStudents[0].UserPrincipalName)"
        }
    }
}

Describe 'Process-StudentEmails' {
    BeforeAll {
        Mock Get-StudentsWithoutEmail { return $mockStudents }
        Mock Add-EmailToStudents { 
            return @{
                SuccessfulUpdates = $mockStudents
                FailedUpdates = @()
            }
        }
    }

    It 'Should process all students when found' {
        $result = Process-StudentEmails
        $result.SuccessfulUpdates.Count | Should -Be 2
        $result.FailedUpdates.Count | Should -Be 0
    }

    It 'Should handle no students found' {
        Mock Get-StudentsWithoutEmail { return $null }
        $result = Process-StudentEmails
        $result | Should -BeNullOrEmpty
    }

    It 'Should handle Get-StudentsWithoutEmail errors' {
        Mock Get-StudentsWithoutEmail { throw "AD Error" }
        { Process-StudentEmails } | Should -Throw
    }

    It 'Should use custom SearchBase when provided' {
        $customSearchBase = "OU=CustomOU,DC=student,DC=apsk12,DC=org"
        $null = Process-StudentEmails -SearchBase $customSearchBase
        Should -Invoke Get-StudentsWithoutEmail -Times 1 -ParameterFilter {
            $SearchBase -eq $customSearchBase
        }
    }

    It 'Should handle partial failures' {
        Mock Add-EmailToStudents { 
            return @{
                SuccessfulUpdates = @($mockStudents[0])
                FailedUpdates = @($mockStudents[1])
            }
        }
        $result = Process-StudentEmails
        $result.SuccessfulUpdates.Count | Should -Be 1
        $result.FailedUpdates.Count | Should -Be 1
    }
}
