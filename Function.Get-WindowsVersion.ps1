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
        OrderOfWin11Versions = @('21H2')
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

        $osObject.SimplifiedName = '10';
        $osObject.Name = $osName;
        $osObject.Build = "$build";

        Switch ($build) {
            19044 { $osObject.Version = '21H2'; }
            19043 { $osObject.Version = '21H1'; }
            19042 { $osObject.Version = '20H2'; }
            19041 { $osObject.Version = '2004'; }
            18363 { $osObject.Version = '1909'; }
            18362 { $osObject.Version = '1903'; }
            17763 { $osObject.Version = '1809'; }
            17134 { $osObject.Version = '1803'; }
            16299 { $osObject.Version = '1709'; }
            15063 { $osObject.Version = '1703'; }
            14393 { $osObject.Version = '1607'; }
            10586 { $osObject.Version = '1511'; }
            10240 { $osObject.Version = '1507'; }
            Default { $osObject.Name = 'Windows 10 Unknown'; $osObject.Version = 'Unknown'; }
        }
    } ElseIf ($osName -like 'Microsoft Windows 11*') {
        # get raw Windows version
        [int64]$rawVersion = [Windows.System.Profile.AnalyticsInfo,Windows.System.Profile,ContentType=WindowsRuntime].GetMember('get_VersionInfo').Invoke( $Null, $Null ).DeviceFamilyVersion

        # decode bits to version bytes
        $build = ( $rawVersion -band 0x00000000FFFF0000l ) -shr 16

        $osObject.SimplifiedName = '11';
        $osObject.Name = $osName;
        $osObject.Build = "$build";

        Switch ($build) {
            22000 { $osObject.Version = '21H2'; }
            Default { $osObject.Name = 'Windows 11 Unknown'; $osObject.Version = 'Unknown'; }
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
