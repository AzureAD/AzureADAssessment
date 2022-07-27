# Microsoft Azure AD Assessment

[![PSGallery Version](https://img.shields.io/powershellgallery/v/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Platform](https://img.shields.io/powershellgallery/p/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Platform)](https://www.powershellgallery.com/packages/AzureADAssessment)

## Assessor Guide
If you are a Microsoft employee or partner performing the assessment for a customer please see the Wiki for the [Assessment Guide](https://github.com/AzureAD/AzureADAssessment/wiki). 

## Install from the PowerShell Gallery
If you run into any errors please see the [FAQ section](#faq) at the end of this document.

```PowerShell
Install-Module AzureADAssessment -Force -Scope CurrentUser

## If you have already installed the module, run the following instead to ensure you have the latest version.
Update-Module AzureADAssessment -Force -Scope CurrentUser
```

## Run the Data Collection
Data collection from Azure AD can be run from any client with access to Azure AD. However, data collection from hybrid components such as AD FS, AAD Connect, etc. are best run locally on those servers. The AAD Connect data collection needs to be run on both Primary and Staging servers.

Verify that you have authorized credentials to access these workloads:
* Azure Active Directory as Global Administrator or Global Reader
* Domain or local administrator access to ADFS Servers
* Domain or local administrator access to Azure AD Proxy Connector Servers
* Domain or local administrator access to Azure AD Connect Server (Primary)
* Domain or local administrator access to Azure AD Connect Server (Staging Server)

> When Connecting for the first time you will be asked to consent to the permissions needed by the assessment. An admin will be needed to provide consent.

Run following commands to produce a package of all the Azure AD data necessary to complete the assessment.
```PowerShell
## Authenticate using a Global Admin or Global Reader account.
Connect-AADAssessment

## Export data to "C:\AzureADAssessment" into a single output package.
Invoke-AADAssessmentDataCollection
```

On each server running hybrid components, install the same module and run the Invoke-AADAssessmentHybridDataCollection command.
```PowerShell
## Export Data to "C:\AzureADAssessment" into a single output package.
Invoke-AADAssessmentHybridDataCollection
```

The output package will be named according to the following pattern: `AzureADAssessmentData-<TenantDomain>.aad`

Once data collection is complete, provide the output packages to whoever is completing the assessment. Please avoid making any changes to the generated files including the name of the file.

## Complete Assessment Reports
If you are generating and reviewing the output yourself, please see the Wiki for the [Assessment Guide](https://github.com/AzureAD/AzureADAssessment/wiki).

## <h2 id="faq">Frequently Asked Questions</h2>
### I don't have internet access to install the module on AAD Connect, ADFS, App Proxy servers
To collect data from hybrid components (such as AAD Connect, AD FS, AAD App Proxy), you can export a portable version of this module that can be easily copied to servers with no internet connectivity.
```PowerShell
## Export Portable Module to "C:\AzureADAssessment".
Export-AADAssessmentPortableModule "C:\AzureADAssessment"
```

On each server running hybrid components, copy the module file "AzureADAssessmentPortable.psm1" and import it there.
```PowerShell
## Import the module on each server running hybrid components.
Import-Module "C:\AzureADAssessment\AzureADAssessmentPortable.psm1"

## Export Data to "C:\AzureADAssessment" into a single output package.
Invoke-AADAssessmentHybridDataCollection
```

### I want to use a service principal identity to run the assessment instead of a user identity
```PowerShell
## If you prefer to use your own app registration (service principal) for automation purposes, you may connect using your own ClientId and Certificate like the example below. Your app registration should include Directory.Read.All and Policy.Read.All permissions to MS Graph for a complete assessment. Once added, ensure you have completed admin consent on the service principal for those application permissions.
Connect-AADAssessment -ClientId <ClientId> -ClientCertificate (Get-Item 'Cert:\CurrentUser\My\<Thumbprint>') -TenantId <TenantId>

## If you would like to specify a different directory, use the OutputDirectory parameter.
Invoke-AADAssessmentDataCollection "C:\Temp"
Invoke-AADAssessmentHybridDataCollection "C:\Temp"
```

### When trying to install the module I'm receiving the error 'A parameter cannot be found that matches parameter name 'AcceptLicense' 
Run the following command to update PowerShellGet to the latest version before attempting to install the AzureADAssessment module again.

```PowerShell
## Update Nuget Package and PowerShellGet Module
Install-PackageProvider NuGet -Scope CurrentUser -Force
Install-Module PowerShellGet -Scope CurrentUser -Force -AllowClobber
## Remove old modules from existing session
Remove-Module PowerShellGet,PackageManagement -Force -ErrorAction Ignore
## Import updated module
Import-Module PowerShellGet -MinimumVersion 2.0 -Force
Import-PackageProvider PowerShellGet -MinimumVersion 2.0 -Force
```

### If at any point you see the error, `<Path> cannot be loaded because running scripts is disabled on this system. For more information, see about_Execution_Policies at http://go.microsoft.com/fwlink/?LinkID=135170.`, you must enable local scripts to be run.

```PowerShell
## Set globally on device
Set-ExecutionPolicy RemoteSigned
## Or set for just for current PowerShell session.
Set-ExecutionPolicy RemoteSigned -Scope Process
```

### MSAL.PS Certificate Error (Authenticode issuer)

The signing certificate for MSAL.PS is changing to use Microsoft's code signing process. If you see the following error, `PackageManagement\Install-Package : Authenticode issuer 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' of the new module 'MSAL.PS' with version 'x.x.x.x' from root certificate authority 'CN=Microsoft Root Certificate Authority 2011, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' is not matching with the authenticode issuer 'CN=Jason Thompson, O=Jason Thompson, L=Cincinnati, S=Ohio, C=US' of the previously-installed module 'MSAL.PS' with version 'x.x.x.x' from root certificate authority 'CN=DigiCert Assured ID Root CA, OU=www.digicert.com, O=DigiCert Inc, C=US'. If you still want to install or update, use -SkipPublisherCheck parameter.`, you can resolve it using the following command.

```PowerShell
Install-Module MSAL.PS -SkipPublisherCheck -Force
```

### Unable to sign in with device code flow
If you are using PowerShell Core (ie PowerShell 6 or 7) and your tenant has a conditional access policy that requires a Compliant or Hybrid Azure AD Joined device, you may not be able to sign in.

To work around this issue use Windows PowerShell (instead of PowerShell 6 or 7). To launch Windows PowerShell go to **Start > Windows PowerShell**

### Unable to load data in PowerBI templates ###
When you open the powerbi templates, you will be asked to reference the folder where the extracted data resides (csv and json). Once selected PowerBI will load the data.
While doing so PowerBI might complain with errors crossreferncing data sources: 
```
Query '*' (step '*') references other queries or steps, so it may not directly access a datasource. Please rebuild this data combination.  
```
To workarround this, configure PowerBI file settings to ignore privacy settings:
* **File > Options and settings > Options**
* In **Options** under **CURRENT FILE** find the **Privacy**
* In **Privacy Levels** select **Ignore the Privacy Levels and potentially improve performance**

## Contents

| File/folder       | Description                                             |
|-------------------|---------------------------------------------------------|
| `build`           | Scripts to package, test, sign, and publish the module. |
| `src`             | Module source code.                                     |
| `tests`           | Test scripts for module.                                |
| `.gitignore`      | Define what to ignore at commit time.                   |
| `README.md`       | This README file.                                       |
| `LICENSE`         | The license for the module.                             |

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
