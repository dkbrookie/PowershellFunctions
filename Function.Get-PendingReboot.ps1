<#
  .SYNOPSIS
  Checks if machine is currently pending reboot.

  .DESCRIPTION
  Checks if machine is currently pending reboot by checking 3 registry locations where windows might store this info.
  Returns an object with 3 values. 'Checks' contains the value of each of the 3 possible registry locations, in order.
  'Output' contains the logging output of the function. 'PendingReboot' contains a boolean indicating whether the machine
  is pending reboot or not.
#>
function Get-PendingReboot {
  $windowsUpdateRebootPath1 = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
  $windowsUpdateRebootPath2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

  $out = @()
  $rebootChecks = @()

  ## The following two reboot keys most commonly exist if a reboot is required for Windows Updates, but it is possible
  ## for an application to make an entry here too.
  $rbCheck1 = Get-ChildItem $windowsUpdateRebootPath1 -EA 0
  $rbCheck2 = Get-Item $windowsUpdateRebootPath2 -EA 0

  ## This is often also the result of an update, but not specific to Windows update. File renames and/or deletes can be
  ## pending a reboot, and this key tells Windows to take these actions on the machine after a reboot to ensure the files
  ## aren't running so they can be renamed.
  $rbCheck3 = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA 0

  If ($rbCheck1) {
    $out += "Found a reboot pending for Windows Updates to complete at $windowsUpdateRebootPath1.`r`n"
    $rebootChecks += $rbCheck1
  }

  If ($rbCheck2) {
    $out += "Found a reboot pending for Windows Updates to complete at $windowsUpdateRebootPath2.`r`n"
    $rebootChecks += $rbCheck2
  }

  If ($rbCheck3) {
    $out += "Found a reboot pending for file renames/deletes on next system reboot.`r`n"
    $out += "`r`n`r`n===========List of files pending rename===========`r`n`r`n`r`n"
    $out = ($rbCheck3).PendingFileRenameOperations | Out-String
    $rebootChecks += $rbCheck3
  }

  Return @{
    Checks = $rebootChecks
    PendingReboot = $rebootChecks.Length -gt 0
    Output = ($out -join "`n")
  }
}
