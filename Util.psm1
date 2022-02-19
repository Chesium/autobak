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
  $content = ConvertTo-Json  -Depth 10 $obj
  WriteFile  $path $content
}

$timeFormat = "yyyy/MM/dd HH:mm:ss.fffffff"
<#* 返回当前距 $time（$timeFormat 格式） 过去了多少秒 *#>
function TimeCalc($time) {
  $spanObj = New-TimeSpan $([System.DateTime]::ParseExact($time, $timeFormat, $null)) $([System.DateTime]::Now)
  return $spanObj.TotalSeconds
}

<#* 返回当前时间的字符串形式，格式由 $timeFormat 决定 *#>
function TimeStr() {
  return Get-Date -Format $timeFormat
}