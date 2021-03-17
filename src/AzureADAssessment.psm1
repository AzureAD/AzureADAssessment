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
    [object] $ModuleConfiguration
)

## Set Strict Mode for Module. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode
Set-StrictMode -Version 3.0

## Initialize Module Configuration
$script:ModuleConfigDefault = Import-Config -Path (Join-Path $PSScriptRoot 'config.json')
$script:ModuleConfig = $script:ModuleConfigDefault.psobject.Copy()

Import-Config | Set-Config
if ($PSBoundParameters.ContainsKey('ModuleConfiguration')) { Set-Config $ModuleConfiguration }
#Export-Config

## Initialize Module Variables
$script:ConnectState = @{
    ClientApplication = $null
    CloudEnvironment  = $null
    MsGraphToken      = $null
    AadGraphToken     = $null
}

$script:MsGraphSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$script:MsGraphSession.Headers.Add('ConsistencyLevel', 'eventual')
$script:MsGraphSession.UserAgent += ' AzureADAssessment'
#$script:MsGraphSession.UserAgent += '{0}/{1}' -f $MyInvocation.MyCommand.Module.Name,$MyInvocation.MyCommand.Module.Version
# $script:MsGraphSession.Proxy = New-Object System.Net.WebProxy -Property @{
#     Address = localhost
#     UseDefaultCredentials = $true
# }

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

#Future
#Get PIM data
#Get Secure Score
#Add Master CmdLet and make it in parallel
