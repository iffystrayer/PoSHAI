$clientid = 'd52055d2-71f4-422a-90d1-b759aee35364'
$tenantID = 'c709011f-bc71-4391-9032-a716dcc728ed'
$Certificate = "BB86D1EAC22F6BFEB487FE8C6830BCE3A737B995"

$scopes = @(
    "Directory.Read.All"
    "Group.Read.All"
    "Mail.ReadWrite"
    "People.Read.All"
    "Sites.Manage.All"
    "User.Read.All"
    "User.ReadWrite.All"
    "AuditLog.Read.All"
)
 
Connect-MgGraph -ClientId $clientid -TenantId $tenantID -CertificateThumbprint $Certificate

#Get-MgProfile
 
Get-MgContext | Select-Object -ExpandProperty Scopes
Connect-MgGraph -ClientId $clientid -TenantId $tenantID -CertificateThumbprint $Certificate

#Get-MgProfile
 
Get-MgContext | Select-Object -ExpandProperty Scopes