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

      # If array item has property "RemoveThisItem" and it's true, this array item should not be in the result whether it exists on the left or the right
      If ($rightEntry.ContainsKey('RemoveThisItem') -and $rightEntry.RemoveThisItem -eq $True) {
        Return
      }

      # If there's a matching left entry for this right entry, now check for matching keys, if a matching key is found, replace it with right
      If ($leftMatching.Length -eq 1) {
        $leftMatching.Keys | Foreach-Object {
          $rightEntryValue = $rightEntry[$_]

          If ($rightEntry.ContainsKey($_)) {
            If ($Null -eq $rightEntryValue) {
              # no-op, a $null entry is a purposeful removal
            } Else {
              $newHashtable[$_] = $rightEntryValue
            }
          } Else {
            $newHashtable[$_] = $leftMatching[$_]
          }

          # Remove matched props from right as we go so that we can add any non-matched ones later
          $rightEntry.Remove($_)
        }

        # Add any remaining right properties to the new hashtable, these were unmatched so they belong in the result as long as values aren't null
        $rightEntry.Keys | ForEach-Object {
          $val = $rightEntry[$_]

          If (($Null -ne $val)) {
            $newHashtable[$_] = $val
          }
        }
      } Else {
        # No match for this right entry, so just add the entry as-is
        $newHashtable = $rightEntry
      }

      # Add the new hashtable we built into the new array we're building
      $newArr += $newHashtable
    }

    # Grab array items from the left that don't have a match on the right
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
          TestObj4 = @{
            SomeTestKey4 = 'SomeValue'
            AnotherTestKey4 = 'a value'
          }
        }
        @{
          Name = 'Test3'
          Test3Prop = $True
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
            TestProp4 = $Null
            TestObj1 = @{
              SomeTestKey = 'SomeOtherValue'
              AnotherTestKey = 'some value'
            }
            TestObj3 = @{
              Barf = 'bleefh'
            }
            TestObj4 = @{
              AnotherTestKey4 = 'a new value'
            }
          },
          @{
            Name = 'Test2'
            Test2Prop1 = $True
          },
          @{
            Name = 'Test3'
            RemoveThisItem = $True
          },
          @{
            Name = 'Test4'
            RemoveThisItem = $True
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

    $failedTests = @()
    $ErrorActionPreference = 'Continue'

    function Format-Output ($name, $expected, $value, $tests) {
      Return "Failed Test $($tests.length + 1): '$name' failed! Expected '$expected' but got '$value'"
    }

    $softwareResult = Merge-ObjectCollections -Left $configuration.Software -Right $overrideConfig.Software.Entries -MatchKey $overrideConfig.Software.MatchKey
    $usersResult = Merge-ObjectCollections -Left $configuration.Users -Right $overrideConfig.Users.Entries -MatchKey $overrideConfig.Users.MatchKey

    $testEntry = $softwareResult | Where-Object { $_.Name -eq 'Test' }
    $test2Entry = $softwareResult | Where-Object { $_.Name -eq 'Test2' }
    $test3Entry = $softwareResult | Where-Object { $_.Name -eq 'Test3' }
    $test4Entry = $softwareResult | Where-Object { $_.Name -eq 'Test4' }

    $softwareResultLength = $testEntry.length
    If ($softwareResultLength -ne 1) {
      $failedTests += Format-Output "There should be 1 entry for 'Test'" 1 $softwareResultLength $failedTests
    }

    $prop1 = $testEntry.TestProp1
    If ($prop1 -ne $True) {
      $failedTests += Format-Output "Right prop of array item should override matching left" $True $prop1 $failedTests
    }

    $prop2 = $testEntry.TestProp2
    If ($prop2 -ne $True) {
      $failedTests += Format-Output "Right prop of array item that doesn't exist in corresponding left array item should end up in result" $True $prop2 $failedTests
    }

    $prop3 = $testEntry.ContainsKey('TestProp4')
    If ($False -ne $prop3) {
      $failedTests += Format-Output "Null in right array item removes item from result" $False $prop3 $failedTests
    }

    $prop4 = $testEntry.ContainsKey('TestProp4')
    If ($False -ne $prop4) {
      $failedTests += Format-Output "Null in right array item that doesn't exist in left still does not end up in result" $False $prop4 $failedTests
    }

    $prop1_2 = $test2Entry.Test2Prop1
    If ($prop1_2 -ne $True) {
      $failedTests += Format-Output "Array item from right that doesn't exist in left makes it through as is" $True $prop1_2 $failedTests
    }

    $someKey = $testEntry.TestObj1.SomeTestKey
    $anotherKey = $testEntry.TestObj1.AnotherTestKey
    If (($someKey -ne 'SomeOtherValue') -or ($anotherKey -ne 'some value')) {
      $msg = "An array item with an object as a value, and that object has multiple matching properties, all the properties should be overridden"
      $failedTests += Format-Output $msg "('SomeOtherValue', 'some value')" "('$someKey', '$anotherKey')" $failedTests
    }

    $anotherKey4 = $testEntry.TestObj4.AnotherTestKey4
    If ($anotherKey4 -ne 'a new value') {
      $failedTests += Format-Output "A property inside an object property that does exist in the overriding object gets overridden. Expected TestObj4.SomeTestKey to equal 'SomeValue' but it did not. Instead, it was '$someKey'"
    }

    $someKey4 = $testEntry.TestObj4.SomeTestKey4
    If ($someKey4 -ne 'SomeValue') {
      $msg = "A Left array item with an object as a value, and that object does have a match on right but does not have a matching property, that property should be in the result"
      $failedTests += Format-Output $msg 'SomeValue' $someKey4 $failedTests
    }

    If ($test3Entry.length -ne 0) {
      $failedTests += Format-Output "When 'RemoveThisItem' is set to true in an array item on the right and the array item exists on the left, the array item should not exist in the result" 0 $test3Entry.length $failedTests
    }

    If ($test4Entry.length -ne 0) {
      $failedTests += Format-Output "When 'RemoveThisItem' is set to true in an array item on the right and the array item does not exist on the left, the array item should not exist in the result" 0 $test4Entry.length $failedTests
    }

    $defenderEntry = $softwareResult | Where-Object { $_.Name -eq 'Defender' }
    $defenderEntryLength = $defenderEntry.length
    If ($defenderEntryLength -ne 1) {
      $failedTests += Format-Output "Top level from left that doesn't exist in right makes it through - Defender was not exactly 1 in quantity! There were $defenderEntryLength entries!"
    }

    If ($defenderEntry.Type -ne 'Script') {
      $failedTests += Format-Output "Defender entry type was not 'Script!"
    }

    $usersResultLength = $usersResult.length
    If ($usersResultLength -ne 2) {
      $failedTests += Format-Output "Expected `$usersResult.length to be 2! It was: $usersResultLength"
    }

    # Enumerate results
    $numFailed = $failedTests.length
    If ($numFailed -gt 0) {
      Write-Output ($failedTests -join "`n")
      Write-Output "`n"
      Write-Output "xxxx --------- $numFailed tests failed --------- xxxx"
    }
    Else {
      Write-Output "Congratulations! All tests passed!"
    }
  }
