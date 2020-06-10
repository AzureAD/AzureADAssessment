# Requires -Module @{ ModuleName = 'MSAL.PS'; RequiredVersion = '4.7.1.2' }
$global:authHeader = $null

function Connect-MSGraphAPI {
    [CmdletBinding()]
    param (
        [string]
        $TenantId,
        [string]
        $ClientID = "92cd380b-4edf-4457-946e-25b4a665cd6a",
        [string]
        $Resource = "https://graph.microsoft.com",
        [string]
        $RedirectUri = "http://localhost",
        [string]
        $Scopes = "Policy.Read.All User.Read.All Group.Read.All Application.Read.All",
        [switch]
        $Interactive = $True
    )
    
    begin {
    }
    
    process {


        $msalToken = $null
        if ($Interactive)
        {
            $msalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes -LoginHint $Credential.UserName                 
        }
        else
        {

            try {
                $msalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes -Silent -LoginHint $Credential.UserName     
            }
            catch [Microsoft.Identity.Client.MsalUiRequiredException] 
            {
                $MsalToken = get-msaltoken -ClientId $ClientID -TenantId $TenantId -RedirectUri $RedirectUri -Scopes $Scopes -UserCredential $Credential                
            }
        }

        $token = $MsalToken.accesstoken
        $Header = @{ }
        $Header.Authorization = "Bearer {0}" -f $token
        $Header.'Content-type' = "application/json"
        $global:authHeader = $Header
    }
    end {
        Write-Output $result
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

    $requestsJson = New-Object psobject -Property @{requests=$requests} | ConvertTo-Json -Depth 100

    Invoke-MSGraphQuery -BaseURI $BaseURI -endpoint "`$batch" -Method "POST" -Body $requestsJson

}

$global:tokenRequestedTime = [DateTime]::MinValue

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
        
        if ($Delta -gt 55)
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
        $PropertyName="id",
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

function Expand-AzureADCAPolicyReferencedUsers()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSObject]
        $Policy
    )

    $msGraphFilter = ""

    $policy.conditions.users.includeUsers | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ }
    $policy.conditions.users.excludeUsers | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ }

    if ($msGraphFilter -ne "")
    {
        $batchQuery = New-MSGraphQueryToBatch -Method GET -endpoint "users" -QueryParameters "`$select=id,userprincipalName&filter=$msGraphFilter"
        Write-Output $batchQuery
    }

}

function Expand-AzureADCAPolicyReferencedGroups()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSObject]
        $Policy
    )

    $msGraphFilter = ""

    $policy.conditions.users.includeGroups | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ }
    $policy.conditions.users.includeGroups | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ }

    if ($msGraphFilter -ne "")
    {
        $batchQuery = New-MSGraphQueryToBatch -Method GET -endpoint "groups" -QueryParameters "`$select=id,displayName&filter=$msGraphFilter"
        Write-Output $batchQuery
    }
}

function Expand-AzureADCAPolicyReferencedApplications()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [PSObject]
        $Policy
    )

    $msGraphFilter = ""

    $policy.conditions.applications.includeApplications | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ -PropertyName "appId"}
    $policy.conditions.applications.excludeApplications | %{ $msGraphFilter = Add-MSGraphObjectIdCondition -InitialFilter $msGraphFilter -ObjectId $_ -PropertyName "appId"}

    if ($msGraphFilter -ne "")
    {
        $batchQuery = New-MSGraphQueryToBatch -Method GET -endpoint "applications" -QueryParameters "`$select=appId,displayName&filter=$msGraphFilter"
        Write-Output $batchQuery
    }

}

function Export-AzureADCAPolicy {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]
        $OutputFilesPath 
    )    
    
    begin {
        
    }
    process {
        $policies = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/policies"
        $namedLocations = Invoke-MSGraphQuery -Method GET -endpoint "identity/conditionalAccess/namedLocations"      

        $usersBatch = @()
        $groupsBatch = @()
        $appsBatch = @()

        foreach($policy in $policies)
        {
            if ($policy -ne $null)
            {
                $usersBatch += Expand-AzureADCAPolicyReferencedUsers -Policy $policy
                $groupsBatch += Expand-AzureADCAPolicyReferencedGroups -Policy $policy
                $appsBatch += Expand-AzureADCAPolicyReferencedApplications -Policy $policy
            }
        }

        $referencedUsers = Invoke-MSGraphBatch -requests $usersBatch 
        $referencedGroups = Invoke-MSGraphBatch -requests $groupsBatch 
        $referencedApps = Invoke-MSGraphBatch -requests $appsBatch 
        
        $policies | ConvertTo-Json -Depth 100 | Out-File "$OutputFilesPath\CAPolicies.json" -Force
        $namedLocations | ConvertTo-Json -Depth 100 | Out-File "$OutputFilesPath\NamedLocations.json" -Force
        
        $referencedUsers.responses | select-object -ExpandProperty body | select-object -ExpandProperty value | ConvertTo-Json -Depth 100| Out-File "$OutputFilesPath\CARefUsers.json" -Force
        $referencedGroups.responses | select-object -ExpandProperty body | select-object -ExpandProperty value | ConvertTo-Json -Depth 100| Out-File "$OutputFilesPath\CARefGroups.json" -Force
        $referencedApps.responses | select-object -ExpandProperty body | select-object -ExpandProperty value | ConvertTo-Json -Depth 100| Out-File "$OutputFilesPath\CARefApps.json" -Force

    }
    end {

        
        
    }
}

