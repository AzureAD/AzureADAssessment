<#
.SYNOPSIS

.EXAMPLE
    PS C:\>

.INPUTS
    System.Object
#>
function Expand-MsGraphRelationship {
    [CmdletBinding()]
    param (
        #
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        #
        [Parameter(Mandatory = $true)]
        [Alias('Type')]
        [ValidateSet('groups', 'directoryRoles')]
        [string] $ObjectType,
        #
        [Parameter(Mandatory = $true)]
        [string] $PropertyName,
        #
        [Parameter(Mandatory = $false)]
        [switch] $References,
        # Specify Batch size.
        [Parameter(Mandatory = $false)]
        [int] $BatchSize = 20
    )

    begin {
        $InputObjects = New-Object 'System.Collections.Generic.List[psobject]'
        $uri = ('{0}/{{0}}/{1}' -f $ObjectType, $PropertyName)
        if ($References) { $uri = '{0}/$ref' -f $uri }
    }

    process {
        $InputObjects.Add($InputObject)
        ## Wait For Full Batch
        if ($InputObjects.Count -ge $BatchSize) {
            [array] $Results = $InputObjects[0..($BatchSize - 1)] | Get-MsGraphResults $uri -DisableUniqueIdDeduplication -GroupOutputByRequest
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
            [array] $Results = $InputObjects | Get-MsGraphResults $uri -DisableUniqueIdDeduplication -GroupOutputByRequest
            for ($i = 0; $i -lt $InputObjects.Count; $i++) {
                [array] $refValues = $Results[$i]
                if ($References) { $refValues = $refValues | Expand-ODataId | Select-Object -Property "*" -ExcludeProperty '@odata.id' }
                if ($null -eq $refValues) { $refValues = @() }
                $InputObjects[$i] | Add-Member -Name $PropertyName -MemberType NoteProperty -Value $refValues -PassThru -ErrorAction Ignore
            }
        }
    }
}
