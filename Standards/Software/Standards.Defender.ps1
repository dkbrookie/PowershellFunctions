# Call in Get-InstalledApplication
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Get-InstalledApplication.ps1') | Invoke-Expression

Function Get-Verification {
  $outputLog = @()
  $nonComplianceReason = @()

  # Get-MPComputerStatus is optional and only exists if "Security Health" app is installed
  If (!(Get-Command 'Get-MPComputerStatus' -errorAction SilentlyContinue)) {
    $nonComplianceReason += "Components required to check the status of Defender are not installed. Install the 'Microsoft.SecHealthUI' package."
    $outputLog += "'Get-MPComputerStatus' was not available so the Windows Defender Module for Powershell does not appear to be installed. "
      + "It is possible that that this script needs to be more thorough in this check."

    Return @{
      OutputLog = $outputLog
      Result = $False
      NonComplianceReason = $nonComplianceReason
    }
  }

  Try {
    # We need to know if SentinelOne is installed. If SentinelOne is not installed, we want Defender to be active.
    $s1Installed = Get-InstalledApplication -ApplicationName 'Sentinel Agent'
  } Catch {
    $outputLog += "An error occurred while checking to see if SentinelOne is installed. The error was: $_"
    $nonComplianceReason += "Unable to determine A/V status. This must be manually assessed."

    Return @{
      OutputLog = $outputLog
      Result = $False
      NonComplianceReason = $nonComplianceReason
    }
  }

  Try {
    $defenderStatus = Get-MPComputerStatus
  } Catch {
    $outputLog += "An error occurred while checking Defender's status. The error was: $_"
    $nonComplianceReason += "Unable to determine Defender's status. This must be manually assessed."

    Return @{
      OutputLog = $outputLog
      NonComplianceReason = $nonComplianceReason
    }
  }

  $mode = $defenderStatus.AMRunningMode

  If ($s1Installed) {
    # S1 is installed so we want Defender in passive mode
    If ($mode -ne 'Passive' -and $mode -ne 'SxS Passive') {
      # Defender is not running in passive mode
      $nonComplianceReason += "SentinelOne is installed, but Defender does not appear to be in passive mode."
      $outputLog += "SentinelOne is installed but Defender is not running in either 'Passive' or 'SxS Passive' mode. It is running in '$mode' mode."
    }
  } ElseIf ($mode -ne 'Normal') {
    # S1 is not installed, so we want Defender to be active
    $nonComplianceReason += "SentinelOne is not installed and Defender is running in '$mode' mode. "
      + "We want Defender running in 'Normal' mode when SentinelOne is missing."
  }

  If ($defenderStatus.DefenderSignaturesOutOfDate) {
    $nonComplianceReason += "Defender definitions are out of date."
  }

  Return @{
    OutputLog           = $outputLog
    NonComplianceReason = $nonComplianceReason # should be empty array if machine is compliant and should provide a brief summary of why machine is noncompliant
  }
}
