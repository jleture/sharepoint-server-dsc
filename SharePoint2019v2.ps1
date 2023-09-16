param (
    [Parameter(Mandatory = $true)] [ValidateNotNullorEmpty()] [PSCredential] $FarmAccount,
    [Parameter(Mandatory = $true)] [ValidateNotNullorEmpty()] [PSCredential] $SetupAccount,
    [Parameter(Mandatory = $true)] [ValidateNotNullorEmpty()] [PSCredential] $WebPoolManagedAccount,
    [Parameter(Mandatory = $true)] [ValidateNotNullorEmpty()] [PSCredential] $ServicePoolManagedAccount,
    [Parameter(Mandatory = $true)] [ValidateNotNullorEmpty()] [PSCredential] $SyncAccount,
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [PSCredential] $Passphrase,
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [string] $Computer = "localhost",
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [string] $SqlInstance = "DEV-SQL\SHAREPOINT",
    [Parameter(Mandatory = $false)] [ValidateNotNullorEmpty()] [string] $ProductKey = "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
)

[string]$Scriptpath = $MyInvocation.MyCommand.Path
[string]$Dir = Split-Path $Scriptpath
Set-Location $Dir

Configuration SharePoint2019v2
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc

    node $Computer
    {
        SPInstallPrereqs InstallPrereqs {
            IsSingleInstance     = "Yes"
            Ensure               = "Present"
            InstallerPath        = "D:\Sources\SharePoint2019\prerequisiteinstaller.exe"
            OnlineMode           = $true
            PsDscRunAsCredential = $SetupAccount
        }
		
        SPInstall InstallSharePoint {
            IsSingleInstance = "Yes"
            Ensure           = "Present"
            BinaryDir        = "D:\Sources\SharePoint2019"
            ProductKey       = $ProductKey
            DependsOn        = "[SPInstallPrereqs]InstallPrereqs"
        }

        SPProductUpdate ProductUpdate1 {
            SetupFile            = "D:\Sources\SharePoint2019\Updates\wssloc2019-kb5002422-fullfile-x64-glb.exe"
            ShutdownServices     = $true
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPInstall]InstallSharePoint"
        }

        SPProductUpdate ProductUpdate2 {
            SetupFile            = "D:\Sources\SharePoint2019\Updates\sts2019-kb5002436-fullfile-x64-glb.exe"
            ShutdownServices     = $true
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPProductUpdate]ProductUpdate1"
        }
		
        Script ExtractBinariesFR {
            GetScript  = {
                @{
                    GetScript  = $GetScript
                    SetScript  = $SetScript
                    TestScript = $TestScript
                }
            }
            SetScript  = {
                D:\Sources\fr_sharepoint_server_2019_language_pack_x64_88abf125.exe /extract:D:\Sources\SharePoint2019\lang\fr
                Start-Sleep 5
            }
            TestScript = {
                Test-Path "D:\Sources\SharePoint2019\lang\fr"
            }
            DependsOn  = "[SPProductUpdate]ProductUpdate1"
        }
		
        SPInstallLanguagePack InstallLanguagePackFR {
            BinaryDir            = "D:\Sources\SharePoint2019\lang\fr"
            Ensure               = "Present"
            DependsOn            = "[Script]ExtractBinariesFR"
            PsDscRunAsCredential = $SetupAccount
        }
		
        SPFarm CreateSPFarm {
            IsSingleInstance          = "Yes"
            Ensure                    = "Present"
            DatabaseServer            = $SqlInstance
            FarmConfigDatabaseName    = "SP_Config"
            Passphrase                = $Passphrase
            FarmAccount               = $FarmAccount
            PsDscRunAsCredential      = $SetupAccount
            AdminContentDatabaseName  = "SP_AdminContent"
            CentralAdministrationPort = 4321
            RunCentralAdmin           = $true
            ServerRole                = "SingleServerFarm"
            DeveloperDashboard        = "On"
            DependsOn                 = "[SPInstallLanguagePack]InstallLanguagePackFR"
        }

        SPManagedAccount ServicePoolManagedAccount {
            AccountName          = $ServicePoolManagedAccount.UserName
            Account              = $ServicePoolManagedAccount
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPManagedAccount WebPoolManagedAccount {
            AccountName          = $WebPoolManagedAccount.UserName
            Account              = $WebPoolManagedAccount
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDiagnosticLoggingSettings ApplyDiagnosticLogSettings {
            IsSingleInstance                            = "Yes"
            PsDscRunAsCredential                        = $SetupAccount
            LogPath                                     = "D:\LOGS\ULS"
            LogSpaceInGB                                = 8
            AppAnalyticsAutomaticUploadEnabled          = $false
            CustomerExperienceImprovementProgramEnabled = $true
            DaysToKeepLogs                              = 5
            DownloadErrorReportingUpdatesEnabled        = $false
            ErrorReportingAutomaticUploadEnabled        = $false
            ErrorReportingEnabled                       = $false
            EventLogFloodProtectionEnabled              = $true
            EventLogFloodProtectionNotifyInterval       = 5
            EventLogFloodProtectionQuietPeriod          = 2
            EventLogFloodProtectionThreshold            = 5
            EventLogFloodProtectionTriggerPeriod        = 2
            LogCutInterval                              = 15
            LogMaxDiskSpaceUsageEnabled                 = $true
            ScriptErrorReportingDelay                   = 30
            ScriptErrorReportingEnabled                 = $true
            ScriptErrorReportingRequireAuth             = $true
            DependsOn                                   = "[SPFarm]CreateSPFarm"
        }

        SPUsageApplication UsageApplication {
            Name                  = "Usage Service Application"
            DatabaseName          = "SP_Usage"
            UsageLogCutTime       = 5
            UsageLogLocation      = "D:\LOGS\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SetupAccount
            DependsOn             = "[SPFarm]CreateSPFarm"
        }

        SPStateServiceApp StateServiceApp {
            Name                 = "State Service Application"
            DatabaseName         = "SP_State"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDistributedCacheService EnableDistributedCache {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SetupAccount
            CreateFirewallRules  = $true
            DependsOn            = @('[SPFarm]CreateSPFarm', '[SPManagedAccount]ServicePoolManagedAccount')
        }

        SPWebApplication IntranetWebApp {
            Name                   = "Intranet"
            ApplicationPool        = "Intranet"
            ApplicationPoolAccount = $WebPoolManagedAccount.UserName
            AllowAnonymous         = $false
            DatabaseName           = "SP_Content_Intranet"
            WebAppUrl              = "http://intranet.ad.local"
            HostHeader             = "intranet.ad.local"
            Port                   = 80
            PsDscRunAsCredential   = $SetupAccount
            DependsOn              = "[SPManagedAccount]WebPoolManagedAccount"
        }

        SPCacheAccounts IntranetWebAppCache {
            WebAppUrl            = "http://intranet.ad.local"
            SuperUserAlias       = "AD\dev_shp_SU"
            SuperReaderAlias     = "AD\dev_shp_SR"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPWebApplication]IntranetWebApp"
        }

        SPSite IntranetSite {
            Url                  = "http://intranet.ad.local"
            OwnerAlias           = "AD\dev_shp_Pool"
            Name                 = "Intranet DEV"
            Template             = "SITEPAGEPUBLISHING#0"
            Language             = 1033
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPWebApplication]IntranetWebApp"
        }

        SPServiceInstance ClaimsToWindowsTokenServiceInstance {
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance SecureStoreServiceInstance {
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance ManagedMetadataServiceInstance {
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance SearchServiceInstance {
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        $serviceAppPoolName = "SharePoint Service Applications"
        SPServiceAppPool MainServiceAppPool {
            Name                 = $serviceAppPoolName
            ServiceAccount       = $ServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPManagedMetaDataServiceApp ManagedMetadataServiceApp {
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SetupAccount
            ApplicationPool      = $serviceAppPoolName
            DatabaseName         = "SP_MMS"
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPSearchServiceApp SearchServiceApp {
            Name                 = "Search Service Application"
            DatabaseName         = "SP_Search"
            ApplicationPool      = $serviceAppPoolName
            PsDscRunAsCredential = $SetupAccount
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName                    = $Computer
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser        = $true
        }
    )
}

SharePoint2019v2 -ConfigurationData $config -OutputPath $Dir
Start-DscConfiguration -Path $Dir -Verbose -Wait -Force -ComputerName $Computer -ErrorAction Stop

.\CreateUPA.ps1