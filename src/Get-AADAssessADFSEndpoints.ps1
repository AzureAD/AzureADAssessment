<# 
 .Synopsis
  Gets the list of all enabled endpoints in ADFS

 .Description
  Gets the list of all enabled endpoints in ADFS

 .Example
  Get-AADAssessADFSEndpoints | Export-Csv -Path ".\ADFSEnabledEndpoints.csv" 
#>
function Get-AADAssessADFSEndpoints {
  Start-AppInsightsRequest $MyInvocation.MyCommand.Name
  try {

    Get-AdfsEndpoint | Where-Object { $_.Enabled -eq "True" } 
    
  }
  catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException $_.Exception }; throw }
  finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $true }
}
