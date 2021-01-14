<#
.SYNOPSIS
    Decompose characters to their base character equivilents and remove diacritics.
.DESCRIPTION

.EXAMPLE
    PS C:\>Remove-Diacritics 'àáâãäåÀÁÂÃÄÅﬁ⁵ẛ'
    Decompose characters to their base character equivilents and remove diacritics.
.EXAMPLE
    PS C:\>Remove-Diacritics 'àáâãäåÀÁÂÃÄÅﬁ⁵ẛ' -CompatibilityDecomposition
    Decompose composite characters to their base character equivilents and remove diacritics.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Remove-Diacritics {
    [CmdletBinding()]
    param
    (
        # String value to transform.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string[]] $InputStrings,
        # Use compatibility decomposition instead of canonical decomposition which further decomposes composite characters and many formatting distinctions are removed.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch] $CompatibilityDecomposition
    )

    process {
        [System.Text.NormalizationForm] $NormalizationForm = [System.Text.NormalizationForm]::FormD
        if ($CompatibilityDecomposition) { $NormalizationForm = [System.Text.NormalizationForm]::FormKD }
        foreach ($InputString in $InputStrings) {
            $NormalizedString = $InputString.Normalize($NormalizationForm)
            $OutputString = New-Object System.Text.StringBuilder

            foreach ($char in $NormalizedString.ToCharArray()) {
                if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
                    [void] $OutputString.Append($char)
                }
            }

            Write-Output $OutputString.ToString()
        }
    }
}
