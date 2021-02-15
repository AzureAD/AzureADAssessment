<#
.SYNOPSIS
    Set Configuration
.EXAMPLE
    PS C:\>Set-Config
    Set Configuration
.INPUTS
    System.String
#>
function Set-Config {
    [CmdletBinding()]
    #[OutputType([object])]
    param (
        # Application Insights Telemetry Disabled
        [Parameter(Mandatory = $false)]
        [bool] $AIDisabled,
        # Application Insights Instrumentation Key
        [Parameter(Mandatory = $false)]
        [string] $AIInstrumentationKey,
        # Application Insights Ingestion Endpoint
        [Parameter(Mandatory = $false)]
        [string] $AIIngestionEndpoint,
        # Configuration File Path
        [Parameter(Mandatory = $false)]
        [string] $Path = 'Config.json'
    )

    if (![IO.Path]::IsPathRooted($Path)) {
        $AppDataDirectory = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)) 'AzureADAssessment'
        $Path = Join-Path $AppDataDirectory $Path
    }

    if ($PSBoundParameters.ContainsKey('AIDisabled')) { $script:ModuleConfig.'ai.disabled' = $AIDisabled }
    if ($PSBoundParameters.ContainsKey('AIInstrumentationKey')) { $script:ModuleConfig.'ai.instrumentationKey' = $AIInstrumentationKey }
    if ($PSBoundParameters.ContainsKey('AIIngestionEndpoint')) { $script:ModuleConfig.'ai.ingestionEndpoint' = $AIIngestionEndpoint }
    
    Assert-DirectoryExists $AppDataDirectory
    ConvertTo-Json $script:ModuleConfig | Set-Content $Path

    #return $script:ModuleConfig
}
