<#
.SYNOPSIS
    Use @odata.id property on object to expand object with id and @odata.type properties.
.EXAMPLE
    PS C:\>Expand-ODataId @{ @odata.id = "directoryObjects/00000000-0000-0000-0000-000000000000/Microsoft.DirectoryServices.User" }
    Expands input object with extracted id and @odata.type from @odata.id property.
.INPUTS
    System.Object
#>
function Expand-ODataId {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        # MS Graph Object with @odata.id property to expand.
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
