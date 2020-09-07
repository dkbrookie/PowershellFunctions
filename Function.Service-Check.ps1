Function Service-Check {
    <#
    .SYNOPSIS
    Attempt auto start of services that are stopped

    .DESCRIPTION
    This script allows you to specify a list of services that you'd like to check if running. If the service(s)
    are not running, this script will attempt to start them as long as the machine has been booted longer than 
    15min (This low of uptime could imply the services just aren't done starting yet). If the service is disabled, 
    it will just inform you the service is disabled with a warning, but will not attempt to enable the service 
    (generally a disabled server is intentional so automatically re-enabling could cause problems). If the service 
    fails to start, it wil attempt to start it 3 times total, then it will check the running status of that services 
    dependencies and start the dependencies automatically if you specify the $StartDependencies as $True.

    .EXAMPLE
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau -AcceptableUptime 30
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau -AcceptableUptime 30 -StartDependencies $True
    
    .NOTES
    Script output is separated by "|"" so it's easier to parse results in Automate.

    At the end of the script, $status is your ending indicator to tell you if you have a problem or not. If it's
    'Success' you're good, if it's 'Warning' you may have an issue to address, and if it's 'Failed' you know you
    have a problem that needs attention.
    #>

    [CmdletBinding()]

    Param(
        [Parameter(
            HelpMessage='Please enter the name of the service(s) you want to check the status of and attempt to restart'
        )][array]$ServiceList
        ,[int]$AcceptableUptime
        ,[switch]$StartDependencies
        ,[Parameter(
            HelpMessage='Choose the role you want to monitor. Each role contains an array of services needed for the given role to check automatically.'
        )]
        [ValidateSet('AD','DHCP','DNS','Print','MSSQL','MySQL','Exchange','Connectwise Control')]
        [string]$Role
    )

    If (!$AcceptableUptime) {
        $AcceptableUptime = 15
    }

    ## Define list of services per server role
    [array]$roleAD = 'ADWS','NTDS','Netlogon','W32Time','LanmanServer','RpcSs','kdc'
    [array]$roleDHCP = 'DHCPServer','DHCP'
    [array]$roleDNS = 'Dnscache','DNS'
    [array]$rolePrint = 'Spooler'
    [array]$roleMSSQL = 'MSSQLSERVER','SQLBrowser','SQLWriter','MsDtsServer100','MsDtsServer 110','MsDtsServer120','MsDtsServer130','MsDtsServer140','MSSQLServerOLAPService','SQLServerAgent'
    [array]$roleMySQL = 'MySQL'
    [array]$roleExchange = 'EdgeCredentialSvc','HostControllerService','IMAP4Svc','MSComplianceAudit','MSExchangeAB','MSExchangeADAM','MSExchangeADTopology','MSExchangeAntispamUpdate','MSExchangeCompliance','MSExchangeDagMgmt','MSExchangeDelivery','MSExchangeDiagnostics','MSExchangeEdgeCredential','MSExchangeEdgeSync','MSExchangeFastSearch','MSExchangeFBA','MSExchangeFDS','MSExchangeFrontEndTransport','MSExchangeHM','MSExchangeHMRecovery','MSExchangeIMAP4','MSExchangeIMAP4BE','MSExchangeIS','MSExchangeMailboxReplication','MSExchangeMailSubmission','MSExchangeMGMT','MSExchangeMailboxAssistants','MSExchangeMTA','MSExchangeNotificationsBroker','MSExchangePOP3','MSExchangePOP3BE','MSExchangeProtectedServiceHost','MSExchangeRepl','MSExchangeRPC','MSExchangeSA','MSExchangeSearch','MSExchangeServiceHost','MSExchangeSubmission','MSExchangeThrottling','MSExchangeTransport','MSExchangeTransportLogSearch','MSExchangeUM','MSExchangeUMCR','MSSpeechService','POP3Svc','RESvc','SMTPSVC','WSBExchange'
    [array]$roleControl = 'ScreenConnect Relay','ScreenConnect Session Manager','ScreenConnect Web Server'

    ## Set the list of services for the role to the list of services to check
    If ($Role -eq 'AD') {
        $ServiceList = $roleAD
    } ElseIf ($Role -eq 'DHCP') {
        $ServiceList = $roleDHCP
    } ElseIf ($Role -eq 'DNS') {
        $ServiceList = $roleDNS
    } ElseIf ($Role -eq 'Print') {
        $ServiceList = $rolePrint
    } ElseIf ($Role -eq 'MSSQL') {
        $ServiceList = $roleMSSQL
    } ElseIf ($Role -eq 'MySQL') {
        $ServiceList = $roleMySQL
    } ElseIf ($Role -eq 'Exchange') {
        $ServiceList = $roleExchange
    } ElseIf ($Role -eq 'Connectwise Control') {
        $ServiceList = $roleControl
    } ElseIf (!$Role) {
        $script:logOutput += "No recognized role was defined, checking service list..."
        If (!$ServiceList) {
            $script:logOutput += "'ServiceList' variable was also blank. No services have been defined to check. Exiting script."
            Break
        }
    }

    $os = Get-WmiObject win32_operatingsystem
    $days = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).TotalDays * 24 * 60
    $hours = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).Hours * 60
    $minutes = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).Minutes
    $upTime = $days + $hours + $minutes
    $script:upTime = [math]::Round($upTime)
    If ($upTime -gt 15) {
        ForEach ($service in $ServiceList) {
            Try {
                #$serviceStatus = (Get-WmiObject win32_service -Filter "Name = '$service' AND startmode <> 'Disabled' AND state <> 'Running'").State
                $serviceStart = (Get-Service -Name $service -ErrorAction Stop).StartType
                If ($serviceStart -eq 'Disabled') {
                    If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                        $script:Status = 'Warning'
                    }
                    $script:logOutput += "$service is set to $serviceStart, unable to start service`r`n"
                    $script:disabled = $True
                }
            } Catch {
                If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                    $script:Status = 'Warning'
                }
                $script:logOutput += "$service does not exist!`r`n"
                $script:disabled = $True
            }
            $script:checkDependency = $False
            Service-Restart -serviceRestart $service
            ## If the service failed to start, in the function we would have set $checkDependency to $True. This is because the service still isn't started
            ## so maybe it's related to a dependency that isn't started yet
            If ($script:checkDependency -eq $True) {
                ## Get a list of dependencies and then print them into the output
                $dependencies = Get-Service -Name $service -RequiredServices | Where-Object { $_.Status -ne 'Running'}
                If ($dependencies) {
                    $dependencyCount = $dependencies.Count
                    $script:logOutput += "$service has $dependencyCount dependency services not currently running. This may be the cause for the service failing to start.`r`n"
                    $dependencies
                    ## If $StartDependencies is true, try to start all dependencies that are not running 
                    If ($StartDependencies) {
                        Try {
                            ForEach ($dependency in $dependencies) {
                                $dependencyName = ($dependency).Name
                                $dependencyStatus = (Get-Service -Name $dependency -ErrorAction Stop).Status
                                If ($dependencyStatus -ne 'Running') {
                                    Service-Restart -serviceRestart $dependencyName
                                }
                            }
                        } Catch {
                            If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                                $script:Status = 'Warning'
                            }
                            $script:logOutput += "$dependencyName does not exist!`r`n"
                            $script:disabled = $True
                        }
                    }
                } Else {
                    $script:logOutput += "Verified $service has no dependencies, so this will not be a factor in the cause for the service not starting. `r`n"
                }
            }
        }
        ## Maybe not the best way, but I'm adding to the strings for what service were started or failed as
        ## a total result and they end up with a comma at the end so these two lines just nuke the ending comma
        If ($script:successfulRestarts) {
            $successfulRestarts = $script:successfulRestarts.Substring(0,$successfulRestarts.Length-1)
        }
        If ($script:failedRestarts) {
            $failedRestarts = $script:failedRestarts.Substring(0,$failedRestarts.Length-1)
        }
        ## Final output to parse with Automate
        "Status=$status|logOutput=$logOutput|uptime=$uptime|successfulRestarts=$successfulRestarts|failedRestarts=$failedRestarts"
    } Else {
        $script:logOutput += "$env:COMPUTERNAME has only been powered on for $upTime minutes so services not being started is expected. Will check again once computer has reach $AcceptableUptime minutes or greater of uptime.`r`n"
        Break
    }
}


Function Service-Restart {
    <#
    .SYNOPSIS
    Restart service function

    .DESCRIPTION
    This is just the function to restart the service 3 times if it's stopped. Most of the description for the function
    above is still accurate and this is just some of the bones to make that top function work.
    
    .EXAMPLE
    Service-Restart -ServiceRestart LTService
    
    .NOTES
    This is just for individual services. The function above (Service-Check) runs a loop to cycle through this.
    #>

    [CmdletBinding()]

    Param(
        [string]$serviceRestart
    )

    ## We're going to try to restart the service 3 times so this just gives us a base 1 to increment from to count our total loops
    $retryCount = 1
    Do {
        Try {
            ## If the service is disabled, don't even attempt to start it
            If ($disabled -ne $True) {
                ## Get the current status of the service
                $serviceStatus = (Get-Service -Name $serviceRestart).Status
                If ($serviceStatus -ne 'Running') {
                    ## Attempt to start the service, then check to make sure the status of the service is Running after 15sec.
                    ## If the status is still not running, it will try a total of 3 times to get it to a running state.
                    $script:logOutput += "$serviceRestart not running. Attempt #$retryCount to start $serviceRestart...`r`n"
                    Start-Service $serviceRestart -ErrorAction Stop
                    Start-Sleep 15
                    $serviceStatus = (Get-Service -Name $serviceRestart).Status
                    If ($serviceStatus -ne 'Running') {
                        Throw
                    } Else {
                        If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                            $script:Status = 'Success'
                            $script:successfulRestarts += $serviceRestart + ','
                        }
                        $script:logOutput += "Successfully started $serviceRestart`r`n"
                        $stopLoop = $True
                    }
                } Else {
                    $script:Status = 'Success'
                    $script:logOutput += "Verified $service is running!`r`n"
                }
            }
        } Catch {
            If ($retryCount -eq 3) {
                ## If we got here, it means we've tried to restart the service 3 times already and it's failed
                If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                    $script:Status = 'Failed'
                    $script:failedRestarts += $serviceRestart + ','
                }
                $script:logOutput += "Failed to start the $serviceRestart service after 3 attempts.`r`n"
                ## Set $checkDependency to $True so the next part of the script will know to check the running status of all dependencies
                ## for the service currently failing to start
                If ($script:checkDependency -ne $True) {
                    $script:checkDependency = $True
                }
                $stopLoop = $True
            } Else {
                $retryCount++
                $stopLoop = $False
            }
        }
    }
    ## As long as the $stoploop is false keep trying the loop again. The loop is set to false after 3 fails in a row.
    While ($stopLoop -eq $False)
    ## Reset the retry counter
    $script:retryCount = 1
    ## Reset the disabled var for the next service check
    $script:disabled = $False
}

