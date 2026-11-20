extends MoodBehavior
## 画画：前台是画画软件，且持续 enter_after 秒，就开始画画；
## 离开软件超过 exit_after 秒，或人走开（空闲超过 away_after 秒）就停
## 心情：最近 undo_window 秒内 Ctrl+Z 达到 undo_count 次就生气（疯狂撤销），停止撤销 angry_hold 秒后恢复；
## 连续画太久就疲倦

@export var monitor: ActivityMonitor  ## 提供前台程序名、空闲时间和撤销次数
## 画画软件的进程名（小写、不带 .exe），可在检查器里增删
@export var apps: PackedStringArray = [
	"photoshop", "clipstudiopaint", "sai", "sai2", "krita",
	"medibangpaintpro", "firealpaca", "illustrator", "aseprite",
]
@export var enter_after := 2  ## 在画画软件里待几秒才开始（防止 Alt+Tab 一晃而过）
@export var exit_after := 3  ## 离开软件几秒才停（切出去看参考图不会立刻退出）
@export var away_after := 60.0  ## 空闲超过多少秒算人走开了
@export var undo_window := 10  ## 统计最近几秒的撤销次数
@export var undo_count := 5  ## 这几秒内撤销几次算“疯狂撤销”（生气）

var _in := 0  # 已连续几秒在画画软件里
var _out := 0  # 已连续几秒不在
var _drawing := false
var _undos: Array[int] = []  # 最近 undo_window 秒每秒的撤销次数


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


func wants_active() -> bool:
	return requested or _drawing


# 每秒检查一次前台程序和撤销次数
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

	_undos.append(monitor.undos)
	if _undos.size() > undo_window:
		_undos.pop_front()
	var total := 0
	for n in _undos:
		total += n
	# 只有这一秒还在撤销、且最近累计够次数，才算（继续）生气；停手后保持 angry_hold 秒就恢复
	tick_mood(_drawing, _drawing and monitor.undos > 0 and total >= undo_count)
