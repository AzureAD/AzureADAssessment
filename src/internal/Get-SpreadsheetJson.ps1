<#
.SYNOPSIS
    Reads all the named ranges in a spreadsheet and returns them as a name value pair
.EXAMPLE
    PS C:\>$object = Get-SpreadsheetJson -SpreadsheetFilePath './InterviewQuestions.xlsx'
    Gets all the named key value pairs in the spreadsheet.
.INPUTS
    string
#>
function Get-SpreadsheetJson {
    [CmdletBinding()]
    [OutputType([psobject])]
    param (
        # Object containing property values
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [string] $SpreadsheetFilePath
    )

    process {
        if(!(Test-Path $SpreadsheetFilePath)){
            Write-Error "File not found at $SpreadsheetFilePath"
            return
        }

        $tempFolder = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'AADAssess') ([guid]::NewGuid())
        if (!(Test-Path $tempFolder)) {
            New-Item $tempFolder -ItemType Directory | Out-Null
        }
        #$tempFolder = ".\temp\"
        #Remove-Item ./temp/  -Recurse -Force


        # move the excel in temp as zip (to be able to expand it)
        Copy-Item -Path $SpreadsheetFilePath -Destination (Join-Path $tempFolder "AzureADAssessment-interview-xlsx.zip")
        Expand-Archive -Path (Join-Path $tempFolder "AzureADAssessment-interview-xlsx.zip") -DestinationPath $tempFolder
        
        $wbFilePath = Join-Path (Join-Path $tempFolder 'xl') 'workbook.xml'
        $sheetFilePath = Join-Path (Join-Path $tempFolder 'xl') 'worksheets'
        $ssFilePath = Join-Path (Join-Path $tempFolder 'xl') 'sharedStrings.xml'
        [xml]$xmlWb = Get-Content $wbFilePath
        [xml]$ss = Get-Content $ssFilePath
        
        $xmlWorksheets = @{}
        $sheetIndex = 1
        foreach ($ws in $xmlWb.workbook.sheets.ChildNodes) {
            $wsFilePath = Join-Path $sheetFilePath "sheet$($sheetIndex).xml"
            [xml]$xmlWs = Get-Content $wsFilePath
            $xmlWorksheets[$ws.name] = $xmlWs
            $sheetIndex = $sheetIndex + 1
        }
        Remove-Item -Path $tempFolder -Recurse -Force #Clean up

        $nrValues = @{}
        foreach($nr in $xmlWb.workbook.definedNames.ChildNodes){
            $name = $nr.name
            $range = $nr.InnerText

            $nrValue = [PSCustomObject]@{
                Name = $name
                Range = $range
                Value = ''
            }
            $nrValues[$name] = $nrValue
        
            $rangeValue = $range -Split '!'
            $sheet = $rangeValue[0].Replace("'", "")
            $cell = $rangeValue[1] -Replace '\$',''
        
            if($xmlWorksheets[$sheet]){
                $c = Select-Xml -Xml $xmlWorksheets[$sheet] -XPath "//*[@r='$cell']"
                $node = Get-ObjectPropertyValue $c 'Node'
                if($node){
                    $type = Get-ObjectPropertyValue $node 't'
                    $innerText = $c.Node.InnerText

                    #Write-Host $name $range $c.Node.InnerText $type
                    switch ($type) {
                        's' {   #String format
                            if($innerText -and $ss.sst.si[$innerText]){
                                $nrValue.Value = $ss.sst.si[$innerText].InnerText
                            }
                            else {
                                #Write-Host "No value in cell: $range"
                            }
                        }
                        Default {
                            # Integer
                            $nrValue.Value = $innerText
                        }
                    }
                }
            }
            else {
                #Write-Host "Sheet not found: $sheet"
            }
        }
        Write-Output $nrValues
    }
}
