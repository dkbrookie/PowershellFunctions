Function Test-ConnectionSpeed {

    <#

    This is a bit quick and dirty and should be cleaned up and put to our standard output methodology
    at some point but this does get the W for now. This is for on demand scripts for techs to remotely
    determine connection speed of a given Windows endpoint
    
    #>

    $downloadURL = "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip"
    #location to save on the computer. Path must exist or it will error
    $workingPath = "$env:windir\LTSvc"
    $downloadPath = "$workingPath\SpeedTest.Zip"
    $extractToPath = "$workingPath\SpeedTest"
    $speedTestEXEPath = "$workingPath\SpeedTest\speedtest.exe"
    #Log File Path
    $logPath = "$workingPath\SpeedTestLog.txt"
    $output = @()


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


    Function RunTest()
    {
        & $SpeedTestEXEPath --accept-license
    }


    #check if file exists
    If (Test-Path $SpeedTestEXEPath -PathType leaf) {
        $output += "SpeedTest EXE Exists, starting test"
        $output += RunTest
    } Else {
        $output += "SpeedTest EXE Doesn't Exist, starting file download"

        #downloads the file from the URL
        (New-Object System.Net.WebClient).DownloadFile($downloadURL,$downloadPath)

        #Unzip the file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Function Unzip {
            param([string]$zipfile, [string]$outpath)

            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
        }

        Unzip $downloadPath $ExtractToPath
        $output += RunTest
    }

    #read results out of log file into string
    $output += (Get-Content -Path $logPath) -join "`n"

    #email results use log file string as body
    Write-Output $output
}