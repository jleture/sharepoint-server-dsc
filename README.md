# sharepoint-server-dsc

PowerShell DSC scripts to install **SharePoint**, **SQL Server**, **Office Online Server** and **SharePoint CU**.

[DSC](https://learn.microsoft.com/en-us/powershell/dsc/overview?view=dsc-1.1) is a management platform in PowerShell that enables management of IT and development infrastructure with configuration as code.

## History

| Version | Date | Comments |
| - | - | - |
| 1.0 | 2023-07-21 | Initial release
| 1.1 | 2023-09-16 | Add a script to create service accounts

## Files
| File | Role |
| - | - |
| **CreateAccounts.ps1** | PowerShell script to create service accounts |
| **SQLServer2019.ps1** | DSC to install SQL Server 2019 |
| **SharePoint2019.ps1** | DSC to install SharePoint 2019 |
| **SharePoint2019v2.ps1** | DSC to install SharePoint 2019 with CU before creating a new farm |
| **OOS2019.ps1** | DSC to install Office Online Server 2019 |
| **SharePoint2019UPA.ps1** | DSC to add 'User Profile Application' to an existing SharePoint 2019 |
| **CreateUPA.ps1** | Classic PowerShell script to create 'User Profile Application' in case DSC is not working |
| **SharePoint2019CU.ps1** | DSC to install a cumulative update to an existing SharePoint 2019 |


## Prerequisites

### [SQL Server](https://github.com/dsccommunity/SQLServerDSC/)
~~~powershell
Install-Module -Name SQLServerDSC
Install-Module -Name DBATools
~~~

> Create 1 new drive (**D** for data)

### [SharePoint](https://github.com/dsccommunity/SharePointDsc)
~~~powershell
Install-Module -Name SharePointDSC
Install-Module -Name xDownloadFile
~~~
> Create 2 new drives (**D** for data and **L** for logs)


### [Office Online Server](https://github.com/dsccommunity/OfficeOnlineServerDsc/)
> Download http://www.powershellgallery.com/packages/OfficeOnlineServerDsc/

> Extract it to C:\Program Files\WindowsPowerShell\Modules\OfficeOnlineServerDsc\1.5.0

~~~powershell
Get-DscResource -Module OfficeOnlineServerDsc
~~~

> Create 1 new drive (**D** for data)

### .NET Framework 3.5
~~~powershell
Install-WindowsFeature Net-Framework-Core -source D:\Sources\sxs
~~~

> `sxs` folder can be found in a Windows Server ISO

### ISO
- SQL Sever 2019 (`D:\Sources\SQLServer2019`)
- SharePoint 2019 (`D:\Sources\SharePoint2019`)
- SharePoint 2019 Entreprise product key
- SharePoint 2019 Language Pack French (`D:\Sources\fr_sharepoint_server_2019_language_pack_x64_88abf125.exe`)
- Office Online Server 2019 (`D:\Sources\OfficeOnlineServer\2019`)
- Office Online Server 2019 Language Pack French (`D:\Sources\OfficeOnlineServer\fr_office_online_server_language_pack_last_updated_november_2018_x64_b65c95d5.exe`)

### Accounts
| Login | Role |
| - | - |
| AD\dev_sql_Install | SQL Server install account |
| AD\dev_sql_Services | SQL Server service account |
| AD\dev_shp_Farm | SharePoint farm account |
| AD\dev_shp_Install | SharePoint install account |
| AD\dev_shp_Pool | SharePoint web application pool account |
| AD\dev_shp_Srv | SharePoint service account |
| AD\dev_shp_Sync | AD user synchronization account |
| AD\dev_shp_SU | SharePoint Super User account |
| AD\dev_shp_SR | SharePoint Super Reader account |


## Samples

~~~powershell
.\CreateAccounts.ps1

.\SQLServer2019.ps1 -SqlInstallCredential AD\dev_sql_Install -SqlServiceCredential AD\dev_sql_Services

.\SharePoint2019.ps1 -FarmAccount AD\dev_shp_Farm -SetupAccount AD\dev_shp_Install
-WebPoolManagedAccount AD\dev_shp_Pool -ServicePoolManagedAccount AD\dev_shp_Srv -SyncAccount
AD\dev_shp_Sync -Passphrase "P@ssphras3"

.\SharePoint2019UPA.ps1 -SPSetupAccount AD\dev_shp_Install -SyncAccount AD\dev_shp_Sync

.\OOS2019.ps1 -InternalUrl "http://dev-office.local"

.\SharePoint2019CU.ps1 -SetupAccount AD\dev_shp_Install
~~~
