Function Merge-ObjectCollections {
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$True)]
      [hashtable[]]
      $Left,
      [Parameter(Mandatory=$True)]
      [hashtable[]]
      $Right,
      [Parameter(Mandatory=$True)]
      [string]
      $MatchKey
    )

    $Right | ForEach-Object {
      $entry = $_
      $leftMatchingEntry = $Left | Where-Object { $_[$MatchKey] -eq $entry[$MatchKey] }

      # If Left doesn't have an entry with this MatchKey, we can just add the entry to the Left collection
      If (!$leftMatchingEntry) {
        $Left += $entry
        Return
      }

      $numMatching = $leftMatchingEntry.length

      If ($numMatching -gt 1) {
        Throw "The collection provided to Merge-Collection must have unique -MatchKey values. There were $numMatching entries with -MatchKey '$MatchKey' value of '$($entry[$MatchKey])'"
      }

      # If Left does have an entry with a matching matchkey, we need to pick through the properties and replace them where an override exists,
      # allow non-overridden keys to stay, and add any new ones
      $leftNotMatchingEntries = $Left | Where-Object { $_[$MatchKey] -ne $entry[$MatchKey] }

      $newHashtable = @{}

      $leftMatchingEntry.Keys | ForEach-Object {
        $name = $_
        $rightValue = $entry[$name]
        $leftValue = $leftMatchingEntry[$name]

        # If the same key exists in the right, assign it to the left
        If ($Null -ne $rightValue) {
          $newHashtable[$name] = $rightValue
        } Else {
          $newHashtable[$name] = $leftValue
        }
      }

      # We have to get wild here b/c of powershell's strange implicit casting behavior... If we don't define a new array and reassign, we end up
      # with a dictionary instead of an array and an error stating that we can't add another entry with a matching property "Name"?

      $newArr = @()

      $newArr += $leftNotMatchingEntries
      $newArr += $newHashtable

      Return $newArr
    }
  }

  Function Test-MergeObjectCollections {
    $configuration = @{
      Software = @(
        @{
          Name = 'Defender'
          Type = 'Script'
        },
        @{
          Name = 'Test'
          Prop1 = $False
          Obj = @{
            SomeKey = 'SomeValue'
            AnotherKey = 'a value'
          }
        }
      )
    }

    $overrideConfig = @{
      Software = @{
        MatchKey = 'Name'
        Entries = @(
          @{
            Name = 'Test'
            Prop1 = $True
            Prop2 = $True
            Obj = @{
              SomeKey = 'SomeOtherValue'
              AnotherKey = 'some value'
            }
          }
        )
      }
    }

    $result = Merge-ObjectCollections -Left $configuration.Software -Right $overrideConfig.Software.Entries -MatchKey $overrideConfig.Software.MatchKey

    $testEntry = $result | Where-Object { $_.Name -eq 'Test' }

    $resultLength = $testEntry.length
    If ($resultLength -ne 1) {
      Throw "there is not exactly 1 entry for 'Test' ! There are $resultLength!"
    }

    $prop1 = $testEntry.Prop1
    If ($prop1 -ne $True) {
      Throw "Prop1 is not True! It is $prop1"
    }

    $prop2 = $testEntry.Prop1
    If ($prop2 -ne $True) {
      Throw "Prop2 is not True! It is $prop2"
    }

    $someKey = $testEntry.Obj.SomeKey
    If ($someKey -ne 'SomeOtherValue') {
      Throw "Expected Obj.SomeKey to equal 'SomeOtherValue' but it did not. Instead, it was '$someKey'"
    }

    $defenderEntry = $result | Where-Object { $_.Name -eq 'Defender' }
    $defenderEntryLength = $defenderEntry.length
    If ($defenderEntryLength -ne 1) {
      Throw "Defender was not exactly 1 in quantity! There were $defenderEntryLength entries!"
    }

    If ($defenderEntry.Type -ne 'Script') {
      Throw "Defender entry type was not 'Script!"
    }

    Write-Output "All tests passed!"
  }
