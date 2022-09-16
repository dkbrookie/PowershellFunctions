Function Test-ConnectionSpeed {

    <#

    This is a bit quick and dirty and should be cleaned up and put to our standard output methodology
    at some point but this does get the W for now. This is for on demand scripts for techs to remotely
    determine connection speed of a given Windows endpoint
    
    #>

    $DownloadURL = "https://install.speedtest.net/app/cli/ookla-speedtest-1.0.0-win64.zip"
    #location to save on the computer. Path must exist or it will error
    $workingPath = "$env:SystemDrive\temp"
    $downloadPath = "$workingPath\SpeedTest.Zip"
    $extractToPath = "$workingPath\SpeedTest"
    $speedTestEXEPath = "$workingPath\SpeedTest\speedtest.exe"
    #Log File Path
    $logPath = "$workingPath\SpeedTestLog.txt"
    $output = @()

    
    #Start Logging to a Text File
    $ErrorActionPreference="SilentlyContinue"
    Stop-Transcript | out-null
    $ErrorActionPreference = "Continue"
    Start-Transcript -path $logPath -Append:$false


    Function RunTest()
    {
        $test = & $SpeedTestEXEPath --accept-license
        $test
    }


    #check if file exists
    If (Test-Path $SpeedTestEXEPath -PathType leaf) {
        $output += "SpeedTest EXE Exists, starting test"
        RunTest
    } Else {
        $output += "SpeedTest EXE Doesn't Exist, starting file download"

        #downloads the file from the URL
        wget $DownloadURL -outfile $DownloadPath

        #Unzip the file
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        Function Unzip {
            param([string]$zipfile, [string]$outpath)

            [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
        }

        Unzip $DownloadPath $ExtractToPath
        RunTest
    }

    #read results out of log file into string
    $output += (Get-Content -Path $logPath) -join "`n"

    #email results use log file string as body
    Write-Output $output

    #stop logging
    Stop-Transcript
}