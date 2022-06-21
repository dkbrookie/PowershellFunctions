<#
Merge-Objects

.DESCRIPTION
This function will merge two objects (hashtables) and return one. The merge strategy is similar to what SQL would call a "FULL JOIN" and it works recursively
in the case of nested objects. If you're familiar with javascript's 'lodash' library, it's very similar to lodash's 'merge' function. All properties from both
objects will appear in the result, recursively. In the case of a property collision, the right property takes priority and will replace the left property value
with the right property value. If either `Left` or `Right` argument is missing, this function acts as a passthrough for the hashtable that was provided. If both
are missing, an empty hashtable will be returned. If a Right or Left value is an object and the matching value on the other side is not, recursion will not take
place and instead the right value will fully replace the left value. You can remove any property from the results by setting the right side value to $Null.

.PARAMETER Left
The base object that is to be superseded by the Right object

.PARAMETER Right
An object defining the values that will supersede the values on the Left object

.EXAMPLE
$config = @{
  SomePropertyThatWillStay = 'value1'
  SomePropertyThatWillBeReplaced = 'value2'

  ObjectThatShouldBeAString = @{
    InconsequentialProp = 'inconsequential value'
  }

  SomeObject = @{
    SomePropertyThatWillStay = 'value3'
    SomePropertyThatWillBeReplaced = 'value4'

    DeepObject = @{
      SomePropertyThatWillBeRemoved = 'value5'
      SomePropertyThatWillStay = 'value6'
    }
  }
}

$configOverride = @{
  SomePropertyThatWillBeReplaced = 'replacement value 1'

  AnObjectThatShouldBeAString = 'replacement value 2'

  SomeObject = @{
    SomePropertyThatWillBeReplaced = 'replacement value 3'

    DeepObject = @{
      SomePropertyThatWillBeRemoved = $Null
      SomeNewProperty = 'new value 1'
    }
  }
}

Merge-Objects -Left $config -Right $configOverride

# Outputs an object that looks like this:
@{
  SomePropertyThatWillStay = 'value1'
  SomePropertyThatWillBeReplaced = 'replacement value 1'

  ObjectThatShouldBeAString = 'replacement value 2'

  SomeObject = @{
    SomePropertyThatWillStay = 'value3'
    SomePropertyThatWillBeReplaced = 'replacement value 3'

    DeepObject = @{
      SomeNewProperty = 'new value 1'
      SomePropertyThatWillStay = 'value6'
    }
  }
}
#>

Function Merge-Objects {
  param (
    $Left,
    $Right
  )

  $newHashtable = @{}

  If (!$Left) { $Left = @{} }
  If (!$Right) { $Right = @{} }

  # If there's a matching left entry for this right entry, now check for matching keys, if a matching key is found, replace it with right
  $Left.Keys | Foreach-Object {
    $rightValue = $Right[$_]
    $leftValue = $Left[$_]

    If ($Right.ContainsKey($_)) {
      If ($Null -eq $rightValue) {
        # no-op, a $null entry is a purposeful removal
      } ElseIf (($rightValue.GetType().Name -eq 'Hashtable') -and ($leftValue.GetType().Name -eq 'Hashtable')) {
        # If both values are hashtables, recurse. If only one side is a hashtable, we just want to replace left with right
        $newHashtable[$_] = Merge-Objects -Left $leftValue -Right $rightValue
      } Else {
        $newHashtable[$_] = $rightValue
      }
    } Else {
      $newHashtable[$_] = $leftValue
    }

    # Remove matched props from right as we go so that we can add any non-matched ones later
    $Right.Remove($_)
  }

  # Add any remaining right properties to the new hashtable, these were unmatched so they belong in the result as long as values aren't null
  $Right.Keys | ForEach-Object {
    $val = $Right[$_]

    If (($Null -ne $val)) {
      $newHashtable[$_] = $val
    }
  }

  Return $newHashtable
}

<#
Merge-ObjectCollections

.DESCRIPTION
Performs Merge-Object an an array of objects. Objects in the array are merged recursively when values match between any property defined by the MatchKey
parameter. The MatchKey parameter should be a string that defines the Name of the object property that should be matched. Objects on either side that don't have
a match will be passed through to the resulting array as-is. See description of Merge-Object to better understand how that function works.

.PARAMETER Left
The base array of objects that will be superseded by the any matching objects in the Right array or passed through if no match is found.

.PARAMETER Right
The array of objects that will supersede the Left array of objects if a match is found, or passed through to the resulting array if no match is found.

.EXAMPLE
$array1 = @(
  @{
    prop1 = 'a name'
    prop2 = $False
    prop3 = $True
    prop4 = 'words'
  },
  @{
    prop1 = 'something else'
    prop2 = $True
  }
)

$array2 = @(
  @{
    prop1 = 'a name'
    prop2 = $Null
    prop3 = $False
  },
  @{
    prop1 = 'something different'
    prop2 = $True
  }
)

Merge-ObjectCollections -Left $array1 -Right $array2 -MatchKey 'prop1'

# Outputs an array like this
@(
  # This came from $array1 but was modified by $array2 because the value of prop1 (the MatchKey) matched
  @{
    prop1 = 'a name'

    # prop2 was deleted

    # prop3 was replaced with the value from $array2
    prop3 = $False

    # prop4 is unmodified
    prop4 = 'words'
  },

  # this came from $array1
  @{
    prop1 = 'something else'
    prop2 = $True
  },

  # This came from $array2
  @{
    prop1 = 'something different'
    prop2 = $True
  }
)

#>
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

      If ($leftMatching.Length -eq 1) {
        # We landed at a matching entry, so merge the two
        $newHashtable = Merge-Objects -Left $leftMatching -Right $rightEntry
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

function New-TestData {
  Return @{
    Configuration = @{
      Software = @(
        @{
          Name = 'Defender'
          Type = 'Script'
        },
        @{
          Name      = 'Test'
          TestProp1 = $False
          TestProp3 = $True
          TestProp5 = $True
          TestProp6 = $True
          TestProp7 = 'blha blah'
          TestObj1  = @{
            SomeTestKey    = 'SomeValue'
            AnotherTestKey = 'a value'
          }
          TestObj2  = @{
            Blah = 'blah'
          }
          TestObj4  = @{
            SomeTestKey4    = 'SomeValue'
            AnotherTestKey4 = 'a value'
          }
          TestObj5 = @{
            SomeKey = 'some object property'
          }
          TestObj6 = 'some string value'
        }
        @{
          Name      = 'Test3'
          Test3Prop = $True
        }
      )
      Users    = @(
        @{
          Name                = 'Base Workstation Local Admin Control'
          LocalAdmins         = @('wks_dkbtech', 'lcl_dkbtech')
          EnforceAddListed    = $False
          EnforceRemoveOthers = $False
        }
      )
    }

    OverrideConfig = @{
      Software = @{
        MatchKey = 'Name'
        Entries  = @(
          @{
            Name      = 'Test'
            TestProp1 = $True
            TestProp2 = $True
            TestProp3 = $Null
            TestProp4 = $Null
            TestProp6 = $False
            TestProp7 = ''
            TestObj1  = @{
              SomeTestKey    = 'SomeOtherValue'
              AnotherTestKey = 'some value'
            }
            TestObj3  = @{
              Barf = 'bleefh'
            }
            TestObj4  = @{
              AnotherTestKey4 = 'a new value'
            }
            TestObj5 = 'some other string value'
            TestObj6 = @{
              SomeKey = 'some other object property'
            }
          },
          @{
            Name       = 'Test2'
            Test2Prop1 = $True
          },
          @{
            Name           = 'Test3'
            RemoveThisItem = $True
          },
          @{
            Name           = 'Test4'
            RemoveThisItem = $True
          }
        )
      }

      Users    = @{
        MatchKey = 'Name'
        Entries  = @(
          @{
            Name        = 'DKB Specific Local Admin Control'
            LocalAdmins = @('dkb')
          }
        )
      }
    }
  }
}

function Format-Output ($name, $expected, $value, $tests) {
  Return "Failed Test $($tests.length + 1): '$name' failed! Expected '$expected' but got '$value'"
}

Function Test-MergeObjects {
  $testData = New-TestData

  $failedTests = @()
  $ErrorActionPreference = 'Continue'

  $defenderConfig = $testData.Configuration.Software | Where-Object { $_.Name -eq 'Defender' }
  $defenderOverride = $testData.OverrideConfig.Software.Entries | Where-Object { $_.Name -eq 'Defender' }
  $defenderResult = Merge-Objects -Left $defenderConfig -Right $defenderOverride

  $hasType = $defenderResult.ContainsKey('Type')
  If ($hasType -ne $True) {
    $failedTests += Format-Output 'When object exists on left but not on right, it should be in result' $True $hasType $failedTests
  }

  $defenderResult2 = Merge-Objects -Left $defenderOverride -Right $defenderConfig

  $hasType2 = $defenderResult2.ContainsKey('Type')
  If ($hasType2 -ne $True) {
    $failedTests += Format-Output 'When object exists on right but not on left, it should be in result' $True $hasType2 $failedTests
  }

  $testConfig = $testData.Configuration.Software | Where-Object { $_.Name -eq 'Test' }
  $testOverride = $testData.OverrideConfig.Software.Entries | Where-Object { $_.Name -eq 'Test' }
  $testResult = Merge-Objects -Left $testConfig -Right $testOverride

  $prop1 = $testResult.TestProp1
  If ($prop1 -ne $True) {
    $failedTests += Format-Output "Right prop should override matching left" $True $prop1 $failedTests
  }

  $prop2 = $testResult.TestProp2
  If ($prop2 -ne $True) {
    $failedTests += Format-Output "Right prop should be in result when missing from left" $True $prop2 $failedTests
  }

  $prop3 = $testResult.ContainsKey('TestProp4')
  If ($False -ne $prop3) {
    $failedTests += Format-Output "Null in right removes item from result" $False $prop3 $failedTests
  }

  $prop4 = $testResult.ContainsKey('TestProp4')
  If ($False -ne $prop4) {
    $failedTests += Format-Output "Null in right that doesn't exist in left still does not end up in result" $False $prop4 $failedTests
  }

  $prop5 = $testResult.TestProp5
  If ($prop5 -ne $True) {
    $failedTests += Format-Output "Left prop should be in result when missing from right" $True $prop5 $failedTests
  }

  $prop6 = $testResult.TestProp6
  If ($prop6 -ne $False) {
    $failedTests += Format-Output "Right prop should override matching left even when overridden value is False" $True $prop6 $failedTests
  }

  $prop7 = $testResult.TestProp7
  If ($prop7 -ne '') {
    $failedTests += Format-Output "Right prop should override matching left even when overridden value is empty string" $True $prop7 $failedTests
  }

  $someKey = $testResult.TestObj1.SomeTestKey
  $anotherKey = $testResult.TestObj1.AnotherTestKey
  If (($someKey -ne 'SomeOtherValue') -or ($anotherKey -ne 'some value')) {
    $msg = "When there is an object as a value, and that object has multiple matching properties, all the properties should be overridden"
    $failedTests += Format-Output $msg "('SomeOtherValue', 'some value')" "('$someKey', '$anotherKey')" $failedTests
  }

  $anotherKey4 = $testResult.TestObj4.AnotherTestKey4
  If ($anotherKey4 -ne 'a new value') {
    $failedTests += Format-Output "A property inside an object property that does exist in the overriding object gets overridden. Expected TestObj4.SomeTestKey to equal 'SomeValue' but it did not. Instead, it was '$someKey'"
  }

  $someKey4 = $testResult.TestObj4.SomeTestKey4
  If ($someKey4 -ne 'SomeValue') {
    $msg = "An object as a value, and that object does have a match on right but does not have a matching property, that property should be in the result"
    $failedTests += Format-Output $msg 'SomeValue' $someKey4 $failedTests
  }

  $someObj5 = $testResult.TestObj5
  If ($someObj5 -ne 'some other string value') {
    $msg = "When left value is a hashtable, but right value is a string, result should be the string"
    $failedTests += Format-Output $msg 'some other string value' $someObj5 $failedTests
  }

  $someObj6 = $testResult.TestObj6
  If ($someObj6.SomeKey -ne 'some other object property') {
    $msg = "When left value is a hashtable, but right value is a string, result should be the string"
    $failedTests += Format-Output $msg 'some other object property' $someObj6 $failedTests
  }

  # Enumerate results
  $numFailed = $failedTests.length
  If ($numFailed -gt 0) {
    Write-Output ($failedTests -join "`n")
    Write-Output "`n"
    Write-Output "xxxx --------- $numFailed tests failed --------- xxxx"
  } Else {
    Write-Output "Congratulations! All Test-MergeObjects tests passed!"
  }
}

Function Test-MergeObjectCollections {
  $testData = New-TestData

  $failedTests = @()
  $ErrorActionPreference = 'Continue'

  $softwareResult = Merge-ObjectCollections -Left $testData.Configuration.Software -Right $testData.OverrideConfig.Software.Entries -MatchKey $testData.OverrideConfig.Software.MatchKey
  $usersResult = Merge-ObjectCollections -Left $testData.Configuration.Users -Right $testData.OverrideConfig.Users.Entries -MatchKey $testData.OverrideConfig.Users.MatchKey

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
  } Else {
    Write-Output "Congratulations! All Test-MergeObjectCollections tests passed!"
  }
}
