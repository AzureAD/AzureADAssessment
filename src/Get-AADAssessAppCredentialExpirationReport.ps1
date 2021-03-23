<#
 .Synopsis
  Provides a report to show all the keys expiration date accross application and service principals

 .Description
  Provides a report to show all the keys expiration date accross application and service principals

 .Example
  Connect-AzureAD
  Get-AADAssessAppCredentialExpirationReport

#>
function Get-AADAssessAppCredentialExpirationReport {
    [CmdletBinding()]
    param (
        # Application Data
        [Parameter(Mandatory = $false)]
        [object] $ApplicationData,
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [object] $ServicePrincipalData
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        function Process-AppCredentials {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [object] $InputObject,
                #
                [Parameter(Mandatory = $true)]
                [string] $ObjectType
            )

            process {
                foreach ($credential in $InputObject.keyCredentials) {
                    [PSCustomObject]@{
                        displayName             = $InputObject.displayName
                        objectType              = $ObjectType
                        credentialType          = $credential.type
                        credentialStartDateTime = $credential.startDateTime
                        credentialEndDateTime   = $credential.endDateTime
                        credentialUsage         = $credential.usage
                    }
                }

                foreach ($credential in $InputObject.passwordCredentials) {
                    [PSCustomObject]@{
                        displayName             = $InputObject.displayName
                        objectType              = $ObjectType
                        credentialType          = "Password"
                        credentialStartDateTime = $credential.startDateTime
                        credentialEndDateTime   = $credential.endDateTime
                    }
                }
            }
        }

        ## Get Applications
        if ($ApplicationData) {
            if ($ApplicationData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $ApplicationData.Values | Process-AppCredentials -ObjectType 'Application'
            }
            else {
                $ApplicationData | Process-AppCredentials -ObjectType 'Application'
            }
        }
        else {
            Write-Verbose "Getting applications..."
            Get-MsGraphResults 'applications?$select=id,displayName,keyCredentials,passwordCredentials' -Top 999 `
            | Process-AppCredentials -ObjectType 'Application'
        }

        ## Get Service Principals
        if ($ServicePrincipalData) {
            if ($ServicePrincipalData -is [System.Collections.Generic.Dictionary[guid, pscustomobject]]) {
                $ServicePrincipalData.Values | Process-AppCredentials -ObjectType 'Service Principal'
            }
            else {
                $ServicePrincipalData | Process-AppCredentials -ObjectType 'Service Principal'
            }
        }
        else {
            Write-Verbose "Getting serviceprincipals..."
            Get-MsGraphResults 'serviceprincipals?$select=id,displayName,keyCredentials,passwordCredentials' -Top 999 `
            | Process-AppCredentials -ObjectType 'Service Principal'
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}
