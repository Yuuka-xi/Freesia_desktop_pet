class_name PetBehavior
extends AnimatedSprite2D
## 分类行为基类：每个动作分类一个节点。
## 子类只需决定“什么时候想上场”（wants_active / request），以及上场后怎么播。

@export var priority := 0  ## 优先级：多个分类同时想上场时，数字大的胜出

var requested := false  ## 是否请求上场（一次性分类用）

@onready var pet = get_parent()  # 调度器 DesktopPet


func _ready() -> void:
	visible = false
	animation_finished.connect(_on_animation_finished)


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
