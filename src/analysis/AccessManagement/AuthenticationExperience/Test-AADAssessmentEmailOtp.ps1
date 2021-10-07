<#
.SYNOPSIS
    Test for a recommendation on Email OTP
.PARAMETER Path
    Path where to look for packages with data collected
.DESCRIPTION
    Test for a recommendation on Email OTP
.EXAMPLE
    PS C:\> Test-AADAssessmentEmailOtp
    Test for email OTP from packages located in "C:\AzureADAssessment"
.EXAMPLE
    PS C:\> Test-AADAssessmentEmailOtp -Path "C:\Temp"
    Test for email OTP from packages located in "C:\Temp"
#>
function Test-AADAssessmentEmailOtp {
    [CmdletBinding()]
    param (
        # Specifies a path where extracted data resides (folder)
        [Parameter(Mandatory = $false)]
        [string] $Path = (Join-Path $env:SystemDrive 'AzureADAssessment')
    )

    Begin {
        # necessary evidence
        $evidenceRef = @("Tenant/emailOTPMethodPolicy.json")

        # import evidence
        $evidenceRef | Import-AADAssessmentEvidence -Path $Path

        # Initialise result
        $result = [PSCustomObject]@{
            "Category" = "Access Management"
            "Area" = "Authentication Experience"
            "Name" = "Email OTP"
            "Summary" = "With email OTP, org members can collaborate with anyone in the world by simply sharing a link or sending an invitation via email. Invited users prove their identity by using a verification code sent to their email account"
            "Recommandation" = "Enable email OTP"
            "Priority" = "Passed"
            "Data" = @()
            "ID" = "AR0001"
            "Visibility" = "All"
        }

        # check that we have a tenant
        if ($script:Evidences["Tenant"].Count -eq 0) {
            $result.Priority = "Skipped"
            $result.Data = "No tenant data found"
        }

        # pick the first tenant (should be only one)
        $tenantName = $script:Evidences["Tenant"].Keys[0]
    }

    Process {
        # get the policy
        $policy = $script:Evidences.Tenant[$tenantName]."emailOTPMethodPolicy.json"

        # error out if no policy where found
        if (!$policy) {
            throw "empty OTP policy"
        }

        # Set the recommendation priority if the policy is either not enabled or doesn't allow Email OTP
        if ($policy.state -ne "enabled" -or $policy.allowExternalIdToUseEmailOtp -ne "enabled") {
            $result.Priority = "P2"
        }
    }

    End {
        $result
    }
}