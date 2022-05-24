# Standards Functions

All standards scripts need to conform to this format:

```
# No parameters. Function should ALWAYS be called "Get-Verification"
Function Get-Verification {
  $output = @()

  # Some logic here...
  # Any output appended to $output like: $output += 'Some message'

  Return @{
    outputLog = $output
    result = $true # boolean indicating whether machine is compliant with this standard
    nonComplianceReason = $Null # should be $Null if machine is compliant and should provide a brief summary of why machine is noncompliant
  }
}
```

They must conform to this format is so that they can be arbitraryily called in a loop in other scripts and that loop needs a consistent interface to interact with.


Example:

```
# Call in Invoke-Output
$WebClient.DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Invoke-Output.ps1') | Invoke-Expression

$software = @(
  @{
    Name = 'Microsoft Defender'
    VerificationScript = 'https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/workstation-standards/Standards/Software/Defender.ps1'
  },
  @{
    Name = 'SentinelOne'
    VerificationScript = 'https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/workstation-standards/Standards/Software/SentinelOne.ps1'
  }
)

$result = $software | Foreach-Object {
  $WebClient.DownloadString($_.VerificationScript) | Invoke-Expression
  $verification = Get-Verification

  Return $verification
}

Invoke-Output $result

```

TODO: Make Invoke-Output work well for this array of outputLog's and piped results
