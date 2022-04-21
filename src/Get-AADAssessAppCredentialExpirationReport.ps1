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
                Write-Verbose "Processing $($ObjectType): $($InputObject.displayName) ($($InputObject.id)) "
                foreach ($credential in $InputObject.keyCredentials) {
                    # check for hasExtensionAttribute
                    $hasExtendedValue = $null
                    if ( [bool]($credential.PSobject.Properties.name -match "hasExtendedValue") ) {
                        $hasExtendedValue = $credential.hasExtendedValue
                    }
                    if ($credential.type -eq "AsymmetricX509Cert" -and ![string]::IsNullOrEmpty($credential.key)) {
                        # credential is a cert and has a key
                        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([System.Convert]::FromBase64String($credential.key))
                        $publicKey = $cert.PublicKey.GetRSAPublicKey()
                        if (!$publickey) {
                            $publicKey = $cert.PublicKey.GetECDsaPublicKey()
                        }
                        $certSignatureAlgorithm = $null
                        $certKeySize = $null
                        if($publicKey) {
                            $certSignatureAlgorithm = $publicKey.SignatureAlgorithm
                            $certKeySize = $publicKey.KeySize
                        }
                        [PSCustomObject]@{
                            displayName                 = $InputObject.displayName
                            objectType                  = $ObjectType
                            credentialType              = $credential.type
                            credentialStartDateTime     = $credential.startDateTime
                            credentialEndDateTime       = $credential.endDateTime
                            credentialUsage             = $credential.usage
                            certSubject                 = $cert.Subject
                            certIssuer                  = $cert.Issuer
                            certIsSelfSigned            = ($cert.Subject -eq $cert.Issuer)
                            certSignatureAlgorithm      = $certSignatureAlgorithm
                            certKeySize                 = $certKeySize
                            credentialHasExtendedValue  = $hasExtendedValue
                        }
                    }
                    else {
                        [PSCustomObject]@{
                            displayName                 = $InputObject.displayName
                            objectType                  = $ObjectType
                            credentialType              = $credential.type
                            credentialStartDateTime     = $credential.startDateTime
                            credentialEndDateTime       = $credential.endDateTime
                            credentialUsage             = $credential.usage
                            certSubject                 = $null
                            certIssuer                  = $null
                            certIsSelfSigned            = $null
                            certSignatureAlgorithm      = $null
                            certKeySize                 = $null
                            credentialHasExtendedValue  = $hasExtendedValue
                        }
                    }
                }

                foreach ($credential in $InputObject.passwordCredentials) {
                    [PSCustomObject]@{
                        displayName                 = $InputObject.displayName
                        objectType                  = $ObjectType
                        credentialType              = "Password"
                        credentialStartDateTime     = $credential.startDateTime
                        credentialEndDateTime       = $credential.endDateTime
                        credentialUsage             = $null
                        certSubject                 = $null
                        certIssuer                  = $null
                        certIsSelfSigned            = $null
                        certSignatureAlgorithm      = $null
                        certKeySize                 = $null
                        credentialHasExtendedValue  = $null
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
