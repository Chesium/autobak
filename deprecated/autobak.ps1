# Invoke-Command -ScriptBlock {fsutil fsinfo drives}
$te = fsutil fsinfo drives
Write-Host $te