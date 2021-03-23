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
        [timespan] $MinimumUpdateFrequency = (New-TimeSpan -Seconds 1)
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
        $stackProgressId.Push($Id)

        try {
            [System.Diagnostics.Stopwatch] $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            for ($iObject = 0; $iObject -lt $total; $iObject++) {
                if ($iObject -eq 0 -or ($stopwatch.Elapsed - $TimeElapsed) -gt $MinimumUpdateFrequency) {
                    [timespan] $TimeElapsed = $stopwatch.Elapsed
                    $PercentComplete = [System.Math]::Truncate([decimal]($iObject / $total * 100))
                    if ($PercentComplete -gt 0) { $SecondsRemaining = $TimeElapsed.TotalSeconds / $PercentComplete - $TimeElapsed.TotalSeconds }
                    if ($Property) { $CurrentOperation = $InputObjects[$iObject].$Property }
                    else { $CurrentOperation = $InputObjects[$iObject] }
                    Write-Progress -CurrentOperation $CurrentOperation -Status ("{0:P0} Completed ({1} of {2}) in {3:c}" -f ($PercentComplete / 100), $iObject, $total, $TimeElapsed.Subtract($TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) -PercentComplete $PercentComplete -SecondsRemaining $SecondsRemaining @paramWriteProgress
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

function Start-Progress {
    [CmdletBinding()]
    param (
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string] $Activity,
        # Total Number of Items
        [Parameter(Mandatory = $true)]
        [int] $Total,
        # Minimum timespan between each progress update.
        [Parameter(Mandatory = $false)]
        [timespan] $MinimumUpdateFrequency = (New-TimeSpan -Seconds 1)
    )

    [int] $Id = 0
    if (!(Get-Variable stackProgressId -ErrorAction SilentlyContinue)) { New-Variable -Name stackProgressId -Scope Script -Value (New-Object System.Collections.Generic.Stack[int]) }
    while ($stackProgressId.Contains($Id)) { $Id += 1 }

    [hashtable] $paramWriteProgress = @{
        Id = $Id
        Activity = $Activity
    }
    if ($stackProgressId.Count -gt 0) { $paramWriteProgress['ParentId'] = $stackProgressId.Peek() }
    $stackProgressId.Push($Id)

    ## Progress Bar
    [timespan] $TimeElapsed = New-TimeSpan
    Write-Progress -Status ("{0:P0} Completed ({1} of {2}) in {3:c}" -f 0, 0, $Total, $TimeElapsed) -PercentComplete 0 @paramWriteProgress

    [PSCustomObject]@{
        WriteProgressParameters = $paramWriteProgress
        CurrentIteration        = 0
        Total                   = $Total
        MinimumUpdateFrequency  = $MinimumUpdateFrequency
        TimeElapsed             = $TimeElapsed
        Stopwatch               = [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Update-Progress {
    [CmdletBinding()]
    param (
        # Progress State Object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObject,
        # Number of items being completed
        [Parameter(Mandatory = $true)]
        [int] $IncrementBy,
        # Specifies the line of text below the progress bar. This text describes the operation that is currently taking place.
        [Parameter(Mandatory = $false)]
        [string] $CurrentOperation
    )

    if ($InputObject.CurrentIteration -gt $InputObject.Total) { $InputObject.CurrentIteration = $InputObject.Total }

    [hashtable] $paramWriteProgress = $InputObject.WriteProgressParameters
    if ($CurrentOperation) { $paramWriteProgress['CurrentOperation'] = $CurrentOperation }
    [int] $SecondsRemaining = -1

    ## Progress Bar
    if ($InputObject.CurrentIteration -eq 0 -or ($InputObject.Stopwatch.Elapsed - $InputObject.TimeElapsed) -gt $InputObject.MinimumUpdateFrequency) {
        $InputObject.TimeElapsed = $InputObject.Stopwatch.Elapsed
        $PercentComplete = $InputObject.CurrentIteration / $InputObject.Total
        $PercentCompleteRoundDown = [System.Math]::Truncate([decimal]($PercentComplete * 100))
        if ($PercentComplete -gt 0) { $SecondsRemaining = $InputObject.TimeElapsed.TotalSeconds / $PercentComplete - $InputObject.TimeElapsed.TotalSeconds }
        Write-Progress -Status ("{0:P0} Completed ({1} of {2}) in {3:c}" -f ($PercentCompleteRoundDown / 100), $InputObject.CurrentIteration, $InputObject.Total, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) -PercentComplete $PercentCompleteRoundDown -SecondsRemaining $SecondsRemaining @paramWriteProgress
    }

    $InputObject.CurrentIteration += $IncrementBy
}

function Stop-Progress {
    [CmdletBinding()]
    param (
        # Progress State Object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [object] $InputObject
    )

    [void] $script:stackProgressId.Pop()
    $InputObject.Stopwatch.Stop()
    [hashtable] $paramWriteProgress = $InputObject.WriteProgressParameters
    Write-Progress -Completed @paramWriteProgress
}
