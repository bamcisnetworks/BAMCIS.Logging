#region Logging

Function Write-Log {
	<#
		.SYNOPSIS
			Writes to a log file and echoes the message to the console.

		.DESCRIPTION
			The cmdlet writes text or a PowerShell ErrorRecord to a log file and displays the log message to the console at the specified logging level.

		.PARAMETER Message
			The message to write to the log file.

		.PARAMETER ErrorRecord
			Optionally specify a PowerShell ErrorRecord object to include with the message.

		.PARAMETER Level
			The level of the log message, this is either INFO, WARNING, ERROR, DEBUG, or VERBOSE. This defaults to INFO.

		.PARAMETER Path
			The path to the log file. If this is not specified, the message is only echoed out.

		.PARAMETER NoInfo
			Specify to not add the timestamp and log level to the message being written.

		.INPUTS
			System.String

				The log message can be piped to Write-Log

		.OUTPUTS
			None

        .EXAMPLE
			try {
				$Err = 10 / 0
			}
			catch [Exception]
			{
				Write-Log -Message $_.Exception.Message -ErrorRecord $_ -Level ERROR
			}

			Writes an ERROR log about dividing by 0 to the default log path.

		.EXAMPLE
			Write-Log -Message "The script is starting"

			Writes an INFO log to the default log path.

		.NOTES
			AUTHOR: Michael Haken
			LAST UPDATE: 8/24/2016
	#>
	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter()]
		[ValidateSet("INFO", "WARNING", "ERROR", "DEBUG", "VERBOSE", "FATAL", "VERBOSEERROR")]
		[System.String]$Level = "INFO",

		[Parameter(Position = 0, ValueFromPipeline = $true, ParameterSetName = "Message", Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Message,

		[Parameter(Position = 0, ValueFromPipeline = $true, ParameterSetName = "Error", Mandatory = $true)]
		[Parameter(Position = 1, ParameterSetName = "Message")]
		[ValidateNotNull()]
		[System.Management.Automation.ErrorRecord]$ErrorRecord,

		[Parameter()]
		[System.String]$Path,

		[Parameter()]
		[Switch]$NoInfo
	)

	Begin {		
		Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
	}

	Process {
		if ($ErrorRecord -ne $null) {
			
			if (-not [System.String]::IsNullOrEmpty($Message))
			{
				$Message += "`r`n"
			}

			$Message += ("Exception: `n" + ($ErrorRecord.Exception | Select-Object -Property * | Format-List | Out-String) + "`n")
			$Message += ("Category: " + ($ErrorRecord.CategoryInfo.Category.ToString()) + "`n")
			$Message += ("Stack Trace: `n" + ($ErrorRecord.ScriptStackTrace | Format-List | Out-String) + "`n")
			$Message += ("Invocation Info: `n" + ($ErrorRecord.InvocationInfo | Format-List | Out-String))
		}
		
		if ($NoInfo) {
			$Content = $Message
		}
		else {
			$Lvl = $Level
			if ($Level -eq "VERBOSEERROR")
			{
				$Lvl = "ERROR"
			}
			$Content = "$(Get-Date) : [$Lvl] $Message"
		}

		if ([System.String]::IsNullOrEmpty($Path))
		{
			$Path = [System.Environment]::GetEnvironmentVariable("LogPath", [System.EnvironmentVariableTarget]::Machine)
		}

		if (-not [System.String]::IsNullOrEmpty($Path)) 
		{
			try
			{
				Add-Content -Path $Path -Value $Content -ErrorAction Stop
			}
			catch [System.UnauthorizedAccessException]
			{
				Write-Verbose -Message "Could not write to log file, you probably need to run the cmdlet with administrative privileges."
			}
			catch [Exception]
			{
				Write-Verbose -Message "Could not write to log file : $($_.Exception.Message)`n$Content"
			}
		}

		switch ($Level) {
			"INFO" {
				Write-Host $Content
				break
			}
			"WARNING" {
				Write-Warning -Message $Content
				break
			}
			"ERROR" {
				Write-Error -Message $Content
				break
			}
			"DEBUG" {
				Write-Debug -Message $Content
				break
			}
			"VERBOSE" {
				Write-Verbose -Message $Content
				break
			}
			"VERBOSEERROR" {
				Write-Verbose -Message $Content
				break
			}
			"FATAL" {
				throw (New-Object -TypeName System.Exception($Content))
			}
			default {
				Write-Warning -Message "Could not determine log level to write."
				Write-Host $Content
				break
			}
		}
	}

	End {
	}
}

Function Write-CMTraceLog {
	<#
		.SYNOPSIS
			Writes a log file formatted to be read by the CMTrace tool.

		.DESCRIPTION
			The cmdlet takes a message and writes it to a file in the format that can be read by CMTrace.

		.PARAMETER Message
			The message to be written to the file.

		.PARAMETER FilePath
			The path of the file to write the log information.

		.PARAMETER LogLevel
			The log level of the message. 1 is Informational, 2 is Warning, and 3 is Error. This defaults to Informational.

		.PARAMETER Component
			The component generating the log file.

		.PARAMETER Thread
			The thread ID of the process running the task. This defaults to the current managed thread ID.

		.PARAMETER ErrorRecord
			Specify a PowerShell ErrorRecord object to include with the message. The resulting message content will be in JSON format.

		.EXAMPLE
			Write-CMTraceLog -Message "Test Warning Message" -FilePath "c:\logpath.log" -LogLevel 2 -Component "PowerShell"

			This command writes "Test Warning Message" to c:\logpath.log and sets it as a Warning message in the CMTrace log viewer tool.

		.INPUTS
			System.String, System.Management.Automation.ErrorRecord

		.OUTPUTS
			None
		
		.NOTES
			AUTHOR: Michael Haken	
			LAST UPDATE: 10/25/2017

		.FUNCTIONALITY
			The intended use of this cmdlet is to write CMTrace formatted log files to be used with the viewer tool.
	#>

	[CmdletBinding()]
	[OutputType()]
	Param(
		[Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = "Message")]
		[ValidateNotNullOrEmpty()]
		[System.String]$Message = [System.String]::Empty,

		[Parameter(Position = 1, Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.String]$FilePath,

		[Parameter(Position = 2)]
		[ValidateSet(1,2,3)]
		[System.Int32]$LogLevel = 1,

		[Parameter(Position = 3)]
		[ValidateNotNullOrEmpty()]
		[System.String]$Component = [System.String]::Empty,

		[Parameter(Position = 4)]
		[System.Int32]$Thread = 0,

		[Parameter(ParameterSetName = "Message")]
		[Parameter(Position = 0, Mandatory = $true, ParameterSetName = "Error")]
		[ValidateNotNull()]
		[System.Management.Automation.ErrorRecord]$ErrorRecord = $null
	)

	Begin {		
		Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
	}

	Process {
		if ($Thread -eq 0) {
			$Thread = [System.Threading.Thread]::CurrentThread.ManagedThreadId
		}

		$Date = Get-Date
		$Time = ($Date.ToString("HH:mm:ss.fff") + "+" + ([System.TimeZone]::CurrentTimeZone.GetUtcOffset((Get-Date)).TotalMinutes * -1))
		$Day = $Date.ToString("MM-dd-yyyy")

		if ($ErrorRecord -ne $null) {			
			[System.Collections.Hashtable]$Data = @{Exception = $ErrorRecord.Exception; Category = $ErrorRecord.CategoryInfo.Category.ToString(); StackTrace = $ErrorRecord.ScriptStackTrace; InvocationInfo = $ErrorRecord.InvocationInfo}
			
			if (-not [System.String]::IsNullOrEmpty($Message))
			{
				$Data.Add("Message", $Message)
			}
			
			$Message = ConvertTo-Json -InputObject $Data -Compress
		}

		$File = $FilePath.Substring($FilePath.LastIndexOf("\") + 1)
		[System.String]$Log = @"
<![LOG[$Message]LOG]!><time="$Time" date="$Day" component="$Component" context="" type="$LogLevel" thread="$Thread" file="$File">
"@
		Add-Content -Path $FilePath -Value $Log -Force
	}

	End {		
	}
}

Function Get-CallerPreference {
    <#
		.SYNOPSIS
			Fetches "Preference" variable values from the caller's scope.

		.DESCRIPTION
		   Script module functions do not automatically inherit their caller's variables, but they can be
		   obtained through the $PSCmdlet variable in Advanced Functions.  This function is a helper function
		   for any script module Advanced Function; by passing in the values of $ExecutionContext.SessionState
		   and $PSCmdlet, Get-CallerPreference will set the caller's preference variables locally.

		.PARAMETER Cmdlet
		   The $PSCmdlet object from a script module Advanced Function.

		.PARAMETER SessionState
		   The $ExecutionContext.SessionState object from a script module Advanced Function.  This is how the
		   Get-CallerPreference function sets variables in its callers' scope, even if that caller is in a different
		   script module.

		.PARAMETER Name
		   Optional array of parameter names to retrieve from the caller's scope.  Default is to retrieve all
		   Preference variables as defined in the about_Preference_Variables help file (as of PowerShell 4.0)
		   This parameter may also specify names of variables that are not in the about_Preference_Variables
		   help file, and the function will retrieve and set those as well.

		.EXAMPLE
		   Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

		   Imports the default PowerShell preference variables from the caller into the local scope.

		.EXAMPLE
		   Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState -Name 'ErrorActionPreference','SomeOtherVariable'

		   Imports only the ErrorActionPreference and SomeOtherVariable variables into the local scope.

		.EXAMPLE
		   'ErrorActionPreference','SomeOtherVariable' | Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState

		   Same as Example 2, but sends variable names to the Name parameter via pipeline input.

		.INPUTS
		   System.String

		.OUTPUTS
		   None

		.NOTES
			AUTHOR: Dave Wyatt (Original Content)
					Michael Haken (Updates)
			LAST MODIFIED: 10/25/2017
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ 
			$_.GetType().FullName -eq "System.Management.Automation.PSScriptCmdlet" 
		})]
		[ValidateNotNull()]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
		[ValidateNotNull()]
        [System.Management.Automation.SessionState]$SessionState,

        [Parameter(ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
        [System.String[]]$Name = @()
    )

    Begin {  
		[System.Collections.Hashtable]$FilterHash = @{}
    }
    
    Process {
		# Add any filter values supplied via the pipeline
		foreach ($Item in $Name)
		{
			$FilterHash.Add($Item, $true)
		}
    }

    End
    {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0
        [System.Collections.Hashtable]$Preferences = @{
            'ErrorView' = $null
            'FormatEnumerationLimit' = $null
            'LogCommandHealthEvent' = $null
            'LogCommandLifecycleEvent' = $null
            'LogEngineHealthEvent' = $null
            'LogEngineLifecycleEvent' = $null
            'LogProviderHealthEvent' = $null
            'LogProviderLifecycleEvent' = $null
            'MaximumAliasCount' = $null
            'MaximumDriveCount' = $null
            'MaximumErrorCount' = $null
            'MaximumFunctionCount' = $null
            'MaximumHistoryCount' = $null
            'MaximumVariableCount' = $null
            'OFS' = $null
            'OutputEncoding' = $null
            'ProgressPreference' = $null
            'PSDefaultParameterValues' = $null
            'PSEmailServer' = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName' = $null
            'PSSessionConfigurationName' = $null
            'PSSessionOption' = $null
            'ErrorActionPreference' = 'ErrorAction'
            'DebugPreference' = 'Debug'
            'ConfirmPreference' = 'Confirm'
            'WhatIfPreference' = 'WhatIf'
            'VerbosePreference' = 'Verbose'
            'WarningPreference' = 'WarningAction'
        }


        foreach ($Item in $Preferences.GetEnumerator())
        {
			# If the preference doesn't have a value or the caller command wasn't supplied that parameter explicitly AND 
			# we're not filtering or if we are, that the filter contains the key,
			# go ahead and get the preference value from the session state of the calling module
			if ([System.String]::IsNullOrEmpty($Item.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($Item.Value) -and
				($FilterHash.Count -eq 0 -or $FilterHash.ContainsKey($Item.Name)))
			{
				$Variable = $Cmdlet.SessionState.PSVariable.Get($Item.Key)

				if ($Variable -ne $null)
				{
					# If the provided session state is the same as the current session state, set the variable locally since they are in the 
					# same module
					if ($SessionState -eq $ExecutionContext.SessionState)
					{
						Set-Variable -Scope 1 -Name $Variable.Name -Value $Variable.Value -Force -Confirm:$false -WhatIf:$false
					}
					# Otherwise set them in the provided session state
					else
					{
						$SessionState.PSVariable.Set($Variable.Name, $Variable.Value)
					}
				}
			}
        }

		# If we are filtering, and the filter was not in the standard set of preferences (like a custom preference), 
		# add it here
        if ($FilterHash.Count -gt 0)
        {
            foreach ($Key in $FilterHash.Keys)
            {
                if (-not $Preferences.ContainsKey($Key))
                {
                    $Variable = $Cmdlet.SessionState.PSVariable.Get($Key)
                
                    if ($Variable -ne $null)
                    {
                        if ($SessionState -eq $ExecutionContext.SessionState)
                        {
                            Set-Variable -Scope 1 -Name $Variable.Name -Value $Variable.Value -Force -Confirm:$false -WhatIf:$false
                        }
                        else
                        {
                            $SessionState.PSVariable.Set($Variable.Name, $Variable.Value)
                        }
                    }
                }
            }
        }
    } 
}

#endregion