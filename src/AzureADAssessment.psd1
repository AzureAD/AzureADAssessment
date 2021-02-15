#
# Module manifest for module 'AzureADAssessment'
#
# Generated by: GTP-Architecture
#
# Generated on: 02/15/2021
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AzureADAssessment.psm1'

# Version number of this module.
ModuleVersion = '1.1'

# Supported PSEditions
CompatiblePSEditions = 'Core','Desktop'

# ID used to uniquely identify this module
GUID = '0dc4c0ce-4ff6-43c2-9913-8e001c84e0d3'

# Author of this module
Author = 'Microsoft Identity'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '© Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'This module analyzes your Azure Active Directory configuration and provides best practice recommendations.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
    @{ ModuleName = 'MSAL.PS'; Guid = 'c765c957-c730-4520-9c36-6a522e35d60b'; ModuleVersion = '4.10.0.1' }
    #@{ ModuleName = 'Microsoft.Graph.Authentication'; Guid = '883916f2-9184-46ee-b1f8-b6a2fb784cee'; ModuleVersion = '1.1.0' }
    @{ ModuleName = 'AzureAD'; Guid = 'd60c0004-962d-4dfb-8d28-5707572ffd00'; ModuleVersion = '2.0.0.55' }
)

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @(
    '.\internal\Assert-DirectoryExists.ps1'
    '.\internal\Confirm-ModuleAuthentication.ps1'
    '.\internal\ConvertFrom-Base64String.ps1'
    '.\internal\ConvertFrom-QueryString.ps1'
    '.\internal\ConvertTo-QueryString.ps1'
    '.\internal\Expand-JsonWebTokenPayload.ps1'
    '.\internal\Get-Config.ps1'
    '.\internal\Get-MsGraphResults.ps1'
    '.\internal\Get-ObjectProperty.ps1'
    '.\internal\New-AppInsightsTelemetry.ps1'
    '.\internal\Remove-Diacritics.ps1'
    '.\internal\Remove-InvalidFileNameCharacters.ps1'
    '.\internal\Set-Config.ps1'
    '.\internal\Start-AppInsightsRequest.ps1'
    '.\internal\Complete-AppInsightsRequest.ps1'
    '.\internal\Use-Progress.ps1'
    '.\internal\Write-AppInsightsDependency.ps1'
    '.\internal\Write-AppInsightsEvent.ps1'
    '.\internal\Write-AppInsightsException.ps1'
    '.\internal\Write-AppInsightsRequest.ps1'
    '.\internal\Write-AppInsightsTrace.ps1'
    '.\Connect-AADAssessment.ps1'
    '.\Disable-AADAssessmentTelemetry.ps1'
    '.\Enable-AADAssessmentTelemetry.ps1'
    '.\Expand-AADAssessAADConnectConfig.ps1'
    '.\Export-AADAssessADFSConfiguration.ps1'
    '.\Get-AADAssessADFSEndpoints.ps1'
    '.\Get-AADAssessAppAssignmentReport.ps1'
    '.\Get-AADAssessApplicationKeyExpirationReport.ps1'
    '.\Get-AADAssessAppProxyConnectorLog.ps1'
    '.\Get-AADAssessCAPolicyReports.ps1'
    '.\Get-AADAssessConsentGrantList.ps1'
    '.\Get-AADAssessmentReports.ps1'
    '.\Get-AADAssessmentSingleReport.ps1'
    '.\Get-AADAssessNotificationEmailAddresses.ps1'
    '.\Get-AADAssessPasswordWritebackAgentLog.ps1'
)

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Connect-AADAssessment'
    'Disable-AADAssessmentTelemetry'
    'Enable-AADAssessmentTelemetry'
    #'Get-MsGraphResults'
    'Get-AADAssessAppProxyConnectorLog'
    'Get-AADAssessPasswordWritebackAgentLog'
    'Get-AADAssessNotificationEmailAddresses'
    'Get-AADAssessAppAssignmentReport'
    'Get-AADAssessConsentGrantList'
    'Get-AADAssessApplicationKeyExpirationReport'
    'Get-AADAssessADFSEndpoints'
    'Export-AADAssessADFSConfiguration'
    'Get-AADAssessCAPolicyReports'
    'Get-AADAssessmentReports'
    'Expand-AADAssessAADConnectConfig'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Microsoft', 'Identity', 'Azure', 'AzureActiveDirectory', 'AzureAD', 'AAD', 'PSEdition_Desktop', 'Windows'

        # A URL to the license for this module.
        LicenseUri = 'https://raw.githubusercontent.com/AzureAD/AzureADAssessment/master/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/AzureAD/AzureADAssessment'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

