<#
.SYNOPSIS
    Import Configuration
.EXAMPLE
    PS C:\>Import-Config
    Import Configuration
.INPUTS
    System.String
#>
function Import-Config {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        # Configuration File Path
        [Parameter(Mandatory = $false)]
        [string] $Path = 'config.json'
    )

    ## Initialize
    if (![IO.Path]::IsPathRooted($Path)) {
        $AppDataDirectory = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)) 'AzureADAssessment'
        $Path = Join-Path $AppDataDirectory $Path
    }

    if (Test-Path $Path) {
        ## Load from File
        $ModuleConfigPersistent = Get-Content $Path -Raw | ConvertFrom-Json

        ## Return Config
        return $ModuleConfigPersistent
    }
}
