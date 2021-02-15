<# 
 .Synopsis
  Gets Azure AD Application Proxy Connector Logs

 .Description
  This functions returns the events from the Azure AD Application Proxy Connector Admin Log

 .Parameter DaysToRetrieve
  Indicates how far back in the past will the events be retrieved

 .Example

 $targetGalleryApp = "GalleryAppName"
 $targetGroup = Get-AzureADGroup -SearchString "TestGroupName"
 $targetAzureADRole = "TestRoleName"
 $targetADFSRPId = "ADFSRPIdentifier"

  $RP=Get-AdfsRelyingPartyTrust -Identifier $targetADFSRPId
  $galleryApp = Get-AzureADApplicationTemplate -DisplayNameFilter $targetGalleryApp

  $RP=Get-AdfsRelyingPartyTrust -Identifier $targetADFSRPId

  New-AzureADAppFromADFSRPTrust `
    -AzureADAppTemplateId $galleryApp.id `
    -ADFSRelyingPartyTrust $RP `
    -TestGroupAssignmentObjectId $targetGroup.ObjectId `
    -TestGroupAssignmentRoleName $targetAzureADRole
#>
function Get-AADAssessAppProxyConnectorLog {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]
        $DaysToRetrieve
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {
        $TimeFilter = $DaysToRetrieve * 86400000
        $EventFilterXml = '<QueryList><Query Id="0" Path="Microsoft-AadApplicationProxy-Connector/Admin"><Select Path="Microsoft-AadApplicationProxy-Connector/Admin">*[System[TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>' -f $TimeFilter
        Get-WinEvent -FilterXml $EventFilterXml
    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}
