Function Install-MSI {
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

    .PARAMETER FileDownloadLink
    This will be the download link to the MSI file. Make sure to include the FULL URL including the http://

    .PARAMETER FileDir
    This is the directory the download files and install logs will be saved to. If you leave this undefined,
    it will default to %windir%\LTSvc\packages\Software\AppName

    .PARAMETER FileMSIPath
    The full path to the MSI installer. If you had a specific location to the MSI file you would define it here.
    Keep in mind you do not have to define the -FileDownloadLink flag, so if you already had a local file or a
    network share file you can just define the path to it here.

    .PARAMETER LogPath
    The full path to where you want the installation logs saved. By default, the logs will be saved in the same
    directory as your install files in %windir%\LTSvc\packages\Software\AppName\Install Log - App Name.txt

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the MSI. By defualt, /qn and /i will be applied for install
    and silent, but if you define this parameter then you will need to add /i and /qn manually. See examples...

    .PARAMETER Wait
    Valid values for this argument are $true or $false. This sets the -Wait flag on the Start-Process command of 
    the installer MSI, meaning it will wait for the MSI to continue before moving on if this is set to $true. Set
    to $true if undefined.

    .Parameter AdditionalDownloadLinks
    If the install process requires additional files, please include all URLs here to download to root dir separated 
    by commas. Exampe: 'https://test.com/file.dll','https://test.com/otherfile.ini'. Keep in mind that the download
    URL NEEDS to end with the file extension. In the examples above, the downloaded file would be named 'file.dll'
    and 'otherfile.ini'. This is because we're taking everything after the '/' as the file name + extension.

    .EXAMPLE
    C:\PS> Install-MSI -AppName 'SuperApp' -FileDownloadURL 'https://domain.com/file/file.msi' -Arguments '/qn /norestart'
    C:\PS> Install-MSI -AppName 'SuperApp' -FileDownloadURL 'https://domain.com/file/file.msi' -Arguments '/qn /norestart' -FileMSIPath "C:\windows\ltsvc\packages\softwar\superapp\superapp.msi" -LogPath "C:\install log.txt"
    C:\PS> Install-MSI -AppName 'SuperApp' -FileDownloadURL 'https://domain.com/file/file.msi' -Arguments '/qn /norestart' -AdditionalDownloadLinks 'https://test.com/file.dll','https://test.com/otherfile.ini'
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
            HelpMessage = "Please enter the full download URL for the installation MSI. This should look something like 'https://website.com/folder/MSIfile.MSI'."
        )]
        [string]$FileDownloadLink,
        [string]$FileDir,
        [string]$FileMSIPath,
        [string]$LogPath,
        [Parameter(
            Mandatory=$True,
            HelpMessage="DO NOT use /i or /l, these are already specified! Enter all other arguments to install the MSI, such as /qn and /norestart"
        )][string]$Arguments,
        [Parameter(
            Mandatory = $false,
            HelpMessage = 'Sets the -Wait flag on the Start-Process command of the installer MSI, meaning it will wait for the MSI to continue before moving on if this is set to $true. This is set to $true by default.'
        )]
        [boolean]$Wait = $true,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "If the install process requires additional files, please include all URLs here to download to root dir separated by commas. Exampe: 'https://test.com/file.dll','https://test.com/otherfile.ini'"
        )]
        [array]$AdditionalDownloadLinks
    )


    # Define vars
    $output = @()


    # Lingering powershell tasks can hold up a successful installation, so here we're saying if a powershell
    # process has been running for more than 90min, and the user is NT Authority\SYSTEM, kill it
    [array]$processes = Get-Process -Name powershell -IncludeUserName -EA 0 | Where-Object { $_.UserName -eq 'NT AUTHORITY\SYSTEM' }
    If ($processes) {
        ForEach ($process in $processes) {
            $timeOpen = New-TimeSpan -Start (Get-Process -Id $process.ID).StartTime
            If ($timeOpen.TotalMinutes -gt 90) {
                Try {
                    $output += "Found the process [$($process.Name)] has been running for 90+ minutes. Killing this off to ensure a successful installation..."
                    Stop-Process -Id $process.Id -Force
                    $output += "[$($process.Name)] has been successfully stopped."
                } Catch {
                    $output += "There was an error when trying to end the $($process.Name)] process."
                }
            }
        }
    }


    # To ensure successful downloads we need to set TLS protocal type to Tls1.2. Downloads regularly fail via Powershell without this step.
    Try {
        # Oddly, this command works to enable TLS12 on even Powershellv2 when it shows as unavailable. This also still works for Win8+
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
        $output += "Successfully enabled TLS1.2 to ensure successful file downloads."
    } Catch {
        $output += "Encountered an error while attempting to enable TLS1.2 to ensure successful file downloads. This can sometimes be due to dated Powershell. Checking Powershell version..."
        # Generally enabling TLS1.2 fails due to dated Powershell so we're doing a check here to help troubleshoot failures later
        $psVers = $PSVersionTable.PSVersion
        If ($psVers.Major -lt 3) {
            $output += "Powershell version installed is only $psVers which has known issues with this script directly related to successful file downloads. Script will continue, but may be unsuccessful."
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

        # Poweshell returns $null arrays that have multiple $null entires as truey. To combat this, we're 
        # converting the array to a string to check for the number of characters in the output string. If 
        # it was an array of $null, the characters returned here will be 0 so we can be sure application 
        # is NOT installed.
        If (($installedApps | Out-String).Length -ne 0) {
            If ($installedApps.Count -gt 1) {
                $script:output += "Multiple applications found with the word(s) [$AppName] in the display name in Add/Remove programs. See list below..."
                $script:output += $installedAppNames
            }
            Return 'Success'
        } Else {
            Return 'Failed'
        }
    }


    # Check to see if the application is already installed. If it is, exit the script.
    $status = Get-InstalledApplications -ApplicationName $AppName
    If ($status -eq 'Success') {
        $output += "The application name [$AppName] is already installed! Script complete."
        $output = $output -join "`n"
        Write-Output $output
        Break
    } Else {
        $output += "Confirmed [$AppName] is not installed, proceeding with installation process"
    }


    # Create all the dirs we need for a successful download/install, and download required files
    Try {
        # Check for the directory variable and set it if it doensn't exist
        If (!$FileDir) {
            $FileDir = "$env:windir\LTSvc\packages\software\$AppName"
        }
        # Create the directory if it doesn't exist
        If(!(Test-Path $FileDir)) {
            New-Item -ItemType Directory $FileDir | Out-Null
        }
        # Set the path for the MSI installer
        If (!$FileMSIPath) {
            $FileMSIPath = $FileDir + '\' + $AppName + '.msi'
        }

        # Download additional files if any are defined
        If ($AdditionalDownloadLinks) {
            ForEach ($additionalDownloadLink in $AdditionalDownloadLinks) {
                # Get the file name including the extension from the download URL
                $additionalFileName = ($AdditionalDownloadLink.Split('/'))[-1]
                $additionalFilePath = $FileDir + '\' + $additionalFileName
                (New-Object System.Net.WebClient).DownloadFile($additionalDownloadLink,$additionalFilePath)
            }
        }

        # Download the MSI if it doens't exist, delete it and downlaod a new one of it does
        If(!(Test-Path $FileMSIPath -PathType Leaf)) {
            (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileMSIPath)
        # If the file already exists, delete it so we can download a fresh copy. It may be a different version so this ensures we're
        # working with the installer we intended to.
        } Else {
            Remove-Item $FileMSIPath -Force
            (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$FileMSIPath)
        }

        # Set the path for logs if it doesn't exist
        If (!$LogPath) {
            $LogPath = $FileDir + '\Install Log - ' + $AppName + '.txt'
        }
    } Catch {
        $output += "Failed to download $FileDownloadLink to $FileMSIPath. Unable to proceed with install without the installer file, exiting script."
        $output = $output -join "`n"
        Write-Output $output
        Break
    }


    Try {
        If ((Get-Process -Name msiexec -EA 0)) {
            $output += "Detected msiexec is already running in the background. End tasking this to ensure a successful MSI deployment..."
             Stop-Process -Name msiexec -Force
            $output += "msiexec ended successfully."
        }
    } Catch {
        $output += "Encountered an error when attempting to end msiexec. Installation attempt still proceeding, but msiexec already running may cause issues with the install."
    }

    Try {
        $output += "Beginning installation of $AppName..."
        If ($Arguments) {
            If ($Wait) {
                # Install with arguments and wait
                Start-Process msiexec.exe -Wait -ArgumentList "/i ""$FileMSIPath"" $Arguments /l*v ""$LogPath"""
            } Else {
                # Install with arguments and no wait
                Start-Process msiexec.exe -ArgumentList "/i ""$FileMSIPath"" $Arguments /l*v ""$LogPath"""
            }
        } Else {
            If ($Wait) {
                # Install with no arguments and wait
                Start-Process msiexec.exe -Wait -ArgumentList "/i ""$FileMSIPath"" /l*v ""$LogPath"""
            } Else {
                # Install with no arguments and no wait
                Start-Process msiexec.exe -ArgumentList "/i ""$FileMSIPath"" /l*v ""$LogPath"""
            }
        }
        $status = Get-InstalledApplications -ApplicationName $AppName
        If ($status -eq 'Success') {
            $output += "Verified the application name [$AppName] is now successfully showing in Add/Remove programs as installed! Script complete."
        } Else {
            $output += "$AppName is not reporting back as installed in Add/Remove Programs."
        }
    } Catch {
        $output += "Failed to install $AppName."
    }


    $output += "For potential troubleshooting needs, here is the full error output: $Error"


    # Delete install files
    Remove-Item $FileDir -Exclude '*.txt' -Recurse -Force


    $output = $output -join "`n"
    Write-Output $output
}
