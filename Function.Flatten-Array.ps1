<#
  .DESCRIPTION
  Recursively flattens input array

  .EXAMPLE
  $deepArray = @('val1', @('val2', @('val3', 'val4'), '', 'val5'), $Null, 'val6')
  Flatten-Array $deepArray

  # Outputs -> @(val1, val2, val3, val4, val5, val6)
#>

function Flatten-Array {
  Param(
    [Parameter(Position = 0)]
    [array]
    $InputArray
  )

  Return $InputArray | ForEach-Object {
    If ($_ -is [array]) {
      Return Flatten-Array $_
    } Else {
      Return $_
    }
  }
}
