# Author: Sheen Ismhael Lim
# Date Created: Dec 8 2021
# This script will check the Exchange Server components and will try to set the components to 'Active' with exception to the component 'ServerWideOffline'
# This script is targeted to only Exchagne 2016 Servers

Param(
    [Parameter(HelpMessage="Determines if the script is ran by Automate 'Y' or ran by manual check 'N'.")]
    [ValidateSet('Y','N')]
    [string]$RunAsMonitor = 'N',
    [Parameter(HelpMessage='Determines if a copy of the logs should be printed on the \LTSvc\componentMonitor directory of the server being monitored.')]
    [ValidateSet('Y','N')]
    [string]$FileOutput = 'N',
    [Parameter(HelpMessage='Determines if the component state should be set to Active, except ServerWideOffline.')]
    [ValidateSet('Y','N')]
    [string]$RecoverStates = 'N'
)

."C:\Program Files\Microsoft\Exchange Server\V15\bin\RemoteExchange.ps1"
Connect-ExchangeServer -auto -ClientApplication:ManagementShell

$consoleStatusMessage = ""
$consoleScriptStatus = "Success"
$hasAnyComponentFailed = $false
function Test-ExchangeComponents {
    $components = Get-ServerComponentState -Identity $env:computername
    
    $isServerWideOfflineActive = $(Get-ServerComponentState -Identity $env:computername -Component ServerWideOffline).State
    if ($isServerWideOfflineActive -eq "Active") { # ServerWideOffline will always be returned as first item in the Get-ServerComponent
        try {
            $components | ForEach-Object {
                if ($_.State -ne "Active" -and $_.Component -ne "ServerWideOffline") {
                    $message = "The Exchange Component '$($_.Component)' has been observed to not in the 'Active' State";
                    $script:logOutput += $message
                    $consoleStatusMessage += $message
    
                    if ($RecoverStates -eq 'Y') {
                        $message = "Attempting to set the component to 'Active'"
                        Set-ServerComponentState -Identity $env:computername -Component $_ -State 'Active'
                        $hasAnyComponentFailed = $false;

                    } else {
                        $hasAnyComponentFailed = $true;

                    }
                    
                } else {
                    $message = "The Exchange Component '$($_.Component)' is 'Active'";
                    $script:logOutput += $message
                    $consoleStatusMessage += $message
                }
            }
        }
        catch {
            $hasAnyComponentFailed = $true
            $message = "An error has occured causing the script Test-ExchangeServer to fail on $($env:computername)."
        }

        if ($hasAnyComponentFailed) {
            $consoleScriptStatus = 'Failed'
            $script:status = 'Failed'
        }

        $consoleScriptStatus = 'Success'
        $script:status = 'Success'
    } else {
        # Auto Recovery for the ServerWideOffline component is not set since this is the component most Exchange administrators turn off to deliberately stop the Exchange server from 
        # Doing its roles. This is primary done when putting the server in maintenance mode for an update.
        $script:logOutput = "The ServerWideOffline component state is not Active, all of the components of Exchange Server will not function regardless even if exchange services are running."
        $consoleScriptStatus = 'Failed'
        $script:status = 'Failed'
    }

    ## Final output to parse with Automate
    $outputDir = "$env:windir\LTSvc\componentMonitor"
    if (!(Test-Path $outputDir)) {
        New-Item $outputDir -ItemType Directory | Out-Null
    } else {
        Remove-Item "$outputDir\*"
    }
    switch ($script:status) {
        'Success' {$outputFile = "$outputDir\Success.txt"}
        'Failed' {$outputFile = "$outputDir\Failed.txt"}
    }

    if ($RunAsMonitor -eq 'Y') {
        "$consoleScriptStatus"
    } else {
        if ($FileOutput -eq 'Y') {
        Set-Content -Value "Status=$logOutput|Status=$status" -Path $outputFile
        } else {
            "logOutput=$logOutput|Status=$status"
        }
    }
}

Test-ExchangeComponents
