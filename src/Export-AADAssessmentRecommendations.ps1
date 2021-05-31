<#
.SYNOPSIS
    Exports AAD Assessment Recommendations to file
.DESCRIPTION
    This cmdlet gets recommendations from input and generate a recommendation file.
    If no recommendations are provided it will generate them
.EXAMPLE
    PS C:\> Export-AADAssessmentRecommendations
    Analyse assessment data from "C:\AzureADAssessment" and export recommendations file in the same folder.
.EXAMPLE
    PS C:\> Export-AADAssessmentRecommendations -OutputDirectory "C:\Temp"
    Analyse assessment data from "C:\Temp" and export recommendations file in the same folder.
.EXAMPLE
    PS C:\> New-AADAssessmentREcommendations | Export-AADAssessmentRecommendations
    Exports recommandations file in "C:\AzureADAssessment"
#>
function Export-AADAssessmentRecommendations {
    [CmdletBinding()]
    param (
        # Recommendations to export
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [Object[]] $Recommandations,
        [Parameter(Mandatory = $true)]
        [string] $TenantName,
        # Specifies a path where extracted data resides (folder)
        [Parameter(Mandatory = $false)]
        [string] $Path = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Full path of the directory where the output files will be copied.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        [Parameter(Mandatory = $false)]
        [ValidateSet("json","md","docx")]
        $OutputType = "json",    
        [Parameter(Mandatory = $false)]
        [bool] $SkipExpand = $false
    )

    #Start-AppInsightsRequest $MyInvocation.MyCommand.Name

    if ($null -eq $Recommandations -or $Recommandations.Count -eq 0) {
        $Recommandations = New-AADAssessmentRecommendations -Path $Path -OutputDirectory $OutputDirectory -SkipExpand $SkipExpand
    }

    if ($OutputType -eq "json") {
        # Export recommendations to json
        $Recommandations | Export-JsonArray (Join-Path $OutputDirectory "recommendations.json")
    }

    if ($OutputType -eq "md") {

        $data = "" | Select-Object Tenant,Date,Version,Summary,Categories
        $data.Tenant = $TenantName
        $data.Date = get-date -Format "dd/MM/yyyy"
        $data.Version = "AzureADAssessment - 2.0"

        # Main Summary
        $data.Summary = "" | Select-Object P1,P2,P3,P1infos

        $P1s = @($Recommandations | Where-Object {$_.Priority -eq "P1"} | Select-Object Category,Area,Name)
        $P2s = @($Recommandations | Where-Object {$_.Priority -eq "P2"} | Select-Object Category,Area,Name)
        $P3s = @($Recommandations | Where-Object {$_.Priority -eq "P3"} | Select-Object Category,Area,Name)

        $data.Summary.P1 = $P1s.Count
        $data.Summary.P2 = $P2s.Count
        $data.Summary.P3 = $P3s.Count

        $data.Summary.P1Infos = @{}

        $data.Categories = @()
        $perCategory = $Recommandations | Group-Object -Property Category
        foreach($catGroup in $perCategory) {
            $catData = "" | Select-Object Category,Summary,Areas
            $catDAta.Category = $catGroup.Name
            $catData.Areas = @{}
            $catData.Summary = "" | Select-Object P1,P2,P3

            $catRecommendations = $catGroup.Group

            $catData.Summary.P1 = @($catRecommendations | Where-Object {$_.Priority -eq "P1"}).Count
            $catData.Summary.P2 = @($catRecommendations | Where-Object {$_.Priority -eq "P2"}).Count
            $catData.Summary.P3 = @($catRecommendations | Where-Object {$_.Priority -eq "P3"}).Count

            if ($catData.Summary.P1 -gt 0) {
                $data.Summary.P1Infos[$catGroup.Name] = @{}
            }

            $perArea = $catRecommendations | Group-Object -Property Area
            foreach ($areaGroup in $perArea) {
                $catData.Areas[$areaGroup.Name] = @($areaGroup.Group | Select-Object Name,Summary,Recommendation,Priority,DataReport | Sort-Object -Property Priority,Name)
                
                $areaP1s = @($catData.Areas[$areaGroup.Name] | Where-Object { $_.Priority -eq "P1"})
                
                if ($areaP1s.Count -gt 0) {
                    $data.Summary.P1Infos[$catGroup.Name][$areaGroup.Name] = @($areaP1s | ForEach-Object { $_.Name })
                }
            }
            $data.Categories += $catData
        }
        
        $data | convertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $OutputDirectory "recommendationsData.json")

        ### Output data as markdown

        # Title
        "# Azure Active Direcotry Asssement Recommendations" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md")
        "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        
        # General informations
        "Tenant Name: $($data.Tenant)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "Date: $($data.Date)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "Version: $($data.Version)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

        # Summary
        "Recommandations:" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "* P1: $($data.Summary.P1)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "* P2: $($data.Summary.P2)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "* P3: $($data.Summary.P3)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
        "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

        if ($data.Summary.P1 -gt 0) {
            # Priority 1 summary
            "First Priority Recommendations:" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            # Adjust Sizes 
            $categorySize = 8
            $areaSize = 4
            $checkSize = 14
            foreach($category in $data.Summary.P1Infos.Keys) {
                # category
                if ($categorySize -lt $category.Length) { $categorySize = $category.Length }
                foreach($area in $data.Summary.P1Infos.$category.Keys) {
                    # area
                    if ($areaSize -lt $area.Length) { $areaSize = $area.Length }
                    foreach($check in $data.Summary.P1Infos.$category.$area) {
                        # category
                        if ($checkSize -lt $check.Length) { $checkSize = $check.Length }
                    }
                }
            }
            # add padding
            $categorySize += 2
            $areaSize += 2
            $checkSize += 2

            # output table
            "|" + " " * (($categorySize - 8) / 2) + "Category" + " " * (($categorySize - 8) / 2) + "|" + `
            " " * (($areaSize - 4) / 2) + "Area" + " " * (($areaSize - 4) / 2) + "|" + `
            " " * (($checkSize - 14) / 2) + "Recommendation" + " " * (($checkSize - 14) / 2) + "|" `
            | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "|" + "-" * $categorySize + "|" + `
            "-" * $areaSize + "|" + `
            "-" * $checkSize + "|" `
            | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

            foreach($category in $data.Summary.P1Infos.Keys) {
                # category
                $categoryShown = $false
                foreach($area in $data.Summary.P1Infos.$category.Keys) {
                    # area
                    $areaShown = $false
                    foreach($check in $data.Summary.P1Infos.$category.$area) {
                        # check
                        if ($categoryShown -and $areaShown) {
                            "|" + " " * $categorySize + "|" + `
                            " " * $areaSize + "|" + `
                            " " * (($checkSize - $check.Length) / 2) + $check + " " * (($checkSize - $check.Length) / 2) + "|" `
                            | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                        } elseif ( $categoryShown -and -not $areaShown) {
                            "|" + " " * $categorySize + "|" + `
                            " " * (($areaSize - $area.Length) / 2) + $area + " " * (($areaSize - $area.Length) / 2) + "|" + `
                            " " * (($checkSize - $check.Length) / 2) + $check + " " * (($checkSize - $check.Length) / 2) + "|" `
                            | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                            $areaShown = $true
                        } else {
                            "|" + " " * (($categorySize - $category.Length) / 2) + $category + " " * (($categorySize - $category.Length) / 2) + "|" + `
                            " " * (($areaSize - $area.Length) / 2) + $area + " " * (($areaSize - $area.Length) / 2) + "|" + `
                            " " * (($checkSize - $check.Length) / 2) + $check + " " * (($checkSize - $check.Length) / 2) + "|" `
                            | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                            $categoryShown = $true
                            $areaShown = $true
                        }
                    }
                }
            }
        }
        
        # output categories

        foreach($category in $data.Categories) {
            # title
            "## $($category.Category)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

            # Summary
            "Recommandations:" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "* P1: $($category.Summary.P1)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "* P2: $($category.Summary.P2)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "* P3: $($category.Summary.P3)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
            "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

            # areas
            foreach($area in $category.Areas.Keys) {
                # title
                "### $($area)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

                # checks
                foreach($check in $category.Areas.$area) {
                    
                    # title
                    "#### $($check.Name)" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

                    # priority
                    "**Priority: $($check.Priority)**" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

                    # summary
                    $check.Summary | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

                    # Recommendation
                    "**Recommendation:**" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    $check.Recommendation | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append

                    # references
                    "References:" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    foreach($ref in $check.DataReport) {
                        "* $ref" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                    }
                    "" | Out-File -FilePath (Join-Path $OutputDirectory "recommendations.md") -Append
                }

            }

        }
    }
    #Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $?
}
