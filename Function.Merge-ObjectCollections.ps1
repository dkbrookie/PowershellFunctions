Function Merge-ObjectCollections {
    [CmdletBinding()]
    param (
      [hashtable[]]
      $Left,
      [hashtable[]]
      $Right,
      [Parameter(Mandatory=$True)]
      [string]
      $MatchKey
    )

    # If both right and left are missing, just return an empty hashtable array
    If (($Left.Length -eq 0) -and ($Right.Length -eq 0)) {
      Return @(@{})
    }

    # If $Left is missing / empty, we can just return right as-is
    If ($Left.Length -eq 0) {
      Return $Right
    }

    # If $Right is missing / empty, we can just return left as-is
    If ($Right.Length -eq 0) {
      Return $Left
    }

    $newArr = @()

    $Right | ForEach-Object {
      $entry = $_
      $leftMatchingEntry = $Left | Where-Object { $_[$MatchKey] -eq $entry[$MatchKey] }
      $rightMatchingEntry = $Right | Where-Object { $_[$MatchKey] -eq $entry[$MatchKey] }

      # If Left doesn't have an entry with this MatchKey, we can just add the entry to the Left collection
      If (!$leftMatchingEntry) {
        $newArr += $entry
        Return
      }

      If ($rightNumMatching -gt 1) {
        Throw "The collection provided to Merge-Collection must have unique -MatchKey values. There were $rightNumMatching entries with -MatchKey '$MatchKey' value of '$($entry[$MatchKey])'"
      }

      # If Left doesn't have an entry with this MatchKey, we can just return it
      If (!$leftMatchingEntry) {
        Return $entry
      }

      # If Left does have an entry with a matching matchkey, we need to pick through the properties and replace them where an override exists,
      # allow non-overridden keys to stay, and add any new ones
      # $leftNotMatchingEntries = $Left | Where-Object { $_[$MatchKey] -ne $entry[$MatchKey] }

      $leftMatchingEntry.Keys | ForEach-Object {
        $name = $_
        $rightValue = $entry[$name]
        $leftValue = $leftMatchingEntry[$name]

        # If the same key exists in the right, assign it to the left
        If ($Null -ne $rightValue) {
          $newHashtable[$name] = $rightValue
        } ElseIf (($Null -eq $rightValue) -and ($entry.ContainsKey($name))) {
          # Entry exists on the right, but it's explicity set to $Null which signals we should delete it from the result. NO ACTION here causes this result.
          # Purposeful No-Op
        } Else {
          $newHashtable[$name] = $leftValue
        }
      }

      # We have to get wild here b/c of powershell's strange implicit casting behavior... If we don't define a new array and reassign, we end up
      # with a dictionary instead of an array and an error stating that we can't add another entry with a matching property "Name"?

      $newArr += $leftNotMatchingEntries
      $newArr += $newHashtable
    }

    Return $newArr
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
          Prop3 = $True
          Obj = @{
            SomeKey = 'SomeValue'
            AnotherKey = 'a value'
          }
        }
      )
      Users = @(
        @{
          Name                = 'Base Workstation Local Admin Control'
          LocalAdmins         = @('wks_dkbtech', 'lcl_dkbtech')
          EnforceAddListed    = $False
          EnforceRemoveOthers = $False
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
            Prop3 = $Null
            Obj = @{
              SomeKey = 'SomeOtherValue'
              AnotherKey = 'some value'
            }
          }
          @{
            Name = 'Test2'
            Prop1 = $True
          }
        )
      }

      Users      = @{
        MatchKey = 'Name'
        Entries  = @(
          @{
            Name        = 'DKB Specific Local Admin Control'
            LocalAdmins = @('dkb')
          }
        )
      }
    }

    $softwareResult = Merge-ObjectCollections -Left $configuration.Software -Right $overrideConfig.Software.Entries -MatchKey $overrideConfig.Software.MatchKey
    $usersResult = Merge-ObjectCollections -Left $configuration.Users -Right $overrideConfig.Users.Entries -MatchKey $overrideConfig.Users.MatchKey

    $testEntry = $result | Where-Object { $_.Name -eq 'Test' }
    $test2Entry = $result | Where-Object { $_.Name -eq 'Test2' }

    $softwareResultLength = $testEntry.length
    If ($softwareResultLength -ne 1) {
      Throw "there is not exactly 1 entry for 'Test' ! There are $softwareResultLength!"
    }

    $prop1 = $testEntry.Prop1
    If ($prop1 -ne $True) {
      Throw "Prop1 of test entry is not True! It is '$prop1'"
    }

    $prop2 = $testEntry.Prop1
    If ($prop2 -ne $True) {
      Throw "Prop2 of test entry is not True! It is '$prop2'"
    }

    $prop3 = $testEntry.Prop3
    If ($Null -ne $prop3) {
      Throw "Prop3 of test entry should not exist! It does! It is '$prop3'"
    }

    $prop1_2 = $test2Entry.Prop1
    If ($prop1_2 -ne $True) {
      Throw "Prop1 of test2 entry is not True! It is '$prop1_2'"
    }

    $someKey = $testEntry.Obj.SomeKey
    If ($someKey -ne 'SomeOtherValue') {
      Throw "Expected Obj.SomeKey to equal 'SomeOtherValue' but it did not. Instead, it was '$someKey'"
    }

    $defenderEntry = $softwareResult | Where-Object { $_.Name -eq 'Defender' }
    $defenderEntryLength = $defenderEntry.length
    If ($defenderEntryLength -ne 1) {
      Throw "Defender was not exactly 1 in quantity! There were $defenderEntryLength entries!"
    }

    If ($defenderEntry.Type -ne 'Script') {
      Throw "Defender entry type was not 'Script!"
    }

    $usersResultLength = $usersResult.length
    If ($usersResultLength -ne 2) {
      Throw "Expected `$usersResult.length to be 2! It was: $usersResultLength"
    }

    Write-Output "All tests passed!"
  }
