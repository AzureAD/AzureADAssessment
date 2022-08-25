<#
.SYNOPSIS
    Export a portable assessment module that can be copied to servers for data collection.
.EXAMPLE
    PS C:\> Export-AADAssessmentPortableModule "c:\temp\contoso"
    Exports the module file to "c:\temp\contoso".
#>
function Export-AADAssessmentPortableModule {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        # Directory to output portable module
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name
    try {

        ## Copy AAD Assessment Portable Module
        $ModulePath = Join-Path $MyInvocation.MyCommand.Module.ModuleBase 'AzureADAssessmentPortable.psm1'
        Copy-Item $ModulePath -Destination $OutputDirectory -Force -PassThru

        ## Download and Save ADFSAADMigrationUtils Module
        #$AdfsAadMigrationModulePath = Join-Path $OutputDirectory 'ADFSAADMigrationUtils.psm1'
        #Invoke-WebRequest -Uri 'https://github.com/AzureAD/Deployment-Plans/raw/master/ADFS%20to%20AzureAD%20App%20Migration/ADFSAADMigrationUtils.psm1' -UseBasicParsing -OutFile $AdfsAadMigrationModulePath

    }
    catch { if ($MyInvocation.CommandOrigin -eq 'Runspace') { Write-AppInsightsException -ErrorRecord $_ }; throw }
    finally { Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $? }
}
