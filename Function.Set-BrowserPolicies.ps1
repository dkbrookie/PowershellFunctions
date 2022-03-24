<#
Google Applications
    Sheets: felcaaldnbdncclmgdcncolpebgiejap
    Slides: aapocclcgogkmnckokdopfmhonfmgoek
    Docs: aohghmighlieiainnegkcijnfilokake
    Calendar: gmbgaklkmjakoegficnlkhebmhkjfich

Possible To Do
    - Add custom message when an extension is blocked from install https://support.google.com/chrome/a/answer/7532015#zippy=%2Cset-installation-policies-automatically-install-force-install-allow-or-block%2Cset-custom-message-for-blocked-apps-and-extensions
#>

# Set vars
$chrome = @{
    rootPath = 'HKLM:\SOFTWARE\Policies\Google'
    namePath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
    ExtensionInstallAllowlistPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallAllowlist'
    ExtensionInstallBlocklist = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallBlocklist'
    ExtensionInstallForcelist = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
    Recommended = 'HKLM:\SOFTWARE\Policies\Google\Chrome\Recommended'
}

$edge = @{
    rootPath = 'HKLM:\SOFTWARE\Policies\Microsoft'
    namePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    ExtensionInstallAllowlistPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallAllowlist'
    ExtensionInstallBlocklist = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist'
    ExtensionInstallForcelist = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
    Recommended = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
}

$brave = @{
    rootPath = 'HKLM:\SOFTWARE\Policies\BraveSoftware'
    namePath = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave'
    ExtensionInstallAllowlistPath = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallAllowlist'
    ExtensionInstallBlocklist = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallBlocklist'
    ExtensionInstallForcelist = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist'
    Recommended = 'HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\Recommended'
}

$ErrorActionPreference = 'Stop'


Function New-ReqDirs {
    Try {
        # Create key for dirs if they don't exist. Note the sort is to ensure parent dirs are created so the
        # child dirs don't fail out. Tested with just -Force, but registry requires each dir (key) to be created
        # individually
        $chrome,$edge,$brave | Select-Object -ExpandProperty Values | Sort-Object { $_.Length } |  ForEach-Object { If (!(Test-Path $_)) {
                New-Item -Path $_ -Force | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Get-MaxValue {
    <#

    .DESCRIPTION
    May not need this, but this is to find the max reg value name. This is useful for the scenario
    where entries already exist for allowed or blocked extensions and you want to get the current
    max number so you can increment it.

    #>
    param (
        [string]$Path
    )
    # Get max current extension configuration reg value number
    $Regex = '^\d*$'
    $RegValues = Get-ItemProperty $Path
    $IntRegValues = $RegValues.PSObject.Properties | Where-Object { $_.Name -match $Regex }
    $maxValue = ($IntRegValues.Name | Measure-Object -Maximum).Maximum
    If (!$maxValue) {
        Return 0
    } Else {
        Return $maxValue
    }
}


Function Set-PasswordManagerPolicy {
    param (
        [ValidateSet('Enabled','Disabled')]
        $PassManagerState = 'Disabled'
    )

    Switch ($PassManagerState) {
        'Disabled'  { $PassManagerState = 0 }
        'Enabled'   { $PassManagerState = 1 }
    }
    
    Try {
        New-ReqDirs
        $chrome.namePath,$edge.namePath,$brave.namePath | ForEach-Object {
            If ((Get-ItemProperty $_ -Name 'PasswordManagerEnabled' -EA 0).'PasswordManagerEnabled' -ne $PassManagerState ) {
                Set-ItemProperty -Path $_ -Name 'PasswordManagerEnabled' -Value $PassManagerState | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-BlockExtensionPolicy {
    <#
    
    .DESCRIPTION
    This function is designed to either block, or unblock the ability for the user to install
    extensions.
    
    This setting can be partially overridden by the Set-AllowedExtensionsPolicy.
    Specifying extension GUIDs in the Set-AllowedExtensionsPolicy will allow the user to only
    install extension listed in your allowed policy.

    This setting can also be partially overridden by the Set-EnforcedExtensionPolicy function
    which will automatic install and enforce the installation of a list of extensions
    specified by extension GUIDs.
    
    #>
    param (
        [ValidateSet('BlockAll','UnblockAll')]
        $BlockExtensionInstallState = '*'
    )

    Try {
        $chrome.ExtensionInstallBlocklist,$edge.ExtensionInstallBlocklist,$brave.ExtensionInstallBlocklist | ForEach-Object {
            If (Test-Path $chrome.ExtensionInstallBlocklist) {
                Remove-Item -Path $_ -Recurse -Force
            }
            If ($BlockExtensionInstallState -eq 'BlockAll') {
                New-ReqDirs
                New-ItemProperty -Path $_ -Name 1 -Type String -Value '*' | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-EnforcedExtensionPolicy {
    <#

    .DESCRIPTION
    This function is designed to **remove all existing extension enforcements** and replace them
    with the array of extension GUID IDs you specify when calling this function.

    This function overrides the Set-BlockExtensionPolicy by allowing the extensions specified
    in this function to install despite block all extensions being set.

    Best practice configuration would be to enforce block all extensions, then specify the list
    of enforced extensions per entity, then set any additional allowed extension installations
    with the Set-AllowedExtensionsPolicy.

    .PARAMETER EnforcedExtensionGUIDs
    Enter a comma separated list of extension GUIDs to be enforced

    #>

    param (
        [array]$EnforcedExtensionGUIDs
    )

    Try {
        # Add GUIDs to the reg to enforce extension installss
        $chrome.ExtensionInstallForcelist,$edge.ExtensionInstallForcelist,$brave.ExtensionInstallForcelist | ForEach-Object {
            # Remove existing enforcement key so we can start fresh with our new list of enforced extensions
            Remove-Item -Path $_ -Recurse -Force

            # Recreate key structure
            New-ReqDirs

            $iteration = 0
            ForEach ($EnforcedGUID in $EnforcedExtensionGUIDs) {
                $iteration++
                New-ItemProperty -Path $_ -Name $iteration -Value $EnforcedGUID | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-AllowedExtensionsPolicy {
    <#

    .DESCRIPTION
    This function is designed to **remove all existing allowed extensions** and replace them
    with the array of extension GUID IDs you specify when calling this function.

    This function overrides the Set-BlockExtensionPolicy by allowing the extensions specified
    in this function to be installed by the user despite block all extensions being set.

    Best practice configuration would be to enforce block all extensions, then specify the list
    of enforced extensions per entity, then set any additional allowed extension installations
    with the Set-AllowedExtensionsPolicy.

    .PARAMETER AllowedExtensionGUIDs
    Enter a comma separated list of extension GUIDs to be enforced

    #>

    param (
        [array]$AllowedExtensionGUIDs
    )

    Try {
        # Add GUIDs to the reg to enforce extension installss
        $chrome.ExtensionInstallAllowlistPath,$edge.ExtensionInstallAllowlistPath,$brave.ExtensionInstallAllowlistPath | ForEach-Object {
            # Remove existing enforcement key so we can start fresh with our new list of enforced extensions
            Remove-Item -Path $_ -Recurse -Force

            # Recreate key structure
            New-ReqDirs

            $iteration = 0
            ForEach ($AllowedGUID in $AllowedExtensionGUIDs) {
                $iteration++
                New-ItemProperty -Path $_ -Name $iteration -Value $AllowedGUID | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-RelaunchEnforcementPolicy {
    <#

    .PARAMETER RelaunchConfiguration
    Valid values are as follows:

    Disabled: Removes the registry key to enforce this setting
    RecommendPrompt: Show a recurring prompt to the user indicating that a relaunch is recommended. Value
    in registry is 1.
    RequiredPrompt: Show a recurring prompt to the user indicating that a relaunch is required. Value in
    registry is 2.

    .PARAMETER NotificationPeriod
    Enter the amount of time that can pass before the relaunch notification will popup in the user's 
    browser. This time is meeasued in miliseconds, and by default is set to 3 days.
    
    #>
    param (
        [ValidateSet('Disabled','RecommendPrompt','RequiredPrompt')]
        $RelaunchConfiguration,
        [int]$NotificationPeriod = 259200000
    )


    Switch ($RelaunchConfiguration) {
        'Disabled'          { $EnforceRelaunch = 0 }
        'RecommendPrompt'   { $EnforceRelaunch = 1 }
        'RequiredPrompt'    { $EnforceRelaunch = 2 }
    }

    # Verify required dirs exist
    New-ReqDirs

    # Enable relaunch notification
    Try {
        $chrome.namePath,$edge.namePath,$brave.namePath | ForEach-Object {
            If ($EnforceRelaunch -ne 0) {
                If ((Get-ItemProperty $_ -Name 'RelaunchNotification' -EA 0).1 -ne $EnforceRelaunch ) {
                    Set-ItemProperty -Path $_ -Name 'RelaunchNotification' -Value $EnforceRelaunch | Out-Null
                }

                # Set the relaunch timer in milliseconds
                If ((Get-ItemProperty $_ -Name 'RelaunchNotificationPeriod' -EA 0).1 -ne $NotificationPeriod ) {  
                    Set-ItemProperty -Path $_ -Name 'RelaunchNotificationPeriod' -Value $NotificationPeriod | Out-Null
                }
            } Else {
                Remove-ItemProperty -Path $_ -Name 'RelaunchNotification' -Force -EA 0
                Remove-ItemProperty -Path $_ -Name 'RelaunchNotificationPeriod' -Force -EA 0
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}
