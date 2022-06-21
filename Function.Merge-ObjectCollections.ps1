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

    # Can't continue if there are any duplicates of MatchKey value in right
    $Right | Foreach-Object {
      $val = $_[$MatchKey]
      $length = ($Right | Where-Object { $_[$MatchKey] -eq $val }).Length
      If ($length -gt 1) {
        Throw "Entries in collection on -Right must have have unique values for '$MatchKey' property! There were $length entries with '$MatchKey' of '$val'!"
      }
    }

    # Can't continue if there are any duplicates of MatchKey value in left
    $Left | Foreach-Object {
      $val = $_[$MatchKey]
      $length = ($Left | Where-Object { $_[$MatchKey] -eq $val }).Length
      If ($length -gt 1) {
        Throw "Entries in collection on -Left must have have unique values for '$MatchKey' property! There were $length entries with '$MatchKey' of '$val'!"
      }
    }

    $newArr = @()
    $leftMatches = @()

    # Find Matches from right to left by comparing MatchKey value, if matches are found, we want to merge them
    $Right | Foreach-Object {
      $newHashtable = @{}
      $rightEntry = $_
      $rightVal = $rightEntry[$MatchKey]
      $leftMatching = $Left | Where-Object { $_[$MatchKey] -eq $rightVal }

      # Compile a list of all left entries that had a match from the right so we can remove them from $Left later
      $leftMatches += $leftMatching

      # If there's a matching left entry for this right entry, now check for matching keys, if a matching key is found, replace it with right
      If ($leftMatching.Length -eq 1) {
        $leftMatching.Keys | Foreach-Object {
          $rightEntryValue = $rightEntry[$_]
          If ($rightEntry.ContainsKey($_)) {
            If ($Null -eq $rightEntryValue) {
              # no-op, a $null entry is a purposeful removal
            } ElseIf (($rightEntryValue.GetType().Name -eq 'Hashtable')) {
              $newHashtable[$_] = 'Overridden object'
            } Else {
              # TODO: check for hashtable type and recursively call function
              $newHashtable[$_] = $rightEntryValue
            }
          } Else {
            $newHashtable[$_] = $leftMatchingValue
          }
        }
      } Else {
        # No match for this right entry, so just add the entry as-is
        Write-Output '-------------'
        Write-Output $rightEntry
        Write-Output '-------------'
        $newHashtable = $rightEntry
      }

      # Add the new object we built into the new array we're building
      $newArr += $newHashtable
    }

    # Grab entries from the left that don't have a match on the right
    $leftNotMatchingEntries = $Left | Foreach-Object {
      # As long as this entry from $Left doesn't exist in $leftMatches return it
      If ($leftMatches.IndexOf($_) -eq -1) {
        Return $_
      }
    }

    $newArr += $leftNotMatchingEntries

    Write-Output $newArr

    # $Right | Foreach-Object {


    # }

    # $newArr = @()

    # $Right | ForEach-Object {
    #   $entry = $_
    #   $leftMatchingEntry = $Left | Where-Object { $_[$MatchKey] -eq $entry[$MatchKey] }
    #   $rightMatchingEntry = $Right | Where-Object { $_[$MatchKey] -eq $entry[$MatchKey] }

    #   # If Left doesn't have an entry with this MatchKey, we can just add the entry to the Left collection
    #   If (!$leftMatchingEntry) {
    #     $newArr += $entry
    #     Return
    #   }

    #   If ($rightNumMatching -gt 1) {
    #     Throw "The collection provided to Merge-Collection must have unique -MatchKey values. There were $rightNumMatching entries with -MatchKey '$MatchKey' value of '$($entry[$MatchKey])'"
    #   }

    #   # If Left doesn't have an entry with this MatchKey, we can just return it
    #   If (!$leftMatchingEntry) {
    #     Return $entry
    #   }

    #   # If Left does have an entry with a matching matchkey, we need to pick through the properties and replace them where an override exists,
    #   # allow non-overridden keys to stay, and add any new ones
    #   # $leftNotMatchingEntries = $Left | Where-Object { $_[$MatchKey] -ne $entry[$MatchKey] }

    #   # $newHashtable = @{}

    #   Return $leftMatchingEntry

    #   $leftMatchingEntry.Keys | ForEach-Object {
    #     $name = $_
    #     $rightValue = $entry[$name]
    #     $leftValue = $leftMatchingEntry[$name]

    #     Write-Output 'right', $rightValue
    #     Write-Output 'left', $leftValue

    #     # If the same key exists in the right, assign it to the left
    #     If ($Null -ne $rightValue) {
    #       $newHashtable[$name] = $rightValue
    #     } ElseIf (($Null -eq $rightValue) -and ($entry.ContainsKey($name))) {
    #       # Entry exists on the right, but it's explicity set to $Null which signals we should delete it from the result. NO ACTION here causes this result.
    #       # Purposeful No-Op
    #     } Else {
    #       $newHashtable[$name] = $leftValue
    #     }
    #   }

    #   # We have to get wild here b/c of powershell's strange implicit casting behavior... If we don't define a new array and reassign, we end up
    #   # with a dictionary instead of an array and an error stating that we can't add another entry with a matching property "Name"?

    #   $newArr += $leftNotMatchingEntries
    #   $newArr += $newHashtable
    # }

    # Return $newArr
  }

  Function Test-MergeObjectCollections {
    $configuration = @{
      $Software = @(
        @{
          Name = 'Defender'
          Type = 'Script'
        },
        @{
          Name = 'Test'
          Prop1 = $False
          Prop3 = $True
          TestObj1 = @{
            SomeKey = 'SomeValue'
            AnotherKey = 'a value'
          }
          TestObj2 = @{
            Blah = 'blah'
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
            TestProp1 = $True
            TestProp2 = $True
            TestProp3 = $Null
            TestObj1 = @{
              SomeKey = 'SomeOtherValue'
              AnotherKey = 'some value'
            }
            TestObj3 = @{
              Barf = 'bleefh'
            }
          },
          @{
            Name = 'Test2'
            Test2Prop1 = $True
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

    # $softwareResult = Merge-ObjectCollections -Left $configuration.Software -Right $overrideConfig.Software.Entries -MatchKey $overrideConfig.Software.MatchKey
    $usersResult = Merge-ObjectCollections -Left $configuration.Users -Right $overrideConfig.Users.Entries -MatchKey $overrideConfig.Users.MatchKey
    Write-Output $usersResult
  #   $testEntry = $softwareResult | Where-Object { $_.Name -eq 'Test' }
  #   $test2Entry = $softwareResult | Where-Object { $_.Name -eq 'Test2' }

  #   $softwareResultLength = $testEntry.length
  #   If ($softwareResultLength -ne 1) {
  #     Throw "there is not exactly 1 entry for 'Test' ! There are $softwareResultLength!"
  #   }

  #   $prop1 = $testEntry.Prop1
  #   If ($prop1 -ne $True) {
  #     Throw "Prop1 of test entry is not True! It is '$prop1'"
  #   }

  #   $prop2 = $testEntry.Prop1
  #   If ($prop2 -ne $True) {
  #     Throw "Prop2 of test entry is not True! It is '$prop2'"
  #   }

  #   $prop3 = $testEntry.Prop3
  #   If ($Null -ne $prop3) {
  #     Throw "Prop3 of test entry should not exist! It does! It is '$prop3'"
  #   }

  #   $prop1_2 = $test2Entry.Prop1
  #   If ($prop1_2 -ne $True) {
  #     Throw "Prop1 of test2 entry is not True! It is '$prop1_2'"
  #   }

  #   $someKey = $testEntry.Obj.SomeKey
  #   If ($someKey -ne 'SomeOtherValue') {
  #     Throw "Expected Obj.SomeKey to equal 'SomeOtherValue' but it did not. Instead, it was '$someKey'"
  #   }

  #   $defenderEntry = $softwareResult | Where-Object { $_.Name -eq 'Defender' }
  #   $defenderEntryLength = $defenderEntry.length
  #   If ($defenderEntryLength -ne 1) {
  #     Throw "Defender was not exactly 1 in quantity! There were $defenderEntryLength entries!"
  #   }

  #   If ($defenderEntry.Type -ne 'Script') {
  #     Throw "Defender entry type was not 'Script!"
  #   }

  #   $usersResultLength = $usersResult.length
  #   If ($usersResultLength -ne 2) {
  #     Throw "Expected `$usersResult.length to be 2! It was: $usersResultLength"
  #   }

  #   Write-Output "All tests passed!"
  }
