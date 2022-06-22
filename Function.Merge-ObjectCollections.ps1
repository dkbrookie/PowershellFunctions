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

# Fix TLS
Try {
  # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
  [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
} Catch {
  Write-Host "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
  # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
  $psVers = $PSVersionTable.PSVersion

  If ($psVers.Major -lt 3) {
    Write-Host "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
  }
}

# Call in Merge-Objects
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Merge-Objects.ps1') | Invoke-Expression

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
