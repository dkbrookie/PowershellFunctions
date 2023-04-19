$dir = "c:\temp"
mkdir $dir -ErrorAction SilentlyContinue
[Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
$webClient = New-Object System.Net.WebClient
$url = "https://go.microsoft.com/fwlink/?LinkID=799445"
$file = "$($dir)\Win10Upgrade.exe"
$webClient.DownloadFile($url,$file)
$proc = Start-Process -FilePath $file -PassThru -Wait -ArgumentList "/quietinstall /skipeula /auto upgrade /copylogs /NoReboot /NoRestartUI /NoRestart $dir"

if ($proc.ExitCode -eq 0) {
  Write-Output "!Success: Upgrade successful"
} else {
  Write-Output "!Error: Upgrade failed. StandardError Output: " + $proc.StandardError
}
