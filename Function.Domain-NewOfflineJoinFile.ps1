Function Domain-NewOfflineJoinFile {
    <#
    .Synopsis
        Join a domain using a DomainJoinFile
    .DESCRIPTION
        This is a PowerShell frontend to the DJOIN.exe command so it's easier to control for multiple clients

    .PARAMETER Domain
        The -Domain just represents the domain you are creating an offline join file for. Use the full domain path
        such as company.local or company.com

    .PARAMETER ComputerName
        For the -ComputerName argument, use the name of the computer you will be joining to the domain. Keep in mind
        that if the computer name already exists in AD that the offline domain file creation will FAIL. Either remove
        the old object from AD, or rename the machine your'e joining.

    .PARAMETER Path
        The -Path switch is the location your already created offline domain join file is located

    .PARAMETER MachineOU
        With the -MachineOU argument you can specify the OU the new computer will be added to.

    .PARAMETER Reuse
        Use the -Reuse parameter to reuse any existing account (password will be reset)

    .PARAMETER NoSearch
        Use the -NoSearch parameter to skip account conflict detection, requires DCNAME (faster)

    .PARAMETER DownLevel
        Use the -DownLevel parameter if you need support for a Windows Server 2008 DC or earlier

    .PARAMETER Printable
        The -Printable parameter can be used to return base64 encoded metadata blob for an answer file

    .PARAMETER RootCACerts
        Use the -RootCACerts parameter if you need to include root CertIficate Authority certificates.

    .PARAMETER CertTemplate
        The -CertTemplate is for achine certIficate template. Includes root CertIficate Authority certIficates.

    .PARAMETER PolicyNames
        -PolicyNames is for semicolon-separated list of policy paths. Each path is a path to a registry policy file.

    .PARAMETER PolicyPaths
        -PolicyPaths is for semicolon-separated list of policy paths. Each path is a path to a registry policy file.

    .PARAMETER NetBIOS
        Use -NetBIOS if you want to use the NetBIOS name of the machine joining the domain.

    .PARAMETER PersistentSite
        Use the -PersistentSite parameter to define the name of persistent site to put the computer joining the domain in.

    .PARAMETER DynamicSite
        Use the -DynamicSite to define the name of dynamic site to initially put the computer joining the domain in.

    .PARAMETER PrimaryDNS
        Use the -PrimaryDNS paraemtger to define the name of the primary DNS domain of the computer joining the domain.

    .EXAMPLE
        PS> Domain-NewOfflineJoinFile -Domain company.local -ComputerName Company-98320DWR
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory=$true,Position=0)]
        [String]$Domain,

        [Parameter(Mandatory=$true,Position=1)]
        [String]$ComputerName,

        [Parameter(Mandatory=$true,Position=2)]
        [String]$Path,

        [Parameter()]
        [String]$MachineOU,

        [Parameter()]
        [Switch]$Reuse,

        [Parameter()]
        [Switch]$NoSearch,

        [Parameter()]
        [Switch]$DownLevel,

        [Parameter()]
        [Switch]$Printable,

        [Parameter()]
        [Switch]$RootCACerts,

        [Parameter()]
        [String]$CertTemplate,

        [Parameter()]
        [String]$PolicyNames,

        [Parameter()]
        [String]$PolicyPaths,

        [Parameter()]
        [String]$NetBIOS,

        [Parameter()]
        [String]$PersistentSite,

        [Parameter()]
        [String]$DynamicSite,

        [Parameter()]
        [String]$PrimaryDNS
    )

    # These statements and the use of single quotes are SECURITY CRITICAL.
    # Without these someone could do an injection attack (e.g. provider a parameter with a ";" to terminate the statement
    # and then start a new, evil, command.
    $Domain         = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Domain)
    $ComputerName   = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($ComputerName)
    $Path           = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Path)
    $MachineOU      = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($MachineOU)
    $CertTemplate   = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($CertTemplate)
    $PolicyNames    = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($PolicyNames)
    $PolicyPaths    = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($PolicyPaths)
    $NetBIOS        = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($NetBIOS)
    $PersistentSite = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($PersistentSite)
    $DynamicSite    = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($DynamicSite)
    $PrimaryDNS     = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($PrimaryDNS)


    $cmd = "djoin.exe /provision /domain '$Domain' /machine '$ComputerName' /savefile '$Path'"

    If ($PSBoundParameters.ContainsKey('MachineOU')) {
        $cmd += "/MACHINEOU '$MachineOU' "
    }

    If ($Reuse.IsPresent) {
        $cmd += "/Reuse "
    }

    If ($NoSearch.IsPresent) {
        $cmd += "/NoSearch "
    }

    If ($DOWNLEVEL.IsPresent) {
        $cmd += "/DOWNLEVEL "
    }

    If ($Printable.IsPresent) {
        $cmd += "/PRINTBLOB "
    }

    If ($RootCACerts.IsPresent) {
        $cmd += "/RootCACerts "
    }

    If ($PSBoundParameters.ContainsKey('MachineOU')) {
        $cmd += "/MACHINEOU '$MachineOU' "
    }

    If ($PSBoundParameters.ContainsKey('CertTemplate')) {
        $cmd += "/CertTemplate '$CertTemplate' "
    }

    If ($PSBoundParameters.ContainsKey('PolicyNames')) {
        $cmd += "/POLICYNAMES '$PolicyNames' "
    }

    If ($PSBoundParameters.ContainsKey('PolicyPaths')) {
        $cmd += "/POLICYPaths '$PolicyPaths' "
    }

    If ($PSBoundParameters.ContainsKey('NetBIOS')) {
        $cmd += "/NetBIOS '$NetBIOS' "
    }

    If ($PSBoundParameters.ContainsKey('PersistentSite')) {
        $cmd += "/PSITE '$PersistentSite' "
    }

    If ($PSBoundParameters.ContainsKey('DynamicSite')) {
        $cmd += "/DSITE '$DynamicSite' "
    }

    If ($PSBoundParameters.ContainsKey('PrimaryDNS')) {
        $cmd += "/PRIMARYDNS '$PrimaryDNS' "
    }

    If ($PSBoundParameters.ContainsKey("Verbose")) {
        Write-Verbose $cmd
    }

    If ($PSCmdlet.ShouldProcess($domain, "Domain join computer [$computerName]")) {
        Invoke-Expression $cmd
    }
}




Function Domain-JoinFromFile {
    <#
    .Synopsis
        Join a domain using a DomainJoinFile
    .DESCRIPTION
        This is a PowerShell frontend to the DJOIN.exe command so it's easier to control for multiple clients
    .PARAMETER Path
        The -Path switch is the location your already created offline domain join file is located
    .EXAMPLE
        PS> Domain-JoinFromFile -Path 'C:\domainJoin.txt' -JoinLocalOS 
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # Path to the DomainJoinFile
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateScript({test-path $_})]
        [String]$Path,

        # WindowsPath specIfies the locally running OS
        [Parameter()]
        [Switch]$JoinLocalOS
    )

    # These statements and the use of single quotes are SECURITY CRITICAL.
    # Without these someone could do an injection attack (e.g. provider a parameter with a ";" to terminate the statement
    # and then start a new, malicious, command.
    $Path = [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Path)

    If ($JoinLocalOS.IsPresent) {
        $TargetString =  "Local computer [$(hostname)]"
    } Else {
        $TargetString =  "Offine computer"
    }

    If ($PSCmdlet.ShouldProcess($TargetString, "Use [$Path] to domain join")) {
        If ($JoinLocalOS.IsPresent) {
            djoin.exe /requestodj /LoadFile $Path /Windowspath '$env:windir' /LocalOS
        } Else {
            djoin.exe /requestodj /LoadFile $Path /Windowspath '$env:windir'
        }
    }
}
