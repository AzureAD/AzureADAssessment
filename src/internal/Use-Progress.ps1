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
    Adapted from: https://github.com/jasoth/Utility.PS
#>
function Use-Progress {
    [CmdletBinding()]
    param
    (
        # Array of objects to loop through.
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [psobject[]] $InputObjects,
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string] $Activity,
        # Total Number of Items
        [Parameter(Mandatory = $false)]
        [int] $Total,
        # Script block to execute for each object in array.
        [Parameter(Mandatory = $false)]
        [scriptblock] $ScriptBlock,
        # Property name to use for current operation
        [Parameter(Mandatory = $false)]
        [string] $Property,
        # Minimum timespan between each progress update.
        [Parameter(Mandatory = $false)]
        [timespan] $MinimumUpdateFrequency = (New-TimeSpan -Seconds 1),
        # Output input objects as they are processed.
        [Parameter(Mandatory = $false)]
        [switch] $PassThru,
        # Write summary to host
        [Parameter(Mandatory = $false)]
        [switch] $WriteSummary
    )

    begin {
        if (!$Total -and $InputObjects) { $Total = $InputObjects.Count }
        $ProgressState = Start-Progress -Activity $Activity -Total $Total -MinimumUpdateFrequency $MinimumUpdateFrequency
    }

    process {
        try {
            foreach ($InputObject in $InputObjects) {
                if ($Property) { $CurrentOperation = $InputObject.$Property }
                else { $CurrentOperation = $InputObject }
                Update-Progress $ProgressState -IncrementBy 1 -CurrentOperation $CurrentOperation
                if ($ScriptBlock) {
                    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $InputObject
                }
                if ($PassThru) { $InputObject }
            }
        }
        catch {
            Stop-Progress $ProgressState
            throw
        }
    }

    end {
        Stop-Progress $ProgressState -WriteSummary:$WriteSummary
    }
}

function Start-Progress {
    [CmdletBinding()]
    param (
        # Specifies the first line of text in the heading above the status bar. This text describes the activity whose progress is being reported.
        [Parameter(Mandatory = $true)]
        [string] $Activity,
        # Total Number of Items
        [Parameter(Mandatory = $false)]
        [int] $Total,
        # Minimum timespan between each progress update.
        [Parameter(Mandatory = $false)]
        [timespan] $MinimumUpdateFrequency = (New-TimeSpan -Seconds 1)
    )

    [int] $Id = 0
    if (!(Get-Variable stackProgressId -Scope Script -ErrorAction Ignore)) { New-Variable -Name stackProgressId -Scope Script -Value (New-Object System.Collections.Generic.Stack[int]) }
    while ($stackProgressId.Contains($Id)) { $Id += 1 }

    [hashtable] $paramWriteProgress = @{
        Id = $Id
        Activity = $Activity
    }
    if ($stackProgressId.Count -gt 0) { $paramWriteProgress['ParentId'] = $stackProgressId.Peek() }
    $stackProgressId.Push($Id)

    ## Progress Bar
    [timespan] $TimeElapsed = New-TimeSpan
    if ($Total) {
        Write-Progress -Status ("{0:P0} Completed ({1:N0} of {2:N0}) in {3:c}" -f 0, 0, $Total, $TimeElapsed) -PercentComplete 0 @paramWriteProgress
    }
    # else {
    #     Write-Progress -Status ("Completed {0} in {1:c}" -f 0, $TimeElapsed) @paramWriteProgress
    # }

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
        [psobject] $InputObject,
        # Number of items being completed
        [Parameter(Mandatory = $true)]
        [int] $IncrementBy,
        # Specifies the line of text below the progress bar. This text describes the operation that is currently taking place.
        [Parameter(Mandatory = $false)]
        [string] $CurrentOperation
    )

    if ($InputObject.Total -gt 0 -and $InputObject.CurrentIteration -ge $InputObject.Total) { $InputObject.Total = $InputObject.CurrentIteration + $IncrementBy }

    [hashtable] $paramWriteProgress = $InputObject.WriteProgressParameters
    if ($CurrentOperation) { $paramWriteProgress['CurrentOperation'] = $CurrentOperation }

    ## Progress Bar
    if ($InputObject.CurrentIteration -eq 0 -or ($InputObject.Stopwatch.Elapsed - $InputObject.TimeElapsed) -gt $InputObject.MinimumUpdateFrequency) {
        $InputObject.TimeElapsed = $InputObject.Stopwatch.Elapsed
        if ($InputObject.Total -gt 0) {
            [int] $SecondsRemaining = -1
            $PercentComplete = $InputObject.CurrentIteration / $InputObject.Total
            $PercentCompleteRoundDown = [System.Math]::Truncate([decimal]($PercentComplete * 100))
            if ($PercentComplete -gt 0) { $SecondsRemaining = $InputObject.TimeElapsed.TotalSeconds / $PercentComplete - $InputObject.TimeElapsed.TotalSeconds }
            Write-Progress -Status ("{0:P0} Completed ({1:N0} of {2:N0}) in {3:c}" -f ($PercentCompleteRoundDown / 100), $InputObject.CurrentIteration, $InputObject.Total, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) -PercentComplete $PercentCompleteRoundDown -SecondsRemaining $SecondsRemaining @paramWriteProgress
        }
        elseif ($InputObject.TimeElapsed.TotalSeconds -gt 0 -and ($InputObject.CurrentIteration / $InputObject.TimeElapsed.TotalSeconds) -ge 1) {
            Write-Progress -Status ("Completed {0:N0} in {1:c} ({2:N0}/sec)" -f $InputObject.CurrentIteration, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond), ($InputObject.CurrentIteration / $InputObject.TimeElapsed.TotalSeconds)) @paramWriteProgress
        }
        elseif ($InputObject.TimeElapsed.TotalMinutes -gt 0 -and ($InputObject.CurrentIteration / $InputObject.TimeElapsed.TotalMinutes) -ge 1) {
            Write-Progress -Status ("Completed {0:N0} in {1:c} ({2:N0}/min)" -f $InputObject.CurrentIteration, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond), ($InputObject.CurrentIteration / $InputObject.TimeElapsed.TotalMinutes)) @paramWriteProgress
        }
        else {
            Write-Progress -Status ("Completed {0:N0} in {1:c}" -f $InputObject.CurrentIteration, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond)) @paramWriteProgress
        }
    }

    $InputObject.CurrentIteration += $IncrementBy
}

function Stop-Progress {
    [CmdletBinding()]
    param (
        # Progress State Object
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject] $InputObject,
        # Write summary to host
        [Parameter(Mandatory = $false)]
        [switch] $WriteSummary
    )

    if ($InputObject -and $InputObject.Stopwatch.IsRunning) {
        [void] $script:stackProgressId.Pop()
        $InputObject.Stopwatch.Stop()
        [hashtable] $paramWriteProgress = $InputObject.WriteProgressParameters
        Write-Progress -Completed @paramWriteProgress
        if ($WriteSummary) {
            $Completed = if ($InputObject.Total -gt 0) { $InputObject.Total } else { $InputObject.CurrentIteration }
            Write-Host ("{2}: Completed {0:N0} in {1:c}" -f $Completed, $InputObject.TimeElapsed.Subtract($InputObject.TimeElapsed.Ticks % [TimeSpan]::TicksPerSecond), $InputObject.WriteProgressParameters.Activity)
        }
    }
}
