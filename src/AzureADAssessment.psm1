## Set Strict Mode for Module. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode
Set-StrictMode -Version 3.0

<# 
.DISCLAIMER
	THIS CODE AND INFORMATION IS PROVIDED "AS IS" WITHOUT WARRANTY OF
	ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO
	THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
	PARTICULAR PURPOSE.

	Copyright (c) Microsoft Corporation. All rights reserved.
#>

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

#Future 
#Get PIM data
#Get Secure Score
#Add Master CmdLet and make it in parallel
