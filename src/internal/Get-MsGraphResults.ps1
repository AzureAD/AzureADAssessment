<#
.SYNOPSIS
    Query Microsoft Graph API
.PARAMETER EnableInFilter
    Enables in filter by in on ids for requried uniqueIds; $filter={previous filter} and id in ({csv with ids})
    Should be more flexible than GetByIds, scalability to be tested to eventually replace getbyids
    This filter is currently experimental and will be subject to future change (move to DisableInFilterBatching).
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
        [Parameter(Mandatory = $false, Position = 1, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
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
        # Total requests to calcuate progress bar when using pipeline.
        [Parameter(Mandatory = $false)]
        [int] $TotalRequests,
        # Copy OData Context to each result value.
        [Parameter(Mandatory = $false)]
        [switch] $KeepODataContext,
        # Add OData Type to each result value.
        [Parameter(Mandatory = $false)]
        [switch] $AddODataType,
        # Incapsulate member and owner reference calls with a parent object.
        [Parameter(Mandatory = $false)]
        [switch] $IncapsulateReferenceListInParentObject,
        # Group results in array by request.
        [Parameter(Mandatory = $false)]
        [switch] $GroupOutputByRequest,
        # Disable deduplication of UniqueId values.
        [Parameter(Mandatory = $false)]
        [switch] $DisableUniqueIdDeduplication,
        # Only return first page of results.
        [Parameter(Mandatory = $false)]
        [switch] $DisablePaging,
        # Disable consolidating uniqueIds using getByIds endpoint
        [Parameter(Mandatory = $false)]
        [switch] $DisableGetByIdsBatching,
        # Specify GetByIds Batch size.
        [Parameter(Mandatory = $false)]
        [int] $GetByIdsBatchSize = 1000,
        # Enables in filter by in on ids for requried uniqueIds; $filter={previous filter} and id in ({csv with ids})
        # Should be more flexible than GetByIds, scalability to be tested to eventually replace getbyids
        [Parameter(Mandatory = $false)]
        [switch] $EnableInFilter,
        [Parameter(Mandatory = $false)]
        [int] $InFilterBatchSize = 15,
        # Force individual requests to MS Graph.
        [Parameter(Mandatory = $false)]
        [switch] $DisableBatching,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20,
        # Base URL for Microsoft Graph API.
        [Parameter(Mandatory = $false)]
        [uri] $GraphBaseUri = $script:mapMgEnvironmentToMgEndpoint[$script:ConnectState.CloudEnvironment]
    )

    begin {

        if ($EnableInFilter) {
            Write-Verbose "EnableInFilter switch used: this filter is currently experimental and will be subject to future change (move to DisableInFilterBatching)"
        }

        [uri] $uriGraphVersionBase = [IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $ApiVersion)
        $listRequests = New-Object 'System.Collections.Generic.Dictionary[string,System.Collections.Generic.List[pscustomobject]]'
        $listRequests.Add($uriGraphVersionBase.AbsoluteUri, (New-Object 'System.Collections.Generic.List[pscustomobject]'))
        [System.Collections.Generic.List[guid]] $listIds = New-Object 'System.Collections.Generic.List[guid]'
        [System.Collections.Generic.HashSet[uri]] $hashUri = New-Object 'System.Collections.Generic.HashSet[uri]'
        $ProgressState = Start-Progress -Activity 'Microsoft Graph Requests' -Total $TotalRequests

        function Catch-MsGraphError {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory = $true)]
                [System.Management.Automation.ErrorRecord] $ErrorRecord
            )

            # throw error record directly if no response is found on the exception
            if (!$_.Exception.psobject.Properties.Name.Contains('Response')) {
                throw $ErrorRecord
            }

            ## Get Response Body
            if ($_.ErrorDetails) {
                $Response = '{0} {1} HTTP/{2}' -f $_.Exception.Response.StatusCode.value__, $_.Exception.Response.ReasonPhrase, $_.Exception.Response.Version
                $ContentType = $_.Exception.Response.Content.Headers.ContentType.ToString()
                $ResponseContent = ConvertFrom-Json $_.ErrorDetails.Message
            }
            elseif ($_.Exception -is [System.Net.WebException]) {
                if ($_.Exception.Response) {
                    $Response = '{0} {1} HTTP/{2}' -f $_.Exception.Response.StatusCode.value__, $_.Exception.Response.StatusDescription, $_.Exception.Response.ProtocolVersion
                    $ContentType = $_.Exception.Response.Headers.GetValues('Content-Type') -join '; '

                    $StreamReader = New-Object System.IO.StreamReader -ArgumentList $_.Exception.Response.GetResponseStream()
                    try { $ResponseContent = ConvertFrom-Json $StreamReader.ReadToEnd() }
                    finally { $StreamReader.Close() }
                }
            }

            Write-Debug -Message (ConvertTo-Json ([PSCustomObject]@{
                        'Request'                             = '{0} {1}' -f $_.TargetObject.Method, $_.TargetObject.RequestUri.AbsoluteUri
                        'Response'                            = $Response
                        'Response.Content-Type'               = $ContentType
                        'Response.Content'                    = $ResponseContent
                        'Response.Header.Date'                = $_.Exception.Response.Headers.GetValues('Date')[0]
                        'Response.Header.request-id'          = $_.Exception.Response.Headers.GetValues('request-id')[0]
                        'Response.Header.client-request-id'   = $_.Exception.Response.Headers.GetValues('client-request-id')[0]
                        'Response.Header.x-ms-ags-diagnostic' = $_.Exception.Response.Headers.GetValues('x-ms-ags-diagnostic')[0] | ConvertFrom-Json
                    }) -Depth 3)

            if ($ResponseContent) {
                ## Write Custom Error
                if ($ResponseContent.error.code -eq 'Authentication_ExpiredToken' -or $ResponseContent.error.code -eq 'Service_ServiceUnavailable' -or $ResponseContent.error.code -eq 'Request_UnsupportedQuery') {
                    #Write-AppInsightsException $_.Exception
                    Write-Error -Exception $_.Exception -Message $ResponseContent.error.message -ErrorId $ResponseContent.error.code -Category $_.CategoryInfo.Category -CategoryActivity $_.CategoryInfo.Activity -CategoryReason $_.CategoryInfo.Reason -CategoryTargetName $_.CategoryInfo.TargetName -CategoryTargetType $_.CategoryInfo.TargetType -TargetObject $_.TargetObject -ErrorAction Stop
                }
                else {
                    if ($ResponseContent.error.code -eq 'Request_ResourceNotFound') {
                        Write-Error -Exception $_.Exception -Message $ResponseContent.error.message -ErrorId $ResponseContent.error.code -Category $_.CategoryInfo.Category -CategoryActivity $_.CategoryInfo.Activity -CategoryReason $_.CategoryInfo.Reason -CategoryTargetName $_.CategoryInfo.TargetName -CategoryTargetType $_.CategoryInfo.TargetType -TargetObject $_.TargetObject -ErrorVariable cmdError -ErrorAction SilentlyContinue
                        Write-Warning $ResponseContent.error.message
                    }
                    else {
                        Write-Error -Exception $_.Exception -Message $ResponseContent.error.message -ErrorId $ResponseContent.error.code -Category $_.CategoryInfo.Category -CategoryActivity $_.CategoryInfo.Activity -CategoryReason $_.CategoryInfo.Reason -CategoryTargetName $_.CategoryInfo.TargetName -CategoryTargetType $_.CategoryInfo.TargetType -TargetObject $_.TargetObject -ErrorVariable cmdError
                    }
                    # generate extra properties for the exception
                    $Properties = @{}
                    $Properties["request"] = '{0} {1}' -f $_.TargetObject.Method, $_.TargetObject.RequestUri.AbsoluteUri
                    $Properties["response"] = $Response 
                    if ($_.Exception.Response.psobject.Properties.Name.Contains("Headers")) {
                        $Properties["date"] = $_.Exception.Response.Headers.GetValues('Date')[0]
                        $Properties["requestId"] = $_.Exception.Response.Headers.GetValues('request-id')[0]
                        $Properties["clientRequestId"] = $_.Exception.Response.Headers.GetValues('client-request-id')[0]
                    }
                    Write-AppInsightsException $cmdError.Exception -Properties $Properties
                }
            }
            else { throw $ErrorRecord }
        }

        function Test-MsGraphBatchError ($BatchResponse, $BatchRequest) {
            if ($BatchResponse.status -ne '200') {
                Write-Debug -Message (ConvertTo-Json $BatchResponse -Depth 3)

                if ($BatchResponse.body.error.code -eq 'Authentication_ExpiredToken' -or $BatchResponse.body.error.code -eq 'Service_ServiceUnavailable' -or $BatchResponse.body.error.code -eq 'Request_UnsupportedQuery') {
                    Write-Error -Message $BatchResponse.body.error.message -ErrorId $BatchResponse.body.error.code -ErrorAction Stop
                }
                else {
                    if ($BatchResponse.body.error.code -eq 'Request_ResourceNotFound') {
                        Write-Error -Message $BatchResponse.body.error.message -ErrorId $BatchResponse.body.error.code -ErrorVariable cmdError -ErrorAction SilentlyContinue
                        Write-Warning $BatchResponse.body.error.message
                    }
                    else {
                        Write-Error -Message $BatchResponse.body.error.message -ErrorId $BatchResponse.body.error.code -ErrorVariable cmdError
                    }
                    # generate extra properties for the exception
                    $Properties = @{}
                    if ($BatchRequest) {
                        $Properties["request"] = "{0} {1}" -f $BatchRequest.method, $BatchRequest.url
                    }
                    if ($BatchResponse.body.error.psobject.Properties.Name.Contains('code') -and $BatchResponse.body.error.psobject.Properties.Name.Contains('message')) {
                        $Properties["response"] = "{0} {1}" -f $BatchResponse.body.error.code, $BatchResponse.body.error.message
                    }
                    if ($BatchResponse.body.error.psobject.Properties.Name.Contains('innerError')) {
                        if ($BatchResponse.body.error.innerError.psobject.Properties.Name.Contains('date')) {
                            $Properties["date"] = $BatchResponse.body.error.innerError.date
                        }
                        if ($BatchResponse.body.error.innerError.psobject.Properties.Name.Contains('request-id')) {
                            $Properties["requestId"] = $BatchResponse.body.error.innerError."request-id"
                        }
                        if ($BatchResponse.body.error.innerError.psobject.Properties.Name.Contains('client-request-id')) {
                            $Properties["clientRequestId"] = $BatchResponse.body.error.innerError."client-request-id"
                        }
                    }
                    Write-AppInsightsException $cmdError.Exception -Properties $Properties
                }
                return $true
            }
            return $false
        }

        function Add-MsGraphRequest {
            param (
                # A collection of request objects.
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object[]] $Requests,
                # Base URL for Microsoft Graph API.
                [Parameter(Mandatory = $false)]
                [uri] $GraphBaseUri = 'https://graph.microsoft.com/'
            )

            process {
                foreach ($Request in $Requests) {
                    if ($DisableBatching) {
                        if ($ProgressState) { Update-Progress $ProgressState -CurrentOperation ('{0} {1}' -f $Request.method.ToUpper(), $Request.url) -IncrementBy 1 }
                        Invoke-MsGraphRequest $Request -GraphBaseUri $GraphBaseUri
                    }
                    else {
                        $listRequests[$GraphBaseUri].Add($Request)
                        ## Invoke when there are enough for a batch
                        while ($listRequests[$GraphBaseUri].Count -ge $BatchSize) {
                            Invoke-MsGraphBatchRequest $listRequests[$GraphBaseUri][0..($BatchSize - 1)] -BatchSize $BatchSize -ProgressState $ProgressState -GraphBaseUri $GraphBaseUri
                            $listRequests[$GraphBaseUri].RemoveRange(0, $BatchSize)
                        }
                    }
                }
            }
        }

        function Invoke-MsGraphBatchRequest {
            param (
                # A collection of request objects.
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object[]] $Requests,
                # Specify Batch size.
                [Parameter(Mandatory = $false)]
                [int] $BatchSize = 20,
                # Use external progress object.
                [Parameter(Mandatory = $false)]
                [psobject] $ProgressState,
                # Base URL for Microsoft Graph API.
                [Parameter(Mandatory = $false)]
                [uri] $GraphBaseUri = 'https://graph.microsoft.com/'
            )

            begin {
                [bool] $ExternalProgress = $false
                if ($ProgressState) { $ExternalProgress = $true }
                else {
                    $ProgressState = Start-Progress -Activity 'Microsoft Graph Requests - Batched' -Total $Requests.Count
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                }
                [uri] $uriEndpoint = [IO.Path]::Combine($GraphBaseUri.AbsoluteUri, '$batch')
                $listRequests = New-Object 'System.Collections.Generic.List[pscustomobject]'
            }

            process {
                foreach ($Request in $Requests) {
                    $listRequests.Add($Request)
                }
            }

            end {
                [array] $BatchRequests = New-MsGraphBatchRequest $listRequests -BatchSize $BatchSize
                for ($iRequest = 0; $iRequest -lt $BatchRequests.Count; $iRequest++) {
                    if ($ProgressState.Total -gt $BatchSize) {
                        Update-Progress $ProgressState -CurrentOperation ('{0} {1}' -f $BatchRequests[$iRequest].method.ToUpper(), $BatchRequests[$iRequest].url) -IncrementBy $BatchRequests[$iRequest].body.requests.Count
                    }
                    $resultsBatch = Invoke-MsGraphRequest $BatchRequests[$iRequest] -NoAppInsights -GraphBaseUri $GraphBaseUri

                    [array] $resultsBatch = $resultsBatch.responses | Sort-Object -Property { [int]$_.id }

                    $throttledRequests = @()
                    [double]$maxRetryAfter = 1.0
                    foreach ($results in ($resultsBatch)) {
                        # check if batch result failed and call the endpoint or throw
                        if ($results.status -eq "429") {
                            # request was throttled
                            $throttledRequests += $listRequests[$results.id]
                            # check if a retry after was recieved
                            if ($results.psobject.Properties.Name.Contains('headers')) {
                                if ($results.headers.psobject.Properties.Name.Contains('Retry-After')) {
                                    $RetryAfter = [double]$results.headers.'Retry-After'
                                    if ($RetryAfter -gt $maxRetryAfter) {
                                        $maxRetryAfter = $RetryAfter
                                    }
                                }
                            }
                            continue
                        }
                        $currentRequest = $BatchRequests[$iRequest] | Where-Object {$_.id -eq $results.id}
                        if (!(Test-MsGraphBatchError $results $currentRequest)) {
                            if ($IncapsulateReferenceListInParentObject -and $listRequests[$results.id].url -match '.*/(.+)/(.+)/((?:transitive)?members|owners)') {
                                [PSCustomObject]@{
                                    id            = $Matches[2]
                                    '@odata.type' = '#{0}' -f (Get-MsGraphEntityType $GraphBaseUri.AbsoluteUri -EntityName $Matches[1])
                                    $Matches[3]   = Complete-MsGraphResult $results.body -DisablePaging:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType -GroupOutputByRequest -Request $listRequests[$results.id] -GraphBaseUri $GraphBaseUri
                                }
                            }
                            else {
                                Complete-MsGraphResult $results.body -DisablePaging:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType -GroupOutputByRequest:$GroupOutputByRequest -Request $listRequests[$results.id] -GraphBaseUri $GraphBaseUri
                            }
                        }
                    }
                    if ($throttledRequests.Count -gt 0) {
                        Write-Warning "$($throttledRequests.Count) requests have been throttled; Retrying after $($maxRetryAfter)s"
                        Start-Sleep -Seconds $maxRetryAfter
                        foreach($request in $throttledRequests) {
                            Invoke-MsGraphRequest $request -NoAppInsights -GraphBaseUri $GraphBaseUri -RetryAfter $RetryAfter
                        }
                    }
                }

                if (!$ExternalProgress) {
                    $Stopwatch.Stop()
                    Write-AppInsightsDependency ('{0} {1}' -f 'POST', $uriEndpoint.AbsolutePath) -Type 'MS Graph' -Data ("{0} {1}`r`n`r`n{2}" -f 'POST', $uriEndpoint.AbsoluteUri, ('{{"requests":[...{0}...]}}' -f $listRequests.Count)) -Duration $Stopwatch.Elapsed -Success ($null -ne $resultsBatch)
                    Stop-Progress $ProgressState
                }
            }
        }

        function Invoke-MsGraphRequest {
            param (
                # A collection of request objects.
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $Request,
                # Do not write application insights dependency.
                [Parameter(Mandatory = $false)]
                [switch] $NoAppInsights,
                # Base URL for Microsoft Graph API.
                [Parameter(Mandatory = $false)]
                [uri] $GraphBaseUri = 'https://graph.microsoft.com/',
                # Number of retries in case of throttling
                [Parameter(Mandatory = $false)]
                [int] $MaxRetries = 5,
                [Parameter(Mandatory = $false)]
                [double] $RetryAfter = 1
            )

            process {
                [uri] $uriEndpoint = $Request.url
                if (!$uriEndpoint.IsAbsoluteUri) {
                    $uriEndpoint = [IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $Request.url.TrimStart('/'))
                }
                #if ($uriEndpoint.Segments -contains 'directoryObjects/') { $NoAppInsights = $true }

                [hashtable] $paramInvokeRestMethod = @{
                    Method = $Request.method
                    Uri    = $uriEndpoint
                }
                if ($Request.psobject.Properties.Name -contains 'headers') { $paramInvokeRestMethod.Add('Headers', $Request.headers) }
                if ($Request.psobject.Properties.Name -contains 'body') {
                    $paramInvokeRestMethod.Add('Body', ($Request.body | ConvertTo-Json -Depth 10 -Compress))
                    $paramInvokeRestMethod.Add('ContentType', 'application/json')
                }

                ## Get results
                $results = $null
                $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
                if (!$NoAppInsights) { $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew() }
                try {
                    for($Retries = 0; $Retries -lt $MaxRetries; $Retries++) {
                        try {
                            $results = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing @paramInvokeRestMethod -ErrorAction Stop
                            # break the loop if no error was raised
                            break
                        }
                        catch {
                            ## error while invoking graph
                            if ($Retries -eq $MaxRetries-1) {
                                # catch error if it was the last try
                                Catch-MsGraphError $_ 
                            }
                            ## check if throttling happened
                            if ($_.Exception.PSobject.Properties.Name.Contains("Response") -and $_.Exception.Response.PSobject.Properties.Name.Contains("StatusCode") -and $_.Exception.Response.StatusCode.value__ -eq 429) {
                                # Get the retry after header
                                try {
                                    $RetryAfter = [double]($_.Exception.Response.Headers.GetValues('Retry-After')[0])
                                } catch {
                                    Write-Verbose "Request throttled but Retry-After not provided ($(Request.url)) using exponential backoff ($(RetryAfter)s)"
                                }
                            }
                            # request had an error and has not reached maximum retries
                            Write-Warning "$($paramInvokeRestMethod['Method']) $($paramInvokeRestMethod['Uri']); error $($_.Exception.Message); attempt $($Retries+1) out of $MaxRetries. Retrying after $($RetryAfter)s"
                            Start-Sleep -Seconds $RetryAfter
                            $RetryAfter = $RetryAfter * 2
                        }                 
                    }
                    if ($results) {
                        if ($IncapsulateReferenceListInParentObject -and $Request.url -match '.*/(.+)/(.+)/((?:transitive)?members|owners)') {
                            [PSCustomObject]@{
                                id            = $Matches[2]
                                '@odata.type' = '#{0}' -f (Get-MsGraphEntityType $GraphBaseUri.AbsoluteUri -EntityName $Matches[1])
                                $Matches[3]   = Complete-MsGraphResult $results -DisablePaging:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType -GroupOutputByRequest -Request $Request -GraphBaseUri $GraphBaseUri
                            }
                        }
                        else {
                            Complete-MsGraphResult $results -DisablePaging:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType -GroupOutputByRequest:$GroupOutputByRequest -Request $Request -GraphBaseUri $GraphBaseUri
                        }       
                    }
                }
                finally {
                    if (!$NoAppInsights) {
                        $Stopwatch.Stop()
                        Write-AppInsightsDependency ('{0} {1}' -f $Request.method.ToUpper(), $uriEndpoint.AbsolutePath) -Type 'MS Graph' -Data ('{0} {1}' -f $Request.method.ToUpper(), $uriEndpoint.AbsoluteUri) -Duration $Stopwatch.Elapsed -Success ($null -ne $results)
                    }
                }
            }
        }

        function Complete-MsGraphResult {
            param (
                # Results from MS Graph API.
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object[]] $Results,
                # Only return first page of results.
                [Parameter(Mandatory = $false)]
                [switch] $DisablePaging,
                # Copy ODataContext to each result value.
                [Parameter(Mandatory = $false)]
                [switch] $KeepODataContext,
                # Add ODataType to each result value.
                [Parameter(Mandatory = $false)]
                [switch] $AddODataType,
                # Group results in array by request.
                [Parameter(Mandatory = $false)]
                [switch] $GroupOutputByRequest,
                # MS Graph request object.
                [Parameter(Mandatory = $false)]
                [psobject] $Request,
                # Base URL for Microsoft Graph API.
                [Parameter(Mandatory = $false)]
                [uri] $GraphBaseUri = 'https://graph.microsoft.com/'
            )

            begin {
                [System.Collections.Generic.List[object]] $listOutput = New-Object 'System.Collections.Generic.List[object]'
            }

            process {
                foreach ($Result in $Results) {
                    $Output = Expand-MsGraphResult $Result -RawOutput:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType
                    if ($GroupOutputByRequest -and $Output) { $listOutput.AddRange([array]$Output) }
                    else { $Output }

                    if (!$DisablePaging -and $Result) {
                        if (Get-ObjectPropertyValue $Result '@odata.nextLink') {
                            [uri] $uriEndpoint = [IO.Path]::Combine($GraphBaseUri.AbsoluteUri, $Request.url.TrimStart('/'))
                            [int] $Total = Get-MsGraphResultsCount $uriEndpoint -GraphBaseUri $GraphBaseUri
                            $Activity = ('Microsoft Graph Request - {0} {1}' -f $Request.method.ToUpper(), $uriEndpoint.AbsolutePath)
                            $ProgressState = Start-Progress -Activity $Activity -Total $Total
                            $ProgressState.CurrentIteration = $Result.value.Count
                            $MaxRetries = 5
                            try {
                                while (Get-ObjectPropertyValue $Result '@odata.nextLink') {
                                    Update-Progress $ProgressState -IncrementBy $Result.value.Count
                                    $nextLink = $Result.'@odata.nextLink'
                                    $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
                                    $Result = $null
                                    [double]$RetryAfter = 1.0
                                    for($Retries = 0; $Retries -lt $MaxRetries; $Retries++) {
                                        try {
                                            $Result = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method Get -Uri $nextLink -Headers $Request.headers -ErrorAction Stop
                                            # break the loop if no error was raised
                                            break
                                        }
                                        catch {
                                            ## error while invoking graph
                                            if ($Retries -eq $MaxRetries-1) {
                                                # catch error if it was the last try
                                                Catch-MsGraphError $_ 
                                            }
                                            # update retry after if throttling
                                            if ($_.Exception.PSobject.Properties.Name.Contains("Response") -and $_.Exception.Response.StatusCode.value__ -eq 429) {
                                                # Get the retry after header
                                                try {
                                                    $RetryAfter = [double]($_.Exception.Response.Headers.GetValues('Retry-After')[0])
                                                } catch {
                                                    Write-Verbose "Request throttled but Retry-After not provided ($nextLink) using exponential backoff ($(RetryAfter)s)"
                                                }
                                            }
                                            # request has encountered and error and has not hit the maximum retires
                                            Write-Warning "GET $nextLink; error '$($_.Exception.Message); attempt $($Retries+1) out of $MaxRetries. Retrying after $($RetryAfter)s"
                                            Start-Sleep -Seconds $RetryAfter
                                            $RetryAfter = $RetryAfter * 2
                                        }
                                    }
                                    if ($Result) {
                                        $Output = Expand-MsGraphResult $Result -RawOutput:$DisablePaging -KeepODataContext:$KeepODataContext -AddODataType:$AddODataType
                                        if ($GroupOutputByRequest -and $Output) { $listOutput.AddRange([array]$Output) }
                                        else { $Output }
                                    }
                                }
                            }
                            finally {
                                Stop-Progress $ProgressState
                            }
                        }
                    }
                }
            }

            end {
                if ($GroupOutputByRequest) { Write-Output $listOutput.ToArray() -NoEnumerate }
            }
        }
    }

    process {
        ## Initialize
        if ($PSBoundParameters.ContainsKey('UniqueId') -and !$UniqueId) { return }
        if ($RelativeUri.OriginalString -eq $UniqueId) { $UniqueId = $null }  # Pipeline string/uri input binds to both parameters so default to just uri

        ## Process Each RelativeUri
        foreach ($uri in $RelativeUri) {
            [string] $BaseUri = $uriGraphVersionBase.AbsoluteUri
            if ($uri.IsAbsoluteUri) {
                if ($uri.AbsoluteUri -match '^https://(.+?)/(v1.0|beta)?') { $BaseUri = $Matches[0] }
                if (!$listRequests.ContainsKey($BaseUri)) { $listRequests.Add($BaseUri, (New-Object 'System.Collections.Generic.List[pscustomobject]')) }
                $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList $uri
            }
            else { $uriQueryEndpoint = New-Object System.UriBuilder -ArgumentList ([IO.Path]::Combine($BaseUri, $uri)) }

            ## Combine query parameters from URI and cmdlet parameters
            [hashtable] $QueryParametersFinal = @{ }
            if ($uriQueryEndpoint.Query) {
                $QueryParametersFinal = ConvertFrom-QueryString $uriQueryEndpoint.Query -AsHashtable
                if ($QueryParameters) {
                    foreach ($ParameterName in $QueryParameters.Keys) {
                        $QueryParametersFinal[$ParameterName] = $QueryParameters[$ParameterName]
                    }
                }
            }
            elseif ($QueryParameters) { $QueryParametersFinal = $QueryParameters }
            if ($Select) { $QueryParametersFinal['$select'] = $Select -join ',' }
            if ($Filter) { $QueryParametersFinal['$filter'] = $Filter }
            if ($Top) { $QueryParametersFinal['$top'] = $Top }
            if ($PSBoundParameters.ContainsKey('Count')) { $QueryParametersFinal['$count'] = ([string]$Count).ToLower() }
            $uriQueryEndpoint.Query = ConvertTo-QueryString $QueryParametersFinal

            ## Expand with UniqueIds
            if ($UniqueId) {
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
                        if ($DisableUniqueIdDeduplication -or $hashUri.Add($uriQueryEndpointUniqueId.Uri)) {
                            if ($EnableInFilter -and $id -match '^[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$') {
                                $listIds.Add($id)
                                while($listIds.Count -ge $InFilterBatchSize) {
                                    # go back to initial uri (without appending id)
                                    $uriQueryEndpointUniqueId = New-Object System.UriBuilder -ArgumentList $uriQueryEndpoint.Uri
                                    # get the query parameters
                                    $QueryParametersInIds = ConvertFrom-QueryString $uriQueryEndpoint.Query -AsHashtable
                                    # get the ids to query
                                    $filterids = $listIds[0..($InFilterBatchSize - 1)]
                                    # append them to "$filter"
                                    if ($QueryParametersInIds.ContainsKey('$filter')) {
                                        $QueryParametersInIds['$filter'] = "($($QueryParametersInIds['$filter'])) and id in ('$($filterids -join "','")')"
                                    } else  {
                                        $QueryParametersInIds['$filter'] = "id in ('$($filterids -join "','")')"
                                    }
                                    # update query 
                                    $uriQueryEndpointUniqueId.Query = ConvertTo-QueryString $QueryParametersInIds
                                    # add new batch request
                                    New-MsGraphRequest $uriQueryEndpointUniqueId.Uri -Headers @{ ConsistencyLevel = $ConsistencyLevel } | Add-MsGraphRequest -GraphBaseUri $BaseUri
                                    # remove ids from ids to request
                                    $listIds.RemoveRange(0, $InFilterBatchSize)
                                    # update progress
                                    if ($ProgressState) { $ProgressState.CurrentIteration += $InFilterBatchSize - 1 }
                                }
                            }
                            elseif (!$DisableGetByIdsBatching -and $id -match '^[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$' -and $uriQueryEndpoint.Uri.Segments.Count -eq 3 -and $uriQueryEndpoint.Uri.Segments[2] -in ('directoryObjects', 'users', 'groups', 'devices', 'servicePrincipals', 'applications') -and ($QueryParametersFinal.Count -eq 0 -or ($QueryParametersFinal.Count -eq 1 -and $QueryParametersFinal.ContainsKey('$select')))) {
                                $listIds.Add($id)
                                while ($listIds.Count -ge $GetByIdsBatchSize) {
                                    New-MsGraphGetByIdsRequest $listIds[0..($GetByIdsBatchSize - 1)] -Types $uriQueryEndpoint.Uri.Segments[2].TrimEnd('s') -Select $QueryParametersFinal['$select'] -BatchSize $GetByIdsBatchSize | Add-MsGraphRequest -GraphBaseUri $BaseUri
                                    $listIds.RemoveRange(0, $GetByIdsBatchSize)
                                    if ($ProgressState) { $ProgressState.CurrentIteration += $GetByIdsBatchSize - 1 }
                                }
                            }
                            else {
                                New-MsGraphRequest $uriQueryEndpointUniqueId.Uri -Headers @{ ConsistencyLevel = $ConsistencyLevel } | Add-MsGraphRequest -GraphBaseUri $BaseUri
                            }
                        }
                        elseif ($ProgressState) { $ProgressState.Total -= 1 }
                    }
                    elseif ($ProgressState) { $ProgressState.Total -= 1 }
                }
            }
            else {
                New-MsGraphRequest $uriQueryEndpoint.Uri -Headers @{ ConsistencyLevel = $ConsistencyLevel } | Add-MsGraphRequest -GraphBaseUri $BaseUri
            }
        }
    }

    end {
        ## Complete Remaining Ids
        if ($listIds.Count -gt 0) {
            New-MsGraphGetByIdsRequest $listIds -Types $uriQueryEndpoint.Uri.Segments[2].TrimEnd('s') -Select $QueryParametersFinal['$select'] -BatchSize $GetByIdsBatchSize | Add-MsGraphRequest -GraphBaseUri $BaseUri
            if ($ProgressState) { $ProgressState.CurrentIteration += $listIds.Count - 1 }
        }
        ## Finish requests
        foreach ($BaseUri in $listRequests.Keys) {
            if ($listRequests[$BaseUri].Count -eq 1) {
                Invoke-MSGraphRequest $listRequests[$BaseUri][0] -GraphBaseUri $BaseUri
            }
            elseif ($listRequests[$BaseUri].Count -gt 0) {
                Invoke-MsGraphBatchRequest $listRequests[$BaseUri] -BatchSize $BatchSize -ProgressState $ProgressState -GraphBaseUri $BaseUri
            }
            if (!$DisableBatching -and $ProgressState -and $ProgressState.CurrentIteration -gt 1) {
                [uri] $uriEndpoint = [IO.Path]::Combine($BaseUri, '$batch')
                Write-AppInsightsDependency ('{0} {1}' -f 'POST', $uriEndpoint.AbsolutePath) -Type 'MS Graph' -Data ("{0} {1}`r`n`r`n{2}" -f 'POST', $uriEndpoint.AbsoluteUri, ('{{"requests":[...{0}...]}}' -f $ProgressState.CurrentIteration)) -Duration $ProgressState.Stopwatch.Elapsed -Success $?
            }
        }
        ## Clean-up
        if ($ProgressState) { Stop-Progress $ProgressState }
    }
}



<#
.SYNOPSIS
    New request object containing Microsoft Graph API details.
.EXAMPLE
    PS C:\>New-MsGraphRequest 'users'
    Return request object for GET /users.
.EXAMPLE
    PS C:\>New-MsGraphRequest -Method Get -Uri 'https://graph.microsoft.com/v1.0/users'
    Return request object for GET /users.
.EXAMPLE
    PS C:\>New-MsGraphRequest -Method Patch -Uri 'users/{id}' -Body ([PsCustomObject]{ displayName = "Joe Cool" }
    Return request object for PATCH /users/{id} with a body payload to update the displayName.
#>
function New-MsGraphRequest {
    [CmdletBinding()]
    param (
        # Specifies the method used for the web request.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [int] $RequestId = 0,
        # Specifies the method used for the web request.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Get', 'Head', 'Post', 'Put', 'Delete', 'Trace', 'Options', 'Merge', 'Patch')]
        [string] $Method = 'Get',
        # Specifies the Uniform Resource Identifier (URI) of the Internet resource to which the web request is sent.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [uri[]] $Uri,
        # Specifies the headers of the web request.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [hashtable] $Headers,
        # Specifies the body of the request.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject] $Body
    )

    process {
        if (!$Headers) { $Headers = @{} }
        for ($iRequest = 0; $iRequest -lt $Uri.Count; $iRequest++) {
            if ($Body) {
                if (!$Headers.ContainsKey('Content-Type')) { $Headers.Add('Content-Type', 'application/json') }
            }
            [string] $url = $Uri[$iRequest].PathAndQuery
            if (!$url) { $url = $Uri[$iRequest].ToString() }
            [pscustomobject]@{
                id      = $RequestId + $iRequest
                method  = $Method.ToUpper()
                url     = $url -replace '^(https://.+?/)?/?(v1.0/|beta/)?', '/'
                headers = $Headers
                body    = $Body
            }
        }
    }
}

function New-MsGraphGetByIdsRequest {
    [CmdletBinding()]
    param (
        # A collection of IDs for which to return objects.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [guid[]] $Ids,
        # A collection of resource types that specifies the set of resource collections to search.
        [Parameter(Mandatory = $false)]
        [string[]] $Types,
        # Filters properties (columns).
        [Parameter(Mandatory = $false)]
        [string[]] $Select,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 1000
    )

    begin {
        $Types = $Types | Where-Object { $_ -ne 'directoryObject' }
        if (!$Select) { $Select = "*" }
        $listIds = New-Object 'System.Collections.Generic.List[guid]'
    }

    process {
        foreach ($Id in $Ids) {
            $listIds.Add($Id)

            ## Process IDs when a full batch is reached
            while ($listIds.Count -ge $BatchSize) {
                New-MsGraphRequest ('/directoryObjects/getByIds?$select={0}' -f ($Select -join ',')) -Method Post -Headers @{ 'Content-Type' = 'application/json' } -Body ([PSCustomObject]@{
                        ids   = $listIds[0..($BatchSize - 1)]
                        types = $Types
                    })
                $listIds.RemoveRange(0, $BatchSize)
            }
        }
    }

    end {
        ## Process any remaining IDs
        if ($listIds.Count -gt 0) {
            New-MsGraphRequest ('/directoryObjects/getByIds?$select={0}' -f ($Select -join ',')) -Method Post -Headers @{ 'Content-Type' = 'application/json' } -Body ([PSCustomObject]@{
                    ids   = $listIds
                    types = $Types
                })
        }
    }
}

function New-MsGraphBatchRequest {
    [CmdletBinding()]
    param (
        # A collection of request objects.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object[]] $Requests,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20,
        # Specify depth of nested batches. MS Graph does not currently support batch nesting.
        [Parameter(Mandatory = $false)]
        [int] $Depth = 1
    )

    process {
        for ($iRequest = 0; $iRequest -lt $Requests.Count; $iRequest += [System.Math]::Pow($BatchSize, $Depth)) {
            $indexEnd = [System.Math]::Min($iRequest + [System.Math]::Pow($BatchSize, $Depth) - 1, $Requests.Count - 1)

            ## Reset ID Order
            for ($iId = $iRequest; $iId -le $indexEnd; $iId++) {
                $Requests[$iId].id = $iId
            }

            ## Generate Batch Request
            if ($Depth -gt 1) {
                $BatchRequest = New-MsGraphBatchRequest $Requests[$iRequest..$indexEnd] -Depth ($Depth - 1)
            }
            else {
                $BatchRequest = $Requests[$iRequest..$indexEnd]
            }

            New-MsGraphRequest -RequestId $iRequest -Method Post -Uri '/$batch' -Headers @{ 'Content-Type' = 'application/json' } -Body ([PSCustomObject]@{
                    requests = $BatchRequest
                })
        }
    }
}

function Get-MsGraphMetadata {
    param (
        # Metadata URL for Microsoft Graph API.
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [uri] $Uri = 'https://graph.microsoft.com/v1.0/$metadata',
        # Force a refresh of metadata.
        [Parameter(Mandatory = $false)]
        [switch] $ForceRefresh
    )

    if (!(Get-Variable MsGraphMetadataCache -Scope Script -ErrorAction SilentlyContinue)) { New-Variable -Name MsGraphMetadataCache -Scope Script -Value (New-Object 'System.Collections.Generic.Dictionary[string,xml]') }
    if (!$Uri.AbsolutePath.EndsWith('$metadata')) { $Uri = ([IO.Path]::Combine($Uri.AbsoluteUri, '$metadata')) }
    [string] $BaseUri = $Uri.AbsoluteUri
    if ($Uri.AbsoluteUri -match ('^.+{0}' -f ([regex]::Escape($Uri.AbsolutePath)))) { $BaseUri = $Matches[0] }

    if ($ForceRefresh -or !$script:MsGraphMetadataCache.ContainsKey($BaseUri)) {
        #$MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
        try {
            $script:MsGraphMetadataCache[$BaseUri] = Invoke-RestMethod -UseBasicParsing -Method Get -Uri $Uri -ErrorAction Ignore
        }
        catch {}
    }
    return $script:MsGraphMetadataCache[$BaseUri]
}

function Get-MsGraphEntityType {
    param (
        # Metadata URL for Microsoft Graph API.
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [uri] $Uri = 'https://graph.microsoft.com/v1.0/$metadata',
        # Name of endpoint.
        [Parameter(Mandatory = $false)]
        [string] $EntityName
    )

    process {
        $MsGraphMetadata = Get-MSGraphMetadata $Uri

        if (!$EntityName -and $Uri.Fragment -match '^#(.+?)(\(.+\))?(/\$entity)?$') { $EntityName = $Matches[1] }

        foreach ($Schema in $MsGraphMetadata.Edmx.DataServices.Schema) {
            foreach ($EntitySet in $Schema.EntityContainer.EntitySet) {
                if ($EntitySet.Name -eq $EntityName) {
                    return $EntitySet.EntityType
                }
            }
        }
    }
}

function Expand-MsGraphResult {
    param (
        # Results from MS Graph API.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object[]] $Results,
        # Do not expand result values
        [Parameter(Mandatory = $false)]
        [switch] $RawOutput,
        # Copy ODataContext to each result value
        [Parameter(Mandatory = $false)]
        [switch] $KeepODataContext,
        # Add ODataType to each result value
        [Parameter(Mandatory = $false)]
        [switch] $AddODataType
    )

    process {
        foreach ($Result in $Results) {
            if (!$RawOutput -and (Get-ObjectPropertyValue $Result.psobject.Properties 'Name') -contains 'value') {
                foreach ($ResultValue in $Result.value) {
                    if ($AddODataType) {
                        $ODataType = Get-ObjectPropertyValue $Result '@odata.context' | Get-MsGraphEntityType
                        if ($ODataType) { $ODataType = '#' + $ODataType }
                        if ($ResultValue -is [hashtable] -and !$ResultValue.ContainsKey('@odata.type')) {
                            $ResultValue.Add('@odata.type', $ODataType)
                        }
                        elseif ($ResultValue.psobject.Properties.Name -notcontains '@odata.type') {
                            $ResultValue | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $ODataType
                        }
                    }
                    if ($KeepODataContext) {
                        if ($ResultValue -is [hashtable]) {
                            $ResultValue.Add('@odata.context', ('{0}/$entity' -f $Result.'@odata.context'))
                        }
                        else {
                            $ResultValue | Add-Member -MemberType NoteProperty -Name '@odata.context' -Value ('{0}/$entity' -f $Result.'@odata.context')
                        }
                    }
                    Write-Output $ResultValue
                }
            }
            else { Write-Output $Result }
        }
    }
}

function Get-MsGraphResultsCount {
    [CmdletBinding()]
    param (
        # Graph endpoint such as "users".
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [uri] $Uri,
        # Base URL for Microsoft Graph API.
        [Parameter(Mandatory = $false)]
        [uri] $GraphBaseUri = 'https://graph.microsoft.com/'
    )

    process {
        if ($Uri.IsAbsoluteUri) {
            $uriEndpointCount = New-Object System.UriBuilder -ArgumentList $Uri -ErrorAction Stop
        }
        else {
            $uriEndpointCount = New-Object System.UriBuilder -ArgumentList $GraphBaseUri -ErrorAction Stop
        }
        ## Remove $ref from path
        $uriEndpointCount.Path = $uriEndpointCount.Path -replace '/\$ref$', ''
        ## Add $count segment to path
        $uriEndpointCount.Path = ([IO.Path]::Combine($uriEndpointCount.Path, '$count'))
        ## $count is not supported with $expand parameter so remove it.
        [hashtable] $QueryParametersUpdated = ConvertFrom-QueryString $uriEndpointCount.Query -AsHashtable
        if ($QueryParametersUpdated.ContainsKey('$expand')) { $QueryParametersUpdated.Remove('$expand') }
        $uriEndpointCount.Query = ConvertTo-QueryString $QueryParametersUpdated
        $MsGraphSession = Confirm-ModuleAuthentication -MsGraphSession -ErrorAction Stop
        [int] $Count = $null
        try {
            $Count = Invoke-RestMethod -WebSession $MsGraphSession -UseBasicParsing -Method Get -Uri $uriEndpointCount.Uri -Headers @{ ConsistencyLevel = 'eventual' } -ErrorAction Ignore
        }
        catch {}
        return $Count
    }
}
