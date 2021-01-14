<#
.SYNOPSIS
    Display progress bar for processing array of objects.
.EXAMPLE
    PS C:\>Use-Progress -InputObjects @(1..10) -Activity "Processing Parent Objects" -ScriptBlock {
        $Parent = $args[0]
        Use-Progress -InputObjects @(1..200) -Activity "Processing Child Objects" -ScriptBlock {
            $Child = $args[0]
            Write-Host "Child $Child of Parent $Parent."
            Start-Sleep -Milliseconds 50
        }
    }
    Display progress bar for processing array of objects.
.INPUTS
    System.Object[]
.LINK
    https://github.com/jasoth/Utility.PS
#>
function Use-Progress {
    [CmdletBinding()]
    param
    (
        # Array of objects to loop through.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]] $InputObjects,
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string] $Activity,
        # Script block to execute for each object in array.
        [Parameter(Mandatory = $true)]
        [scriptblock] $ScriptBlock,
        # Property name to use for current operation
        [Parameter(Mandatory = $false)]
        [string] $Property,
        # Minimum timespan between each progress update.
        [Parameter(Mandatory = $false)]
        [timespan] $MinimumUpdateFrequency = (New-Timespan -Seconds 1)
    )

    begin {
        [System.Collections.Generic.List[object]] $listObjects = New-Object System.Collections.Generic.List[object]
    }

    process {
        $listObjects.AddRange($InputObjects)
    }

    end {
        if ($listObjects.Count -gt 0) { [object[]] $InputObjects = $listObjects.ToArray() }
        [int] $Id = 0
        if (!(Get-Variable stackProgressId -ErrorAction SilentlyContinue)) { New-Variable -Name stackProgressId -Scope Script -Value (New-Object System.Collections.Generic.Stack[int]) }
        while ($stackProgressId.Contains($Id)) { $Id += 1 }
        [hashtable] $paramWriteProgress = @{
            Id       = $Id
            Activity = $Activity
        }
        if ($stackProgressId.Count -gt 0) { $paramWriteProgress['ParentId'] = $stackProgressId.Peek() }
        [int] $SecondsRemaining = -1
        [int] $total = $InputObjects.Count

        try {
            $stackProgressId.Push($Id)
            [System.Diagnostics.Stopwatch] $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($iObject = 0; $iObject -lt $total; $iObject++) {
                if ($iObject -eq 0 -or ($stopwatch.Elapsed - $TimeElapsed) -gt $MinimumUpdateFrequency) {
                    [timespan] $TimeElapsed = $stopwatch.Elapsed
                    $PercentComplete = $iObject / $total
                    if ($PercentComplete -gt 0) { $SecondsRemaining = $TimeElapsed.TotalSeconds / $PercentComplete - $TimeElapsed.TotalSeconds }
                    if ($Property) { $CurrentOperation = $InputObjects[$iObject].$Property }
                    else { $CurrentOperation = $InputObjects[$iObject] }
                    Write-Progress -CurrentOperation $CurrentOperation -Status ("{0:P0} Completed ({1} of {2}) in {3:c}" -f $PercentComplete, $iObject, $total, $TimeElapsed.Subtract($TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) -PercentComplete ($PercentComplete * 100) -SecondsRemaining $SecondsRemaining @paramWriteProgress
                }
                Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $InputObjects[$iObject]
            }
            $stopwatch.Stop()
            Write-Progress -Status ("{0:P0} Completed ({1} of {2}) in {3:c}" -f 1, $total, $total, $TimeElapsed.Subtract($TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) -PercentComplete 100 -SecondsRemaining 0 @paramWriteProgress
        }
        finally {
            [void] $stackProgressId.Pop()
            #Start-Sleep -Seconds 1
            Write-Progress -Id $Id -Activity $Activity -Completed
        }
    }
}
