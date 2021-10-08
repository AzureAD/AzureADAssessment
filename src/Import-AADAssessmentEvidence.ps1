
<#
.SYNOPSIS
    Import evidence from the assessment data
.PARAMETER Ref
    Refence of the file to look for. Composed of the package type (Tenant, AADC, ADFS, AADP) followed by the file name separated by a "/"
.PARAMETER Path
    Path where to look for packages with data collected
.DESCRIPTION
    This cmdlet reads data collected from package (zip) and caches it in memory
    Reference indicates witch file to load from which kind of package (Tenant, AADC, ADFS, AADAP)
.EXAMPLE
    PS C:\> Import-AADAssessmentEvidence -Ref "Tenant/conditionalAccessPolicies.json"
    Reads conditional access policies from packages located in "C:\AzureADAssessment"
.EXAMPLE
    PS C:\> New-AADAssessmentRecommendations -Path "C:\Temp" -Ref "Tenant/conditionalAccessPolicies.json"
    Reads conditional access policies from packages located in "C:\Temp"
#>
function Import-AADAssessmentEvidence {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true, 
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true
        )]
        [string] $Ref,
        # Full path of the directory where the output files will be generated.
        [Parameter(Mandatory = $false)]
        [string] $Path = (Join-Path $env:SystemDrive 'AzureADAssessment')
    )

    process {
        # check that reference is in a correct format
        $refInfo = $Ref -split "/"
        if ($refInfo.Length -ne 2) {
            throw "invalid evidence reference $Ref"
        }

        # determine whare to look for the file
        $component = $refInfo[0]
        $relativeFolder = ""
        $zipFile = ""
        Switch ($refInfo[0]) {
            "Tenant" {
                $relativeFolder = "AAD-*.onmicrosoft.com"
                $zipFile = "AzureADAssessmentData-*.onmicrosoft.com.zip"
            }
            "AADC" {
                $relativeFolder = "AADC" 
                $zipFile = "AzureADAssessmentData-AADC-*.zip"
            }
            "ADFS" {
                $relativeFolder = "ADFS"
                $zipFile = "AzureADAssessmentData-ADFS-*.zip"
            }
            "AADAP" {
                $relativeFolder = "AADAP"
                $zipFile = "AzureADAssessmentData-AADAP-*.zip"
            }
            default {
                throw "unknown evidence component $($refInfo[0])"
            }
        }

        # determine filename
        $fileName = $refInfo[1]
        # skip if file type not supported
        if ($fileName -inotmatch "\.(csv|json|xml)$") {
            return
        }

        # get the path to the evidence archive
        $zipPath = Join-Path $Path $zipFile
        Add-Type -assembly "system.io.compression.filesystem"

        # resolve the file
        Write-Verbose "searching zips: $zipPath"
        $foundZipFiles = Get-ChildItem -Path $zipPath
        foreach($foundZipFile in $foundZipFiles) {
            # get the environement (tenant name or server name)
            $envName = $foundZipFile -replace ".zip$","" -replace "^AzureADAssessmentData*-",""
            # initialize env infos
            if (!$script:Evidences[$component].ContainsKey($envName)) {
                $script:Evidences[$component][$envName] = @{}
            }
            # check if file loaded
            if ($script:Evidences[$component][$envName].ContainsKey($fileName)) {
                Write-Verbose "$component/$envName/$fileName already loaded"
                return
            } 
            # read the zip file and extract desired evidence
            Write-Verbose "Opening zip file: $foundZipFile"
            $zip = [io.compression.zipfile]::OpenRead($foundZipFile)
            # get the files to read
            $toRead = @()
            foreach($entry in $zip.Entries) {
                if (($entry -like "$relativeFolder\$fileName") -or ($entry -like "$relativeFolder/$fileName")) {
                    $toRead += $entry
                }
            }
            foreach($zipEntry in $toRead) {
                Write-Verbose "Reading $zipEntry"
                $file = $zipEntry.Open()
                $reader = New-Object IO.StreamReader($file)
                switch -Wildcard ($zipEntry.Name) {
                    "*.json" {
                        $script:Evidences[$component][$envName][$fileName] = $reader.ReadToEnd() | ConvertFrom-Json
                    }
                    "*.csv" {
                        $script:Evidences[$component][$envName][$fileName] = $reader.ReadToEnd() | ConvertFrom-Csv
                    }
                    "*.xml" {
                        $script:Evidences[$component][$envName][$fileName] = [System.Xml.Serialization]::Deserialize($read) 
                    }
                }
                $reader.Close()
                $file.Close()
            }
            $zip.Dispose()
        }
    }
}