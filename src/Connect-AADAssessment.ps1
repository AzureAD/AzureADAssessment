<#
.SYNOPSIS
    Connect the Azure AD Assessment module to Azure AD tenant.
.DESCRIPTION
    This command will connect Microsoft.Graph, AzureAD, and MSOnline modules to your Azure AD tenant.
.EXAMPLE
    PS C:\>Connect-AADAssessment
    Connect to home tenant of authenticated user.
.EXAMPLE
    PS C:\>Connect-AADAssessment -TenantId '00000000-0000-0000-0000-000000000000'
    Connect to specified tenant.
#>
function Connect-AADAssessment {
    [CmdletBinding(DefaultParameterSetName = 'PublicClient')]
    param (
        # Specifies the client application or client application options to use for authentication.
        [Parameter(Mandatory = $true, ParameterSetName = 'InputObject', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object] $ClientApplication,
        # Identifier of the client requesting the token.
        [Parameter(Mandatory = $false, ParameterSetName = 'PublicClient', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate', Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string] $ClientId = 'c62a9fcb-53bf-446e-8063-ea6e2bfcc023',
        # Client assertion certificate of the client requesting the token.
        [Parameter(Mandatory = $true, ParameterSetName = 'ConfidentialClientCertificate', ValueFromPipelineByPropertyName = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $ClientCertificate,
        # Instance of Azure Cloud
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Global', 'China', 'Germany', 'USGov', 'USGovDoD')]
        [string] $CloudEnvironment = 'Global',
        # Tenant identifier of the authority to issue token.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [string] $TenantId = 'organizations',
        # Stay signed in across PowerShell sessions on current device.
        #[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        #[switch] $StaySignedIn,
        # Disable Telemetry
        [Parameter(Mandatory = $false)]
        [switch] $DisableTelemetry
    )

    ## Update Telemetry Setting
    if ($PSBoundParameters.ContainsKey($DisableTelemetry)) { Set-Config -AIDisabled $DisableTelemetry }

    ## Track Command Execution and Performance
    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        ## Update WebSession User Agent String with Module Info
        $script:MsGraphSession.UserAgent = $script:MsGraphSession.UserAgent -replace 'AzureADAssessment', ('{0}/{1}' -f $PSCmdlet.MyInvocation.MyCommand.Module.Name, $MyInvocation.MyCommand.Module.Version)

        ## Create Client Application
        switch ($PSCmdlet.ParameterSetName) {
            'InputObject' {
                $script:ConnectState.ClientApplication = $ClientApplication
                break
            }
            'PublicClient' {
                $script:ConnectState.ClientApplication = New-MsalClientApplication -ClientId $ClientId -TenantId $TenantId -AzureCloudInstance $script:mapMgEnvironmentToAzureCloudInstance[$CloudEnvironment] -RedirectUri 'http://localhost'
                #$script:ConnectState.ClientApplication = New-MsalClientApplication -ClientId $ClientId -TenantId $TenantId -AzureCloudInstance $script:mapMgEnvironmentToAzureCloudInstance[$CloudEnvironment] -RedirectUri 'urn:ietf:wg:oauth:2.0:oob'
                break
            }
            'ConfidentialClientCertificate' {
                $script:ConnectState.ClientApplication = New-MsalClientApplication -ClientId $ClientId -ClientCertificate $ClientCertificate -TenantId $TenantId -AzureCloudInstance $script:mapMgEnvironmentToAzureCloudInstance[$CloudEnvironment]
                break
            }
        }
        #if ($StaySignedIn) { $script:ConnectState.ClientApplication | Enable-MsalTokenCacheOnDisk }
        $script:ConnectState.CloudEnvironment = $CloudEnvironment

        Confirm-ModuleAuthentication $script:ConnectState.ClientApplication -CloudEnvironment $script:ConnectState.CloudEnvironment -ErrorAction Stop
        #Get-MgContext
        #Get-AzureADCurrentSessionInfo
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}
