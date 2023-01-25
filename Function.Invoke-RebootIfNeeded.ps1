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
# Call in Read-PendingRebootStatus
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/Invoke-RebootIfNeeded/Function.Read-PendingRebootStatus.ps1') | Invoke-Expression
# Call in Registry-Helpers
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression
# TODO: Switch this to master branch upon merge
# Call in Invoke-OnNextStartup
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/Invoke-RebootIfNeeded/Function.Invoke-OnNextStartup.ps1') | Invoke-Expression

Function Invoke-RebootIfNeeded {
  <#
  .SYNOPSIS
  Reboots machine when a reboot is pending. Notes reason for reboot in registry. Creates scheduled task that checks this location after machine comes back up.
  If the reason for reboot is still there after reboot, forcefully removes that entry from the registry.

  .DESCRIPTION
  Checks all of the potential places that a pending reboot could be hiding on a system (via Read-PendingRebootStatus) and reboots machine if one is found. No
  action is taken if no pending reboot is found

  .PARAMETER (int, default = 10) Timeout
  Determines how long before the reboot occurs in seconds

  .PARAMETER (string, default = "$env:windir\LTSvc") LogPath
  Determines where logs are stored. A directory called "PendingReboots" will be created under this path which is where logs will be placed.

  .OUTPUTS
  Boolean - indicates whether machine is rebooting. $true means machine is rebooting. $false means reboot is not necessary
  #>

  Param (
    [int]
    $RebootDelay = 10,
    [string]
    $LogPath = "$env:windir\LTSvc"
  )

  $status = Read-PendingRebootStatus
  $rootPath = 'HKLM:\SOFTWARE\DKB\SystemState'
  $pendingRebootRegRootPath = "$rootPath\PendingRebootEntries"

  # Make sure some paths exist
  If (!(Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory | Out-Null
  }
  $rootDir = "$LogPath\PendingReboots"
  If (!(Test-Path -Path $rootDir)) {
    New-Item -Path $rootDir -ItemType Directory | Out-Null
  }
  $logFile = "$rootDir\log.txt"
  If (!(Test-Path -Path $logFile)) {
    New-Item -Path $logFile -ItemType File | Out-Null
  }

  Function Write-ToLogFile ($msg) {
    $contents = Get-Content -Path $logFile -Tail 499
    $contents + "`n" + (Get-Date -Format 'mm/dd/yyyy_HH:mm:ss - ').ToString() + $msg | Out-File $logFile
  }

  If ($status.HasPendingReboots) {
    # Pending reboots do exist according to Read-PendingRebootStatus, so loop through them and create registry and log entries for each of them
    $status.Entries | Foreach-Object {
      $pendingRebootPath = "$($_.Path)\$($_.Name)"
      $name = $pendingRebootPath -replace '\\', '-'
      $taskName = "Delete-$($pendingRebootPath -replace '\\', '-' -replace ':', '')"

      # Create a registry entry for each, we want to cache the locations now because we don't want to rely on network connectivity existing on next boot
      If (!(Test-RegistryValue -Path $pendingRebootPath -Name $name)) {
        Write-RegistryValue -Path $pendingRebootRegRootPath -Name $name -Value 1
        Write-ToLogFile "Writing '$pendingRebootRegRootPath\$name' to registry."
      }

      # If scheduled task for this item was already created, no need to create it again
      If (Get-ScheduledTask -TaskName $taskName -EA 0) {
        Return
      }

      # Create a scheduled task that takes action after next reboot and checks whatever locations were pending to see if they still exist and deletes them if they do
      # TODO: add logic to find powershell.exe from monitors
      $scriptBlock = {
        param($logFile, $regRootPath)

        Function Write-ToLogFile ($msg) {
          $contents = Get-Content -Path $logFile -Tail 499
          $contents + "`n" + (Get-Date -Format 'mm/dd/yyyy_HH:mm:ss - ').ToString() + $msg | Out-File $logFile
        }

        (Get-Item -Path $regRootPath).Property | Foreach-Object {
          $parts = $_ -split '-';
          $name = $parts[-1];
          $path = ($parts -ne $name) -join '\';

          Write-ToLogFile ('Rebooted. ' + $path + '\' + $name + ' still exists, so removing it manually.')

          Remove-ItemProperty -Path $path -Name $name -Force -EA 0
          Remove-ItemProperty -Path $regRootPath -Name $_
        };
      }

      Write-ToLogFile "Creating '$taskName' scheduled task which will run next reboot."
      Invoke-OnNextStartup -ScriptBlock $scriptBlock -TaskName $taskName -ArgumentList @($logFile, $pendingRebootRegRootPath)
    }

    Write-ToLogFile "Rebooting machine now."
    # shutdown.exe /r /c "Restarting your machine in $Delay seconds to complete critical Windows patching. Please save your work!" /t $Delay

    Return $true
  } Else {
    Return $false
  }
}
