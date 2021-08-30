Function Install-ChromiumExtension {
    <#
    Chrome
        1: Google Chrome - Adblock Plus - cfhdojbkjhnklbpkdaibdccddilifddb
        2: Google Chrome - LastPass - hdokiejnpimakedhajhdlcegeplioahd
        3: Google Chrome - Qure4u CareManager - mdofmedkjabchieldhdbknompappgppd
    
    Edge
        1: Microsoft Edge - Adblock Plus - gmgoamodcdcjnbaobigkjelfplakmdhh
        2: Microsoft Edge - LastPass - bbcinlkgjjkejfdpemiealijmmooekmp
        3: INCOMPATIBLE - Microsoft Edge - Qure4u CareManager - mdofmedkjabchieldhdbknompappgppd
    #>

    [CmdletBinding(DefaultParametersetName='none')]

    Param(
        [Parameter(
            Mandatory = $true,
            HelpMessage = "Please enter the name of the extension you want to install exactly as seen you want it to be seen in Add/Remove Programs."
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
            HelpMessage = "Please enter the extension ID if the extension you want to install. You can find this in developer mode in the browser once the extension is installed."
        )]  [string]$ExtensionID,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "This can be any number, but must be unique to all other extensions currently enforced via GPO. There is a running list with ID references at the top of this function."
        )]  [string]$GPOInstallNumber,
        [Parameter(
            Mandatory = $true,
            HelpMessage = "This appears in Add/Remove progams under the version number."
        )]  [string]$InstallVersion,
        [Parameter(
            Mandatory = $false,
            HelpMessage = "Type the name of the add/remove item to remove EXACTLY as seen in add/remove programs. Removes previous entry for custom enforced extensions installed before installing the new plugin. Note this is only removing the add/remove program entry, not actually removing the plugin enforcement on the browser (unnecessary)."
        )]  [string]$RemovePrevious
    )


    # Set vars
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
    

    # Create reg key for GPOs if they don't exist
    If (!(Test-Path $gpoDir -EA 0)) {
        New-Item -Path $gpoDir -EA 0 | Out-Null
    } Else {
        $output += 'Verified GPO reg keys exist'
    }


    # Create the GPO enforcement reg value for the apropriate browser
    If ((Get-ItemProperty $gpoDir -Name $GPOInstallNumber -EA 0).$GPOInstallNumber -ne $ExtensionID) {
        Set-ItemProperty -Path $gpoDir -Name $GPOInstallNumber -Value $ExtensionID | Out-Null
        $output += "Successfully set [$ExtensionName] GPO reg auto deploy"
    } Else {
        $output += "Confirmed the [$ExtensionName] reg entry is present"
    }


    # Remove previous versions of the custom enforced extensions
    If ($RemovePrevious) {
        $RemovePrevious = $baseAddRemoveDir + '\' + $RemovePrevious
        If ((Test-Path -Path $RemovePrevious)) {
            Remove-Item -Path $RemovePrevious -Force -EA 0 | Out-Null
        }
    }

    # Create an entry in the Uninstall key in registry so this appears in Add/Remove Programs. This
    # lets us track which machines have this installed and which ones don't via AUtomate
    $addRemoveDir = "HKLM:\SOftware\Microsoft\Windows\CurrentVersion\Uninstall\$ExtensionName"
    If (!(Test-Path $addRemoveDir-EA)) {
        New-Item $addRemoveDir -EA 0 | Out-Null
        New-ItemProperty -Path $addRemoveDir -PropertyType String -Name 'DisplayIcon' -Value 'C:\Windows\LTSvc\labtech.ico' -EA 0 | Out-Null
        New-ItemProperty -Path $addRemoveDir -PropertyType String -Name 'DisplayName' -Value $ExtensionName -EA 0 | Out-Null
        New-ItemProperty -Path $addRemoveDir -PropertyType String -Name 'DisplayVersion' -Value $InstallVersion -EA 0 | Out-Null
        New-ItemProperty -Path $addRemoveDir -PropertyType String -Name 'Publisher' -Value 'DKBInnovative' -EA 0 | Out-Null
        New-ItemProperty -Path $addRemoveDir -PropertyType String -Name 'UninstallString' -Value 'C:\dontuninstallme' -EA 0 | Out-Null
        $output += "Successfully added [$ExtensionName] item in Add/Remove Programs"
    }


    $output = $output -join "`n"
    Write-Output $output
}