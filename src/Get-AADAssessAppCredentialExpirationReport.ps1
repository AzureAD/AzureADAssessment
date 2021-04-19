<#
.SYNOPSIS
    Provides a report to show all the keys expiration date accross application and service principals
.DESCRIPTION
    Provides a report to show all the keys expiration date accross application and service principals
.EXAMPLE
    PS C:\> Get-AADAssessAppCredentialExpirationReport | Export-Csv -Path ".\AppCredentialsReport.csv"
#>
function Get-AADAssessAppCredentialExpirationReport {
    [CmdletBinding()]
    param (
        # Application Data
        [Parameter(Mandatory = $false)]
        [psobject] $ApplicationData,
        # Service Principal Data
        [Parameter(Mandatory = $false)]
        [psobject] $ServicePrincipalData,
        # Generate Report Offline, only using the data passed in parameters
        [Parameter(Mandatory = $false)]
        [switch] $Offline
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        if ($Offline -and (!$PSBoundParameters['ApplicationData'] -or !$PSBoundParameters['ServicePrincipalData'])) {
            Write-Error -Exception (New-Object System.Management.Automation.ItemNotFoundException -ArgumentList 'Use of the offline parameter requires that all data be provided using the data parameters.') -ErrorId 'DataParametersRequired' -Category ObjectNotFound
            return
        }

        function Process-AppCredentials {
            param (
                #
                [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
                [psobject] $InputObject,
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
            Get-MsGraphResults 'servicePrincipals?$select=id,displayName,keyCredentials,passwordCredentials' -Top 999 `
            | Process-AppCredentials -ObjectType 'Service Principal'
        }

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}
