﻿configuration DuCUG_XenDesktop76 {
    param (
        ## Installation Active Directory account
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $Credential,
        ## Storefront .Pfx certificate password
        [Parameter(Mandatory)] [System.Management.Automation.PSCredential] $PfxCertificateCredential
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xCredSSP, CitrixXenDesktop7, xWebAdministration, cPfxCertificate;

    ## Need delegated access to all Controllers (NetBIOS and FQDN) and the database server
    $credSSPDelegatedComputers = $ConfigurationData.AllNodes | Where Role -eq 'Controller' | ForEach {
        Write-Output $_.NodeName
        if ($_.NodeName.Contains('.')) {
            ## Output NetBIOS name
            Write-Output ('{0}' -f $_.Split('.')[0]);
        }
        else {
            ## Output FQDN
            Write-Output ('{0}.{1}' -f $_.NodeName, $ConfigurationData.NonNodeData.XenDesktop.Site.DomainName);
        }
    };
    $credSSPDelegatedComputers += $ConfigurationData.NonNodeData.XenDesktop.Site.DatabaseServer;

    $SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
    <## Determine whether database names have been specified in $ConfigurationData
        and default to <SiteName>Site, <SiteName>Logging and <SiteName>Monitor if not ##>
    $siteDatabaseName = "$($siteName)Site";
    if ($ConfigurationData.NonNodeData.XenDesktop.Site.SiteDatabaseName) {
        $siteDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.SiteDatabaseName;
    }
    $loggingDatabaseName = "$($siteName)Logging";
    if ($ConfigurationData.NonNodeData.XenDesktop.Site.LoggingDatabaseName) {
        $loggingDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.LoggingDatabaseName;
    }
    $monitorDatabaseName = "$($siteName)Monitor";
    if ($ConfigurationData.NonNodeData.XenDesktop.Site.MonitorDatabaseName) {
        $monitorDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.MonitorDatabaseName;
    }

#region Licensing

    node $AllNodes.Where{ $_.Role -eq 'Licensing' }.NodeName {
        WindowsFeature RDSLicensing {
            Name = 'RDS-Licensing';
        }
        
        WindowsFeature RDSLicensingUI {
            Name = 'RDS-Licensing-UI';
        }
        
        XD7Feature XD7LicenseServer {
            <# Issue with version on XD 7.6 media! #>
            Role = 'Licensing';
            SourcePath = $Node.MediaPath;
        }

        File XDLicenseFile {
            Type = 'File';
            SourcePath = $ConfigurationData.NonNodeData.XenDesktop.Licensing.LicenseFilePath;
            DestinationPath = "${env:ProgramFiles(x86)}\Citrix\Licensing\MyFiles";
            DependsOn = '[XD7Feature]XD7LicenseServer';
        }

    }

#endregion Licensing

#region XenDesktop Controllers

    node $AllNodes.Where{ $_.Role -eq 'Controller' }.NodeName {
        
        xCredSSP CredSSPServer {
            Role = 'Server';
        }

        xCredSSP CredSSPClient {
            Role = 'Client';
            DelegateComputers = $credSSPDelegatedComputers;
        }
        
        XD7Feature XD7Controller {
            Role = 'Controller';
            SourcePath = $Node.MediaPath;
        }

        File StarLabLocalPfx {
            DestinationPath = "$env:SystemDrive\Source\star.lab.local.pfx";
            SourcePath = $ConfigurationData.NonNodeData.XenDesktop.Controller.PfxCertificatePath;
            Type = 'File';
        }

        cPfxCertificate StarLabLocal {
            Thumbprint = $ConfigurationData.NonNodeData.XenDesktop.Controller.PfxCertificateThumbprint;
            Location = 'LocalMachine';
            Store = 'My';
            Path = "$env:SystemDrive\Source\star.lab.local.pfx";
            Credential = $PfxCertificateCredential;
            DependsOn = '[File]StarLabLocalPfx';
        }

        <#! Restart after controller install #>
    }
    
    node ($AllNodes | Where Role -eq 'Controller' | Select -First 1).NodeName {
        
        XD7Database XD7SiteDatabase {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            DatabaseServer = $ConfigurationData.NonNodeData.XenDesktop.Site.DatabaseServer;
            DatabaseName = $siteDatabaseName;
            Credential = $Credential;
            DataStore = 'Site';
            DependsOn = '[XD7Feature]XD7Controller';
        }

        XD7Database XD7SiteLoggingDatabase {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            DatabaseServer = $ConfigurationData.NonNodeData.XenDesktop.Site.DatabaseServer;
            DatabaseName = $loggingDatabaseName;
            Credential = $Credential;
            DataStore = 'Logging';
            DependsOn = '[XD7Feature]XD7Controller';
        }

        XD7Database XD7SiteMonitorDatabase {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            DatabaseServer = $ConfigurationData.NonNodeData.XenDesktop.Site.DatabaseServer;
            DatabaseName = $monitorDatabaseName;
            Credential = $Credential;
            DataStore = 'Monitor';
            DependsOn = '[XD7Feature]XD7Controller';
        }
        
        XD7Site XD7Site {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            DatabaseServer = $ConfigurationData.NonNodeData.XenDesktop.Site.DatabaseServer;
            SiteDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.SiteDatabaseName;
            LoggingDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.LoggingDatabaseName;
            MonitorDatabaseName = $ConfigurationData.NonNodeData.XenDesktop.Site.MonitorDatabaseName;
            Credential = $Credential;
            DependsOn = '[XD7Feature]XD7Controller','[XD7Database]XD7SiteDatabase','[XD7Database]XD7SiteLoggingDatabase','[XD7Database]XD7SiteMonitorDatabase';
        }

        XD7SiteLicense XD7SiteLicense {
            LicenseServer = ($ConfigurationData.AllNodes | Where Role -eq 'Licensing' | Select -First 1).NodeName;
            Credential = $Credential;
            DependsOn = '[XD7Site]XD7Site';
        }

        XD7Administrator DomainAdmins {
            Name = 'LAB\Domain Admins';
            Credential = $Credential;
        }

        XD7Role DomainAdminsFullAdministrator {
            Name = 'Full Administrator';
            Members = 'LAB\Domain Admins';
            Credential = $Credential;
        }

        XD7Catalog ManualCatalog {
            Name = 'Manual';
            Description = 'Manual machine catalog provisioned by DSC';
            Allocation = 'Random';
            Persistence = 'Local';
            Provisioning = 'Manual';
            IsMultiSession = $true;
            Credential = $Credential;
            DependsOn = '[XD7Site]XD7Site';
        }

        XD7CatalogMachine ManualCatalogMachines {
            Name = 'Manual';
            Members = $ConfigurationData.AllNodes | Where Role -eq 'SessionVDA' | % { $_.NodeName };
            Credential = $Credential;
            DependsOn = '[XD7Catalog]ManualCatalog';
        }

        XD7DesktopGroup ManualDesktopGroup {
            Name = 'Manual';
            Description = 'Manual delivery group provisioned by DSC';
            DeliveryType = 'DesktopsAndApps';
            DesktopType = 'Shared';
            IsMultiSession = $true;
            Credential = $Credential;
            DependsOn = '[XD7Site]XD7Site';
        }

        XD7DesktopGroupMember ManualDesktopGroupMachines {
            Name = 'Manual';
            Members = $ConfigurationData.AllNodes | Where Role -eq 'SessionVDA' | % { $_.NodeName };
            Credential = $Credential;
            DependsOn = '[XD7Catalog]ManualCatalog','[XD7DesktopGroup]ManualDesktopGroup';
        }

        XD7EntitlementPolicy ManualDesktopGroupEntitlement {
            DeliveryGroup = 'Manual';
            EntitlementType = 'Desktop';
            Credential = $Credential;
            DependsOn = '[XD7DesktopGroup]ManualDesktopGroup';
        }

        XD7AccessPolicy SessionVDADirect {
            DeliveryGroup = 'Manual';
            AccessType = 'Direct';
            Credential = $Credential;
            DependsOn = '[XD7DesktopGroup]ManualDesktopGroup';
            IncludeUsers = 'LAB\XenDesktop Users';
        }

        XD7AccessPolicy SessionVDAAccessGateway {
            DeliveryGroup = 'Manual';
            AccessType = 'AccessGateway';
            Enabled = $false;
            Credential = $Credential;
            DependsOn = '[XD7DesktopGroup]ManualDesktopGroup';
            IncludeUsers = 'LAB\XenDesktop Users';
        }
    }
     
    node ($AllNodes | Where Role -eq 'Controller' | Select -Skip 1 | ForEach { $_.NodeName } ) {
        XD7WaitForSite WaitForSite {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            ExistingControllerName = ($ConfigurationData.AllNodes | Where Role -eq 'Controller' | Select -First 1).NodeName;
            Credential = $Credential;
            DependsOn = '[XD7Feature]XD7Controller';
        }
        
        XD7Controller XD7ControllerJoin {
            SiteName = $ConfigurationData.NonNodeData.XenDesktop.Site.Name;
            ExistingControllerName = ($ConfigurationData.AllNodes | Where Role -eq 'Controller' | Select -First 1).NodeName;
            Credential = $Credential;
            DependsOn = '[XD7Feature]XD7Controller','[XD7WaitForSite]WaitForSite';
        }
    }

#endregion XenDesktop Controllers

#region Studio

    node $AllNodes.Where{ $_.Role -eq 'Studio' }.NodeName {
        XD7Feature XD7Studio {
            Role = 'Studio';
            SourcePath = $Node.MediaPath;
        }
    }

#endregion Studio

#region StoreFront

    node $AllNodes.Where{ $_.Role -eq 'Storefront' }.NodeName {
        
        $features = @(
            'NET-Framework-45-ASPNET',
            'Web-Server',
            'Web-Common-Http',
            'Web-Default-Doc',
            'Web-Http-Errors',
            'Web-Static-Content',
            'Web-Http-Redirect',
            'Web-Http-Logging',
            'Web-Filtering',
            'Web-Basic-Auth',
            'Web-Windows-Auth',
            'Web-Net-Ext45',
            'Web-AppInit',
            'Web-Asp-Net45',
            'Web-ISAPI-Ext',
            'Web-ISAPI-Filter',
            'Web-Mgmt-Console',
            'Web-Scripting-Tools'
        )
        foreach ($feature in $features) {
            WindowsFeature $feature {
                Name = $feature;
                Ensure = 'Present';
            }
        }

        File StarLabLocalPfx {
            DestinationPath = "$env:SystemDrive\Source\star.lab.local.pfx";
            SourcePath = $ConfigurationData.NonNodeData.XenDesktop.StoreFront.PfXcertificatePath;
            Type = 'File';
        }

        cPfxCertificate StarLabLocal {
            Thumbprint = $ConfigurationData.NonNodeData.XenDesktop.StoreFront.PfXcertificateThumbprint;
            Location = 'LocalMachine';
            Store = 'My';
            Path = "$env:SystemDrive\Source\star.lab.local.pfx";
            Credential = $PfxCertificateCredential;
            DependsOn = '[File]StarLabLocalPfx';
        }
        
        XD7Feature XD7StoreFront {
            Role = 'Storefront';
            SourcePath = $Node.MediaPath;
            DependsOn = '[WindowsFeature]Web-Server';
        }

        xWebSite DefaultWebSite {
            Name = 'Default Web Site';
            PhysicalPath = 'C:\inetpub\wwwroot';
            BindingInfo = @(
                MSFT_xWebBindingInformation  { Protocol = 'HTTPS'; Port = 443; CertificateThumbprint = 'A4D8B8E3B1B6910CB54C3B6CDFD6478914327850'; CertificateStoreName = 'My'; }
                MSFT_xWebBindingInformation  { Protocol = 'HTTP'; Port = 80; }
            )
            DependsOn = '[WindowsFeature]Web-Server','[cPfxCertificate]StarLabLocal';
        }
    }

#endregion StoreFront

#region Director

    node $AllNodes.Where{ $_.Role -eq 'Director' }.NodeName {
        XD7Feature XD7Director {
            Role = 'Director';
            SourcePath = $Node.MediaPath;
        }

        xWebConfigKeyValue ServiceAutoDiscovery {
            ConfigSection = 'AppSettings';
            Key = 'Service.AutoDiscoveryAddresses';
            Value = ($ConfigurationData.AllNodes | Where Role -eq 'Controller' | Select -First 1).NodeName;
            IsAttribute = $false;
            WebsitePath = 'IIS:\Sites\Default Web Site\Director';
        }
    }

#endregion Director

#region RDSH/VDA

    node $AllNodes.Where{ $_.Role -eq 'SessionVDA' }.NodeName {
        foreach ($feature in @('RDS-RD-Server', 'Remote-Assistance', 'Desktop-Experience')) {
            WindowsFeature $feature.Replace('-','') {
                Name = $feature;
                Ensure = 'Present';
            }
        }
        
        XD7VDAFeature XD7SessionVDA {
            Role = 'SessionVDA';
            SourcePath = $Node.MediaPath;
            DependsOn = '[WindowsFeature]RDSRDServer';
        }

        foreach ($controller in ($ConfigurationData.AllNodes | Where Role -eq 'Controller' | ForEach { $_.NodeName })) {
            XD7VDAController "XD7VDA$($controller)" {
                Name = $controller;
                DependsOn = '[XD7VDAFeature]XD7SessionVDA';
            }
        }

        Registry RDSLicenseServer {
            Key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\TermService\Parameters\LicenseServers';
            ValueName = 'SpecifiedLicenseServers';
            ValueData = $ConfigurationData.AllNodes | Where Role -eq 'Licensing' | ForEach { $_.NodeName }
            ValueType = 'MultiString';
        }

        Registry RDSLicensingMode {
            Key = 'HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Terminal Server\RCM\Licensing Core';
            ValueName = 'LicensingMode';
            ValueData = '4'; # 2 = Per Device, 4 = Per User
            ValueType = 'Dword';
        }

        <# Set RDS License Server #>
    }

#endregion RDSH/VDA

} #end configuration
