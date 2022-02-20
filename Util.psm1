<#* 读取路径为 $path 的文件，返回字符串 *#>
function ReadFile($path) {
  return (Get-Content -Raw -Encoding "UTF8NoBOM" -Path "$path" )
}

<#* 将字符串 $content 写入路径为 $path 的文件 *#>
function WriteFile($path, $content) {
  Set-Content -Encoding "UTF8NoBOM" -Path "$path" -Value $content
}

<#* 读取路径为 $path 的JSON文件，返回对象 *#>
function ReadJsonFile($path) {
  $content = ReadFile $path
  if ($null -eq $content) {
    return @{}
  }
  return ConvertFrom-Json -AsHashtable -InputObject $content 
}

<#* 将对象 $obj 转换为JSON格式，写入路径为 $path 的文件 *#>
function WriteJsonFile($path, $obj) {
  $content = ConvertTo-Json -Depth 100 $obj
  WriteFile $path $content
}

<#* 统计文件行数，-ReadCount参数的取值影响统计速度和消耗内存 *#>
<#* 参考：https://www.codenong.com/12084642/ *#>
function CountLine($path){
  $cnt = 0
  Get-Content -Path $path -ReadCount 500 |% { $cnt += $_.Count }
  return $cnt
}

<#* 获取文件大小（单位：字节） *#>
function GetSize($path){
  return (Get-ChildItem $path).Length
}

$timeFormat = "yyyy/MM/dd HH:mm:ss.fffffff"
<#* 返回当前距 $time（$timeFormat 格式） 过去了多少秒 *#>
function TimeCalc($time) {
  $spanObj = New-TimeSpan $([System.DateTime]::ParseExact($time, $timeFormat, $null)) $([System.DateTime]::Now)
  return $spanObj.TotalSeconds
}

<#* 将相对路径转为 String 类型的绝对路径，即使是不存在的文件也行 *#>
<#* 参考：https://www.jb51.net/article/53423.htm *#>
function AbslPath($path) {
  return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$path")
}

<#* 返回当前时间的字符串形式，格式由 $timeFormat 决定 *#>
function TimeStr() {
  return Get-Date -Format $timeFormat
}