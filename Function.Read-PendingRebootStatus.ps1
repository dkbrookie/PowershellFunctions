# Call in Registry-Helpers
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression

function Read-PendingRebootStatus {
  $out = @()
  $entries = @()

  $keys = @(
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Updates'
      Name = 'UpdateExeVolatile'
    },
    @{
      Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
      Name = 'PendingFileRenameOperations'
    },
    @{
      Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
      Name = 'PendingFileRenameOperations2'
    },
    @{
      Path = 'HKLM:\SYSTEM\CurrentSet001\Control\Session'
      Name = 'Manager'
    },
    @{
      Path = 'HKLM:\SYSTEM\CurrentSet002\Control\Session'
      Name = 'Manager'
    },
    @{
      Path = 'HKLM:\SYSTEM\CurrentSet003\Control\Session'
      Name = 'Manager'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
      Name = 'RebootRequired'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Services'
      Name = 'Pending'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
      Name = 'Mandatory'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update'
      Name = 'PostRebootReporting'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
      Name = 'DVDRebootSignal'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'
      Name = 'RebootPending'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing'
      Name = 'RebootInProgress'
    },
    @{
      Path = 'HKLM:\SOFTWARE\Microsoft\ServerManager'
      Name = 'CurrentRebootAttempts'
    },
    @{
      Path = 'HKLM:\SOFTWARE\DKB\SystemState'
      Name = 'HasPendingReboot'
      ValueCheck = '1'
    }
  )

  $keys | ForEach-Object {
    $path = $_.Path
    $name = $_.Name
    $fullPath = "$path\$name"

    If (Test-RegistryValue -Path $path -Name $name) {
      $value = Get-RegistryValue -Path $path -Name $name

      # If there is a value check, check the value of the reg key against it and return early if it doesn't match, that ain't a pending reboot
      If ($_.ValueCheck -and ($value -ne $_.ValueCheck)) {
        Return
      }

      $out += "Found a reboot pending at $fullPath"

      $entries += @{
        Path = $path
        Name = $name
        Value = $value
      }
    }
  }

  Return @{
    Entries = $entries
    HasPendingReboots = $entries.Length -gt 0
    Output = ($out -join "`n")
  }
}
