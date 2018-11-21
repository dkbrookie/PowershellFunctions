Function Get-SubnetItems {
    <#
        .SYNOPSIS
        Powerful asynchronus IPv4 Network Scanner
        .DESCRIPTION
        This powerful asynchronus IPv4 Network Scanner allows you to scan every IPv4-Range you want (172.16.1.47 to 172.16.2.5 would work). But there is also the possibility to scan an entire subnet based on an IPv4-Address withing the subnet and a the subnetmask/CIDR.
        The default result will contain the the IPv4-Address, Status (Up or Down) and the Hostname. Other values can be displayed via parameter.
        .EXAMPLE
        .\IPv4NetworkScan.ps1 -StartIPv4Address 192.168.178.0 -EndIPv4Address 192.168.178.20
        IPv4Address   Status Hostname
        -----------   ------ --------
        192.168.178.1 Up     fritz.box
        .EXAMPLE
        .\IPv4NetworkScan.ps1 -IPv4Address 192.168.178.0 -Mask 255.255.255.0 -DisableDNSResolving
        IPv4Address    Status
        -----------    ------
        192.168.178.1  Up
        192.168.178.22 Up
        .EXAMPLE
        .\IPv4NetworkScan.ps1 -IPv4Address 192.168.178.0 -CIDR 25 -EnableMACResolving
        IPv4Address    Status Hostname           MAC               Vendor
        -----------    ------ --------           ---               ------
        192.168.178.1  Up     fritz.box          XX-XX-XX-XX-XX-XX AVM Audiovisuelles Marketing und Computersysteme GmbH
        192.168.178.22 Up     XXXXX-PC.fritz.box XX-XX-XX-XX-XX-XX ASRock Incorporation
    #>

    [CmdletBinding(DefaultParameterSetName='CIDR')]
    Param(
      [Parameter(
        ParameterSetName='Range',
        Position=0,
        Mandatory=$True,
        HelpMessage='Start IPv4-Address like 192.168.1.10')]
      [IPAddress]$StartIPv4Address,

      [Parameter(
        ParameterSetName='Range',
        Position=1,
        Mandatory=$True,
        HelpMessage='End IPv4-Address like 192.168.1.100')]
      [IPAddress]$EndIPv4Address,

      [Parameter(
        ParameterSetName='CIDR',
        Position=0,
        Mandatory=$True,
        HelpMessage='IPv4-Address which is in the subnet')]
      [Parameter(
        ParameterSetName='Mask',
        Position=0,
        Mandatory=$True,
        HelpMessage='IPv4-Address which is in the subnet')]
      [IPAddress]$IPv4Address,

      [Parameter(
        ParameterSetName='CIDR',
        Position=1,
        Mandatory=$True,
        HelpMessage='CIDR like /24 without "/"')]
      [ValidateRange(0,31)]
      [Int32]$CIDR,

      [Parameter(
        ParameterSetName='Mask',
        Position=1,
        Mandatory=$True,
        Helpmessage='Subnetmask like 255.255.255.0')]
      [ValidateScript({
          If($_ -match "^(254|252|248|240|224|192|128).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(254|252|248|240|224|192|128|0)$")
          {
            Return $True
          }
          else
          {
            Throw "Enter a valid subnetmask (like 255.255.255.0)!"
          }
      })]
      [String]$Mask,

      [Parameter(
        Position=2,
        HelpMessage='Maxmium number of ICMP checks for each IPv4-Address (Default=2)')]
      [Int32]$Tries=2,

    [Parameter(
	    Position=3,
	    HelpMessage='Maximum number of threads at the same time (Default=256)')]
    [Int32]$Threads=256,

      [Parameter(
        Position=4,
        HelpMessage='Resolve DNS for each IP (Default=Enabled)')]
      [Switch]$DisableDNSResolving,

      [Parameter(
        Position=5,
        HelpMessage='Resolve MAC-Address for each IP (Default=Disabled)')]
      [Switch]$EnableMACResolving,

      [Parameter(
        Position=6,
        HelpMessage='Get extendend informations like BufferSize, ResponseTime and TTL (Default=Disabled)')]
      [Switch]$ExtendedInformations,

      [Parameter(
        Position=7,
        HelpMessage='Include inactive devices in result')]
      [Switch]$IncludeInactive
    )

    Begin{
        Write-Verbose -Message "Script started at $(Get-Date)"

        $OUIListPath = "$PSScriptRoot\Resources\oui.txt"

        Function Convert-Subnetmask
        {
          [CmdLetBinding(DefaultParameterSetName='CIDR')]
          param(
            [Parameter(
              ParameterSetName='CIDR',
              Position=0,
              Mandatory=$True,
              HelpMessage='CIDR like /24 without "/"')]
            [ValidateRange(0,32)]
            [Int32]$CIDR,

            [Parameter(
              ParameterSetName='Mask',
              Position=0,
              Mandatory=$True,
              HelpMessage='Subnetmask like 255.255.255.0')]
            [ValidateScript({
              If($_ -match "^(254|252|248|240|224|192|128).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$")
              {
                Return $True
              }
              else
              {
                Throw "Enter a valid subnetmask (like 255.255.255.0)!"
              }
            })]
            [String]$Mask
          )

          Begin {
          }
          Process {
            Switch($PSCmdlet.ParameterSetName)
            {
              "CIDR" {
                # Make a string of bits (24 to 11111111111111111111111100000000)
                $CIDR_Bits = ('1' * $CIDR).PadRight(32, "0")

                # Split into groups of 8 bits, convert to Ints, join up into a string
                $Octets = $CIDR_Bits -split '(.{8})' -ne ''
                $Mask = ($Octets | ForEach-Object -Process {[Convert]::ToInt32($_, 2) }) -join '.'
              }

              "Mask" {
                # Convert the numbers into 8 bit blocks, join them all together, count the 1
                $Octets = $Mask.ToString().Split(".") | ForEach-Object -Process {[Convert]::ToString($_, 2)}
                $CIDR_Bits = ($Octets -join "").TrimEnd("0")

                # Count the "1" (111111111111111111111111 --> /24)
                $CIDR = $CIDR_Bits.Length
              }
            }

            [pscustomobject] @{
              Mask = $Mask
              CIDR = $CIDR
            }
          }

          End {
          }
        }

        # Helper Function to convert an IPv4-Address to Int64 and vise versa
        Function Convert-IPv4Address
        {
          [CmdletBinding(DefaultParameterSetName='IPv4Address')]
          param(
            [Parameter(
              ParameterSetName='IPv4Address',
              Position=0,
              Mandatory=$True,
              HelpMessage='IPv4-Address as string like "192.168.1.1"')]
            [IPaddress]$IPv4Address,

            [Parameter(
              ParameterSetName='Int64',
              Position=0,
              Mandatory=$True,
              HelpMessage='IPv4-Address as Int64 like 2886755428')]
            [long]$Int64
          )

          Begin {
          }

          Process {
            Switch($PSCmdlet.ParameterSetName)
            {
              # Convert IPv4-Address as string into Int64
              "IPv4Address" {
                $Octets = $IPv4Address.ToString().Split(".")
                $Int64 = [long]([long]$Octets[0]*16777216 + [long]$Octets[1]*65536 + [long]$Octets[2]*256 + [long]$Octets[3])
              }

              # Convert IPv4-Address as Int64 into string
              "Int64" {
                $IPv4Address = (([System.Math]::Truncate($Int64/16777216)).ToString() + "." + ([System.Math]::Truncate(($Int64%16777216)/65536)).ToString() + "." + ([System.Math]::Truncate(($Int64%65536)/256)).ToString() + "." + ([System.Math]::Truncate($Int64%256)).ToString())
              }
            }

            [pscustomobject] @{
              IPv4Address = $IPv4Address
              Int64 = $Int64
            }
          }

          End {
          }
        }

        # Helper Function to create a new Subnet
        Function Get-IPv4Subnet
        {
          [CmdletBinding(DefaultParameterSetName='CIDR')]
          param(
            [Parameter(
              Position=0,
              Mandatory=$True,
              HelpMessage='IPv4-Address which is in the subnet')]
            [IPAddress]$IPv4Address,

            [Parameter(
              ParameterSetName='CIDR',
              Position=1,
              Mandatory=$True,
              HelpMessage='CIDR like /24 without "/"')]
            [ValidateRange(0,31)]
            [Int32]$CIDR,

            [Parameter(
              ParameterSetName='Mask',
              Position=1,
              Mandatory=$True,
              Helpmessage='Subnetmask like 255.255.255.0')]
            [ValidateScript({
              If($_ -match "^(254|252|248|240|224|192|128).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(254|252|248|240|224|192|128|0)$")
              {
                  Return $True
              }
              else
              {
                  Throw "Enter a valid subnetmask (like 255.255.255.0)!"
              }
            })]
            [String]$Mask
          )

          Begin{
          }

          Process{
              # Convert Mask or CIDR - because we need both in the code below
              Switch($PSCmdlet.ParameterSetName)
              {
                "CIDR" {
                  $Mask = (Convert-Subnetmask -CIDR $CIDR).Mask
                }
                "Mask" {
                  $CIDR = (Convert-Subnetmask -Mask $Mask).CIDR
                }
              }

              # Get CIDR Address by parsing it into an IP-Address
              $CIDRAddress = [System.Net.IPAddress]::Parse([System.Convert]::ToUInt64(("1"* $CIDR).PadRight(32, "0"), 2))

              # Binary AND ... this is how subnets work.
              $NetworkID_bAND = $IPv4Address.Address -band $CIDRAddress.Address

              # Return an array of bytes. Then join them.
              $NetworkID = [System.Net.IPAddress]::Parse([System.BitConverter]::GetBytes([UInt32]$NetworkID_bAND) -join ("."))

              # Get HostBits based on SubnetBits (CIDR) // Hostbits (32 - /24 = 8 -> 00000000000000000000000011111111)
              $HostBits = ('1' * (32 - $CIDR)).PadLeft(32, "0")

              # Convert Bits to Int64
              $AvailableIPs = [Convert]::ToInt64($HostBits,2)

              # Convert Network Address to Int64
              $NetworkID_Int64 = (Convert-IPv4Address -IPv4Address $NetworkID.ToString()).Int64

              # Convert add available IPs and parse into IPAddress
              $Broadcast = [System.Net.IPAddress]::Parse((Convert-IPv4Address -Int64 ($NetworkID_Int64 + $AvailableIPs)).IPv4Address)

              # Change useroutput ==> (/27 = 0..31 IPs -> AvailableIPs 32)
              $AvailableIPs += 1

              # Hosts = AvailableIPs - Network Address + Broadcast Address
              $Hosts = ($AvailableIPs - 2)

              # Build custom PSObject
              [pscustomobject] @{
                  NetworkID = $NetworkID
          	    Broadcast = $Broadcast
          	    IPs = $AvailableIPs
         	        Hosts = $Hosts
              }
          }

          End{
          }
      }
    }

    Process{
        # Calculate Subnet (Start and End IPv4-Address)
        If($PSCmdlet.ParameterSetName -eq 'CIDR' -or $PSCmdlet.ParameterSetName -eq 'Mask')
        {
          # Convert Subnetmask
          If($PSCmdlet.ParameterSetName -eq 'Mask')
          {
            $CIDR = (Convert-Subnetmask -Mask $Mask).CIDR
          }

          # Create new subnet
          $Subnet = Get-IPv4Subnet -IPv4Address $IPv4Address -CIDR $CIDR

          # Assign Start and End IPv4-Address
          $StartIPv4Address = $Subnet.NetworkID
          $EndIPv4Address = $Subnet.Broadcast
        }

        # Convert Start and End IPv4-Address to Int64
        $StartIPv4Address_Int64 = (Convert-IPv4Address -IPv4Address $StartIPv4Address.ToString()).Int64
        $EndIPv4Address_Int64 = (Convert-IPv4Address -IPv4Address $EndIPv4Address.ToString()).Int64

        # Check If range is valid
        If($StartIPv4Address_Int64 -gt $EndIPv4Address_Int64)
        {
          Write-Error -Message "Invalid IP-Range... Check your input!" -Category InvalidArgument -ErrorAction Stop
        }

        # Calculate IPs to scan (range)
        $IPsToScan = ($EndIPv4Address_Int64 - $StartIPv4Address_Int64)

        Write-Verbose -Message "Scanning range from $StartIPv4Address to $EndIPv4Address ($($IPsToScan + 1) IPs)"
        Write-Verbose -Message "Running with max $Threads threads"
        Write-Verbose -Message "ICMP checks per IP: $Tries"

        # Properties which are displayed in the output
        $PropertiesToDisplay = @()
        $PropertiesToDisplay += "IPv4Address", "Status"

        If($DisableDNSResolving -eq $False)
        {
          $PropertiesToDisplay += "Hostname"
        }

        If($EnableMACResolving)
        {
          $PropertiesToDisplay += "MAC"
        }

        # Check If it is possible to assign vendor to MAC --> import CSV-File
        If($EnableMACResolving)
        {
          If(Test-Path -Path $OUIListPath -PathType Leaf)
          {
            $OUIHashTable = @{ }

            Write-Verbose -Message "Read oui.txt and fill hash table..."

            ForEach($Line in Get-Content -Path $OUIListPath)
            {
              If(-not([String]::IsNullOrEmpty($Line)))
              {
                Try{
                  $HashTableData = $Line.Split('|')
                  $OUIHashTable.Add($HashTableData[0], $HashTableData[1])
                }
                Catch [System.ArgumentException] { } # Catch If mac is already added to hash table
              }
            }

            $AssignVendorToMAC = $True

            $PropertiesToDisplay += "Vendor"
          }
          else
          {
            $AssignVendorToMAC = $False

            Write-Warning -Message "No OUI-File to assign vendor with MAC-Address found! Execute the script ""Create-OUIListFromWeb.ps1"" to download the latest version. This warning does not affect the scanning procedure."
          }
        }

        If($ExtendedInformations)
        {
          $PropertiesToDisplay += "BufferSize", "ResponseTime", "TTL"
        }

        # Scriptblock --> will run in runspaces (threads)...
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            Param(
			    $IPv4Address,
			    $Tries,
			    $DisableDNSResolving,
			    $EnableMACResolving,
			    $ExtendedInformations,
                $IncludeInactive
		    )

            # +++ Send ICMP requests +++
            $Status = [String]::Empty

		    For($i = 0; $i -lt $Tries; i++)
		    {
			    Try{
				    $PingObj = New-Object System.Net.NetworkInformation.Ping

				    $Timeout = 1000
				    $Buffer = New-Object Byte[] 32

				    $PingResult = $PingObj.Send($IPv4Address, $Timeout, $Buffer)

				    If($PingResult.Status -eq "Success")
				    {
					    $Status = "Up"
					    Break # Exit loop, If host is reachable
				    }
				    else
				    {
					    $Status = "Down"
				    }
			    }
			    Catch
			    {
				    $Status = "Down"
				    Break # Exit loop, If there is an error
			    }
		    }

		    # +++ Resolve DNS +++
		    $Hostname = [String]::Empty

            If((-not($DisableDNSResolving)) -and ($Status -eq "Up" -or $IncludeInactive))
            {
		        Try{
                    $Hostname = ([System.Net.Dns]::GetHostEnTry($IPv4Address).HostName)
                }
                Catch { } # No DNS
     	    }

            # +++ Get MAC-Address +++
		    $MAC = [String]::Empty

            If(($EnableMACResolving) -and (($Status -eq "Up") -or ($IncludeInactive)))
            {
                $Arp_Result = (arp -a ).ToUpper()

			    ForEach($Line in $Arp_Result)
                {
                    If($Line.TrimStart().StartsWith($IPv4Address))
                    {
					    $MAC = [Regex]::Matches($Line,"([0-9A-F][0-9A-F]-){5}([0-9A-F][0-9A-F])").Value
                    }
                }
            }

		    # +++ Get extended informations +++
		    $BufferSize = [String]::Empty
		    $ResponseTime = [String]::Empty
            $TTL = $Null

            If($ExtendedInformations -and ($Status -eq "Up"))
		    {
			    Try{
				    $BufferSize =  $PingResult.Buffer.Length
				    $ResponseTime = $PingResult.RoundtripTime
				    $TTL = $PingResult.Options.Ttl
			    }
			    Catch{ } # Failed to get extended informations
		    }

            # +++ Result +++
            If(($Status -eq "Up") -or ($IncludeInactive))
            {
              [pscustomobject] @{
                IPv4Address = $IPv4Address
                Status = $Status
                Hostname = $Hostname
                MAC = $MAC
                BufferSize = $BufferSize
  			        ResponseTime = $ResponseTime
  			        TTL = $TTL
              }
            }
            else
            {
              $Null
            }
        }

        Write-Verbose -Message "Setting up RunspacePool..."

        # Create RunspacePool and Jobs
        $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $Threads, $Host)
        $RunspacePool.Open()
        [System.Collections.ArrayList]$Jobs = @()

        Write-Verbose -Message "Setting up jobs..."

        # Set up jobs for each IP...
        for ($i = $StartIPv4Address_Int64; $i -le $EndIPv4Address_Int64; $i++)
        {
            # Convert IP back from Int64
            $IPv4Address = (Convert-IPv4Address -Int64 $i).IPv4Address

		    # Create hashtable to pass parameters
		    $ScriptParams = @{
			    IPv4Address = $IPv4Address
			    Tries = $Tries
			    DisableDNSResolving = $DisableDNSResolving
			    EnableMACResolving = $EnableMACResolving
			    ExtendedInformations = $ExtendedInformations
            IncludeInactive = $IncludeInactive
		    }

		    # Catch when Trying to divide through zero
            Try {
			    $Progress_Percent = (($i - $StartIPv4Address_Int64) / $IPsToScan) * 100
		    }
		    Catch {
			    $Progress_Percent = 100
		    }

            Write-Progress -Activity "Setting up jobs..." -Id 1 -Status "Current IP-Address: $IPv4Address" -PercentComplete $Progress_Percent

		    # Create new job
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool

            $JobObj = [pscustomobject] @{
                RunNum = $i - $StartIPv4Address_Int64
                Pipe = $Job
                Result = $Job.BeginInvoke()
            }

            # Add job to collection
            [void]$Jobs.Add($JobObj)
        }

        Write-Verbose -Message "Waiting for jobs to complete & starting to process results..."

        # Total jobs to calculate percent complete, because jobs are removed after they are processed
        $Jobs_Total = $Jobs.Count

        # Process results, while waiting for other jobs
        Do {
            # Get all jobs, which are completed
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript {$_.Result.IsCompleted}

            # If no jobs finished yet, wait 500 ms and Try again
            If($Null -eq $Jobs_ToProcess)
            {
                Write-Verbose -Message "No jobs completed, wait 250ms..."

                Start-Sleep -Milliseconds 250
                Continue
            }

            # Get jobs, which are not complete yet
            $Jobs_Remaining = ($Jobs | Where-Object -FilterScript {$_.Result.IsCompleted -eq $False}).Count

            # Catch when Trying to divide through zero
            Try {
                $Progress_Percent = 100 - (($Jobs_Remaining / $Jobs_Total) * 100)
            }
            Catch {
                $Progress_Percent = 100
            }

            Write-Progress -Activity "Waiting for jobs to complete... ($($Threads - $($RunspacePool.GetAvailableRunspaces())) of $Threads threads running)" -Id 1 -PercentComplete $Progress_Percent -Status "$Jobs_Remaining remaining..."

            Write-Verbose -Message "Processing $(If($Null -eq $Jobs_ToProcess.Count){"1"}else{$Jobs_ToProcess.Count}) job(s)..."

            # Processing completed jobs
            ForEach($Job in $Jobs_ToProcess)
            {
                # Get the result...
                $Job_Result = $Job.Pipe.EndInvoke($Job.Result)
                $Job.Pipe.Dispose()

                # Remove job from collection
                $Jobs.Remove($Job)

                # Check If result contains status
                If($Job_Result.Status)
                {
                    If($AssignVendorToMAC)
                    {
                        $Vendor = [String]::Empty

                        # Check If MAC is null or empty
                        If(-not([String]::IsNullOrEmpty($Job_Result.MAC)))
                        {
                            # Split it, so we can search the vendor (XX-XX-XX-XX-XX-XX to XXXXXX)
                            $MAC_VendorSearch = $Job_Result.MAC.Replace("-","").Substring(0,6)

                            $Vendor = $OUIHashTable.Get_Item($MAC_VendorSearch)
                        }

                        [pscustomobject] @{
                            IPv4Address = $Job_Result.IPv4Address
                            Status = $Job_Result.Status
                            Hostname = $Job_Result.Hostname
                            MAC = $Job_Result.MAC
                            Vendor = $Vendor
                            BufferSize = $Job_Result.BufferSize
                            ResponseTime = $Job_Result.ResponseTime
                            TTL = $ResuJob_Resultlt.TTL
                        } | Select-Object -Property $PropertiesToDisplay
                    }
                    else
                    {
                        $Job_Result | Select-Object -Property $PropertiesToDisplay
                    }
                }
            }

        } While ($Jobs.Count -gt 0)

        Write-Verbose -Message "Closing RunspacePool and free resources..."

        # Close the RunspacePool and free resources
        $RunspacePool.Close()
        $RunspacePool.Dispose()

        Write-Verbose -Message "Script finished at $(Get-Date)"
    }

    End{
    }
}
