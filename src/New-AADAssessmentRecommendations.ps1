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

function Get-PriorityIcon($reco){
    $priority = Get-ObjectPropertyValue $reco 'Priority'
    $icon = "✅"
    if($priority -ne "Passed"){
        $icon = "❗️"
    }
    return $icon
}
function Write-RecommendationsReport($recommendationsList) {
    $html = @'
    <head><title>Azure AD Assessment - Recommendations</title></head>
    <script src="https://cdn.jsdelivr.net/npm/@webcomponents/webcomponentsjs@2/webcomponents-loader.min.js"></script>    
    <script type="module" src="https://cdn.jsdelivr.net/gh/zerodevx/zero-md@1/src/zero-md.min.js"></script>
    <zero-md>
        <script type="text/markdown">
            @@MARKDOWN@@
        </script>
    </zero-md>
'@
    $md = "# Azure AD Assessment - Recommendations`n"
    $md += "## Assessment Summary`n"

    $md += "`n   |**Category**|**Area**|**Name**|**Status**|`n"
    $md += "   | --- | --- | --- | --- |`n"
    
    $recommendationsList = $recommendationsList | Sort-Object Priority,Category,Area,Name
    $rowIndex = 0
    foreach ($reco in $recommendationsList) {
        $rowIndex += 1
        $md += "   | $($reco.Category) | $($reco.Area)  | [$($reco.Name)](#$($reco.Name.ToLower().Replace(" ", "-").Replace('"', '')))  | $(Get-PriorityIcon($reco)) $($reco.Priority)  |`n"
    }

    $md += "## Assessment Recommendations`n"
    $rowIndex = 0
    foreach ($reco in $recommendationsList) {
        $rowIndex += 1
        $priority = Get-ObjectPropertyValue $reco 'Priority'
        if($priority -ne "Passed"){    
            $md += "### $($reco.Name)`n"
            $md += "#### Priority = $(Get-PriorityIcon($reco)) $($reco.Priority)`n"
            $md += "$($reco.Category) >  $($reco.Area)`n`n"
            $md += "$($reco.Summary)`n"
            $md += "#### Recommendation`n"
            $md += "> $($reco.Recommendation)`n"
            $md += "`n[⤴️ Back To Summary](#assessment-summary)`n"            
            $md += "`n"
            if($null -ne $reco.Data -and $reco.Data.Length -gt 0){
                $md += "`n   |"
                $hr = "`n   |"
                foreach($prop in $reco.Data[0].PsObject.Properties){
                    $md += "$($prop.Name)|"
                    $hr += " --- |"
                }
                $md += $hr
                foreach ($item in $reco.Data) {
                    $md += "`n   |"
                    foreach($prop in $item.PsObject.Properties){
                        $md += "$($prop.Value)|"
                    }
                }
                #$md += ConvertTo-Html -InputObject $reco.Data -Fragment
            }
            $md += "`n`n"
        }
    }
    $md += "`n`n"

    $html = $html.Replace("@@MARKDOWN@@", $md)
    $htmlReportPath = Join-Path $OutputDirectory "AssessmentReport.html"
    Set-Content -Path $htmlReportPath -Value $html
    Invoke-Item $htmlReportPath
}
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
        [switch] $SkipExpand = $false,
        # Path to the spreadsheet with the interview answers
        [Parameter(Mandatory = $false)]
        [string] $InterviewSpreadsheetPath
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
        ### Load all the data on AAD
        # Prepare paths
        $AssessmentDetailPath = Join-Path $TenantDirectoryData "AzureADAssessment.json"
        # Read assessment data
        $AssessmentDetail = Get-Content $AssessmentDetailPath -Raw | ConvertFrom-Json
        # Generate AAD data path
        $AADPath = Join-Path $TenantDirectoryData "AAD-$($AssessmentDetail.AssessmentTenantDomain)"
        $data = @{}
        <# do not load file before hand but only when necessary
        $files = get-childitem -Path $AADPath -File
        foreach($file in $files) {
            switch -Wildcard ($file.Name) {
                "*.json" {
                    $data[$file.Name] = get-content -Path $file.FullName | ConvertFrom-Json
                }
                "*.csv" {
                    $data[$file.Name] = Import-Csv -Path $file.FullName
                }
                "*.xml" {
                    $data[$file.Name] = Import-Clixml -Path $file.FullName
                }
                default {
                    Write-Warning "Unsupported data file format: $($file.Name)"
                }
            }
        }#>
        ### Load configuration file
        $recommendations = Select-Xml -Path (Join-Path $PSScriptRoot "AADRecommendations.xml") -XPath "/recommendations"
        $recommendationList = @()
        foreach($recommendationDef in $recommendations.Node.recommendation) {
            # make sure necessary files are loaded
            $fileMissing = $false
            foreach($fileName in $recommendationDef.Sources.File) {
                $filePath = Join-Path $AADPath $fileName
                if (!(Test-Path -Path $filePath)) {
                    Write-Warning "File not found: $filePath"
                    $fileMissing = $true
                    break
                }
                if ($fileName -in $data.Keys) {
                    continue
                }
                switch -Wildcard ($fileName) {
                    "*.json" {
                        $data[$fileName] = get-content -Path $filePath | ConvertFrom-Json
                    }
                    "*.csv" {
                        $data[$fileName] = Import-Csv -Path $filePath
                    }
                    "*.xml" {
                        $data[$fileName] = Import-Clixml -Path $filePath
                    }
                    default {
                        Write-Warning "Unsupported data file format: $($fileName)"
                    }
                }
            }
            if ($fileMissing) {
                write-warning "A necessary file is missing"
                continue
            }
            $scriptblock = [Scriptblock]::Create($recommendationDef.PowerShell)
            $recommendation = $recommendationDef | select-object Category,Area,Name,Summary,Recommendation,Priority,Data
            $result = Invoke-Command -ScriptBlock $scriptblock -ArgumentList $Data
            $recommendation.Priority = $result.Priority
            $recommendation.Data = $result.Data
            $recommendationList += $recommendation
        }

        Write-RecommendationsReport $recommendationList

        # generate Trusted network locations
        #Get-TrustedNetworksRecommendation -Path $TenantDirectoryData
    } else {
        Write-Error "No Tenant Data found"
    }

    #Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $?
}
