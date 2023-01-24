

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
    $SelfDestruct
  )

  Try {
    $base64Action = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ScriptBlock))
  } Catch {
    Throw "Could not convert the command to a base64 encoded string. The error was: $_"
  }

  Try {
    $tasks = @(New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $base64Action")

    If ($SelfDestruct) {
      $tasks += New-ScheduledTaskAction -Execute "schtasks.exe" -Argument "/delete /f /tn `"$taskName`""
    }

    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM"
    $settings = New-ScheduledTaskSettingsSet

    Register-ScheduledTask -Action $tasks -Trigger $Trigger -Principal $principal -Settings $settings -TaskName $TaskName

    # Return the output from the first script block and a message indicating that the second script block was scheduled
    Return "`nThe command block was scheduled to run as SYSTEM on the next system startup."
  } Catch {
    # If the first script block produces an error, return the output from the first script block and a message indicating that the second script block was not scheduled
    Throw "`nThe command was not scheduled due to an error. The error was: $_"
  }
}
