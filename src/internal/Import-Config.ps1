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
    [OutputType([object])]
    param (
        # Configuration File Path
        [Parameter(Mandatory = $false)]
        [string] $Path = 'Config.json',
        # Variable to output config
        [Parameter(Mandatory = $false)]
        [ref] $OutConfig = ([ref]$script:ModuleConfig)
    )

    ## Initialize
    if (![IO.Path]::IsPathRooted($Path)) {
        $AppDataDirectory = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)) 'AzureADAssessment'
        $Path = Join-Path $AppDataDirectory $Path
    }

    if (Test-Path $Path) {
        ## Load from File
        $ModuleConfigPersistent = Get-Content $Path -Raw | ConvertFrom-Json

        ## Update local configuration
        Set-Config $ModuleConfigPersistent -OutConfig $OutConfig
    }
}
