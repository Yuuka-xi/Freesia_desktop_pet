extends PetBehavior
## 随机动作：待机时每隔一段时间随机播一个，播 1~2 遍后回到待机

@export var idle: PetBehavior  ## 只有它在场时才计时
@export var interval_min := 20.0  ## 两次随机动作之间的最短间隔（秒）
@export var interval_max := 60.0  ## 最长间隔（秒）
@export var loops_min := 1  ## 最少播几遍
@export var loops_max := 2  ## 最多播几遍

var _wait := 0.0  # 距离下次随机动作还剩几秒
var _loops_left := 0  # 还剩几遍


func _ready() -> void:
	super()
	animation_looped.connect(_on_animation_looped)
	_reset_wait()


func _process(delta: float) -> void:
	if pet.current == idle:
		_wait -= delta
		if _wait <= 0.0:
			request()


func enter() -> void:
	super()
	_loops_left = randi_range(loops_min, loops_max)
	_reset_wait()


# 每播完一遍减一次，播够了就回到待机
func _on_animation_looped() -> void:
	_loops_left -= 1
	if _loops_left <= 0:
		done()


func _reset_wait() -> void:
	_wait = randf_range(interval_min, interval_max)
