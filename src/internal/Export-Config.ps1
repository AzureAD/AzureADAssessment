<#
.SYNOPSIS
    Export Configuration
.EXAMPLE
    PS C:\>Export-Config
    Export Configuration
.INPUTS
    System.String
#>
function Export-Config {
    [CmdletBinding()]
    param (
        # Configuration Object
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObject = $script:ModuleConfig,
        # Property Names to Ignore
        [Parameter(Mandatory = $false)]
        [string[]] $IgnoreProperty,
        # Ignore Default Configuration Values
        [Parameter(Mandatory = $false)]
        [object] $IgnoreDefaultValues = $script:ModuleConfigDefault,
        # Configuration File Path
        [Parameter(Mandatory = $false)]
        [string] $Path = 'config.json'
    )

    ## Initialize
    if (![IO.Path]::IsPathRooted($Path)) {
        $AppDataDirectory = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)) 'AzureADAssessment'
        $Path = Join-Path $AppDataDirectory $Path
    }

    ## Read configuration file
    $ModuleConfigPersistent = $null
    if (Test-Path $Path) {
        ## Load from File
        $ModuleConfigPersistent = Get-Content $Path -Raw | ConvertFrom-Json
    }
    if (!$ModuleConfigPersistent) { $ModuleConfigPersistent = [PSCustomObject]@{} }

    ## Update persistent configuration
    foreach ($Property in $InputObject.psobject.Properties) {
        if ($Property.Name -in (Get-ObjectPropertyValue $ModuleConfigPersistent.psobject.Properties 'Name')) {
            ## Update previously persistent property value
            $ModuleConfigPersistent.($Property.Name) = $Property.Value
        }
        elseif ($IgnoreProperty -notcontains $Property.Name -and $Property.Value -ne (Get-ObjectPropertyValue $IgnoreDefaultValues $Property.Name)) {
            ## Add property with non-default value
            $ModuleConfigPersistent | Add-Member -Name $Property.Name -MemberType NoteProperty -Value $Property.Value
        }
    }

    ## Export persistent configuration to file
    Assert-DirectoryExists $AppDataDirectory
    ConvertTo-Json $ModuleConfigPersistent | Set-Content $Path
}
