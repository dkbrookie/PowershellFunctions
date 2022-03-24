Function Service-Check {
    <#
    .SYNOPSIS
    Attempt auto start of services that are stopped.

    .DESCRIPTION
    This script allows you to specify a list of services that you'd like to check if running. If the service(s)
    are not running, this script will attempt to start them as long as the machine has been booted longer than
    15min (This low of uptime could imply the services just aren't done starting yet). If the service is disabled,
    it will just inform you the service is disabled with a warning, but will not attempt to enable the service
    (generally a disabled service is intentional so automatically re-enabling could cause problems). If the service
    fails to start, it will attempt to start it 3 times total, then it will check the running status of that services
    dependencies and start the dependencies automatically if you specify the $StartDependencies as $True. This will
    output the results to $env:windir\LTSvc\serviceMonitor\$status.txt ($status will be Success, Warning, or Failed).

    .PARAMETER ServiceList
    Set to Y if you want the final output to go to a text file at $env:windir\LTSvc\serviceMonitor\[reuslt].txt. By
    default this is set to N and will output to console.

    .PARAMETER Role
    Specify the server role / application you want to monitor. Each role has a set of services associated to the role.
    Not all services will always be present depending on the version of the role, so the script will just output a
    warning if the service doesn't exist. This means you really only need to worry about an output of $status = FAILED
    since this would mean the service SHOULD be running and isn't.

    .PARAMETER CheckDependencies
    Set to Y if you want to check the status of all dependencies. This is Y unless manually set to N here.

    .PARAMETER StartDependencies
    Set to Y if you want to automatically attempt to start all dependencies with the same logic as the primary service.
    This is N unless manually set to Y here.

    .PARAMETER FileOutput
    If running as a monitor is set to Y the output will just be SUCCESS, WARNING, or FAILED. By default this is set to N.

    .PARAMETER RunAsMonitor
    If running as a monitor is set to Y the output will just be SUCCESS, WARNING, or FAILED. By default this is set to N.

    .EXAMPLE
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau -AcceptableUptime 30
    Service-Check -ServiceList DHCP,LTSvcmon,LTService,wuau -AcceptableUptime 30 -StartDependencies $True
    Check and start the AD, DHCP, and DNS services and dependencies. For the output only show $status (Success, Warning, or Failed)
    Service-Check -Role AD,DHCP,DNS -StartDependencies Y -RunAsMonitor Y

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
        ,[Parameter(
            HelpMessage='Set to Y if you want the final output to go to a text file at $env:windir\LTSvc\serviceMonitor\[reuslt].txt. By default this is set to N and will output to console.'
        )]
        [ValidateSet('AD','Apache','Autodesk','AutoElevate','Citrix XenApp','Connectwise Automate Server','Connectwise Control Endpoint','Connectwise Control Server','Connectwise Manage','DHCP','DNS','EleVia','Exchange','Hyper-V','IIS','Lighthouse','ManageEngine Password Self Reset','Microsoft Dynamics','MSSQL','MySQL','Nessus','Netwrix','Perch Log Shipper','PostgreSQL','Print','ProjectWise','Quickbooks','Roar','SCVMM','Sentinel Licensing Server','SentinelOne','Sharepoint','Trimble','Umbrella','Veeam Agent','Veeam B&R','Webroot','Windows Server','Windows Workstation')]
        [array]$Role
        ,[int]$AcceptableUptime = 15
        ,[Parameter(
            HelpMessage='Set to Y if you want to check the status of all dependencies. This is Y unless manually set to N here.'
        )]
        [ValidateSet('Y','N')]
        [string]$CheckDependencies = 'Y'
        ,[Parameter(
            HelpMessage='Set to Y if you want to automatically attempt to start all dependencies with the same logic as the primary service. This is N unless manually set to Y here.'
        )]
        [ValidateSet('Y','N')]
        [string]$StartDependencies = 'N'
        ,[Parameter(
            HelpMessage='Set to Y if you want to automatically attempt to start all dependencies with the same logic as the primary service. This is N unless manually set to Y here.'
        )]
        [ValidateSet('Y','N')]
        [string]$FileOutput = 'N'
        ,[Parameter(
            HelpMessage='If running as a monitor is set to Y the output will just be SUCCESS, WARNING, or FAILED. By default this is set to N'
        )]
        [ValidateSet('Y','N')]
        [string]$RunAsMonitor = 'N'
    )

    ## Here we define which services we want to check per role
    Switch ([array]$Role) {
        'AD'                                { [array]$ServiceList += 'ADWS','NTDS','Netlogon','W32Time','LanmanServer','RpcSs','kdc' }
        'Apache'                            { [array]$ServiceList += 'Apache*' }
        'Autodesk'                          { [array]$ServiceList += 'Autodesk' }
        'AutoElevate'                       { [array]$ServiceList += 'AESMService' }
        'Citrix XenApp'                     { [array]$ServiceList += 'Citrix Encryption Service','Citrix Licensing','CitrixCseEngine','CitrixHealthMon','Citrix_GTLicensingProv','TSGateway','sshd' }
        'Connectwise Automate Server'       { [array]$ServiceList += 'LabMySQL','LTAgent','LTRedirSvc','LTSCServiceMon','LTSCService' }
        'Connectwise Control Endpoint'      { [array]$ServiceList += 'ScreenConnect Client (dc46be1169788118)' }
        'Connectwise Control Server'        { [array]$ServiceList += 'ScreenConnect Relay','ScreenConnect Session Manager','ScreenConnect Web Server' }
        'Connectwise Manage'                { [array]$ServiceList += 'EmailRobot','CwManageSmtpRelay','NsnClientService','OutlookSync','ConnectWiseUpdaterService','ConnectWiseApiCallbackService','ConnectWiseEmailAuditService' }
        'DHCP'                              { [array]$ServiceList += 'DHCPServer','DHCP' }
        'DNS'                               { [array]$ServiceList += 'Dnscache','DNS' }
        'EleVia'                            { [array]$ServiceList += 'EleVia Email Service','EleVia Invoice Watcher' }
        'Exchange'                          { [array]$ServiceList += 'EdgeCredentialSvc','HostControllerService','IMAP4Svc','MSComplianceAudit','MSExchangeAB','MSExchangeADAM','MSExchangeADTopology','MSExchangeAntispamUpdate','MSExchangeCompliance','MSExchangeDagMgmt','MSExchangeDelivery','MSExchangeDiagnostics','MSExchangeEdgeCredential','MSExchangeEdgeSync','MSExchangeFastSearch','MSExchangeFBA','MSExchangeFDS','MSExchangeFrontEndTransport','MSExchangeHM','MSExchangeHMRecovery','MSExchangeIMAP4','MSExchangeIMAP4BE','MSExchangeIS','MSExchangeMailboxReplication','MSExchangeMailSubmission','MSExchangeMGMT','MSExchangeMailboxAssistants','MSExchangeMTA','MSExchangeNotificationsBroker','MSExchangePOP3','MSExchangePOP3BE','MSExchangeProtectedServiceHost','MSExchangeRepl','MSExchangeRPC','MSExchangeSA','MSExchangeSearch','MSExchangeServiceHost','MSExchangeSubmission','MSExchangeThrottling','MSExchangeTransport','MSExchangeTransportLogSearch','MSExchangeUM','MSExchangeUMCR','MSSpeechService','POP3Svc','RESvc','SMTPSVC','WSBExchange' }
        'Hyper-V'                           { [array]$ServiceList += 'vmms','vhdsvc','nvspwmi' }
        'IIS'                               { [array]$ServiceList += 'IISAdmin','W3SVC' }
        'Lighthouse'                        { [array]$ServiceList += 'LICENCESERVER','DBSERVER' }
        'ManageEngine Password Self Reset'  { [array]$ServiceList += 'ADSelfServicePlus','ADManager Plus','ADAudit Plus','ManageEngineAnalyticsPlusServer' }
        'Microsoft Dynamics'                { [array]$ServiceList += 'MicrosoftDynamicsNavServer','MicrosoftDynamicsNavWS' }
        'MSSQL'                             { [array]$ServiceList += 'MSSQLSERVER','SQLBrowser','SQLWriter','MsDtsServer100','MsDtsServer 110','MsDtsServer120','MsDtsServer130','MsDtsServer140','MSSQLServerOLAPService','SQLServerAgent' }
        'MySQL'                             { [array]$ServiceList += 'MySQL' }
        'Nessus'                            { [array]$ServiceList += 'Tenable Nessus' }
        'Netwrix'                           { {array}$ServiceList += 'NwADASitSvc','NwAdfsSvc','NwArchiveSvc','NwCfgServerSvc','NwCoreSvc','NwDataClassificationSvc','NwDataCollectionCoreSvc','NwFileStorageSvc','NwManagementSvc','NwNetworkDeviceSvc','NwNLASvc','NwOracleSvc','NwSqlaHost','NwSyslogCollectionSvc','NwUBACoreSvc','NwUserActivitySvc','NwWatchdogSvc','NwWebAPISvc','NwWsaHostSvc' }
        'Perch Log Shipper'                 { [array]$ServiceList += 'auditbeat','winlogbeat','sysmon','perch-auditbeat','perch-winlogbeat' }
        'PostgreSQL'                        { [array]$ServiceList += 'postgresql','postgresql-x64-*' }
        'Print'                             { [array]$ServiceList += 'Spooler' }
        'ProjectWise'                       { [array]$ServiceList += 'PWFTSrv','PWConSrv','ProjectWise IMF Printer Driver Service','PWAppSrv','Bentley Orchestration Shepherd','PWAutSrv','BentleyLogging','BentleyGeoWebPublisherLoggingService','BentleyGeoWebPublisherImaging','BentleyGeoWebPublisherAutomationService','BentleyGeoWebPublisherServer','DgnIndexingService' }
        'Quickbooks'                        { [array]$ServiceList += 'QuickbooksDB*', 'QBCFMonitorService' }
        'Roar'                              { [array]$ServiceList += 'roaragent' }
        'SCVMM'                             { [array]$ServiceList += 'SCVMMService','SCVMMAgent' }
        'Sentinel Licensing Server'         { [array]$ServiceList += 'hasplms','Sentinel RMS License Manager','SentinelKeysServer','SentinelProtectionServer','SentinelSecurityRuntime' }
        'SentinelOne'                       { [array]$ServiceList += 'SentinelAgent','SentinelHelperService','LogProcessorService','SentinelStaticEngine' }
        'SharePoint'                        { [array]$ServiceList += 'SPAdmin*','SPTimer*','SPTrace*','SPWriter*' }
        'Trimble'                           { [array]$ServiceList += 'Trimble Mapping And GIS License Service' }
        'Umbrella'                          { [array]$ServiceList += 'Umbrella_RC' }
        'Veeam Agent'                       { [array]$ServiceList += 'VeeamEndpointBackupSvc' }
        'Veeam B&R'                         { [array]$ServiceList += 'VeeamBackupSvc','VeeamBrokerSvc','VeeamCatalogSvc','VeeamCloudSvc','VeeamDeploySvc','VeeamDistributionSvc','VeeamFilesysVssSvc','VeeamManagementAgentSvc','VeeamMBPDeploymentService','VeeamMountSvc','VeeamNFSSvc','VeeamTransportSvc','VeeamHvIntegrationSvc','RPcSs' }
        'Webroot'                           { [array]$ServiceList += 'WRSVC' }
        'Windows Server'                    { [array]$ServiceList += 'EventLog','Schedule','ProfSvc','LSM' }
        'Windows Workstation'               { [array]$ServiceList += 'DHCP','spooler','EventLog','Schedule','ProfSvc','LSM','NetLogon','LanmanWorkstation','Dnscache','SamSs','PlugPlay','CryptSvc','Server','Workstation' }
    }

    ## Get total uptime. Reason being, if the machine hasn't been on long it's going to be expected for services
    ## to not be started. Services like SQL can take 5min+ to start easily.
    $os = Get-WmiObject win32_operatingsystem
    $days = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).TotalDays * 24 * 60
    $hours = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).Hours * 60
    $minutes = ((get-date) - ($os.ConvertToDateTime($os.lastbootuptime))).Minutes
    $upTime = $days + $hours + $minutes
    $script:upTime = [math]::Round($upTime)
    If ($upTime -gt 15) {
        ForEach ($service in $ServiceList) {
            Try {
                ## Commented out, just another way to check for service status if we want to change to only watching enabled services
                #$serviceStatus = (Get-WmiObject win32_service -Filter "Name = '$service' AND startmode <> 'Disabled' AND state <> 'Running'").State
                ## With the error action set to Stop here, that means it will go to the Catch if the service doesn't exist
                $serviceStart = (Get-Service -Name $service -ErrorAction Stop).StartType
                ## If the service is set to Disabled then add that to the log output and set the script final status to Warning
                If ($serviceStart -eq 'Disabled') {
                    If ($script:Status -ne 'Failed') {
                        $script:Status = 'Success'
                    }
                    $script:logOutput += "$service is set to $serviceStart, unable to start service`r`n"
                    ## Setting $disabled to $true means that the next parts of the script will not try to start this service. We're doing this
                    ## because it's disabled so we know the service start will fail.
                    $script:disabled = $True
                }
                ## If the service called is a wildcard then the error action of stop above won't work, so we need to manually check
                ## to see if it exists
                ## This used to be = 'Warning'
                If (!$serviceStart) {
                    If ($script:Status -ne 'Failed') {
                        $script:Status = 'Success'
                    }
                    $script:logOutput += "--$service does not exist!`r`n"
                    $script:disabled = $True
                }
            } Catch {
                ## Set the status to Warning as long as it's not already Warning or Failed
                ## This used to be = 'Warning'
                If ($script:Status -ne 'Failed') {
                    $script:Status = 'Success'
                }
                ## Pretty straight forward here, but update the final log output that this service doesn't exist
                $script:logOutput += "--$service does not exist!`r`n"
                ## Then set $disabled to $true so we don't try to restart a service that doesn't exist
                $script:disabled = $True
            }
            Service-Restart -serviceRestart $service
            ## If the service failed to start, in the function we would have set $checkDependency to $True. This is because the service still isn't started
            ## so maybe it's related to a dependency that isn't started yet
            If ($script:CheckDependency -eq 'Y') {
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
                            ## This used to be = 'Warning'
                            If ($script:Status -ne 'Failed') {
                                $script:Status = 'Success'
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
        $outputDir = "$env:windir\LTSvc\serviceMonitor"
        If (!(Test-Path $outputDir)) {
            New-Item $outputDir -ItemType Directory | Out-Null
        } Else {
            Remove-Item "$outputDir\*"
        }
        Switch ($script:status) {
            'Success' {$outputFile = "$outputDir\Success.txt"}
            'Warning' {$outputFile = "$outputDir\Warning.txt"}
            'Failed' {$outputFile = "$outputDir\Failed.txt"}
        }

        ## If this is set to run as a monitor just output the status only
        If ($RunAsMonitor -eq 'Y') {
            "$Status"
        } Else {
            ## If the output was set to file then send it to the file, otherwise just output to console
            If ($FileOutput -eq 'Y') {
            Set-Content -Value "Status=$status|logOutput=$logOutput|uptime=$uptime|successfulRestarts=$successfulRestarts|failedRestarts=$failedRestarts" -Path $outputFile
            } Else {
                "logOutput=$logOutput|Status=$status|uptime=$uptime|successfulRestarts=$successfulRestarts|failedRestarts=$failedRestarts"
            }
        }
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
                    If ($script:Status -ne 'Warning' -and $script:Status -ne 'Failed') {
                        $script:Status = 'Success'
                    }
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

$script:status = $null
$script:logOutput = $null
$script:uptime = $null
$script:successfulRestarts = $null
$script:failedRestarts = $null
$script:serviceList = $null
