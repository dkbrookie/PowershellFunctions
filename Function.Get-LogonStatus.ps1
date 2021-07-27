<#
    .Synopsis
    Will return the logged-on status of a computer as 0, 1, or 2.
        - 0: not logged on
        - 1: logged on and actively using PC
        - 2: logged on but locked
#>
function Get-LogonStatus {
    $user = $Null

    Try {
        $user = Get-WmiObject -ClassName win32_computersystem | Select-Object -ExpandProperty UserName -ErrorAction Stop
    } Catch {
        # not logged on if we land here
        Return 0
    }

    If (!$user) {
        # Not sure how we ended up here, because the last block should have errored if no user
        # and the catch should have returned 0... but just in case!
        Return 0
    }

    Try {
        # If user is logged on, but is on the lock screen, logonui process will be active
        If (Get-Process logonui -ErrorAction Stop) {
            Return 2
        }
    } Catch {
        # If logonui is not active, user is logged in and active
        Return 1
    }
}
