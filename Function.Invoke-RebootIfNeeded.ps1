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

# Call in Read-PendingRebootStatus
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Read-PendingRebootStatus.ps1') | Invoke-Expression
# Call in Registry-Helpers
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression

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

  .OUTPUTS
  Boolean - indicates whether machine is rebooting. $true means machine is rebooting. $false means reboot is not necessary
  #>

  Param (
    [int]
    $Timeout = 10
  )

  $status = Read-PendingRebootStatus
  $rootPath = 'HKLM:\SOFTWARE\DKB\SystemState'
  $pendingRebootRegRootPath = "$rootPath\PendingRebootEntries"

  # Make sure some paths exist
  $ltDir = "$env:windir\LTSvc"
  If (!(Test-Path -Path $ltDir)) {
    New-Item -Path $ltDir -ItemType Directory | Out-Null
  }
  $rootDir = "$ltDir\PendingReboots"
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
    # Pending reboots do exist according to Read-PendingRebootStatus, so loop through them and create registry annd log entries for each of them
    $status.Entries | Foreach-Object {
      $pendingRebootPath = "$($_.Path)\$($_.Name)"
      $name = $pendingRebootPath -replace '\\', '-'
      $taskName = "Delete-$($pendingRebootPath -replace '\\', '-' -replace ':', '')"
      $xmlFile = "$rootDir\$taskName.xml"

      # Create a registry entry for each, we want to cache the locations now because we don't want to rely on network connectivity existing on next boot
      If (!(Test-RegistryValue -Path $pendingRebootPath -Name $name)) {
        Write-RegistryValue -Path $pendingRebootRegRootPath -Name $name -Value 1
        Write-ToLogFile "Writing '$pendingRebootRegRootPath\$name' to registry."
      }

      # If scheduled task for this item was already created, no need to create it again
      If (Get-ScheduledTask -TaskName $taskName -EA 0) {
        Return
      }

      # Had to remove the following two things from the '-Command' string, they don't work for some reason when run from a sheduled task
      # TODO: log when reg entries are manually removed
      # Function Write-ToLogFile (`$msg) {
      #   `$contents = Get-Content -Path $logFile -Tail 499;
      #   `$contents + `"``n`" + (Get-Date -Format 'mm/dd/yyyy_HH:mm:ss - ').ToString() + `$msg | Out-File $logFile;
      # }
      # Write-ToLogFile ('Rebooted. ' + `$path + '\' + `$name + ' still exists, so removing it manually.')

      # Create a scheduled task that takes action after next reboot and checks whatever locations were pending to see if they still exist and deletes them if they do
      # TODO: add logic to find powershell.exe from monitors
      $psString = "-Command &amp;{

        `$ErrorActionPreference = 'SilentlyContinue';

        `$reboots = @(`'$((Get-Item -Path $pendingRebootRegRootPath).Property -join ''',''')`') | Foreach-Object {
          `$parts = `$_ -split '-';
          `$name = `$parts[-1];
          `$path = (`$parts -ne `$name) -join '\';
          Remove-ItemProperty -Path `$path -Name `$name -Force -EA 0;
          Remove-ItemProperty -Path $pendingRebootRegRootPath -Name `$_
        };

        `$ErrorActionPreference = 'Continue'; }"

      $xml = "<?xml version='1.0' encoding='UTF-16'?>
        <Task version='1.3' xmlns='http://schemas.microsoft.com/windows/2004/02/mit/task'>
        <RegistrationInfo>
        <Date>2015-07-27T13:03:33.7076468</Date>
        <Author>NT AUTHORITY\SYSTEM</Author>
        </RegistrationInfo>
        <Triggers>
        <BootTrigger>
        <Enabled>true</Enabled>
        </BootTrigger>
        </Triggers>
        <Principals>
        <Principal id='Author'>
        <RunLevel>HighestAvailable</RunLevel>
        <UserId>NT AUTHORITY\SYSTEM</UserId>
        <LogonType>S4U</LogonType>
        </Principal>
        </Principals>
        <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <AllowHardTerminate>true</AllowHardTerminate>
        <StartWhenAvailable>false</StartWhenAvailable>
        <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
        <IdleSettings>
        <StopOnIdleEnd>true</StopOnIdleEnd>
        <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Enabled>true</Enabled>
        <Hidden>false</Hidden>
        <RunOnlyIfIdle>false</RunOnlyIfIdle>
        <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
        <UseUnifiedSchedulingEngine>false</UseUnifiedSchedulingEngine>
        <WakeToRun>false</WakeToRun>
        <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
        <Priority>7</Priority>
        </Settings>
        <Actions Context='Author'>
        <Exec>
        <Command>powershell.exe</Command>
        <Arguments>$psString</Arguments>
        <WorkingDirectory>c:\windows\system32</WorkingDirectory>
        </Exec>
        <Exec>
        <Command>schtasks.exe</Command>
        <Arguments>/delete /f /tn `"$taskName`"</Arguments>
        <WorkingDirectory>c:\windows\system32</WorkingDirectory>
        </Exec>
        </Actions>
        </Task>"

      $xml | Out-File -FilePath $xmlFile

      schtasks.exe /Create /XML $xmlFile /TN "$taskName"
      Write-ToLogFile "Creating '$taskName' scheduled task which will run next reboot."
    }

    Write-ToLogFile "Rebooting machine now."
    shutdown.exe /r /c "Restarting your machine in $Timeout seconds to complete critical Windows patching. Please save your work!" /t $Timeout

    Return $true
  } Else {
    Return $false
  }
}
