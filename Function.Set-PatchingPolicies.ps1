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


        Future improvenets:
        - Ensure access to .do.dsp.mp.microsoft.com
        - Ensure access to *.download.windowsupdate.com
        - Ensure access to *.dl.delivery.mp.microsoft.com
        - Ensure access to *.delivery.mp.microsoft.com
    #>


    Param(
        [ValidateSet('Default','Desired')]
        [array]$SetState
    )


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


    $services.Keys | ForEach-Object {
        Try {
            $curService = Get-Service -Name $_
            # Get service is incapable of giving us a distinct value difference between 'Automatic' and
            # 'Automatic (Delayed)'. For this reason, we're using sc.exe to get that status, then using
            # `Switch` to convert the output to expected values for `Set-Service`
            $curStartType = ((sc.exe qc $_ | Select-String "START_TYPE") -replace '\s+', ' ').trim().Split(" ") | Select-Object -Last 1


            Switch ($curStartType) {
                'AUTO_START'    { $curStartType = 'Automatic'   }
                'DEMAND_START'  { $curStartType = 'Manual'      }
                '(DELAYED)'     { $curStartType = 'Boot'        }
                'DISABLED'      { $curStartType = 'Disabled'    }
                Default         { $curStartType = 'HELP'        }
            }


            "Current [$_] StartType: [$curStartType]"
            "Desired [$_] StartType: [$($services.$_.StartType)]"
            # If the current `StartType` is not the same as our defined desired state hashtable value, align it
            If ($curStartType -ne $services.$_.StartType) {
                Set-Service -Name $_ -StartupType $($services.$_.StartType) -ErrorAction Stop
                "Successfully set [$_] to start type of [$($services.$_.StartType)]"
                "- Alignment of the [$_] service StartType has been successfully enforced!"
            } Else {
                "- Alignment of the [$_] service StartType confirmed!"
            }


            # If the current `Status` is not the same as our defined desired state hashtable value, align it
            If ($curService.Status -ne $services.$_.StatStatuse) {
                "[$_] current Status: [$($curService.Status)]"
                "[$_] desired Status: [$($services.$_.Status)]"
                If ($curService.Status -ne 'Running' -and $services.$_.Status -eq 'Running') {
                    Start-Service -Name $_ -ErrorAction Stop
                    "Successfully set [$_] to the Status of [$($services.$_.Status)]"
                    "- Enforced alignment on the [$_] service [$($services.$_.Status)] Status"
                } ElseIf ($curService.Status -ne 'Stopped' -and $services.$_.Status -eq 'Stopped') {
                    Stop-Service -Name $_ -Force -ErrorAction Stop
                    "Successfully set [$_] to the Status of [$($services.$_.Status)]"
                    "- Enforced alignment on the [$_] service [$($services.$_.Status)] Status"
                } Else {
                    "- Enforced alignment on the [$_] service to [$($services.$_.Status)] Status"
                }
            }
        } Catch {
            "Failed to verify alignment: [$_]."
        }
    }
}


Function Set-PatchingTasks {
    [CmdletBinding()]

    Param(
        [ValidateSet('Default','Desired')]
        [array]$SetState
    )

    $tasks = @{
        defaultState = @{
            'Backup Scan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Maintenance Install' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'MusUx_UpdateInterval' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Reboot' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Reboot_Battery' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Report policies'  = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Schedule Maintenance Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Scan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Schedule Scan Static Task' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Schedule Wake To Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'Start Oobe Expedite Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabed'
            }
            'StartOobeAppsScan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'UpdateModelTask' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'USO_UxBroker' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
            'UUS Failover Task' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Ready'
            }
        }

        desiredState = @{
            'Backup Scan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Maintenance Install' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'MusUx_UpdateInterval' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Reboot' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Reboot_Battery' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Report policies'  = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Maintenance Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Scan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Scan Static Task' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Wake To Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Schedule Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'Start Oobe Expedite Work' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'StartOobeAppsScan' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'UpdateModelTask' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'USO_UxBroker' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
            'UUS Failover Task' = @{
                TaskPath = '\Microsoft\Windows\UpdateOrchestrator\'
                State = 'Disabled'
            }
        }
    }


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
