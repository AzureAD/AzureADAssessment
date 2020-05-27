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
        $RedirectUri = "urn://azuread/configassessmentapp",
        [string]
        $Scopes = "Policy.Read.All",
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


function Get-AzureADECAPolicy {
    [CmdletBinding()]
    param (
    )
    
    begin {
        
    }
    process {
        $endpoint = "identity/conditionalAccess/policies"         
        $results = Invoke-MSGraphQuery -Method GET -endpoint $endpoint -QueryParameters  $QueryParameters
    }
    end {

        write-output $results
        
    }
}

