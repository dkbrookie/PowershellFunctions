Try {
  # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
  [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
} Catch {
  $output += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
  # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
  $psVers = $PSVersionTable.PSVersion

  If ($psVers.Major -lt 3) {
    $output += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
  }
}

# TODO: Switch this to master branch upon merge
# Call in Register-ScheduledPowershellTask
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/Invoke-RebootIfNeeded/Function.Register-ScheduledPowershellTask.ps1') | Invoke-Expression

Function Invoke-OnNextStartup {
  <#
  .SYNOPSIS
  Schedules a powershell scriptblock to run via windows task scheduler on next startup
  .DESCRIPTION
  Provided a ScriptBlock and a Name, creates a self-destructing scheduled task that will run the script block as system upon next startup
  #>

  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ScriptBlock]$ScriptBlock,
    [Parameter(Mandatory = $true)]
    [string]$TaskName,
    [Parameter(Mandatory = $false)]
    [string[]]
    $ArgumentList
  )

  $trigger = New-ScheduledTaskTrigger -AtStartup
  Register-ScheduledPowershellTask -TaskName $TaskName -Trigger $trigger -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList -SelfDestruct
}
