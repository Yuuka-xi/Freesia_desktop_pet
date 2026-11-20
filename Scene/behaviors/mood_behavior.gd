class_name MoodBehavior
extends PetBehavior
## 带心情的分类（打字、画画）：普通 / 生气 / 疲倦 三组动作
## 动画名以 angry_ 开头属于“生气”，tired_ 开头属于“疲倦”，其余为“普通”
##   生气：子类判断“正在发火”（打字太快、疯狂撤销），并至少保持 angry_hold 秒
##   疲倦：连续活动超过 tired_after 秒；中途休息满 rest_reset 秒就清零
##   两者同时满足时显示生气

@export var tired_after := 1800.0  ## 连续活动多少秒后疲倦（默认 30 分钟）
@export var rest_reset := 300.0  ## 休息多少秒后疲倦清零（默认 5 分钟）
@export var angry_hold := 3.0  ## 生气至少保持几秒，避免在阈值附近来回切换

var mood := ""  ## 当前心情："" 普通，"angry" 生气，"tired" 疲倦
var _session := 0.0  # 连续活动了多少秒
var _rest := 0.0  # 已经休息了多少秒
var _angry_left := 0.0  # 生气还要保持几秒


## 子类每秒调用一次：active = 这一秒是否在做这件事，angry = 这一秒是否在发火
func tick_mood(active: bool, angry: bool) -> void:
	if active:
		_session += 1.0
		_rest = 0.0
	else:
		_rest += 1.0
		if _rest >= rest_reset:
			_session = 0.0
	_angry_left = angry_hold if angry else maxf(_angry_left - 1.0, 0.0)

	var new_mood := ""
	if _angry_left > 0.0:
		new_mood = "angry"
	elif _session >= tired_after:
		new_mood = "tired"
	if new_mood != mood:
		mood = new_mood
		if pet.current == self:
			play_mood()  # 正在场上时心情变了，立刻换成对应的动作


func enter() -> void:
	visible = true
	play_mood()


## 从当前心情对应的那组动作里随机挑一个；这组没有动作就退回普通
func play_mood() -> void:
	var group := []
	for name in sprite_frames.get_animation_names():
		var is_angry := name.begins_with("angry_")
		var is_tired := name.begins_with("tired_")
		if (mood == "angry" and is_angry) or (mood == "tired" and is_tired) \
				or (mood == "" and not is_angry and not is_tired):
			group.append(name)
	if group.is_empty() and mood != "":
		mood = ""
		play_mood()
		return
	play(group.pick_random())
