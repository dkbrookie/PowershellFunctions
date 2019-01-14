Function Install-MSI {
  <#
    .SYNOPSIS
    Take-Own

    .DESCRIPTION
    Take-Own force takes ownership to the Administrators group over the entire file or folder path you define in -FolderPath or -FilePath.
    This is useful for deleting or modifying system or other user files on a system to ensure no errors.

    .PARAMETER FolderPath
    Define the full folder path of the item you want to take ownership of such as "C:\Users"

    .PARAMETER FilePath
    Define the full path to a single file to take ownership of such as "C:\test.txt"

    .EXAMPLE
    C:\PS> Install-MSI -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi" -FileDir "C:\windows\ltsvc\packages\softwar\superapp" -FileMSIPath "C:\windows\ltsvc\packages\softwar\superapp\superapp.msi"
  #>

  [CmdletBinding()]

  Param(
    [Parameter(
      Mandatory=$True,
      HelpMessage="Please enter the name of the application you want to install"
    )][string]$AppName,
    [string]$FileDownloadLink,
    [string]$FileDir,
    [string]$FileMSIPath,
    [Parameter(
      Mandatory=$True,
      HelpMessage="Enter all arguments to install the MSI, such as /qn and /norestart"
    )][string]$Arguments
  )

  ## call OS bit check script
  If(!$WebClient) {
    Write-Error "The $WebClient var is empty, meaning the call to GitHub with the token to access the private repo doesn't exist."
    Return
  } Else {
    ($WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Get-OSBit.ps1') | iex
    $osVer = Get-OSBit
  }

  Try {
    If(!(Test-Path $fileDir)) {
      New-Item -ItemType Directory $fileDir | Out-Null
    }

    If(!(Test-Path $FileMSIPath -PathType Leaf)) {
      ($WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Get-FileDownload.ps1') | iex
      Get-FileDownload -FileURL $FileDownloadLink -DestinationFile $FileMSIPath
      If(!(Test-Path $FileMSIPath -PathType Leaf)) {
        Write-Error "Failed to download $FileDownloadLink"
        Break
      }
    }
  } Catch {
    Write-Error "Failed to download all required files"
  }
  #endregion checkFiles


  Start-Process msiexec.exe -Wait -ArgumentList "/i ""$FileMSIPath"" $Arguments"
  Write-Host "$AppName installation complete"
  #endregion installVAC
}
