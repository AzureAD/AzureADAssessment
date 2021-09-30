
function Confirm-ModuleAuthentication {
    param (
        # Specifies the client application or client application options to use for authentication.
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [psobject] $ClientApplication = $script:ConnectState.ClientApplication,
        # Instance of Azure Cloud
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Global', 'China', 'Germany', 'USGov', 'USGovDoD')]
        [string] $CloudEnvironment = $script:ConnectState.CloudEnvironment,
        # User account to authenticate
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $User,
        # Ignore any access token in the user token cache and attempt to acquire new access token using the refresh token for the account if one is available.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch] $ForceRefresh,
        # Return MsGraph WebSession object for use with Invoke-RestMethod command
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch] $MsGraphSession,
        # CorrelationId
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [guid] $CorrelationId = (New-Guid),
        # Scopes for AAD Graph
        #[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        #[string[]] $AadGraphScopes = 'https://graph.windows.net/Directory.Read.All',
        # Scopes for MS Graph
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]] $MsGraphScopes = @(
            'Organization.Read.All'
            'RoleManagement.Read.Directory'
            #'Application.Read.All'
            'User.Read.All'
            'Group.Read.All'
            'Policy.Read.All'
            'Directory.Read.All'
            #'SecurityEvents.Read.All'
            #'Reports.Read.All'
            #'AuditLog.Read.All'
        )
    )

    ## Add Microsoft Graph endpoint for the appropriate cloud
    for ($iScope = 0; $iScope -lt $MsGraphScopes.Count; $iScope++) {
        if (!$MsGraphScopes[$iScope].Contains('//')) {
            $MsGraphScopes[$iScope] = [IO.Path]::Combine($script:mapMgEnvironmentToMgEndpoint[$CloudEnvironment], $MsGraphScopes[$iScope])
        }
    }

    if (!$MsGraphScopes.Contains('openid')) { $MsGraphScopes += 'openid' }

    ## Throw error if no client application exists
    if (!$script:ConnectState.ClientApplication) {
        $Exception = New-Object System.Security.Authentication.AuthenticationException -ArgumentList ('You must call the Connect-AADAssessment cmdlet before calling any other cmdlets.')
        Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::AuthenticationError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConnectAADAssessmentRequired' -ErrorAction Stop
    }

    ## Initialize
    #if (!$User) { $User = Get-MsalAccount $script:ConnectState.ClientApplication | Select-Object -First 1 -ExpandProperty Username }
    if ($script:AppInsightsRuntimeState.OperationStack.Count -gt 0) {
        $CorrelationId = $script:AppInsightsRuntimeState.OperationStack.Peek().Id
    }
    [hashtable] $paramMsalToken = @{
        #CorrelationId = $CorrelationId
    }
    if (!$User -and !(Get-MsalAccount $ClientApplication)) {
        # if ($PSVersionTable.PSEdition -eq 'Core') {
        #     $paramMsalToken.Add('DeviceCode', $true)
        # }
        # else {
            $paramMsalToken.Add('Interactive', $true)
        #}
    }

    ## Get Tokens
    $MsGraphToken = $null
    #$AadGraphToken = $null
    if ($ClientApplication -is [Microsoft.Identity.Client.IPublicClientApplication]) {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            #$MsGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes $MsGraphScopes -ExtraScopesToConsent $AadGraphScopes -UseEmbeddedWebView:$false -ForceRefresh:$ForceRefresh -CorrelationId $CorrelationId -Interactive:$Interactive -Verbose:$false -ErrorAction Stop
            #$AadGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes $AadGraphScopes -UseEmbeddedWebView:$false -ForceRefresh:$ForceRefresh -CorrelationId $CorrelationId -Verbose:$false -ErrorAction Stop
            $MsGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes $MsGraphScopes -UseEmbeddedWebView:$true -ForceRefresh:$ForceRefresh -CorrelationId $CorrelationId -LoginHint $User @paramMsalToken -Verbose:$false -ErrorAction Stop
            #$AadGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes 'https://graph.windows.net/.default' -UseEmbeddedWebView:$true -ForceRefresh:$ForceRefresh -CorrelationId $CorrelationId -LoginHint $User -Verbose:$false -ErrorAction Stop
        }
        catch { throw }
        finally {
            $Stopwatch.Stop()
            if (!$script:ConnectState.MsGraphToken -or $paramMsalToken.ContainsKey('Interactive')) {
                Write-AppInsightsDependency 'GET Access Token (Interactive)' -Type 'Azure AD' -Data 'GET Access Token (Interactive)' -Duration $Stopwatch.Elapsed -Success ($null -ne $MsGraphToken)
            }
            elseif ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken) {
                Write-AppInsightsDependency 'GET Access Token' -Type 'Azure AD' -Data 'GET Access Token' -Duration $Stopwatch.Elapsed -Success ($null -ne $MsGraphToken)
            }
        }
        if (!$script:ConnectState.MsGraphToken -or ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken)) {
            Write-Verbose 'Connecting Modules...'
            #Connect-MgGraph -Environment $CloudEnvironment -TenantId $MsGraphToken.TenantId -AccessToken $MsGraphToken.AccessToken | Out-Null
            #Connect-AzureAD -AzureEnvironmentName $mapMgEnvironmentToAzureEnvironment[$CloudEnvironment] -TenantId $AadGraphToken.TenantId -AadAccessToken $AadGraphToken.AccessToken -MsAccessToken $MsGraphToken.AccessToken -AccountId $AadGraphToken.Account.Username | Out-Null
            #Write-Warning ('Because this command obtains an access token for use with other modules such as AzureAD, those external module commands cannot automatically refresh the tokens when they expire or are revoked. To maintain access, this command must be run again when the current token expires at "{0:t}".' -f [System.DateTimeOffset]::FromUnixTimeSeconds((Expand-JsonWebTokenPayload $AadGraphToken.AccessToken).exp).ToLocalTime())
            if ($script:MsGraphSession.Headers.ContainsKey('Authorization')) {
                $script:MsGraphSession.Headers['Authorization'] = $MsGraphToken.CreateAuthorizationHeader()
            }
            else {
                $script:MsGraphSession.Headers.Add('Authorization', $MsGraphToken.CreateAuthorizationHeader())
            }
        }
    }
    else {
        Write-Warning 'Using a confidential client is non-interactive and requires that the necessary scopes/permissions be added to the application or have permissions on-behalf-of a user.'
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $MsGraphToken = Get-MsalToken -ConfidentialClientApplication $ClientApplication -Scopes 'https://graph.microsoft.com/.default' -CorrelationId $CorrelationId -Verbose:$false -ErrorAction Stop
            #$AadGraphToken = Get-MsalToken -ConfidentialClientApplication $ClientApplication -Scopes 'https://graph.windows.net/.default' -CorrelationId $CorrelationId -Verbose:$false -ErrorAction Stop
        }
        catch { throw }
        finally {
            $Stopwatch.Stop()
            if (!$script:ConnectState.MsGraphToken -or ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken)) {
                Write-AppInsightsDependency 'GET Access Token (Confidential Client)' -Type 'Azure AD' -Data 'GET Access Token (Confidential Client)' -Duration $Stopwatch.Elapsed -Success ($null -ne $MsGraphToken)
            }
        }
        if (!$script:ConnectState.MsGraphToken -or ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken)) {
            Write-Verbose 'Connecting Modules...'
            #$JwtPayload = Expand-JsonWebTokenPayload $AadGraphToken.AccessToken
            #Connect-MgGraph -Environment $CloudEnvironment -TenantId $MsGraphToken.TenantId -AccessToken $MsGraphToken.AccessToken | Out-Null
            #Connect-AzureAD -AzureEnvironmentName $mapMgEnvironmentToAzureEnvironment[$CloudEnvironment] -TenantId $JwtPayload.tid -AadAccessToken $AadGraphToken.AccessToken -MsAccessToken $MsGraphToken.AccessToken -AccountId $JwtPayload.sub | Out-Null
            #Write-Warning ('Because this command obtains an access token for use with other modules such as AzureAD, those external module commands cannot automatically refresh the tokens when they expire or are revoked. To maintain access, this command must be run again when the current token expires at "{0:t}".' -f [System.DateTimeOffset]::FromUnixTimeSeconds((Expand-JsonWebTokenPayload $AadGraphToken.AccessToken).exp).ToLocalTime())
            if ($script:MsGraphSession.Headers.ContainsKey('Authorization')) {
                $script:MsGraphSession.Headers['Authorization'] = $MsGraphToken.CreateAuthorizationHeader()
            }
            else {
                $script:MsGraphSession.Headers.Add('Authorization', $MsGraphToken.CreateAuthorizationHeader())
            }
        }
    }
    $script:ConnectState.MsGraphToken = $MsGraphToken
    #$script:ConnectState.AadGraphToken = $AadGraphToken

    if ($MsGraphSession) {
        Write-Output $script:MsGraphSession
    }
}
