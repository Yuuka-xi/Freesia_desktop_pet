extends PetBehavior
## 休眠：用户离开超过 sleep_after 秒就睡觉，回来（动鼠标或键盘）自动醒
## 入睡时从本分类里任选一个动作循环播放

@export var monitor: ActivityMonitor  ## 提供“离开了多久”
@export var sleep_after := 300.0  ## 离开多少秒后入睡


# 离开够久就想睡；也可以用调试键 request() 强制入睡（点一下就醒）
func wants_active() -> bool:
	return requested or monitor.idle_seconds >= sleep_after
