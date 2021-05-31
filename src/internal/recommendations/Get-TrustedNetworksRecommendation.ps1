<#
.SYNOPSIS
    Produces the Azure AD Assessment recommendations for Trusted Network Locations.
.DESCRIPTION
    This cmdlet generates the recommendations for Trusted network locations.
    Defining trusted network location improves detection of risks events and provides more flexibility in conditional access policies.
.EXAMPLE
    PS C:\> Get-TrustedNetworkRecommendation -Path "C:\AzureADAssessment\AzureADAssessment-contoso.onmicrosoft.com"
    Reads Trusted network configurations from "C:\AzureADAssessment\AzureADAssessment-contoso.onmicrosoft.com" and generate recommendation.
#>
function Get-TrustedNetworksRecommendation {
    [CmdletBinding()]
    param (
        # Specifies a path where extracted data resides (folder)
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string] $Path
    )

    #Start-AppInsightsRequest $MyInvocation.MyCommand.Name

    ### Prepare paths
    $AssessmentDetailPath = Join-Path $Path "AzureADAssessment.json"

    ### Read assessment data
    $AssessmentDetail = Get-Content $AssessmentDetailPath -Raw | ConvertFrom-Json

    ### Generate AAD data path
    $AADPath = Join-Path $Path "AAD-$($AssessmentDetail.AssessmentTenantDomain)"

    ### Get trusted network configuration from file
    $namedLocations = get-content -Path (Join-Path $AADPath "namedLocations.json") | ConvertFrom-Json

    $trustedNetworks = @($namedLocations | Where-Object { $_.isTrusted })

    if ($trustedNetworks.Count -eq 0) {
        ### Generate recommendation
        # TODO: add check for auth type Federated/PTA/PHS and update the priority accordingly
        #       with federation the "insideCorporateNetwork" claim can be defined which would reduce priority to P2
        $rec = "" | select-object Category,Area,Name,Summary,Recommendation,Priority,DataReport
        $rec.Category = "Access Management"
        $rec.Area = "Access Policies"
        $rec.Name = "Trusted networks"
        $rec.Summary = "Trusted network is a signal leveraged by identity protection to improve risk detection. Defining your trusted networks will improve detection of risk events"
        $rec.Recommendation = "Define trusted networks"
        $rec.Priority = "P1"
        $rec.DataReport = Join-Path $AADPath "namedLocations.json"
        $rec
    }

    ### Get conditional access policies from file
    # REM: should this check be made in conditional access recommendation
    $CAPolicies = get-content -Path (Join-Path $AADPath "conditionalAccessPolicies.json") | ConvertFrom-Json

    # filter enabled policies
    $enabledCAPolicies = @($CAPolicies | Where-Object { $_.state -eq "enabled"})

    # list policies using trusted networks conditions
    $trustedNetworkPolicies = @($enabledCAPolicies | Where-Object { 
        $null -ne $_.conditions.locations -and (`
            $_.conditions.locations.includedLocations -contains "AllTrusted" -or `
            $_.conditions.locations.excludedLocations -contains "AllTrusted"
        )
    })

    # list policies using riskState conditions
    $riskPolicies = @($enabledCAPolicies | Where-Object {
        $_.conditions.signInRiskLevels.Count -gt 0 -or `
        $_.conditions.userRiskLevels.Count -gt 0
    })

    # list policies using devices conditions
    # TODO: check with Device ABAC too?
    $devicePolicies = @($enabledCAPolicies | Where-Object {
        $_.conditions.psobject.properties.match('devices').Count -and `
        $null -ne $_.conditions.devices -and (`
            $_.conditions.devices.excludeDevices.Count -gt 0 -or `
            $_.conditions.devices.excludeDevicesStates.Count -gt 0
        )
    })

    # list policies using device grant controls
    $deviceGrantPolicies = @($enabledCAPolicies | Where-Object {
        $null -ne $_.grantControls -and (`
            $_.grantControls.builtInControls -contains "compliantDevice" -or `
            $_.grantControls.builtInControls -contains "domainJoinDevice"
        )
    })

    # generate recommandation to use network location if risk or device are not used
    if ($trustedNetworkPolicies.Count -eq 0 -and $riskPolicies.Count -eq 0 -and ($devicePolicies.Count -eq 0 -or $deviceGrantPolicies.Count -eq 0)) {
        $rec = "" | select-object Category,Area,Name,Summary,Recommendation,Priority,DataReport
        $rec.Category = "Access Management"
        $rec.Area = "Access Policies"
        $rec.Name = "Conditional Access Conrols (network, device or risk)"
        $rec.Summary = "Protect your users sign-ins by applying conditional access policies including risk, device or network location controls to improve your security"
        $rec.Recommendation = "Design conditional access to include either risk, device or netowrk location conditions"
        $rec.Priority = "P1"
        $rec.DataReport = @(Join-Path $AADPath "conditionalAccessPolicies.json")
        $rec
    }    

    #Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $?
}