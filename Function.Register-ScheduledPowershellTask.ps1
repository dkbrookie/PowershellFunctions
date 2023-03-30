Try {
  # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
  [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
} Catch {
  Write-Output "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
  # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
  $psVers = $PSVersionTable.PSVersion

  If ($psVers.Major -lt 3) {
    Write-Output "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
  }
}

# Call in New-EncodedCommandWithArguments
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.New-EncodedCommandWithArguments.ps1') | Invoke-Expression


Function Register-ScheduledPowershellTask {
  <#
  .SYNOPSIS
  Schedules a powershell scriptblock to run via windows task scheduler
  .DESCRIPTION
  Provided a `Trigger` (ScheduledTaskTrigger) a `ScriptBlock`, and a `TaskName`, this will create a scheduled task that will run the provided
  ScriptBlock based on the trigger. `SelfDestruct` can be used to specify that you'd like the task to self-delete upon execution.
  #>

  [CmdletBinding()]
  Param(
    # (ScriptBlock, required) The powershell scriptblock that will be executed by the scheduled task
    [Parameter(Mandatory = $true, Position = 0)]
    [scriptblock]
    $ScriptBlock,
    # (ScheduledTaskTrigger, required) See ScheduledTaskTrigger docs
    [Parameter(Mandatory=$true)]
    [ciminstance[]]
    $Trigger,
    # (string, required) The name that will be used in task scheduler
    [Parameter(Mandatory = $true)]
    [string]
    $TaskName,
    # (Switch, default $false) Indicates whether this task should delete itself upon first run
    [Parameter(Mandatory = $false)]
    [switch]
    $SelfDestruct,
    # (string[]) An array of positional arguments that will be passed into the ScriptBlock on execution
    [Parameter(Mandatory = $false)]
    [string[]]
    $ArgumentList
  )

  Try {
    $task = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -Command $(New-EncodedCommandWithArguments -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList)"

    $tasks = @($task)

    If ($SelfDestruct) {
      $tasks += New-ScheduledTaskAction -Execute "schtasks.exe" -Argument "/delete /f /tn `"$taskName`""
    }

    $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM"
    $settings = New-ScheduledTaskSettingsSet

    Register-ScheduledTask -Action $tasks -Trigger $Trigger -Principal $principal -Settings $settings -TaskName $TaskName
  } Catch {
    # If the first script block produces an error, return the output from the first script block and a message indicating that the second script block was not scheduled
    Throw "`nThe command was not scheduled due to an error. The error was: $_"
  }
}
