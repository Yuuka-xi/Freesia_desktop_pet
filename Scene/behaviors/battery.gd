extends PetBehavior
## 电量：
##   电量低于 low_percent 且没插电 → 一直播 low_anim，直到插上电源
##   插上电源的那一刻 → 播一遍 charge_anim，然后回到正常状态
## 台式机没有电池，不会触发

@export var monitor: ActivityMonitor  ## 提供电量和充电状态
@export var low_percent := 10  ## 低于多少电量算低电量
@export var low_anim := &"battery_low"
@export var charge_anim := &"battery_charging"

var _was_charging := true  # 上一秒是否插着电（启动时默认插着，避免一启动就误触发）
var _charge_pending := false  # 刚插上电，还没播完充电动画


func _ready() -> void:
	super()
	monitor.updated.connect(_on_monitor_updated)
	animation_looped.connect(_on_animation_looped)


# 低电量时一直想上场；刚插电时也想上场（播一遍充电动画）
func wants_active() -> bool:
	return requested or _charge_pending or _is_low()


func _is_low() -> bool:
	return monitor.battery >= 0 and monitor.battery < low_percent and not monitor.charging


func enter() -> void:
	visible = true
	_play_state()


# 每秒检查一次：从“没插电”变成“插着电”就算刚充上
func _on_monitor_updated() -> void:
	if monitor.battery >= 0 and monitor.charging and not _was_charging:
		_charge_pending = true
		if pet.current == self:
			_play_state()  # 正在播低电量时插上电，立刻换成充电动画
	_was_charging = monitor.charging


func _play_state() -> void:
	play(charge_anim if _charge_pending else low_anim)


# 充电动画播完一遍就结束，回到正常状态
func _on_animation_looped() -> void:
	if animation == charge_anim:
		_charge_pending = false
		done()
