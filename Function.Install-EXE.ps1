Function Install-EXE {
  <#
    .SYNOPSIS
    Install-EXE allows you to easily downooad and install an application via EXE

    .DESCRIPTION
    This allows you to define as little as just the download link for the EXE installer and the rest
    will be auto filled for you. If you decide to define more flags, like install dir or arguments,
    you will need to make sure these values are complete and in quotes if there are spaces. See examples
    for more informaiton.

    .PARAMETER AppName
    Define the name of your application. This will be used as the folder name for the downlaoded file, and
    the name of the installer EXE oce downloaded.

    .PARAMETER FileDownloadLink
    This will be the download link to the EXE file. Make sure to include the FULL URL including the http://

    .PARAMETER FileDir
    This is the directory the download files and install logs will be saved to. If you leave this undefined,
    it will default to %windir%\LTSvc\packages\Software\AppName

    .PARAMETER FileEXEPath
    The full path to the EXE installer. If you had a specific location to the EXE file you would define it here.
    Keep in mind you do not have to define the -FileDownloadLink flag, so if you already had a local file or a
    network share file you can just define the path to it here.

    .PARAMETER LogPath
    The full path to where you want the installation logs saved. By default, the logs will be saved in the same
    directory as your install files in %windir%\LTSvc\packages\Software\AppName\Install Log - App Name.txt

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the EXE.

    .EXAMPLE
    C:\PS> Install-EXE -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.EXE -Arguments "/silent""
    C:\PS> Install-EXE -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.EXE" -FileEXEPath "C:\windows\ltsvc\packages\softwar\superapp\superapp.EXE" -Arguments "/s""
  #>

  [CmdletBinding()]

  Param(
    [Parameter(
      Mandatory=$True,
      HelpMessage="Please enter the name of the application you want to install"
    )][string]$AppName,
    [string]$FileDownloadLink,
    [string]$FileDir,
    [string]$FileEXEPath,
    [Parameter(
      Mandatory=$True,
      HelpMessage="Enter all arguments to install the EXE, such as /s or /silent"
    )][string]$Arguments
  )

  Try {
    If (!$FileDir) {
      $FileDir = "$env:windir\LTSvc\packages\software\$AppName"
    }
    If(!(Test-Path $FileDir)) {
      New-Item -ItemType Directory $FileDir | Out-Null
    }

    If (!$FileEXEPath) {
      $FileEXEPath = "$FileDir\$($AppName).EXE"
    }
    If(!(Test-Path $FileEXEPath -PathType Leaf)) {
      (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileEXEPath)
      }

    If (!$LogPath) {
      "$LogPath = $FileDir\Install Log - $($AppName).txt"
    }
  } Catch {
    Write-Error "Failed to download $FileDownloadLink to $FileEXEPath"
  }
  #endregion checkFiles

  Try {
    Start-Process $FileEXEPath -Wait -ArgumentList $Arguments
    Write-Host "$AppName installation complete"
    #endregion installVAC
  } Catch {
    Write-Error "Failed to install $AppName"
  }
}
