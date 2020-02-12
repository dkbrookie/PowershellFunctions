Function Unlock-ADUser {
    <#
    .SYNOPSIS
    UnlockADUser

    .DESCRIPTION
    Unlock-ADUser is a qucik function used to unlock an AD user. The function will check if the user is currently locked, and if yes,
    will unlock the account. If the user is NOT locked out, it will just output that it was not locked and no action is required.

    .PARAMETER User
    Define the AD username you want to unlock

    .EXAMPLE
    C:\PS> Unlock-ADUser -User 'usernamehere'
    #>

    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $True)]
        [string]$User,
    )

    If (!$user) {
        Write-Warning 'No user was specified to unlock! Please use the -User pararmeter to define the user you want unlocked.'
    }

    Try {
        If (!(Get-ADUser -Identity $user -Properties * | Select-Object LockedOut).LockedOut) {
            Write-Output "Confirmed $user account is unlocked!"
        } Else {
            Write-Output "Unlocking user $user..."
            Unlock-ADAccount -Identity $user
            If (!(Get-ADUser -Identity $user -Properties * | Select-Object LockedOut).LockedOut) {
                Write-Output "Confirmed $user was successfully unlocked!"
            }
        }
    } Catch {
        Write-Warning "!ERROR: There was a problem when trying to unlock the $user account. A ticket has been generated to DKBInnovative Service Team"
    }
}