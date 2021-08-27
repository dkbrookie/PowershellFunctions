<#
Checks to see if $minGb exists on C drive and tries to reclaim it if it does not.
Returns a hashtable with Output and DiskFull Keys. Output is a string with all messages
that occurred. DiskFull is a boolean, $True if disk still has less than $minGb available.
$False if disk has at least $minGb available.
#>

function Get-IsDiskFull {
    param ([Int]$minGb)
    $out = @()

    $spaceAvailable = [math]::round((Get-PSDrive C | Select-Object -ExpandProperty Free) / 1GB, 0)

    If ($spaceAvailable -lt $minGb) {
        $out += "You only have a total of $spaceAvailable GBs available, we need $minGb or more to complete successfully. Starting disk cleanup script to attempt clearing enough space to continue..."

        ## Run the disk cleanup script
        (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/Automate-Public/master/Maintenance/Disk%20Cleanup/Powershell/Disk_Cleanup.ps1') | Invoke-Expression

        $spaceAvailable = [math]::round((Get-PSDrive C | Select-Object -ExpandProperty Free) / 1GB, 0)

        If ($spaceAvailable -lt 10) {
            # Disk is still too full :'(
            $out = "!Error: After disk cleanup the available space is now $spaceAvailable GBs, still under $minGb. Please manually clear at least $minGb and try this script." + $out

            Return @{
                Output = $out
                DiskFull = $True
            }
        }
    }
}
