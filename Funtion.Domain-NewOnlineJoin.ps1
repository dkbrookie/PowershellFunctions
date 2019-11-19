Function Domain-NewOnlineJoin {
    <#
    .Synopsis
        Join a domain using the built in Powershell calls.

    .DESCRIPTION
        This is a function to handle a domain join with some error handling.

    .PARAMETER Domain
        Full domain here like "DOMAIN.local".

    .PARAMETER Server
        AD server you want to contact to join the domain. You can use the FQDN or just the server name, if it's
        only the server name the domain will be added to the end of it automatically.

    .PARAMETER Username
        AD username you want to use to join the machine to the domain. Be sure to include the domain name before
        the username like "DOMAIN\USER"
    
    .PARAMETER Password
        Password for the AD account you're using to join the domain

    .EXAMPLE
        PS> Domain-NewOnlineJoin -Domain company.local -Server ADSERVER -Username DOMAIN\Administrator -Password SomePassHere
    #>

    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Domain,

        [Parameter(Mandatory=$true)]
        [String]$Server,

        [Parameter(Mandatory=$true)]
        [String]$Username,

        [Parameter(Mandatory=$true)]
        [String]$Password
    )

    $Pass = $Password | ConvertTo-SecureString -asPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Username,$Pass)

    If ($Server -notlike "*$Domain") {
        $Server = $Server + '.' + $Domain
    }

    Try {
        Test-Connection $Server -EA Stop | Out-Null
    } Catch {
        Write-Warning "Unable to contact $Server! This means the domain join will fail. Please ensure $env:COMPUTERNAME can communicate with $Server and try again."
        Break
    }

    Try {
        Add-Computer -DomainName $Domain -Credential $Credential -Server "$Server" -Restart
    } Catch {
        Write-Warning "Error Message: $_"
    }

    $Server = $Null
}