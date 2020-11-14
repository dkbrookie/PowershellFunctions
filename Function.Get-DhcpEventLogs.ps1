Function Get-DhcpEventLogs {
    <#
    .SYNOPSIS
    Get-DhcpEventLogs-- Reads the Windows DHCP server logs

    .DESCRIPTION 
    The Windows DHCP server logs are stored in CSV format in C:\Windows\System32\dhcp. It's difficult to 
    read these logs in Notepad due to them being in CSV format. This script converts each line of the log
    file into a PSObject and then processes through it with the parameters you specify below. Additionally, 
    the PSObject will contain descriptive versions of the ID and QResult fields

    .PARAMETER Lines
    Define the total number of events you want returned. This is to help control long query times since
    sometimes these log files can be thousands and thousands of lines long. By default this is 500. If
    you're upping your total $LogDays to multiple days you're gonna wanna pretty much max this one out to
    9999 or similar if you really want to see old data.

    .PARAMETER EventIDs
    Specify a list of specific Event IDs to pull. See all available Event IDs below in the $idMeanings
    section to figure out which Event IDs you'd like to pull. By default, this is 14,15,22,31,56,57,58,
    61,62 which are the most common error codes for DHCP.

    .PARAMETER LogDays
    Specify how many days back you want to retrieve logs for. Note that the maximum is 7 days. Default
    is 1 day.

    .PARAMETER GroupEvents
    Group all events by ID number to just get a quick snapshot of all unique events returned instead
    of a verbose long list of events. By default this is No.

    .OUTPUTS
    A PSObject, output from ConvertFrom-CSV

    .EXAMPLE
    Get-DhcpEventLogs -Lines 200 -EventIds 11,12,52 -GroupEvents No -LogDays 5
    Get-DhcpEventLogs -EventIDs 31 -GroupEvents Yes -LogDays 2
    #>

    param(
        [parameter(Position=0,Mandatory=$false)]
        [Alias("count")]
        [int]$Lines = 500,

        [parameter(Mandatory=$false)]
        [ValidateSet(00,01,02,10,11,12,13,14,15,16,17,18,20,21,22,23,24,25,30,31,32,33,34,35,36,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64)]
        [array]$EventIDs = (14,15,22,31,56,57,58,61,62),

        [parameter(Mandatory=$false)]
        [ValidateSet(1,2,3,4,5,6,7)]
        [int]$LogDays = 1,

        [parameter(Mandatory=$false)]
        [ValidateSet('Yes','No')]
        [string]$GroupEvents = 'No'        
    )
    
    ## Logs are stored in flat text files and they store them by day name...it's odd, but is what it is. Because
    ## of this, if we want to pull logs for more than 1 day, we need to get-content of as many log files as we can
    ## and then later compare the parsed dates of the events to the time period specified above in the $LogDays
    ## parameter. By default the log time is just 7 days so we're pulling logs for every day of the week and calling
    ## it good.
    If ($LogDays -le 1) {
        [array]$days = (get-date).DayOfWeek.ToString().Substring(0,3)
    } Else {
        [array]$days = 'Mon','Tue','Wed','Thu','Fri','Sat','Sun'
    }

    ## CSV header fields, to be used later when converting each line of the tailed log from CSV
    $headerFields = @("ID","Date","Time","Description","IP Address","Host Name","MAC Address","User Name","TransactionID","QResult","Probationtime","CorrelationID","Dhcid","VendorClass(Hex)","VendorClass(ASCII)","UserClass(Hex)","UserClass(ASCII)","RelayAgentInformation","DnsRegError")

    ## Translations of the ID field, as per the description inside the log file itself
    $idMeanings = @{ 
        00 = "The log was started.";
        01 = "The log was stopped.";
        02 = "The log was temporarily paused due to low disk space.";
        10 = "A new IP address was leased to a client.";
        11 = "A lease was renewed by a client.";
        12 = "A lease was released by a client.";
        13 = "An IP address was found to be in use on the network.";
        14 = "A lease request could not be satisfied because the scope's address pool was exhausted.";
        15 = "A lease was denied.";
        16 = "A lease was deleted.";
        17 = "A lease was expired and DNS records for an expired leases have not been deleted.";
        18 = "A lease was expired and DNS records were deleted.";
        20 = "A BOOTP address was leased to a client.";
        21 = "A dynamic BOOTP address was leased to a client.";
        22 = "A BOOTP request could not be satisfied because the scope's address pool for BOOTP was exhausted.";
        23 = "A BOOTP IP address was deleted after checking to see it was not in use.";
        24 = "IP address cleanup operation has begun.";
        25 = "IP address cleanup statistics.";
        30 = "DNS update request to the named DNS server.";
        31 = "DNS update failed.";
        32 = "DNS update successful.";
        33 = "Packet dropped due to NAP policy.";
        34 = "DNS update request failed as the DNS update request queue limit exceeded.";
        35 = "DNS update request failed.";
        36 = "Packet dropped because the server is in failover standby role or the hash of the client ID does not match.";
        # Event descriptions for 50-64 sourced from https://technet.microsoft.com/en-us/library/cc776384(v=ws.10).aspx
        50 = "The DHCP server could not locate the applicable domain for its configured Active Directory installation.";
        51 = "The DHCP server was authorized to start on the network.";
        52 = "The DHCP server was recently upgraded to a Windows Server 2003 operating system, and, therefore, the unauthorized DHCP server detection feature (used to determine whether the server has been authorized in Active Directory) was disabled."
        53 = "The DHCP server was authorized to start using previously cached information. Active Directory was not currently visible at the time the server was started on the network.";
        54 = "The DHCP server was not authorized to start on the network. When this event occurs, it is likely followed by the server being stopped.";
        55 = "The DHCP server was successfully authorized to start on the network.";
        56 = "The DHCP server was not authorized to start on the network and was shut down by the operating system. You must first authorize the server in the directory before starting it again.";
        57 = "Another DHCP server exists and is authorized for service in the same domain.";
        58 = "The DHCP server could not locate the specified domain.";
        59 = "A network-related failure prevented the server from determining if it is authorized.";
        60 = "No Windows Server 2003 domain controller (DC) was located. For detecting whether the server is authorized, a DC that is enabled for Active Directory is needed.";
        61 = "Another DHCP server was found on the network that belongs to the Active Directory domain.";
        62 = "Another DHCP server was found on the network.";
        63 = "The DHCP server is trying once more to determine whether it is authorized to start and provide service on the network.";
        64 = "The DHCP server has its service bindings or network connections configured so that it is not enabled to provide service."
    }

    $qResultMeanings = @{0 = "No Quarantine"; 1 = "Quarantine"; 2 = "Drop Packet"; 3 = "Probation"; 6 = "No Quarantine Information"}

    ForEach ($day in $days) {
        $filePath = "$env:SystemRoot\System32\dhcp\DhcpSrvLog-$day.log"
        $errorEvents += Get-Content $filePath –tail $Lines | ConvertFrom-Csv –Header $headerFields | Select-Object *,@{n="ID Description";e={$idMeanings[[int]::parse($_.ID)]}},@{n="QResult Description";e={$qResultMeanings[[int]::parse($_.QResult)]}}
    }
    ## Loop through each event log entry so we can sort through the different IDs. Some events are NOT errors
    ## and even if they are we don't necassarily care about them. We're going to process through each one and
    ## pick out the ones we want to look at.
    ForEach ($errorEvent in $errorEvents) {
        ## Exclude the garbage the PSObject conversion process doesn't clean up
        If (($errorEvent.Date) -and $errorEvent.Id -ne 'QResult: 0: NoQuarantine' -and $errorEvent.ID -ne 'ID') {
            ## Combine the date and time from the log file event to and convert to a PS datetime object
            [datetime]$date = $errorEvent.Date + ' ' + $errorEvent.Time
            ## Only output Event IDs specified in the $EventIDs parameter
            If ($EventIDs -contains $errorEvent.Id -and $date -gt (Get-Date).AddDays(-$LogDays)) {
                ## Add all events that meet all above criteria to the final event output var
                [array]$totalEvents += $errorEvent
            }
        }
    }

    ## Here we check to see if the GroupEvents option was set to yes, then group them with Sort-Object ID -Unique 
    ## if it is Yes
    If ($GroupEvents -eq 'Yes') {
        $totalEvents | Sort-Object Id -Unique | Select-Object ID, Date, Time, Description, 'IP Address', 'Host Name', QResult, DnsRegError, 'ID Description'
    } Else {
        $totalEvents | Select-Object ID, Date, Time, Description, 'IP Address', 'Host Name', QResult, DnsRegError, 'ID Description'
    }

    ## Setting a ticket true/false here so we can later use these results to ticket w/ Automate
    If ($totalEvents) {
        $global:createTicket = 'Yes'
        ## Output total number of events found per event ID. This will help determine if this is a one off issue or
        ## a reoccuring problem that's going to need more investigation
        Write-Output "Name is the EventID, and Count is the Total times the event has occured out of the last total 500 events.`r`n"
        $totalEvents.Id | Group-Object | Select-Object Name, Count
    } Else {
        $global:createTicket = 'No'
        Write-Output 'No events found matching your criteria'
    }
}