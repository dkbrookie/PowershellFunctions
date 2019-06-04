Function Install-MSI {
  <#
    .SYNOPSIS
    Install-MSI allows you to easily downooad and install an application via MSI

    .DESCRIPTION
    This allows you to define as little as just the download link for the MSI installer and the rest
    will be auto filled for you. If you decide to define more flags, like install dir or arguments,
    you will need to make sure these values are complete and in quotes if there are spaces. See examples
    for more informaiton.

    .PARAMETER AppName
    Define the name of your application. This will be used as the folder name for the downlaoded file, and
    the name of the installer MSI oce downloaded.

    .PARAMETER FileDownloadLink
    This will be the download link to the MSI file. Make sure to include the FULL URL including the http://

    .PARAMETER FileDir
    This is the directory the download files and install logs will be saved to. If you leave this undefined,
    it will default to %windir%\LTSvc\packages\Software\AppName

    .PARAMETER FileMSIPath
    The full path to the MSI installer. If you had a specific location to the MSI file you would define it here.
    Keep in mind you do not have to define the -FileDownloadLink flag, so if you already had a local file or a
    network share file you can just define the path to it here.

    .PARAMETER LogPath
    The full path to where you want the installation logs saved. By default, the logs will be saved in the same
    directory as your install files in %windir%\LTSvc\packages\Software\AppName\Install Log - App Name.txt

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the MSI. By defualt, /qn and /i will be applied for install
    and silent, but if you define this parameter then you will need to add /i and /qn manually. See examples...

    .EXAMPLE
    C:\PS> Install-MSI -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi"
    C:\PS> Install-MSI -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi" -FileMSIPath "C:\windows\ltsvc\packages\softwar\superapp\superapp.msi" -LogPath "C:\install log.txt"
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
    [string]$LogPath,
    [Parameter(
      HelpMessage="Enter all arguments to install the MSI, such as /qn and /norestart"
    )][string]$Arguments
  )

  Try {
    If (!$FileDir) {
      $FileDir = "$env:windir\LTSvc\packages\software\$AppName"
    }
    If(!(Test-Path $FileDir)) {
      New-Item -ItemType Directory $FileDir | Out-Null
    }

    If (!$FileMSIPath) {
      $FileMSIPath = "$FileDir\$($AppName).msi"
    }
    If(!(Test-Path $FileMSIPath -PathType Leaf)) {
      (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileMSIPath)
      }

    If (!$LogPath) {
      "$LogPath = $FileDir\Install Log - $($AppName).txt"
    }
  } Catch {
    Write-Error "Failed to download $FileDownloadLink to $FileMSIPath"
  }
  #endregion checkFiles

  Try {
    Start-Process msiexec.exe -Wait -ArgumentList "/i ""$FileMSIPath"" $Arguments /qn /l $LogPath"
    Write-Host "$AppName installation complete"
    #endregion installVAC
  } Catch {
    Write-Error "Failed to install $AppName"
  }
}
