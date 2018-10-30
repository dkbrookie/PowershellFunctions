Function YesNo-Popup {
  <#
    .SYNOPSIS
    YesNo-Popup

    .DESCRIPTION
    YesNo-Popup allows you to define a custom title and message for a popup to the end user by defining the `-Message` and `-Title` parameters.DESCRIPTION

    .PARAMETER Message
    Define the message you want to display to the end user here. Keep in mind if you want to use multiple lines, you have to start each new line with `n (not this is the key next to the number 1 key and not a single quote)

    .PARAMETER Title
    Define the title of the popup window here. If not specified, this will be "DKBInnovative Notice"

    .EXAMPLE
    C:\PS> YesNo-Popup -Message "This is my message to display on the popup" -Title "Custom title here"
    C:\PS> YesNo-Popup -Message "This is an example of how to use`nMultiple lines separated by using a backtick`nwhich is next to the 1 key"
  #>
  [CmdletBinding()]

  Param(
      [Parameter(Mandatory = $True)]
      [string]$Message,
      [string]$Title
  )

  $imgUrl = "https://support.dkbinnovative.com/labtech/transfer/assets/dkblogo.png"
  $bgImage = "$env:windir\LTSvc\dkblogo.png"
  If(!(Test-Path $bgImage -PathType Leaf)) {
    Start-BitsTransfer -Source $imgUrl -Destination $bgImage
  }

  If(!$Message) {
    $Message = "No message was specified"
  }

  If(!$Title){
    $Title = "DKBInnovative Notice"
  }

  ##Load the Winforms assembly
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

  ##Button 1
  $button1 = new-object System.Windows.Forms.Button
  $button1.Text = "Yes"
  $button1.AutoSize = $True
  $button1.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $button1.Anchor = [System.Windows.Forms.AnchorStyles]::Right
  $button1.Margin = 20
  $button1.Location = New-Object Drawing.Point -40,40
  $rebootForm.Controls.Add($button1)
  ##Button 1 action
  $button1.add_click({
      $global:Answer = "Yes"
      $rebootForm.Close()
  })


  ##Button 2
  $button2 = new-object System.Windows.Forms.Button
  $button2.Text = "No"
  $button2.AutoSize = $True
  $button2.Dock = [System.Windows.Forms.DockStyle]::Bottom
  $button2.Anchor = [System.Windows.Forms.AnchorStyles]::Right
  $button2.Margin = 20
  $button2.Location = New-Object Drawing.Point ($button1.Location.X + 80),($button1.Location.Y)
  $rebootForm.Controls.Add($button2)
  ##Button 2 action
  $button2.add_click({
      $global:Answer = "No"
      $rebootForm.Close()
  })

  $rebootForm.Controls.Add($Label)
  $rebootForm.ShowDialog() | Out-Null
}

Trigger-Popup
Write-Output "$Answer"
