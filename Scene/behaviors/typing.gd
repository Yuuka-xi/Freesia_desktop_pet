extends PetBehavior
## 打字：最近 window 秒内按键达到 threshold 次就开始打字，
## 连续 cooldown 秒没按键才停（防止偶尔按快捷键触发、停下思考时立刻切走）

@export var monitor: ActivityMonitor  ## 提供每秒按键数
@export var window := 5  ## 统计最近几秒的按键
@export var threshold := 8  ## 这几秒内按了几次键算在打字
@export var cooldown := 5  ## 连续几秒没按键就停止打字

var _history: Array[int] = []  # 最近 window 秒每秒的按键数
var _quiet := 0  # 已经连续几秒没按键
var _typing := false


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


func wants_active() -> bool:
	return requested or _typing


# 每秒收到一次按键数，更新是否在打字
func _on_monitor_updated() -> void:
	_history.append(monitor.keys)
	if _history.size() > window:
		_history.pop_front()
	_quiet = 0 if monitor.keys > 0 else _quiet + 1

	var total := 0
	for n in _history:
		total += n
	if not _typing and total >= threshold:
		_typing = true
	elif _typing and _quiet >= cooldown:
		_typing = false
