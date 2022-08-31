<#
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>

param (
    # Provide module configuration
    [Parameter(Mandatory = $false)]
    [psobject] $ModuleConfiguration
)

## Set Strict Mode for Module. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode
Set-StrictMode -Version 3.0

## Display Warning on old PowerShell versions. https://docs.microsoft.com/en-us/powershell/scripting/install/PowerShell-Support-Lifecycle#powershell-end-of-support-dates
# ToDo: Only Windows PowerShell can currently satify device compliance CA requirement. Look at adding Windows Broker (WAM) support to support device compliance on PowerShell 7.
# if ($PSVersionTable.PSVersion -lt [version]'7.0') {
#     Write-Warning 'It is recommended to use this module with the latest version of PowerShell which can be downloaded here: https://aka.ms/install-powershell'
# }

## Initialize Module Configuration
$script:ModuleConfigDefault = Import-Config -Path (Join-Path $PSScriptRoot 'config.json')
$script:ModuleConfig = $script:ModuleConfigDefault.psobject.Copy()

Import-Config | Set-Config
if ($PSBoundParameters.ContainsKey('ModuleConfiguration')) { Set-Config $ModuleConfiguration }
#Export-Config

## Initialize Module Variables
$script:ConnectState = @{
    ClientApplication = $null
    CloudEnvironment  = 'Global'
    MsGraphToken      = $null
}

$script:MsGraphSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$script:MsGraphSession.Headers.Add('ConsistencyLevel', 'eventual')
$script:MsGraphSession.UserAgent += ' AzureADAssessment'
#$script:MsGraphSession.UserAgent += '{0}/{1}' -f $MyInvocation.MyCommand.Module.Name,$MyInvocation.MyCommand.Module.Version
# $script:MsGraphSession.Proxy = New-Object System.Net.WebProxy -Property @{
#     Address = localhost
#     UseDefaultCredentials = $true
# }

[string[]] $script:MsGraphScopes = @(
    'Organization.Read.All'
    'RoleManagement.Read.Directory'
    'Application.Read.All'
    'User.Read.All'
    'Group.Read.All'
    'Policy.Read.All'
    'Directory.Read.All'
    'SecurityEvents.Read.All'
    'UserAuthenticationMethod.Read.All'
    'AuditLog.Read.All'
    'Reports.Read.All'
)

$script:mapMgEnvironmentToAzureCloudInstance = @{
    'Global'   = 'AzurePublic'
    'China'    = 'AzureChina'
    'Germany'  = 'AzureGermany'
    'USGov'    = 'AzureUsGovernment'
    'USGovDoD' = 'AzureUsGovernment'
}
$script:mapMgEnvironmentToAzureEnvironment = @{
    'Global'   = 'AzureCloud'
    'China'    = 'AzureChinaCloud'
    'Germany'  = 'AzureGermanyCloud'
    'USGov'    = 'AzureUSGovernment'
    'USGovDoD' = 'AzureUsGovernment'
}
$script:mapMgEnvironmentToAadRedirectUri = @{
    'Global'   = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    'China'    = 'https://login.partner.microsoftonline.cn/common/oauth2/nativeclient'
    'Germany'  = 'https://login.microsoftonline.com/common/oauth2/nativeclient'
    'USGov'    = 'https://login.microsoftonline.us/common/oauth2/nativeclient'
    'USGovDoD' = 'https://login.microsoftonline.us/common/oauth2/nativeclient'
}
$script:mapMgEnvironmentToMgEndpoint = @{
    'Global'   = 'https://graph.microsoft.com/'
    'China'    = 'https://microsoftgraph.chinacloudapi.cn/'
    'Germany'  = 'https://graph.microsoft.de/'
    'USGov'    = 'https://graph.microsoft.us/'
    'USGovDoD' = 'https://dod-graph.microsoft.us/'
}

## Initialize Application Insights for Anonymous Telemetry
$script:AppInsightsRuntimeState = [PSCustomObject]@{
    OperationStack = New-Object System.Collections.Generic.Stack[PSCustomObject]
    SessionId      = New-Guid
}

if (!$script:ModuleConfig.'ai.disabled') {
    $script:AppInsightsState = [PSCustomObject]@{
        UserId = New-Guid
    }
    Import-Config -Path 'AppInsightsState.json' | Set-Config -OutConfig ([ref]$script:AppInsightsState)
    Export-Config -Path 'AppInsightsState.json' -InputObject $script:AppInsightsState -IgnoreDefaultValues $null
}

## HashArray with already read evidence
$script:Evidences =  @{
    'Tenant' = @{} # tenant files
    'AADC' = @{} # aadconnect files indexed by server name
    'ADFS' = @{} # ADFS files indexed by server name
    'AADAP' = @{} # AAD Proxy Agent files indexed by server name
}

#Future
#Get PIM data
#Get Secure Score
#Add Master CmdLet and make it in parallel
