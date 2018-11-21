Function Get-FileDownload {
  [CmdletBinding()]

  Param(
      [Parameter(Mandatory = $True)]
      [string]$FileURL,
      [Parameter(Mandatory = $True)]
      [string]$Destination
  )

  Try {
    Start-BitsTransfer -Source $FileURL -Destination $Destination
    }
  } Catch {
    Write-Error "There was an error while trying to download 7zip"
  }
}
