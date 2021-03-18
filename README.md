# Microsoft Azure AD Assessment

[![PSGallery Version](https://img.shields.io/powershellgallery/v/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/AzureADAssessment) [![PSGallery Platform](https://img.shields.io/powershellgallery/p/AzureADAssessment.svg?style=flat&logo=powershell&label=PSGallery%20Platform)](https://www.powershellgallery.com/packages/AzureADAssessment)

## Install from the PowerShell Gallery
```PowerShell
Install-Module AzureADAssessment -Force -AcceptLicense
## If you have already installed the module, run the following instead to ensure you have the latest version.
Update-Module AzureADAssessment -Force
```

If you encounter the error, `WARNING: The specified module 'MSAL.PS' with PowerShellGetFormatVersion '2.0' is not supported by the current version of PowerShellGet. Get the latest version of the PowerShellGet module to install this module, 'MSAL.PS'` then run the following commands to proceed with the installation.

```PowerShell
## Update Nuget Package and PowerShellGet Module
Install-PackageProvider NuGet -Force
Install-Module PowerShellGet -Force

## In a new PowerShell process, install the MSAL.PS Module. Restart PowerShell console if this fails.
&(Get-Process -Id $pid).Path -Command { Install-Module MSAL.PS -AcceptLicense }
Import-Module MSAL.PS
```

## Run the Data Collection
Run following commands to produce a package of all the data necessary to complete the assessment.
```PowerShell
## Authenticate
Connect-AADAssessment
## If you prefer to use your own app registration for automation purposes, you may connect using your own ClientId and Certificate like the example below. Your app registration should include Directory.Read.All and Policy.Read.All permissions to MS Graph for a complete assessment. Once added, ensure you have completed admin consent on the service principal for those application permissions.
Connect-AADAssessment -ClientId <ClientId> -ClientCertificate (Get-Item 'Cert:\CurrentUser\My\<Thumbprint>') -TenantId <TenantId>

## Export Data to "C:\AzureADAssessment".
Invoke-AADAssessmentDataCollection
## If you would like to specify a different directory, use the OutputDirectory parameter.
Invoke-AADAssessmentDataCollection "C:\Temp"
```

Run the following to collect data from hybrid components such as AAD Connect, AD FS, AAD App Proxy.
```PowerShell
## Export Portable Module to "C:\AzureADAssessment".
Export-AADAssessmentPortableModule "C:\AzureADAssessment"

## On each server running hybrid components, copy the module file "AzureADAssessmentPortable.psm1" and import it there.
Import-Module "C:\AzureADAssessment\AzureADAssessmentPortable.psm1"
## Export Data to "C:\AzureADAssessment".
Invoke-AADAssessmentHybridDataCollection
## If you would like to specify a different directory, use the OutputDirectory parameter.
Invoke-AADAssessmentHybridDataCollection "C:\Temp"
```

Data collection is complete so provide the output packages to whoever is completing the assessment.

As the assessor, run the following command using the output package from data collection to complete generation of the assessment reports.
```PowerShell
## Output Assessment Reports to "C:\AzureADAssessment".
Complete-AADAssessmentReports "C:\AzureADAssessment\AzureADAssessmentData-<TenantName>.onmicrosoft.com.zip"
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
