<#
  .Description
  Receives either `Hashtable`, or `string array` as input and writes output as newline delimited string or a pipe delimited string using `Write-Host`

  If input is `-InputObject` which expects a `Hashtable`, output will be single pipe delimited string mapping keys to values with equals sign in between key and value

  If input is `-InputStringArray` which expects a `string array`, output will be a single newline delimited string

  .Example
  # -InputObject example
  $blah = @{
    output='Here is a message.', 'Another message.'
    someField=1
    anotherField=0
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
#>

Function Invoke-Output {
  Param (
    [Parameter(Mandatory = $True, ValueFromPipeline = $True, Position = 0, ParameterSetName='Hashtable')]
    [Hashtable]$InputObject,
    [Parameter(Mandatory = $True, ValueFromPipeline = $True, Position = 0, ParameterSetName='String')]
    [string[]]$InputStringArray
  )

  If ($InputObject) {
    $out = ''

    $InputObject.GetEnumerator() | ForEach-Object { $i = 1 } {
      $value = $_.Value
      $name = $_.Name

      # We already know input is a hashtable, but we want to make sure that every item in the hashtable is either a string or an array of strings
      If ($value.GetType().BaseType.Name -eq 'Array') {
        ForEach ($entry in $value) {
          If ($entry.GetType().Name -ne 'String') {
            Write-Output "Invoke-Output Error: Entry named '$($name)' is not valid because Invoke-Output can only handle hashtables with values of type [string] or [string[]] (array of strings). Entry named '$($name)' contained type '$($entry.GetType().BaseType.Name)'`n`n"
            $value = $value | Where-Object { $_ -ne $entry }
          }
        }

        $value = $value -join "`n`n"
      }

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
