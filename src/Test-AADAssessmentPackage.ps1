<#
.SYNOPSIS
    Test that the provided Azure AD Assessment package has the necessary content
.DESCRIPTION
    Test that the provided Azure AD Assessment package has the necessary content
.EXAMPLE
    PS C:\>Test-AADAssessmentPackage 'C:\AzureADAssessmentData-contoso.aad'
    Test that the package for contoso has the necesary content for the assessment.
.INPUTS
    System.String
#>
function Test-AADAssessmentPackage {
    [CmdletBinding()]
    param
    (
        # Path to the file where the exported events will be stored
        [Parameter(Mandatory = $true)]
        [string] $Path,
        # Reports should have been generated
        [Parameter(Mandatory = $false)]
        [bool] $SkippedReportOutput
    )

    if (!(Test-Path -path $Path)) {
        Write-Warning "Assessment package not found"
        return $false
    }

    $fullPath = Convert-Path $Path

    $requiredEntries = @(
        "AAD-*/administrativeUnits.csv",
        "AAD-*/AppCredentialsReport.csv",
        "AAD-*/applications.json",
        "AAD-*/appRoleAssignments.csv",
        "AAD-*/conditionalAccessPolicies.json",
        "AAD-*/ConsentGrantReport.csv",
        "AAD-*/emailOTPMethodPolicy.json",
        "AAD-*/groups.csv",
        "AAD-*/namedLocations.json",
        "AAD-*/NotificationsEmailsReport.csv",
        "AAD-*/oauth2PermissionGrants.csv",
        "AAD-*/organization.json",
        "AAD-*/RoleAssignmentReport.csv",
        "AAD-*/roleDefinitions.csv",
        "AAD-*/servicePrincipals.csv",
        "AAD-*/servicePrincipals.json",
        "AAD-*/subscribedSkus.json",
        "AAD-*/userRegistrationDetails.json",
        "AAD-*/users.csv",
        "AzureADAssessment.json"
    )

    if ($SkippedReportOutput) {
        $requiredEntries = @(
            "AAD-*/administrativeUnits.csv",
            "AAD-*/applicationData.xml",
            "AAD-*/appRoleAssignmentData.xml",
            "AAD-*/conditionalAccessPolicies.json",
            "AAD-*/directoryRoleData.xml"
            "AAD-*/emailOTPMethodPolicy.json",
            "AAD-*/groupData.xml",
            "AAD-*/namedLocations.json",
            "AAD-*/oauth2PermissionGrantData.xml",
            "AAD-*/organization.json",
            "AAD-*/roleAssignmentSchedulesData.xml",
            "AAD-*/roleDefinitions.csv",
            "AAD-*/roleEligibilitySchedulesData.xml",
            "AAD-*/servicePrincipalData.xml",
            "AAD-*/subscribedSkus.json",
            "AAD-*/userData.xml",
            "AAD-*/userRegistrationDetails.json",
            "AzureADAssessment.json"
        )
    }

    $entries = [IO.Compression.ZipFile]::OpenRead($fullPath).Entries

    $effectiveEntries = $entries | Where-Object { $_.Length -gt 0}

    $validPackage = $true
    foreach($requiredEntry in $requiredEntries) {
        $found = $false
        foreach ($effectiveEntry in $effectiveEntries) {
            if (($effectiveEntry.FullName -replace "\\","/") -like $requiredEntry) {
                $found = $true
            }
        }
        if (!$found) {
            Write-Warning "Required entry '$requiredEntry' not found or empty"
            $validPackage = $false
        }
    }

    # retrun package vaility
    return $validPackage
}
