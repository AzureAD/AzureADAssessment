<#
.SYNOPSIS
    Produces the Azure AD Assessment recommendations from collected data.
.DESCRIPTION
    This cmdlet reads data collected and generates recommendations accordingly.
.EXAMPLE
    PS C:\> New-AADAssessmentRecommendations
    Collect and package assessment data from "C:\AzureADAssessment" and generate recommendations in the same folder.
.EXAMPLE
    PS C:\> New-AADAssessmentRecommendations -OutputDirectory "C:\Temp"
    Collect and package assessment data from "C:\Temp" and generate recommendations in the same folder.
#>

function New-AADAssessmentRecommendations {
    [CmdletBinding()]
    param (
        # Specifies a path where extracted data resides (folder)
        [Parameter(Mandatory = $false)]
        [string] $Path = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        # Full path of the directory where the output files will be copied.
        [Parameter(Mandatory = $false)]
        [string] $OutputDirectory = (Join-Path $env:SystemDrive 'AzureADAssessment'),
        [Parameter(Mandatory = $false)]
        [switch] $SkipExpand = $false,
        # Path to the spreadsheet with the interview answers
        [Parameter(Mandatory = $false)]
        [string] $InterviewSpreadsheetPath
    )

    Start-AppInsightsRequest $MyInvocation.MyCommand.Name

    ## Expand extracted data
    if (-not $SkipExpand) {
        $Archives = Get-ChildItem -Path $Path | Where-Object {$_.Name -like "AzureADAssessmentData-*.zip" }
        $ExtractedDirectories = @()
        foreach($Archive in $Archives) {
            $OutputDirectoryData = Join-Path $OutputDirectory ([IO.Path]::GetFileNameWithoutExtension($Archive.Name))
            Expand-Archive -Path $Archive.FullName -DestinationPath $OutputDirectoryData -Force -ErrorAction Stop
            $ExtractedDirectories += $OutputDirectoryData
        }
    }

    ## Determine folder contents
    $TenantDirectoryData = $null
    $AADCDirecotryData = @()
    $ADFSDirectoryData = @()
    $AADAPDirectoryData = @()
    foreach($Directory in Get-ChildItem -Path $Path -Directory) {
        Switch -Wildcard ($Directory.Name) {
            "AzureADAssessmentData-*.onmicrosoft.com" {
                $TenantDirectoryData = $Directory.FullName
            }
            "AzureADAssessmentData-AADC-*" {
                $AADCDirecotryData += $Directory.FullName
            }
            "AzureADAssessmentData-ADFS-*" {
                $ADFSDirectoryData += $Directory.FullName
            }
            "AzureADAssessmentData-AADAP-*" {
                $AADAPDirectoryData += $Directory.FullName
            }
            default {
                Write-Warning "Unrecognized directory $($Directory.Name)"
            }
        }
    }

    # Generate recommendations from tenant data
    if (![String]::IsNullOrWhiteSpace($TenantDirectoryData)) {
        $data = @{}
        ### Load all the data on AAD

        # Load Interview questions
        if($null -ne $InterviewSpreadsheetPath){
            $interviewQna = Get-SpreadsheetJson $InterviewSpreadsheetPath
            $interviewQnaPath = Join-Path $TenantDirectoryData "QnA.json"
            $interviewQna | ConvertTo-Json | Out-File $interviewQnaPath
            $data['QnA.json'] = $interviewQna
        }
        
        # Prepare paths
        $AssessmentDetailPath = Join-Path $TenantDirectoryData "AzureADAssessment.json"
        # Read assessment data
        $AssessmentDetail = Get-Content $AssessmentDetailPath -Raw | ConvertFrom-Json
        # Generate AAD data path
        $AADPath = Join-Path $TenantDirectoryData "AAD-$($AssessmentDetail.AssessmentTenantDomain)"
        
        <# do not load file before hand but only when necessary
        $files = get-childitem -Path $AADPath -File
        foreach($file in $files) {
            switch -Wildcard ($file.Name) {
                "*.json" {
                    $data[$file.Name] = get-content -Path $file.FullName | ConvertFrom-Json
                }
                "*.csv" {
                    $data[$file.Name] = Import-Csv -Path $file.FullName
                }
                "*.xml" {
                    $data[$file.Name] = Import-Clixml -Path $file.FullName
                }
                default {
                    Write-Warning "Unsupported data file format: $($file.Name)"
                }
            }
        }#>
        ### Load configuration file
        $recommendations = Select-Xml -Path (Join-Path $PSScriptRoot "AADRecommendations.xml") -XPath "/recommendations"
        $recommendationList = @()
        $idUniqueCheck = @{} # Hashtable to validate that IDs are unique
        foreach($recommendationDef in $recommendations.Node.recommendation) {

            if($idUniqueCheck.ContainsKey($recommendationDef.ID)){
                Write-Error "Found duplicate recommendation $($recommendationDef.ID)"
            }
            else {
                $idUniqueCheck.Add($recommendationDef.ID, $recommendationDef.ID)
            }

            if(Get-ObjectPropertyValue $recommendationDef 'Sources'){
                # make sure necessary files are loaded
                $fileMissing = $false
                foreach($fileName in $recommendationDef.Sources.File) {
                    $filePath = Join-Path $AADPath $fileName
                    if (!(Test-Path -Path $filePath)) {
                        Write-Warning "File not found: $filePath"
                        $fileMissing = $true
                        break
                    }
                    if ($fileName -in $data.Keys) {
                        continue
                    }
                    switch -Wildcard ($fileName) {
                        "*.json" {
                            $data[$fileName] = get-content -Path $filePath | ConvertFrom-Json
                        }
                        "*.csv" {
                            $data[$fileName] = Import-Csv -Path $filePath
                        }
                        "*.xml" {
                            $data[$fileName] = Import-Clixml -Path $filePath
                        }
                        default {
                            Write-Warning "Unsupported data file format: $($fileName)"
                        }
                    }
                }
                if ($fileMissing) {
                    write-warning "A necessary file is missing"
                    continue
                }
            }

            $recommendation = $recommendationDef | select-object ID,Category,Area,Name,Summary,Recommendation,Priority,Data,SortOrder
            
            # Manual checks won't have a PowerShell script to run
            if(Get-ObjectPropertyValue $recommendationDef 'PowerShell'){
                $scriptblock = [Scriptblock]::Create($recommendationDef.PowerShell)
                $result = Invoke-Command -ScriptBlock $scriptblock -ArgumentList $Data
                $recommendation.Priority = $result.Priority
                $recommendation.Data = $result.Data    
            }
            else {
                if((Get-ObjectPropertyValue $recommendationDef 'Type') -eq 'QnA'){
                    Set-TypeQnAResult $data $recommendationDef $recommendation
                }
    
            }
            Set-SortOrder $recommendation
            $recommendationList += $recommendation
        }

        
        #Set-Content -Value ($idUniqueCheck.GetEnumerator()  | Sort-Object name | Select-Object name) -Path ./log.txt
        #Write-Output "Total checks: $($idUniqueCheck.Count)"

        Write-Output "Completed $($recommendationList.Length) checks."

        Write-Verbose "Writing recommendations"
        Write-RecommendationsReport $data $recommendationList
        Write-Verbose "Recommendations written"

        # generate Trusted network locations
        #Get-TrustedNetworksRecommendation -Path $TenantDirectoryData
    } else {
        Write-Error "No Tenant Data found"
    }

    Complete-AppInsightsRequest $MyInvocation.MyCommand.Name -Success $?
}

function Set-TypeQnAResult($data, $recommendationDef, $recommendation){

    $qnaData = $data['QnA.json']
    
    $qnaReco = Get-ObjectPropertyValue $recommendationDef 'QnA'
    $namedRange = Get-ObjectPropertyValue $qnaReco 'Name'
    
    $userValue = Get-ObjectPropertyValue $qnaData[$namedRange] 'Value'
    switch ($userValue) {
        '' { $recommendation.Priority = "Not Answered" }
        'Not Applicable' { $recommendation.Priority = "N/A" }
        Default {
            foreach($answer in $qnaReco.Answers.Answer){
                if($userValue -eq $answer.Value){
                    $recommendation.Priority = $answer.Priority
                }
            }    
        }
    }
}