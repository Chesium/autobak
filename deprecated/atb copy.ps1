$diskListJsonPath = "x.json"
$copiedHJsonPath = "cp.json"
$logPath = "atb.log"
$timeFormat = "yyyy/MM/dd HH:mm:ss.fffffff"
$fztime = 10.0
$slptime = 500.0
$evtIN = "U"
$efuPath = "efu"
$indexPath = "u.csv"
$evtiniPath = "evt.ini"
$bakPath = "bak"

$evtiniPrefix = "[Everything]`nauto_include_fixed_volumes=0`nauto_include_removable_volumes=0`nfilelists="

$global:len = 0
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

function Get-LineN() {
  [int]$LinesInFile = 0
  $reader = New-Object IO.StreamReader $indexPath
  while ($null -ne $reader.ReadLine()) { $LinesInFile++ }
  $reader.Close()
  return $LinesInFile
}

function FileName($s) {
  return Split-Path -Leaf $s
}

function AddDisk($d) {
  $id = $d.SerialNumber
  $vol = $d  | Get-Partition | Get-Volume
  $let = $vol.DriveLetter
  $name = $vol.FileSystemLabel
  Log -s "Update Disk ($let`:/) ID:[$id] `"$name`""

  $excTime = Measure-Command {
    Start-Process Everything.exe -Wait -PassThru -NoNewWindow -ArgumentList "-admin -instance $evtIN -create-file-list $efuPath\$id.efu $let`:\"
  }
  Log -s "Create EFU file $(Resolve-Path .)$efuPath\$id.efu using $($excTime.TotalMilliseconds)ms"

  WriteFile -path $evtiniPath -content "$evtiniPrefix`"$((Resolve-Path .).ToString().Replace("\","/"))/$efuPath/$id.efu`""
  $excTime = Measure-Command {
    Start-Process Everything.exe -Wait -PassThru -NoNewWindow -ArgumentList "-startup -admin -reindex -instance $evtIN -config $evtiniPath"
  }
  Log -s "Use Everything($evtIN) to open $efuPath\$id.efu using $($excTime.TotalMilliseconds)ms"
  
  $excTime = Measure-Command {
    do {
      $te = Start-Process es.exe -Wait -PassThru -NoNewWindow -ArgumentList "-instance $evtIN -date-modified -s ext:pptx -export-csv $indexPath -sort-size-ascending"
    } while ($te.ExitCode -ne 0)
  }
  Log -s "export txt using $($excTime.TotalMilliseconds)ms"

  $len = Get-LineN
  Log -s "Find $len file(s) in total."

  $reader = New-Object IO.StreamReader $indexPath
  $fileA = $reader.ReadLine().Split(",", 2)
  $modt = $fileA[0]
  $file = $fileA[1]
  [int]$i = 0
  $copied = @()
  [int]$copiedN = 0
  if ($null -ne $hash[$id]) {
    $copied = $hash[$id].copied
    $copiedN = $hash[$id].copiedN
  }
  while ($null -ne $file) {
    if ($null -ne $cp[(FileName -s $file)]) {
      if ($modt -eq $cp[(FileName -s $file)].modt) {
        Write-Host "Duplicate: $(FileName -s $file)"
        $fileA = $reader.ReadLine().Split(",", 2)
        $modt = $fileA[0]
        $file = $fileA[1]
        continue
      }
    }
    $i++
    Write-Host "Copying [$i/$len]"
    Copy-Item $file -Destination "$bakPath"
    $copied += $file
    $copiedN++
    $cp[(FileName -s $file)] = @{id = $id; modt = $modt }
    $fileA = $reader.ReadLine().Split(",", 2)
    $modt = $fileA[0]
    $file = $fileA[1]
  }
  $reader.Close()
  # Remove-Item $indexPath

  
  $hash[$id] = @{
    Letter  = $let;
    Name    = $name;
    AddTime = TimeStr
    copied  = $copied
    copiedN = $copiedN
  }
  WriteJsonFile -path $diskListJsonPath -obj $hash
  WriteJsonFile -path $copiedHJsonPath -obj $cp
}
function Log($s) {
  Write-Output "[$(TimeStr)]$s" >> $logPath
}



Log -s "LAUNCH"
if ((Test-Path $diskListJsonPath) -ne "True") {
  New-Item $diskListJsonPath
  Log -s "Create $(Resolve-Path $diskListJsonPath)"
}
if ((Test-Path $copiedHJsonPath) -ne "True") {
  New-Item $copiedHJsonPath
  Log -s "Create $(Resolve-Path $copiedHJsonPath)"
}
if ((Test-Path $efuPath) -ne "True") {
  mkdir $efuPath
  Log -s "Create $(Resolve-Path $efuPath)"
}
if ((Test-Path $bakPath) -ne "True") {
  mkdir $bakPath
  Log -s "Create $(Resolve-Path $bakPath)"
}
$global:hash = (ReadJsonFile -path $diskListJsonPath )
$global:cp = (ReadJsonFile -path $copiedHJsonPath )
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