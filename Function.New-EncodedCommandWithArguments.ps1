

Function New-EncodedCommandWithArguments {
  <#
  .SYNOPSIS
  Preps a scriptblock + arguments for that scriptblock in a scheduled task
  .DESCRIPTION
  Converts a script block into a string that contains an encoded version of Scriptblock which can be stored in a scheduled task for use later with
  powershell.exe's -Command parameter. This method allows you to store the command as a base64 string which allows you to write a ScriptBlock in pure
  powershell without worrying about escaping special characters. Normally this practice keeps you from passing arguments to the script block, but with this
  method, passing arguments to the scriptblock is possible. Please note that arguments are NOT base64 encoded, only the scriptblock is base64 encoded.
  .EXAMPLE
  PS> powershell.exe -Command (New-EncodedCommandWithArguments -ScriptBlock { param($a, $b) $a + $b } -ArgumentList @(2, 2) | Invoke-Expression)
  # outputs 22
  .EXAMPLE
  PS> $task = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -Command $(New-EncodedCommandWithArguments -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList)"
  # Creates a scheduled task action that will execute the $ScriptBlock with the provided $ArgumentList
  #>
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $true)]
    [scriptblock]
    $ScriptBlock,
    [Parameter(Mandatory = $false)]
    [string[]]
    $ArgumentList
  )

  Try {
    $base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($ScriptBlock))
  } Catch {
    Throw "Could not convert the command to a base64 encoded string. The error was: $_"
  }

  # TODO: Currently only accepts string values in ArgumentList.. Assess whether this is acceptable. For instance { param($a, $b) $a + b } @(2, 2) returns '22'
  # Would be preferable if values could be completely untouched.
  Return '''Invoke-Command -ScriptBlock { param([string]$sb, [Object[]]$ArgumentList) ' +
    '$ScriptBlock = [ScriptBlock]::Create([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($sb))); ' +
    'Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList } ' +
    "-ArgumentList @(''$base64'', `"@(''$($ArgumentList -join "'', ''")'')`")'"
}
