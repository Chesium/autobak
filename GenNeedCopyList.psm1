Import-Module .\WaitUntilEvtLaunch.psm1

# 生成只包含指定文件列表（路径为 $fl）的自定义EVT配置文件（不包含NTFS卷和其他文件夹）
# 采用拼接的方法
function __gen_ini($fl,$path){
  # 配置文件前半部分路径
  $evc1_path="res\evc1"
  # 配置文件后半部分路径
  $evc2_path="res\evc2"
  Copy-Item $evc1_path $path
  # 在两部分之间插入指定的文件列表路径
  Write-Output $fl >> $path
  Get-Content $evc2_path | Add-Content $path
}

# 从EFU文件（路径为 $efu）中筛选出符合 $filter 的文件，导出至 $o
# 通过启动一个自定义配置文件的EVT临时实例，用es来导出
function GenNeedCopyList($efu, $filter, $o) {
  ####配置#### #### #### ####
  # EVT临时配置文件存储路径     ##
  $__ini = "__evc.ini"      ##
  # 临时EVT实例名             ##
  $__inst = "XXX"           ##
  ####配置#### #### #### ####

  # 生成临时EVT配置文件
  __gen_ini -fl "$(Resolve-Path $efu)" -path $__ini
  # 静默启动临时EVT实例，使用刚刚生成的临时配置文件
  Everything -instance $__inst -reindex -startup -config $(Resolve-Path $__ini)
  # 暂停脚本，直到EVT成功启动
  WaitUntilEvtLaunch -instance $__inst
  # 删除临时配置文件。因为EVT退出时会重新生成一份配置文件
  # 不事先删除原先那份的话无法判断何时生成的新配置文件
  Remove-Item $__ini
  # 使用es导出目标文件列表
  es -instance $__inst $filter -sort-size-ascending -export-txt $o
  # 退出临时EVT实例
  Everything -instance $__inst -exit
  # 等候EVT退出时重新生成配置文件
  do {} until ((Test-Path $__ini) -eq $true)
  # 删除刚刚生成的配置文件，这时有可能该文件仍被EVT占用，所以重复删除至文件不存在
  do {Remove-Item $__ini 2> $null} until ((Test-Path $__ini) -eq $false)
}