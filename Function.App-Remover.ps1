Function App-Remover {
    <#
    .SYNOPSIS
    Install-MSI allows you to easily downooad and install an application via MSI

    .DESCRIPTION
    This allows you to define as little as just the download link for the MSI installer and the rest
    will be auto filled for you. If you decide to define more flags, like install dir or arguments,
    you will need to make sure these values are complete and in quotes if there are spaces. See examples
    for more informaiton.

    .PARAMETER AppName
    IMPORTANT: Type the name EXACTLY as shown in Add/Remove programs in Control Panel. This will be used 
    as the application name searched in Add/Remove programs after installation to verify this was successful,
    used as the folder name for the setup file, and the name of the installer MSI once downloaded.

    .PARAMETER LogPath
    The full path to where you want the installation logs saved. By default, the logs will be saved in the same
    directory as your install files in %windir%\LTSvc\packages\Software\AppName\Install Log - App Name.txt

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the MSI. By defualt, /qn and /i will be applied for install
    and silent, but if you define this parameter then you will need to add /i and /qn manually. See examples...

    .EXAMPLE
    C:\PS> Install-MSI -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi"
    C:\PS> Install-MSI -AppName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi" -FileMSIPath "C:\windows\ltsvc\packages\softwar\superapp\superapp.msi" -LogPath "C:\install log.txt"
    #>


    [CmdletBinding()]


    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the application you want to uninstall exactly as seen in Add/Remove programs"
        )]
        [string]$AppName,
        [string]$LogPath = "$env:windir\LTSvc\$AppName-removalLog.txt"
    )

    # Set vars
    [array]$outputArray = ''
    [array]$installedAppsArray = ''

    # Quick function to check for successful application install after the installer runs. This is used near the end of the function.
    Function Get-InstalledApplications ($ApplicationName,$installedAppsArray = $installedAppsArray) {
        # Applications may be in either of these locations depending on if x86 or x64
        $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        }
        # Applications can also install to single user profiles, so we're checking user profiles too
        $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        # Not using all of this output right now but nice to have it handy in case we want to output any of it later
        $script:installedAppNames = $installedAppsArray.DisplayName
        $script:installedAppDate = $installedAppsArray.InstallDate
        $script:installedAppUninstallString = $installedAppsArray.UninstallString
        If ($installedAppsArray) {
            If ($installedAppsArray.Count -gt 1) {
                $script:logOutput += "Multiple applications found with the word(s) [$AppName] in the display name in Add/Remove programs. See list below..."
                $script:logOutput += $installedAppNames
            }
            'Installed'
        } Else {
            'NotInstalled'
        }
    }


    # MSIExec removal attempt
    $appGUID = (Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*$AppName*" }).IdentifyingNumber
    If ($appGUID) {
        $outputArray += "Attempting: Start-Process msiexec.exe -ArgumentList /x $appGUID /qn /norestart /l $LogPath -Wait"
        $outputArray += Start-Process msiexec.exe -ArgumentList "/x ""$appGUID"" /qn /norestart /l ""$LogPath""" -Wait
        $appStatus = Get-InstalledApplications -ApplicationName $AppName
        If ($appStatus -eq 'NotInstalled') {
            $outputArray += "$AppName has been successfully removed! Exiting script"
            $outputArray
            Break
        } Else {
            $outputArray += "$AppName has failed to uninstall using the standard MSIExec /x method"
        }
    } Else {
        $outputArray += "No GUID was found in registry for the app name $AppName"
    }


    # WMIC removal attempt
    $outputArray += "Attempting to remove $AppName with WMIC uninstall..."
    $outputArray += &cmd.exe /c "WMIC Product where name='$AppName' call uninstall"
    $appStatus = Get-InstalledApplications -ApplicationName $AppName
    If ($appStatus -eq 'NotInstalled') {
        $outputArray += "$AppName has been successfully removed! Exiting script"
        $outputArray
        Break
    } Else {
        $outputArray += "$AppName has failed to uninstall using the WMIC uninstall. Checking to see if force manual removal has been enabled..."
    }

    
    # Manually check reg entries for matching app names and run MSIExec on all of them
    $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    }
    # Applications can also install to single user profiles, so we're checking user profiles too
    $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    # Attempt uninstall switches for all install locations pulled from both general system and user profiles
    ForEach ($app in $installedAppsArray) {
        $appGUID = $app.PSChildName
        $uninstallString = $app.UninstallString
        # If the uninstall string exists, parse it out to just the path to the installer
        If ($uninstallString) {
            $parsedUninstallString = (($uninstallString.Split('"'))[1])
            $testPath = Test-Path -Path $parsedUninstallString -PathType Leaf
        }
        $outputArray += "Attemping to remove $appGUID..."
            $outputArray += Start-Process msiexec.exe -ArgumentList "/x ""$appGUID"" /qn /norestart /l ""$LogPath""" -Wait
            If ($uninstallString -like '*.exe*' -and $uninstallString -notlike '*msiexec*') {
                # Check to see if the uninstall file exists. Sometimes a failed install leaves the EXE missing so we know this will fail
                $parsedUninstallString = (($uninstallString.Split('"'))[1])
                If ($testPath) {
                    $outputArray += "Attempting $uninstallString /s..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/s' -Wait -EA 0
                    $outputArray += "Attempting $uninstallString /S..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/S' -Wait -EA 0
                    $outputArray += "Attempting $uninstallString /verysilent..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/verysilent' -Wait -EA 0
                    $outputArray += "Attempting $uninstallString /silent..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/silent' -Wait -EA 0
                    $outputArray += "Attempting $uninstallString /quiet..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/quiet' -Wait -EA 0
                    $outputArray += "Attempting $uninstallString /q..."
                    $outputArray += Start-Process $uninstallString -ArgumentList '/q' -Wait -EA 0
                } Else {
                    $outputArray += "The reported uninstall file at $parsedUninstallString doesn't exist!"
                }
            } ElseIf ($uninstallString -like '*msiexec*' -and $uninstallString -notlike '*/qn*' -and $uninstallString -notlike '*/norestart*') {
                $outputArray += "Attempting $uninstallString /qn /norestart..."
                $uninstallString = $uninstallstring + ' /qn /norestart'
            }
        }    
    $appStatus = Get-InstalledApplications -ApplicationName $AppName
    If ($appStatus -eq 'NotInstalled') {
        $outputArray += "$AppName has been successfully removed! Exiting script"
        $outputArray
        Break
    } Else {
        $outputArray += "$AppName has failed to uninstall using the manual reg search paired with the MSIExec /x method"
    }

    $outputArray
    $outputArray = $Null
}