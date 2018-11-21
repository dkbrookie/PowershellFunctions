Function Get-PSExec {
  $PSExecDir = "$env:windir\LTSvc\packages\software\PSExec"
  $PSExecURL = "https://support.dkbinnovative.com/labtech/Transfer/software/PSExec/7za.exe"
  $PSExecExe = "$PSExecDir\PSExec.exe"

  Try {
    If(!(Test-Path $PSExecDir)) {
      New-Item -ItemType Directory $PSExecDir | Out-Null
    }
    If(!(Test-Path $PSExecExe -PathType Leaf)) {
      Start-BitsTransfer -Source $PSExecURL -Destination $PSExecExe
      If(!(Test-Path $PSExecExe -PathType Leaf)) {
        Write-Error "Failed to download VACAgent zip"
        Break
      }
    }
  } Catch {
    Write-Error "There was an error while trying to download PSExec"
  }
}
