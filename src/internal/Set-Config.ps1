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
    #[OutputType([psobject])]
    param (
        # Configuration Object
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        # Application Insights Telemetry Disabled
        [Parameter(Mandatory = $false)]
        [bool] $AIDisabled,
        # Application Insights Instrumentation Key
        [Parameter(Mandatory = $false)]
        [string] $AIInstrumentationKey,
        # Application Insights Ingestion Endpoint
        [Parameter(Mandatory = $false)]
        [string] $AIIngestionEndpoint,
        # Variable to output config
        [Parameter(Mandatory = $false)]
        [ref] $OutConfig = ([ref]$script:ModuleConfig)
    )

    ## Update local configuration
    if ($InputObject) {
        if ($InputObject -is [hashtable]) { $InputObject = [PSCustomObject]$InputObject }
        foreach ($Property in $InputObject.psobject.Properties) {
            if ($OutConfig.Value.psobject.Properties.Name -contains $Property.Name) {
                $OutConfig.Value.($Property.Name) = $Property.Value
            }
            else {
                Write-Warning ('Ignoring invalid configuration property [{0}].' -f $Property.Name)
            }
        }
    }
    if ($PSBoundParameters.ContainsKey('AIDisabled')) { $OutConfig.Value.'ai.disabled' = $AIDisabled }
    if ($PSBoundParameters.ContainsKey('AIInstrumentationKey')) { $OutConfig.Value.'ai.instrumentationKey' = $AIInstrumentationKey }
    if ($PSBoundParameters.ContainsKey('AIIngestionEndpoint')) { $OutConfig.Value.'ai.ingestionEndpoint' = $AIIngestionEndpoint }

    ## Return updated local configuration
    #return $OutConfig.Value
}
