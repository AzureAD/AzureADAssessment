<#
.SYNOPSIS
    Query Microsoft Graph API
.EXAMPLE
    PS C:\>Get-MsGraphResults 'users'
    Return query results for first page of users.
.EXAMPLE
    PS C:\>Get-MsGraphResults 'users' -ApiVersion beta
    Return query results for all users using the beta API.
.EXAMPLE
    PS C:\>Get-MsGraphResults 'users' -UniqueId 'user1@domain.com','user2@domain.com' -Select id,userPrincipalName,displayName
    Return id, userPrincipalName, and displayName for user1@domain.com and user2@domain.com.
#>
function Get-MsGraphResults {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
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
        # Specifies consistency level.
        [Parameter(Mandatory = $false)]
        [string] $ConsistencyLevel = "eventual",
        # Only return first page of results.
        [Parameter(Mandatory = $false)]
        [switch] $DisablePaging,
        # Force individual requests to MS Graph.
        [Parameter(Mandatory = $false)]
        [switch] $DisableBatching,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20,
        # Base URL for Microsoft Graph API.
        [Parameter(Mandatory = $false)]
        [uri] $GraphBaseUri = 'https://graph.microsoft.com/'
    )

    begin {
        $listRequests = New-Object 'System.Collections.Generic.List[psobject]'

        function Format-Result ($results, $RawOutput) {
            if (!$RawOutput -and (Get-ObjectProperty $results 'value')) {
                foreach ($result in $results.value) {
                    if ($result -is [hashtable]) {
                        $result.Add('@odata.context', ('{0}/$entity' -f $results.'@odata.context'))
                    }
                    else {
                        $result | Add-Member -MemberType NoteProperty -Name '@odata.context' -Value ('{0}/$entity' -f $results.'@odata.context')
                    }
                    Write-Output $result
                }
            }
            else { Write-Output $results }
        }

        function Complete-Result ($results, $DisablePaging) {
            if (!$DisablePaging -and $results) {
                while (Get-ObjectProperty $results '@odata.nextLink') {
                    # Confirm-ModuleAuthentication
                    # $results = Invoke-MgGraphRequest -Method GET -Uri $results.'@odata.nextLink' -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                    $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession
                    $results = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method GET -Uri $results.'@odata.nextLink' -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                    Format-Result $results $DisablePaging
                }
            }
        }
    }

    process {
        ## Initialize
        if (!$UniqueId) { [string[]] $UniqueId = '' }
        if ($DisableBatching -and ($RelativeUri.Count -gt 1 -or $UniqueId.Count -gt 1)) {
            Write-Warning ('This command is invoking {0} individual Graph requests. For better performance, remove the -DisableBatching parameter.' -f ($RelativeUri.Count * $UniqueId.Count))
        }

        ## Process Each RelativeUri
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
            foreach ($id in $UniqueId) {
                $uriQueryEndpointFinal = New-Object System.UriBuilder -ArgumentList $uriQueryEndpoint.Uri
                $uriQueryEndpointFinal.Path = ([IO.Path]::Combine($uriQueryEndpointFinal.Path, $id))

                if (!$DisableBatching -and ($RelativeUri.Count -gt 1 -or $UniqueId.Count -gt 1)) {
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
                        # Confirm-ModuleAuthentication
                        # [hashtable] $results = Invoke-MgGraphRequest -Method GET -Uri $uriQueryEndpointFinal.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                        $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession
                        $results = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method GET -Uri $uriQueryEndpointFinal.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                        Format-Result $results $DisablePaging
                        Complete-Result $results $DisablePaging
                    }
                    catch { throw }
                }
            }
        }
    }

    end {
        if ($listRequests.Count -gt 0) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, '$batch'))
            for ($iRequest = 0; $iRequest -lt $listRequests.Count; $iRequest += $BatchSize) {
                # foreach ($request in $listRequests[$iRequest..$indexEnd]) {
                #     $request.url = $request.url.Substring($uriQueryEndpoint.Uri.AbsoluteUri.Length - 6)
                #     $request.url
                # }
                $indexEnd = [System.Math]::Min($iRequest + $BatchSize - 1, $listRequests.Count - 1)
                $jsonRequests = New-Object psobject -Property @{ requests = $listRequests[$iRequest..$indexEnd] } | ConvertTo-Json -Depth 5
                Write-Debug $jsonRequests
                
                # Confirm-ModuleAuthentication
                # [hashtable] $resultsBatch = Invoke-MgGraphRequest -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -Body $jsonRequests
                # [hashtable[]] $resultsBatch = $resultsBatch.responses | Sort-Object -Property id
                $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession
                $resultsBatch = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -ContentType 'application/json' -Body $jsonRequests
                [array] $resultsBatch = $resultsBatch.responses | Sort-Object -Property { [int]$_.id }

                foreach ($results in ($resultsBatch.body)) {
                    Format-Result $results $DisablePaging
                    Complete-Result $results $DisablePaging
                }
            }
        }
    }
}
