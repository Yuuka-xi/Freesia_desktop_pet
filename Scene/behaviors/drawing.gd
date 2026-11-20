extends PetBehavior
## 画画：前台是画画软件，且持续 enter_after 秒，就开始画画；
## 离开软件超过 exit_after 秒，或人走开（空闲超过 away_after 秒）就停

@export var monitor: ActivityMonitor  ## 提供前台程序名和空闲时间
## 画画软件的进程名（小写、不带 .exe），可在检查器里增删
@export var apps: PackedStringArray = [
	"photoshop", "clipstudiopaint", "sai", "sai2", "krita",
	"medibangpaintpro", "firealpaca", "illustrator", "aseprite",
]
@export var enter_after := 2  ## 在画画软件里待几秒才开始（防止 Alt+Tab 一晃而过）
@export var exit_after := 3  ## 离开软件几秒才停（切出去看参考图不会立刻退出）
@export var away_after := 60.0  ## 空闲超过多少秒算人走开了

var _in := 0  # 已连续几秒在画画软件里
var _out := 0  # 已连续几秒不在
var _drawing := false


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


func wants_active() -> bool:
	return requested or _drawing


# 每秒检查一次前台程序
func _on_monitor_updated() -> void:
	var hit := monitor.app in apps and monitor.idle_seconds < away_after
	if hit:
		_in += 1
		_out = 0
	else:
		_out += 1
		_in = 0
	if not _drawing and _in >= enter_after:
		_drawing = true
	elif _drawing and _out >= exit_after:
		_drawing = false
