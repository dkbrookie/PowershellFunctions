Function Remove-ChromiumExtension {
    <#
    Chrome
        ExtensionName: Google Chrome - Adblock Plus
        GPOInstallNumber: 1
        ExtensionID: cfhdojbkjhnklbpkdaibdccddilifddb
        Comptaible: Yes

        ExtensionName: Google Chrome - LastPass
        GPOInstallNumber: 2
        ExtensionID: hdokiejnpimakedhajhdlcegeplioahd
        Comptaible: Yes

        ExtensionName: Google Chrome - Qure4u CareManager
        GPOInstallNumber: 3
        ExtensionID: mdofmedkjabchieldhdbknompappgppd
        Comptaible: Yes
    
    Edge
        ExtensionName: Google Chrome - Adblock Plus
        GPOInstallNumber: 1
        ExtensionID: gmgoamodcdcjnbaobigkjelfplakmdhh
        Comptaible: Yes

        ExtensionName: Google Chrome - LastPass
        GPOInstallNumber: 2
        ExtensionID: bbcinlkgjjkejfdpemiealijmmooekmp
        Comptaible: Yes

        ExtensionName: Google Chrome - Qure4u CareManager
        GPOInstallNumber: 3
        ExtensionID: mdofmedkjabchieldhdbknompappgppd
        Comptaible: No
    #>

    [CmdletBinding(DefaultParametersetName='none')]

    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Choose the browser to install an extension to."
        )]
        [ValidateSet(
            'Google Chrome','Microsoft Edge'
        )]
            [string]$Browser,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the extension you want to install exactly as seen you want it to be seen in Add/Remove Programs."
        )]  [string]$ExtensionName,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the GPO install number. Use key in above documentation to identify currently enforced extensions."
        )]  [string]$GPOInstallNumber
    )


    # Set vars
    $output = @()
    $baseAddRemoveDir = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    $addRemoveDir = $baseAddRemoveDir + '\' + $ExtensionName
    Switch ($Browser) {
        'Google Chrome' {
                $baseDir = 'HKLM:\SOFTWARE\Policies\Google'
                $gpoDir = $baseDir + '\Chrome\ExtensionInstallForcelist'
            }
        'Microsoft Edge' { 
            $baseDir = 'HKLM:\SOFTWARE\Policies\Microsoft'
            $gpoDir = $baseDir + '\Edge\ExtensionInstallForcelist'
        }
    }


    # Remove GPO policy
    Try {
        If ((Test-Path $gpoDir)) {
            Remove-ItemProperty -Path $gpoDir -Name $GPOInstallNumber -EA 0 | Out-Null
            $output += "Successfully removed [$extensionName]"
        } Else {
            $output += "Verified [$extensionName] is already removed"
        }
    } Catch {
        $output += "There was an issue removing [$extensionName]"
    }


    # Remove Add/Remove entry
    Remove-Item $addRemoveDir -Force -EA 0


    $output = $output -join "`n"
    Write-Output $output
}