Try {
  # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
  [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
} Catch {
  $out += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
  # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
  $psVers = $PSVersionTable.PSVersion

  If ($psVers.Major -lt 3) {
    $out += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
  }
}

# Call in Cache-AndRestoreRegistryValue
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Cache-AndRestoreRegistryValue.ps1') | Invoke-Expression
# Call in Read-PendingRebootStatus
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Read-PendingRebootStatus.ps1') | Invoke-Expression

Function Cache-AndRestorePendingReboots {
  <#
  .SYNOPSIS
  Removes all pending reboots in registry and then puts them back after the next reboot
  .DESCRIPTION
  Gathers up all pending reboots in windows registry as identified by Read-PendingRebootStatus and moves them to a temporary location, then creates
  self-deleting scheduled tasks to move them back to their original locations after the next reboot occurs.
  .OUTPUTS
  Returns object with `ActionTaken` which is a bool value indicating whether pending reboots existed and were therefore cached, or none existed so no action
  was taken, `Output` which is a string with output messages, and `ErrorState` which is true if any errors were experienced.
  #>
  $out = @()
  $errorState = $false
  $status = Read-PendingRebootStatus

  If (!$status.HasPendingReboots) {
    # No pending reboots exist, so can exit early
    Return @{
      ActionTaken = $false
      Output = 'No pending reboots were found.'
      ErrorState = $false
    }
  }

  $pendingReboots = $status.Entries

  $pendingReboots | ForEach-Object {
    $path = $_.Path
    $name = $_.Name

    Try {
      Cache-AndRestoreRegistryValue -Path $path -Name $name
    } Catch {
      $errorState = $true
      $out += "Had trouble caching reboot at $path/$name, so it may still exist"
    }
  }

  Return @{
    ActionTaken = $true
    Output = $status.Output + $out
    ErrorState = $errorState
  }
}
