
<# 
 .Synopsis
  Exports the configuration of Relying Party Trusts and Claims Provider Trusts

 .Description
  Creates and zips a set of files that hold the configuration of ADFS claim providers and relying parties

 .Example
  Export-AADAssessADFSConfiguration
#>

Function Export-AADAssessADFSConfiguration {
    $filePathBase = "C:\ADFS\apps\"
    $zipfileBase = "c:\ADFS\zip\"
    $zipfileName = $zipfileBase + "ADFSApps.zip"
    mkdir $filePathBase -ErrorAction SilentlyContinue
    mkdir $zipfileBase -ErrorAction SilentlyContinue

    $AdfsRelyingPartyTrusts = Get-AdfsRelyingPartyTrust
    foreach ($AdfsRelyingPartyTrust in $AdfsRelyingPartyTrusts) {
        $RPfileName = $AdfsRelyingPartyTrust.Name.ToString()
        $CleanedRPFileName = Remove-InvalidFileNameChars -Name $RPfileName
        $RPName = "RPT - " + $CleanedRPFileName
        $filePath = $filePathBase + $RPName + '.xml'
        $AdfsRelyingPartyTrust | Export-Clixml $filePath -ErrorAction SilentlyContinue
    }

    $AdfsClaimsProviderTrusts = Get-AdfsClaimsProviderTrust
    foreach ($AdfsClaimsProviderTrust in $AdfsClaimsProviderTrusts) {
 
        $CPfileName = $AdfsClaimsProviderTrust.Name.ToString()
        $CleanedCPFileName = Remove-InvalidFileNameChars -Name $CPfileName
        $CPTName = "CPT - " + $CleanedCPFileName
        $filePath = $filePathBase + $CPTName + '.xml'
        $AdfsClaimsProviderTrust | Export-Clixml $filePath -ErrorAction SilentlyContinue
 
    } 

    If (Test-Path $zipfileName) {
        Remove-Item $zipfileName
    }

    Add-Type -assembly "system.io.compression.filesystem"
    [io.compression.zipfile]::CreateFromDirectory($filePathBase, $zipfileName)
    
    Invoke-Item $zipfileBase
}
