# Azure AD Configuration Assessment Guide

Information Gathering Guide

# Introduction

This guide contains all the verifications to perform with customers to perform a comprehensive review of their cloud identity configuration and infrastructure.

- The **Checklist** contains the tasks that both the Engagement Driver and the customer need to do ahead of the interview.
- The **Administration Portals Walkthrough** provides a guided walkthrough of the administration portals, alongside some questions to be asked as the customer navigates through the configuration.
- The **Interview Questions** provides specific questions to ask the customer that were not captured in the administration portal walkthrough section. These questions are broken down by different Identity and Access Management (IAM) areas, and specific checks.

## Catalog of Actors

Azure AD Assessor:

- **Engagement Driver:** The person who will be interviewing the customer and presenting the results.

Customer Team Actors:

- **IAM Architect**
- **IAM Operations**
- **InfoSec Architect**
- **InfoSec Operations**

# Pre-Interview Checklist

## Individual Assessment

- Create a collaboration space to share files with the customer. This can be a shared Teams or SharePoint library.
- **Share this link with your customer** [https://aka.ms/AzureADAssessmentGuide](https://aka.ms/AzureADAssessmentGuide). Ask them to follow the instructions in the &#39;Run the Data Collection&#39; section and share the zip files with you over Teams/SharePoint.
  - This step is a pre-requisite for the customer to do ahead of time. The scripts can take a few hours to run on large tenants.
- **Create a local folder** to store the assessments (Eg. &quot;C:\AzureADAssessment\Woodgrove&quot;) and copy the zip file(s) from the customer.
- Install/Update the AzureADAssessment module on your laptop to the latest version. Eg.
```powershell
Install-Module AzureADAssessment-Force -AcceptLicense
```

- Run the **Complete-AADAssessmentReports** command to complete the generation of the assessment reports. Eg.
```powershell
Complete-AADAssessmentReports `
  -Path C:\AzureADAssessment\Woodgrove\AzureADAssessmentData-woodgrove.onmicrosoft.com.zip `
  -OutputDirectory C:\AzureADAssessment\Woodgrove\Report
```

- Open the two Power BI template files located in the **OutputDirectory**. They will automatically collect the data from the customer&#39;s data files to populate the Power BI data model.
  - AzureADAssessment-PowerShell.pbit
  - AzureADAssessment-ConditionalAccess.pbit
- Click the **Save** button in Power BI to save the pbix files in preparation for writing the final report and sharing with the customer.

# Interview

- Set up a 1-2 hour call with the customer and complete the [AzureADAssessment Survey](https://github.com/AzureAD/AzureADAssessment/blob/master/assets/AzureADAssessment-Survey.xlsx) worksheet.

# Post-Interview

## Generate Azure AD Config Documenter Report

- Generate the Azure AD Connect Config Documenter report using the Powershell command below.
```powershell
Import-Module AzureADAssessment

Expand-AADAssessAADConnectConfig -CustomerName 'Woodgrove' `
  -AADConnectProdConfigZipFilePath C:\AzureADAssessment\Woodgrove\AzureADAssessmentData-AADC-PROD.zip `
  -AADConnectProdStagingZipFilePath C:\AzureADAssessment\Woodgrove\AzureADAssessmentData-AADC-STAGING.zip `
  -OutputRootPath C:\AzureADAssessment\Woodgrove\Report\AADC 
```

- This command will generate an HTML report that you then will analyze to provide the relevant recommendations. Upload that HTML file in the customer collaboration workspace as well.

## Generate AD FS App Migration Report (If applicable)

If customer provided ADFS data follow the instructions to generate the ADFS to Azure AD Migration report as explained in the [official documentation](https://github.com/AzureAD/Deployment-Plans/tree/master/ADFS%20to%20AzureAD%20App%20Migration#instructions-if-you-want-to-run-the-analysis-from-another-server).

# Report Write Up

On completion of the interview, you will have the required information to write the final report for the customer.

- Open these three files that were created in the previous steps.
  - AzureADAssessment-PowerShell.pbix
  - AzureADAssessment-ConditionalAccess.pbix
  - AzureADAssessment-Survey.xlsx
- Download the [AzureADAssessment-ReportOut](https://github.com/merill/AzureADAssessment/raw/master/assets/AzureADAssessment-ReportOut.pptx) PowerPoint file and use it as a template to document the final report for the customer.
- Using the [Azure AD Configuration Assessment Reference](https://github.com/AzureAD/AzureADAssessment/blob/master/docs/reference.md) as a guide, review each Recommendation/Check and compare with the customer's configuration.
  - If the customer's configuration is not in-line with a recommendation, add it to the ReportOut PowerPoint document with the appropriate priority.
  - When adding a recommendation remember to link back to the appropriate section in the [Azure AD Configuration Assessment Reference](https://github.com/AzureAD/AzureADAssessment/blob/master/docs/reference.md) (tip: hovering over a heading will display a link icon that you can right-click and copy).
