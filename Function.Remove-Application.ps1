Function Remove-Application {
    <#
    .SYNOPSIS
    Remove-Application allows you to easily attempt a silent uninstallation of any application with just
    the name from add/remove programs.

    .DESCRIPTION
    This script will take the name of the application in add/remove programs and attempt several silent 
    arguments and methods to uninstall the application in the background automatically. The output is
    very thorough and lets you know all attempts the script made.

    .PARAMETER ApplicationName
    IMPORTANT: Type the name EXACTLY as shown in Add/Remove programs in Control Panel.

    .PARAMETER LogPath
    The full path to where you want the uninstallation logs saved. By default, the logs will be saved in the same
    directory as your install files in %windir%\LTSvc\packages\Software\AppName\Install Log - ApplicationName.txt

    .EXAMPLE
    C:\PS> Remove-Application -ApplicationName "SuperApp" -FileDownloadURL "https://domain.com/file/file.msi"
    #>


    [CmdletBinding()]


    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the application you want to uninstall exactly as seen in Add/Remove programs"
        )]
        [string]$ApplicationName,
        [string]$LogPath = "$env:windir\LTSvc\$ApplicationName-removalLog.txt"
    )


    # Set vars
    $output = @()
    $installedAppsArray = @()
    $possibleArguments = '/s','/S','/verysilent','/silent','/quiet','/q','--uninstall'
    $timeOutLimit = 30
    $appGUID = (Get-WmiObject Win32_Product | Where-Object { $_.Name -like "*$ApplicationName*" }).IdentifyingNumber
    If ($appGUID) {
        $msiType = $true
        $output += "Confirmed this is an MSI based uninstall"
    } Else {
        $output += "Confirmed this is an EXE based uninstall"
    }


    # Quick function to check for successful application install after the installer runs. This is used near the end of the function.
    Function Get-InstalledApplications ($ApplicationName) {
        $installedAppsArray = @()
        # Applications may be in either of these locations depending on if x86 or x64
        $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        }
        # Applications can also install to single user profiles, so we're checking user profiles too
        $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -EA 0 | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        # Not using all of this output right now but nice to have it handy in case we want to output any of it later
        $script:installedAppNames = $installedAppsArray.DisplayName
        $script:installedAppDate = $installedAppsArray.InstallDate
        $script:installedAppUninstallString = $installedAppsArray.UninstallString
        If ($installedAppsArray) {
            If ($installedAppsArray.Count -gt 1) {
                $script:logOutput += "Multiple applications found with the word(s) [$ApplicationName] in the display name in Add/Remove programs. See list below..."
                $script:logOutput += $installedAppNames
            }
            Return 'Installed'
        } Else {
            Return 'NotInstalled'
        }
    }


    # MSIExec removal attempt
    If ($msiType) {
        $output += "Attempting generic MSI GUID removal using: [Start-Process msiexec.exe -ArgumentList /x $appGUID /qn /norestart /l $LogPath]"
        $output += Start-Process msiexec.exe -ArgumentList "/x ""$appGUID"" /qn /norestart /l ""$LogPath""" -Wait -PassThru
        $appStatus = Get-InstalledApplications -ApplicationName $ApplicationName
        If ($appStatus -eq 'NotInstalled') {
            $output += "$ApplicationName has been successfully removed! Exiting script"
            Return $output
        } Else {
            $output += "$ApplicationName has failed to uninstall"
        }
    } Else {
        # If there was no GUID found then the MSI method isn't going to work so we need to find the uninstall string that
        # should point us to an uninstall EXE.
        $output += "No GUID was found in registry for the app name [$ApplicationName]. This generally means this was not installed via EXE"
    }


    # WMIC removal attempt
    # If the last step indicated we found a GUID then we know the MSI uninstall route should work. If we're here, it
    # means the first attempt with standard msiexec /x didn't work, so we're going to try with the WMIC approach.
    If ($msiType) {
        $output += "Attempting to remove $ApplicationName with the WMIC uninstall method..."
        $output += &cmd.exe /c "WMIC Product where name='$ApplicationName' call uninstall"
        $appStatus = Get-InstalledApplications -ApplicationName $ApplicationName
        If ($appStatus -eq 'NotInstalled') {
            $output += "$ApplicationName has been successfully removed! Exiting script"
            Return $output
        } Else {
            $output += "$ApplicationName has failed to uninstall using the WMIC uninstall"
        }
    }

    
    # Manually check reg entries for matching app names
    $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    $installedAppsArray += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    }
    # Applications can also install to single user profiles, so we're checking user profiles too
    $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    $installedAppsArray += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    # Attempt uninstall switches for all install locations pulled from both general system and user profiles
    ForEach ($app in $installedAppsArray) {
        $uninstallString = $app.UninstallString


        # If the uninstall string exists, parse it out to just the path to the installer
        If ($uninstallString) {
            $output += "Parsing EXE location out of uninstall string..."
            # If there's double quotes in the string then parse it out, otherwise use it as-is. We're trying to get to the
            # path of the uninstall EXE and it can be difficult to parse that out. If there's double quotes around the EXE
            # path then it's pretty simple to split that out...otherwise, it's very difficult to figure out where the EXE
            # path ends and the arguments begin. For this reason, at this time we're just gonna use the uninstall string
            # as-is if there's no double quotes. Should probably see if this can be improved later.
            Switch ($true) {
                ($uninstallSTring -like '*"*') { $parsedUninstallString = (($uninstallString.Split('"'))[1]) }
                Default { $parsedUninstallString = $uninstallString }
            }
            $output += "Parsed path: [$parsedUninstallString]"
            $output += "Successfully located an uninstall string in the regsitry. Uninstall string: [$uninstallString]"
            
            # Check to see if the uninstall file exists. Sometimes a failed install leaves the EXE missing so we know this can fail
            $testPath = Test-Path -Path $parsedUninstallString -PathType Leaf -EA 0
            #$proc = $uninstallString.split('\.')[-2]
            $output += "Verifying the uninstall EXE exists..."
        }


        # Determine if this is an EXE uninstall string or an MSI based uninstall string
        If ($uninstallString -like '*.exe*' -and $uninstallString -notlike '*msiexec*') {
            If ($testPath) {
                $output += "Confirmed the [$parsedUninstallString] file exists!"
                $output += "Attempting uninstall with default uninstall string of [$uninstallString]..."
                $proc = Start-Process $uninstallString -PassThru -EA 0
                #Wait-Process -Timeout $timeOutLimit -ErrorVariable timeOut
                Start-Sleep ($timeOutLimit + 5)
                [string]$procName = ($proc).Name
                Stop-Process -Name $procName -Force | Out-Null
                $output += "Stopped the [$argument] attempt since it has exceeded the defined timeout limit of [$timeOutLimit] seconds"
                $appStatus = Get-InstalledApplications -ApplicationName $ApplicationName
                If ($appStatus -eq 'NotInstalled') {
                    $output += "Successfully removed [$ApplicationName] with the arguments command: [Start-Process $parsedUninstallString -EA 0]"
                    Return $output
                }


                ForEach ($argument in $possibleArguments) {
                    $output += "Attempting [$parsedUninstallString] uninstall string with the [$argument] argument..."
                    $proc = Start-Process $parsedUninstallString -ArgumentList $argument -PassThru
                    $output += "$procName has initiated..."
                    #Wait-Process -Name ($proc).Name -Timeout $timeOutLimit -ErrorVariable timeOut
                    # Set the amount of time to wait for the process to complete before we force close it and try the next argument. We're
                    # setting a limit here because there's high likelyhood the uninstaller just starts with the full GUI sitting there 
                    # waiting for the user to hit 'Next' or 'Yes'. Since this is intended to run as system, the user would never see these
                    # apps popup, and instead it would be in the background and we just determine if the process is running too long, kill
                    # it and try the next one.
                    Start-Sleep ($timeOutLimit + 5)
                    Stop-Process -Name $procName -Force | Out-Null
                    $output += "Stopped the [$argument] attempt since it has exceeded the defined timeout limit of [$timeOutLimit] seconds"


                    $appStatus = Get-InstalledApplications -ApplicationName $ApplicationName
                    If ($appStatus -eq 'NotInstalled') {
                        $output += "Successfully removed [$ApplicationName] with the arguments command: [Start-Process $parsedUninstallString -ArgumentList $argument -EA 0]"
                        Return $output
                    }
                }
            } Else {
                $output += "The uninstall file path in registry [$parsedUninstallString] doesn't exist!"
            }
        } ElseIf ($uninstallString -like '*msiexec*' -and $uninstallString -notlike '*/qn*' -and $uninstallString -notlike '*/norestart*') {
            $output += "Detected there was no silent arguments on the registry uninstall string. Attempting [Start-Process msiexec.exe -ArgumentList `"/x $uninstallString /qn /norestart /l $LogPath`" -Wait -PassThru]..."
            $uninstallString = $uninstallString -replace('/x','') -replace('msiexec.exe','') -replace('msiexec','')
            $output += Start-Process msiexec.exe -ArgumentList "/x ""$uninstallString"" /qn /norestart /l ""$LogPath""" -Wait -PassThru
        }
    }


    # Final check to see if the application was successfully removed
    $appStatus = Get-InstalledApplications -ApplicationName $ApplicationName
    If ($appStatus -eq 'NotInstalled') {
        $output += "[$ApplicationName] has been successfully removed! Exiting script"
    } Else {
        $output += "[$ApplicationName] has failed to uninstall"
    }


    Return $output
}