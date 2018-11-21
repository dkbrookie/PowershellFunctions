Function Get-7zip {
  $7zipDir = "$env:windir\LTSvc\packages\software\7zip"
  $7zipURL = "https://support.dkbinnovative.com/labtech/Transfer/software/7zip/7za.exe"
  $7zipExe = "$7zipDir\7zip.exe"

  Try {
    If(!(Test-Path $7zipDir)) {
      New-Item -ItemType Directory $7zipDir | Out-Null
    }
    If(!(Test-Path $7zipExe -PathType Leaf)) {
      Start-BitsTransfer -Source $7zipURL -Destination $7zipExe
      If(!(Test-Path $7zipExe -PathType Leaf)) {
        Write-Error "Failed to download VACAgent zip"
        Break
      }
    }
  } Catch {
    Write-Error "There was an error while trying to download 7zip"
  }
}
