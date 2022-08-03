<#
  .Description
  Receives either `Hashtable` or `string array` as input and writes output as newline delimited string or a pipe delimited string using `Write-Output`

  If input is `-InputObject` which expects a `Hashtable`, output will be single pipe delimited string mapping keys to values with equals sign in between key and value

  If input is `-InputStringArray` which expects a `string array`, output will be a single newline delimited string

  If a value of `-InputObject` is an array, the array of arrays will be flattened out into a single string. This is recursive and can handle any arbitrary depth of arrays.

  .Example
  # -InputObject example
  $messages = @('Here is a message.', 'Another message.')

  $blah = @{
    output = $messages
    someField = 1
    anotherField = 0
  }

  Invoke-Output $blah

  # Outputs:
  output=Here is a message.`n`nAnother message.|someField=1|anotherField=0

  .Example
  # -InputStringArray example
  $messages = @('Here is a message.', 'Another message.')

  Invoke-Output $messages

  # Outputs:
  Here is a message.`n`nAnother message.

  .Example
  # Nested array item example
  $messages = @('Here is a message.', @('Nested array.'), 'Another message.')

  $blah = @{
    output = $messages
    someField = 1
    anotherField = 0
  }

  Invoke-Output $blah

  # Outputs:
  output=Here is a message. Nested array. Another message.|someField=1|anotherField=0
#>

# Fix TLS
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)

# Call in Flatten-Array
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Flatten-Array.ps1') | Invoke-Expression

Function Invoke-Output {
  Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True, Position = 0, ParameterSetName = 'Hashtable')]
    [Hashtable]$InputObject,
    [Parameter(Mandatory = $True, ValueFromPipeline = $True, Position = 0, ParameterSetName = 'String')]
    [AllowEmptyCollection()]
    [AllowNull()]
    [string[]]$InputStringArray
  )

  If ($InputObject) {
    $out = ''

    $InputObject.GetEnumerator() | ForEach-Object { $i = 1 } {
      $value = Flatten-Array $_.Value
      $item = "$($_.Name)=$value"

      If ($i -lt $InputObject.Count) {
        $item += '|'
      }

      $out += $item

      $i++
    }

    Write-Output $out
  } ElseIf ($InputStringArray) {
    Write-Output ($InputStringArray -join "`n`n")
  }
}
