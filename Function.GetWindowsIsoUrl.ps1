<#
    .DESCRIPTION
    Returns a link to a (non-enterprise) Windows ISO download for Windows 10 or 11

    .INPUTS
    $Rel - Should be something like '20H1' or '21H2'
    $Win - Should be either '10' or '11'

    .OUTPUTS
    Object with keys "Type" which is the system architecture that the ISO was built for and "Link"
    which is the URL of the ISO which will be valid for a short time (whatever microsoft decides..
    something like 24-48 hours?)

    .EXAMPLE
    PS> Get-WindowsIsoUrl -Win '11' -Rel '21H2'
    Type  Link
    ----  ----
    x64   https://software-download.microsoft.com/pr/Win11_English_x64.iso

    .NOTES
    In order to support a new version, you must update Fido by pulling upstream changes from the
    main Fido repository then add the new values to the ValidateSets in the params below
#>

function Get-WindowsIsoUrl {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('20H2', '21H1', '21H2')]
        [string]$Rel,
        [Parameter(Mandatory)]
        [ValidateSet(10, 11)]
        [string]$Win
    )

    $fidoScript = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/Fido/master/Fido.ps1')

    $params = @{
        Win = "'Windows $Win'"
        GetUrl = '$true'
        Lang = '"English"'
        Rel = "'$Rel'"
    }

    $fidoScriptBlock = [ScriptBlock]::create(".{$fidoScript} $(&{$args} @params)")


    $url = Invoke-Command -ScriptBlock $fidoScriptBlock

    If ($Null -eq $url) {
        Throw "FIDO (WinISO URL generator script) is not returning a value!! Must fix FIDO!"
    }

    Return $url
}
