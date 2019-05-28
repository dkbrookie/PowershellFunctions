## Clear out all variables / hash tables before starting the script
Remove-Variable * -ErrorAction SilentlyContinue; Remove-Module *; $error.Clear(); Clear-Host

Function YesNo-Popup {
  <#
    .SYNOPSIS
    YesNo-Popup

    .DESCRIPTION
    YesNo-Popup allows you to define a custom title, message, background, custom buttons, and start a reboot for a popup to the end
    user by defining the -Title, -Message, -Option1, -Option2, -BackgroundImage, and -RebootOnYes parameters.

    .PARAMETER Message
    Define the message you want to display to the end user here. Keep in mind if you want to use multiple lines, you have to start
    each new line with `n (not this is the key next to the number 1 key and not a single quote)

    .PARAMETER Title
    Define the title of the popup window here. If not specified, this will be "DKBInnovative"

    .PARAMETER Option1
    Define what the first button option will be on the popup. Keep in mind that whatever your button says is exactly what the output
    will be if the user clicks that button. So if Option1 = "WOOHOO!" and the user clicks Option2, then the output of the popup to
    your console will be "WOOHOO!". The default option will be "Yes" unless this parameter is specified.

    .PARAMETER Option2
    Define what the second button option will be on the popup. Keep in mind that whatever your button says is exactly what the output
    will be if the user clicks that button. So if Option2 = "WOOHOO!" and the user clicks Option2, then the output of the popup to
    your console will be "WOOHOO!". The default option will be "No" unless this parameter is specified.

    .PARAMETER BackgroundImage
    Allows you to set a custom background image on the popup. Fill in this parameter with the direct URL to a custom image-- generally
    a PNG with a transparent background works best. Th0e image should be ~190px wide and 75px tall. Variations of those sizes
    will be fine if they're at least close.

    .PARAMETER RebootOnYes
    Fill out this parameter with 'Yes' or 'No'. If 'Yes', the machine will be auto rebooted with a 5min warning for the user to save
    their files IF they click "Yes" from the popup. If 'No', the script will just output the answer to $Option1 or $Option2.

    .EXAMPLE
    C:\PS> YesNo-Popup -Message "This is my message to display on the popup" -Title "Custom title here"
    C:\PS> YesNo-Popup -Message "This is an example of how to use`nMultiple lines separated by using a backtick`nwhich is next to the
    1 key"
    C:\PS> YesNo-Popuyp -Message "This is the message that will be displayed to the user" -Option1 HI -Option2 BYE
    C:\PS> YesNo-Popuyp -Message "This is the message that will be displayed to the user" -BackgroundImage
    "https://yourdomain.com/animage.png"
    C:\PS> YesNo-Popuyp -Message "This is the message that will be displayed to the user" -RebootOnYes Yes
    In CMD: powershell.exe -command "& {(new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/dkbrookie/PowershellFunctions/master/Function.YesNo-Popup.ps1') | iex ; YesNo-Popup -Title 'DKBInnovative' -Message 'Your machine is pending a reboot, okay to reboot now?'}"
  #>

  [CmdletBinding()]

  Param(
      [Parameter(Mandatory = $True)]
      [string]$Message,
      [string]$Title,
      [string]$Option1,
      [string]$Option2,
      [string]$BackgroundImage,
      [string]$RebootOnYes
  )

  If(!$BackgroundImage) {
    $BackgroundImage = "https://support.dkbinnovative.com/labtech/transfer/assets/dkblogo.png"
  }

  $bgImage = "$env:windir\LTSvc\logo.png"
  If(!(Test-Path $bgImage -PathType Leaf)) {
    (New-Object System.Net.WebClient).DownloadFile($BackgroundImage,$bgImage)
  }

  If(!$Message) {
    $Message = "No message was specified"
  }

  If(!$Title) {
    $Title = "DKBInnovative"
  }

  If(!$Option1) {
    $Option1 = "Yes"
  }

  If(!$Option2) {
    $Option2 = "No"
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
  $Label.Text = $message

  #region Button1
  $button1 = new-object System.Windows.Forms.Button
  $button1.Text = $Option1
  $button1.AutoSize = $True
  $button1.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $button1.Anchor = [System.Windows.Forms.AnchorStyles]::Right
  $button1.Margin = 20
  $button1.Location = New-Object Drawing.Point -40,40
  $rebootForm.Controls.Add($button1)

  ## Timer
  $Timer = New-Object System.Windows.Forms.Timer
  $Timer.Interval = 1000
  $script:countDown = 120

  ## Button 1 action
  $button1.add_click({
    If($RebootOnYes -eq 'Yes') {
      shutdown /r /f /c "Preparing to restart your machine to complete critical Windows patching. Please save your work!" /t 120
      $Timer.add_Tick({
        $Label.Text = "Your computer will reboot in 2 minutes, please save all open files.`n`n$script:countDown seconds" + $textfield.text
        $script:countDown--
        IF($script:countDown -eq 0) {
          $rebootForm.Close()
        }
      })
    } Else {
      $global:Answer = $Option1
      $rebootForm.Close()
    }
  })
  #endregion Button1

  #region Button2
  $button2 = new-object System.Windows.Forms.Button
  $button2.Text = $Option2
  $button2.AutoSize = $True
  $button2.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $button2.Anchor = [System.Windows.Forms.AnchorStyles]::Right
  $button2.Margin = 20
  $button2.Location = New-Object Drawing.Point ($button1.Location.X + 80),($button1.Location.Y)
  $rebootForm.Controls.Add($button2)

  ## Button 2 action
  $button2.add_click({
    $global:Answer = $Option2
    $rebootForm.Close()
  })
  #endregion Button2

  $Timer.Start()
  $rebootForm.Controls.Add($Label)
  $rebootForm.ShowDialog() | Out-Null
  Write-Output "$Answer"
}
