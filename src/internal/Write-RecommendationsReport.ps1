function Write-RecommendationsReport($data, $recommendationsList) {

    $html = @'
    <head><title>Azure AD Assessment - Recommendations</title></head>
    <script type="module" src="https://cdn.jsdelivr.net/gh/zerodevx/zero-md@1/src/zero-md.min.js"></script>
    <zero-md>
        <script type="text/markdown">
            @@MARKDOWN@@
        </script>
    </zero-md>
'@
    $qna = $data['QnA.json']
    $md = "# Azure AD Assessment - Recommendations`n"
    $md += " | | |`n"
    $md += " | --- | --- |`n"
    $md += " |**Organization Name**|$(Get-ObjectPropertyValue $qna['AD_OrgName'] 'value')|`n"
    $md += " |**Organization Primary Contact**|$(Get-ObjectPropertyValue $qna['AD_OrgPrimaryContact'] 'value')|`n"
    $md += " |**Assessment Carried Out By**|$(Get-ObjectPropertyValue $qna['AD_AssessorName'] 'value')|`n"
    $md += " |**Assessment Date**|$(Get-ObjectPropertyValue $qna['AD_AssessmentDate'] 'value')|`n"

    $md += "## Assessment Summary`n"
    $md += "The table below lists a summary of the findings for this tenant.`n`n"
    $md += Get-PrioritySummaryTable $recommendationsList

    $md += "`n## Assessment Details`n"
    $md += "Click on the name of the check to learn more about the finding and how you can remediate the issue.`n`n"
    $md += "`n   |**Category**|**Area**|**Name**|**Status**|`n"
    $md += "   | --- | --- | --- | --- |`n"
    
    $recommendationsList = $recommendationsList | Sort-Object SortOrder,Category,Area,ID,Name

    foreach ($reco in $recommendationsList) {
        $md += "   | $($reco.Category) | $($reco.Area)  | [$(Get-RecoTitle $reco)](#$(Get-RecoTitleLink $reco)) | $(Get-PriorityIcon($reco)) $($reco.Priority)  |`n"
    }

    $md += @'
## Overview

This document describes the checks performed during the Azure Active Directory (Azure AD) Configuration Assessment workshop around the following Identity and Access Management (IAM) areas:

- **Identity Management:** Ability to manage the lifecycle of identities and their entitlements
- **Access Management:** Ability to manage credentials, define authentication experience, delegate assignment, measure usage, and define access policies based on enterprise security posture
- **Governance:** Ability to assess and attest the access granted non-privileged and privileged identities, audit and control changes to the environment
- **Operations:** Optimize the operations Azure Active Directory (Azure AD)

Each category is divided into different checks. Then, each check defines some recommendations as follows:

- **🟥 P0:** Implement as soon as possible. This typically indicates a security risk
- **🟧 P1:** Implement over the next 30 days. This typically indicates an operational gap
- **🟨 P2:** Implement over the next 60 days. This typically indicates optimization in the current operation to make better use of Azure AD provided capabilities
- **🟦 P3:** Implement after 60+ days. This is a cleanup, streamlining recommendation.

Each check may contain several forms of results:

- **Summaries:** Notable findings illustrating the current state of the environment being assessed.
- **Recommendations** : Actionable items that improve the alignment of the environment with Microsoft's best practices.
- **Data Reports** : Reports based on data elements retrieved directly from the environment.

Some checks might not be applicable at the time of the assessment due to customers' environment (e.g. AD FS best practices might not apply if customer uses password hash sync).

Please be aware of the following disclaimers

- The recommendations in this document are current as of the date of this engagement. This changes constantly, and customers should be continuously evaluating their IAM practices as Microsoft products and services evolve over time
- The recommendations are based on the data provided during the interview, and telemetry.
- The recommendations cover several IAM areas, but there is not meant to be taken as of absolute coverage

'@

    foreach ($reco in $recommendationsList) {

        $md += "`n`n[⤴️ Back To Summary](#assessment-summary)`n"
        $md += "## $(Get-RecoTitle $reco)`n"
        $md += "### Priority = $(Get-PriorityIcon($reco)) $($reco.Priority)`n"
        $md += "$($reco.Category) >  $($reco.Area)`n`n"
        $md += "$($reco.Summary)`n"
        $md += "### Recommendation`n"
        $md += "> $($reco.Recommendation)`n"
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
        'N/A' { $reco.SortOrder = 20 } # Show last
        'Passed' { $reco.SortOrder = 10 }
        'P1' { $reco.SortOrder = 1 }
        'P2' { $reco.SortOrder = 2 }
        'P3' { $reco.SortOrder = 3 }
        
        Default { $reco.SortOrder = 7 }
    }
}
function Get-PriorityIcon($reco){
    $priority = Get-ObjectPropertyValue $reco 'Priority'
    return Get-IconForPriority $priority
}

function Get-IconForPriority($priority){
    switch ($priority) {
        'Passed' { $icon = "✅" }
        'P0' { $icon = "🟥" }
        'P1' { $icon = "🟧" }
        'P2' { $icon = "🟨" }
        'P3' { $icon = "🟦" }
        'Not Answered' { $icon = "❓" }
        'N/A' { $icon = "" }
        Default { $icon = "🟪" }
    }

    return $icon
}

function Get-PrioritySummaryTable {
    param (
        $recommendationsList
    )

    $summary = $recommendationsList.Priority | Group-Object -NoElement | Select-Object Name, Count
    
    $p0 = 0; $p1 = 0; $p2 = 0; $p3 = 0; $passed = 0
    foreach ($item in $summary) {
        switch ($item.Name) {
            'P0' { $p0 = $item.Count }
            'P1' { $p1 = $item.Count }
            'P2' { $p2 = $item.Count }
            'P3' { $p3 = $item.Count }
            'Passed' { $passed = $item.Count }
            Default {}
        }
    }
 
    $md += "`n`n | $(Get-IconForPriority 'P0') P0 | $(Get-IconForPriority 'P1') P1 | $(Get-IconForPriority 'P2') P2 | $(Get-IconForPriority 'P3') P3 | $(Get-IconForPriority 'Passed') Passed |"
    foreach ($item in $summary) {
        if($item.Name -notin 'P0', 'P1', 'P2', 'P3', 'Passed', 'N/A' ){
            $md += " $(Get-IconForPriority $item.Name) $($item.Name) | "
        }
    }
    $md += "`n | :-:  | :-:  | :-:  | :-:  | :-:  |"
    foreach ($item in $summary) {
        if($item.Name -notin 'P0', 'P1', 'P2', 'P3', 'Passed', 'N/A' ){
            $md += " :-: |"
        }
    }
    $md += "`n | $($p0) | $($p1) | $($p2) | $($p3) | $($passed) |"
    foreach ($item in $summary) {
        if($item.Name -notin 'P0', 'P1', 'P2', 'P3', 'Passed', 'N/A' ){
            $md += "$($item.Count) | "
        }
    }
    return $md
}