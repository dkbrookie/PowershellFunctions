function Get-WindowsIsoUrl {
    param([string]$Rel = '20H2')

    $fidoScript = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/Fido/master/Fido.ps1')

    $params = @{
        Win = '"Windows 10"'
        GetUrl = '$true'
        Lang = '"English"'
        Rel = $Rel
    }

    $fidoScriptBlock = [ScriptBlock]::create(".{$fidoScript} $(&{$args} @params)")


    $url = Invoke-Command -ScriptBlock $fidoScriptBlock

    If ($Null -eq $url) {
        Throw "FIDO (WinISO URL generator script) is not returning a value!! Must fix FIDO!"
    }

    Return $url
}
