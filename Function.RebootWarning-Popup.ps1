## Clear out all variables / hash tables before starting the script
Remove-Variable * -ErrorAction SilentlyContinue; Remove-Module *; $error.Clear(); Clear-Host

Function RebootWarning-Popup {
    [CmdletBinding()]

    Param(
        [string]$Message,
        [string]$Title,
        [string]$Option1,
        [string]$BackgroundImage
    )

    If (!$BackgroundImage) {
        $BackgroundImage = "https://drive.google.com/uc?export=download&id=115V55-YXSvaPD6cuUQ_KzO0-SY8FSVW5"
    }

    $bgImage = "$env:windir\LTSvc\logo.png"
    If (!(Test-Path $bgImage -PathType Leaf)) {
        (New-Object System.Net.WebClient).DownloadFile($BackgroundImage,$bgImage)
    }

    If (!$Title) {
        $Title = "DKBInnovative"
    }
    If (!$Option1) {
        $Option1 = "OK"
    }
    If (!$Message) {
        $Message = "Your computer needs to reboot!"
    }

    ## Load the Winforms assembly
    [reflection.assembly]::LoadWithPartialName( "System.Windows.Forms") | Out-Null
    Add-Type -AssemblyName System.Windows.Forms

    $Icon = [system.drawing.icon]::ExtractAssociatedIcon("C:\Windows\LTSvc\labTech.ico")
    $Background = [system.drawing.image]::FromFile($bgImage)
    $Font = New-Object System.Drawing.Font("Segoe UI",10,[System.Drawing.FontStyle]::Regular)
    $rebootForm = New-Object system.Windows.Forms.Form
    $rebootForm.Text = $Title
    $rebootForm.Icon = $Icon
    $rebootForm.AutoScale = $True
    $rebootForm.AutoSize = $True
    $rebootForm.Font = $Font
    $rebootForm.TopMost = $True
    $rebootForm.AutoSizeMode = "GrowAndShrink"
    $rebootForm.BackColor = "White"
    $rebootForm.StartPosition = "CenterScreen"
    $rebootForm.BackgroundImage = $Background
    $rebootForm.BackgroundImageLayout = "Center"

    ## Text
    $Label = New-Object System.Windows.Forms.Label
    $Label.AutoSize = $True
    $Label.BackColor = "Transparent"
    $Label.textAlign = "MiddleCenter"
    $Label.Dock = [System.Windows.Forms.DockStyle]::Top
    $Label.Anchor = [System.Windows.Forms.AnchorStyles]::Left
    $Label.Padding = 15
    $Label.Text = $Message

    #region Button1
    $button1 = new-object System.Windows.Forms.Button
    $button1.Text = $Option1
    $button1.AutoSize = $True
    $button1.Dock = [System.Windows.Forms.DockStyle]::Bottom
    $button1.Anchor = [System.Windows.Forms.AnchorStyles]::Right
    $button1.Margin = 20
    $button1.Location = New-Object Drawing.Point 20,40
    $rebootForm.Controls.Add($button1)

    ## Timer
    $Timer = New-Object System.Windows.Forms.Timer
    $Timer.Interval = 1000
    $script:countDown = 120

    $Timer.add_Tick({
        $Label.Text = "Your computer will reboot in 2 minutes to finish installing critical updates, please save all open files.`n`n$script:countDown seconds" + $textfield.text
        $global:countDown--
        IF($script:countDown -eq 0) {
            $rebootForm.Close()
        }
        $button1.add_click({
            $rebootForm.Close()
        })
    })


    $Timer.Start()
    $rebootForm.Controls.Add($Label)
    $rebootForm.ShowDialog() | Out-Null
    Write-Output "$Answer"
}
