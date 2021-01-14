
Function Get-AADAssessmentSingleReport {
    [CmdletBinding()]
    param
    (
        [String]$FunctionName,
        [String]$OutputDirectory,
        [String]$OutputCSVFileName
    )

    $OriginalThreadUICulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
    $OriginalThreadCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture

    try {
        #reports need to be created in en-US for backend processing of datetime
        $culture = [System.Globalization.CultureInfo]::GetCultureInfo("en-US")
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $culture
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

        $OutputFilePath = Join-Path $OutputDirectory $OutputCSVFileName
        #$Report = Invoke-Expression -Command $FunctionName
        #$Report | Export-Csv -Path $OutputFilePath
        Invoke-Expression -Command $FunctionName | Export-Csv -Path $OutputFilePath
    }
    finally {
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $OriginalThreadUICulture
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $OriginalThreadCulture
    } 
}
