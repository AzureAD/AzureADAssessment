<# 
 .Synopsis
  Gets the list of all enabled endpoints in ADFS

 .Description
  Gets the list of all enabled endpoints in ADFS

 .Example
  Get-AADAssessADFSEndpoints | Export-Csv -Path ".\ADFSEnabledEndpoints.csv" 
#>
function Get-AADAssessADFSEndpoints {
    Get-AdfsEndpoint | Where-Object { $_.Enabled -eq "True" } 
}
