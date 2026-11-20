class_name ActivityMonitor
extends Node
## 活动检测：后台运行 PowerShell 助手（tools/activity_monitor.ps1），每秒读取一次系统状态。
## 各分类脚本从这里取数据，例如 Sleep 读取 idle_seconds。

const SCRIPT := "res://tools/activity_monitor.ps1"
const RUN_PATH := "user://activity_monitor.ps1"

signal updated  ## 每收到一次新数据（约每秒）发出

var idle_seconds := 0.0  ## 距离用户上次操作键盘/鼠标过了多少秒
var keys := 0  ## 过去约 1 秒按了几次键
var app := ""  ## 前台程序进程名（小写、不带 .exe），如 photoshop
var sound: Array = []  ## 正在出声的程序进程名，如 ["cloudmusic"]
var path := ""  ## 前台程序 exe 的完整路径（小写）
var fullscreen := false  ## 是否处于 D3D 独占全屏
var shots := 0  ## 过去约 1 秒剪贴板里出现了几次新图片（截屏）
var battery := -1  ## 电量百分比，没有电池为 -1
var charging := true  ## 是否插着电源

var _pid := -1
var _thread: Thread


func _ready() -> void:
	# 先复制到 user://：导出后 res:// 里的文件在 .pck 中，外部程序读不到
	var source := FileAccess.get_file_as_bytes(SCRIPT)
	if source.is_empty():
		push_warning("找不到活动检测脚本：" + SCRIPT)
		return
	var file := FileAccess.open(RUN_PATH, FileAccess.WRITE)
	file.store_buffer(source)
	file.close()

	# 启动助手，把本进程 ID 传过去，桌宠意外退出时助手也会自己结束
	var info := OS.execute_with_pipe("powershell.exe", [
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", ProjectSettings.globalize_path(RUN_PATH), str(OS.get_process_id()),
	])
	if info.is_empty():
		push_warning("活动检测助手启动失败")
		return
	_pid = info.pid
	_thread = Thread.new()
	_thread.start(_read_loop.bind(info.stdio))


# 后台线程：逐行阻塞读取助手输出，不会卡住画面
func _read_loop(stdio: FileAccess) -> void:
	while stdio.is_open() and stdio.get_error() == OK:
		var line := stdio.get_line()
		if line.begins_with("{"):
			_apply.call_deferred(JSON.parse_string(line))


# 回到主线程更新数据
func _apply(data: Variant) -> void:
	if data is Dictionary:
		idle_seconds = data.get("idle", 0.0)
		keys = int(data.get("keys", 0))
		app = data.get("app", "")
		sound = data.get("sound", [])
		path = data.get("path", "")
		fullscreen = data.get("fullscreen", false)
		shots = int(data.get("shots", 0))
		battery = int(data.get("battery", -1))
		charging = data.get("charging", true)
		updated.emit()


# 桌宠关闭时结束助手进程
func _exit_tree() -> void:
	if _pid > 0:
		OS.kill(_pid)
	if _thread:
		_thread.wait_to_finish()
