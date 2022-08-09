Function Set-Screensaver {
  Param(
    # URL to a web location that contains an image file specified in the FileName field. Must be an ssl/https accessible location. Do not include
    # 'https://' or a trailing slash. Example: 'www.example.com'
    [Parameter(Mandatory = $True)]
    [string]
    $DownloadUrl,
    # The directory on the machine where the image file should be stored. Do not include a trailing slash. Example: 'C:\Users\Public\Pictures'
    [Parameter(Mandatory = $True)]
    [string]
    $StoragePath,
    # The name of the image file as it exists at the URL, the name will be the same on the machine. Avoid spaces in web accessible asset names. This function
    # is capable of handling spaces, but it can create problems, so avoid it if you can.
    [Parameter(Mandatory = $True)]
    [string]
    $FileName
  )

  $outputLog = @()
  $changes = @()

  $screensaverPath = "$StoragePath\$FileName"

  # Fix TLS
  Try {
    # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
    [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    $outputLog += "Successfully enabled TLS1.2 to ensure successful file downloads."
  } Catch {
    $outputLog += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
    # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
    $psVers = $PSVersionTable.PSVersion

    If ($psVers.Major -lt 3) {
      $outputLog += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
    }
  }

  # Call in Registry-Helpers
  (New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression

  # Ensure screensaver file exists
  If (!(Test-Path -Path $screensaverPath)) {
    # Construct the full download URL. Replace spaces if they exist with '%20' b/c that's how URLs work
    $screensaverUrl = "$($DownloadUrl -replace ' ', '%20')/$($FileName -replace ' ', '%20')"

    Try {
      Start-BitsTransfer -Source "https://$screensaverUrl" -Destination $screensaverPath -ErrorAction Stop
    } Catch {
      $outputLog += "Ran into an error when downloading screensaver. The error was: $($_.Exception.Message)."
    }
  }

  If (!(Test-Path -Path $screensaverPath)) {
    $outputLog += 'Was not able to download the screensaver and it does not exist on the machine. Not able to set screensaver.'
  } Else {
    # Mount HKU because we need it to set hkey_current_user values for all users as system
    Try {
      New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    } Catch {
      $outputLog += "Could not mount HKU. Exiting early and taking no action. The error was: $_"

      # Exit early b/c we need HKU to continue
      Return @{
        outputLog = $outputLog
        status    = 'PSDrive Error'
      }
    }

    # Loop through all sids in HKU
    Get-ChildItem -path 'HKU:/' | ForEach-Object {
      $sid = $_.PSChildName

      # The screensaver exists, so we can go ahead and set it
      $desktopPath = "HKU:\$sid\Control Panel\Desktop"
      $systemPath = "HKU:\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System"

      $regPaths = @(
        @{
          Path  = $desktopPath
          Name  = 'SCRNSAVE.EXE'
          Value = $screensaverPath
        },
        @{
          Path  = $desktopPath
          Name  = 'ScreenSaveActive'
          Value = 1
        },
        @{
          Path  = $desktopPath
          Name  = 'ScreenSaveTimeout'
          Value = 300
        },
        @{
          Path  = $desktopPath
          Name  = 'ScreenSaverIsSecure'
          Value = 1
        },
        @{
          Path  = $systemPath
          Name  = 'NoDispScrSavPage'
          Value = 1
        }
      )

      # Loop through all paths
      $regPaths | ForEach-Object {
        $path = $_.Path
        $name = $_.Name
        $value = $_.Value
        $type = $_.Type

        $errorMsg = "There was an issue when setting registry value of '$value' at '$path\$name' and it may have not been set"

        # If registry value does not match anticipated value
        If ((Get-RegistryValue -Path $path -Name $name) -ne $value) {
          Try {
            $result = Write-RegistryValue -Path $path -Name $name -Value $value -Type $type

            # Write-RegistryValue doesn't throw when it errors, it always returns a string, so we need to watch for an error message, we want to enter the
            # catch upon error
            If ($result -like '*Could not*') {
              Throw $result
            }

            $changes += "$path\$name was adjusted to '$value'"
          } Catch {
            $outputLog += $errorMsg + ", the error was: $($_.Exception.Message)."
            $skipAdditionalCheck = $True
          }
        }

        If (!$skipAdditionalCheck -and (Get-RegistryValue -Path $path -Name $name) -ne $value) {
          $outputLog += $errorMsg + '.'
        }
      }
    }

    # Unmount HKU
    Try {
      Remove-PSDrive 'HKU'
    } Catch {
      $outputLog += "Could not unmount HKU for some reason. The error was: $_"
    }
  }

  # If no changes were made
  If ($changes.Length -lt 1) {
    $changes += "No change"
  }

  Return @{
    outputLog = $outputLog
    status    = $changes
  }
}