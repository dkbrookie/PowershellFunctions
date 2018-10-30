
## This is a concept, DOESN'T WORK YET

Function Download-Status {
  ## Path to report on
  $path = "https://support.dkbinnovative.com/labtech/Transfer/OS/Windows10/Prox64.1803.zip"

  [reflection.assembly]::loadwithpartialname("System.Windows.Forms") | Out-Null
  Add-Type -assembly System.Windows.Forms

  ## Title for the winform
  $Title = "Donwload Status: $Path"
  ## Winform dimensions
  $height = 100
  $width = 400
  ## Winform background color
  $color = "White"

  ## Create the form
  $form1 = New-Object System.Windows.Forms.Form
  $form1.Text = $title
  $form1.Height = $height
  $form1.Width = $width
  $form1.BackColor = $color

  $form1.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
  #$ Display center screen
  $form1.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

  ## Create label
  $label1 = New-Object system.Windows.Forms.Label
  $label1.Text = "Not started"
  $label1.Left =5
  $label1.Top = 10
  $label1.Width = $width - 20
  #Adjusted height to accommodate progress bar
  $label1.Height =15
  $label1.Font = "Roboto"

  #Add the label to the form
  $form1.controls.add($label1)

  $progressBar1 = New-Object System.Windows.Forms.ProgressBar
  $progressBar1.Name = 'progressBar1'
  $progressBar1.Value = 0
  $progressBar1.Style="Continuous"

  $System_Drawing_Size = New-Object System.Drawing.Size
  $System_Drawing_Size.Width = $width - 40
  $System_Drawing_Size.Height = 20
  $progressBar1.Size = $System_Drawing_Size

  $progressBar1.Left = 5
  $progressBar1.Top = 40

  $form1.Controls.Add($progressBar1)
  $form1.Show()| out-null

  ## Give the form focus
  $form1.Focus() | out-null

  ## Update the form
  $label1.text="Preparing to analyze $path"
  $form1.Refresh()

  start-sleep -Seconds 1

  ## Run code and update the status form

  ## Get top level folders
  $top = Get-ChildItem -Path $path -Directory

  ## Initialize a counter
  $i=0
}
