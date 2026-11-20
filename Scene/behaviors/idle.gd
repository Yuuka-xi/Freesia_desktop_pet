extends PetBehavior
## 正常待机：优先级最低，没有别的分类想上场时就是它
## 每隔 switch_time 秒换一个待机动作（等当前这遍播完再换）
## 被其他分类打断后回来，接着播原来的动作，计时也接着算

@export var switch_time := 10.0  ## 多少秒换一个待机动作，0 表示不换

var _elapsed := 0.0  # 当前待机动作已经播了多久（被打断期间不计时）
var _started := false  # 是否已经抽过第一个待机动作


func _ready() -> void:
	super()
	animation_looped.connect(_on_animation_looped)


func _process(delta: float) -> void:
	if pet.current == self:
		_elapsed += delta


func wants_active() -> bool:
	return true


# 第一次上场随机抽一个；之后回来都接着播原来那个
func enter() -> void:
	visible = true
	if _started:
		play(animation)
	else:
		_started = true
		play_random()


# 每播完一遍检查一次，时间到了就换一个不一样的待机动作
func _on_animation_looped() -> void:
	if switch_time > 0.0 and _elapsed >= switch_time:
		_elapsed = 0.0
		_play_different()


func _play_different() -> void:
	var names := Array(sprite_frames.get_animation_names())
	if names.size() > 1:
		names.erase(String(animation))
	play(names.pick_random())
