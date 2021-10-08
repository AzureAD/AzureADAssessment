<#
.SYNOPSIS

.EXAMPLE
    PS C:\>

.INPUTS
    System.Object
#>
function Expand-ODataId {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowEmptyCollection()]
        [object[]] $InputObjects
    )

    process {
        foreach ($InputObject in $InputObjects) {
            if ($InputObject.'@odata.id' -match 'directoryObjects/(.+)/.+\.(.+)$') {
                $InputObject | Add-Member -Name 'id' -MemberType NoteProperty -Value $Matches[1] -ErrorAction Ignore
                $InputObject | Add-Member -Name '@odata.type' -MemberType NoteProperty -Value ('#microsoft.graph.{0}' -f ($Matches[2][0].ToString().ToLower() + $Matches[2].Substring(1))) -ErrorAction Ignore
            }
            $InputObject
        }
    }
}
