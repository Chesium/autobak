# 暂停脚本直到 Everything 实例 $instance 启动完成
# 一般用于启动 EVT 或使用其生成文件列表后
# 随后即可正常调用 es 或使用 EVT 生成的文件列表
function WaitUntilEvtLaunch($instance){
  # 使用 es.exe 搜索所有文件名+扩展名为空
  # ^$ "^" 是一行的开头 "$" 为一行的结尾
  # 文件名+扩展名必定只有一行且不为空（应该吧）所以 es -r ^$ 搜不出任何东西
  # 2> $null 会将错误输出忽略
  # 应该有更简单的方法实现，不过这样够了
  do {
    es -instance $instance -r ^$ 2> $null
  } until ($? -eq $true)
}