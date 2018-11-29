Function Get-OSBIt {
  Try {
    If((Get-WmiObject win32_operatingsystem | Select-Object -ExpandProperty osarchitecture) -eq '64-bit') {
      Write-Output "x64"
    } Else {
      Write-Output "x86"
    }
  } Catch {
    Write-Error "Unable to determine OS architecture" | Out-File $logFile -Append
    Return
  }
}
