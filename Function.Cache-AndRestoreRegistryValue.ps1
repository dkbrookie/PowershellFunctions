#Write a powershell function that accepts a path to a registry location as a parameter, then it moves that registry value to a temporary registry location and schedules a task to move it back after the next reboot

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

# Call in Registry-Helpers
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression
# TODO: change to master branch on merge
# Call in Invoke-OnNextStartup
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/Invoke-RebootIfNeeded/Function.Invoke-OnNextStartup.ps1') | Invoke-Expression

Function Cache-AndRestoreRegistryValue {
  <#
  .SYNOPSIS
  Removes a registry value and creates a scheduled task to put it back after the next reboot
  .DESCRIPTION
  Given a registry key path and value name, a registry value will be removed from it's current location and a scheduled task will be created which moves it back
  to it's original location after the next reboot occurrs.
  #>

  Param (
    # The path to a target registry key
    [Parameter(Mandatory = $true)]
    [string]
    $Path,
    # The name of the registry value to be cached
    [Parameter(Mandatory = $true)]
    [string]
    $Name,
    [Parameter(Mandatory = $false)]
    [string]
    $TempRegPath = "HKLM:\\SOFTWARE\DKB\Temp"
  )

  # It doesn't make sense to continue if the value we're copying doesn't exist
  If (!(Test-RegistryValue -Path $Path -Name $Name)) {
    Throw "The specified registry value '$Path\$Name' does not exist."
  }

  # TODO: test this. Create some funky perms and see if they make it through this process
  # Check permissions, maybe get current ACL (then edit ACL for stupid reason)

  # Create path for the temp location
  $date = (Get-Date -Format 'MMddyy-hhmmss')
  $tempPath = $TempRegPath + '\' + $date + '\'
  If (!(Test-Path -Path $tempPath)) {
    Try {
      New-Item -Path $tempPath -Force -ErrorAction Stop | Out-Null
    } Catch {
      Throw $_
    }
  }

  # Copy to the temp location, stop upon error, do not want to continue if this errors out
  Try {
    Copy-ItemProperty -Path $Path -Name $Name -Destination $tempPath -ErrorAction Stop
  } Catch {
    Throw $_
  }

  Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue

  # Now we're moving it back to it's original location
  $actionLater = {
    param($originalPath, $name, $tempPath)

    # If the path to the original location doesn't exist, create it
    If (!(Test-Path -Path $originalPath)) {
      New-Item -Path $originalPath -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Copy back to the original location
    Try {
      Copy-ItemProperty -Path $tempPath -Name $name -Destination $originalPath -Force -ErrorAction Stop
    } Catch {
      # Return early on error, we don't want to delete if this was unsuccessful
      Return
    }

    # Remove the temp entry
    Remove-ItemProperty -Path $tempPath -Name $name -Force

    # Check to see if the key is empty now, if it is, delete the key
    If ((Get-Item -Path $tempPath -EA 0) -and ((Get-Item -Path $tempPath).Property.length -lt 1)) {
      Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue | Out-Null
    }
  }

  Invoke-OnNextStartup -ScriptBlock $actionLater -TaskName ("Replace $Name - $date")  -ArgumentList @($Path, $Name, $tempPath)
}
