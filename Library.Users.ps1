# Store Powershell version as a var to compare against later
$psVers = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"

Function Get-IsLocalAdmin ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $localAdmins = Get-LocalAdminGroupMembers

    If ($UserName -like '*\*') {
        $isLocalAdmin = $localAdmins | Where-Object { $_.Caption -eq $UserName }
    } Else {
        $isLocalAdmin = $localAdmins | Where-Object { $_.Name -eq $UserName }
    }

    If ($isLocalAdmin) { Return $true }

    Return $false
}

Function Get-LocalAdminGroup {
    Return Get-WmiObject -Class Win32_Group -Filter "LocalAccount=TRUE AND SID='S-1-5-32-544'"
}

Function Get-LocalAdminGroupName {
    Return (Get-LocalAdminGroup).Name
}

Function Get-LocalUserExists ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $user = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount=True AND Name='$UserName'"

    If ($user) { Return $true }

    Return $false
}

Function New-LocalUserMaker ($UserName, $Pass) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }
    If (!$Pass) { Throw 'You must provide a password!'; Return; }
    If (Get-LocalUserExists $UserName) { Write-Output "Not creating new user $UserName because a user with that name already exists."; Return; }

    If ($psVers -lt 5.1) {
        &cmd.exe /c "net user /add $UserName $Pass"

        # Verify that the user was actually created
        If (!(Get-LocalUserExists $UserName)) {
            Throw "Could not create user [$UserName] for some reason. If there was an error, it is likely printed right before this error, but no promises."
            Return
        }
    } Else {
        $stringPass = ConvertTo-SecureString -String $Pass -AsPlainText -Force
        New-LocalUser $UserName -Password $stringPass -FullName $UserName -Description "Created by DKBInnovative on $(Get-Date)" -ErrorAction Stop | Out-Null
    }
}

Function Get-LocalUserStatus ($UserName) {
    <#

    .DESCRIPTION
        This function is designed to return all information from Get-LocalUser even if the machine is not on
        Powershell 5+. This is done by using CMD and WMI on legacy version of Powershell to gather data on
        the user and storing it in a hashtable where the output properties match the Get-LocalUser output.

        If this returns $falsy, it means the local user does not exist

    .PARAMETER User
        The user you want to return information about

    #>

    If (!$UserName) { Throw 'You must provide a username!'; Return; }
    If (!(Get-LocalUserExists $UserName)) { Throw "Cannot get current status because [$UserName] does not exist!"; Return; }

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

    $user = Get-WmiObject -Class Win32_UserAccount -Filter "LocalAccount=True AND Name='$UserName'" | Select-Object *
    $newUser.LocalAdmin = Get-IsLocalAdmin $UserName
    $newUser.AccountExpires = (net user $UserName | Select-String -Pattern 'Account expires(\s*(.*))') -replace 'Account expires(\s*)',''
    $newUser.Description = $user.Description

    If ($user.Disabled) {
        $newUser.Enabled = $false
    } Else {
        $newUser.Enabled = $true
    }

    $newUser.FullName = $user.FullName
    $newUser.PasswordChangeableDate = (net user $UserName | Select-String -Pattern 'Password changeable(\s*(.*))') -replace 'Password changeable(\s*)',''
    $newUser.PasswordExpires = (net user $UserName | Select-String -Pattern 'Password expires(\s*(.*))') -replace 'Password expires(\s*)',''
    $newUser.UserMayChangePassword = $user.PasswordChangeable
    $newUser.PasswordRequired = $user.PasswordRequired
    $newUser.PasswordLastSet = Get-LastLocalPasswordChangeTime -User $UserName
    $newUser.LastLogon = (net user $UserName | Select-String -Pattern 'Last logon(\s*(.*))') -replace 'Last logon(\s*)',''
    $newUser.Name = $user.Name
    $newUser.SID = $user.SID

    If ($user.LocalAccount) {
        $newUser.PrincipalSource = 'Local'
    } Else {
        $newUser.PrincipalSource = 'Domain'
    }

    Return $newUser
}

# TODO: Test this! Untested
Function New-RandomPassword {
    <#
    .DESCRIPTION
        Note this function will only work if the script is started from Automate because the dictionary is in a
        private github repo and the API key has to be called from Automate
    #>
    $symbol = ''
    $dict = 'https://raw.githubusercontent.com/dkbrookie/Security/master/Credential_Management/Windows_Local_Admin_Control/Dictionary.txt'
    $word1 = (($WebClient).DownloadString($dict)).split() | Get-Random -ErrorAction Stop
    $random = Get-Random -Maximum 999999999 -Minimum 10000000
    $string = @'
@#$%~`^&(*)_+';?\][}:.,<#>`./;~`-="
'@

    For ($i = 0; $i -lt 2; $i++ ) {
        $symbol += $string[(Get-Random -Minimum 0 -Maximum $string.Length)]
    }

    Return $word1 + $random + $symbol
}

Function New-LocalAdmin ($UserName, $Pass) {
    <#
    .DESCRIPTION
        Determinds the version of Powershell and if less than PS 5.1 will use CMD to create a new user.
        CMD commands are written to validate after user creation and will throw if the user was not
        successfully created.

        User is created and placed inside the local Administrators group, and the password is set to
        never expire.

        If the user already exists, the script reset pass, verifies the user is in the local administrators
        group, the password is set to never expire, and the account is enabled.

    .PARAMETER User
        The username as a string that you want to create

    .PARAMETER Pass
        If you want to specify a password you can define this value, otherwise a randomly generated
        password will be created.
    #>
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    If (!$Pass) {
        Try {
            # Generate password if $Pass wasn't defined
            $Pass = New-RandomPassword
        } Catch {
            Throw "There was an error when generating random password. The error was: $_"
            Return
        }
    }

    If (!(Get-LocalUserExists $UserName)) {
        # If user doesn't exist, create them
        New-LocalUserMaker $UserName $Pass
        Write-Output "Successfully created [$UserName]"
    } Else {
        Write-Output "[$UserName] already exists"
        # If user does exist, reset password
        Set-LocalUserPass -User $UserName -Pass $Pass
    }

    # Verify/enforce user lines up to desired standards
    Set-ExistingAccountConfig -User $UserName
    Write-Output "Successfully enforced all configurations for [$UserName]"
}

Function Set-LocalUserPass ($UserName, $Pass) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }
    If (!$Pass) { Throw 'You must provide a password!'; Return; }
    If (!(Get-LocalUserExists $UserName)) { Throw "User [$UserName] does not exist! Unable to set pass"; Return; }

    If ($psVers -lt 5.1) {
        &cmd.exe /c "net user $UserName $Pass" | Out-Null
        &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$UserName') set PasswordExpires=False" | Out-Null
        # Verify the password was successfully changed
        $passChangeDate = Get-LastLocalPasswordChangeTime -User $UserName
        # If it's been more than 5min since the last password change on the user we're going to conut that a failure and
        # have it throw here
        If (((Get-Date) - $passChangeDate).TotalMinutes -gt 5) {
            Throw "Failed to set a new password for [$UserName]."
            Return
        } Else {
            Write-Output "Successfully set a new password for [$UserName]"
        }
    } Else {
        $stringPass = ConvertTo-SecureString -String $Pass -AsPlainText -Force
        Set-LocalUser -Name $UserName -Password $stringPass -ErrorAction Stop
        Write-Output "Successfully set a new password for [$UserName]"
    }
}

Function Add-ToLocalAdminGroup ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $userDetails = Get-LocalUserStatus -User $UserName

    # Add the $UserName is in the local Administrators group if not a member currently
    If ($userDetails -and !$userDetails.LocalAdmin) {
        If ($psVers -lt 5.1) {
            &cmd.exe /c "net localgroup $(Get-LocalAdminGroupName) $UserName /add" | Out-Null
        } Else {
            Add-LocalGroupMember -Group (Get-LocalAdminGroupName) -Member $UserName -ErrorAction Stop
        }
    }

    # CMD doesn't give us any kind of validation or throw if something failed so we're going to validate and throw here if
    # the user does not exist. Note the function called here is one defined in this script, not a default function
    $userDetails = Get-LocalUserStatus -User $UserName

    If (!$userDetails -or !$userDetails.LocalAdmin) {
        Throw "Failed to add [$UserName] to the local admins group. If there was an error, it is likely printed right before this error, but no promises."
    } Else {
        Return "Verified [$UserName] is in the local [$(Get-LocalAdminGroupName)] group."
    }
}

Function Set-PasswordNeverExpire ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $userDetails = Get-LocalUserStatus -User $UserName

    If ($userDetails.PasswordExpires) {
        If ($psVers -lt 5.1) {
            &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$UserName') set PasswordExpires=False" | Out-Null
        } Else {
            Set-LocalUser -Name $UserName -PasswordNeverExpires $true -ErrorAction Stop
        }
    }

    # CMD doesn't give us any kind of validation or throw if something failed so we're going to validate and throw here if
    # the user does not exist. Note the function called here is one defined in this script, not a default function
    $userDetails = Get-LocalUserStatus -User $UserName

    If (!$userDetails -or ($userDetails.PasswordExpires -ne 'Never')) {
        Throw "Failed to set required password to never expire for [$UserName]. If there was an error, it is likely printed right before this error, but no promises."
    } Else {
        Return "Verified [$UserName] password is set to never expire."
    }
}

Function Enable-User ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $userDetails = Get-LocalUserStatus -User $UserName

    If (!$userDetails.Enabled) {
        If ($psVers -lt 5.1) {
            &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$UserName') set Disabled=False" | Out-Null
        } Else {
            Enable-LocalUser -Name $UserName -ErrorAction Stop
        }
    }

    # CMD doesn't give us any kind of validation or throw if something failed so we're going to validate and throw here if
    # the user does not exist. Note the function called here is one defined in this script, not a default function
    $userDetails = Get-LocalUserStatus -User $UserName

    If (!$userDetails -or !$userDetails.Enabled) {
        Throw "Failed to enable [$UserName]. If there was an error, it is likely printed right before this error, but no promises."
    } Else {
        Return "Verified [$UserName] is enabled."
    }
}

Function Disable-User ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $userDetails = Get-LocalUserStatus -User $UserName

    If ($userDetails.Enabled) {
        If ($psVers -lt 5.1) {
            &cmd.exe /c "wmic useraccount WHERE (LocalAccount=True AND Name='$UserName') set Disabled=True" | Out-Null
        } Else {
            Disable-LocalUser -Name $UserName -ErrorAction Stop
        }
    }

    # CMD doesn't give us any kind of validation or throw if something failed so we're going to validate and throw here if
    # the user does not exist. Note the function called here is one defined in this script, not a default function
    $userDetails = Get-LocalUserStatus -User $UserName

    If (!$userDetails -or $userDetails.Enabled) {
        Throw "Failed to enable [$UserName]. If there was an error, it is likely printed right before this error, but no promises."
    } Else {
        Return "Verified [$UserName] is disabled."
    }
}

Function Set-ExistingAccountConfig ($UserName) {
    <#
    .DESCRIPTION
        This function is intended to enforce required settings on an existing user. This function will force the
        input user to have the following settings:
        - Member of local Administrators group
        - PasswordNeverExpires set to $false
        - User Enabled is $true

        This function will throw on failure to enforce any of these settings. This function works for all versions of
        Powershell.
    #>
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    $output = ''

    Try {
        $output += Add-ToLocalAdminGroup -UserName $UserName
    } Catch {
        $output += $_
    }

    Try {
        $output += Set-PasswordNeverExpire -UserName $UserName
    } Catch {
        $output += $_
    }

    Try {
        $output += Enable-User -UserName $UserName
    } Catch {
        $output += $_
    }

    Return $output
}

Function Get-LastLocalPasswordChangeTime ($UserName) {
    <#
    .DESCRIPTION
        The date/time the password was last set is in CMD. This function uses regex to get the date the
        password was last successfully set.

        The intended usage of this function is to verify a password was successfully changed. Occasionally,
        dependingo on the configuration of the endpoint, the password can fail to set if the password complexity
        has very non-standard requirements. If this is the case, we want to make sure we do NOT wipe the previous
        password, and want to preserve that password to ensure we still have access to the machine.
    #>
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    # Grab the local time the machine reports the password was last changed locally
    [datetime]$lastChanged = ((net user $UserName | Select-String -Pattern 'Password last set(\s*(.*))') -replace 'Password last set(\s*)','')
    Return $lastChanged
}


Function Disable-LocalUserAccount ($UserName) {
    <#
    .DESCRIPTION
        Very stragiht forward function to disable the input user. This function works with any version
        of Powershell.
    #>
    If (!$UserName) { Throw 'You must provide a username!'; Return; }

    If ($psVers -lt 5.1) {
        &cmd.exe /c "net user $UserName /active:no" | Out-Null
        If ((Get-LocalUserStatus -User $UserName).Enabled -ne $false) {
            Throw "Failed to disable [$UserName]"
        } Else {
            Write-Output "Successfully disabled [$UserName]"
        }
    } Else {
        Disable-LocalUser -Name $UserName -ErrorAction Stop
        Write-Output "Successfully disabled [$UserName]"
    }
}

Function Get-LocalAdminGroupMembers {
    <#
    .DESCRIPTION
        This function outputs all users currently in the local administrators group. This does not check to see
        if the account is enabled, but is rather a raw output. To determine if the user is enabled, use the
        Get-LocalUserStatus function.

    .Example
        Get-LocalAdminGroupMembers
        # AccountType : 512
        # Caption     : computername\Administrator
        # Domain      : computername
        # SID         : x-x-x-xx-xxxxx-xxxxx-xx-x
        # FullName    :
        # Name        : Administrator
    .Example
        Get-LocalAdminGroupMembers | ForEach-Object { Get-LocalUserStatus $_.Name }
        # AccountExpires                 Never
        # FullName
        # PasswordExpires                Never
        # SID                            x-x-x-xx-xxxxx-xxxxx-xx-x
        # Name                           Administrator
        # PrincipalSource                Domain
        # Description                    Built-in account for administering the computer/domain
        # LocalAdmin                     True
        # ObjectClass
        # UserMayChangePassword          True
        # LastLogon                      Never
        # Enabled                        True
        # PasswordRequired               True
        # PasswordLastSet                5/12/2022 10:19:42 AM
        # PasswordChangeableDate         5/12/2022 10:19:42 AM
    #>
    $wmiEnumOpts = New-Object System.Management.EnumerationOptions
    $wmiEnumOpts.BlockSize = 20

    $localAdmins = Get-LocalAdminGroup | Foreach-Object {
        Return $_.GetRelated("Win32_Account", "Win32_GroupUser", "", "", "PartComponent", "GroupComponent", $false, $wmiEnumOpts)
    }

    $errorMessage = "The local group corresponding to SID 'S-1-5-32-544' (admin) returns 0 users. " +
        "This implies there was a problem with the command execution. $($Error[0])"

    If (!$localAdmins) { Throw $errorMessage; Return; }

    Return $localAdmins
}

Function Remove-FromLocalAdminGroup ($UserName) {
    If (!$UserName) { Throw 'You must provide a username!'; Return; }
    If (!(Get-IsLocalAdmin $UserName)) { Write-Output "Successfully verified [$UserName] is not in the local $(Get-LocalAdminGroupName) group"; Return; }

    If ($psVers -lt 5.1) {
        &cmd.exe /c "net localgroup $(Get-LocalAdminGroupName) $UserName /delete" | Out-Null

        If (Get-IsLocalAdmin $UserName) { Throw "Failed to remove [$UserName] from the local [$(Get-LocalAdminGroupName)] group"; Return; }

        Write-Output "Successfully removed [$UserName] from the local $(Get-LocalAdminGroupName) group"
    } Else {
        Try {
            Remove-LocalGroupMember -Member $UserName -Group (Get-LocalAdminGroupName) -ErrorAction Stop
            Write-Output "Successfully removed [$UserName] from the local $(Get-LocalAdminGroupName) group"
        } Catch {
            Throw "Failed to remove [$UserName] from the local [$(Get-LocalAdminGroupName)] group. $($Error[0])"
        }
    }
}
