<#
.SYNOPSIS
    Converts an object to a JSON-formatted string and saves the string to a file.
.EXAMPLE
    PS C:\>@{ Property = 'Value' } | Export-JsonArray -Path .\JsonFile.json
    Converts an object to a JSON-formatted string and saves the string to a file.
.INPUTS
    System.Object
.NOTES
    Due to limitations in script functions, there is no way to override the StopProcessing() function or detect the user stopping a command.
    This could leave a file lock on the output file. To release the lock on the file manually either close the PowerShell process or force garbage collection using the command below.
    PS C:\>[System.GC]::Collect()
#>
function Export-JsonArray {
    [CmdletBinding()]
    [OutputType([string])]
    param (
        # Specifies the objects to convert to JSON format.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]] $InputObject,
        # Omits white space and indented formatting in the output string.
        [Parameter(Mandatory = $false)]
        [switch] $Compress,
        # Specifies how many levels of contained objects are included in the JSON representation. The default value is 2.
        [Parameter(Mandatory = $false)]
        [int] $Depth = 2,
        # A required parameter that specifies the location to save the JSON output file.
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Path
    )

    begin {
        [int] $iObject = 0
        [string] $JsonObject = $null

        try {
            $StreamWriter = New-Object System.IO.StreamWriter -ArgumentList $Path
        }
        catch [System.Management.Automation.MethodInvocationException] {
            [System.GC]::Collect()
            $StreamWriter = New-Object System.IO.StreamWriter -ArgumentList $Path
        }
        try {
            ## Start JSON Array to File
            #Set-Content $Path -Value '[' -NoNewline
            if ($Compress) { $StreamWriter.Write('[') }
            else { $StreamWriter.WriteLine('[') }
        }
        catch {
            $StreamWriter.Close()
            throw
        }
    }

    process {
        try {
            foreach ($Object in $InputObject) {
                $JsonObject = ConvertTo-Json $Object -Depth $Depth -Compress:$Compress
                if ($iObject -gt 0) {
                    if ($Compress) { $StreamWriter.Write(',') }
                    else { $StreamWriter.WriteLine(',') }
                }
                ## Add JSON Object to File
                #Add-Content $Path -Value $JsonObject -NoNewline
                if (!$Compress) { $JsonObject = ('  ' + $JsonObject) -replace ([Environment]::NewLine), "$([Environment]::NewLine)  " }
                $StreamWriter.Write($JsonObject)
                $iObject++
            }
        }
        catch {
            $StreamWriter.Close()
            throw
        }
    }

    end {
        try {
            ## Complete JSON Array to File
            #Add-Content $Path -Value ']'
            if (!$Compress) { $StreamWriter.WriteLine('') }
            $StreamWriter.Write(']')
        }
        finally {
            $StreamWriter.Close()
        }
    }
}
