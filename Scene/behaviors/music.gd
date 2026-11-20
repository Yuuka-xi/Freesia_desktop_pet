extends PetBehavior
## 听音乐：名单里的音乐软件持续出声 enter_after 秒就开始，静音超过 exit_after 秒才停
## 播放器在后台、最小化都能检测；人走开也继续听歌
## 记住上一次听歌的动作：被戳一戳等打断后回来，或下次再听歌时，还是同一个动作
## 累计听满 switch_time 秒换一个（等当前这遍播完再换）；被打断期间不计时

@export var monitor: ActivityMonitor  ## 提供正在出声的程序列表
## 音乐软件的进程名（小写、不带 .exe），可在检查器里增删
@export var apps: PackedStringArray = [
	"cloudmusic", "qqmusic", "kugou", "kwmusic", "spotify",
	"applemusic", "foobar2000", "musicbee", "aimp",
]
@export var enter_after := 3  ## 持续出声几秒才开始
@export var exit_after := 5  ## 静音几秒才停（切歌时的短暂停顿不会退出）
@export var switch_time := 300.0  ## 累计听多少秒换一个动作（默认 5 分钟），0 表示不换

var _on := 0  # 已连续几秒在放歌
var _off := 0  # 已连续几秒没放
var _playing := false
var _started := false  # 是否已经抽过第一个听歌动作
var _elapsed := 0.0  # 当前听歌动作已经播了多久（被打断期间不计时）


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)
	animation_looped.connect(_on_animation_looped)


func _process(delta: float) -> void:
	if pet.current == self:
		_elapsed += delta


# 每播完一遍检查一次，时间到了就换一个不一样的听歌动作
func _on_animation_looped() -> void:
	if switch_time > 0.0 and _elapsed >= switch_time:
		_elapsed = 0.0
		var names := Array(sprite_frames.get_animation_names())
		if names.size() > 1:
			names.erase(String(animation))
		play(names.pick_random())


func wants_active() -> bool:
	return requested or _playing


# 第一次上场随机抽一个；之后回来都接着播上一次的那个
func enter() -> void:
	visible = true
	if _started:
		play(animation)
	else:
		_started = true
		play_random()


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
