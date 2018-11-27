Function Get-Tree($Path,$Include='*') {
  @(Get-Item $Path -Include $Include -Force) +
    (Get-ChildItem $Path -Recurse -Include $Include -Force) | Sort PSPath -Descending -Unique
}

Function Remove-Tree($Path,$Include='*') {
  Get-Tree $Path $Include | Remove-Item -Force -Recurse
}
