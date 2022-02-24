$dirs = @{
    browsers = @{
        chrome = @{
            rootPath = 'HKLM:\SOFTWARE\Policies\Google'
            namePath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
            ExtensionInstallAllowlistPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallAllowlist'
            ExtensionInstallBlocklist = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallBlocklist'
            ExtensionInstallForcelist = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
            Recommended = 'HKLM:\SOFTWARE\Policies\Google\Chrome\Recommended'
        }
        edge = @{
            rootPath = 'HKLM:\SOFTWARE\Policies\Microsoft'
            namePath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            ExtensionInstallAllowlistPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallAllowlist'
            ExtensionInstallBlocklist = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallBlocklist'
            ExtensionInstallForcelist = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist'
            Recommended = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge\Recommended'
        }
    }
}


$ErrorActionPreference = 'Stop'


Function New-ReqDirs {
    Try {
        # Create key for dirs if they don't exist
        $dirs.browsers.chrome,$dirs.browsers.edge | Select-Object -ExpandProperty Values | Sort-Object { $_.Length } |  ForEach-Object { If (!(Test-Path $_)) {
                New-Item -Path $_ | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-PasswordManager {
    param (
        [ValidateSet(1,0)]
        $PassManagerState = 0
    )
    
    Try {
        New-ReqDirs
        $dirs.browsers.chrome.namePath,$dirs.browsers.edge.namePath | ForEach-Object { If ((Get-ItemProperty $_ -Name 'PasswordManagerEnabled' -EA 0).'PasswordManagerEnabled' -ne $passManagerState ) {
                Set-ItemProperty -Path $_ -Name 'PasswordManagerEnabled' -Value $passManagerState | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-BlockAllExtensionInstalls {
    <#
    Working through how to handle getting the max increment of existing REG_SZ entries in the reg key.
    https://www.imab.dk/install-google-chrome-extensions-using-microsoft-intune/
    #>
    param (
        [ValidateSet(1,0)]
        $BlockExtensionInstallState = 0
    )

    Try {
        New-ReqDirs
        $dirs.browsers.chrome.ExtensionInstallBlocklist,$dirs.browsers.edge.ExtensionInstallBlocklist | ForEach-Object { 
            Get-ChildItem
            
            If ((Get-ItemProperty $_ -Name 'PasswordManagerEnabled' -EA 0).'PasswordManagerEnabled' -ne $passManagerState ) {
                Set-ItemProperty -Path $_ -Name 'PasswordManagerEnabled' -Value $passManagerState | Out-Null
            }
        }
        Return $true
    } Catch {
        Return $false
    }
}


Function Set-RelaunchEnforcement {
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


    New-ReqDirs


    # Enable relaunch notification
    Try {
        $dirs.browsers.chrome.namePath,$dirs.browsers.edge.namePath | ForEach-Object {
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