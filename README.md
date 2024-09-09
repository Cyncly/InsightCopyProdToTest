# CopyProdToTest
Automation of Copying an Insight (and optionally Construct) Database from one environment (e.g. "Prod") to another (e.g. "Test" including adjustments for the target environment

## Overview
The solution described here is based on Powershell and SQL Scripts. The main script is named "CopyProdToTest.ps1".
The script runs without any user interaction. All parameters are read from a config file and customized SQL script files. Thus, the script can be started automatically by a scheduled task with all output being redirected to a logfile.
These are the main steps of the script (many of them are optional):
- Take backups of the current Insight and Construct source databases
 -Stop Insight services in the target environment
- Kill all Sessions on target databases
- Drop target databases
- Restore target databases from the backups
- Run "New installation" SQL Scripts on Insight target database
- Adjust Settings and parameters in the Insight database (like paths, URLs, Email addresses etc.)
- Copy Reporting Services Reports from Source to Target server resp. subfolder
- Reduce the size of the target database by running specific "purge" procedures or truncating specific tables
- Create a backup of the target database
- Reboot target Construct Application Workstation
- Start Insight services in the target environment

## Prerequisites
The script can be started on any Windows computer, but it is recommended to start it on the target database server.
The Powershell module "SQLServer" is required for the script.
To install the SqlServer PowerShell module from the PowerShell Gallery open PowerShell (either PowerShell.exe or the PowerShell ISE) as Administrator and run the following command:
```Install-Module -Force -Allowclobber SqlServer```
If `Install-Module` leads to error messages like "Unable to download from URI 'https://go.microsoft.com...", probably this Microsoft article might help:
https://answers.microsoft.com/en-us/windows/forum/windows_7-performance/trying-to-install-program-using-powershell-and/4c3ac2b2-ebd4-4b2a-a673-e283827da143

The "CopyProdToTest" script must be run by a domain user account with following access rights:
- SQL Server "sysadmin" role in both SQL Server instances
- Member of the local Windows group "Administrators" on the Inresponse host(s) for the target environment
- If the firewall is active on the Inresponse host(s) for the target environment, make sure to enable the predefined rules "Remote Service Management (RPC)" and "Remote Service Management (RPC-EPMAP)"
- Read/Write access to a shared folder that can be used for the database backup. Also, the SQL Server service accounts of both SQL Server instances need to have read and write access to this folder.

If the option to copy Reporting Services Reports is used, the Powershell Module "ReportingServicesTools" is also required. To install this module run the following command from a Powershell as Administrator:
```Install-Module -Force -Allowclobber ReportingServicesTools```


## Get Started

## Run CopyProdToTest