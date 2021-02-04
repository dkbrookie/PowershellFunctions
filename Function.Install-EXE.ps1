Function Install-EXE {
    <#
    .SYNOPSIS
    Install-EXE allows you to easily download and install an application via EXE

    .DESCRIPTION
    This allows you to define as little as just the download link and application name for the  installer and 
    the rest will be auto filled for you. If you decide to define more flags, like install dir or arguments,
    you will need to make sure these values are complete and in quotes if there are spaces. See examples for 
    more informaiton.

    .PARAMETER AppName
    IMPORTANT: Type the name EXACTLY as shown in Add/Remove programs in Control Panel. This will be used 
    as the application name searched in Add/Remove programs after installation to verify this was successful,
    used as the folder name for the setup file, and the name of the installer EXE once downloaded.

    .PARAMETER FileDownloadLink
    This will be the download link to the EXE file. Make sure to include the FULL URL including the http://

    .PARAMETER FileDir
    This is the directory the download files and install logs will be saved to. If you leave this undefined,
    it will default to %windir%\LTSvc\packages\Software\AppName

    .PARAMETER FileEXEPath
    The full path to the EXE installer. If you had a specific location to the EXE file you would define it here.
    Keep in mind you do not have to define the -FileDownloadLink flag, so if you already had a local file or a
    network share file you can just define the path to it here.

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the EXE.

    .PARAMETER Wait
    Valid values for this argument are $true or $false. This sets the -Wait flag on the Start-Process command of 
    the installer EXE, meaning it will wait for the EXE to continue before moving on if this is set to $true. Set
    to $true if undefined.

    .EXAMPLE
    C:\PS> Install-EXE -AppName 'Microsoft Edge' -FileDownloadURL 'https://domain.com/file/file.EXE' -Arguments '/silent'
    C:\PS> Install-EXE -AppName 'Microsoft Edge' -FileDownloadURL 'https://domain.com/file/file.EXE' -FileEXEPath 'C:\windows\ltsvc\packages\software\Microsoft Edge\Microsoft Edge.EXE' -Arguments '/s'
    #>


    [CmdletBinding()]


    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the application you want to install exactly as seen in Add/Remove programs."
        )]
        [string]$AppName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the full download URL for the installation EXE. This should look something like 'https://website.com/folder/exefile.exe'."
        )]
        [string]$FileDownloadLink,
        [string]$FileDir,
        [string]$FileEXEPath,
        [Parameter(
            HelpMessage = "Enter all arguments to install the EXE, such as /s or /silent."
        )]
        [string]$Arguments,
        [Parameter(
            HelpMessage = 'Sets the -Wait flag on the Start-Process command of the installer EXE, meaning it will wait for the EXE to continue before moving on if this is set to $true. This is set to $true by default.'
        )]
        [boolean]$Wait = $true
    )


    # Lingering powershell tasks can hold up a successful installation, so here we're saying if a powershell
    # process has been running for more than 90min, and the user is NT Authority\SYSTEM, kill it
    [array]$processes = Get-Process -Name powershell -IncludeUserName | Where { $_.UserName -eq 'NT AUTHORITY\SYSTEM' }
    ForEach ($process in $processes) {
        $timeOpen = New-TimeSpan -Start (Get-Process -Id $process.ID).StartTime
        If ($timeOpen.TotalMinutes -gt 90) {
            Stop-Process -Id $process.Id -Force
        }
    }


    # To ensure successful downloads we need to set TLS protocal type to Tls1.2. Downloads regularly fail via Powershell without this step.
    Try {
        # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        [array]$script:logOutput += "Successfully enabled TLS1.2 to ensure successful file downloads."
    } Catch {
        [array]$script:logOutput += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
        # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
        $psVers = $PSVersionTable.PSVersion
        If ($psVers.Major -lt 3) {
            [array]$script:logOutput += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
        }
    }
    

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
            'Success'
        } Else {
            'Failed'
        }
    }


    # Create all the dirs we need for a successful download/install
    Try {
        # Check for the directory variable and set it if it doensn't exist
        If (!$FileDir) {
            $FileDir = "$env:windir\LTSvc\packages\software\$AppName"
        }
        # Create the directory if it doesn't exist
        If(!(Test-Path $FileDir)) {
            New-Item -ItemType Directory $FileDir | Out-Null
        }
        # Set the path for the EXE installer
        If (!$FileEXEPath) {
            $FileEXEPath = "$FileDir\$($AppName).EXE"
        }

        # Download the EXE if it doens't exist, delete it and downlaod a new one of it does
        If(!(Test-Path $FileEXEPath -PathType Leaf)) {
            (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileEXEPath)
        # If the file already exists, delete it so we can download a fresh copy. It may be a different version so this ensures we're
        # working with the installer we intended to.
        } Else {
            Remove-Item $FileEXEPath -Force
            (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileEXEPath)
        }
    } Catch {
        [array]$script:logOutput += "Failed to download $FileDownloadLink to $FileEXEPath. Unable to proceed with install without the installer file, exiting script."
    }


    # Since we added the option to NOT wait for the EXE to finish (on the off chance an EXE hangs after install, some do this for some reason) we need to
    # set alternate start-process commands
    Try {
        [array]$script:logOutput += "Beginning installation of $AppName..."
        If ($Arguments) {
            If ($Wait) {
                # Install with arguments and wait
                Start-Process $FileEXEPath -Wait -ArgumentList "$Arguments"
            } Else {
                # Install with arguments and no wait
                Start-Process $FileEXEPath -ArgumentList "$Arguments"
            }
        } Else {
            If ($Wait) {
                # Install with no arguments and wait
                Start-Process $FileEXEPath -Wait
            } Else {
                # Install with no arguments and no wait
                Start-Process $FileEXEPath
            }
        }
        $status = Get-InstalledApplications -ApplicationName $AppName
        If ($status -eq 'Success') {
            [array]$script:logOutput += "Verified the application name [$AppName] is now successfully showing in Add/Remove programs as installed! Script complete."
        } Else {
            [array]$script:logOutput += "$AppName is not reporting back as installed in Add/Remove Programs."
        }
    } Catch {
        [array]$script:logOutput += "Failed to install $AppName. Full error output: $Error"
    }


    # Delete the installer file
    Remove-Item $FileEXEPath -Force


    [array]$script:logOutput = [array]$script:logOutput -join "`n"
    $script:logOutput
}
