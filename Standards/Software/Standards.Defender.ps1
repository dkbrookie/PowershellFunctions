# Function Get-IsApplicationInstalled ($software) {
#   $installed = (Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where { $_.DisplayName -like "*$software*" }) -ne $null

#   If (-Not $installed) {
#     Write-Host "'$software' NOT is installed.";
#   }
#   else {
#     Write-Host "'$software' is installed."
#   }
# }

Function Get-Verification {
  $output = @()

  # $result = Get-IsApplicationInstalled 'Defender'

  Return @{
    outputLog           = $output
    result              = $true # boolean indicating whether machine is compliant with this standard
    nonComplianceReason = $Null # should be $Null if machine is compliant and should provide a brief summary of why machine is noncompliant
  }
}
