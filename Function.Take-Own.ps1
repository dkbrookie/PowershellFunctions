Function Take-Own {
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
    C:\PS> Take-Own -FolderPath C:\Users
    C:\PS> Take-Own -FolderPath C:\Users -SuppressResults $True
    C:\PS> Take-Own -FolderPath C:\Users -SuppressResults $False
    C:\PS> Take-Own -FilePath C:\test.txt -SuppressResults $False

    .NOTES
    Another way to take ownership I might wanna look into later is icacls "full path of folder or drive" /setowner "Administrators" /T /C.
    Tried this on my own machine while troubleshooting an issues and seems like it might be a better option than "takeown" since takeown
    just takes ownership as admin group and using the icacls ownership method you can specify users and groups.
  #>

  [CmdletBinding()]

  Param(
    [string]$FolderPath,
    [string]$FilePath,
    [string]$SuppressResults
  )

  If(!$FolderPath -and !$FilePath) {
    Write-Output "You must define the -FolderPath or -FilePath parameter. Use 'Get-Help Take-Own' and 'Get-Help Take-Own -Examples' for help."
    Return
  }

  If(!$SuppressResults) {
    $SuppressResults = $True
  }

  If($SuppressResults -eq $True) {
    If($FilePath) {
      echo y| takeown /F $FilePath /A | Out-Null
      echo y| cacls $FilePath /C /grant administrators:F | Out-Null
    }
    ElseIf($FolderPath) {
      echo y| takeown /F $FolderPath\* /R /A | Out-Null
      echo y| cacls $FolderPath\*.* /T /grant administrators:F | Out-Null
    } Else {
      Write-Output "No input for the -FolderPath or -FilePath parameters was provided. Use 'Get-Help Take-Own' and 'Get-Help Take-Own -Examples' for help."
    }
  } Else {
    If($FilePath) {
      echo y| takeown /F $FilePath /A | Out-Null
      echo y| cacls $FilePath /C /grant administrators:F
    }
    ElseIf($FolderPath) {
      echo y| takeown /F $FolderPath\* /R /A
      echo y| cacls $FolderPath\*.* /T /grant administrators:F
    } Else {
      Write-Output "No input for the -FolderPath or -FilePath parameters was provided. Use 'Get-Help Take-Own' and 'Get-Help Take-Own -Examples' for help."
    }
    Write-Output "Take-Own tasks completed"
  }
}
