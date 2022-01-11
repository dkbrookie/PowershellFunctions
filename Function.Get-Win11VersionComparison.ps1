<#
Detects current Win11 version and compares against another version. Determines if the current windows version is "equal to", "less than", "greater than",
"less than or equal to", or "greather than or equal to"

In the case of an invalid situation, such as requesting a version of windows that is not supported, or running this function on a Windows Server machine,
this script will throw an exception, so it should be used with try/catch.

Upon meeting a valid situation. It will check the version you provided against the version of windows that the current machine is running and output a hash
table with "Result" (boolean) and Output (string).

Example of correct usage:
Try {
    $winIsLessThan21H2 = Get-Win11VersionComparison -LessThan '21H2'
} Catch {
    Write-Output $Error[0].Exception.Message
}

If ($winIsLessThan21H2.Result) {
    Return 'Success! This is a newer version!' + $winIsLessThan21H2.Output
} Else {
    Return 'Oh no! This is an old version!' + $winIsLessThan21H2.Output
}
#>

# Call in Get-WindowsVersion
(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Get-WindowsVersion.ps1') | Invoke-Expression

function Get-Win11VersionComparison {
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'LessThan')]
        [string]$LessThan,
        [Parameter(Mandatory = $true, ParameterSetName = 'LessThanOrEqualTo')]
        [string]$LessThanOrEqualTo,
        [Parameter(Mandatory = $true, ParameterSetName = 'GreaterThan')]
        [string]$GreaterThan,
        [Parameter(Mandatory = $true, ParameterSetName = 'GreaterThanOrEqualTo')]
        [string]$GreaterThanOrEqualTo,
        [Parameter(Mandatory = $true, ParameterSetName = 'EqualTo')]
        [string]$EqualTo
    )

    Switch ($true) {
        ([bool]$LessThan)               { $variableMsg = 'less than'; $checkAgainst = $LessThan }
        ([bool]$LessThanOrEqualTo)      { $variableMsg = 'less than or equal to'; $checkAgainst = $LessThanOrEqualTo }
        ([bool]$GreaterThan)            { $variableMsg = 'greater than'; $checkAgainst = $GreaterThan }
        ([bool]$GreaterThanOrEqualTo)   { $variableMsg = 'greater than or equal to'; $checkAgainst = $GreaterThanOrEqualTo }
        ([bool]$EqualTo)                { $variableMsg = 'equal to'; $checkAgainst = $EqualTo }
    }

    # Normalize all alpha characters to uppercase
    $checkAgainst = $checkAgainst.ToUpper()

    # Just to simplify the output message in each case below
    function Get-OutputMessage {
        param([bool]$Result)

        $msg1 = "The current Windows version, $version, is "
        $msg2 = "$variableMsg the requested version, $checkAgainst"

        If ($Result) {
             Return $msg1 + $msg2
        } Else {
            Return $msg1 + "not " + $msg2
        }
    }

    # Gather current OS info
    $windowsVersion = Get-WindowsVersion
    $osName = $windowsVersion.SimplifiedName
    $orderOfWin11Versions = $windowsVersion.OrderOfWin11Versions
    $version = $windowsVersion.Version
    $currentVersionIndex = $orderOfWin11Versions.IndexOf($version)
    $checkAgainstIndex = $orderOfWin11Versions.IndexOf($checkAgainst)

    # Doesn't make sense if this isn't win11
    If ($osName -ne '11') {
        Throw "This does not appear to be a Windows 11 machine. Function 'Get-Win11VersionComparison' only supports Windows 11 machines. This is: $osName"
    }

    # If the current version is not in the list of win 11 versions, it's not supported
    If ($currentVersionIndex -eq -1) {
        Throw "Something went wrong determining the current version of windows, it does not appear to be in the list.." +
                "Maybe a new version of windows 11? Function 'Get-Win11VersionComparison' supports $($orderOfWin11Versions[0]) through $($orderOfWin11Versions[-1]) " +
                "This is: $version. If you need to add a new version of windows, edit this: " +
                "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
    }

    # If the wanted version is not in the list of win 11 versions, it's not supported
    If ($checkAgainstIndex -eq -1) {
        Throw "Something went wrong determining the wanted version of windows, it does not appear to be in the supported list.." +
        "Maybe a new version of windows 11? Function 'Get-Win11VersionComparison' supports versions $($orderOfWin11Versions[0]) through $($orderOfWin11Versions[-1]) " +
        "You requested: $checkAgainst. If you need to add a new version of windows, edit this: " +
        "https://github.com/dkbrookie/PowershellFunctions/blob/master/Function.Get-WindowsVersion.ps1"
    }

    # Here's the meat
    Switch ($true) {
        ([bool]$LessThan) {
            If ($currentVersionIndex -lt $checkAgainstIndex) {
                Return @{
                    Result = $true
                    Output = Get-OutputMessage -Result $true
                }
            } Else {
                Return @{
                    Result = $false
                    Output = Get-OutputMessage -Result $false
                }
            }
        }

        ([bool]$LessThanOrEqualTo) {
            If ($currentVersionIndex -le $checkAgainstIndex) {
                Return @{
                    Result = $true
                    Output = Get-OutputMessage -Result $true
                }
            } Else {
                Return @{
                    Result = $false
                    Output = Get-OutputMessage -Result $false
                }
            }
        }

        ([bool]$GreaterThan) {
            If ($currentVersionIndex -gt $checkAgainstIndex) {
                Return @{
                    Result = $true
                    Output = Get-OutputMessage -Result $true
                }
            } Else {
                Return @{
                    Result = $false
                    Output = Get-OutputMessage -Result $false
                }
            }
        }

        ([bool]$GreaterThanOrEqualTo) {
            If ($currentVersionIndex -ge $checkAgainstIndex) {
                Return @{
                    Result = $true
                    Output = Get-OutputMessage -Result $true
                }
            } Else {
                Return @{
                    Result = $false
                    Output = Get-OutputMessage -Result $false
                }
            }
        }

        ([bool]$EqualTo) {
            If ($currentVersionIndex -eq $orderOfWin11Versions.IndexOf($EqualTo)) {
                Return @{
                    Result = $true
                    Output = Get-OutputMessage -Result $true
                }
            } Else {
                Return @{
                    Result = $false
                    Output = Get-OutputMessage -Result $false
                }
            }
        }
    }
}
