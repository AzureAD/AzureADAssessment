<#
.SYNOPSIS
    Format number in different unit of measure.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 1234 -Unit 'byte(s)'
    Format number in kilobytes.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 12345678 -Unit 'B'
    Format number in megabytes.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 1234 'kilobyte(s)'
    Format number in megabytes.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 12345678 'KB' -TargetUnit 'MB'
    Format number in megabytes.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 1234 'bit(s)'
    Format number in kilobits.
.EXAMPLE
    PS C:\>Format-NumberWithUnit 1234 'm'
    Format number in kilometers.
.INPUTS
    System.Double
#>
function Format-NumberWithUnit {
    [CmdletBinding()]
    [OutputType()]
    param (
        # Number to scale
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [double] $Number,
        # Unit of Number
        [Parameter(Mandatory = $true, Position = 2)]
        [string] $Unit,
        # Target Unit of Number
        [Parameter(Mandatory = $false)]
        [string] $TargetUnit
    )

    begin {
        $mapMetricSymbol = @{
            -8 = 'y'
            -7 = 'z'
            -6 = 'a'
            -5 = 'f'
            -4 = 'p'
            -3 = 'n'
            -2 = 'µ'
            -1 = 'm'
            0  = ''
            1  = 'k'
            2  = 'M'
            3  = 'G'
            4  = 'T'
            5  = 'P'
            6  = 'E'
            7  = 'Z'
            8  = 'Y'
        }

        $mapMetricPrefix = New-Object hashtable @{
            -8 = 'yocto'
            -7 = 'zepto'
            -6 = 'atto'
            -5 = 'femto'
            -4 = 'pico'
            -3 = 'nano'
            -2 = 'micro'
            -1 = 'milli'
            0  = ''
            1  = 'kilo'
            2  = 'mega'
            3  = 'giga'
            4  = 'tera'
            5  = 'peta'
            6  = 'exa'
            7  = 'zetta'
            8  = 'yotta'
        }

        # $mapMetricToExponent = @{
        #     #'y'     = -8
        #     #'z'     = -7
        #     'a'     = -6
        #     'f'     = -5
        #     #'p'     = -4
        #     'n'     = -3
        #     'µ'     = -2
        #     #'m'     = -1
        #     'yocto' = -8
        #     'zepto' = -7
        #     'atto'  = -6
        #     'femto' = -5
        #     'pico'  = -4
        #     'nano'  = -3
        #     'micro' = -2
        #     'milli' = -1
        #     ''      = 0
        #     'kilo'  = 1
        #     'mega'  = 2
        #     'giga'  = 3
        #     'tera'  = 4
        #     'peta'  = 5
        #     'exa'   = 6
        #     'zetta' = 7
        #     'yotta' = 8
        #     'k'     = 1
        #     'M'     = 2
        #     'G'     = 3
        #     'T'     = 4
        #     'P'     = 5
        #     'E'     = 6
        #     'Z'     = 7
        #     'Y'     = 8
        # }

        # This method of adding hashtable method uses case-sensitive lookups
        $mapMetricToExponent = New-Object hashtable
        $mapMetricToExponent.Add('y', -8)
        $mapMetricToExponent.Add('z', -7)
        $mapMetricToExponent.Add('a', -6)
        $mapMetricToExponent.Add('f', -5)
        $mapMetricToExponent.Add('p', -4)
        $mapMetricToExponent.Add('n', -3)
        $mapMetricToExponent.Add('µ', -2)
        $mapMetricToExponent.Add('m', -1)
        $mapMetricToExponent.Add('yocto', -8)
        $mapMetricToExponent.Add('zepto', -7)
        $mapMetricToExponent.Add('atto', -6)
        $mapMetricToExponent.Add('femto', -5)
        $mapMetricToExponent.Add('pico', -4)
        $mapMetricToExponent.Add('nano', -3)
        $mapMetricToExponent.Add('micro', -2)
        $mapMetricToExponent.Add('milli', -1)
        $mapMetricToExponent.Add('', 0)
        $mapMetricToExponent.Add('kilo', 1)
        $mapMetricToExponent.Add('mega', 2)
        $mapMetricToExponent.Add('giga', 3)
        $mapMetricToExponent.Add('tera', 4)
        $mapMetricToExponent.Add('peta', 5)
        $mapMetricToExponent.Add('exa', 6)
        $mapMetricToExponent.Add('zetta', 7)
        $mapMetricToExponent.Add('yotta', 8)
        $mapMetricToExponent.Add('k', 1)
        $mapMetricToExponent.Add('M', 2)
        $mapMetricToExponent.Add('G', 3)
        $mapMetricToExponent.Add('T', 4)
        $mapMetricToExponent.Add('P', 5)
        $mapMetricToExponent.Add('E', 6)
        $mapMetricToExponent.Add('Z', 7)
        $mapMetricToExponent.Add('Y', 8)
    }

    process {
        if ($Unit -match '(yocto|zepto|atto|femto|pico|nano|micro|milli|centi|deci|deca|hecto|kilo|mega|giga|tera|peta|exa|zetta|yotta|[yzafpnµmcdhkMGTPEZY](?=[A-Z]$|(?-i:[A-Z])))?(.*)') {
            $UnitPrefix = if ($Matches[1] -in 'M', 'P', 'Z', 'Y') { $Matches[1] } elseif ($Matches[1]) { $Matches[1].ToLower() } else { '' }
            $UnitName = $Matches[2]
        }

        if ($UnitName.StartsWith('Byte', [System.StringComparison]::OrdinalIgnoreCase) -or $UnitName -ceq 'B') {
            $Base = 1024
        }
        else {
            $Base = 1000
        }

        [int] $SourceExponent = $mapMetricToExponent[$UnitPrefix.ToLower()]
        [int] $AutoExponent = 0
        if ($TargetUnit) {
            if ($TargetUnit -match '(yocto|zepto|atto|femto|pico|nano|micro|milli|centi|deci|deca|hecto|kilo|mega|giga|tera|peta|exa|zetta|yotta|[yzafpnµmcdhkMGTPEZY](?=[A-Z]$|(?-i:[A-Z])))?(.*)') {
                [string] $TargetUnitPrefix = $null
                $TargetUnitPrefix = if ($Matches[1] -in 'M', 'P', 'Z', 'Y') { $Matches[1] } elseif ($Matches[1]) { $Matches[1].ToLower() } else { '' }
                $UnitName = $Matches[2]

                $AutoExponent = $mapMetricToExponent[$TargetUnitPrefix] - $SourceExponent
            }
        }
        else {
            $AutoExponent = [System.Math]::Floor([System.Math]::Log($Number) / [System.Math]::Log($Base)) # Fails when number is negative

            if ($UnitName.Length -le 2) {
                $TargetUnit = $mapMetricSymbol[($SourceExponent + $AutoExponent)] + $UnitName
            }
            else {
                $TargetUnit = $mapMetricPrefix[($SourceExponent + $AutoExponent)] + $UnitName
            }
        }
        [double] $ScaledNumber = $Number / [System.Math]::Pow($Base, $AutoExponent)

        Write-Output ('{0:0.##} {1}' -f $ScaledNumber, $TargetUnit)
    }
}
