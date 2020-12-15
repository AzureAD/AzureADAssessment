## Set Strict Mode for Module. https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode
Set-StrictMode -Version 3.0

<# 
 
.SYNOPSIS
	MSCloudIdAssessment.psm1 is a Windows PowerShell module to gather configuration information across different components of the identity infrastrucutre

.DESCRIPTION

	Version: 1.0.0

	MSCloudIdUtils.psm1 is a Windows PowerShell module with some Azure AD helper functions for common administrative tasks


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

$global:authHeader = $null
$global:msgraphToken = $null
$global:tokenRequestedTime = [DateTime]::MinValue

$global:forceMSALRefreshIntervalMinutes = 30

function Get-MSCloudIdAccessToken {
    [CmdletBinding()]
    param (
        [string]
        $TenantId,
        [string]
        $ClientID,
        [string]
        $RedirectUri,
        [string]
        $Scopes,
        [switch]
        $Interactive
    )
    
    $msalToken = $null
    if ($Interactive)
    {
        $msalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes -Resource -ForceRefresh        
    }
    else
    {
        try {
            $msalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes -Silent -ForceRefresh  
        }
        catch [Microsoft.Identity.Client.MsalUiRequiredException] 
        {
            $MsalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes               
        }
    }

    Write-Output $MsalToken
}


function Connect-MSGraphAPI {
    [CmdletBinding()]
    param (
        [string]
        $TenantId,
        [string]
        $ClientID = "1b730954-1685-4b74-9bfd-dac224a7b894",
        [string]
        $RedirectUri = "urn:ietf:wg:oauth:2.0:oob",
        [string]
        $Scopes = "https://graph.microsoft.com/.default",
        [switch]
        $Interactive
    )
    
    $token = Get-MSCloudIdAccessToken -TenantId $TenantId -ClientID $ClientID -RedirectUri $RedirectUri -Scopes $Scopes -Interactive:$Interactive
    $Header = @{ }
    $Header.Authorization = "Bearer {0}" -f $token.AccessToken
    $Header.'Content-type' = "application/json"
    
    $global:msgraphToken = $token
    $global:authHeader = $Header
}

<# 
 .Synopsis
  Starts the sessions to AzureAD and MSOnline Powershell Modules

 .Description
  This function prompts for authentication against azure AD 

#>
function Start-MSCloudIdSession		
{
    Connect-MSGraphAPI
    $msGraphToken = $global:msgraphToken

    $aadTokenPsh = Get-MSCloudIdAccessToken -ClientID 1b730954-1685-4b74-9bfd-dac224a7b894 -Scopes "https://graph.windows.net/.default"  -RedirectUri "urn:ietf:wg:oauth:2.0:oob" 
    #$aadTokenPsh

    Connect-AzureAD -AadAccessToken $aadTokenPsh.AccessToken  -MsAccessToken $msGraphToken.AccessToken -AccountId $msGraphToken.Account.UserName -TenantId $msGraphToken.TenantID  | Out-Null

    $global:tokenRequestedTime = [DateTime](Get-Date)

    Write-Debug "Session Established!"
}



function Reset-MSCloudIdSession		
{

    $CurrentDate = [DateTime](Get-Date)
    $Delta= ($CurrentDate - $global:tokenRequestedTime).TotalMinutes
    
    #we are going to attempt to get a token before the AT expires
    #tenants who set a token lifetime shorter than 30 mins might get 
    #issues / error messages if an activity takes longer than 30 mins

    if ($Delta -gt $global:forceMSALRefreshIntervalMinutes) 
    {
        Connect-MSGraphAPI 
        Write-Debug "Session Refreshed for token freshness!"

        $global:tokenRequestedTime = $CurrentDate
        $msGraphToken = $global:msgraphToken

        $aadTokenPsh = Get-MSCloudIdAccessToken -ClientID 1b730954-1685-4b74-9bfd-dac224a7b894 -Scopes "https://graph.windows.net/.default"  -RedirectUri "urn:ietf:wg:oauth:2.0:oob" 

        Connect-AzureAD -AadAccessToken $aadTokenPsh.AccessToken  -MsAccessToken $msGraphToken.AccessToken -AccountId $msGraphToken.Account.UserName -TenantId $msGraphToken.TenantID  | Out-Null

        $global:tokenRequestedTime = [DateTime](Get-Date)

    }
    $Headers = $global:authHeader    
}


Function Remove-InvalidFileNameChars 
{
  param(
    [Parameter(Mandatory=$true,
      Position=0,
      ValueFromPipeline=$true,
      ValueFromPipelineByPropertyName=$true)]
    [String]$Name
  )

  $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
  $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
  return ($Name -replace $re)
}


Function Get-MSCloudIdAssessmentSingleReport
{
    [CmdletBinding()]
    param
    (
        [String]$FunctionName,
        [String]$OutputDirectory,
        [String]$OutputCSVFileName
    )

    $OriginalThreadUICulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
    $OriginalThreadCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture

    try {
        #reports need to be created in en-US for backend processing of datetime
        $culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $culture
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

        $OutputFilePath = Join-Path $OutputDirectory $OutputCSVFileName
        $Report = Invoke-Expression -Command $FunctionName
        $Report | Export-Csv -Path $OutputFilePath
    }
    finally
    {
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $OriginalThreadUICulture
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OriginalThreadCulture
    } 
}

function New-MSGraphQueryToBatch
{
    [CmdletBinding()]
    param (
        # endpoint
        [string]
        $endpoint,
        [string]
        $QueryParameters,
        # HTTP Method
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]
        $Method,
        [string]
        $Body
    )

    if ($null -notlike $QueryParameters) {
        $URI = ("/{0}?{1}" -f $endpoint, $QueryParameters)
        
    }
    else {
        $URI = ("/{0}" -f $endpoint)
    }

    $result = New-Object PSObject -Property @{
        id = [Guid]::NewGuid()
        method=$Method
        url=$URI
        body=$Body
    }

    Write-Output $result
}

function Invoke-MSGraphBatch
{
    param (
        # Base URI
        [string]
        $BaseURI = "https://graph.microsoft.com/",
        # endpoint
        [ValidateSet("1.0", "beta")]
        [string]
        $APIVersion = "beta",
        [object[]]
        $requests
    )

    #MS Graph limit
    $maxBatchSize = 20
    $batchCount = 0
    $currentBatch=@()
    $totalResults=@()

    foreach($request in $requests)
    {
        $batchCount++
        $currentBatch += $request
        
        if ($batchCount -ge $maxBatchSize)
        {
            $requestsJson = New-Object psobject -Property @{requests=$currentBatch} | ConvertTo-Json -Depth 100
            $batchResults = Invoke-MSGraphQuery -BaseURI $BaseURI -endpoint "`$batch" -Method "POST" -Body $requestsJson
            $totalResults += $batchResults
            
            $batchCount = 0
            $currentBatch = @()
        }
    }

    if ($batchCount -gt 0)
    {
        $requestsJson = New-Object psobject -Property @{requests=$currentBatch} | ConvertTo-Json -Depth 100
        $batchResults = Invoke-MSGraphQuery -BaseURI $BaseURI -endpoint "`$batch" -Method "POST" -Body $requestsJson
        $totalResults += $batchResults
        
        $batchCount = 0
        $currentBatch = @()
    }

    Write-Output $totalResults
}



function Invoke-MSGraphQuery {
    [CmdletBinding()]
    param (
        # Base URI
        [string]
        $BaseURI = "https://graph.microsoft.com/",
        # endpoint
        [string]
        $endpoint,
        [ValidateSet("1.0", "beta")]
        [string]
        $APIVersion = "beta",
        [string]
        $QueryParameters,
        # HTTP Method
        [Parameter(Mandatory = $true)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]
        $Method,
        [string]
        $Body

    )
    
    begin {
        # Header
        $CurrentDate = [DateTime](Get-Date)
        $Delta= ($CurrentDate - $global:tokenRequestedTime).TotalMinutes
        
        if ($Delta -gt $global:forceMSALRefreshIntervalMinutes)
        {
            Connect-MSGraphAPI
            $global:tokenRequestedTime = $CurrentDate
        }
        $Headers = $global:authHeader        
    }
    
    process {

        if ($null -notlike $QueryParameters) {
            $URI = ("{0}{1}/{2}?{3}" -f $BaseURI, $APIVersion, $endpoint, $QueryParameters)
            
        }
        else {
            $URI = ("{0}{1}/{2}" -f $BaseURI, $APIVersion, $endpoint)
        }
        
        try {

            switch ($Method) {
                "GET" {

                    $queryUrl = $URI
                    Write-Verbose ("Invoking $Method request on $queryUrl...")
                    while (-not [String]::IsNullOrEmpty($queryUrl)) {
                       
                        try {                            
                            $pagedResults = Invoke-RestMethod -Method $Method -Uri $queryUrl -Headers $Headers -ErrorAction Stop
                        
                        }
                        catch {
                        
                            $StatusCode = [int]$_.Exception.Response.StatusCode
                            $message = $_.Exception.Message
                            Write-Error "ERROR During Request -  $StatusCode $message"

                        }

                    
                        if ($pagedResults.value -ne $null) {
                            $queryResults += $pagedResults.value
                        }
                        else {
                            $queryResults += $pagedResults
                        }
                        $queryCount = $queryResults.Count
                        Write-Progress -Id 1 -Activity "Querying directory" -CurrentOperation "Retrieving results ($queryCount found so far)" 
                        $queryUrl = ""

                        $odataNextLink = $pagedResults | Select-Object -ExpandProperty "@odata.nextLink" -ErrorAction SilentlyContinue

                        if ($null -ne $odataNextLink) {
                            $queryUrl = $odataNextLink
                        }
                        else {
                            $odataNextLink = $pagedResults | Select-Object -ExpandProperty "odata.nextLink" -ErrorAction SilentlyContinue
                            if ($null -ne $odataNextLink) {
                                $absoluteUri = [Uri]"https://bogus/$odataNextLink"
                                $skipToken = $absoluteUri.Query.TrimStart("?")
                                
                            }
                        }
                    }

                    Write-Verbose ("Returning {0} total results" -f $queryResults.count)
                    Write-Output $queryResults

                }

                "POST" {
                    $queryUrl = $URI
                    Write-Verbose ("Invoking $Method request on $queryUrl using $Headers with Body $body...")
                    #Connect-MSGraphAPI

                    $qErr = $Null
                    try {                    
                        $queryResults = Invoke-RestMethod -Method $Method -Uri $queryUrl -Headers $Headers -Body $Body -UseBasicParsing -ErrorVariable qErr -ErrorAction Stop
                        Write-Output $queryResults
                    }
                    catch {
                        $StatusCode = [int]$_.Exception.Response.StatusCode
                        $message = $_.Exception.Message
                        Write-Error "ERROR During Request -  $StatusCode $message"


                    }
                   

                   
                   
                }

                "PUT" {
                    $queryUrl = $URI
                    Write-Verbose ("Invoking $Method request on $queryUrl...")
                    $pagedResults = Invoke-RestMethod -Method $Method -Uri $queryUrl -Headers $Headers -Body $Body
                }
                "DELETE" {
                    $queryUrl = $URI
                    Write-Verbose ("Invoking $Method request on $queryUrl...")
                    $pagedResults = Invoke-RestMethod -Method $Method -Uri $queryUrl -Headers $Headers
                }
            }
            
            
        }
        catch {
            
        }
    }
    
    end {
        
    }
}

function Add-MSGraphObjectIdCondition
{
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $InitialFilter,
        [Parameter()]
        [string]
        $PropertyName,
        [string]
        $ObjectId,
        [Parameter()]
        $Operator = "or"
    )

    $oid = [Guid]::NewGuid()

    if ([String]::IsNullOrWhiteSpace($oid) -or -not [Guid]::TryParse($ObjectId, [ref]$oid))
    {
        Write-Output $InitialFilter
        return
    }

    $Condition = "$PropertyName+eq+'$ObjectId'"

    if ([string]::IsNullOrWhiteSpace($InitialFilter))
    {
        Write-Output $Condition
    }
    else {
        Write-Output "$InitialFilter+$Operator+$Condition"
    }
}

function Expand-AzureADCAPolicyReferencedObjects()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $ObjectIds,
        [Parameter(Mandatory=$true)]
        [string]
        $Endpoint,
        [Parameter()]
        [string]
        $FilterProperty = "id",
        [Parameter(Mandatory=$true)]
        [string]
        $SelectProperties
    )
    #MS Graph limit
    $maxConditionsPerQuery = 15
    $objectsInQuery = 0
    $msGraphFilter = ""

    foreach($objectId in $ObjectIds)
    {
        $objectsInQuery++
        $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $objectId -PropertyName $FilterProperty

        if ($objectsInQuery -eq $maxConditionsPerQuery)
        {
            $batchQuery = New-MSGraphQueryToBatch -Method GET -endpoint $Endpoint -QueryParameters "`$select=$SelectProperties&filter=$msGraphFilter"
            Write-Output $batchQuery
            $objectsInQuery = 0
            $msGraphFilter = ""
        } 
    }

    if ($objectsInQuery -gt 0)
    {
        $batchQuery = New-MSGraphQueryToBatch -Method GET -endpoint $Endpoint -QueryParameters "`$select=$SelectProperties&filter=$msGraphFilter"
        Write-Output $batchQuery
    }   
}

# Export-ModuleMember -Function New-MSCloudIdGraphApp
# Export-ModuleMember -Function Connect-AADAssessment
# Export-ModuleMember -Function Remove-MSCloudIdGraphApp
# Export-ModuleMember -Function Get-AADAssessAppProxyConnectorLog
# Export-ModuleMember -Function Get-AADAssessPasswordWritebackAgentLog
# Export-ModuleMember -Function Get-AADAssessNotificationEmailAddresses
# Export-ModuleMember -Function Get-AADAssessAppAssignmentReport
# Export-ModuleMember -Function Get-AADAssessConsentGrantList
# Export-ModuleMember -Function Get-AADAssessApplicationKeyExpirationReport
# Export-ModuleMember -Function Get-AADAssessADFSEndpoints
# Export-ModuleMember -Function Export-AADAssessADFSConfiguration
# Export-ModuleMember -Function Get-AADAssessCAPolicyReports
# Export-ModuleMember -Function Get-AADAssessmentAzureADReports
# Export-ModuleMember -Function Expand-AADAssessAADConnectConfig

#Future 
#Get PIM data
#Get Secure Score
#Add Master CmdLet and make it in parallel
