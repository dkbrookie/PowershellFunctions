
Function Download-File {
  <#
  .SYNOPSIS
  Download-File allows you to provide a URL to a file and it will ensure that the file exists on the local machine.

  .DESCRIPTION
  Provided a URL, a storage path, and a file name, Download-File will ensure that a file exists on a target machine, downloading it if necessary.
  This is meant to be run as often as required, if the file already exists, no action is taken.

  .PARAMETER DownloadUrl
  Provide the URL to a web location that contains a file. This path should not include http:// or https:// and it should not include
  the file name or a trailing slash. https is enforced so you must be using SSL on the file download server. Example: 'files.example.com/some-directory'

  .PARAMETER StoragePath
  Provide a path to store the file on the target machine. Do not include a trailing slash. Example: 'C:\Users\Public\Pictures'

  .PARAMETER FileName
  The name of the file including the file extension, which will be used at the DownloadUrl path and also on the target machine file system.
  Example: 'wallpaper.jpg'

  .PARAMETER FileHash
  The expected SHA256 checksum for the file. Optional. If this is set, the file will be validated against the provided hash. If the hash of the downloaded
  file does not match, the file will be deleted and downloaded again. If the file is downloaded again and the hash does not match a second time, a registry
  key is set to mark this file as "bad" and it will not be tried again until this registry key is cleared.

  .PARAMETER FileSizeThreshold
  Specify the threshold at which this function should switch to using asynchronous downloads and scheduled tasks vs execution blocking synchronous downloads
  and immediate output.

  .PARAMETER RegKeyName
  Some registry values are used to track status of downloaded file, to cache the BITS job ID, etc... and RegKeyName allows you to customize the name of the
  registry key where these values are stored.

  .PARAMETER APIUrl
  If provided, will send status updates via http POST requests to the provided URL

  .PARAMETER APIKey
  If provided, API status updates will include this value

  .PARAMETER ProcessId
  If provided, API status updates will include this value

  .PARAMETER MachineId
  If provided, API status updates will include this value

  .EXAMPLE
  Download-File -DownloadUrl 'example.com/downloads' -StoragePath 'C:\Users\Public\Pictures' -FileName 'some-example.jpg'
  # This will download a file from 'https://example.com/downloads/some-example.jpg' and place it at 'C:\Users\Public\Pictures\some-example.jpg' then set that
  # as the active wallpaper for all users on the machine.

  .OUTPUTS
  Output is an object (hashtable) that contains the keys 'outputLog' and 'status'. 'outputLog' contains all messages that occurred during execution, and
  'status' is one of: 0 - "file doesn't exist", 1 - "file exists", 2 - "file exists but hash check has failed more than once"

  .NOTES
  This function uses BITS. The web server that is hosting your file MUST meet certain criteria to be compatible with BITS. It must support the
  'HTTP Range Header' for instance. Please see BITS documentation for more information. It also must support HTTPS and provide a valid SSL cert.
  #>
  Param(
    [Parameter(Mandatory = $True)]
    [string]$DownloadUrl,
    [Parameter(Mandatory = $True)]
    [string]$StoragePath,
    [Parameter(Mandatory = $True)]
    [string]$FileName,
    [Parameter(Mandatory = $False)]
    [string]$FileHash,
    [Parameter(Mandatory = $False)]
    [string]$FileSizeThreshold = '20M',
    [Parameter(Mandatory = $False)]
    [string]$RegKeyName = 'Configuration-Management',
    [Parameter(Mandatory = $False)]
    [string]$APIUrl,
    [Parameter(Mandatory = $False)]
    [string]$APIKey,
    [Parameter(Mandatory = $False)]
    [string]$ProcessId,
    [Parameter(Mandatory = $False)]
    [string]$MachineId
  )

  # TODO: Save all these error messages in the registry for future inspection and troubleshooting
  If ($APIUrl) {
    # Verify that URL is https
    If ($APIUrl -notlike 'https://*') {
      Throw "The url '$APIUrl' needs to start with 'https' but this one does not!"
      Return
    }

    # TODO: Fork/copy this and import it https://github.com/staxmanade/DevMachineSetup/blob/master/GlobalScripts/Check-Url.ps1
    # Verify the URL is valid and is responding
    If (!(Check-Url $APIUrl).IsValid) {
      Throw "The url '$APIUrl' is not returning an 'OK' response so it appears to be invalid."
      Return
    }

    $statusStarted = @{
      machineId = $MachineId
      processId = $ProcessId
      status = "Starting 'Download-File'"
    } | ConvertTo-Json

    Try {
      Invoke-WebRequest -Uri $APIUrl -Method POST -Body (ConvertTo-Json $statusStarted )
    } Catch {
      # We want to stop execution if the web request was not successful. If an APIUrl was specified, we don't want machines acting without keeping the server
      # up to date on its actions
      Throw "Was not able to make web request to identify status. The error was: $_"
      Return
    }
  }

  # Get size of file at $DownloadUrl. We need it to make some decisions.

  # If file size is greater than $FileSizeThreshold

  # function detects size of incoming file, if under a certain threshold and not on metered connection, download now synchronously.
  # If above certain threshold OR on metered connection, creates an async bits transfer and creates a scheduled task that checks on the transfer
  # every so often. When that scheduled task notices transfer is complete, it sends a web request notifying the server that the download is
  # complete so the server can take next steps. Server triggers checks once a day as well, just in case the scheduled task has been deleted or
  # interrupted in some way. Another option would be to not require a server call at all and instead put the next steps in the scheduled task.

  # Additional considerations:
  # - server-side - if more than certain threshold instances returning hash mishmatch for this file, create ticket and stop downloading - would require
  #   - "phone home" to check if should download before every download starts.
  #   - Phone home could just check for existence of a filename.proceed file at a web location before starting, or an API call
  #   - server would mark file as bad upon ticket creation
}
