Function Get-InstalledApp {
  <#
    .SYNOPSIS
    Get-InstalledApp

    .DESCRIPTION
    Finds the current install status of an application. If the application is NOT installed, the return will be NULL, if an
    application IS installed, the return will be $True

    .PARAMETER AppName
    In quotes define the app name in question exactly as it's seen in Add Remove Programs in Control Panel

    .EXAMPLE
    C:\PS> Get-InstalledApp -AppName 'Microsoft SQL Server 2016'
  #>

  [CmdletBinding()]

  Param(
      [Parameter(Mandatory = $True)]
      [string]$AppName
  )

  If([IntPtr]::Size -eq 4) {
    $regPath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  } Else {
    $regPath = @(
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
      'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
  }
  $result = Get-ItemProperty $regPath | .{process{If($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString | Where { $_.DisplayName -eq $AppName }
  If($result) {
    $True
  }
}
