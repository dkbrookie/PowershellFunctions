Function Domain-NewOnlineJoin {
    <#
    .Synopsis
        Join a domain using the built in Powershell calls

    .DESCRIPTION
        This is a function to handle a domain join with some error handling

    .PARAMETER Domain
        test

    .PARAMETER Server
        test

    .PARAMETER Username
        test
    
    .PARAMETER Password
        test

    .EXAMPLE
        PS> Domain-NewOnlineJoin -Domain company.local -Server ADSERVER -Username Administrator -Password SomePassHere
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