extends PetBehavior
## 截屏：剪贴板里出现新图片就播一遍拍照动作，播完回到原来的状态
## （Win+Shift+S、微信/QQ 截图、Snipaste 复制等都会放进剪贴板）
## 前台是 ignore_apps 里的程序时忽略（如在 PS 里 Ctrl+C 复制选区）

@export var monitor: ActivityMonitor  ## 提供截屏次数和前台程序
## 这些程序在前台时，剪贴板出现图片不算截屏（小写、不带 .exe）
@export var ignore_apps: PackedStringArray = [
	"photoshop", "clipstudiopaint", "sai", "sai2", "krita",
	"medibangpaintpro", "firealpaca", "illustrator", "aseprite",
]


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


# 每秒检查一次：有新截图就上场；正在播时又截了一张，就从头再播
func _on_monitor_updated() -> void:
	if monitor.shots <= 0 or monitor.app in ignore_apps:
		return
	if pet.current == self:
		frame = 0
		play()
	else:
		request()
