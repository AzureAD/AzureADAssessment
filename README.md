# Microsoft Azure AD Assessment

[![PSGallery Version](https://img.shields.io/powershellgallery/v/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Platform](https://img.shields.io/powershellgallery/p/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Platform)](https://www.powershellgallery.com/packages/AzureADAssessment)

## Install from the PowerShell Gallery
```PowerShell
Install-Module AzureADAssessment -Force -AcceptLicense
## If you have already installed the module, run the following instead to ensure you have the latest version.
Update-Module AzureADAssessment -Force
```

If you encounter an error, try the following commands instead to update the PowerShell Package Manager.
```PowerShell
## Update Nuget Package and PowerShellGet Module
Install-PackageProvider NuGet -Force
Install-Module PowerShellGet -Force

## In a new PowerShell process, install the AzureADAssessment Module. Restart PowerShell console if this fails.
&(Get-Process -Id $pid).Path -Command { Install-Module AzureADAssessment -AcceptLicense }
Import-Module AzureADAssessment
```

## Run the Data Collection
Data collection from Azure AD can be run from any client with access to Azure AD. However, data collection from hybrid components such as AD FS, AAD Connect, etc. are best run locally on those servers.

Verify that you have authorized credentials to access these workloads:
* Azure Active Directory as Global Administrator or Global Reader
* Domain or local administrator access to ADFS Servers
* Domain or local administrator access to Azure AD Proxy Connector Servers
* Domain or local administrator access to Azure AD Connect Server (Primary)
* Domain or local administrator access to Azure AD Connect Server (Staging Server)

Run following commands to produce a package of all the Azure AD data necessary to complete the assessment.
```PowerShell
## Authenticate using a Global Admin or Global Reader account.
Connect-AADAssessment

## Export data to "C:\AzureADAssessment" into a single output package.
Invoke-AADAssessmentDataCollection
```

The output package will be named according to the following pattern: `AzureADAssessmentData-<TenantDomain>.zip`

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

Once data collection is complete, provide the output packages to whoever is completing the assessment.

## Complete Assessment Reports
As the assessor, run the following command using the output package from data collection to complete generation of the assessment reports.
```PowerShell
## Output Assessment Reports to "C:\AzureADAssessment" and "C:\AzureADAssessment\PowerBI".
Complete-AADAssessmentReports "C:\AzureADAssessment\AzureADAssessmentData-<TenantName>.onmicrosoft.com.zip"
```

The generated reports and PowerBI templates can now be used to assess the tenant.

## Alternate Ways to Run The Assessment
```PowerShell
## If you prefer to use your own app registration for automation purposes, you may connect using your own ClientId and Certificate like the example below. Your app registration should include Directory.Read.All and Policy.Read.All permissions to MS Graph for a complete assessment. Once added, ensure you have completed admin consent on the service principal for those application permissions.
Connect-AADAssessment -ClientId <ClientId> -ClientCertificate (Get-Item 'Cert:\CurrentUser\My\<Thumbprint>') -TenantId <TenantId>

## If you would like to specify a different directory, use the OutputDirectory parameter.
Invoke-AADAssessmentDataCollection "C:\Temp"
Invoke-AADAssessmentHybridDataCollection "C:\Temp"
Complete-AADAssessmentReports "C:\AzureADAssessment\AzureADAssessmentData-<TenantName>.onmicrosoft.com.zip" -OutputDirectory "C:\Temp"
```

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
