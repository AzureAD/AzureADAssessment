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

        $tempFolder = Join-Path ([IO.Path]::GetTempPath()) 'AADAssess' ([guid]::NewGuid())
        #$tempFolder = ".\temp\"
        #Remove-Item ./temp/  -Recurse -Force

        Expand-Archive -Path $SpreadsheetFilePath -DestinationPath $tempFolder
        
        $wbFilePath = Join-Path $tempFolder 'xl' 'workbook.xml'
        $sheetFilePath = Join-Path $tempFolder 'xl' 'worksheets'
        $ssFilePath = Join-Path $tempFolder 'xl' 'sharedStrings.xml'
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
                    $ssIndex = $c.Node.InnerText
                    if($ssIndex -and $ss.sst.si[$ssIndex]){
                        $nrValue.Value = $ss.sst.si[$ssIndex].InnerText
                    }
                    else {
                        #Write-Host "No value in cell: $range"
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
