<#
.SYNOPSIS
    Remove invalid filename characters from string.
.DESCRIPTION

.EXAMPLE
    PS C:\>Remove-InvalidFileNameCharacters 'à/1\b?2|ć*3<đ>4 ē'
    Remove invalid filename characters from string.
.EXAMPLE
    PS C:\>Remove-InvalidFileNameCharacters 'à/1\b?2|ć*3<đ>4 ē' -RemoveDiacritics
    Remove invalid filename characters and diacritics from string.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Remove-InvalidFileNameCharacters {
    [CmdletBinding()]
    param
    (
        # String value to transform.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string[]] $InputStrings,
        # Character used as replacement for invalid characters. Use '' to simply remove.
        [Parameter(Mandatory = $false)]
        [string] $ReplacementCharacter = '-',
        # Replace characters with diacritics to their non-diacritic equivilent.
        [Parameter(Mandatory = $false)]
        [switch] $RemoveDiacritics
    )

    process {
        foreach ($InputString in $InputStrings) {
            [string] $OutputString = $InputString
            if ($RemoveDiacritics) { $OutputString = Remove-Diacritics $OutputString -CompatibilityDecomposition }
            $OutputString = [regex]::Replace($OutputString, ('[{0}]' -f [regex]::Escape([System.IO.Path]::GetInvalidFileNameChars() -join '')), $ReplacementCharacter)
            Write-Output $OutputString
        }
    }
}
