
function Format-Csv {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        #
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]] $InputObjects,
        #
        [Parameter(Mandatory = $false)]
        [string] $ArrayDelimiter = ";"
    )

    begin {
        function Transform ($InputObject) {
            if ($InputObject) {
                if ($InputObject -is [DateTime]) {
                    $InputObject = $InputObject.ToString("o")
                }
                elseif ($InputObject -is [Array] -or $InputObject -is [System.Collections.ArrayList]) {
                    for ($i = 0; $i -lt $InputObject.Count; $i++) {
                        $InputObject[$i] = Transform $InputObject[$i]
                    }
                    $InputObject = $InputObject -join $ArrayDelimiter
                }
                elseif ($InputObject -is [System.Management.Automation.PSCustomObject]) {
                    return ConvertTo-Json $InputObject
                }
            }
            return $InputObject
        }
    }

    process {
        foreach ($InputObject in $InputObjects) {
            $OutputObject = $InputObject.psobject.Copy()
            foreach ($Property in $OutputObject.psobject.Properties) {
                if ($Property.Value -is [DateTime] -or $Property.Value -is [Array] -or $Property.Value -is [System.Collections.ArrayList] -or $Property.Value -is [System.Management.Automation.PSCustomObject]) {
                    $Property.Value = Transform $Property.Value
                }
            }
            $OutputObject
        }
    }
}
