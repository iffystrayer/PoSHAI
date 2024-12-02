# Verbose preference to continue
$VerbosePreference = "Continue"

# Advanced function to get the list of students without email
function Get-StudentsWithoutEmail {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase = "OU=Schools,DC=student,DC=apsk12,DC=org"
    )
    process {
        try {
            Write-Verbose "Retrieving the list of students without email from $SearchBase..."
            # Optimize by using server-side filtering
            $students = Get-ADUser -Filter {(emailaddress -notlike "*") -and (Enabled -eq $true) -and (name -notlike "academy*")} `
                                 -Properties emailaddress, employeeid `
                                 #-SearchBase $SearchBase
            
            if ($students) {
                Write-Verbose "Found $($students.Count) students without email addresses."
                return $students
            } else {
                Write-Verbose "No students found without email addresses."
                return $null
            }
        }
        catch {
            Write-Warning "Error retrieving students: $_"
            throw $_
        }
    }
}

# Advanced function to add email addresses to students
function Add-EmailToStudents {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNull()]
        [array]$Students
    )
    begin {
        $added = @()
        $failed = @()
    }
    process {
        foreach ($student in $Students) {
            try {
                Write-Verbose "Processing student: $($student.SAMAccountName) (EmployeeID: $($student.EmployeeID))"
                
                # Validate UPN before attempting to set
                if ([string]::IsNullOrEmpty($student.UserPrincipalName)) {
                    throw "UserPrincipalName is null or empty"
                }

                $setResult = Set-ADUser -Identity $student.SAMAccountName `
                                      -EmailAddress $student.UserPrincipalName `
                                      -Add @{ProxyAddresses="SMTP:"+$student.UserPrincipalName} `
                                      -ErrorAction Stop `
                                      -PassThru
                
                $added += $setResult
                Write-Verbose "Successfully added email for $($student.SAMAccountName)"
            }
            catch {
                Write-Warning "Error adding email for $($student.SAMAccountName): $_"
                $failed += $student
            }
        }
    }
    end {
        Write-Verbose "Operation completed. Successfully processed: $($added.Count), Failed: $($failed.Count)"
        return @{
            SuccessfulUpdates = $added
            FailedUpdates = $failed
        }
    }
}

# Main process workflow
function Process-StudentEmails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string]$SearchBase = "OU=Schools,DC=student,DC=apsk12,DC=org"
    )
    process {
        try {
            Write-Verbose "Starting email update process..."
            
            # Get students without email addresses
            $studentsNoEmail = Get-StudentsWithoutEmail -SearchBase $SearchBase
            
            if ($studentsNoEmail -and $studentsNoEmail.Count -gt 0) {
                Write-Verbose "Found $($studentsNoEmail.Count) students requiring email updates."
                
                # Add emails to students
                $results = Add-EmailToStudents -Students $studentsNoEmail
                
                # Report results
                Write-Verbose "Email update process completed:"
                Write-Verbose "  - Successfully updated: $($results.SuccessfulUpdates.Count) students"
                Write-Verbose "  - Failed updates: $($results.FailedUpdates.Count) students"
                
                if ($results.FailedUpdates.Count -gt 0) {
                    Write-Warning "Some updates failed. Check the logs for details."
                }
                
                return $results
            } else {
                Write-Verbose "No students need email updates."
                return $null
            }
        }
        catch {
            Write-Error "An error occurred during the email update process: $_"
            throw $_
        }
    }
}

# Example execution with error handling
try {
    Process-StudentEmails -Verbose
}
catch {
    Write-Error "Failed to process student emails: $_"
}
