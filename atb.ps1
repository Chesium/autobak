Import-Module .\Util.psm1
Import-Module .\WaitUntilEvtLaunch.psm1
Import-Module .\GenNeedCopyList.psm1

<#* 存储已处理磁盘信息的JSON文件路径 *#>
$diskListJsonPath = "__x.json"
<#* 日志文件路径 *#>
$logPath = "__atb.log"
<#* 再次更新同一磁盘的冷却时间，单位为秒 *#>
$fztime = 10.0
<#* 每次尝试更新间的间隔时间，单位为毫秒 *#>
$slptime = 500.0
<#* 用于生成磁盘文件列表（EFU格式）的EVT实例名 *#>
$evtInctName = "Te"
<#* 磁盘文件列表（EFU格式）存放目录 *#>
$efuPath = "__efu"
<#* 目标文件列表存放目录 *#>
$efupath2 = "__targets"
<#* 目标文件存放目录 *#>
$destpath = "__dest"

<#* 将信息写入日志文件（带时间） *#>
function Log($s) {
  Write-Output "[$(TimeStr)]$s" >> $logPath
}

<#* 主函数：添加/更新磁盘 *#>
function AddDisk($d) {
  <#* $id：磁盘序列号 *#>
  $id = $d.SerialNumber
  <#* $vol：卷对象 *#>
  $vol = $d  | Get-Partition | Get-Volume
  <#* 其形如下表：
     DriveLetter    FriendlyName  FileSystemType DriveType HealthStatus
  ----------------- ------------- -------------- --------- ------------
          E            ******         FAT32      Removable   Healthy   

  OperationalStatus SizeRemaining      Size
  ----------------- ------------- --------------
          OK           **.** GB      **.** GB
  #>
  <#* $letter：盘符 *#>
  $letter = $vol.DriveLetter
  <#* $vol_name：卷标（盘名） *#>
  $vol_name = $vol.FileSystemLabel
  <##> Log -s "Update Disk ($letter`:/) ID:[$id] `"$vol_name`""
  <#* 若无哈希表则新建 *#>
  if ($null -eq $hash[$id]) {
    $hash[$id] = @{
      Letter  = $letter;
      Name    = $vol_name;
      AddTime = TimeStr;
      targets = @{}
    }
  }
  else {
    <#* 哈希表已存在，更新 AddTime *#>
    $hash[$id].AddTime = TimeStr
  }
  <#* 保存哈希表至JSON文件 *#>
  WriteJsonFile -path $diskListJsonPath -obj $hash
  <#* 使用指定EVT实例生成整个磁盘的文件列表（EFU格式） *#>
  $excTime = Measure-Command {
    Everything.exe -instance $evtInctName -create-file-list $efuPath\$id.efu $letter`:\
    do {} until((Test-Path $efuPath\$id.efu) -eq $true)
  }
  <##> Log -s "Create EFU file using $($excTime.TotalMilliseconds)ms: $(AbslPath $efuPath\$id.efu)"
  $excTime = Measure-Command {
    GenNeedCopyList -efu "$efuPath\$id.efu" -filter "ext:xlsx" -o "$efuPath2\$id"
  }
  <##> Log -s "Gen targets list using $($excTime.TotalMilliseconds)ms: $(AbslPath $efuPath2\$id)"
  if ((Test-Path $destpath\$id) -ne "True") {
    mkdir $destpath\$id
    # <##> Log -s "Create $(AbslPath $destpath\$id)"
  }
  $lineN = CountLine -path $efuPath2\$id
  <##> Log -s "Begin copying $($lineN) files"
  $reader = New-Object System.IO.StreamReader("$efuPath2\$id")
  $cnt = 1
  while ($null -ne ($line = $reader.ReadLine()) ) {
    $name = Split-Path $line -Leaf -Resolve
    $size = GetSize $line
    <##> Log -s "Processing [$cnt/$lineN] size:$size `"$name`""

    # Write-Host $name
    # Write-Host (ConvertTo-Json -Depth 5 $hash)
    if ($null -eq $hash[$id].targets[$name]) {
      <##> Log -s "It's new!"
      mkdir $destpath\$id\$name
      $base_path = AbslPath $destpath\$id\$name\$name
      $excTime = Measure-Command { Copy-Item $line $destpath\$id\$name }
      <##> Log -s "Copying using $($excTime.TotalMilliseconds)ms: $base_path"
      $hash[$id].targets[$name] = @{
        AddTime  = TimeStr;
        path     = $line;
        BasePath = $base_path;
        upd      = @()
      }
    }
    else {
      <##> Log -s "Déjà vu!"
      $patch_index = $hash[$id].targets[$name].upd.Length + 1
      $patch_path = AbslPath $destpath\$id\$name\patch$patch_index
      $excTime = Measure-Command { bsdiff $hash[$id].targets[$name].BasePath $line $patch_path }
      <##> Log -s "Gen Patch using $($excTime.TotalMilliseconds)ms: $patch_path"
      $hash[$id].targets[$name].upd += @{
        AddTime   = TimeStr;
        path      = $line;
        PatchPath = $patch_path
      }
    }
    $cnt ++
    WriteJsonFile -path $diskListJsonPath -obj $hash
  }
  $reader.Dispose()
}

<#*## #### #### ####
 #*    程序入口    *#
 #*## #### #### ####>

<##> Log -s "LAUNCH"
<#*#: 检查各个目录是否存在，若无，则新建 #>
if ((Test-Path $diskListJsonPath) -ne "True") {
  New-Item $diskListJsonPath
  <##> Log -s "Create $(AbslPath $diskListJsonPath)"
}
if ((Test-Path $efuPath) -ne "True") {
  mkdir $efuPath
  <##> Log -s "Create $(AbslPath $efuPath)"
}
if ((Test-Path $efupath2) -ne "True") {
  mkdir $efupath2
  <##> Log -s "Create $(AbslPath $efupath2)"
}

<#* 从JSON文件中读取已处理磁盘信息哈希表 *#>
$hash = (ReadJsonFile -path $diskListJsonPath)

<#*## #### #### ####
 #*     主循环     *#
 #*## #### #### ####>

While (1) {
  <#* 获取USB磁盘列表 *#>
  $Disks = Get-Disk | Where-Object -FilterScript { $_.Bustype -Eq "USB" }
  <#* 获取到的列表形如：
  Number Friendly Name SerialNumber HealthStatus OperationalStatus TotalSize Partition
  ------ ------------- ------------ ------------ ----------------- --------- ---------
     2     Kingston…   ************    Healthy        Online        **.** GB    MBR
  #>
  <#DEBUG#> Write-Host "$(TimeStr)"
  foreach ($d in $Disks) {
    <#* 获取磁盘序列号 *#>
    $id = $d.SerialNumber
    <#* 若此序列号从未添加过，则添加该磁盘 *#>
    if ($null -eq $hash[$id]) {
      AddDisk -d $d
    }<#* 若此序列号曾添加过，但更新冷却时间已过，那也添加（更新）该磁盘 *#>
    elseif ((TimeCalc -time $hash[$id].AddTime) -gt $fztime) {
      AddDisk -d $d
    }
  }
  <#* 尝试更新间的冷却 *#>
  Start-Sleep -m $slptime
}