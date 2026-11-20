extends Control
## 桌宠调度器：处理拖动与点击，并在各分类（PetBehavior 子节点）之间切换。
## 新增分类：加一个 AnimatedSprite2D 子节点，挂上继承 PetBehavior 的脚本，填好优先级即可，这里不用改。
## 鼠标只在角色不透明的部分有效，透明处会穿透到下面的窗口（按当前帧轮廓实时更新）

const CLICK_DISTANCE := 5.0  # 按下到松开移动小于这个像素数算“点击”，否则算“拖动”
const ALPHA_THRESHOLD := 0.1  # 透明度高于这个值的像素才算角色身体

var current: PetBehavior  ## 当前在场的分类
var _behaviors: Array[PetBehavior] = []
var _pressing := false
var _dragging := false
var _press_pos := Vector2i.ZERO
var _drag_offset := Vector2i.ZERO
var _shape_cache := {}  # 帧贴图 → 该帧的轮廓（贴图坐标），算过一次就记住
var _last_texture: Texture2D  # 上次设置穿透区域时用的帧

@onready var poke: PetBehavior = $Poke


func _ready() -> void:
	get_viewport().transparent_bg = true
	for child in get_children():
		if child is PetBehavior:
			_behaviors.append(child)


func _process(_delta: float) -> void:
	_pick_behavior()
	_update_mouse_area()


# 当前帧变了，就把窗口的可点击区域换成这一帧的角色轮廓
func _update_mouse_area() -> void:
	if current == null or current.sprite_frames == null:
		return
	var texture := current.sprite_frames.get_frame_texture(current.animation, current.frame)
	if texture == null or texture == _last_texture:
		return
	_last_texture = texture
	if not _shape_cache.has(texture):
		_shape_cache[texture] = _outline(texture)
	var shape: PackedVector2Array = _shape_cache[texture]
	if shape.size() < 3:
		return  # 整帧透明时保留上一帧的区域，避免变成整个窗口都能点
	# 贴图坐标 → 窗口像素坐标（精灵居中显示，再乘上视口到窗口的缩放）
	var to_window := Vector2(get_window().size) / get_viewport_rect().size
	var origin := current.position + current.offset - texture.get_size() * current.scale / 2.0
	var area := PackedVector2Array()
	for p in shape:
		area.append((origin + p * current.scale) * to_window)
	DisplayServer.window_set_mouse_passthrough(area)


# 从一帧贴图的不透明像素算出一个外轮廓（凸包：把手里的道具等分离的部分也包进去）
func _outline(texture: Texture2D) -> PackedVector2Array:
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(texture.get_image(), ALPHA_THRESHOLD)
	var points := PackedVector2Array()
	for poly in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 2.0):
		points.append_array(poly)
	return Geometry2D.convex_hull(points) if points.size() >= 3 else PackedVector2Array()


# 调度核心：在所有想上场的分类里选优先级最高的，和当前不同就切换
func _pick_behavior() -> void:
	var best: PetBehavior = null
	for b in _behaviors:
		if b.wants_active() and (best == null or b.priority > best.priority):
			best = b
	if best == current:
		return
	if current:
		current.exit()
	current = best
	if current:
		current.enter()


# 左键：移动距离小算点击（交给“戳一戳”），超过 CLICK_DISTANCE 就拖动窗口
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = DisplayServer.mouse_get_position()
			_drag_offset = _press_pos - DisplayServer.window_get_position()
		else:
			if _pressing and not _dragging:
				poke.poke()
			_pressing = false
		accept_event()
	elif event is InputEventMouseMotion and _pressing:
		# 在窗口外松开时收不到松开事件，这里兜底结束拖动
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_pressing = false
			return
		var mouse := DisplayServer.mouse_get_position()
		if not _dragging and Vector2(mouse - _press_pos).length() > CLICK_DISTANCE:
			_dragging = true
		if _dragging:
			DisplayServer.window_set_position(mouse - _drag_offset)
		accept_event()


# 调试快捷键（仅编辑器运行时有效）：数字键 1、2… 让第 N 个分类请求上场
func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not OS.is_debug_build() or not key.pressed or key.echo:
		return
	var index := key.keycode - KEY_1
	if index >= 0 and index < _behaviors.size():
		_behaviors[index].request()
