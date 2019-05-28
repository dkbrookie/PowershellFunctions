Function OK-Popup {
    <#
    .SYNOPSIS
    OK-Popup

    .DESCRIPTION
    YesNo-Popup allows you to define a custom title and message for a popup to the end user by defining the `-Message` and `-Title`
    parameters. You can also chagne what the button says by defining the -Option1 parameter.

    .PARAMETER Message
    Define the message you want to display to the end user here. Keep in mind if you want to use multiple lines, you have to start
    each new line with `n (not this is the key next to the number 1 key and not a single quote)

    .PARAMETER Title
    Define the title of the popup window here. If not specified, this will be "DKBInnovative"

    .PARAMETER Option1
    Define what the button will say on the popup. Keep in mind that whatever your button says is exactly what the output will be if
    the user clicks that button. So if Option1 = "WOOHOO!" and the user clicks Option2, then the output of the popup to your console
    will be "WOOHOO!". The default value is "OK" unless defined in this parameter

    .PARAMETER RebootNotification
    Allows you to specify if this is a reboot notification. If this is set to $True, the users machine will start a count down to reboot
    in 2 minutes. The prompt will have count down, and the user will also receieve some built in Windows reboot notifications on their
    screen.

    .EXAMPLE
    C:\PS> YesNo-Popup -Message "This is my message to display on the popup" -Title "Custom title here"
    C:\PS> YesNo-Popup -Message "This is an example of how to use`nMultiple lines separated by using a backtick`nwhich is next to the 1 key"
    C:\PS> YesNo-Popuyp -Message "This is the message that will be displayed to the user" -Option1 HI
    #>

    [CmdletBinding()]

    Param(
        [Parameter(Mandatory = $True)]
        [string]$Message,
        [string]$Title,
        [string]$Option1,
        [string]$RebootNotification
    )

    $psIcon = "https://drive.google.com/uc?export=download&id=1eNCta3hRYErNI2_Q8Wyu-C034-25cjUM"
    $imgUrl = "https://drive.google.com/uc?export=download&id=115V55-YXSvaPD6cuUQ_KzO0-SY8FSVW5"
    $bgImage = "$env:windir\LTSvc\dkblogo.png"
    If (!(Test-Path $bgImage -PathType Leaf)) {
        (New-Object System.Net.WebClient).DownloadFile($imgUrl,$bgImage)
    }#End If

    If (!$Message) {
        $Message = "No message was specified"
    }#End If

    If (!$Title) {
    $Title = "DKBInnovative"
    }#End If

    If (!$Option1) {
        $Option1 = "OK"
    }#End If

    # Load the Winforms assembly
    [reflection.assembly]::LoadWithPartialName( "System.Windows.Forms") | Out-Null
    Add-Type -AssemblyName System.Windows.Forms

    $Icon = [system.drawing.icon]::ExtractAssociatedIcon("C:\Windows\LTSvc\labTech.ico")
    $Background = [system.drawing.image]::FromFile($bgImage)
    $Font = New-Object System.Drawing.Font("Roboto",10,[System.Drawing.FontStyle]::Regular)
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

    $Label = New-Object System.Windows.Forms.Label
    $Label.AutoSize = $True
    $Label.BackColor = "Transparent"
    $Label.textAlign = "MiddleCenter"
    $Label.Dock = [System.Windows.Forms.DockStyle]::Top
    $Label.Anchor = [System.Windows.Forms.AnchorStyles]::Left
    $Label.Text = $message



    If(!$RebootNotification) {
        # Button 1
        $button1 = new-object System.Windows.Forms.Button
        $button1.Text = $Option1
        $button1.AutoSize = $True
        $button1.Dock = [System.Windows.Forms.DockStyle]::Bottom
        $button1.Anchor = [System.Windows.Forms.AnchorStyles]::Right
        $button1.Margin = 20
        $button1.Location = New-Object Drawing.Point 35,40
        $rebootForm.Controls.Add($button1)

        # Button 1 action
        $button1.add_click({
        $global:Answer = $Option1
        $rebootForm.Close()
        })
    } ELse {
        # Button 1
        $button1 = new-object System.Windows.Forms.Button
        $button1.Text = $Option1
        $button1.AutoSize = $True
        $button1.Dock = [System.Windows.Forms.DockStyle]::Bottom
        $button1.Anchor = [System.Windows.Forms.AnchorStyles]::Right
        $button1.Margin = 20
        $button1.Location = New-Object Drawing.Point 35,40
        $rebootForm.Controls.Add($button1)
        
        ## Timer
        $Timer = New-Object System.Windows.Forms.Timer
        $Timer.Interval = 1000
        $script:countDown = 120

        ## Button 1 action
        $button1.add_click({
            shutdown /r /f /c "Preparing to restart your machine to complete critical Windows patching. Please save your work!" /t 120
            $Timer.add_Tick({
                $Label.AutoSize = $True
                $Label.textAlign = "MiddleCenter"
                $Label.Dock = [System.Windows.Forms.DockStyle]::Top
                $Label.Anchor = [System.Windows.Forms.AnchorStyles]::Left
                $Label.Text = "Your computer will reboot in 2 minutes, please save all open files.`n`n$script:countDown seconds" + $textfield.text
                $script:countDown--
                IF($script:countDown -eq 0) {
                    $rebootForm.Close()
                }
            })
        })
        #endregion Button1
    }#End Else

    If($RebootNotification) {
        $Timer.Start()
    }
    $rebootForm.Controls.Add($Label)
    $rebootForm.ShowDialog() | Out-Null
    Write-Output "$Answer"
}
