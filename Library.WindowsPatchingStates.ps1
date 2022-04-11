Function Set-WindowsUpdateServiceStates {
    <#
    .DESCRIPTION
        Display Name: Windows Update
        Service Name: wuauserv
        Description: This is the primary Windows update service required for all patching functions

        Display Name: Update Orchestrator Service
        Service Name: UsoSvc
        Description: New to Windows 10+, this is responsible for orchestrating all update processes including
        downloading and installing Windows updates. This service is required for built in Windows updates in 
        Windows 10+ to function properly, however we have tested services such as Connectwise Automate patch
        management and "pswindowsupdate" patch management to still be fully functional with this service disabled.
        
        Display Name: Windows Update Medic Service
        Service Name: WaaSMedicSvc
        Description: This is a service intended to keep desired state of Windows settings, and performs troubleshooting
        steps in the background for issues such as update download failures. This is a newer service introduced in Windows
        10+. Documentation on the specifics of this service are non existent.
        Source: https://thegeekpage.com/windows-update-medic-service-waasmedicsvc/
        
        Display Name: Microsoft Update Health Service
        Service Name: uhssvc
        Description: This is an update from Microsoft designed to imnprove the overall quality and effectiveness of
        Windows Updates introduced in Windows 10 with patch KB4023057.
        Source: https://support.microsoft.com/en-us/topic/kb4023057-update-for-windows-update-service-components-fccad0ca-dc10-2e46-9ed1-7e392450fb3a


    .NOTES
        Known Issues
        - 'Microsoft Update Health Service' currently fails to be set to 'Disabled' due to permission issues.


    #>


    Param(
        [ValidateSet('Default','Desired')]
        [string]$SetState
    )

    If ($SetState -eq 'Default') {
        $state = 'defaultState'
    } Else {
        $state = 'desiredState'
    }


    $services = @{
        defaultState = @{
            wuauserv = @{
                DisplayName =   'Windows Update'
                Status      =   'Running'
                StartType   =   'Automatic'
            }
            UsoSvc = @{
                DisplayName =   'Update Orchestrator Service'
                Status      =   'Stopped'
                StartType   =   'Automatic'
            }
            WaaSMedicSvc = @{
                DisplayName =   'Windows Update Medic Service'
                Status      =   'Stopped'
                StartType   =   'Automatic'
            }
            uhssvc = @{
                DisplayName =   'Microsoft Update Health Service'
                Status      =   'Stopped'
                StartType   =   'Automatic'
            }
        }

        
        desiredState = @{
            wuauserv = @{
                DisplayName =   'Windows Update'
                Status      =   'Running'
                StartType   =   'Automatic'
            }
            UsoSvc = @{
                DisplayName =   'Update Orchestrator Service'
                Status      =   'Stopped'
                StartType   =   'Disabled'
            }
            WaaSMedicSvc = @{
                DisplayName =   'Windows Update Medic Service'
                Status      =   'Stopped'
                StartType   =   'Disabled'
            }
            uhssvc = @{
                DisplayName =   'Microsoft Update Health Service'
                Status      =   'Stopped'
                StartType   =   'Disabled'
            }
        }
    }


    $services.$state.Keys | ForEach-Object {
        Try {
            $curService = Get-Service -Name $_
            # Get service is incapable of giving us a distinct value difference between 'Automatic' and
            # 'Automatic (Delayed)'. For this reason, we're using sc.exe to get that status, then using
            # `Switch` to convert the output to expected values for `Set-Service`
            $curStartType = (Get-Service -Name $_).StartType


            # If the current `StartType` is not the same as our defined desired state hashtable value, align it
            If ($curStartType -ne $services.$state.$_.StartType) {
                Set-Service -Name $_ -StartupType $($services.$state.$_.StartType) -ErrorAction Stop
            }


            # If the current `Status` is not the same as our defined desired state hashtable value, align it
            If ($curService.Status -ne $services.$state.$_.Status) {
                If ($curService.Status -ne 'Running' -and $services.$state.$_.Status -eq 'Running') {
                    Start-Service -Name $_ -ErrorAction Stop
                } ElseIf ($curService.Status -ne 'Stopped' -and $services.$state.$_.Status -eq 'Stopped') {
                    Stop-Service -Name $_ -Force -ErrorAction Stop
                } Else {
                    # TODO look for `Stopping` or `Starting` statuses and handle accordingly
                    "The [$_] service is in the $($curService.Status) status and unable to be changed at this time"
                }
            }
        } Catch {
            "Failed to verify alignment: [$_]."
        }
    }
}


Function Set-PatchingTaskStates {
    [CmdletBinding()]

    Param(
        [ValidateSet('Default','Desired')]
        [string]$SetState
    )

    $tasks = @{
        defaultState = @{
            'Backup Scan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Maintenance Install' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'MusUx_UpdateInterval' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Reboot' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Reboot_Battery' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Report policies'  = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Schedule Maintenance Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Scan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Schedule Scan Static Task' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Schedule Wake To Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'Start Oobe Expedite Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabed'
            }
            'StartOobeAppsScan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'UpdateModelTask' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'USO_UxBroker' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
            'UUS Failover Task' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Ready'
            }
        }


        desiredState = @{
            'Backup Scan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Maintenance Install' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'MusUx_UpdateInterval' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Reboot' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Reboot_Battery' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Report policies'  = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Maintenance Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Scan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Scan Static Task' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Wake To Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Schedule Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'Start Oobe Expedite Work' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'StartOobeAppsScan' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'UpdateModelTask' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'USO_UxBroker' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
            'UUS Failover Task' = @{
                TaskPath    =   '\Microsoft\Windows\UpdateOrchestrator\'
                State       =   'Disabled'
            }
        }
    }


    # Give SYSTEM permission to modify all tasks
    $taskDir = "$env:windir\system32\tasks"
    $acl = Get-Acl -Path $taskDir
    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    $objType = [System.Security.AccessControl.AccessControlType]::Allow 
    $permission = "SYSTEM","FullControl",$InheritanceFlag, $PropagationFlag, $objType
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetAccessRule($accessRule)
    Set-Acl $taskDir $acl


    # Set task states
    If ($SetState -eq 'Default') {
        $tasks.defaultState.Keys | ForEach-Object {
            If ($tasks.defaultState.$_.State -eq 'Ready') {
                Enable-ScheduledTask -TaskName $_ -TaskPath $tasks.defaultState.$_.TaskPath
            } ElseIf ($tasks.defaultState.$_.State -eq 'Disabled') {
                Disable-ScheduledTask -TaskName $_ -TaskPath $tasks.defaultState.$_.TaskPath
            }
        }
    } Else {
        $tasks.desiredState.Keys | ForEach-Object {
            If ($tasks.desiredState.$_.State -eq 'Ready') {
                Enable-ScheduledTask -TaskName $_ -TaskPath $tasks.desiredState.$_.TaskPath
            } ElseIf ($tasks.desiredState.$_.State -eq 'Disabled') {
                Disable-ScheduledTask -TaskName $_ -TaskPath $tasks.desiredState.$_.TaskPath
            }
        }        
    }
}


Function Test-WindowsUpdateConnectivity {
    <#
    Will throw if any connections fail
    #>
    'dl.delivery.mp.microsoft.com','download.windowsupdate.com','download.microsoft.com','go.microsoft.com' | ForEach-Object {
        Test-Connection $_ -ErrorAction Stop
    }
}


Function Set-WindowsAutoUpdateLocalPolicies {
    <#
    .DESCRIPTION
        If set to Desired, sets Windows Update settings to allow third party management of Windows
        Update by disabling most built in features of Windows Updates.

        Note setting Desired as the state also removes WSUS configurations from the endpoint.
    
    .Notes
        See below for registry values and their meanings in relation to Windows Updates

        Source: https://docs.microsoft.com/de-de/security-updates/WindowsUpdateServices/18127499

        Name
            AUOptions
        Possible Values
            2|3|4|5
        Value Definitions
            2: Notify before download.
            3: Automatically download and notify of installation.
            4: Automatic download and scheduled installation. (Only valid if values exist for ScheduledInstallDay and ScheduledInstallTime.)
            5: Automatic Updates is required, but end users can configure it.
        Value Type
            Reg_DWORD


        Name
            AutoInstallMinorUpdates
        Possible Values
            0|1
        Value Definitions
            0: Treat minor updates like other updates.
            1: Silently install minor updates.
        Value Type
            Reg_DWORD


        Name
            DetectionFrequency
        Possible Values
            n; where n=time in hours (1-22)
        Value Definitions
            Time between detection cycles.
        Value Type
            Reg_DWORD


        Name
            DetectionFrequencyEnabled
        Possible Values
            0|1
        Value Defintions
            1: Enable DetectionFrequency
            0: Disable custom DetectionFrequency (use default value of 22 hours).
        Value Type
            Reg_DWORD


        Name
            NoAutoRebootWithLoggedOnUsers
        Possible Values
            0|1
        Value Definitions
            1: Logged-on user gets to choose whether or not to restart his or her computer.
            0: Automatic Updates notifies user that the computer will restart in 5 minutes.
        Value Type
            Reg_DWORD
        

        Name
            NoAutoUpdate
        Possible Values
            0|1
        Value Definitions
            0: Enable Automatic Updates.
            1: Disable Automatic Updates.
        Value Type
            Reg_DWORD


        Name
            RebootRelaunchTimeout
        Possible Values
            n; where n=time in minutes (1-1440).
        Value Definitions
            Time between prompting again for a scheduled restart.
        Value Type
            Reg_DWORD

        
        Name
            RebootRelaunchTimeoutEnabled
        Possible Values\
            0|1
        Value Definitions
            1: Enable RebootRelaunchTimeout.
            0: Disable custom RebootRelaunchTimeout(use default value of 10 minutes).
        Value Type
            Reg_DWORD

        
        Name
            RebootWarningTimeout
        Possible Values
            n; where n=time in minutes (1-30).
        Value Definitions
            Length, in minutes, of the restart warning countdown after installing updates with a deadline or scheduled updates.
        Value Type
            Reg_DWORD
        

        Name
            RebootWarningTimeoutEnabled
        Possible Values
            0|1
        Value Definitions
            1: Enable RebootWarningTimeout.
            0: Disable custom RebootWarningTimeout (use default value of 5 minutes).
        Value Type
            Reg_DWORD
        

        Name
            RescheduleWaitTime
        Possible Values
            n; where n=time in minutes (1-60).
        Value Definitions
            Time, in minutes, that Automatic Updates should wait at startup before applying updates from a missed scheduled installation time.
            Note that this policy applies only to scheduled installations, not deadlines. Updates whose deadlines have expired should always 
            be installed as soon as possible.
        Value Type
            Reg_DWORD


        Name
            RescheduleWaitTimeEnabled
        Possible Values
            0|1
        Value Definitions
            1: Enable RescheduleWaitTime
            0: Disable RescheduleWaitTime(attempt the missed installation during the next scheduled installation time).
        Value Type
            Reg_DWORD


        Name
            ScheduledInstallDay
        Possible Values
            0|1|2|3|4|5|6|7
        Value Definitions
            0: Every day.
            1: through 7 = The days of the week from Sunday (1) to Saturday (7). (Only valid if AUOptions equals 4.)
        Value Type
            Reg_DWORD


        Name
            ScheduledInstallTime
        Possible Values
            n; where n = the time of day in 24-hour format (0-23).
        Value Type
            Reg_DWORD

        
        Name
            UseWUServer
        Possible Values
            0|1
        Value Definitions
            The WUServer value is not respected unless this key is set.
    
    #>

    [CmdletBinding()]

    Param(
        [ValidateSet('Default','Desired')]
        [string]$SetState
    )

    If ($SetState -eq 'Desired') {
        $disableAU = @{
            # These are all REG_DWORD values
            AUOptions                       =   2   # Notify before download
            AutoInstallMinorUpdates         =   0   # Treat minor updates like other updates
            NoAutoRebootWithLoggedOnUsers   =   1   # Logged-on user gets to choose whether or not to restart his or her computer
            NoAutoUpdate                    =   1   # Disable Automatic Updates
            RebootRelaunchTimeout           =   440 # Time in minutes
            RebootRelaunchTimeoutEnabled    =   1   # Enable RebootRelaunchTimeout
            RebootWarningTimeout            =   30  # Length, in minutes, of the restart warning countdown after installing updates with a deadline or scheduled updates.
            RebootWarningTimeoutEnabled     =   1   # Enable RebootWarningTimeout
            UseWUServer                     =   0   # Disabled
        }


        $winUpdateRegDir    = 'HKLM:\Software\Policies\Microsoft\Windows\WindowsUpdate'
        $auRegDir           = "$winUpdateRegDir\AU"


        If (!(Test-Path -Path $auRegDir)) {
            # TODO: repalce this create with the reg helper function to create new keys from full path fed
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -EA 0 | Out-Null
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' -EA 0 | Out-Null
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -EA 0 | Out-Null
            New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -EA 0 | Out-Null
        }

        # Set settings in the AU reg key
        $disableAU.Keys | ForEach-Object {
            Set-ItemProperty -Path $auRegDir -Name $_ -Value $disableAU.$_
        }
    } Else {
        # Key only exists for the purpose of controlling updates, so deleting it restores Windows update to default values
        Remove-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Force
    }
}
