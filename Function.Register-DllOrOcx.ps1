# Register-DllOrOcx stolen from https://powershelladministrator.com/2019/12/17/register-dll-or-ocx-files-check-result/

# This is not fully tested. Please remove this line once tested and confident.

# Call in Search-Registry
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Search-Registry.ps1') | Invoke-Expression

function Register-DllOrOcx {
  param (
    [Parameter(Mandatory=$true)]
    [string]$Path
  )

  $outputLog = @()

  $filename = ($Path -split '\\')[-1]

  #The main script starts here
  $registerProc = Start-Process "$env:SystemRoot\System32\regsvr32.exe" "/s $Path" -Wait -PassThru
  $exitCode = $registerProc.ExitCode

  If ($exitCode -ne 0) {
    $outputLog += "Attempt to register $filename may not have been successful as the process exit code was $exitCode."
  }

  # Now check to make sure it registered properly

  Try {
    #Create a new PSDrive, as powershell doesn't have a default drive for HKEY_CLASSES_ROOT
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
  } Catch {
    $outputLog = $outputLog + '!Fail: Could not search the registry to verify registration. Creating PSDrive for HKCR failed'
    Return $outputLog
  }

  #Search the registry for the file
  $success = Search-Registry -Path "hkcr:\TypeLib" -Recurse -ValueDataRegex "$fileName"

  If ($success){
    $outputLog = "!Success: Registry value found for $fileName." + $outputLog
  } Else {
    $outputLog = "!Fail: Registry value not found for $fileName." + $outputLog
  }

  Try {
    #Remove the PSDrive that was created
    Remove-PSDrive -Name HKCR
  } Catch {
    $outputLog += 'Could not remove HKCR PSDrive for some reason...'
  }

  Return $outputLog
}
