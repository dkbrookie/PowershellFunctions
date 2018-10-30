Function Trigger-Popup {
  Param($Message)

  If(!$msp) {
    $msp = "DKBInnovative"
  }

  $imgUrl = "https://support.dkbinnovative.com/labtech/transfer/assets/dkblogo.png"
  $bgImage = "$env:windir\LTSvc\dkblogo.png"
  If(!(Test-Path $bgImage -PathType Leaf)) {
    Start-BitsTransfer -Source $imgUrl -Destination $bgImage
  }

  ##Load the Winforms assembly
  [reflection.assembly]::LoadWithPartialName( "System.Windows.Forms") | Out-Null
  Add-Type -AssemblyName System.Windows.Forms

  $Icon = [system.drawing.icon]::ExtractAssociatedIcon("C:\Windows\LTSvc\labTech.ico")
  $Background = [system.drawing.image]::FromFile("C:\dkblogo.png")
  $Font = New-Object System.Drawing.Font("Roboto",10,[System.Drawing.FontStyle]::Regular)
  $rebootForm = New-Object system.Windows.Forms.Form
  $rebootForm.Text = $msp
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

Trigger-Popup -Message "Your machine is pending a restart to complete critical patching.`nPLEASE NOTE: The next reboot to your computer will install updates,`nplease plan accordingly.`n`nRestart now?"
Write-Output "$Answer"
