function Write-RecommendationsReport($recommendationsList) {
    $html = @'
    <head><title>Azure AD Assessment - Recommendations</title></head>
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
    
    $recommendationsList = $recommendationsList | Sort-Object SortOrder,Category,Area,ID,Name

    foreach ($reco in $recommendationsList) {
        $md += "   | $($reco.Category) | $($reco.Area)  | [$(Get-RecoTitle $reco)](#$(Get-RecoTitleLink $reco)) | $(Get-PriorityIcon($reco)) $($reco.Priority)  |`n"
    }

    foreach ($reco in $recommendationsList) {

        $md += "## $(Get-RecoTitle $reco)`n"
        $md += "### Priority = $(Get-PriorityIcon($reco)) $($reco.Priority)`n"
        $md += "$($reco.Category) >  $($reco.Area)`n`n"
        $md += "$($reco.Summary)`n"
        $md += "### Recommendation`n"
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
        }
        $md += "`n`n"
    }
    $md += "`n`n"

    $html = $html.Replace("@@MARKDOWN@@", $md)
    $htmlReportPath = Join-Path $OutputDirectory "AssessmentReport.html"
    Set-Content -Path $htmlReportPath -Value $html
    Invoke-Item $htmlReportPath
}


function Get-RecoTitle($reco){
    return "$($reco.ID) - $($reco.Name)"
}

function Get-RecoTitleLink($reco){
    $title = Get-RecoTitle $reco
    return $title.ToLower().Replace(" ", "-").Replace('"', '')
}

function Set-SortOrder($reco){
    $priority = Get-ObjectPropertyValue $reco 'Priority'
    switch ($priority) {
        'Passed' { $reco.SortOrder = 10 }
        'P1' { $reco.SortOrder = 1 }
        'P2' { $reco.SortOrder = 2 }
        'P3' { $reco.SortOrder = 3 }
        Default { $reco.SortOrder = 4 }
    }
}
function Get-PriorityIcon($reco){
    $priority = Get-ObjectPropertyValue $reco 'Priority'
    switch ($priority) {
        'Passed' { $icon = "✅" }
        'P1' { $icon = "🟥" }
        'P2' { $icon = "🟧" }
        'P3' { $icon = "🟨" }
        Default { $icon = "🟦" }
    }

    return $icon
}
