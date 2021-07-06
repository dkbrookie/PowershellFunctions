Function User-LockStatus {
    <#
    .SYNOPSIS
    Attempt auto start of services that are stopped.

    .DESCRIPTION
    Checks the lock status of a machine by gathering lockout status of all user accounts currently logged into
    the target machine. If any account is unlocked, the output will be 'Unlocked'. If ALL accounts are locked out,
    the output will be 'Locked'.

    .PARAMETER ComputerName
    Set the name of the computer you want to check the current lockout status on. If empty, defaults to 'localhost'

    .EXAMPLE
    User-LockStatus -ComputerName 'DC-0142'
    User-LockStatus
    
    .NOTES
    
    #>

    [CmdletBinding()]

    Param(
        [string]$ComputerName = 'localhost'
    )

    $ErrorActionPreference = 'SilentlyContinue'

    $users = (Get-WmiObject -Class win32_computersystem -ComputerName $ComputerName).username.Split("\")[1]
    If ((Get-Process logonui -ComputerName $ComputerName) -and ($users)) {
        $Locked = $True
    }
    ForEach ($user in $users) {
        $Output = New-Object PSObject
        $Output | Add-Member noteproperty Computer $ComputerName
        $Output | Add-Member noteproperty Username $User
        $Output | Add-Member noteproperty Locked $Locked
    }

    If ($Output.Locked) {
        Write-Output "Locked"
    } Else {
        Write-Output "Unlocked"
    }
}