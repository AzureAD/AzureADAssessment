<#
.SYNOPSIS
    Format data size in bytes to human readable format.
.DESCRIPTION

.EXAMPLE
    PS > Format-DataSize 123
    Format 123 bytes to "123.0 Bytes".
.EXAMPLE
    PS > Format-DataSize 1234567890
    Format 1234567890 bytes to "1.150 GB".
.INPUTS
    System.Int64
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Format-DataSize {
    [CmdletBinding()]
    [Alias('Format-FileSize')]
    [OutputType([string])]
    param (
        # 
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [long] $Bytes
    )

    begin {
        ## Adapted From:
        ##  https://github.com/PowerShell/PowerShell/blob/80b5df4b7f6e749e34a2363e1ef6cc09f2761c89/src/System.Management.Automation/engine/Utils.cs#L1489
        function DisplayHumanReadableFileSize([long] $bytes) {
            switch ($bytes) {
                { $_ -lt 1024 -and $_ -ge 0 } { return "{0:0.0} Bytes" -f $bytes }
                { $_ -lt 1048576 -and $_ -ge 1024 } { return "{0:0.0} KB" -f ($bytes / 1024) }
                { $_ -lt 1073741824 -and $_ -ge 1048576 } { return "{0:0.0} MB" -f ($bytes / 1048576) }
                { $_ -lt 1099511627776 -and $_ -ge 1073741824 } { return "{0:0.000} GB" -f ($bytes / 1073741824) }
                { $_ -lt 1125899906842624 -and $_ -ge 1099511627776 } { return "{0:0.00000} TB" -f ($bytes / 1099511627776) }
                { $_ -lt 1152921504606847000 -and $_ -ge 1125899906842624 } { return "{0:0.0000000} PB" -f ($bytes / 1125899906842624) }
                { $_ -ge 1152921504606847000 } { return "{0:0.000000000} EB" -f ($bytes / 1152921504606847000 ) }
                Default { return "0 Bytes" }
            }
        }
    }

    process {
        foreach ($Byte in $Bytes) {
            DisplayHumanReadableFileSize $Byte
        }
    }
}
