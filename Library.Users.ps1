# Set vars
$symbol = ''
$date = Get-Date


# Store Powershell version as a var to compare against later
$psVers = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"


# DONE
Function Get-LocalUserStatus ($User) {
    <#

    .DESCRIPTION
        This function is designed to return all information from Get-LocalUser even if the machine is not on
        Powershell 5+. This is done by using CMD and WMI on legacy version of Powershell to gather data on
        the user and storing it in a hashtable where the output properties match the Get-LocalUser output.

        If this returns $falsy, it means the local user does not exist

    .PARAMETER User
        The user you want to return information about

    #>
    $newUser = @{
        AccountExpires = $null
        Description = $null
        Enabled = $null
        FullName = $null
        PasswordChangeableDate = $null
        PasswordExpires = $null
        UserMayChangePassword = $null
        PasswordRequired = $null
        PasswordLastSet = $null
        LastLogon = $null
        Name = $null
        SID = $null
        PrincipalSource = $null
        ObjectClass = $null
        LocalAdmin = $null
    }

    $computerName = "."
    $wmiEnumOpts = New-Object System.Management.EnumerationOptions
    $wmiEnumOpts.BlockSize = 20

    $argList = @{
        "Class"        = "Win32_Group"
        "ComputerName" = $computerName
        "Filter"       = "LocalAccount=TRUE AND SID='S-1-5-32-544'"
    }

    $wmiUser = Get-WmiObject @argList | Foreach-Object {
        $_.GetRelated("Win32_Account", "Win32_GroupUser", "", "", "PartComponent", "GroupComponent", $FALSE, $wmiEnumOpts)
    } | Where-Object { $_.Name -eq 'Administrator' }

    If ($wmiUser) {
        # User exists
        $newUser.AccountExpires = (net user $User | Select-String -Pattern 'Account expires(\s*(.*))') -replace 'Account expires(\s*)',''
        $newUser.Description = $wmiUser.Description
        If ($user.Disabled) {
            $newUser.Enabled = $false
        } Else {
            $newUser.Enabled = $true
        }
        $newUser.FullName = $wmiUser.FullName
        $newUser.PasswordChangeableDate = (net user $User | Select-String -Pattern 'Password changeable(\s*(.*))') -replace 'Password changeable(\s*)',''
        $newUser.PasswordExpires = (net user $User | Select-String -Pattern 'Password expires(\s*(.*))') -replace 'Password expires(\s*)',''
        $newUser.UserMayChangePassword = $wmiUser.PasswordChangeable
        $newUser.PasswordRequired = $wmiUser.PasswordRequired
        $newUser.PasswordLastSet = Get-LastLocalPasswordChangeTime -User $User
        $newUser.LastLogon = (net user $User | Select-String -Pattern 'Last logon(\s*(.*))') -replace 'Last logon(\s*)',''
        $newUser.Name = $wmiUser.Name
        $newUser.SID = $wmiUser.SID
        If ($user.LocalAccount) {
            $newUser.PrincipalSource = 'Local'
        } Else {
            $newUser.PrincipalSource = 'Domain'
        }
        If ($LocalAdmin) {
            $newUser.LocalAdmin = $true
        }

        Return $newUser
    } Else {
        # User does not exist
        Return $false
    }
}




# DONE
Function New-RandomPassword {
    <#
    .DESCRIPTION
        Note this function will only work if the script is started from Automate because the dictionary is in a
        private github repo and the API key has to be called from Automate
    #>
    $word1 = (($WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/Security/master/Credential_Management/Windows_Local_Admin_Control/Dictionary.txt')).split() | Get-Random -ErrorAction Stop
    $random = Get-Random -Maximum 999999999 -Minimum 10000000
    $string = @'
@#$%~`^&(*)_+';?\][}:.,<#>`./;~`-="
'@
    For ($i = 0; $i -lt 2; $i++ ) {
        $symbol += $string[(Get-Random -Minimum 0 -Maximum $string.Length)]
    }
    Return $word1 + $random + $symbol
}




# DONE
Function New-LocalAdmin ($User,$Pass) {
    <#
    .DESCRIPTION
        Determinds the version of Powershell and if less than PS 5.1 will use CMD to create a new user.
        CMD commands are written to validate after user creation and will throw if the user was not
        successfully created.

        User is created and placed inside the local Administrators group, and the password is set to
        never expire.

        If the user already exists, the script verifies the user is in the local administrators group,
        the password is set to never expire, and the account is enabled.

    .PARAMETER User
        The username as a string that you want to create

    .PARAMETER Pass
        If you want to specify a password you can define this value, otherwise a randomly generated
        password will be created.
    #>
    Try {
        If (!$Pass) {
            # Generate password if $Pass wasn't defined
            $Pass = New-RandomPassword
        }

        If ($psVers -lt 5.1) {
            $userDetails = Get-LocalUserStatus -User $User
            # If the user doesn't exist, create it
            If (!$userDetails) {
                # Create $User admin account using CMD
                &cmd.exe /c "net user /add $User $Pass"
                # Verify/enforce user lines up to desired standards
                Set-ExistingAccountConfig -User $User
            } Else {
                # Set a new user password. This function will throw if it fails to generate or set the password.
                Set-LocalUserPass -User $User -Pass $Pass
                # Verify/enforce user lines up to desired standards
                Set-ExistingAccountConfig -User $User
            }
        } Else {
            # Create $User admin account
            $stringPass = ConvertTo-SecureString -String $Pass -AsPlainText -Force
            If (!(Get-LocalUserStatus -User $User)) {
                # If the user does not exist, create it and ensure it has the correct configuration
                New-LocalUser $User -Password $stringPass -FullName $User -Description "Created by DKBInnovative on $date" -ErrorAction Stop
                Set-ExistingAccountConfig -User $User
                Return "Successfully created the user [$User] and enforced all configurations"
            } Else {
                # If the user does exist, update the password and ensure it has the correct configuration
                Set-LocalUserPass -User $User -Pass $stringPass
                Set-ExistingAccountConfig -User $User
                Return "Verified the user [$User] already exists"
            }
        }
    } Catch {
        Return "Failed to create, or enforce configuration for the user [$User]. Full output: $Error"
    }
}




# PRODTODO WIP
Function Set-LocalUserPass ($User,$Pass) {
    If ($psVers -lt 5.1) {
        &cmd.exe /c "net user $User $password"
        &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$User') set PasswordExpires=False"
        # Verify the password was successfully changed
        $passChangeDate = Get-LastLocalPasswordChangeTime -User $User
        # If it's been more than 5min since the last password change on the user we're going to conut that a failure and
        # have it throw here
        If ((Get-Date - $passChangeDate).Minutes -gt 5) {
            Throw "Failed to set a new password for the user [$User]. -- $Error"
        } Else {
            Return "Successfully set a new password for the user [$User]"
        }
    } Else {
        $stringPass = ConvertTo-SecureString -String $Pass -AsPlainText -Force
        Set-LocalUser -Name $User -Password $stringPass -ErrorAction Stop
        Return "Successfully set a new password for the user [$User]"
    }
}




# DONE
Function Set-ExistingAccountConfig ($User) {
    <#
    .DESCRIPTION
        This function is intended to enforce required settings on an existing user. This function will force the
        input user to have the following settings:
        - Member of local Administrators group
        - PasswordNeverExpires set to $False
        - User Enabled is $true

        This function will throw on failure to enforce any of these settings. This function works for all versions of
        Powershell.
    #>
    If ($psVers -lt 5.1) {
        $userDetails = Get-LocalUserStatus -User $User

        # Add the $User is in the local Administrators group if not a member currently
        If (!$userDetails.LocalAdmin) {
            &cmd.exe /c "net localgroup Administrators $User /add"
        }
        # Set the $User password to never expire
        If ($userDetails.PasswordExpires) {
            &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$User') set PasswordExpires=False"
        }
        # Enable the $User
        If (!$userDetails.Enabled) {
            &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$User') set Disabled=False"
        }

        # CMD doesn't give us any kind of validation or throw if something failed so we're going to validate and throw here if
        # the user does not exist. Note the function called here is one defined in this script, not a default function
        $userDetails = Get-LocalUserStatus -User $User
        If (!$userDetails -or !$userDetails.LocalAdmin -or $userDetails.PasswordExpires -or !$userDetails.Enabled) {
            Throw "Failed to set required parameters for the user [$User]. -- $Error"
        } Else {
            Return "Verified the user [$User] is in the local [Administrators] group, verified [$User] password is set to never expire, and verified [$User] is enabled"
        }
    } Else {
        $userDetails = Get-LocalUserStatus -User $User

        # Add the $User is in the local Administrators group if not a member currently
        If (!$userDetails.LocalAdmin) {
            Add-LocalGroupMember -Group Administrators -Member $User -ErrorAction Stop
        }
        # Set the $User password to never expire
        If ($userDetails.PasswordExpires) {
            Set-LocalUser -Name $User -PasswordNeverExpires $true -ErrorAction Stop
        }
        # Enable the $User
        If (!$userDetails.Enabled) {
            Enable-LocalUser -Name $User -ErrorAction Stop
        }

        Return "Verified the user [$User] is in the local [Administrators] group, verified [$User] password is set to never expire, and verified [$User] is enabled"
    }
}




# DONE
Function Get-LastLocalPasswordChangeTime ($User) {
    <#
    .DESCRIPTION
        The date/time the password was last set is in CMD. This function uses regex to get the date the
        password was last successfully set.

        The intended usage of this function is to verify a password was successfully changed. Occasionally,
        dependingo on the configuration of the endpoint, the password can fail to set if the password complexity
        has very non-standard requirements. If this is the case, we want to make sure we do NOT wipe the previous
        password, and want to preserve that password to ensure we still have access to the machine.
    #>
    # Grab the local time the machine reports the password was last changed locally
    [datetime]$lastChanged = (net user $User | Select-String -Pattern 'Password last set(\s*(.*))') -replace 'Password last set(\s*)',''
    Return $lastChanged
}




# DONE
Function Disable-LocalUserAccount ($User) {
    <#
    .DESCRIPTION
        Very stragiht forward function to disable the input user. This function works with any version
        of Powershell.
    #>
    If ($psVers -lt 5.1) {
        &cmd.exe /c "net user $_ /active:no"
        If ((Get-LocalUserStatus -User $User).Disabled -ne 'True') {
            Throw "Failed to disable the user [$User]"
        } Else {
            Return "Successfully disabled the user [$User]"
        }
    } Else {
        Disable-LocalUser -Name $User -ErrorAction Stop
        Return "Successfully disabled the user [$User]"
    }
}




# DONE
Function Get-LocalAdminGroupMembers {
    <#
    .DESCRIPTION
        This function outputs all users currently in the local administrators group. This does not check to see
        if the account is enabled, but is rather a raw output. To determine if the user is enabled, use the
        Get-LocalUserStatus function.
    #>
    If ($psVers -lt 5.1) {
        $localAdmins = ((Get-WmiObject win32_group -filter 'Name = "Administrators"' -ErrorAction Stop).GetRelated('Win32_UserAccount')).Name
        If (!$localAdmins) {
            Throw "The local [Administrators] group return 0 users. This implies there was a problem with the command execution. $Error"
        }
        Return $localAdmins
    } Else {
        $localAdmins = (Get-LocalGroupMember -Group Administrators -ErrorAction Stop | Where-Object { $_.PrincipalSource -eq 'Local' }).Name -replace("$env:COMPUTERNAME\\",'')
        Return $localAdmins
    }
}




Function Remove-FromLocalAdminGroup ($User) {
    If ($psVers -lt 5.1) {
        &cmd.exe /c "net localgroup Administrators $User /delete"
        If ((Get-LocalUserStatus -User $User).LocalAdmin) {
            Throw "Failed to remove the user [$User] from the local [Administrators] group"
        } Else {
            Return "Successfully removed the user [$User] from the local Administrators group"
        }
    } Else {
        Try {
            Remove-LocalGroupMember -Member $User -Group Administrators -ErrorAction Stop
            Return "Successfully removed the user [$User] from the local Administrators group"
        } Catch {
            Throw "Failed to remove the user [$User] from the local [Administrators] group. $Error"
        }
    }
}
