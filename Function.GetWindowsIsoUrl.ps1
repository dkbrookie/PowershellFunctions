function Get-WindowsIsoUrl {
    param([string]$Rel = '20H2')

    $fidoScript = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/Fido/master/Fido.ps1')

    $params = @{
        GetUrl = '$true'
        Rel = $Rel
    }

    $fidoScriptBlock = [ScriptBlock]::create(".{$fidoScript} $(&{$args} @params)")


    Return Invoke-Command -ScriptBlock $fidoScriptBlock
}
