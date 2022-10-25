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
            $output += "Could not create $regPath. Error was: $($_.Exception.Message)"
        }
    }

    If (Test-RegistryValue -Name $Name) {
        $output += "A value already exists at $propertyPath. Overwriting value."
    }

    Try {
        $output += "Setting $propertyPath to $Value"
        New-ItemProperty -Path $regPath -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop | Out-Null
    } Catch {
        $output += "Could not create registry property $propertyPath. Error was: $($_.Exception.Message)"
    }

    Return ($output -join ' ')
}

function Add-RegKeyLastWriteTime {
    <#
        .DESCRIPTION
        Allows querying a registry key (output from Get-ChildItem or Get-Item)'s LastWriteTime. Doesn't work for properties, only keys.
        Copypasta from https://superuser.com/questions/1609746/how-to-sort-registry-entries-by-last-write-time-last-modified-time-in-powershell
        Requires Powershell 3.0+

        .EXAMPLE
        Get-ChildItem HKCU:\ | Add-RegKeyLastWriteTime | Select Name,LastWriteTime
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ParameterSetName = "ByKey", Position = 0, ValueFromPipeline)]
        # Registry key object returned from Get-ChildItem or Get-Item
        [Microsoft.Win32.RegistryKey] $RegistryKey,
        [Parameter(Mandatory, ParameterSetName = "ByPath", Position = 0)]
        # Path to a registry key
        [string] $Path
    )

    begin {
        # Define the namespace (string array creates nested namespace):
        $Namespace = "DKB.RegistryHelpers"

        If ($PSVersionTable.PSVersion.Major -lt 3) {
            Throw "Powershell version 3+ is required to use 'Add-RegKeyLastWriteTime'"
        }

        # Make sure type is loaded (this will only get loaded on first run):
        Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;

        $($Namespace | ForEach-Object {
            "namespace $_ {"
        })
            public class advapi32 {
                [DllImport("advapi32.dll", CharSet = CharSet.Auto)]
                public static extern Int32 RegQueryInfoKey(
                    Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey,
                    StringBuilder lpClass,
                    [In, Out] ref UInt32 lpcbClass,
                    UInt32 lpReserved,
                    out UInt32 lpcSubKeys,
                    out UInt32 lpcbMaxSubKeyLen,
                    out UInt32 lpcbMaxClassLen,
                    out UInt32 lpcValues,
                    out UInt32 lpcbMaxValueNameLen,
                    out UInt32 lpcbMaxValueLen,
                    out UInt32 lpcbSecurityDescriptor,
                    out System.Runtime.InteropServices.ComTypes.FILETIME lpftLastWriteTime
                );
            }
        $($Namespace | ForEach-Object { "}" })
"@

        # Get a shortcut to the type:
        $RegTools = ("{0}.advapi32" -f ($Namespace -join ".")) -as [type]
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            "ByKey" {
                # Already have the key, no more work to be done 🙂
            }
            "ByPath" {
                # We need a RegistryKey object (Get-Item should return that)
                $Item = Get-Item -Path $Path -ErrorAction Stop

                # Make sure this is of type [Microsoft.Win32.RegistryKey]
                if ($Item -isnot [Microsoft.Win32.RegistryKey]) {
                    throw "'$Path' is not a path to a registry key!"
                }
                $RegistryKey = $Item
            }
        }

        # Initialize variables that will be populated:
        $ClassLength = 255 # Buffer size (class name is rarely used, and when it is, I've never seen
        # it more than 8 characters. Buffer can be increased here, though.
        $ClassName = New-Object System.Text.StringBuilder $ClassLength  # Will hold the class name
        $LastWriteTime = New-Object System.Runtime.InteropServices.ComTypes.FILETIME

        switch ($RegTools::RegQueryInfoKey($RegistryKey.Handle,
                $ClassName,
                [ref] $ClassLength,
                $null, # Reserved
                [ref] $null, # SubKeyCount
                [ref] $null, # MaxSubKeyNameLength
                [ref] $null, # MaxClassLength
                [ref] $null, # ValueCount
                [ref] $null, # MaxValueNameLength
                [ref] $null, # MaxValueValueLength
                [ref] $null, # SecurityDescriptorSize
                [ref] $LastWriteTime
            )) {
            0 {
                # Success
                # Convert to DateTime object:
                $UnsignedLow = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes($LastWriteTime.dwLowDateTime), 0)
                $UnsignedHigh = [System.BitConverter]::ToUInt32([System.BitConverter]::GetBytes($LastWriteTime.dwHighDateTime), 0)
                # Shift high part so it is most significant 32 bits, then copy low part into 64-bit int:
                $FileTimeInt64 = ([Int64] $UnsignedHigh -shl 32) -bor $UnsignedLow
                # Create datetime object
                $LastWriteTime = [datetime]::FromFileTime($FileTimeInt64)

                # Add properties to object and output them to pipeline
                $RegistryKey | Add-Member -NotePropertyMembers @{
                    LastWriteTime = $LastWriteTime
                    ClassName     = $ClassName.ToString()
                } -PassThru -Force
            }
            122 {
                # ERROR_INSUFFICIENT_BUFFER (0x7a)
                throw "Class name buffer too small"
                # function could be recalled with a larger buffer, but for
                # now, just exit
            }
            default {
                throw "Unknown error encountered (error code $_)"
            }
        }
    }
}
