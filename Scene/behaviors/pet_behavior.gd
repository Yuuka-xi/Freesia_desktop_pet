class_name PetBehavior
extends AnimatedSprite2D
## 分类行为基类：每个动作分类一个节点。
## 子类只需决定“什么时候想上场”（wants_active / request），以及上场后怎么播。
## 省内存：动作资源（frames_path）上场前在后台加载，下场后释放；keep_loaded 的分类常驻内存。

@export var priority := 0  ## 优先级：多个分类同时想上场时，数字大的胜出
@export_file("*.tres") var frames_path := ""  ## 本分类的动作资源（SpriteFrames）
@export var keep_loaded := false  ## 是否常驻内存（经常出现的分类，如待机）

var requested := false  ## 是否请求上场（一次性分类用）
var _last_anim := &""  # 释放前在播的动作，重新加载后恢复（让“记住上次动作”继续有效）
var _loading := false  # 是否正在后台加载动作资源

@onready var pet = get_parent()  # 调度器 DesktopPet


func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)
	if keep_loaded:
		load_frames()


## 立刻加载动作资源（常驻分类启动时用）
func load_frames() -> void:
	if sprite_frames == null and frames_path != "":
		_set_frames(load(frames_path))


## 动作资源是否已就绪；还没有就在后台开始加载并返回 false，调度器下一帧再问
func frames_ready() -> bool:
	if sprite_frames != null or frames_path == "":
		return true
	if not _loading:
		_loading = true
		ResourceLoader.load_threaded_request(frames_path)
	var status := ResourceLoader.load_threaded_get_status(frames_path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return false
	_loading = false
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_set_frames(ResourceLoader.load_threaded_get(frames_path))
	else:
		_set_frames(load(frames_path))  # 后台加载失败时改为直接加载
	return true


func is_loading() -> bool:
	return _loading


## 释放动作资源；常驻的分类不释放
func unload_frames() -> void:
	if keep_loaded or sprite_frames == null:
		return
	_last_anim = animation
	sprite_frames = null


# 装上动作资源，并恢复上次在播的动作
func _set_frames(frames: SpriteFrames) -> void:
	sprite_frames = frames
	if _last_anim != &"" and frames.has_animation(_last_anim):
		animation = _last_anim


## 现在是否想上场；默认看 requested，常驻分类（如待机）可重写为 true
func wants_active() -> bool:
	return requested


## 请求上场，调度器下一帧会按优先级决定是否切过来
func request() -> void:
	requested = true


## 被调度器选中：显示并随机播放一个动作
func enter() -> void:
	visible = true
	play_random()


## 被换下：隐藏、停止，并清掉请求
func exit() -> void:
	visible = false
	stop()
	requested = false


## 从本分类里随机挑一个动作播放
func play_random() -> void:
	var names := sprite_frames.get_animation_names()
	play(names[randi() % names.size()])


## 本次表演结束，让出舞台
func done() -> void:
	requested = false


# 一次性动画（不循环）播完就算结束
func _on_animation_finished() -> void:
	done()
