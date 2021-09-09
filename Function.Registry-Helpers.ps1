<#
    # All functions rely on $regPath being set before this script is called. The intention is for a given script to have a single
    # reg path where it's interacting with keys. This is for the sake of convenience since this scenario pops up often.
    # Each function optionally receives a -Path param which will be used instead if provided, for when this convention doesn't fit.
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

    Return [bool](Get-RegistryValue -Name $Name -Path $Path)
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

    Remove-ItemProperty -Path $regPath -Name $Name -Force -EA 0 | Out-Null
}

# Write-RegistryValue sets a registry value and returns an output string with results of action taken. It creates the entire path if it doesn't exist.
function Write-RegistryValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [Parameter(Mandatory=$false)]
        [string]$Path
    )

    $output = @()

    If ($Path) {
        $regPath = $Path
    }

    $propertyPath = "$regPath\$Name"

    If (!(Test-Path -Path $regPath)) {
        Try {
            New-Item -Path $regPath -Force -ErrorAction Stop | Out-Null
        } Catch {
            $output += Get-ErrorMessage $_ "Could not create registry key $regPath."
        }
    }

    If (Test-RegistryValue -Name $Name) {
        $output += "A value already exists at $propertyPath. Overwriting value."
    }

    Try {
        New-ItemProperty -Path $regPath -Name $Name -Value $Value -Force -ErrorAction Stop | Out-Null
    } Catch {
        $output += Get-ErrorMessage $_ "Could not create registry property $propertyPath."
    }

    Return $output
}