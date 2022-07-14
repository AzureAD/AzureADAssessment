<#
.SYNOPSIS
    Test that the provided Azure AD Assessment package has the necessary content
.DESCRIPTION
    Test that the provided Azure AD Assessment package has the necessary content
.EXAMPLE
    PS C:\>Test-AADAssessmentPackage 'C:\AzureADAssessmentData-contoso.onmicrosoft.com.aad'
    Test that the package for contoso.onmicrosoft.com has the necesary content for the assessment.
.INPUTS
    System.String
#>
function Test-AADAssessmentPackage {
    [CmdletBinding()]
    param
    (
        # Path to the file where the exported events will be stored
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    if (!(Test-Path -path $Path)) {
        Write-Warning "Assessment package not found"
        return $false
    }

    $fullPath = Convert-Path $Path

    $requiredEntries = @(
        "AAD-*.onmicrosoft.com/administrativeUnits.csv",
        "AAD-*.onmicrosoft.com/AppCredentialsReport.csv",
        "AAD-*.onmicrosoft.com/applications.json",
        "AAD-*.onmicrosoft.com/appRoleAssignments.csv",
        "AAD-*.onmicrosoft.com/conditionalAccessPolicies.json",
        "AAD-*.onmicrosoft.com/ConsentGrantReport.csv",
        "AAD-*.onmicrosoft.com/emailOTPMethodPolicy.json",
        "AAD-*.onmicrosoft.com/groups.csv",
        "AAD-*.onmicrosoft.com/namedLocations.json",
        "AAD-*.onmicrosoft.com/NotificationsEmailsReport.csv",
        "AAD-*.onmicrosoft.com/oauth2PermissionGrants.csv",
        "AAD-*.onmicrosoft.com/organization.json",
        "AAD-*.onmicrosoft.com/RoleAssignmentReport.csv",
        "AAD-*.onmicrosoft.com/roleDefinitions.csv",
        "AAD-*.onmicrosoft.com/servicePrincipals.csv",
        "AAD-*.onmicrosoft.com/servicePrincipals.json",
        "AAD-*.onmicrosoft.com/subscribedSkus.json",
        "AAD-*.onmicrosoft.com/userRegistrationDetails.json",
        "AAD-*.onmicrosoft.com/users.csv",
        "AzureADAssessment.json"
    )

    $entries = [IO.Compression.ZipFile]::OpenRead($fullPath).Entries

    $effectiveEntries = $entries | Where-Object { $_.Length -gt 0}

    if ($effectiveEntries -match "Data\.(xml|csv)$") {
        Write-Warning "Assessment package contains data files which should have been removed by reporting"
    }

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
