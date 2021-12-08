function Get-WindowsVersion {
    $osDeets = Get-WmiObject win32_operatingsystem
    $osName = $osDeets.Caption
    $osArch = $osDeets.OSArchitecture

    $osObject = @{
        Name = $Null
        SimplifiedName = $Null
        Build = $Null
        Version = $Null
        Arch = $osArch
        OrderOfWin10Versions = @('1507','1511','1607','1703','1709','1803','1809','1903','1909','2004','20H2','21H1', '21H2')
    }

    If ($osName -like 'Microsoft Windows Server 2008*' -and $osName -notlike '*R2*') {
        $osObject.SimplifiedName = '2008'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows Server 2008 R2*') {
        $osObject.SimplifiedName = '2008r2'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows Server 2012*' -and $osName -notlike '*R2*') {
        $osObject.SimplifiedName = '2012'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows Server 2012 R2*') {
        $osObject.SimplifiedName = '2012r2'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows Server 2016*') {
        $osObject.SimplifiedName = '2016'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows Server 2019*') {
        $osObject.SimplifiedName = '2019'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows 10*') {
        # get raw Windows version
        [int64]$rawVersion = [Windows.System.Profile.AnalyticsInfo,Windows.System.Profile,ContentType=WindowsRuntime].GetMember('get_VersionInfo').Invoke( $Null, $Null ).DeviceFamilyVersion

        # decode bits to version bytes
        $build = ( $rawVersion -band 0x00000000FFFF0000l ) -shr 16

        Switch ($build) {
            19044 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '21H2'; $osObject.Build = '19044'; }
            19043 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '21H1'; $osObject.Build = '19043'; }
            19042 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '20H2'; $osObject.Build = '19042'; }
            19041 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '2004'; $osObject.Build = '19041'; }
            18363 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1909'; $osObject.Build = '18363'; }
            18362 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1903'; $osObject.Build = '18362'; }
            17763 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1809'; $osObject.Build = '17763'; }
            17134 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1803'; $osObject.Build = '17134'; }
            16299 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1709'; $osObject.Build = '16299'; }
            15063 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1703'; $osObject.Build = '15063'; }
            14393 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1607'; $osObject.Build = '14393'; }
            10586 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1511'; $osObject.Build = '10586'; }
            10240 { $osObject.Name = $osName; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = '1507'; $osObject.Build = '10240'; }
            Default { $osObject.Name = 'Windows 10 Unkown'; $osObject.SimplifiedName = 'Windows 10'; $osObject.Version = 'Unkown'; $osObject.Build = "$build"; }
        }
    } ElseIf ($osName -like 'Microsoft Windows 8*') {
        $osObject.SimplifiedName = '8.1'
        $osObject.Name = $osName
    } ElseIf ($osName -like 'Microsoft Windows 7*') {
        $osObject.SimplifiedName = '7'
        $osObject.Name = $osName
    }

    Return $osObject
}
