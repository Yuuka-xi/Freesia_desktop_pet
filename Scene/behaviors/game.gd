extends PetBehavior
## 打游戏：前台程序满足任一规则并持续 enter_after 秒就开始，离开超过 exit_after 秒才停
## 规则：①exe 在游戏库目录里 ②进程名在游戏名单里 ③D3D 独占全屏
## 排除名单优先：命中排除名单的程序（如装在 Steam 里的 Godot）永远不算游戏
## 不按空闲时间判断人走开（手柄操作、看过场动画时都不碰键鼠）

@export var monitor: ActivityMonitor  ## 提供前台程序信息
## ① exe 路径包含这些片段就算游戏（小写，用 \\ 表示反斜杠）
@export var path_keywords: PackedStringArray = [
	"\\steamapps\\common\\",  # Steam
	"\\epic games\\",  # Epic
	"\\wegameapps\\",  # WeGame
	"\\ea games\\",  # EA App
	"\\ubisoft game launcher\\games\\",  # Ubisoft Connect
	"\\gog galaxy\\games\\",  # GOG
	"\\xboxgames\\",  # Xbox / Game Pass
	"\\riot games\\",  # 英雄联盟、无畏契约
]
## ② 进程名在名单里就算游戏（小写、不带 .exe）
@export var apps: PackedStringArray = [
	"yuanshen", "genshinimpact",  # 原神
	"starrail",  # 崩坏：星穹铁道
	"zenlesszonezero",  # 绝区零
	"bh3",  # 崩坏3
	"league of legends", "valorant-win64-shipping",
]
## ③ 是否把 D3D 独占全屏也算作游戏
@export var use_fullscreen := true
## 进程名包含这些片段的永远不算游戏（装在游戏库里的工具、启动器等）
@export var exclude: PackedStringArray = [
	"godot", "unity", "unrealeditor", "blender", "aseprite", "krita",
	"wallpaper", "obs64", "steamwebhelper", "epicgameslauncher", "riotclient",
]
@export var enter_after := 3  ## 在游戏里待几秒才开始
@export var exit_after := 5  ## 离开游戏几秒才停

var _in := 0  # 已连续几秒在游戏里
var _out := 0  # 已连续几秒不在
var _gaming := false


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


func wants_active() -> bool:
	return requested or _gaming


# 前台程序是不是游戏
func is_game(app: String, path: String, fullscreen: bool) -> bool:
	for word in exclude:
		if word in app:
			return false
	if app in apps or (use_fullscreen and fullscreen):
		return true
	for word in path_keywords:
		if word in path:
			return true
	return false


# 每秒检查一次前台程序
func _on_monitor_updated() -> void:
	if is_game(monitor.app, monitor.path, monitor.fullscreen):
		_in += 1
		_out = 0
	else:
		_out += 1
		_in = 0
	if not _gaming and _in >= enter_after:
		_gaming = true
	elif _gaming and _out >= exit_after:
		_gaming = false
