<#
 .Synopsis
  Provides a report to show all the keys expiration date accross application and service principals

 .Description
  Provides a report to show all the keys expiration date accross application and service principals

 .Example
  Connect-AzureAD
  Get-AADAssessApplicationKeyExpirationReport

#>
function Get-AADAssessApplicationKeyExpirationReport {
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

        ## Load Data
        if (!$ApplicationData) {
            $ApplicationData = Get-MsGraphResults 'applications?$select=id,displayName,keyCredentials,passwordCredentials' -Top 999
        }

        ## Get Application Credentials
        foreach ($app in $ApplicationData) {
            foreach ($credential in $app.keyCredentials) {
                [PSCustomObject]@{
                    displayName             = $app.displayName
                    objectType              = "Application"
                    credentialType          = $credential.type
                    credentialStartDateTime = $credential.startDateTime
                    credentialEndDateTime   = $credential.endDateTime
                    credentialUsage         = $credential.usage
                }
            }

            foreach ($credential in $app.passwordCredentials) {
                [PSCustomObject]@{
                    displayName             = $app.displayName
                    objectType              = "Application"
                    credentialType          = "Password"
                    credentialStartDateTime = $credential.startDateTime
                    credentialEndDateTime   = $credential.endDateTime
                }
            }
        }

        ## Get Service Principal Credentials
        if (!$ServicePrincipalData) {
            $ServicePrincipalData = Get-MsGraphResults 'serviceprincipals?$select=id,displayName,keyCredentials,passwordCredentials' -Top 999
        }

        foreach ($sp in $ServicePrincipalData) {
            foreach ($credential in $sp.keyCredentials) {
                [PSCustomObject]@{
                    displayName             = $sp.displayName
                    objectType              = "Service Principal"
                    credentialType          = $credential.type
                    credentialStartDateTime = $credential.startDateTime
                    credentialEndDateTime   = $credential.endDateTime
                    credentialUsage         = $credential.usage
                }
            }

            foreach ($credential in $sp.passwordCredentials) {
                [PSCustomObject]@{
                    displayName             = $sp.displayName
                    objectType              = "Service Principal"
                    credentialType          = "Password"
                    credentialStartDateTime = $credential.startDateTime
                    credentialEndDateTime   = $credential.endDateTime
                }
            }
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}
