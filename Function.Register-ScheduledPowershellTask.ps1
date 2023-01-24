

Function Register-ScheduledPowershellTask {
  <#
  .SYNOPSIS
  Schedules a powershell scriptblock to run via windows task scheduler
  .DESCRIPTION
  Provided a `Trigger` (ScheduledTaskTrigger) a `ScriptBlock`, and a `TaskName`, Create-ScheduledPsTask will create a scheduled task that will run the provided
  powershell at the trigger time. `SelfDestruct` can be used to specify that you'd like the task to self-delete upon execution.
  .OUTPUTS
  Upon success, returns a (string) success message
  #>

  [CmdletBinding()]
  Param(
    # Parameter help description
    [Parameter(Mandatory = $true, Position = 0)]
    [scriptblock]
    $ScriptBlock,
    # Parameter help description
    [Parameter(Mandatory=$true)]
    [ciminstance[]]
    $Trigger,
    # Parameter help description
    [Parameter(Mandatory = $true)]
    [string]
    $TaskName,
    # Parameter help description
    [Parameter(Mandatory = $false)]
    [switch]
    $SelfDestruct,
    [Parameter(Mandatory = $false)]
    [string[]]
    $ArgumentList
  )

  Try {
    $tasks = @(New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -Command '& { $($ScriptBlock.ToString()) }' @('$($ArgumentList -join ''',''')')")

    If ($SelfDestruct) {
      $tasks += New-ScheduledTaskAction -Execute "schtasks.exe" -Argument "/delete /f /tn `"$taskName`""
    }

    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM"
    $settings = New-ScheduledTaskSettingsSet

    Register-ScheduledTask -Action $tasks -Trigger $Trigger -Principal $principal -Settings $settings -TaskName $TaskName

    # Return a message indicating that the second script block was scheduled
    Return "`nThe command block was scheduled to run as SYSTEM on the next system startup."
  } Catch {
    # If the first script block produces an error, return the output from the first script block and a message indicating that the second script block was not scheduled
    Throw "`nThe command was not scheduled due to an error. The error was: $_"
  }
}
