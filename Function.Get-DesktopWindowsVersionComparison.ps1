<#
.SYNOPSIS
Detects current Win10 version and compares against another version. Determines if the current windows version is "equal to", "less than", "greater than",
"less than or equal to", or "greather than or equal to"
.DESCRIPTION
Detects current Win10 version and compares against another version. Determines if the current windows version is "equal to", "less than", "greater than",
"less than or equal to", or "greather than or equal to"

In the case of an invalid situation, such as requesting a version of windows that is not supported, or running this function on a Windows Server machine,
this script will throw an exception, so it should be used with try/catch.

Upon meeting a valid situation. It will check the version you provided against the version of windows that the current machine is running and output a hash table with "Result" (boolean) and Output (string).

It works with either Build ID (i.e. 19042) or Version ID (i.e. 20H2). Default is Build ID. You can use the -UseVersion switch to use VersionID.

.EXAMPLE
Try {
  $winIsLessThan19042 = Get-DesktopWindowsVersionComparison -LessThan 19042
} Catch {
  Write-Output $Error[0].Exception.Message
}

If ($winIsLessThan19042.Result) {
  Return 'Success! This is a newer version!' + $winIsLessThan19042.Output
} Else {
  Return 'Oh no! This is an old version!' + $winIsLessThan19042.Output
}

.EXAMPLE
Try {
  $winIsLessThan20H2 = Get-DesktopWindowsVersionComparison -LessThan 20H2 -UseVersion
} Catch {
  Write-Output $Error[0].Exception.Message
}

If ($winIsLessThan20H2.Result) {
  Return 'Success! This is a newer version!' + $winIsLessThan20H2.Output
} Else {
  Return 'Oh no! This is an old version!' + $winIsLessThan20H2.Output
}
#>

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

# TODO: switch this to master branch
# Call in Get-WindowsVersion
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/swap-windows-build-IDs-from-20H2-to-19042/Function.Get-WindowsVersion.ps1') | Invoke-Expression

function Get-DesktopWindowsVersionComparison {
  param (
    [Parameter(Mandatory = $true, ParameterSetName = 'LessThan')]
    [string]$LessThan,
    [Parameter(Mandatory = $true, ParameterSetName = 'LessThanOrEqualTo')]
    [string]$LessThanOrEqualTo,
    [Parameter(Mandatory = $true, ParameterSetName = 'GreaterThan')]
    [string]$GreaterThan,
    [Parameter(Mandatory = $true, ParameterSetName = 'GreaterThanOrEqualTo')]
    [string]$GreaterThanOrEqualTo,
    [Parameter(Mandatory = $true, ParameterSetName = 'EqualTo')]
    [string]$EqualTo,
    [Parameter(Mandatory = $false)]
    [switch]$UseVersion = $false
  )

  Switch ($true) {
    ([bool]$LessThan)               { $variableMsg = 'less than'; $checkAgainst = $LessThan }
    ([bool]$LessThanOrEqualTo)      { $variableMsg = 'less than or equal to'; $checkAgainst = $LessThanOrEqualTo }
    ([bool]$GreaterThan)            { $variableMsg = 'greater than'; $checkAgainst = $GreaterThan }
    ([bool]$GreaterThanOrEqualTo)   { $variableMsg = 'greater than or equal to'; $checkAgainst = $GreaterThanOrEqualTo }
    ([bool]$EqualTo)                { $variableMsg = 'equal to'; $checkAgainst = $EqualTo }
  }

  # Normalize all alpha characters to upppercase
  $checkAgainst = $checkAgainst.ToUpper()

  # Gather current OS info
  $windowsVersion = Get-WindowsVersion
  $osName = $windowsVersion.SimplifiedName
  $orderOfWindowsVersions = $windowsVersion.OrderOfWindowsVersions
  $version = $windowsVersion.Version
  $build = $windowsVersion.Build
  $currentVersionIndex = $orderOfWindowsVersions.IndexOf($version)
  $checkAgainstIndex = $orderOfWindowsVersions.IndexOf($checkAgainst)

  # Just to simplify the output message in each case below
  function Get-OutputMessage {
    param([bool]$Result)

    If ($UseVersion) {
      $versionForMessage = $version
    } Else {
      $versionForMessage = $build
    }

    $msg1 = "The current Windows version, $versionForMessage, is "
    $msg2 = "$variableMsg the requested version, $checkAgainst"

    If ($Result) {
      Return $msg1 + $msg2
    } Else {
      Return $msg1 + "not " + $msg2
    }
  }

  # Doesn't make sense if this isn't win10 or win11
  $osIs10 = $osName -eq '10'
  $osIs11 = $osName -eq '11'
  If (!($osIs10 -or $osIs11)) {
    Throw "This does not appear to be a Windows 10 machine. Function 'Get-DesktopWindowsVersionComparison' only supports Windows 10/11 machines. This is: $osName"
  }

  If ($useVersion -and ($version -eq 'Unknown')) {
    Throw "This version of Windows is unknown to this script. Cannot compare. This is: $osName"
  }

  # If $UseVersion is not true, we expect the value we're checking against to contain no letters, if it does contain letters, this is probably being used incorrectly
  If ($checkAgainst -match '[a-z]') {
    If (!$UseVersion) {
      Throw "The value you're trying to check against contains letters. You probably want to use the -UseVersion switch as it is " +
        "intended to signal that you're checking against version ID (i.e. 20H2) instead of Build ID (i.e. 19042)"
    }
  } Else {
    # The value we're checking against does not contain letters. If $UseVersion is true, we expect it to contain letters. This is probably being used incorrectly.
    If ($UseVersion) {
      Throw "The value you're trying to check against does not contain letters. You probably don't want to use the -UseVersion switch. " +
        "It is intended to signal that you're checking against version ID (i.e. 20H2) instead of Build ID (i.e. 19042)"
    }
  }

  # If the current version is not in the list of win 10/11 versions, it's not supported
  If ($UseVersion -and ($currentVersionIndex -eq -1)) {
    Throw "Something went wrong determining the current version of windows, it does not appear to be in the list.. " +
      "Maybe a new version of windows 10? Function 'Get-DesktopWindowsVersionComparison' supports $($orderOfWindowsVersions[0]) through $($orderOfWindowsVersions[-1]) " +
      "This is: $version. If you need to add a new version of windows, edit this: " +
      "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
  }

  # If the wanted version is not in the list of win 10 versions, it's not supported
  If ($UseVersion -and ($checkAgainstIndex -eq -1)) {
    Throw "Something went wrong determining the wanted version of windows, it does not appear to be in the supported list.. " +
      "Maybe a new version of windows 10? Function 'Get-DesktopWindowsVersionComparison' supports versions $($orderOfWindowsVersions[0]) " +
      "through $($orderOfWindowsVersions[-1]) " + "You requested: $checkAgainst. If you need to add a new version of windows, edit this: " +
      "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
  }

  If ($UseVersion) {
    $currentOsValue = $currentVersionIndex
    $requestedValue = $checkAgainstIndex
  } Else {
    $currentOsValue = $build
    $requestedValue = $checkAgainst
  }

  # Here's the meat
  Switch ($true) {
    ([bool]$LessThan) {
      $result = $currentOsValue -lt $requestedValue
    }
    ([bool]$LessThanOrEqualTo) {
      $result = $currentOsValue -le $requestedValue
    }
    ([bool]$GreaterThan) {
      $result = $currentOsValue -gt $requestedValue
    }
    ([bool]$GreaterThanOrEqualTo) {
      $result = $currentOsValue -ge $requestedValue
    }
    ([bool]$EqualTo) {
      $result = $currentOsValue -eq $requestedValue
    }
  }

  Return @{
    Result = $result
    Output = Get-OutputMessage -Result $result
  }
}
