<#
.SYNOPSIS
    Expand MS Graph relationship property on object.
.EXAMPLE
    PS C:\>@{ id = "00000000-0000-0000-0000-000000000000" } | Expand-MsGraphRelationship -ObjectType groups -PropertyName members -References
    Add and populate members property on input object using a references call for best performance.
.INPUTS
    System.Object
#>
function Expand-MsGraphRelationship {
    [CmdletBinding()]
    param (
        # MS Graph Object to expand with relationship property.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        # Type of object being expanded.
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('groups', 'directoryRoles')]
        [string] $ObjectType,
        # Name of relationship property.
        [Parameter(Mandatory = $true)]
        [string] $PropertyName,
        # Only retrieve relationship object references.
        [Parameter(Mandatory = $false)]
        [switch] $References,
        # Filters properties (columns).
        [Parameter(Mandatory = $false)]
        [string[]] $Select,
        # Number of results per request
        [Parameter(Mandatory = $false)]
        [int] $Top,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )

    begin {
        $InputObjects = New-Object 'System.Collections.Generic.List[psobject]'
        $uri = ('{0}/{{0}}/{1}' -f $ObjectType, $PropertyName)
        if ($References) { $uri = '{0}/$ref' -f $uri }
        elseif ($Select) { $uri = $uri + ('?$select={0}' -f ($Select -join ',')) }
    }

    process {
        $InputObjects.Add($InputObject)
        ## Wait For Full Batch
        if ($InputObjects.Count -ge $BatchSize) {
            if ($Top -gt 1) {
                [array] $Results = $InputObjects[0..($BatchSize - 1)] | Get-MsGraphResults $uri -Top $Top -DisableUniqueIdDeduplication -GroupOutputByRequest
            }
            else {
                [array] $Results = $InputObjects[0..($BatchSize - 1)] | Get-MsGraphResults $uri -DisableUniqueIdDeduplication -GroupOutputByRequest
            }
            for ($i = 0; $i -lt $InputObjects.Count; $i++) {
                [array] $refValues = $Results[$i]
                if ($References) { $refValues = $refValues | Expand-ODataId | Select-Object -Property "*" -ExcludeProperty '@odata.id' }
                if ($null -eq $refValues) { $refValues = @() }
                $InputObjects[$i] | Add-Member -Name $PropertyName -MemberType NoteProperty -Value $refValues -PassThru -ErrorAction Ignore
            }
            $InputObjects.RemoveRange(0, $BatchSize)
        }
    }

    end {
        ## Finish Remaining
        if ($InputObjects.Count) {
            if ($Top -gt 1) {
                [array] $Results = $InputObjects | Get-MsGraphResults $uri -Top $Top -DisableUniqueIdDeduplication -GroupOutputByRequest
            }
            else {
                [array] $Results = $InputObjects | Get-MsGraphResults $uri -DisableUniqueIdDeduplication -GroupOutputByRequest
            }
            for ($i = 0; $i -lt $InputObjects.Count; $i++) {
                [array] $refValues = $Results[$i]
                if ($References) { $refValues = $refValues | Expand-ODataId | Select-Object -Property "*" -ExcludeProperty '@odata.id' }
                if ($null -eq $refValues) { $refValues = @() }
                $InputObjects[$i] | Add-Member -Name $PropertyName -MemberType NoteProperty -Value $refValues -PassThru -ErrorAction Ignore
            }
        }
    }
}
