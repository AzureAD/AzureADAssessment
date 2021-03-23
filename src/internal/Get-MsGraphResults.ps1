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
        [uri[]] $RelativeUri,
        # Specifies unique Id(s) for the URI endpoint. For example, users endpoint accepts Id or UPN.
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $false)]
        #[ValidateNotNullOrEmpty()]
        [string[]] $UniqueId,
        # Filters properties (columns).
        [Parameter(Mandatory = $false)]
        [string[]] $Select,
        # Filters results (rows). https://docs.microsoft.com/en-us/graph/query-parameters#filter-parameter
        [Parameter(Mandatory = $false)]
        [string] $Filter,
        # Specifies the page size of the result set.
        [Parameter(Mandatory = $false)]
        [int] $Top,
        # Include a count of the total number of items in a collection
        [Parameter(Mandatory = $false)]
        [switch] $Count,
        # Parameters such as "$orderby".
        [Parameter(Mandatory = $false)]
        [hashtable] $QueryParameters,
        # API Version.
        [Parameter(Mandatory = $false)]
        [ValidateSet('v1.0', 'beta')]
        [string] $ApiVersion = 'v1.0',
        # Specifies consistency level.
        [Parameter(Mandatory = $false)]
        [string] $ConsistencyLevel = "eventual",
        # Copy OData Context to each object.
        [Parameter(Mandatory = $false)]
        [switch] $KeepODataContext,
        # Disable deduplication of UniqueId values.
        [Parameter(Mandatory = $false)]
        [switch] $DisableUniqueIdDeduplication,
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
        $listRequests = New-Object 'System.Collections.Generic.List[pscustomobject]'

        function Catch-MsGraphError ($ErrorRecord) {
            if ($_.Exception -is [System.Net.WebException]) {
                $StreamReader = New-Object System.IO.StreamReader -ArgumentList $_.Exception.Response.GetResponseStream()
                try { $responseBody = ConvertFrom-Json $StreamReader.ReadToEnd() }
                finally { $StreamReader.Close() }

                if ($responseBody.error.code -eq 'Authentication_ExpiredToken' -or $responseBody.error.code -eq 'Service_ServiceUnavailable') {
                    #Write-AppInsightsException $_.Exception
                    Write-Error -Exception $_.Exception -Message $responseBody.error.message -ErrorId $responseBody.error.code -Category $_.CategoryInfo.Category -CategoryActivity $_.CategoryInfo.Activity -CategoryReason $_.CategoryInfo.Reason -CategoryTargetName $_.CategoryInfo.TargetName -CategoryTargetType $_.CategoryInfo.TargetType -TargetObject $_.TargetObject -ErrorAction Stop
                }
                else {
                    Write-Error -Exception $_.Exception -Message $responseBody.error.message -ErrorId $responseBody.error.code -Category $_.CategoryInfo.Category -CategoryActivity $_.CategoryInfo.Activity -CategoryReason $_.CategoryInfo.Reason -CategoryTargetName $_.CategoryInfo.TargetName -CategoryTargetType $_.CategoryInfo.TargetType -TargetObject $_.TargetObject -ErrorVariable cmdError
                    Write-AppInsightsException $cmdError.Exception
                }
            }
            else { throw $ErrorRecord }
        }

        function Test-MsGraphBatchError ($BatchResponse) {
            if ($BatchResponse.status -ne '200') {
                if ($BatchResponse.body.error.code -eq 'Authentication_ExpiredToken' -or $BatchResponse.body.error.code -eq 'Service_ServiceUnavailable') {
                    Write-Error -Message $BatchResponse.body.error.message -ErrorId $BatchResponse.body.error.code -ErrorAction Stop
                }
                else {
                    Write-Error -Message $BatchResponse.body.error.message -ErrorId $BatchResponse.body.error.code -ErrorVariable cmdError
                    Write-AppInsightsException $cmdError.Exception
                }
                return $true
            }
            return $false
        }

        function New-MsGraphBatchRequest {
            param (
                [object[]] $Requests,
                [int] $BatchSize = 20,
                [int] $Depth = 1,
                [uri] $GraphBatchUri = 'https://graph.microsoft.com/v1.0/$batch'
            )

            for ($iRequest = 0; $iRequest -lt $Requests.Count; $iRequest += [System.Math]::Pow($BatchSize, $Depth)) {
                $indexEnd = [System.Math]::Min($iRequest + [System.Math]::Pow($BatchSize, $Depth) - 1, $Requests.Count - 1)

                if ($Depth -gt 1) {
                    $BatchRequest = New-MsGraphBatchRequest $Requests[$iRequest..$indexEnd] -Depth ($Depth - 1)
                }
                else {
                    $BatchRequest = $Requests[$iRequest..$indexEnd]
                }

                [pscustomobject]@{
                    id     = $iRequest
                    method = 'POST'
                    url    = $GraphBatchUri.AbsoluteUri
                    body   = [PSCustomObject]@{ requests = $BatchRequest }
                }
            }
        }

        function Get-MsGraphResultsCount ([uri]$Uri) {
            $uriQueryEndpointCount = New-Object System.UriBuilder -ArgumentList $Uri -ErrorAction Stop
            $uriQueryEndpointCount.Path = ([IO.Path]::Combine($uriQueryEndpointCount.Path, '$count'))
            [int] $Count = $null
            try {
                $Count = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method GET -Uri $uriQueryEndpointCount.Uri.AbsoluteUri -Headers @{ ConsistencyLevel = 'eventual' } -Verbose:$false -ErrorAction Ignore
            }
            catch {}
            return $Count
        }

        function Format-Result ($results, [bool]$RawOutput, [bool]$KeepODataContext) {
            if (!$RawOutput -and $results.psobject.Properties.Name -contains 'value') {
                foreach ($result in $results.value) {
                    if ($KeepODataContext) {
                        if ($result -is [hashtable]) {
                            $result.Add('@odata.context', ('{0}/$entity' -f $results.'@odata.context'))
                        }
                        else {
                            $result | Add-Member -MemberType NoteProperty -Name '@odata.context' -Value ('{0}/$entity' -f $results.'@odata.context')
                        }
                    }
                    Write-Output $result
                }
            }
            else { Write-Output $results }
        }

        function Complete-Result ($results, [bool]$DisablePaging, [bool]$KeepODataContext, [string]$RequestMethod = 'GET', [uri]$RequestUri, [hashtable]$RequestHeaders) {
            Format-Result $results $DisablePaging $KeepODataContext
            if (!$DisablePaging -and $results) {
                $ProgressState = $null
                if (Get-ObjectPropertyValue $results '@odata.nextLink') {
                    $Total = Get-MsGraphResultsCount $RequestUri
                    if ($Total) {
                        $Activity = 'Microsoft Graph Request'
                        if ($RequestUri) { $Activity = ('Microsoft Graph Request - {0} {1}' -f $RequestMethod, $RequestUri.AbsolutePath) }
                        $ProgressState = Start-Progress -Activity $Activity -Total $Total
                        $ProgressState.CurrentIteration = $results.value.Count
                    }
                }
                try {
                    while (Get-ObjectPropertyValue $results '@odata.nextLink') {
                        if ($ProgressState) { Update-Progress $ProgressState -IncrementBy $results.value.Count }
                        $nextLink = $results.'@odata.nextLink'
                        # Confirm-ModuleAuthentication -ErrorAction Stop
                        # $results = Invoke-MgGraphRequest -Method GET -Uri $results.'@odata.nextLink' -Headers $RequestHeaders
                        $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
                        $results = $null
                        try {
                            $results = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method Get -Uri $nextLink -Headers $RequestHeaders -ErrorAction Stop
                        }
                        catch { Catch-MsGraphError $_ }
                        Format-Result $results $DisablePaging $KeepODataContext
                    }
                }
                finally {
                    if ($ProgressState) { Stop-Progress $ProgressState }
                }
            }
        }
    }

    process {
        ## Initialize
        if ($DisableBatching -and ($RelativeUri.Count -gt 1 -or $UniqueId -and $UniqueId.Count -gt 1)) {
            Write-Warning ('This command is invoking {0} individual Graph requests. For better performance, remove the -DisableBatching parameter.' -f ($RelativeUri.Count * $UniqueId.Count))
        }

        ## Process Each RelativeUri
        [System.Collections.Generic.List[uri]] $uriQueryEndpoints = New-Object 'System.Collections.Generic.List[uri]'
        foreach ($uri in $RelativeUri) {
            if ($uri.IsAbsoluteUri) { $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList $uri }
            else { $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, $uri)) }

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
            if ($Top) { $finalQueryParameters['$top'] = $Top }
            if ($PSBoundParameters.ContainsKey('Count')) { $finalQueryParameters['$count'] = $Count }
            $uriQueryEndpoint.Query = ConvertTo-QueryString $finalQueryParameters

            ## Expand with UniqueIds
            if ($PSBoundParameters.ContainsKey('UniqueId')) {
                foreach ($id in $UniqueId) {
                    if ($id) {
                        ## If the URI contains '{0}', then replace it with Unique Id.
                        if ($uriQueryEndpoint.Uri.AbsoluteUri.Contains('%7B0%7D')) {
                            $uriQueryEndpointUniqueId = New-Object System.UriBuilder -ArgumentList ([System.Net.WebUtility]::UrlDecode($uriQueryEndpoint.Uri.AbsoluteUri) -f $id)
                        }
                        else {
                            $uriQueryEndpointUniqueId = New-Object System.UriBuilder -ArgumentList $uriQueryEndpoint.Uri
                            $uriQueryEndpointUniqueId.Path = ([IO.Path]::Combine($uriQueryEndpointUniqueId.Path, $id))
                        }
                        if (!$uriQueryEndpoints.Contains($uriQueryEndpointUniqueId.Uri) -or $DisableUniqueIdDeduplication) { $uriQueryEndpoints.Add($uriQueryEndpointUniqueId.Uri) }
                    }
                }
            }
            else { $uriQueryEndpoints.Add($uriQueryEndpoint.Uri) }
        }

        ## Invoke graph requests individually or save for single batch request
        foreach ($uriFinal in $uriQueryEndpoints) {
            if (!$DisableBatching -and ($uriQueryEndpoints.Count -gt 1)) {
                ## Create batch request entry
                $request = [pscustomobject]@{
                    id      = $listRequests.Count #(New-Guid).ToString()
                    method  = 'GET'
                    url     = $uriFinal.AbsoluteUri -replace ('{0}{1}/' -f $GraphBaseUri.AbsoluteUri, $ApiVersion)
                    headers = @{ ConsistencyLevel = $ConsistencyLevel }
                }
                $listRequests.Add($request)
            }
            else {
                ## Get results
                # Confirm-ModuleAuthentication -ErrorAction Stop
                # [hashtable] $results = Invoke-MgGraphRequest -Method GET -Uri $uriFinal.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel }
                $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
                $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                try {
                    $results = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method GET -Uri $uriFinal.AbsoluteUri -Headers @{ ConsistencyLevel = $ConsistencyLevel } -ErrorAction Stop
                    #Format-Result $results $DisablePaging $KeepODataContext
                    Complete-Result $results $DisablePaging $KeepODataContext 'GET' $uriFinal @{ ConsistencyLevel = $ConsistencyLevel }
                }
                catch { Catch-MsGraphError $_ }
                finally {
                    $Stopwatch.Stop()
                    Write-AppInsightsDependency ('{0} {1}' -f 'GET', $uriFinal.AbsolutePath) -Type 'MS Graph' -Data ('{0} {1}' -f 'GET', $uriFinal.AbsoluteUri) -Duration $Stopwatch.Elapsed -Success ($null -ne $results)
                }
            }
        }
    }

    end {
        if ($listRequests.Count -gt 0) {
            $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion, '$batch'))

            $ProgressState = Start-Progress -Activity 'Microsoft Graph Requests - Batched' -Total $listRequests.Count
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($iRequest = 0; $iRequest -lt $listRequests.Count; $iRequest += $BatchSize) {
                Update-Progress $ProgressState -IncrementBy $BatchSize
                # foreach ($request in $listRequests[$iRequest..$indexEnd]) {
                #     $request.url = $request.url.Substring($uriQueryEndpoint.Uri.AbsoluteUri.Length - 6)
                #     $request.url
                # }
                $indexEnd = [System.Math]::Min($iRequest + $BatchSize - 1, $listRequests.Count - 1)
                $jsonRequests = [PSCustomObject]@{ requests = $listRequests[$iRequest..$indexEnd] } | ConvertTo-Json -Depth 5 -Compress

                # Confirm-ModuleAuthentication -ErrorAction Stop
                # [hashtable] $resultsBatch = Invoke-MgGraphRequest -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -Body $jsonRequests
                # [hashtable[]] $resultsBatch = $resultsBatch.responses | Sort-Object -Property id
                $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
                $resultsBatch = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method POST -Uri $uriQueryEndpoint.Uri.AbsoluteUri -ContentType 'application/json' -Body $jsonRequests -ErrorAction Stop

                [array] $resultsBatch = $resultsBatch.responses | Sort-Object -Property { [int]$_.id }
                foreach ($results in ($resultsBatch)) {
                    if (!(Test-MsGraphBatchError $results)) {
                        #Format-Result $results.body $DisablePaging $KeepODataContext
                        Complete-Result $results.body $DisablePaging $KeepODataContext $listRequests[$results.id].method $uriQueryEndpoint.Uri.AbsoluteUri.Replace('$batch', $listRequests[$results.id].url) $listRequests[$results.id].headers
                    }
                }
            }
            $Stopwatch.Stop()
            Write-AppInsightsDependency ('{0} {1}' -f 'POST', $uriQueryEndpoint.Uri.AbsolutePath) -Type 'MS Graph' -Data ("{0} {1}`r`n`r`n{2}" -f 'POST', $uriQueryEndpoint.Uri.AbsoluteUri, ('{{"requests":[...{0}...]}}' -f $listRequests.Count)) -Duration $Stopwatch.Elapsed -Success ($null -ne $resultsBatch)
            Stop-Progress $ProgressState
        }
    }
}
