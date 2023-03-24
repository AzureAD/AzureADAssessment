<#
.SYNOPSIS
    Write Exception to Application Insights.
.EXAMPLE
    PS C:\>Write-AppInsightsEvent $exception
    Write Exception to Application Insights.
.INPUTS
    System.Exception
#>
function Write-AppInsightsException {
    [CmdletBinding()]
    [Alias('Write-AIException')]
    param (
        # Exceptions
        [Parameter(Mandatory = $true, ParameterSetName = 'Exception', Position = 1)]
        [Exception[]] $Exception,
        # ErrorRecords
        [Parameter(Mandatory = $true, ParameterSetName = 'ErrorRecord', Position = 1)]
        [System.Management.Automation.ErrorRecord[]] $ErrorRecord,
        # Severity Level
        [Parameter(Mandatory = $false)]
        [ValidateSet('Verbose', 'Information', 'Warning', 'Error', 'Critical')]
        [string] $SeverityLevel,
        # Custom Properties
        [Parameter(Mandatory = $false)]
        [hashtable] $Properties,
        # Custom Ordered Properties. An ordered dictionary can be defined as: [ordered]@{ first = '1'; second = '2' }
        [Parameter(Mandatory = $false)]
        [System.Collections.Specialized.OrderedDictionary] $OrderedProperties,
        # Include process processor and memory usage statistics.
        [Parameter(Mandatory = $false)]
        [switch] $IncludeProcessStatistics,
        # Instrumentation Key
        [Parameter(Mandatory = $false)]
        [string] $InstrumentationKey = $script:ModuleConfig.'ai.instrumentationKey',
        # Ingestion Endpoint
        [Parameter(Mandatory = $false)]
        [string] $IngestionEndpoint = $script:ModuleConfig.'ai.ingestionEndpoint'
    )

    begin {
        ## Return Immediately when Telemetry is Disabled
        if ($script:ModuleConfig.'ai.disabled') { return }

        ## Application Insights Exception Helper Functions
        # https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/ExceptionConverter.cs#L9
        Set-Variable MaxParsedStackLength -Value 32768 -Option Constant

        <#
        .SYNOPSIS
            Convert Exceptions Tree to ExceptionDetails
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/DataContracts/ExceptionTelemetry.cs#L386
        #>
        function ConvertExceptionTree ([Exception] $exception, [hashtable] $parentExceptionDetails, [System.Collections.Generic.List[hashtable]] $exceptions) {
            if ($null -eq $exception) {
                $exception = New-Object Exception -ArgumentList 'n/a'
            }

            [hashtable] $exceptionDetails = ConvertToExceptionDetails $exception $parentExceptionDetails

            ## For upper level exception see if Message was provided and do not use exceptiom.message in that case
            #if ($null -eq $parentExceptionDetails -and ![string]::IsNullOrWhiteSpace($this.Message)) {
            #    $exceptionDetails.message = $this.Message
            #}

            $exceptions.Add($exceptionDetails)

            [AggregateException] $aggregate = $exception -as [AggregateException]
            if ($null -ne $aggregate) {
                foreach ($inner in $aggregate.InnerExceptions) {
                    ConvertExceptionTree $inner $exceptionDetails $exceptions
                }
            }
            elseif ($null -ne $exception.InnerException) {
                ConvertExceptionTree $exception.InnerException $exceptionDetails $exceptions
            }
        }

        <#
        .SYNOPSIS
            Converts a Exception to a Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryTypes.ExceptionDetails.
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/ExceptionConverter.cs#L14
        #>
        function ConvertToExceptionDetails ([Exception]$exception, [hashtable]$parentExceptionDetails) {
            [hashtable] $exceptionDetails = CreateWithoutStackInfo $exception $parentExceptionDetails
            $stack = New-Object System.Diagnostics.StackTrace -ArgumentList $Exception, $true

            $frames = $stack.GetFrames()
            $sanitizedTuple = SanitizeStackFrame $frames
            $exceptionDetails['parsedStack'] = $sanitizedTuple[0]
            $exceptionDetails['hasFullStack'] = $sanitizedTuple[1]
            return $exceptionDetails
        }

        <#
        .SYNOPSIS
            Creates a new instance of ExceptionDetails from a Exception and a parent ExceptionDetails.
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/External/ExceptionDetailsImplementation.cs#L13
        #>
        function CreateWithoutStackInfo ([Exception]$exception, [hashtable]$parentExceptionDetails) {
            if ($null -eq $exception) {
                throw (New-Object ArgumentNullException -ArgumentList $exception.GetType().Name)
            }

            [hashtable] $exceptionDetails = [ordered]@{
                id       = $exception.GetHashCode()
                typeName = $exception.GetType().FullName
                message  = $exception.Message
            }

            if ($null -ne $parentExceptionDetails) {
                $exceptionDetails.outerId = $parentExceptionDetails.id
            }

            return $exceptionDetails
        }

        <#
        .SYNOPSIS
            Sanitizing stack to 32k while selecting the initial and end stack trace.
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/ExceptionConverter.cs#L93
        #>
        function SanitizeStackFrame ([System.Diagnostics.StackFrame[]]$inputList) {
            [System.Collections.Generic.List[hashtable]] $orderedStackTrace = New-Object System.Collections.Generic.List[hashtable]
            [bool] $hasFullStack = $true
            if ($null -ne $inputList -and $inputList.Count -gt 0) {
                [int] $currentParsedStackLength = 0
                for ($level = 0; $level -lt $inputList.Count; $level++) {
                    ## Skip middle part of the stack
                    [int] $current = if ($level % 2 -eq 0) { ($inputList.Count - 1 - ($level / 2)) } else { ($level / 2) }

                    [hashtable] $convertedStackFrame = GetStackFrame $inputList[$current] $current
                    $currentParsedStackLength += GetStackFrameLength $convertedStackFrame

                    if ($currentParsedStackLength -gt $MaxParsedStackLength) {
                        $hasFullStack = $false
                        break
                    }

                    $orderedStackTrace.Insert($orderedStackTrace.Count / 2, $convertedStackFrame)
                }
            }

            return $orderedStackTrace, $hasFullStack
        }

        <#
        .SYNOPSIS
            Converts a System.Diagnostics.StackFrame to a Microsoft.ApplicationInsights.Extensibility.Implementation.TelemetryTypes.StackFrame.
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/ExceptionConverter.cs#L36
        #>
        function GetStackFrame ([System.Diagnostics.StackFrame]$stackFrame, [int]$frameId) {
            [hashtable] $convertedStackFrame = [ordered]@{
                level = $frameId
            }

            $methodInfo = $stackFrame.GetMethod()
            [string] $fullName = $null
            [string] $assemblyName = $null

            if ($null -eq $methodInfo) {
                $fullName = "unknown"
                $assemblyName = "unknown"
            }
            else {
                $assemblyName = $methodInfo.Module.Assembly.FullName
                if ($null -ne $methodInfo.DeclaringType) {
                    $fullName = $methodInfo.DeclaringType.FullName + "." + $methodInfo.Name
                }
                else {
                    $fullName = $methodInfo.Name
                }
            }

            $convertedStackFrame['method'] = $fullName
            $convertedStackFrame['assembly'] = $assemblyName
            $convertedStackFrame['fileName'] = $stackFrame.GetFileName()

            ## 0 means it is unavailable
            [int] $line = $stackFrame.GetFileLineNumber()
            if ($line -ne 0) {
                $convertedStackFrame['line'] = $line
            }

            return $convertedStackFrame
        }

        <#
        .SYNOPSIS
            Gets the stack frame length for only the strings in the stack frame.
        .LINK
            https://github.com/microsoft/ApplicationInsights-dotnet/blob/81288f26921df1e8e713d31e7e9c2187ac9e6590/BASE/src/Microsoft.ApplicationInsights/Extensibility/Implementation/ExceptionConverter.cs#L82
        #>
        function GetStackFrameLength ([hashtable]$stackFrame) {
            [int] $stackFrameLength = if ($null -eq $stackFrame.method) { 0 } else { $stackFrame.method.Length }
            $stackFrameLength += if ($null -eq $stackFrame.assembly) { 0 } else { $stackFrame.assembly.Length }
            $stackFrameLength += if ($null -eq $stackFrame.fileName) { 0 } else { $stackFrame.fileName.Length }
            return $stackFrameLength
        }
    }

    process {
        ## Return Immediately when Telemetry is Disabled
        if ($script:ModuleConfig.'ai.disabled') { return }
        
        switch ($PSCmdlet.ParameterSetName) {
            'Exception' {
                $InputObjects = $Exception
                break
            }
            'ErrorRecord' {
                $InputObjects = $ErrorRecord
                break
            }
        }

        foreach ($InputObject in $InputObjects) {
            ## Get New Telemetry Entry
            $AppInsightsTelemetry = New-AppInsightsTelemetry 'AppExceptions' -InstrumentationKey $InstrumentationKey

            ## Determine ErrorRecord from Exception input
            [Exception] $InputException = $null
            if ($InputObject -is [System.Management.Automation.ErrorRecord]) {
                $InputException = $InputObject.Exception
                $AppInsightsTelemetry.data.baseData['properties']['ScriptStackTrace'] = $InputObject.ScriptStackTrace.Replace($MyInvocation.MyCommand.Module.ModuleBase,'')
            }
            elseif ($InputObject -is [System.Management.Automation.ErrorRecord]) {
                $InputException = $InputObject
            }

            if ($InputException) {
                ## Get Exception Details
                [System.Collections.Generic.List[hashtable]] $exceptions = New-Object System.Collections.Generic.List[hashtable]
                ConvertExceptionTree $InputException $null $exceptions
                $AppInsightsTelemetry.data.baseData['exceptions'] = $exceptions
            }
            
            ## Update Telemetry Data
            if ($SeverityLevel) { $AppInsightsTelemetry.data.baseData['severityLevel'] = $SeverityLevel }

            if ($IncludeProcessStatistics) {
                $PsProcess = Get-Process -PID $PID
                $AppInsightsTelemetry.data.baseData['properties']['TotalProcessorTime'] = $PsProcess.TotalProcessorTime.ToString()

                $AppInsightsTelemetry.data.baseData['properties']['VirtualMemorySize'] = Format-DataSize $PsProcess.VM
                $AppInsightsTelemetry.data.baseData['properties']['WorkingSetMemorySize'] = Format-DataSize $PsProcess.WS
                $AppInsightsTelemetry.data.baseData['properties']['PagedMemorySize'] = Format-DataSize $PsProcess.PM
                $AppInsightsTelemetry.data.baseData['properties']['NonpagedMemorySize'] = Format-DataSize $PsProcess.NPM

                $AppInsightsTelemetry.data.baseData['properties']['PeakVirtualMemorySize'] = Format-DataSize $PsProcess.PeakVirtualMemorySize64
                $AppInsightsTelemetry.data.baseData['properties']['PeakWorkingSetMemorySize'] = Format-DataSize $PsProcess.PeakWorkingSet64
                $AppInsightsTelemetry.data.baseData['properties']['PeakPagedMemorySize'] = Format-DataSize $PsProcess.PeakPagedMemorySize64

                $AppInsightsTelemetry.data.baseData['properties']['TotalProcessorTimeInSeconds'] = $PsProcess.CPU

                $AppInsightsTelemetry.data.baseData['properties']['VirtualMemoryInBytes'] = $PsProcess.VM
                $AppInsightsTelemetry.data.baseData['properties']['WorkingSetMemoryInBytes'] = $PsProcess.WS
                $AppInsightsTelemetry.data.baseData['properties']['PagedMemoryInBytes'] = $PsProcess.PM
                $AppInsightsTelemetry.data.baseData['properties']['NonpagedMemoryInBytes'] = $PsProcess.NPM

                $AppInsightsTelemetry.data.baseData['properties']['PeakVirtualMemoryInBytes'] = $PsProcess.PeakVirtualMemorySize64
                $AppInsightsTelemetry.data.baseData['properties']['PeakWorkingSetMemoryInBytes'] = $PsProcess.PeakWorkingSet64
                $AppInsightsTelemetry.data.baseData['properties']['PeakPagedMemoryInBytes'] = $PsProcess.PeakPagedMemorySize64
            }

            if ($OrderedProperties) { $AppInsightsTelemetry.data.baseData['properties'] += $OrderedProperties }
            if ($Properties) { $AppInsightsTelemetry.data.baseData['properties'] += $Properties }

            ## Write Data to Application Insights
            Write-Debug (([PSCustomObject]$AppInsightsTelemetry) | ConvertTo-Json -Depth 6)
            try { $result = Invoke-RestMethod -UseBasicParsing -Method Post -Uri $IngestionEndpoint -ContentType 'application/json' -Body ($AppInsightsTelemetry | ConvertTo-Json -Depth 6 -Compress) -Verbose:$false -ErrorAction SilentlyContinue }
            catch {}
        }
    }

}
