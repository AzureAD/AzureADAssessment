
function Invoke-AADAssessmentHybridDataCollection {
    [CmdletBinding()]
    param
    (
        # Specify directory to output data. A subdirectory will automatically be created called "AzureADAssessment".
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = $env:SystemDrive
    )

    $OutputDirectory = Join-Path $OutputDirectory "AzureADAssessment"
    $OutputDirectoryData = Join-Path $OutputDirectory "Data"

    ## ADFS Data Collection
    $ADFSService = Get-Service adfssrv -ErrorAction SilentlyContinue
    if ($ADFSService) {
        ## Create Output Directory
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData-ADFS-$env:COMPUTERNAME.zip"
        $OutputDirectoryADFS = Join-Path $OutputDirectoryData 'ADFS'
        if (!(Test-Path $OutputDirectoryADFS)) { New-Item $OutputDirectoryADFS -ItemType Container -ErrorAction Stop }

        ## Get ADFS Properties
        Get-AdfsProperties | Out-File (Join-Path $OutputDirectoryADFS 'ADFSProperties.txt')
        Get-AdfsProperties | ConvertTo-Json | Set-Content (Join-Path $OutputDirectoryADFS 'ADFSProperties.json')

        ## Get ADFS Endpoints
        Get-AADAssessADFSEndpoints | Export-Csv -Path (Join-Path $OutputDirectoryADFS 'ADFSEnabledEndpoints.csv') -NoTypeInformation:$false

        ## Get ADFS Configuration
        Export-AADAssessADFSConfiguration -OutputDirectory $OutputDirectoryADFS

        ## Event Data
        Export-AADAssessADFSAdminLog -OutputDirectory $OutputDirectoryADFS -DaysToRetrieve 15

        ## Package Output
        if ($PSVersionTable.PSVersion -ge [version]'5.0') {
            Compress-Archive (Join-Path $OutputDirectoryADFS '\*') -DestinationPath $PackagePath -Force
        }
        else {
            Add-Type -AssemblyName "System.IO.Compression.FileSystem"
            [System.IO.Compression.ZipFile]::CreateFromDirectory($OutputDirectoryADFS, $PackagePath)
        }
    }

    ## Azure AD Connect Data Collection
    $AADCService = Get-Service ADSync -ErrorAction SilentlyContinue
    if ($AADCService) {
        ## Create Output Directory
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData-AADC-$env:COMPUTERNAME.zip"
        $OutputDirectoryAADC = Join-Path $OutputDirectoryData 'AADC'
        if (!(Test-Path $OutputDirectoryAADC)) { New-Item $OutputDirectoryAADC -ItemType Container -ErrorAction Stop }

        ## AAD Connect Configuration
        Remove-Item (Join-Path $OutputDirectoryAADC 'AzureADConnectSyncConfig') -Recurse -Force -ErrorAction SilentlyContinue
        Get-ADSyncServerConfiguration -Path (Join-Path $OutputDirectoryAADC 'AzureADConnectSyncConfig')

        ## Event Data
        Get-AADAssessPasswordWritebackAgentLog -DaysToRetrieve 7 | Export-Csv -Path (Join-Path $OutputDirectoryAADC "AADPasswriteback-$env:COMPUTERNAME.csv") -NoTypeInformation:$false

        ## Package Output
        if ($PSVersionTable.PSVersion -ge [version]'5.0') {
            Compress-Archive (Join-Path $OutputDirectoryAADC '\*') -DestinationPath $PackagePath -Force
        }
        else {
            Add-Type -AssemblyName "System.IO.Compression.FileSystem"
            [System.IO.Compression.ZipFile]::CreateFromDirectory($OutputDirectoryAADC, $PackagePath)
        }
    }

    ## Azure AD App Proxy Connector Data Collection
    $AADAPService = Get-Service WAPCSvc -ErrorAction SilentlyContinue
    if ($AADAPService) {
        ## Create Output Directory
        $PackagePath = Join-Path $OutputDirectory "AzureADAssessmentData-AADAP-$env:COMPUTERNAME.zip"
        $OutputDirectoryAADAP = Join-Path $OutputDirectoryData 'AADAP'
        if (!(Test-Path $OutputDirectoryAADAP)) { New-Item $OutputDirectoryAADAP -ItemType Container -ErrorAction Stop }

        ## Event Data
        Get-AADAssessAppProxyConnectorLog -DaysToRetrieve 7 | Export-Csv -Path (Join-Path $OutputDirectoryAADAP "AzureADAppProxyConnectorLog-$env:COMPUTERNAME.csv") -NoTypeInformation:$false

        ## Package Output
        if ($PSVersionTable.PSVersion -ge [version]'5.0') {
            Compress-Archive (Join-Path $OutputDirectoryAADAP '\*') -DestinationPath $PackagePath -Force
        }
        else {
            Add-Type -AssemblyName "System.IO.Compression.FileSystem"
            [System.IO.Compression.ZipFile]::CreateFromDirectory($OutputDirectoryAADAP, $PackagePath)
        }
    }
}


<# 
 .Synopsis
  Exports the configuration of Relying Party Trusts and Claims Provider Trusts

 .Description
  Creates and zips a set of files that hold the configuration of AD FS claim providers and relying parties.
  The output files are created under a directory called "ADFS" in the system drive.
 
 .Example
  Export-AADAssessADFSConfiguration
#>
function Export-AADAssessADFSConfiguration {
    [CmdletBinding()]
    param (
        # 
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory
    )

    $filePathBase = Join-Path $OutputDirectory 'apps'
    #$zipfileBase = Join-Path $OutputDirectory 'zip'
    #$zipfileName = Join-Path $zipfileBase "ADFSApps.zip"
    mkdir $filePathBase -ErrorAction SilentlyContinue
    #mkdir $zipfileBase -ErrorAction SilentlyContinue

    $AdfsRelyingPartyTrusts = Get-AdfsRelyingPartyTrust
    foreach ($AdfsRelyingPartyTrust in $AdfsRelyingPartyTrusts) {
        $RPfileName = $AdfsRelyingPartyTrust.Name.ToString()
        $CleanedRPFileName = Remove-InvalidFileNameCharacters $RPfileName
        $RPName = "RPT - " + $CleanedRPFileName
        $filePath = Join-Path $filePathBase ($RPName + '.xml')
        $AdfsRelyingPartyTrust | Export-Clixml -LiteralPath $filePath -ErrorAction SilentlyContinue
    }

    $AdfsClaimsProviderTrusts = Get-AdfsClaimsProviderTrust
    foreach ($AdfsClaimsProviderTrust in $AdfsClaimsProviderTrusts) {
        $CPfileName = $AdfsClaimsProviderTrust.Name.ToString()
        $CleanedCPFileName = Remove-InvalidFileNameCharacters $CPfileName
        $CPTName = "CPT - " + $CleanedCPFileName
        $filePath = Join-Path $filePathBase ($CPTName + '.xml')
        $AdfsClaimsProviderTrust | Export-Clixml -LiteralPath $filePath -ErrorAction SilentlyContinue
    } 

    #If (Test-Path $zipfileName) {
    #    Remove-Item $zipfileName
    #}

    #Add-Type -assembly "system.io.compression.filesystem"
    #[io.compression.zipfile]::CreateFromDirectory($filePathBase, $zipfileName)
    
    #Invoke-Item $zipfileBase
}


<# 
 .Synopsis
  Gets the list of all enabled endpoints in ADFS

 .Description
  Gets the list of all enabled endpoints in ADFS

 .Example
  Get-AADAssessADFSEndpoints | Export-Csv -Path ".\ADFSEnabledEndpoints.csv" 
#>
function Get-AADAssessADFSEndpoints {
    Get-AdfsEndpoint | Where-Object { $_.Enabled -eq "True" }
}


<# 
 .Synopsis
  Gets the AD FS Admin Log

 .Description
  This function exports the events from the AD FS Admin log

 .Example
  Get the last seven days of logs  
  Export-AADAssessADFSAdminLog -DaysToRetrieve 7
#>
function Export-AADAssessADFSAdminLog {
    [CmdletBinding()]
    param
    (
        # 
        [Parameter(Mandatory = $true)]
        [string] $OutputDirectory,
        # Specify how far back in the past will the events be retrieved
        [Parameter(Mandatory = $true)]
        [int] $DaysToRetrieve
    )

    $TimeSpan = New-TimeSpan -Day $DaysToRetrieve
    $XPathQuery = '*[System[TimeCreated[timediff(@SystemTime) <= {0}]]]' -f $TimeSpan.TotalMilliseconds
    #Get-WinEvent -FilterXPath $XPathQuery
    #Get-WinEvent -FilterHashtable @{ LogName = 'AD FS/Admin'; StartTime = ((Get-Date) - $TimeSpan) }
    Export-EventLog -Path (Join-Path $OutputDirectory "ADFS-$env:COMPUTERNAME.evtx") -LogName 'AD FS/Admin' -Query $XPathQuery -Overwrite
}


<# 
 .Synopsis
  Gets Azure AD Application Proxy Connector Logs

 .Description
  This functions returns the events from the Azure AD Application Proxy Connector Admin Log

 .Parameter DaysToRetrieve
  Indicates how far back in the past will the events be retrieved

 .Example

 $targetGalleryApp = "GalleryAppName"
 $targetGroup = Get-AzureADGroup -SearchString "TestGroupName"
 $targetAzureADRole = "TestRoleName"
 $targetADFSRPId = "ADFSRPIdentifier"

  $RP=Get-AdfsRelyingPartyTrust -Identifier $targetADFSRPId
  $galleryApp = Get-AzureADApplicationTemplate -DisplayNameFilter $targetGalleryApp

  $RP=Get-AdfsRelyingPartyTrust -Identifier $targetADFSRPId

  New-AzureADAppFromADFSRPTrust `
    -AzureADAppTemplateId $galleryApp.id `
    -ADFSRelyingPartyTrust $RP `
    -TestGroupAssignmentObjectId $targetGroup.ObjectId `
    -TestGroupAssignmentRoleName $targetAzureADRole
#>
function Get-AADAssessAppProxyConnectorLog {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]
        $DaysToRetrieve
    )

    $TimeFilter = $DaysToRetrieve * 86400000
    $EventFilterXml = '<QueryList><Query Id="0" Path="Microsoft-AadApplicationProxy-Connector/Admin"><Select Path="Microsoft-AadApplicationProxy-Connector/Admin">*[System[TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>' -f $TimeFilter
    Get-WinEvent -FilterXml $EventFilterXml
}


<# 
 .Synopsis
  Gets the Azure AD Password Writeback Agent Log

 .Description
  This functions returns the events from the Azure AD Password Write Bag source from the application Log

 .Parameter DaysToRetrieve
  Indicates how far back in the past will the events be retrieved

 .Example
  Get the last seven days of logs and saves them on a CSV file   
  Get-AADAssessPasswordWritebackAgentLog -DaysToRetrieve 7 | Export-Csv -Path ".\AzureADAppProxyLogs-$env:ComputerName.csv" 
#>
function Get-AADAssessPasswordWritebackAgentLog {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]
        $DaysToRetrieve
    )

    $TimeFilter = $DaysToRetrieve * 86400000
    $EventFilterXml = "<QueryList><Query Id='0' Path='Application'><Select Path='Application'>*[System[Provider[@Name='PasswordResetService'] and TimeCreated[timediff(@SystemTime) &lt;= {0}]]]</Select></Query></QueryList>" -f $TimeFilter
    Get-WinEvent -FilterXml $EventFilterXml
}



### ==================
###  Helper Functions
### ==================

<#
.SYNOPSIS
    Decompose characters to their base character equivilents and remove diacritics.
.DESCRIPTION

.EXAMPLE
    PS C:\>Remove-Diacritics 'àáâãäåÀÁÂÃÄÅﬁ⁵ẛ'
    Decompose characters to their base character equivilents and remove diacritics.
.EXAMPLE
    PS C:\>Remove-Diacritics 'àáâãäåÀÁÂÃÄÅﬁ⁵ẛ' -CompatibilityDecomposition
    Decompose composite characters to their base character equivilents and remove diacritics.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Remove-Diacritics {
    [CmdletBinding()]
    param
    (
        # String value to transform.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string[]] $InputStrings,
        # Use compatibility decomposition instead of canonical decomposition which further decomposes composite characters and many formatting distinctions are removed.
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [switch] $CompatibilityDecomposition
    )

    process {
        [System.Text.NormalizationForm] $NormalizationForm = [System.Text.NormalizationForm]::FormD
        if ($CompatibilityDecomposition) { $NormalizationForm = [System.Text.NormalizationForm]::FormKD }
        foreach ($InputString in $InputStrings) {
            $NormalizedString = $InputString.Normalize($NormalizationForm)
            $OutputString = New-Object System.Text.StringBuilder

            foreach ($char in $NormalizedString.ToCharArray()) {
                if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($char) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
                    [void] $OutputString.Append($char)
                }
            }

            Write-Output $OutputString.ToString()
        }
    }
}


<#
.SYNOPSIS
    Remove invalid filename characters from string.
.DESCRIPTION

.EXAMPLE
    PS C:\>Remove-InvalidFileNameCharacters 'à/1\b?2|ć*3<đ>4 ē'
    Remove invalid filename characters from string.
.EXAMPLE
    PS C:\>Remove-InvalidFileNameCharacters 'à/1\b?2|ć*3<đ>4 ē' -RemoveDiacritics
    Remove invalid filename characters and diacritics from string.
.INPUTS
    System.String
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Remove-InvalidFileNameCharacters {
    [CmdletBinding()]
    param
    (
        # String value to transform.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyString()]
        [string[]] $InputStrings,
        # Character used as replacement for invalid characters. Use '' to simply remove.
        [Parameter(Mandatory = $false)]
        [string] $ReplacementCharacter = '-',
        # Replace characters with diacritics to their non-diacritic equivilent.
        [Parameter(Mandatory = $false)]
        [switch] $RemoveDiacritics
    )

    process {
        foreach ($InputString in $InputStrings) {
            [string] $OutputString = $InputString
            if ($RemoveDiacritics) { $OutputString = Remove-Diacritics $OutputString -CompatibilityDecomposition }
            $OutputString = [regex]::Replace($OutputString, ('[{0}]' -f [regex]::Escape([System.IO.Path]::GetInvalidFileNameChars() -join '')), $ReplacementCharacter)
            Write-Output $OutputString
        }
    }
}


<#
.SYNOPSIS
    Exports events from an event log.
.DESCRIPTION

.EXAMPLE
    PS C:\>Export-EventLog 'C:\ADFS-Admin.evtx' -LogName 'AD FS/Admin'
    Export all logs from "AD FS/Admin" event log.
.INPUTS
    System.String
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


Export-ModuleMember Invoke-AADAssessmentHybridDataCollection
Export-ModuleMember Export-AADAssessADFSConfiguration
Export-ModuleMember Get-AADAssessADFSEndpoints
Export-ModuleMember Export-AADAssessADFSAdminLog
Export-ModuleMember Get-AADAssessAppProxyConnectorLog
Export-ModuleMember Get-AADAssessPasswordWritebackAgentLog
