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
        Break
      }
    }

    # Can't continue if there are any duplicates of MatchKey value in left
    $Left | Foreach-Object {
      $val = $_[$MatchKey]
      $length = ($Left | Where-Object { $_[$MatchKey] -eq $val }).Length
      If ($length -gt 1) {
        Throw "Entries in collection on -Left must have have unique values for '$MatchKey' property! There were $length entries with '$MatchKey' of '$val'!"
        Break
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


            $newHashtable[$_] = $rightEntry[$_]
            } Else {
              # TODO: check for hashtable type and recursively call function
              $newHashtable[$_] = $rightEntryValue
            }
          } Else {
            $newHashtable[$_] = $leftMatching[$_]
          }

          # Remove props from right as we go so that we can add any non-matched ones later
          $rightEntry.Remove($_)
        }

        # Add any remaining right properties to the new hashtable, these were unmatched so they haven't been handled yet
        $rightEntry.Keys | ForEach-Object {
          $newHashtable[$_] = $rightEntry[$_]
        }
      } Else {
        # No match for this right entry, so just add the entry as-is
        $newHashtable = $rightEntry
      }

      # Add the new hashtable we built into the new array we're building
      $newArr += $newHashtable
    }

    # Find top level matches on the left and add properties that didn't exist to their right match
    # $leftMatches |

    # Grab top level entries from the left that don't have a match on the right
    $leftNotMatchingEntries = $Left | Foreach-Object {
      # As long as this entry from $Left doesn't exist in $leftMatches return it
      If ($leftMatches.IndexOf($_) -eq -1) {
        Return $_
      }
    }

    $newArr += $leftNotMatchingEntries

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
          TestProp1 = $False
          TestProp3 = $True
          TestObj1 = @{
            SomeTestKey = 'SomeValue'
            AnotherTestKey = 'a value'
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
              SomeTestKey = 'SomeOtherValue'
              AnotherTestKey = 'some value'
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

    $softwareResult = Merge-ObjectCollections -Left $configuration.Software -Right $overrideConfig.Software.Entries -MatchKey $overrideConfig.Software.MatchKey
    $usersResult = Merge-ObjectCollections -Left $configuration.Users -Right $overrideConfig.Users.Entries -MatchKey $overrideConfig.Users.MatchKey
    $testEntry = $softwareResult | Where-Object { $_.Name -eq 'Test' }
    $test2Entry = $softwareResult | Where-Object { $_.Name -eq 'Test2' }

    $softwareResultLength = $testEntry.length
    If ($softwareResultLength -ne 1) {
      Throw "There is not exactly 1 entry for 'Test' ! There are $softwareResultLength!"
    }

    $prop1 = $testEntry.TestProp1
    If ($prop1 -ne $True) {
      Throw "Right prop override left - TestProp1 of test entry is not True! It is '$prop1'"
    }

    $prop2 = $testEntry.TestProp2
    If ($prop2 -ne $True) {
      Throw "Exist in Right but not in left - TestProp2 of test entry is not True! It is '$prop2'"
    }

    $prop3 = $testEntry.TestProp3
    If ($Null -ne $prop3) {
      Throw "Null in right deletes entry - TestProp3 of test entry should not exist! It does! It is '$prop3'"
    }

    $prop1_2 = $test2Entry.Test2Prop1
    If ($prop1_2 -ne $True) {
      Throw "Top level from right that doesn't exist in left makes it through - Test2Prop1 of test2 entry is not True! It is '$prop1_2'"
    }

    $someKey = $testEntry.TestObj1.SomeTestKey
    If ($someKey -ne 'SomeOtherValue') {
      Throw "Expected TestObj1.SomeTestKey to equal 'SomeOtherValue' but it did not. Instead, it was '$someKey'"
    }

    $defenderEntry = $softwareResult | Where-Object { $_.Name -eq 'Defender' }
    $defenderEntryLength = $defenderEntry.length
    If ($defenderEntryLength -ne 1) {
      Throw "Top level from left that doesn't exist in right makes it through - Defender was not exactly 1 in quantity! There were $defenderEntryLength entries!"
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
