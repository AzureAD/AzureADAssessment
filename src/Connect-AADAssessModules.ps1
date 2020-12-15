function Connect-AADAssessModules {
    param (
        # Specifies the client application or client application options to use for authentication.
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object] $ClientApplication = $script:ConnectState.ClientApplication,
        # Instance of Azure Cloud
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Global', 'China', 'Germany', 'USGov', 'USGovDoD')]
        [string] $CloudEnvironment = $script:ConnectState.CloudEnvironment,
        # Scopes required by AzureAD PowerShell Module for AAD Graph
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]] $AadGraphScopes = 'https://graph.windows.net/Directory.AccessAsUser.All',
        # Scopes required by AzureAD PowerShell Module for MS Graph
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string[]] $MsGraphScopes = @(
            'https://graph.microsoft.com/AuditLog.Read.All'
            'https://graph.microsoft.com/Directory.AccessAsUser.All'
            'https://graph.microsoft.com/Directory.ReadWrite.All'
            'https://graph.microsoft.com/Group.ReadWrite.All'
            'https://graph.microsoft.com/IdentityProvider.ReadWrite.All'
            'https://graph.microsoft.com/Policy.ReadWrite.TrustFramework'
            'https://graph.microsoft.com/PrivilegedAccess.ReadWrite.AzureAD'
            'https://graph.microsoft.com/PrivilegedAccess.ReadWrite.AzureResources'
            'https://graph.microsoft.com/TrustFrameworkKeySet.ReadWrite.All'
            'https://graph.microsoft.com/User.Invite.All'
        )
    )

    ## Throw error
    if (!$script:ConnectState.ClientApplication) {
        $Exception = New-Object System.Security.Authentication.AuthenticationException -ArgumentList ('You must call the Connect-AADAssessment cmdlet before calling any other cmdlets.')
        Write-Error -Exception $Exception -Category ([System.Management.Automation.ErrorCategory]::AuthenticationError) -CategoryActivity $MyInvocation.MyCommand -ErrorId 'ConnectAADAssessmentRequired' -ErrorAction Stop
    }
    
    ## Get Tokens for Connect-AzureAD command
    if ($ClientApplication -is [Microsoft.Identity.Client.IPublicClientApplication]) {
        $MsGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes $MsGraphScopes -ExtraScopesToConsent $AadGraphScopes -UseEmbeddedWebView:$false -ErrorAction Stop
        $AadGraphToken = Get-MsalToken -PublicClientApplication $ClientApplication -Scopes $AadGraphScopes -UseEmbeddedWebView:$false -ErrorAction Stop
        if (!$script:ConnectState.MsGraphToken -or ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken) -or !$script:ConnectState.AadGraphToken -or ($script:ConnectState.AadGraphToken.AccessToken -ne $AadGraphToken.AccessToken)) {
            Write-Verbose 'Connecting Modules...'
            Connect-MgGraph -Environment $CloudEnvironment -TenantId $MsGraphToken.TenantId -AccessToken $MsGraphToken.AccessToken | Out-Null
            Connect-AzureAD -AzureEnvironmentName $mapMgEnvironmentToAzureEnvironment[$CloudEnvironment] -TenantId $AadGraphToken.TenantId -AadAccessToken $AadGraphToken.AccessToken -MsAccessToken $MsGraphToken.AccessToken -AccountId $AadGraphToken.Account.Username | Out-Null
        }
    }
    else {
        Write-Warning 'Using a confidential client is non-interactive and requires that the necessary scopes/permissions be added to the application or have permissions on-behalf-of a user.'
        $MsGraphToken = Get-MsalToken -ConfidentialClientApplication $ClientApplication -Scopes 'https://graph.microsoft.com/.default' -ErrorAction Stop
        $AadGraphToken = Get-MsalToken -ConfidentialClientApplication $ClientApplication -Scopes 'https://graph.windows.net/.default' -ErrorAction Stop
        if (!$script:ConnectState.MsGraphToken -or ($script:ConnectState.MsGraphToken.AccessToken -ne $MsGraphToken.AccessToken) -or !$script:ConnectState.AadGraphToken -or ($script:ConnectState.AadGraphToken.AccessToken -ne $AadGraphToken.AccessToken)) {
            Write-Verbose 'Connecting Modules...'
            $JwtPayload = Expand-JsonWebTokenPayload $AadGraphToken.AccessToken
            Connect-MgGraph -Environment $CloudEnvironment -TenantId $MsGraphToken.TenantId -AccessToken $MsGraphToken.AccessToken | Out-Null
            Connect-AzureAD -AzureEnvironmentName $mapMgEnvironmentToAzureEnvironment[$CloudEnvironment] -TenantId $JwtPayload.tid -AadAccessToken $AadGraphToken.AccessToken -MsAccessToken $MsGraphToken.AccessToken -AccountId $JwtPayload.sub | Out-Null
        }
    }
    $script:ConnectState.MsGraphToken = $MsGraphToken
    $script:ConnectState.AadGraphToken = $AadGraphToken
    #Write-Warning ('Because this command connects the AzureAD module by obtaining access tokens outside the module itself, the AzureAD module commands cannot automatically refresh the tokens when they expire or are revoked. To maintain access, this command must be run again when the current token expires at "{0:t}".' -f [System.DateTimeOffset]::FromUnixTimeSeconds((Expand-JsonWebTokenPayload $AadGraphToken.AccessToken).exp).ToLocalTime())
}
