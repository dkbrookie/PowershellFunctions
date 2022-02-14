<#
Detects current Win10 version and compares against another version. Determines if the current windows version is "equal to", "less than", "greater than",
"less than or equal to", or "greather than or equal to"

In the case of an invalid situation, such as requesting a version of windows that is not supported, or running this function on a Windows Server machine,
this script will throw an exception, so it should be used with try/catch.

Upon meeting a valid situation. It will check the version you provided against the version of windows that the current machine is running and output a hash table with "Result" (boolean) and Output (string).

Example of correct usage:
Try {
  $winIsLessThan20H2 = Get-Win10VersionComparison -LessThan '20H2'
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

  # Just to simplify the output message in each case below
  function Get-OutputMessage {
    param([bool]$Result)

    $msg1 = "The current Windows version, $version, is "
    $msg2 = "$variableMsg the requested version, $checkAgainst"

    If ($Result) {
       Return $msg1 + $msg2
    } Else {
      Return $msg1 + "not " + $msg2
    }
  }

  # Gather current OS info
  $windowsVersion = Get-WindowsVersion
  $osName = $windowsVersion.SimplifiedName
  $orderOfWindowsVersions = $windowsVersion.OrderOfWindowsVersions
  $version = $windowsVersion.Version
  $build = $windowsVersion.Build
  $currentVersionIndex = $orderOfWindowsVersions.IndexOf($version)
  $checkAgainstIndex = $orderOfWindowsVersions.IndexOf($checkAgainst)

  $osIs10 = $osName -eq '10'
  $osIs11 = $osName -eq '11'

  # Doesn't make sense if this isn't win10 or win11
  If (!($osIs10 -or $osIs11)) {
    Throw "This does not appear to be a Windows 10 machine. Function 'Get-DesktopWindowsVersionComparison' only supports Windows 10/11 machines. This is: $osName"
  }

  If ($version -eq 'Unknown') {
    Throw "This version of Windows is unknown to this script. Cannot compare. This is: $osName"
  }

  # If the current version is not in the list of win 10/11 versions, it's not supported
  If ($currentVersionIndex -eq -1) {
    Throw "Something went wrong determining the current version of windows, it does not appear to be in the list.." +
        "Maybe a new version of windows 10? Function 'Get-Win10VersionComparison' supports $($orderOfWindowsVersions[0]) through $($orderOfWindowsVersions[-1]) " +
        "This is: $version. If you need to add a new version of windows, edit this: " +
        "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
  }

  # If the wanted version is not in the list of win 10 versions, it's not supported
  If ($checkAgainstIndex -eq -1) {
    Throw "Something went wrong determining the wanted version of windows, it does not appear to be in the supported list.." +
    "Maybe a new version of windows 10? Function 'Get-Win10VersionComparison' supports versions $($orderOfWindowsVersions[0]) through $($orderOfWindowsVersions[-1]) " +
    "You requested: $checkAgainst. If you need to add a new version of windows, edit this: " +
    "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
  }

  # Here's the meat
  Switch ($true) {
    ([bool]$LessThan) {
      $result = $currentVersionIndex -lt $checkAgainstIndex
    }

    ([bool]$LessThanOrEqualTo) {
      $result = $currentVersionIndex -le $checkAgainstIndex
    }

    ([bool]$GreaterThan) {
      $result = $currentVersionIndex -gt $checkAgainstIndex
    }

    ([bool]$GreaterThanOrEqualTo) {
      $result = $currentVersionIndex -ge $checkAgainstIndex
    }

    ([bool]$EqualTo) {
      $result = $currentVersionIndex -eq $orderOfWindowsVersions.IndexOf($EqualTo)
    }
  }

  Return @{
    Result = $result
    Output = Get-OutputMessage -Result $result
  }
}
