<#
.SYNOPSIS
    Query Microsoft Graph API
.EXAMPLE
    PS C:\>Invoke-MsGraphQuery -RelativeUri 'users'
    Return query results for first page of users.
.EXAMPLE
    PS C:\>Invoke-MsGraphQuery -TenantId tenant.onmicrosoft.com -Scopes 'User.ReadBasic.All' -RelativeUri 'users' -ApiVersion beta -ReturnAllResults
    Return query results for all users in tenant.onmicrosoft.com using the beta API.
#>
function Invoke-MgGraphQuery {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]] $RelativeUri,
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

            if (!$QueryParameters) {
                if ($uriQueryEndpoint.Query) { [hashtable] $QueryParameters = ConvertFrom-QueryString $uriQueryEndpoint.Query -AsHashtable }
                else { [hashtable] $QueryParameters = @{ } }
            }
            $uriQueryEndpoint.Query = ConvertTo-QueryString $QueryParameters

            if ($BatchRequests -and $RelativeUri.Count -gt 1) {
                $request = New-Object PSObject -Property @{
                    id      = $listRequests.Count #(New-Guid).ToString()
                    method  = 'GET'
                    url     = $uriQueryEndpoint.Uri.AbsoluteUri -replace ('{0}{1}/' -f $GraphBaseUri.AbsoluteUri, $ApiVersion)
                    headers = @{ ConsistencyLevel = $ConsistencyLevel }
                }
                $listRequests.Add($request)
            }
            else {
                ## Get results
                try {
                    Connect-AADAssessModules
                    [hashtable] $results = Invoke-MgGraphRequest -Method GET -Uri $uriQueryEndpoint.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel }
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
