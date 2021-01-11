<#
.SYNOPSIS
    Query Microsoft Graph API
.EXAMPLE
    PS C:\>Invoke-MsGraphQuery -RelativeUri 'users'
    Return query results for first page of users.
.EXAMPLE
    PS C:\>Invoke-MsGraphQuery -RelativeUri 'users' -ApiVersion beta -ReturnAllResults
    Return query results for all users using the beta API.
.EXAMPLE
    PS C:\>Invoke-MsGraphQuery -RelativeUri 'users' -UniqueId 'user1@domain.com','user2@domain.com' -Select id,userPrincipalName,displayName -BatchRequests
    Return id, userPrincipalName, and displayName for user1@domain.com and user2@domain.com.
#>
function Invoke-MgGraphQuery {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]] $RelativeUri,
        # Specifies unique Id(s) for the URI endpoint. For example, users endpoint accepts Id or UPN.
        [Parameter(Mandatory = $false)]
        [string[]] $UniqueId,
        # Filters properties (columns).
        [Parameter(Mandatory = $false)]
        [string[]] $Select,
        # Filters results (rows). https://docs.microsoft.com/en-us/graph/query-parameters#filter-parameter
        [Parameter(Mandatory = $false)]
        [string] $Filter,
        # Parameters such as "$top".
        [Parameter(Mandatory = $false)]
        [hashtable] $QueryParameters,
        # API Version.
        [Parameter(Mandatory = $false)]
        [ValidateSet('v1.0', 'beta')]
        [string] $ApiVersion = 'v1.0',
        # Specifies consistency level
        [Parameter(Mandatory = $false)]
        [string] $ConsistencyLevel = "eventual",
        # If results exceed a single page, request additional pages to get all data.
        [Parameter(Mandatory = $false)]
        [switch] $ReturnAllResults,
        # Base URL for Microsoft Graph API.
        [Parameter(Mandatory = $false)]
        [uri] $GraphBaseUri = 'https://graph.microsoft.com/',
        # Batch requests.
        [Parameter(Mandatory = $false)]
        [switch] $BatchRequests,
        # Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )

    begin {
        $listRequests = New-Object 'System.Collections.Generic.List[psobject]'
    }

    process {
        foreach ($uri in $RelativeUri) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, $uri))

            ## Combine query parameters from URI and cmdlet parameters
            if ($uriQueryEndpoint.Query) {
                [hashtable] $finalQueryParameters = ConvertFrom-QueryString $uriQueryEndpoint.Query -AsHashtable
                if ($QueryParameters) {
                    foreach ($ParameterName in $QueryParameters.Keys) {
                        $finalQueryParameters[$ParameterName] = $QueryParameters[$ParameterName]
                    }
                }
            }
            elseif ($QueryParameters) { [hashtable] $finalQueryParameters = $QueryParameters }
            else { [hashtable] $finalQueryParameters = @{ } }
            if ($Select) { $finalQueryParameters['$select'] = $Select -join ',' }
            if ($Filter) { $finalQueryParameters['$filter'] = $Filter }
            $uriQueryEndpoint.Query = ConvertTo-QueryString $finalQueryParameters

            ## Invoke graph requests individually or save for single batch request
            if (!$UniqueId) { [string[]] $UniqueId = '' }
            if (!$BatchRequests -and ($RelativeUri.Count -gt 1 -or $UniqueId.Count -gt 1)) {
                Write-Warning ('This command is invoking {0} individual Graph requests. For better performance, add the -BatchRequests parameter.' -f ($RelativeUri.Count * $UniqueId.Count))
            }
            foreach ($id in $UniqueId) {
                $uriQueryEndpointFinal = New-Object System.UriBuilder -ArgumentList $uriQueryEndpoint.Uri
                $uriQueryEndpointFinal.Path = ([IO.Path]::Combine($uriQueryEndpointFinal.Path, $id))

                if ($BatchRequests -and $RelativeUri.Count -gt 1) {
                    ## Create batch request entry
                    $request = New-Object PSObject -Property @{
                        id      = $listRequests.Count #(New-Guid).ToString()
                        method  = 'GET'
                        url     = $uriQueryEndpointFinal.Uri.AbsoluteUri -replace ('{0}{1}/' -f $GraphBaseUri.AbsoluteUri, $ApiVersion)
                        headers = @{ ConsistencyLevel = $ConsistencyLevel }
                    }
                    $listRequests.Add($request)
                }
                else {
                    ## Get results
                    try {
                        Connect-AADAssessModules
                        [hashtable] $results = Invoke-MgGraphRequest -Method GET -Uri $uriQueryEndpointFinal.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                        Write-Output $results

                        if ($ReturnAllResults -and $results) {
                            while ($results.ContainsKey('@odata.nextLink')) {
                                Connect-AADAssessModules
                                $results = Invoke-MgGraphRequest -Method GET -Uri $results.'@odata.nextLink' -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                                Write-Output $results
                            }
                        }
                    }
                    catch { throw }
                }
            }
        }
    }

    end {
        if ($listRequests.Count -gt 0) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, '$batch'))
            for ($iRequest = 0; $iRequest -lt $RelativeUri.Count; $iRequest += $BatchSize) {
                # foreach ($request in $listRequests[$iRequest..$indexEnd]) {
                #     $request.url = $request.url.Substring($uriQueryEndpoint.Uri.AbsoluteUri.Length - 6)
                #     $request.url
                # }
                $indexEnd = [System.Math]::Min($iRequest + $BatchSize - 1, $RelativeUri.Count - 1)
                $jsonRequests = New-Object psobject -Property @{ requests = $listRequests[$iRequest..$indexEnd] } | ConvertTo-Json -Depth 5
                Write-Debug $jsonRequests
                Connect-AADAssessModules
                [hashtable] $resultsBatch = Invoke-MgGraphRequest -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -Body $jsonRequests
                [hashtable[]] $resultsBatch = $resultsBatch.responses | Sort-Object -Property id
                #Write-Output $resultsBatch.body

                foreach ($results in ($resultsBatch.body)) {
                    Write-Output $results
                    if ($ReturnAllResults -and $results) {
                        while ($results.ContainsKey('@odata.nextLink')) {
                            Connect-AADAssessModules
                            $results = Invoke-MgGraphRequest -Method GET -Uri $results.'@odata.nextLink' -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                            Write-Output $results
                        }
                    }
                }
            }
        }
    }
}
