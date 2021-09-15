Function Install-EXE {
    <#
    .SYNOPSIS
    Install-EXE allows you to easily download and install an application via EXE, or via MSI if the EXE 
    contained a zipped MSI installer.

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

    .PARAMETER ExtractInstaller
    Some exe installers are actually a two step process where the first exe you download and launch just
    unpacks the real installer (and sometimes various other files), then you run that extractead exe to 
    install the application. This parameter is to account for that nuance, so if set to $true will then
    require you to answer additional questions about the extraction process in -PathToExtractedInstaller and
    -ExtractrArguments.

    .PARAMETER PathToExtractedInstaller
    Enter the path including the name of the EXE beginning after $env:windir\LTSvc\packages\software\$AppName\. 
    Example: "foldername1\foldername2\unpacker.exe" would set the directory to "$env:windir\LTSvc\packages\
    software\$AppName\foldername1\foldername2\unpacker.exe" (or .msi).

    .PARAMETER ExtractArguments
    These arguments are speciifc to the EXE that needs to be extracted, generally something similar to '-unpack 
    C:\extractfolder.

    .PARAMETER Arguments
    Here you can define all arguments you want to use on the EXE or MSI here.

    .PARAMETER Wait
    Valid values for this argument are $true or $false. This sets the -Wait flag on the Start-Process command of 
    the installer EXE, meaning it will wait for the EXE to continue before moving on if this is set to $true. Set
    to $true if undefined.

    .PARAMETER FileDir
    This is the directory the download files and install logs will be saved to. If you leave this undefined,
    it will default to %windir%\LTSvc\packages\Software\AppName

    .PARAMETER InstallFilePath
    The full path to the EXE installer. If you had a specific location to the EXE file you would define it here.
    Keep in mind you do not have to define the -FileDownloadLink flag, so if you already had a local file or a
    network share file you can just define the path to it here.

    .Parameter AdditionalDownloadLinks
    If the install process requires additional files, please include all URLs here to download to root dir separated 
    by commas. Exampe: 'https://test.com/file.dll','https://test.com/otherfile.ini'. Keep in mind that the download
    URL NEEDS to end with the file extension. In the examples above, the downloaded file would be named 'file.dll'
    and 'otherfile.ini'. This is because we're taking everything after the '/' as the file name + extension.

    .EXAMPLE
    Standard install
    C:\PS> Install-EXE -AppName 'Microsoft Edge' -FileDownloadURL 'https://domain.com/file/file.EXE' -Arguments '/silent'
    C:\PS> Install-EXE -AppName 'Microsoft Edge' -FileDownloadURL 'https://domain.com/file/file.EXE' -InstallFilePath 'C:\windows\ltsvc\packages\software\Microsoft Edge\Microsoft Edge.EXE' -Arguments '/s'

    Extraction before install
    C:\PS> Install-EXE -AppName 'Autodesk DWG TrueView 2022 - English' -FileDownloadLink 'https://efulfillment.autodesk.com/NetSWDLD/2022/ACD/D7A6621A-1A6A-3DAC-BBD2-9EB566035195/SFX/DWGTrueView_2022_English_64bit_dlm.sfx.exe' -ExtractInstaller $true -PathToExtractedInstaller 'DWGTrueView_2022_English_64bit_dlm\Setup.exe' -ExtractArguments "-suppresslaunch -d ""C:\windows\ltsvc\packages\software\Autodesk DWG TrueView""" -InstallArguments '--silent'
    #>


    [CmdletBinding(DefaultParametersetName='none')]

    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the application you want to install exactly as seen in Add/Remove programs."
        )]  [string]$AppName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the full download URL for the installation EXE. This should look something like 'https://website.com/folder/exefile.exe'."
        )]  [string]$FileDownloadLink,
        <# ↓------------------------ Extract EXE ------------------------↓ #>
        [Parameter(
            ParameterSetName = 'extract',
            Mandatory = $false
        )]  [boolean]$ExtractInstaller,
        [Parameter(
            ParameterSetName = 'extract',
            Mandatory = $true,
            HelpMessage = 'Enter the path including the name of the EXE beginning after $env:windir\LTSvc\packages\software\$AppName\. Example: "foldername1\foldername2\unpacker.exe" would set the directory to "$env:windir\LTSvc\packages\software\$AppName\foldername1\foldername2\unpacker.exe".'
        )]  [string]$PathToExtractedInstaller,
        [Parameter(
            ParameterSetName = 'extract',
            Mandatory = $true,
            HelpMessage = "These arguments are speciifc to the EXE that needs to be extracted, generally something similar to '-unpack C:\extractfolder."
        )]  [string]$ExtractArguments,
        <# ↑------------------------ Extract EXE ------------------------↑ #>
        [Parameter(
            HelpMessage = "Enter all arguments to install the EXE, such as /s or /silent."
        )] [string]$Arguments,
        [Parameter(
            HelpMessage = 'Sets the -Wait flag on the Start-Process command of the installer EXE, meaning it will wait for the EXE to continue before moving on if this is set to $true. This is set to $true by default.'
        )]  [boolean]$Wait = $true,
        <# ↓------------------------ Custom Directory ------------------------↓ #>
        [Parameter(
            ParameterSetName = 'dir',
            Mandatory = $false,
            HelpMessage = "If you want to use a custom directory, please specify it here."
        )]  [string]$FileDir,
        [Parameter(
            ParameterSetName = 'dir',
            Mandatory = $true,
            HelpMessage = "When using a custom directory, you also need to specify the name of the install file (including extension) in the custom directory."
        )]  [string]$InstallFilePath,
        <# ↑------------------------ Custom Directory ------------------------↑ #>
        [Parameter(
            Mandatory = $false,
            HelpMessage = "If the install process requires additional files, please include all URLs here to download to root dir separated by commas. Exampe: 'https://test.com/file.dll','https://test.com/otherfile.ini'"
        )]
        [array]$AdditionalDownloadLinks
    )


    # Define vars
    $output = @()

    
    # Quick function to check for successful application install after the installer runs. This is used near the end of the function.
    Function Get-InstalledApplications ($ApplicationName) {

        # Define vars
        [array]$installedApps = @()

        # Applications may be in either of these locations depending on if x86 or x64
        $installedApps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedApps += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }

        If ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
            New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
        }

        # Applications can also install to single user profiles, so we're checking user profiles too
        $installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        $installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }

        # Not using all of this output right now but nice to have it handy in case we want to output any of it later.
        # Also need to sort out if I want to keep using script: scope here or just output to straight string at a
        # later time
        # $script:installedAppNames = $installedApps.DisplayName
        # $script:installedAppDate = $installedApps.InstallDate
        # $script:installedAppUninstallString = $installedApps.UninstallString
        If ($installedApps) {
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
    }


    # Lingering powershell tasks can hold up a successful installation, so here we're saying if a powershell
    # process has been running for more than 90min, and the user is NT Authority\SYSTEM, kill it. System is 
    # significant because it implies the installation was started from a script and not a user, so we're
    # cleaning up without killing processes from the logged in user.
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


    # Create all the dirs we need for a successful download/install, then download required files
    Try {

        # Check for the directory variable and set it if it doesn't exist
        If (!$FileDir) {
            $FileDir = "$env:windir\LTSvc\packages\software\$AppName"
        }

        # Create the directory if it doesn't exist
        If(!(Test-Path $FileDir)) {
            New-Item -ItemType Directory $FileDir | Out-Null
        }

        # Set the path to extraction EXE if the variable was defined
        If ($PathToExtractedInstaller) {
            $PathToExtractedInstaller = $FileDir + '\' + $PathToExtractedInstaller
        }
        # Set the path for the EXE installer
        If (!$InstallFilePath) {
            $InstallFilePath = "$FileDir\$($AppName).exe"
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

        If((Test-Path $InstallFilePath -PathType Leaf)) {
            # If the file already exists, delete it so we can download a fresh copy. It may be a different version so this ensures we're
            # working with the installer we intended to.
            Remove-Item $InstallFilePath -Force
        }

        # Download the file!
        (New-Object System.Net.WebClient).DownloadFile($FileDownloadLink,$InstallFilePath)

    } Catch {
        $output += "Failed to download $FileDownloadLink to $InstallFilePath. Unable to proceed with install without the installer file, exiting script."
        Break
    }


    # If this script is started from Automate with nothing defined for extract installer, it will pass in
    # 'Empty' instead of $false. This is because of some weird ways Automate handles NULL...this just makes
    # it easier to account for.
    If ($ExtractInstaller -eq 'Empty') {
        $ExtractInstaller = $false
        $output += 'Found that the variable $ExtractInstaller was set to "Empty" (presumeably from Automate) so have updated $ExtractInstaller to "$false" value.'
    }

    If ($ExtractInstaller) {
        # This means yes we need to extract an EXE before install
        Start-Process $InstallFilePath -ArgumentList $ExtractArguments -Wait
        # Update the installer EXE path to the path of the extracted EXE. The file we downloaded was just for extracting,
        # the file we just unpacked is what we execute to install
        $output += 'Setting the $installFilePath value to the value of $PathToExtractedInstaller...'
        $InstallFilePath = $PathToExtractedInstaller
    }


    # Since we added the option to NOT wait for the EXE to finish (on the off chance an EXE hangs after install, some do this for some reason) we need to
    # create alternative start-process commands
    Try {
        $output += "Beginning installation of $AppName..."
        If ($InstallFilePath -like '*.exe') {
        $output += "Found the installer is a .EXE file, Attempting install with EXE arguments..."
            $installHash = @{
                FilePath = $InstallFilePath
                ArgumentList = $Arguments
                Wait = $Wait
            }
        } ElseIf ($InstallFilePath -like '*.msi') {
            $output += "Found the installer is a .MSI file, Attempting install with MSI arguments..."
            $installHash = @{
                FilePath = "msiexec.exe"
                ArgumentList = "/i ""$InstallFilePath"" $Arguments"
                Wait = $Wait
            }
        } Else {
            $output += "No relevant installation file type was found in $InstallFilePath. Exiting script."
            $output = $output -join "`n"
            Write-Output $output
            Break
        }

        # Time to actually install this thing!
        Start-Process @installHash

        # Check to see if the installation was successful
        $status = Get-InstalledApplications -ApplicationName $AppName
        If ($status -eq 'Success') {
            $output += "Verified the application [$AppName] was successfully installed! Script complete."
        } Else {
            $output += "$AppName is not reporting back as installed in Add/Remove Programs."
        }
    } Catch {
        $output += "Failed to install $AppName."
    }


    # Delete the installer file
    Try {
        $output += "Removing installation files..."
        Remove-Item $FileDir -Force -Recurse
        $output += "Successfully removed installation files!"
    } Catch {
        $output += "Failed to remove installation files. This isn't necassarily a problem as disk cleanup will try again later, but logging just in case this info is relevant later."
    }


    $output += "For potential troubleshooting needs, here is the full error output: $Error"


    $output = $output -join "`n"
    Write-Output $output
}