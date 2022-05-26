<#

Check-VersionString

**NOTE: While using similar semantics, DOES NOT adhere to semver spec**

Checks two version strings against one another and returns $True or $False signaling whether the -Version string satisfies the
requirement defined by the -CheckAgainst string. Only supports exact match, carrot `^`, star `*` and tilde `~` characters.

An exact match only returns true if the two strings match exactly and DO NOT contain a carrot or a star character.

If a carrot exists as the first character of the CheckAgainst string, the Version string will pass if it is any version larger than
the specified version.

If a star exists as one of the digits, any version will pass, from the point of the star onward.

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

  Return $True
}

Function Test-CheckVersionString {
  $failedTests = @()
  $ErrorActionPreference = 'Continue'

  function Format-Output ($name, $expected, $value, $tests) {
    Return "Test $($tests.length + 1): $name failed! Expected '$expected' but got '$value'"
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

  # Expecting $True
  If ($higherCarrot -ne $True) {
    $failedTests += Format-Output '$higherCarrot' $False $higherCarrot $failedTests
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
    $failedTests += Format-Output '$moreSpecificCarrot' $False $moreSpecificCarrot $failedTests
  }

  # Star tests
  $patchStarExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.2.*'
  $patchStarHigher = Check-VersionString -Version '1.3.3' -CheckAgainst '1.2.*'
  $patchStarLower = Check-VersionString -Version '1.1.3' -CheckAgainst '1.2.*'

  $minorStarExact = Check-VersionString -Version '1.2.3' -CheckAgainst '1.*'
  $minorStarHigher = Check-VersionString -Version '1.3.3' -CheckAgainst '1.*'
  $minorStarLower = Check-VersionString -Version '1.1.3' -CheckAgainst '1.*'
  $minorStarMajorHigher = Check-VersionString -Version '2.1.3' -CheckAgainst '1.*'
  $minorStarMajorLower = Check-VersionString -Version '0.1.3' -CheckAgainst '1.*'

  $majorStarOne = Check-VersionString -Version '1' -CheckAgainst '*'
  $majorStarTwo = Check-VersionString -Version '1.2' -CheckAgainst '*'
  $majorStarThree = Check-VersionString -Version '1.2.3' -CheckAgainst '*'

  If ($patchStarExact -ne $True) {
    $failedTests += Format-Output '$patchStarExact' $False $patchStarExact $failedTests
  }
  If ($patchStarHigher -ne $False) {
    $failedTests += Format-Output '$patchStarHigher' $False $patchStarHigher $failedTests
  }
  If ($patchStarLower -ne $False) {
    $failedTests += Format-Output '$patchStarLower' $False $patchStarLower $failedTests
  }

  If ($minorStarExact -ne $True) {
    $failedTests += Format-Output '$minorStarExact' $True $minorStarExact $failedTests
  }
  If ($minorStarHigher -ne $True) {
    $failedTests += Format-Output '$minorStarHigher' $True $minorStarHigher $failedTests
  }
  If ($minorStarLower -ne $True) {
    $failedTests += Format-Output '$minorStarLower' $True $minorStarLower $failedTests
  }
  If ($minorStarMajorHigher -ne $False) {
    $failedTests += Format-Output '$minorStarMajorHigher' $False $minorStarMajorHigher $failedTests
  }
  If ($minorStarMajorLower -ne $False) {
    $failedTests += Format-Output '$minorStarMajorLower' $False $minorStarMajorLower $failedTests
  }

  If ($majorStarOne -ne $True) {
    $failedTests += Format-Output '$majorStarOne' $True $majorStarOne $failedTests
  }
  If ($majorStarTwo -ne $True) {
    $failedTests += Format-Output '$majorStarTwo' $True $majorStarTwo $failedTests
  }
  If ($majorStarThree -ne $True) {
    $failedTests += Format-Output '$majorStarThree' $True $majorStarThree $failedTests
  }


  # Expecting $True
  If ($higherCarrot -ne $True) {
    $failedTests += Format-Output '$higherCarrot' $False $higherCarrot $failedTests
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
    $failedTests += Format-Output '$moreSpecificCarrot' $False $moreSpecificCarrot $failedTests
  }

  # Enumerate results
  $numFailed = $failedTests.length
  If ($numFailed -gt 0) {
    Write-Output ($failedTests -join "`n")
    Write-Output "`n"
    Write-Output "**** --------- $numFailed tests failed --------- ****"
  } Else {
    Write-Output "All tests passed!"
  }
}
