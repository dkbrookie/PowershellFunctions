<#

Check-VersionString

xxNOTE: While using similar semantics, DOES NOT adhere to semver specxx

Checks two version strings against one another and returns $True or $False signaling whether the -Version string satisfies the
requirement defined by the -CheckAgainst string. Only supports exact match, carrot `^`, `x` and tilde `~` characters.

An exact match only returns true if the two strings match exactly and DO NOT contain a carrot or a `x` character.

If a carrot exists as the first character of the CheckAgainst string, the Version string will pass if it is any version larger than
the specified version.

If a `x` exists as one of the digits, any version will pass, from the point of the `x` onward.

.Parameter CheckAgainst
Specifies the required/benchmark version string

.Parameter Version
Specifies the version string being tested which will be checked against the CheckAgainst version string

.Example


#>
Function Check-VersionString {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $True)]
    [string]$CheckAgainst,
    [Parameter(Mandatory = $True)]
    [string]$Version
  )

  # If they're an exact match, or $CheckAgainst is 'x' on its own, we can quickly call that a pass
  If (($Version -eq $CheckAgainst) -or ('x' -eq $CheckAgainst)) { Return $True }

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
    $toCheckSameLength = $Version.split('.')[0..($checkAgainstWithoutX.length - 1)]

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

  # If there's a carrot in the string, we want to pass if $Version is larger
  If (($CheckAgainst -like '*^*') -and ($Version -gt $CheckAgainst.split('^')[-1])) {
    Return $True
  }

  Return $False
}

Function Test-CheckVersionString {
  $failedTests = @()
  $ErrorActionPreference = 'Continue'

  function Format-Output ($name, $expected, $value, $tests) {
    Return "Failed Test $($tests.length + 1): $name failed! Expected '$expected' but got '$value'"
  }

  # Make sure the function exists
  If (!(Get-Command 'Check-VersionString')) {
    $failedTests += 'Check-VersionString does not exist! Cannot run tests!'
  }

  # Exact true tests
  $exactOne = Check-VersionString -Version '1' -CheckAgainst '1'
  $exactTwo = Check-VersionString -Version '1.2' -CheckAgainst '1.2'
  $exactThree = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2.3'

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
  $higherExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2.2'
  $lowerExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2.4'
  $lessSpecificExact = Check-VersionString -Version '1.2' -CheckAgainst '1.2.4'
  $moreSpecificExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2'


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
  $higherCarrot = Check-VersionString -Version '1.2.3' -CheckAgainst '^1.2.2'
  $lowerCarrot = Check-VersionString -Version '1.2.3' -CheckAgainst '^1.2.4'
  $lessSpecificCarrot = Check-VersionString -Version '1.2' -CheckAgainst '^1.2.4'
  $moreSpecificCarrot = Check-VersionString -Version '1.2.3' -CheckAgainst '^1.2'
  $higherMajorCarrot = Check-VersionString -Version '3.1.3' -CheckAgainst '^1.2'
  $lowerMajorCarrot = Check-VersionString -Version '1.4.3' -CheckAgainst '^2.2'

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

  # X tests
  $patchXExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2.x'
  $patchXHigher = Check-VersionString -Version '1.3.3' -CheckAgainst '1.2.x'
  $patchXLower = Check-VersionString -Version '1.1.3' -CheckAgainst '1.2.x'

  $minorXExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.x'
  $minorXHigher = Check-VersionString -Version '1.3.3' -CheckAgainst '1.x'
  $minorXLower = Check-VersionString -Version '1.1.3' -CheckAgainst '1.x'
  $minorXMajorHigher = Check-VersionString -Version '2.1.3' -CheckAgainst '1.x'
  $minorXMajorLower = Check-VersionString -Version '0.1.3' -CheckAgainst '1.x'

  $majorXOne = Check-VersionString -Version '1' -CheckAgainst 'x'
  $majorXTwo = Check-VersionString -Version '1.2' -CheckAgainst 'x'
  $majorXThree = Check-VersionString -Version '1.2.3' -CheckAgainst 'x'

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
