<#
.SYNOPSIS
    Gets a report selected users in the tenant
.DESCRIPTION
    This function returns a list of users in the tenant
    It will collect the lastsignindatetime (interactive or non interactive) and check the authenticationmethods available to the user
.EXAMPLE
    PS C:\> Get-AADAssessUserReport | Export-Csv -Path ".\users.csv"
#>
function Get-AADAssessUserReport {
    [CmdletBinding()]
    param (
        # User Data
        [Parameter(Mandatory = $false)]
        [psobject] $UserData,
        [Parameter(Mandatory = $false)]
        [psobject] $RegistrationDetailsData,
        [Parameter(Mandatory = $false)]
        [switch] $Offline
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        function Process-User {
            param (
                # Input Object (user)
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $InputObject,
                # LookupCache
                [Parameter(Mandatory = $true)]
                [psobject] $LookupCache
            )

            begin {
                $aadp1plan = "eec0eb4f-6444-4f95-aba0-50c24d67f998"
                $aadp2plan = "41781fb2-bc02-4b7c-bd55-b576c07bb09d"
            }

            process {
                # check user license
                $aadLicense = "None"
                if ($InputObject.psobject.Properties.Name.Contains('assignedPlans')) {
                    $plans = $InputObject.assignedPlans | foreach-object { $_.servicePlanId }
                    if ($plans -contains $aadp2plan) { $aadLicense = "AADP2" }
                    elseif ($plans -contains $aadp1plan) { $aadLicense = "AADP1" }
                }
                # get last signindate times
                $lastInteractiveSignInDateTime = ""
                $lastNonInteractiveSignInDateTime = ""
                if ($InputObject.psobject.Properties.Name.Contains('signInActivity')) { 
                    $lastInteractiveSignInDateTime = $InputObject.signInActivity.lastSignInDateTime
                    $lastNonInteractiveSignInDateTime = $InputObject.signInActivity.lastNonInteractiveSignInDateTime
                }
                # get the registered methods and MFA capability
                $registerationDetails = $LookupCache.userRegistrationDetails[$InputObject.id]
                # set default values
                $isMfaCapable = $false
                $isMfaRegistered = $false
                $methodsRegistered = ""
                if ($registerationDetails) {
                    $isMfaRegistered = $registerationDetails.isMfaRegistered
                    $isMfaCapable = $registerationDetails.isMfaCapable
                    $methodsRegistered = $registerationDetails.methodsRegistered -join ";"
                } else {
                    Write-Warning "authentication method registration not found for $($InputObject.id)"
                }
                # output user object
                [PSCustomObject]@{
                    "id" = $InputObject.id
                    "userPrincipalName" = $InputObject.userPrincipalName
                    "displayName" = $InputObject.displayName -replace "`n",""
                    "userType" = $InputObject.UserType
                    "accountEnabled" = $InputObject.accountEnabled
                    "onPremisesSyncEnabled" = [bool]$_.onPremisesSyncEnabled
                    "onPremisesImmutableId" = ![string]::IsNullOrWhiteSpace($InputObject.onPremisesImmutableId)
                    "mail" = $InputObject.mail
                    "otherMails" = $InputObject.otherMails -join ';' 
                    "AADLicense" = $aadLicense
                    "lastInteractiveSignInDateTime" = $lastInteractiveSignInDateTime
                    "lastNonInteractiveSignInDateTime" = $lastNonInteractiveSignInDateTime
                    "isMfaRegistered" = $isMfaRegistered
                    "isMfaCapable" = $isMfaCapable
                    "methodsRegistered" = $methodsRegistered
                }
            }    
        }

        if ($Offline -and (!$PSBoundParameters['UserData'] -or !$PSBoundParameters['RegistrationDetailsData'])) {
            Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList 'Use of the offline parameter requires that all data be provided using the data parameters.') -ErrorId 'DataParametersRequired' -Category ObjectNotFound
            return
        }

        ## Initialize lookup cache
        $LookupCache = New-LookupCache

        ## Check UserData presence
        if ($UserData) {
            if ($UserData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.user = $UserData
            }
            else {
                $UserData | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
            }
        }
        else {
            Write-Warning "Getting all users (this can take a while)..."
            Get-MsGraphResults 'users' -Select 'id,userPrincipalName,userType,displayName,accountEnabled,onPremisesSyncEnabled,onPremisesImmutableId,mail,otherMails,proxyAddresses,assignedPlans,signInActivity' -ApiVersion 'beta'` | Add-AadObjectToLookupCache -Type user -LookupCache $LookupCache
        }

        ## Check RegistrationDetails presence
        if ($RegistrationDetailsData) {
            if ($RegistrationDetailsData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $LookupCache.userRegistrationDetails = $RegistrationDetailsData
            }
            else {
                $RegistrationDetailsData | Add-AadObjectToLookupCache -Type "userRegistrationDetails" -LookupCache $LookupCache
            }
        }
        else {
            Get-MsGraphResults 'reports/authenticationMethods/userRegistrationDetails' -ApiVersion 'beta' | Add-AadObjectToLookupCache -Type "userRegistrationDetails" -LookupCache $LookupCache
        }

        ## Generate user report infos
        $LookupCache.user.Values | Process-User -LookupCache $LookupCache

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}