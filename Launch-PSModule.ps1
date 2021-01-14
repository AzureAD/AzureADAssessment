param
(
    # Module to Launch
    [Parameter(Mandatory = $false)]
    [string] $ModuleManifestPath = ".\src\*.psd1",
    # ScriptBlock to Execute After Module Import
    [Parameter(Mandatory = $false)]
    [scriptblock] $PostImportScriptBlock,
    # Paths to PowerShell Executables
    [Parameter(Mandatory = $false)]
    [string[]] $PowerShellPaths = @(
        'pwsh'
        'powershell'
    ),
    # Import Module into the same session
    [Parameter(Mandatory = $false)]
    [switch] $NoNewWindow #= $true
)

if ($NoNewWindow) {
    Import-Module $ModuleManifestPath -PassThru -Force
    if ($PostImportScriptBlock) { Invoke-Command -ScriptBlock $PostImportScriptBlock -NoNewScope }
}
else {
    [scriptblock] $ScriptBlock = {
        param ([string]$ModulePath, [scriptblock]$PostImportScriptBlock)
        ## Force WindowsPowerShell to load correct version of built-in modules when launched from PowerShell 6+
        if ($PSVersionTable.PSEdition -eq 'Desktop') { Import-Module 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility', 'CimCmdlets' -MaximumVersion 5.9.9.9 }
        Import-Module $ModulePath -PassThru
        Invoke-Command -ScriptBlock $PostImportScriptBlock -NoNewScope
    }
    $strScriptBlock = 'Invoke-Command -ScriptBlock {{ {0} }} -ArgumentList {1}, {{ {2} }}' -f $ScriptBlock, $ModuleManifestPath, $PostImportScriptBlock
    #$strScriptBlock = 'Import-Module {0} -PassThru' -f $ModuleManifestPath

    foreach ($Path in $PowerShellPaths) {
        Start-Process $Path -ArgumentList ('-NoExit', '-NoProfile', '-EncodedCommand', [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($strScriptBlock)))
    }
}
