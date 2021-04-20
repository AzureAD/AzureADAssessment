
function Format-Csv {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        #
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]] $InputObjects,
        #
        [Parameter(Mandatory = $false)]
        [string] $ArrayDelimiter = "`r`n"
    )

    begin {
        function Transform ($InputObject) {
            if ($InputObject) {
                switch ($InputObject.GetType()) {
                    { $_.Equals([DateTime]) } {
                        $InputObject = $InputObject.ToString("o")
                        break
                    }
                    { $_.BaseType -and $_.BaseType.Equals([Array]) } {
                        for ($i = 0; $i -lt $InputObject.Count; $i++) {
                            $InputObject[$i] = Transform $InputObject[$i]
                        }
                        $InputObject = $InputObject -join $ArrayDelimiter
                        break
                    }
                    { $_.Equals([System.Management.Automation.PSCustomObject]) } {
                        return $InputObject | ConvertTo-Json
                    }
                }
            }
            return $InputObject
        }
    }

    process {
        foreach ($InputObject in $InputObjects) {
            $OutputObject = $InputObject.psobject.Copy()
            foreach ($Property in $OutputObject.psobject.Properties) {
                $Property.Value = Transform $Property.Value
            }
            Write-Output $OutputObject
        }
    }
}
