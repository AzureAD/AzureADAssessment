<#
.SYNOPSIS
    Get Configuration
.EXAMPLE
    PS C:\>Get-Config
    Get Configuration
.INPUTS
    System.String
#>
function Get-Config {
    [CmdletBinding()]
    [OutputType([object])]
    param (
        # Output Module Configuration
        [Parameter(Mandatory = $false)]
        [switch] $PassThru,
        # Configuration File Path
        [Parameter(Mandatory = $false)]
        [string] $Path = 'Config.json'
    )

    if (![IO.Path]::IsPathRooted($Path)) {
        $AppDataDirectory = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)) 'AzureADAssessment'
        $Path = Join-Path $AppDataDirectory $Path
    }

    [hashtable] $ModuleConfigDefaults = @{
        'ai.disabled'           = $false
        'ai.instrumentationKey' = 'da85df16-64ea-4a62-8856-8bbb9ca86615'
        'ai.ingestionEndpoint'  = 'https://dc.services.visualstudio.com/v2/track'
    }

    if (Test-Path $Path) {
        ## Load from File
        $script:ModuleConfig = Get-Content $Path -Raw | ConvertFrom-Json
        foreach ($Key in $ModuleConfigDefaults.Keys) {
            if (!($script:ModuleConfig | Get-Member -Name $Key -MemberType NoteProperty)) {
                $script:ModuleConfig | Add-Member -Name $Key -MemberType NoteProperty -Value $ModuleConfigDefaults[$Key]
            }
        }
    }
    else {
        ## Load from Defaults
        $script:ModuleConfig = [PSCustomObject]$ModuleConfigDefaults
    }

    if ($PassThru) {
        return $script:ModuleConfig
    }
}
