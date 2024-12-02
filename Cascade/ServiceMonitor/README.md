# Service Monitor PowerShell Module

This PowerShell module provides functionality to monitor services across multiple servers, automatically attempt to restart stopped services, and send notifications to administrators.

## Features

- Monitor multiple services across multiple servers
- Automatic service restart attempts when services stop
- Email notifications for service stops, restart attempts, and successful restarts
- Configurable monitoring interval

## Requirements

- PowerShell 5.1 or higher
- Appropriate permissions to monitor and restart services on target servers
- SMTP server for sending email notifications

## Installation

1. Copy the module folder to one of your PowerShell module directories:
   ```powershell
   $env:PSModulePath -split ';'
   ```
2. Import the module:
   ```powershell
   Import-Module ServiceMonitor
   ```

## Usage

```powershell
# Example usage
Watch-ServiceStatus -ComputerNames @('server1', 'server2') `
                   -ServiceNames @('spooler', 'wuauserv') `
                   -AdminEmail 'admin@yourdomain.com' `
                   -SmtpServer 'smtp.yourdomain.com' `
                   -FromEmail 'monitoring@yourdomain.com' `
                   -CheckInterval 300
```

### Parameters

- `ComputerNames`: Array of server names to monitor
- `ServiceNames`: Array of service names to monitor
- `AdminEmail`: Email address to receive notifications
- `SmtpServer`: SMTP server for sending notifications
- `FromEmail`: Email address to send notifications from
- `CheckInterval`: Time in seconds between service checks (default: 300)
