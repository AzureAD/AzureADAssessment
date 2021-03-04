<#
.SYNOPSIS
    Exports events from an event log.
.DESCRIPTION
    
.EXAMPLE
    PS C:\>Export-EventLog 'C:\ADFS-Admin.evtx' -LogName 'AD FS/Admin'
    Export all logs from "AD FS/Admin" event log.
.INPUTS
    System.String
.LINK
    https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wevtutil
#>
function Export-EventLog {
    [CmdletBinding()]
    param
    (
        # Path to the file where the exported events will be stored
        [Parameter(Mandatory = $true)]
        [string] $Path,
        # Name of log
        [Parameter(Mandatory = $true)]
        [string] $LogName,
        # Defines the XPath query to filter the events that are read or exported.
        [Parameter(Mandatory = $false)]
        [Alias('q')]
        [string] $Query,
        # Specifies that the export file should be overwritten.
        [Parameter(Mandatory = $false)]
        [Alias('ow')]
        [switch] $Overwrite
    )

    $argsWevtutil = New-Object 'System.Collections.Generic.List[System.String]'
    $argsWevtutil.Add('export-log')
    $argsWevtutil.Add($LogName)
    $argsWevtutil.Add($Path)
    if ($Query) { $argsWevtutil.Add(('/q:"{0}"' -f $Query)) }
    if ($PSBoundParameters.ContainsKey('Overwrite')) { $argsWevtutil.Add(('/ow:{0}' -f $Overwrite)) }

    wevtutil $argsWevtutil.ToArray()
}
