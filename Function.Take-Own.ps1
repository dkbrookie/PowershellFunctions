Function Take-Own {
  <#
    .SYNOPSIS
    Take-Own

    .DESCRIPTION
    Take-Own force takes ownership to the Administrators group over the entire folder path you define in -FolderPath. This is
    useful for deleting or modifying system or other user files on a system to ensure no errors.

    .PARAMETER FolderPath
    Define the full folder path of the itme you want to take control over such as "C:\Users"

    .EXAMPLE
    C:\PS> Take-Own -FolderPath C:\Users
    C:\PS> Take-Own -FolderPath C:\Users -SuppressResults $True
    C:\PS> Take-Own -FolderPath C:\Users -SuppressResults $False
  #>

  [CmdletBinding()]

  Param(
    [Parameter(Mandatory = $True)]
    [string]$FolderPath,
    [string]$SuppressResults
  )

  If(!$FolderPath) {
    Write-Output "You must define the -FolderPath parameter. Use 'Get-Help Take-Own' and 'Get-Help Take-Own -Examples' for help."
    Return
  }

  If(!$SuppressResults) {
    $SuppressResults = $True
  }

  If($SuppressResults -eq $True) {
    echo y| takeown /F $FolderPath\* /R /A | Out-Null
    echo y| cacls $FolderPath\*.* /T /grant administrators:F | Out-Null
  } Else {
    echo y| takeown /F $FolderPath\* /R /A
    echo y| cacls $FolderPath\*.* /T /grant administrators:F
    Write-Output "Take-Own tasks completed"
  }
}
