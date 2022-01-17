Function Get-InstalledApplication {
    <#
    .SYNOPSIS
    Get-InstalledApplication

    .DESCRIPTION
    Finds the current install status of an application. If the application is NOT installed, 
    the return will be $false, if an application IS installed, the return will be $true

    .PARAMETER ApplicationName
    In quotes define the app name in question exactly as it's seen in Add Remove Programs in Control Panel

    .EXAMPLE
    C:\PS> Get-InstalledApp ApplicationName 'Microsoft SQL Server 2016'
    #>


    [CmdletBinding()]

    param(
        [Parameter(Mandatory = $True)]
        [string]$ApplicationName
    )


    # Applications may be in either of these locations depending on if x86 or x64
    [array]$installedApps = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    [array]$installedApps += Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    if ((Get-PSDrive -PSProvider Registry).Name -notcontains 'HKU') {
        New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS | Out-Null
    }
    # Applications can also install to single user profiles, so we're checking user profiles too
    [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
    [array]$installedApps += Get-ItemProperty "HKU:\*\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -like "*$ApplicationName*" }


    # Poweshell returns $null arrays that have multiple $null entires as truthy. To combat this, we're 
    # converting the array to a string to check for the number of characters in the output string. If 
    # it was an array of $null, the characters returned here will be 0 so we can be sure application 
    # is NOT installed.
    if (($installedApps | Out-String).Length -ne 0) {
        return $true
    } else {
        return $false
    }
}