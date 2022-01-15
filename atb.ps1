$diskListJsonPath = "x.json"
$logPath = "atb.log"
$timeFormat = "yyyy/MM/dd HH:mm:ss.fffffff"
$fztime = 10.0
$slptime = 500.0
$evtInctName = "U"
$efuPath = "efu"
function ReadFile($path) {
  return (Get-Content -Raw -Encoding "UTF8NoBOM" -Path "$path" )
}
function WriteFile($path, $content) {
  Set-Content -Encoding "UTF8NoBOM" -Path "$path" -Value $content
}
function ReadJsonFile($path) {
  $content = ReadFile $path
  if ($null -eq $content) {
    return @{}
  }
  return ConvertFrom-Json -AsHashtable -InputObject $content 
}
function WriteJsonFile($path, $obj) {
  $content = ConvertTo-Json  -Depth 10 $obj
  WriteFile  $path $content
}
function TimeCalc($time) {
  $spanObj = New-TimeSpan $([System.DateTime]::ParseExact($time, $timeFormat, $null)) $([System.DateTime]::Now)
  return $spanObj.TotalSeconds
}
function TimeStr() {
  return Get-Date -Format $timeFormat
}

function AddDisk($d) {
  $id = $d.SerialNumber
  $vol = $d  | Get-Partition | Get-Volume
  $let = $vol.DriveLetter
  $name = $vol.FileSystemLabel
  Log -s "Update Disk ($let`:/) ID:[$id] `"$name`""
  $excTime = Measure-Command {
    Everything.exe -instance $evtInctName -create-file-list $efuPath\$id.efu $let`:\
  }
  Log -s "Create EFU file $(Resolve-Path $efuPath\$id.efu) using $($excTime.TotalMilliseconds)ms"
  $hash[$id] = @{
    Letter  = $let;
    Name    = $name;
    AddTime = TimeStr
  }
  WriteJsonFile -path $diskListJsonPath -obj $hash
}
function Log($s) {
  Write-Output "[$(TimeStr)]$s" >> $logPath
}



Log -s "LAUNCH"
if ((Test-Path $diskListJsonPath) -ne "True") {
  New-Item $diskListJsonPath
  Log -s "Create $(Resolve-Path $diskListJsonPath)"
}
if ((Test-Path $efuPath) -ne "True") {
  mkdir $efuPath
  Log -s "Create $(Resolve-Path $efuPath)"
}
$hash = (ReadJsonFile -path $diskListJsonPath )
While (1) {
  $time = TimeStr
  $Disks = Get-Disk | Where-Object -FilterScript { $_.Bustype -Eq "USB" }
  Write-Host ">$time"
  foreach ($d in $Disks) {
    $id = $d.SerialNumber
    if ($null -eq $hash[$id]) {
      AddDisk -d $d
    }
    elseif ((TimeCalc -time $hash[$id].AddTime) -gt $fztime) {
      AddDisk -d $d
    }
  }
  Start-Sleep –m $slptime
}