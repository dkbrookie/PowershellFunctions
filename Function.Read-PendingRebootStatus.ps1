# Call in Registry-Helpers
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression

function Read-PendingRebootStatus {
  <#
  .DESCRIPTION
    Read-PendingRebootStatus checks all of the various registry locations that windows could be hiding a pending reboot, it aggregates any pending reboots
    found and reports them back if they exist.
  .OUTPUTS
    An object with keys "HasPendingReboots" "Entries" and "Output"
    - HasPendingReboots (bool): true if any pending reboots are found, otherwise false
    - Entries (array of Hashtables): When pending reboots are found, this array is populated with the path, name, and value of the registry keys that were found
    - Output (string): A newline-delimited string containing the full path of all pending reboots found
  #>
  $out = @()
  $entries = @()

  # TODO: I don't know for certain how all of these work, it is possible that some of them need to be value-checked similar to the "HasPendingReboot" one
  # I'm creating myself as the last entry. Ideally we know for certain that the existence of the rest of these means a pending reboot but we may need to
  # rely on trial and error to figure out some of these.
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
