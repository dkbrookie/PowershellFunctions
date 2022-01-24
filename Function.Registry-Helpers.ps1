<#
    All functions (except Remove-RegistryKey) rely on $regPath being set before this script is called. The intention is for a given script to have a single
    reg path where it's interacting with keys. This is for the sake of convenience since this scenario pops up often. Each function optionally receives
    a -Path param (except Remove-RegistryKey, -Path is mandatory there) which will be used instead if provided, for when this convention doesn't fit.

    .Example
    # Path doesn't exist yet, but that's OK
    $regPath = 'HKLM:\\SOFTWARE\LabTech\BlarneyStoneStatus'

    (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.Registry-Helpers.ps1') | Invoke-Expression

    Remove-RegistryValue -Name 'NewValue'
    # Doesn't return anything or error. The intended result is already true.

    Test-RegistryValue -Name 'NewValue'
    # Returns False

    Write-RegistryValue -Name 'NewValue' -Value 1
    # Returns 'HKLM:\\SOFTWARE\LabTech\BlarneyStoneStatus didn't exist, so creating it. Setting HKLM:\\SOFTWARE\LabTech\BlarneyStoneStatus\NewValue to 1'

    Test-RegistryValue -Name 'NewValue'
    # Returns True

    Get-RegistryValue -Name 'NewValue'
    # Returns 1

    Write-RegistryValue -Name 'NewValue' -Value 0
    # Returns 'A value already exists at HKLM:\\SOFTWARE\LabTech\BlarneyStoneStatus\NewValue. Overwriting value. Setting HKLM:\\SOFTWARE\LabTech\BlarneyStoneStatus\NewValue to 0.'

    Test-RegistryValue -Name 'NewValue'
    # Returns True

    Get-RegistryValue -Name 'NewValue'
    # Returns 0

    # Can also specify path instead of relying on $regPath
    Test-RegistryValue -Name 'OtherValue' -Path 'HKLM:\\some\registry\path'
#>

# Get-RegistryValue gets a registry value if it exists and just returns $null if it doesn't, without sending an error to stderr.
# Meant to be used by itself when value (or even key) not existing should just return null.
function Get-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    If ($Path) {
        $regPath = $Path
    }

    If (!$regPath) {
        Throw 'Get-RegistryValue could not continue. Path was not specified or was invalid! Please either specify $Path or set $regPath variable before using this function.'
    }

    Try {
        Return Get-ItemPropertyValue -Path $regPath -Name $Name -ErrorAction Stop
    } Catch {
        Return $null
    }
}

# Test-RegistryValue is identical to Get-RegistryValue except that it returns a boolean $true/$false instead of a value/$null
function Test-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    If ($Path) {
        $regPath = $Path
    }

    If (!$regPath) {
        Throw 'Test-RegistryValue could not continue. Path was not specified or was invalid! Please either specify $Path or set $regPath variable before using this function.'
    }

    $result = Get-RegistryValue -Name $Name -Path $regPath

    # We want to return $true even if registry value is 0 or an empty string
    If ($result -or ($result -eq 0) -or ($result -eq '')) {
        Return $true
    } Else {
        Return $false
    }
}

# Remove-RegistryValue removes a registry value if it exists, and takes no action when it doesn't
function Remove-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    If ($Path) {
        $regPath = $Path
    }

    If (!$regPath) {
        Throw 'Remove-RegistryValue could not continue. Path was not specified or was invalid! Please either specify $Path or set $regPath variable before using this function.'
    }

    Remove-ItemProperty -Path $regPath -Name $Name -Force -EA 0 | Out-Null
}

# Remove-RegistryKey deletes an entire key. This one requires `-Path` to be set and will not use pre-set $regPath
function Remove-RegistryKey {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # currently only handles HKLM, need to adjust regex if you want it to work for other areas of the registry
    $regex = '^HKLM:\\([a-zA-Z0-9\s_@\-\^!#.\:\/\$%&+={}\[\]\\*])+$'

    # Make sure that $Path is actually a registry path. If it's not, it could end up accidentally nuking some folder in the CWD
    If (!($Path -match $regex)) {
        Throw "Remove-RegistryKey could not continue. 'Path' parameter does not appear to be a valid HKLM registry location! Adjust regex in script if you need to use a non-HKLM registry location. Provided 'Path' was '$Path'"
    }

    Remove-Item -Path $Path -Force -Recurse -EA 0 | Out-Null
}

# Write-RegistryValue sets a registry value and returns an output string with results of action taken. It creates the entire path if it doesn't exist.
function Write-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [Parameter(Mandatory=$false)]
        [string]$Path,
        [string]$Type = 'string'
    )

    $output = @()

    If ($Path) {
        $regPath = $Path
    }

    If (!$regPath) {
        Throw 'Write-RegistryValue could not continue. Path was not specified or was invalid! Please either specify $Path or set $regPath variable before using this function.'
    }

    $propertyPath = "$regPath\$Name"

    If (!(Test-Path -Path $regPath)) {
        Try {
            $output += "$regPath didn't exist, so creating it."
            New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
        } Catch {
            $output += Get-ErrorMessage $_ "Could not create $regPath."
        }
    }

    If (Test-RegistryValue -Name $Name) {
        $output += "A value already exists at $propertyPath. Overwriting value."
    }

    Try {
        $output += "Setting $propertyPath to $Value"
        New-ItemProperty -Path $regPath -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop | Out-Null
    } Catch {
        $output += Get-ErrorMessage $_ "Could not create registry property $propertyPath."
    }

    Return ($output -join ' ')
}
