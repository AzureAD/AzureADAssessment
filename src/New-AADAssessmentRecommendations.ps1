<#
.SYNOPSIS
    Produces the Azure AD Assessment recommendations from collected data.
.DESCRIPTION
    This cmdlet reads data collected and generates recommendations accordingly.
.EXAMPLE
    PS C:\> New-AADAssessmentRecommendations
    Collect and package assessment data from "C:\AzureADAssessment" and generate recommendations in the same folder.
.EXAMPLE
    PS C:\> New-AADAssessmentRecommendations -OutputDirectory "C:\Temp"
    Collect and package assessment data from "C:\Temp" and generate recommendations in the same folder.
#>
function New-AADAssessmentRecommendations {
    [CmdletBinding()]
    param (
        # Specifies a path where extracted data resides (folder)
        [Parameter(Mandatory = $false)]
        [string] $Path = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Full path of the directory where the output files will be copied.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        [Parameter(Mandatory = $false)]
        [bool] $SkipExpand = $false
    )

    #Start-AppInsightsRequest $MyInvocation.MyCommand.Name


    ## Expand extracted data
    if (-not $SkipExpand) {
        $Archives = Get-ChildItem -Path $Path | Where-Object {$_.Name -like "AzureADAssessmentData-*.zip" }
        $ExtractedDirectories = @()
        foreach($Archive in $Archives) {
            $OutputDirectoryData = Join-Path $OutputDirectory ([IO.Path]::GetFileNameWithoutExtension($Archive.Name))
            Expand-Archive -Path $Archive.FullName -DestinationPath $OutputDirectoryData -Force -ErrorAction Stop
            $ExtractedDirectories += $OutputDirectoryData
        }
    }

    ## Determine folder contents
    $TenantDirectoryData = $null
    $AADCDirecotryData = @()
    $ADFSDirectoryData = @()
    $AADAPDirectoryData = @()
    foreach($Directory in Get-ChildItem -Path $Path -Directory) {
        Switch -Wildcard ($Directory.Name) {
            "AzureADAssessmentData-*.onmicrosoft.com" {
                $TenantDirectoryData = $Directory.FullName
            }
            "AzureADAssessmentData-AADC-*" {
                $AADCDirecotryData += $Directory.FullName
            }
            "AzureADAssessmentData-ADFS-*" {
                $ADFSDirectoryData += $Directory.FullName
            }
            "AzureADAssessmentData-AADAP-*" {
                $AADAPDirectoryData += $Directory.FullName
            }
            default {
                Write-Warning "Unrecognized directory $($Directory.Name)"
            }
        }
    }

    # Generate recommendations from tenant data
    if (![String]::IsNullOrWhiteSpace($TenantDirectoryData)) {
        # generate Email OTP recommendation
        Get-EOTPRecommendation -Path $TenantDirectoryData
        # generate Trusted network locations
        Get-TrustedNetworksRecommendation -Path $TenantDirectoryData
    } else {
        Write-Error "No Tenant Data found"
    }

    #Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $?
}
