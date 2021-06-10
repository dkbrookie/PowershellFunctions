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


    # Quick function to check for successful application install after the installer runs. This is used near the end of the function.
    Function Get-InstalledApplications ($ApplicationName) {
        # Applications may be in either of these locations depending on if x86 or x64
        [array]$installedApps = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        [array]$installedApps += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        }
        # Applications can also install to single user profiles, so we're checking user profiles too
        [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        # Not using all of this output right now but nice to have it handy in case we want to output any of it later
        $script:installedAppNames = $installedApps.DisplayName
        $script:installedAppDate = $installedApps.InstallDate
        $script:installedAppUninstallString = $installedApps.UninstallString
        If ($installedApps) {
            If ($installedApps.Count -gt 1) {
                [array]$script:logOutput += "Multiple applications found with the word(s) [$AppName] in the display name in Add/Remove programs. See list below..."
                [array]$script:logOutput += $installedAppNames
            }
            'Installed'
        } Else {
            'NotInstalled'
        }
    }


    # MSIExec removal attempt
    $appGUID = (Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*$AppName*" }).IdentifyingNumber
    If ($appGUID) {
        [array]$logOutput += "Attempting to remove $AppName with the found GUID of $appGUID using MSIExec /uninstall..."
        [array]$logOutput += Start-Process msiexec.exe -ArgumentList "/x ""$appGUID"" /qn /norestart /l ""$LogPath""" -Wait
        $appStatus = Get-InstalledApplications -ApplicationName $AppName
        If ($appStatus -eq 'NotInstalled') {
            [array]$logOutput += "$AppName has been successfully removed! Exiting script"
            $logOutput
            Break
        } Else {
            [array]$logOutput += "$AppName has failed to uninstall using the standard MSIExec /x method"
        }
    } Else {
        [array]$logOutput += "No GUID was found in registry for the app name $AppName"
    }


    # WMIC removal attempt
    [array]$logOutput += "Attempting to remove $AppName with WMIC uninstall..."
    [array]$logOutput += &cmd.exe /c "WMIC Product where name='$AppName' call uninstall"
    $appStatus = Get-InstalledApplications -ApplicationName $AppName
    If ($appStatus -eq 'NotInstalled') {
        [array]$logOutput += "$AppName has been successfully removed! Exiting script"
        $logOutput
        Break
    } Else {
        [array]$logOutput += "$AppName has failed to uninstall using the WMIC uninstall. Checking to see if force manual removal has been enabled..."
    }

    
    # Manually check reg entries for matching app names and run MSIExec on all of them
    [array]$installedApps = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    [array]$installedApps += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    }
    # Applications can also install to single user profiles, so we're checking user profiles too
    [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$AppName*" }
    ForEach ($app in $installedApps) {
        $appGUID = $app.PSChildName
        $uninstallString = $app.UninstallString
        [array]$logOutput += "Attemping to remove $appGUID..."
            [array]$logOutput += Start-Process msiexec.exe -ArgumentList "/x ""$appGUID"" /qn /norestart /l ""$LogPath""" -Wait
            If ($uninstallString -like '*.exe*' -and $uninstallString -notlike '*msiexec*') {
                [array]$logOutput += "Attempting $uninstallString /s..."
                [array]$logOutput += Start-Process $uninstallString -ArgumentList '/s' -Wait -EA 0
                [array]$logOutput += "Attempting $uninstallString /S..."
                [array]$logOutput += Start-Process $uninstallString -ArgumentList '/S' -Wait -EA 0
                [array]$logOutput += "Attempting $uninstallString /verysilent..."
                [array]$logOutput += Start-Process $uninstallString -ArgumentList '/verysilent' -Wait -EA 0
                [array]$logOutput += "Attempting $uninstallString /silent..."
                [array]$logOutput += Start-Process $uninstallString -ArgumentList '/silent' -Wait -EA 0
            }
            If ($uninstallString -like '*msiexec*' -and $uninstallString -notlike '*/qn*' -and $uninstallString -notlike '*/norestart*') {
                [array]$logOutput += "Attempting $uninstallString /qn /norestart..."
                $uninstallString = $uninstallstring + ' /qn /norestart'
            } Else {
                [array]$logOutput += "Attempting $uninstallString..."
                [array]$logOutput += &cmd.exe /c "$uninstallString"
            }
        }
        $appStatus = Get-InstalledApplications -ApplicationName $AppName
        If ($appStatus -eq 'NotInstalled') {
            [array]$logOutput += "$AppName has been successfully removed! Exiting script"
            $logOutput
            Break
        } Else {
            [array]$logOutput += "$AppName has failed to uninstall using the manual reg search paired with the MSIExec /x method"
    }

    $logOutput
    $logOutput = $Null
}