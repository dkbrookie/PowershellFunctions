<#
  .SYNOPSIS
  Checks PC battery status

  .DESCRIPTION
  If machine has a battery and is currently on battery power, returns $true, otherwise returns false
#>
Function Get-IsOnBattery {
  $battery = Get-WmiObject -Class Win32_Battery | Select-Object -First 1
  $hasBattery = $null -ne $battery
  $batteryInUse = $battery.BatteryStatus -eq 1

  Return $hasBattery -and $batteryInUse
}
