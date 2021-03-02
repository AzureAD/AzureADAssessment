<# 
 .Synopsis
  Produces the Azure AD Configuration reports required by the Azure AD assesment
 .Description
  This cmdlet reads the configuration information from the target Azure AD Tenant and produces the output files 
  in a target directory

 .PARAMETER OutputDirectory
    Full path of the directory where the output files will be generated.

.EXAMPLE
   .\Get-AADAssessmentReports -OutputDirectory "c:\temp\contoso" 

#>
function Complete-AADAssessmentReports {
    [CmdletBinding()]
    param
    (
        # Specifies a path
        [Parameter(Mandatory = $true)]
        [Alias("PSPath")]
        [string] $Path
        # 
        #[Parameter(Mandatory = $false)]
        #[string] $OutputDirectory
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        Connect-AADAssessment

        $OutputDirectory = Join-Path (Split-Path $Path) ([IO.Path]::GetFileNameWithoutExtension($Path))
        $AssessmentDetailPath = Join-Path $OutputDirectory "AADAssessment.json"

        Expand-Archive $Path -DestinationPath $OutputDirectory -Force
        $AssessmentDetail = Get-Content $AssessmentDetailPath -Raw | ConvertFrom-Json

        #-InstrumentationKey 'f7c43a96-9493-41e3-ad62-4320f5835ce2' "da85df16-64ea-4a62-8856-8bbb9ca86615"
        Write-AppInsightsEvent 'AAD Assessment Report Generation Complete' -OverrideProperties -Properties @{
            AssessmentId       = $AssessmentDetail.AssessmentId
            AssessmentVersion  = $AssessmentDetail.AssessmentVersion
            AssessmentTenantId = $AssessmentDetail.AssessmentTenantId
            AssessorTenantId   = $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId
            AssessorUserId     = if ($script:ConnectState.MsGraphToken -and $script:ConnectState.MsGraphToken.Account.HomeAccountId.TenantId -in ('72f988bf-86f1-41af-91ab-2d7cd011db47', 'cc7d0b33-84c6-4368-a879-2e47139b7b1f')) { $script:ConnectState.MsGraphToken.Account.HomeAccountId.ObjectId }
        }
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}
