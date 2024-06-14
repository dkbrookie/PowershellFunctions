<#

Test-VersionString

**NOTE: While using similar semantics, DOES NOT adhere to semver spec**

Checks two version strings against one another and returns $True or $False signaling whether the -StringToCheck string satisfies the
requirement defined by the -CheckAgainst string. Only supports exact match, carrot `^`, and `x` characters.

An exact match only returns true if the two strings match exactly and DO NOT contain a carrot or a `x` character.

If a carrot exists as the first character of the CheckAgainst string, the Version string will pass if it is any version larger than
the specified version.

If an `x` exists as one of the digits, any version will pass, from the point of the `x` onward.

.Parameter CheckAgainst
Specifies the required/benchmark version string

.Parameter StringToCheck
Specifies the version string being tested which will be checked against the CheckAgainst version string

.Example
Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '^1.2.3'
# returns $True

.Example
Test-VersionString -StringToCheck '1.2.2' -CheckAgainst '^1.2.3'
# returns $False

.Example
Test-VersionString -StringToCheck '1.3.3' -CheckAgainst '1.x'
# returns $True

.Example
Test-VersionString -StringToCheck '2.1.3' -CheckAgainst '1.x'
# returns $False
#>
Function Test-VersionString {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $True)]
    [string]$CheckAgainst,
    [Parameter(Mandatory = $True)]
    [string]$StringToCheck
  )

  # If they're an exact match, or $CheckAgainst is 'x' on its own, we can quickly call that a pass
  If (($StringToCheck -eq $CheckAgainst) -or ('x' -eq $CheckAgainst)) { Return $True }

  $CheckAgainst = $CheckAgainst.replace('*', 'x')

  If ($CheckAgainst -like '*x*') {
    If ($CheckAgainst -like '*^*') { Throw '$CheckAgainst can ONLY contain a carrot OR a `x`, not both!'; Return; }

    # Ensure the `x` is in the last position
    If ($CheckAgainst[-1] -ne 'x') { Throw 'An `x` needs to be the LAST character, like: 1.2.x NOT 1.x.3'; Return; }

    # Ensure the `x` is immediately following a dot as long as there are dots ('x' by itself shouldn't throw)
    If (($CheckAgainst[-2] -ne '.') -and ($CheckAgainst.split('.').length -gt 1)) {
      Throw "An `x` needs to be the only character in its group, like: 1.2.x NOT 1.2.3x. Got: $CheckAgainst"; Return; }

    ###
    # Remove the group with the `x` and remove the same group and anything following from the version string being checked
    ###

    # Split by dot and remove the x and the dot (1.2.x becomes 1.2)
    $numSectionsCheckAgainst = $CheckAgainst.split('.').length - 2
    $checkAgainstWithoutX = $CheckAgainst.split('.')[0..$numSectionsCheckAgainst]

    # Make the "to check" the same number of sections b/c we don't care about anything after the '.x' (using the same 'checkagainst' as above, 1.4.5 becomes 1.4)
    $toCheckSameLength = $StringToCheck.split('.')[0..($checkAgainstWithoutX.length - 1)]

    # Loop through each entry in each string and check each against eachother from beginning to end
    # If any section in 'to check' is not equal to the corresponding section in 'check against' then the string we're checking has failed
    For ($i = 0; $i -lt $checkAgainstWithoutX.length; $i++) {
      $toCheckSection = $toCheckSameLength[$i]
      $checkAgainstSection = $checkAgainstWithoutX[$i]

      If ($toCheckSection -ne $checkAgainstSection) {
        # If $toCheckSection is not the same as $checkAgainstSection, it failed
        Return $False
      }
    }

    # If we made it all the way through the loop without returning $False, we can return $True
    Return $True
  }

  # If there's a carrot in the string, we want to pass if $StringToCheck is larger OR the same (after removing the carrot)
  If (($CheckAgainst -like '*^*')) {
    If (($StringToCheck -gt $CheckAgainst.split('^')[-1]) -or ($StringToCheck -eq $CheckAgainst.replace('^', ''))) {
      Return $True
    }
  }

  Return $False
}

Function Test-TestVersionString {
  $failedTests = @()
  $ErrorActionPreference = 'Continue'

  function Format-Output ($name, $expected, $value, $tests) {
    Return "Failed Test $($tests.length + 1): $name failed! Expected '$expected' but got '$value'"
  }

  # Make sure the function exists
  If (!(Get-Command 'Test-VersionString')) {
    $failedTests += 'Test-VersionString does not exist! Cannot run tests!'
  }

  # Exact true tests
  $exactOne = Test-VersionString -StringToCheck '1' -CheckAgainst '1'
  $exactTwo = Test-VersionString -StringToCheck '1.2' -CheckAgainst '1.2'
  $exactThree = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.2.3'

  # These should all be $True
  If ($exactOne -ne $True) {
    $failedTests += Format-Output '$exactOne' $True  $exactOne  $failedTests
  }

  If ($exactTwo -ne $True) {
    $failedTests += Format-Output '$exactTwo' $True $exactTwo $failedTests
  }

  If ($exactThree -ne $True) {
    $failedTests += Format-Output '$exactThree' $True $exactThree $failedTests
  }

  # ------------------------------------------------------------------------- #

  # Exact false tests
  $higherExact = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.2.2'
  $lowerExact = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.2.4'
  $lessSpecificExact = Test-VersionString -StringToCheck '1.2' -CheckAgainst '1.2.4'
  $moreSpecificExact = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.2'


  # These should all be $False
  If ($higherExact -ne $False) {
    $failedTests += Format-Output '$higherExact' $False $higherExact $failedTests
  }

  If ($lowerExact -ne $False) {
    $failedTests += Format-Output '$lowerExact' $False $lowerExact $failedTests
  }

  If ($lessSpecificExact -ne $False) {
    $failedTests += Format-Output '$lessSpecificExact' $False $lessSpecificExact $failedTests
  }

  If ($moreSpecificExact -ne $False) {
    $failedTests += Format-Output '$moreSpecificExact' $False $moreSpecificExact $failedTests
  }

  # ------------------------------------------------------------------------- #

  # Carrot tests
  $sameCarrot = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '^1.2.3'
  $higherCarrot = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '^1.2.2'
  $lowerCarrot = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '^1.2.4'
  $lessSpecificCarrot = Test-VersionString -StringToCheck '1.2' -CheckAgainst '^1.2.4'
  $moreSpecificCarrot = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '^1.2'
  $higherMajorCarrot = Test-VersionString -StringToCheck '3.1.3' -CheckAgainst '^1.2'
  $lowerMajorCarrot = Test-VersionString -StringToCheck '1.4.3' -CheckAgainst '^2.2'
  $hugeMinorCarrot = Test-VersionString -StringToCheck '1.4345.3' -CheckAgainst '^2.2'
  $hugePatchCarrot = Test-VersionString -StringToCheck '1.4.3657543' -CheckAgainst '^2.2'

  # Expecting $True
  If ($sameCarrot -ne $True) {
    $failedTests += Format-Output '$sameCarrot' $True $sameCarrot $failedTests
  }

  # Expecting $True
  If ($higherCarrot -ne $True) {
    $failedTests += Format-Output '$higherCarrot' $True $higherCarrot $failedTests
  }

  # Expecting $False
  If ($lowerCarrot -ne $False) {
    $failedTests += Format-Output '$lowerCarrot' $False $lowerCarrot $failedTests
  }

  # Expecting $False
  If ($lessSpecificCarrot -ne $False) {
    $failedTests += Format-Output '$lessSpecificCarrot' $False $lessSpecificCarrot $failedTests
  }

  # Expecting $True
  If ($moreSpecificCarrot -ne $True) {
    $failedTests += Format-Output '$moreSpecificCarrot' $True $moreSpecificCarrot $failedTests
  }

  # Expecting $True
  If ($higherMajorCarrot -ne $True) {
    $failedTests += Format-Output '$higherMajorCarrot' $True $higherMajorCarrot $failedTests
  }

  # Expecting $False
  If ($lowerMajorCarrot -ne $False) {
    $failedTests += Format-Output '$lowerMajorCarrot' $False $lowerMajorCarrot $failedTests
  }

  # Expecting $False
  If ($hugeMinorCarrot -ne $False) {
    $failedTests += Format-Output '$hugeMinorCarrot' $False $hugeMinorCarrot $failedTests
  }

  # Expecting $False
  If ($hugePatchCarrot -ne $False) {
    $failedTests += Format-Output '$hugePatchCarrot' $False $hugePatchCarrot $failedTests
  }

  # X tests
  $patchXExact = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.2.x'
  $patchXHigher = Test-VersionString -StringToCheck '1.3.3' -CheckAgainst '1.2.x'
  $patchXLower = Test-VersionString -StringToCheck '1.1.3' -CheckAgainst '1.2.x'

  $minorXExact = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst '1.x'
  $minorXHigher = Test-VersionString -StringToCheck '1.3.3' -CheckAgainst '1.x'
  $minorXLower = Test-VersionString -StringToCheck '1.1.3' -CheckAgainst '1.x'
  $minorXMajorHigher = Test-VersionString -StringToCheck '2.1.3' -CheckAgainst '1.x'
  $minorXMajorLower = Test-VersionString -StringToCheck '0.1.3' -CheckAgainst '1.x'

  $majorXOne = Test-VersionString -StringToCheck '1' -CheckAgainst 'x'
  $majorXTwo = Test-VersionString -StringToCheck '1.2' -CheckAgainst 'x'
  $majorXThree = Test-VersionString -StringToCheck '1.2.3' -CheckAgainst 'x'

  If ($patchXExact -ne $True) {
    $failedTests += Format-Output '$patchXExact' $False $patchXExact $failedTests
  }
  If ($patchXHigher -ne $False) {
    $failedTests += Format-Output '$patchXHigher' $False $patchXHigher $failedTests
  }
  If ($patchXLower -ne $False) {
    $failedTests += Format-Output '$patchXLower' $False $patchXLower $failedTests
  }

  If ($minorXExact -ne $True) {
    $failedTests += Format-Output '$minorXExact' $True $minorXExact $failedTests
  }
  If ($minorXHigher -ne $True) {
    $failedTests += Format-Output '$minorXHigher' $True $minorXHigher $failedTests
  }
  If ($minorXLower -ne $True) {
    $failedTests += Format-Output '$minorXLower' $True $minorXLower $failedTests
  }
  If ($minorXMajorHigher -ne $False) {
    $failedTests += Format-Output '$minorXMajorHigher' $False $minorXMajorHigher $failedTests
  }
  If ($minorXMajorLower -ne $False) {
    $failedTests += Format-Output '$minorXMajorLower' $False $minorXMajorLower $failedTests
  }

  If ($majorXOne -ne $True) {
    $failedTests += Format-Output '$majorXOne' $True $majorXOne $failedTests
  }
  If ($majorXTwo -ne $True) {
    $failedTests += Format-Output '$majorXTwo' $True $majorXTwo $failedTests
  }
  If ($majorXThree -ne $True) {
    $failedTests += Format-Output '$majorXThree' $True $majorXThree $failedTests
  }

  # Enumerate results
  $numFailed = $failedTests.length
  If ($numFailed -gt 0) {
    Write-Output ($failedTests -join "`n")
    Write-Output "`n"
    Write-Output "xxxx --------- $numFailed tests failed --------- xxxx"
  } Else {
    Write-Output "Congratulations! All tests passed!"
  }
}
