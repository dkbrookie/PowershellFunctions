Function Get-FileDownload {
  <#
    .SYNOPSIS
    Get-FileDownload

    .DESCRIPTION
    Downlaods a file using either the Bits protocol or the .NET protocol.

    .PARAMETER FileURL
    Enter the full direct URL to the file

    .PARAMETER DestinationFile
    Enter the full path to the destination file including the extension.

    .PARAMETER TransferType
    You can use the Bits download method instead of the standard .NET method by specifying the value of this as Bits.
    If this is not defined at all, the download will by default use the .NET method. Note the BITS method requires
    Powershell 3 or higher.

    .EXAMPLE
    C:\PS> Get-FileDownload -FileURL https://domain.com/file/file.txt -DestinationFolder C:\temp\file.txt
    C:\PS> Get-FileDownload -FileURL https://domain.com/file/file.txt -DestinationFolder C:\temp\file.txt -TransferType Bits
  #>
  [CmdletBinding()]
  Param(
      [Parameter(Mandatory = $True)]
      [string]$FileURL,
      [Parameter(Mandatory = $True)]
      [string]$DestinationFile,
      [string]$TransferType
  )

  $startTime = Get-Date

  If($TransferType -eq 'Bits') {
    Try {
      Start-BitsTransfer -Source $FileURL -Destination $DestinationFile
      Write-Output "Download Complete! Download Total Time: $((Get-Date).Subtract($startTime).Seconds) second(s)"
    } Catch {
      Write-Error "There was an error while trying to download $FileURL"
    }
  } ElseIf($TransferType -eq 'IWR') {
    Try {
      Invoke-WebRequest -Uri $FileURL -OutFile $DestinationFile
      Write-Output "Download Complete! Download Total Time: $((Get-Date).Subtract($startTime).Seconds) second(s)"
    } Catch {
      Write-Error "There was an error while trying to download $FileURL"
    }
  } Else {
    Try {
      (New-Object System.Net.WebClient).DownloadFile($FileURL,$DestinationFile)
      Write-Output "Download Complete! Download Total Time: $((Get-Date).Subtract($startTime).Seconds) second(s)"
    } Catch {
      Write-Error "There was an error while trying to download $FileURL"
    }
  }
}
