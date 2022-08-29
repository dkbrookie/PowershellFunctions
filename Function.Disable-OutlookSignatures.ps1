Function Disable-OutlookSignatures() {
  <#
  .SYNOPSIS
  Deletes existing signatures and disables adding new signatures for all users

  .DESCRIPTION
  Deletes everying in the user's signature folder and adds registry values to disable local and roaming Outlook signatures

  .EXAMPLE
  Disable-OutlookSignatures
  #>
  $outputLog = @()

  # Fix TLS
  Try {
    # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
  } Catch {
    $outputLog += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
    # Generally enabling TLS1.2 fails due to dated Powershell so we"re doing a check here to help troubleshoot failures later
    $psVers = $PSVersionTable.PSVersion

    If ($psVers.Major -lt 3) {
      $outputLog += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
    }
  }

  # Call in Registry-Helpers
  (New-Object System.Net.WebClient).DownloadString("https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1") | Invoke-Expression

  # Loop through list of user folders, deleting signatures for each user
  Get-ChildItem -Path "C:\Users" | Where-Object { $_.Name -ne "Public" } | Foreach-Object {
    $userPath = $_.FullName
    $path = "$userPath\AppData\Roaming\Microsoft\Signatures"

    If (Test-Path -Path $path) {
      Get-ChildItem -Path $path | Remove-Item -Recurse -Force
      $outputLog += "Deleted signatures at user path: $userPath"
    }
  }

  If (!(Get-ItemProperty 'HKLM:\SOFTWARE\Classes\Outlook.Application' -ErrorAction SilentlyContinue)) {
    $outputLog += "Outlook is not installed so no further action is necessary."

    # No need to continue if outlook is not installed
    Return @{
      outputLog = $outputLog
      status    = "Outlook Not Installed"
    }
  }

  # Mount HKU because we need it to set hkey_current_user values for all users as system
  Try {
    New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
  } Catch {
    $outputLog += "Could not mount HKU. Exiting early and taking no further action. The error was: $_"

    # Exit early b/c we need HKU to continue
    Return @{
      outputLog = $outputLog
      status    = "PSDrive Error"
    }
  }

  # Loop through all sids in HKU and disable adding new signatures for all users
  Get-ChildItem -path "HKU:\" | ForEach-Object {
    $sid = $_.PSChildName
    $regPath = "HKU:\$sid\Software\Microsoft\Office\16.0\Common\MailSettings"

    Write-RegistryValue -Path $regPath -Name 'DisableSignatures' -Value "1" -Type 'DWORD'
    Write-RegistryValue -Path $regPath -Name 'DisableRoamingSignaturesTemporaryToggle' -Value "1" -Type 'DWORD'
  }

  $outputLog += "Set registry values for all users"

  # Unmount HKU
  Try {
    Remove-PSDrive "HKU" -ErrorAction Stop
  } Catch {
    $outputLog += "Could not unmount HKU for some reason. The error was: $_"
  }

  Return @{
    outputLog = $outputLog
    status    = $changes
  }
}
