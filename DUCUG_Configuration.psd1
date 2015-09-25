@{
    AllNodes = @(
        @{
            NodeName = '*';                                               ## Settings apply to all nodes, but can be overridden by the individual node
            CertificateFile = '\\LABHOST\Resources\LabClient.cer';        ## Credential encryption certificate public key
            Thumbprint = '599E0BDA95ADED538154DC9FA6DE94920424BCB1';      ## Credential encryption certificate thumbprint
            MediaPath = '\\LABHOST\Resources\Media\CitrixXenDesktop76';   ## Node-accessible Citrix XenDesktop 7.6 installation media path
        }                                                                 
        @{ NodeName = 'EUDBLS01';   Role = 'Licensing'; }                 
        @{ NodeName = 'DUCUG-SF01'; Role = 'Storefront','Director'; }     ## Composite resource installs Director on all Storefront servers
        @{ NodeName = 'DUCUG-XC01'; Role = 'Controller','Studio'; }       ## Composite resource installs Studio on all Controller servers
        @{ NodeName = 'DUCUG-XC02'; Role = 'Controller','Studio'; }
        @{ NodeName = 'DUCUG-SH01'; Role = 'SessionVDA'; MachineCatalog = 'Manual Server Catalog'; DeliveryGroup = 'Server Desktop'; }
        @{ NodeName = 'DUCUG-SH02'; Role = 'SessionVDA'; MachineCatalog = 'Manual Server Catalog'; DeliveryGroup = 'Server Desktop'; }
    )
    NonNodeData = @{
        XenDesktop = @{
            
            Site = @{
                Name = 'DuCUGDemo';
                DomainName = 'lab.local';
                DatabaseServer = 'DUCUG-DB01.lab.local';
                Administrators = 'XenDesktop Admins','Domain Admins';
            }
            
            Controller = @{
                PfxCertificatePath = '\\LABHOST\Resources\star.lab.local.pfx';
                PfxCertificateThumbprint = '72825832F6FCE7A53C0F72019921A51380238ADB';
            }
            
            MachineCatalogs = @(
                @{
                    Name = 'Manual Server Catalog';
                    Description = 'Manual RDS Session Hosts';
                }
            )
            
            DeliveryGroups = @(
                @{
                    Name = 'Server Desktop';
                    DisplayName = 'Standard Desktop';
                    Description = 'Published XenApp Desktop';
                    Users = 'Domain Users';
                }
            )
            
            Licensing = @{
                LicenseFilePath = '\\LABHOST\Resources\EUDBLS01_XenDesktop_PLAT_PartnerUse_15022016.lic';
            }
            
            Storefront = @{
                PfxCertificatePath = '\\LABHOST\\Resources\star.lab.local.pfx';
                PfxCertificateThumbprint = '72825832F6FCE7A53C0F72019921A51380238ADB';
            }

        } #end XenDesktop
    } #end nonNodeData
}
