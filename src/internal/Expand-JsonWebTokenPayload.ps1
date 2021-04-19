<#
.SYNOPSIS
    Extract Json Web Token (JWT) from JWS structure to PowerShell object.
.EXAMPLE
    PS C:\>$MsalToken.IdToken | Expand-JsonWebTokenPayload
    Extract Json Web Token (JWT) from JWS structure to PowerShell object.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/MSIdentityTools
#>
function Expand-JsonWebTokenPayload {
    [CmdletBinding()]
    [Alias('Expand-JwtPayload')]
    [OutputType([PSCustomObject])]
    param (
        # JSON Web Signature (JWS)
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]] $InputObjects
    )

    process {
        foreach ($InputObject in $InputObjects) {
            [string] $JwsPayload = $InputObject.Split('.')[1]
            $JwtDecoded = $JwsPayload | ConvertFrom-Base64String -Base64Url | ConvertFrom-Json
            Write-Output $JwtDecoded
        }
    }
}
