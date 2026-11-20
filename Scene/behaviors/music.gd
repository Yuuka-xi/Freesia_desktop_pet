extends PetBehavior
## 听音乐：名单里的音乐软件持续出声 enter_after 秒就开始，静音超过 exit_after 秒才停
## 播放器在后台、最小化都能检测；人走开也继续听歌

@export var monitor: ActivityMonitor  ## 提供正在出声的程序列表
## 音乐软件的进程名（小写、不带 .exe），可在检查器里增删
@export var apps: PackedStringArray = [
	"cloudmusic", "qqmusic", "kugou", "kwmusic", "spotify",
	"applemusic", "foobar2000", "musicbee", "aimp",
]
@export var enter_after := 3  ## 持续出声几秒才开始
@export var exit_after := 5  ## 静音几秒才停（切歌时的短暂停顿不会退出）

var _on := 0  # 已连续几秒在放歌
var _off := 0  # 已连续几秒没放
var _playing := false


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)


func wants_active() -> bool:
	return requested or _playing


# 每秒检查一次：出声的程序里有没有音乐软件
func _on_monitor_updated() -> void:
	var hit := false
	for name in monitor.sound:
		if name in apps:
			hit = true
			break
	if hit:
		_on += 1
		_off = 0
	else:
		_off += 1
		_on = 0
	if not _playing and _on >= enter_after:
		_playing = true
	elif _playing and _off >= exit_after:
		_playing = false
