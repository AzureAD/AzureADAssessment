<#
.SYNOPSIS
    Convert Base64 String to Byte Array or Plain Text String.
.EXAMPLE
    PS C:\>ConvertFrom-Base64String "QSBzdHJpbmcgd2l0aCBiYXNlNjQgZW5jb2Rpbmc="
    Convert Base64 String to String with Default Encoding.
.EXAMPLE
    PS C:\>"QVNDSUkgc3RyaW5nIHdpdGggYmFzZTY0dXJsIGVuY29kaW5n" | ConvertFrom-Base64String -Base64Url -Encoding Ascii
    Convert Base64Url String to String with Ascii Encoding.
.EXAMPLE
    PS C:\>[guid](ConvertFrom-Base64String "5oIhNbCaFUGAe8NsiAKfpA==" -RawBytes)
    Convert Base64 String to GUID.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function ConvertFrom-Base64String {
    [CmdletBinding()]
    [OutputType([byte[]], [string])]
    param (
        # Value to convert
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputObjects,
        # Use base64url variant
        [Parameter (Mandatory = $false)]
        [switch] $Base64Url,
        # Output raw byte array
        [Parameter (Mandatory = $false)]
        [switch] $RawBytes,
        # Encoding to use for text strings
        [Parameter (Mandatory = $false)]
        [ValidateSet('Ascii', 'UTF32', 'UTF7', 'UTF8', 'BigEndianUnicode', 'Unicode')]
        [string] $Encoding = 'Default'
    )

    process {
        foreach ($InputObject in $InputObjects) {
            [string] $strBase64 = $InputObject
            if (!$PSBoundParameters.ContainsValue('Base64Url') -and ($strBase64.Contains('-') -or $strBase64.Contains('_'))) { $Base64Url = $true }
            if ($Base64Url) { $strBase64 = $strBase64.Replace('-', '+').Replace('_', '/').PadRight($strBase64.Length + (4 - $strBase64.Length % 4) % 4, '=') }
            [byte[]] $outBytes = [System.Convert]::FromBase64String($strBase64)
            if ($RawBytes) {
                Write-Output $outBytes -NoEnumerate
            }
            else {
                [string] $outString = ([Text.Encoding]::$Encoding.GetString($outBytes))
                Write-Output $outString
            }
        }
    }
}
