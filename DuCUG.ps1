if (-not $credential) { $credential = Get-Credential -UserName 'LAB\XDA' -Message 'Enter XenDesktop administrator account/password' }
if (-not $pfxCredential) { $pfxCredential = Get-Credential -UserName Pfx -Message 'Enter Pfx certificate password' }

## Find the Hyper-V host's name
$hypervHostname = (Get-Item 'HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters').GetValue('HostName');

## Import the DSC configuration
. "\\$hypervHostname\Resources\DuCUGXD7Lab_Composite.ps1";

$ducugLabParameters = @{
    OutputPath = "\\$hypervHostname\Resources\DSCConfigurations\";
    ConfigurationData = "\\$hypervHostname\Resources\DUCUGXD7Lab_Configuration.psd1";
    Credential = $credential;
    PfxCertificateCredential = $pfxCredential;
}
## Invoke the configuration using the environment data
DuCUG_XenDesktop76 @ducugLabParameters;

### Prove there is no "smoke and mirrors!"

## Start the PUSH deployment
Start-DscConfiguration -Path "\\$hypervHostname\Resources\DSCConfigurations\" -Wait -Verbose;

## Start the StoreFront configuration
$scriptBlock = {

    . 'C:\Program Files\Citrix\Receiver StoreFront\Scripts\ImportModules.ps1';
    $storefrontParams = @{
        HostBaseUrl = 'https://storefront.lab.local';
        FarmName = 'DuCUGDemo';
        Port = 80;
        TransportType = 'HTTP';
        SslRelayPort = 443;
        Servers = 'DUCUG-XC01.lab.local','DUCUG-XC02.lab.local';
        LoadBalance = $true;
        FarmType = 'XenDesktop';
        StoreFriendlyName ='DuCUGDemo';
    }
    Set-DSInitialConfiguration @storefrontParams;
}

Invoke-Command -ComputerName DUCUG-SF01 -ScriptBlock $scriptBlock;
