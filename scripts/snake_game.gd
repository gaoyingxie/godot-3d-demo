extends Node3D
## 贪吃蛇主控制器 — 管理蛇身、食物、分数、游戏状态

# ── 地图 ──
const GRID_SIZE: int = 20
const CELL_SIZE: float = 1.0

# ── 蛇 ──
var snake_body: Array[Vector3i] = []  # 每节格子坐标
var direction: Vector3i = Vector3i(1, 0, 0)
var next_direction: Vector3i = Vector3i(1, 0, 0)
var is_alive: bool = true
var score: int = 0

# ── 计时器 ──
const TICK_INTERVAL: float = 0.22
var tick_timer: float = 0.0

# ── 预制体 ──
var _segment_scene: PackedScene
var _segments: Array[Node3D] = []  # 已实例化的节点（与 snake_body 一一对应）

# ── 食物 ──
var _food_position: Vector3i = Vector3i.ZERO

# ── 节点 ──
@onready var _world_root: Node3D = $SnakeWorld
@onready var _cam_follow: Node3D = $CameraAnchor
@onready var _food_marker: Node3D = $Food
@onready var _ui_label: Label = $UI/ScoreLabel
@onready var _gameover_panel: Control = $UI/GameOverPanel

func _ready() -> void:
	_segment_scene = preload("res://snake/snake_segment.tscn")
	_gameover_panel.visible = false
	_start_game()


func _start_game() -> void:
	# 清理旧节点
	for s in _segments:
		s.queue_free()
	_segments.clear()
	snake_body.clear()

	# 蛇头放中间，面向右
	var start_x: int = GRID_SIZE / 2 - 2
	var start_z: int = GRID_SIZE / 2
	for i in range(3):
		var pos := Vector3i(start_x - i, 0, start_z)
		snake_body.append(pos)
		var seg: Node3D = _segment_scene.instantiate()
		_seg_set_color(seg, i == 0)
		_world_root.add_child(seg)
		_seg_update_pos(seg, pos)
		_segments.append(seg)

	direction = Vector3i(1, 0, 0)
	next_direction = direction
	is_alive = true
	score = 0
	tick_timer = 0.0

	_spawn_food()
	_update_ui()


func _add_new_segment(grid_pos: Vector3i, is_head: bool) -> void:
	var seg: Node3D = _segment_scene.instantiate()
	_seg_set_color(seg, is_head)
	_world_root.add_child(seg)
	_seg_update_pos(seg, grid_pos)
	_segments.append(seg)


func _seg_set_color(seg: Node3D, is_head: bool) -> void:
	var mat := StandardMaterial3D.new()
	if is_head:
		mat.albedo_color = Color(0.4, 0.8, 1.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 0.8, 1.0)
		mat.emission_energy_multiplier = 0.5
	else:
		mat.albedo_color = Color(0.3, 0.7, 0.4, 1.0)
	seg.set("material_override", mat)


func _seg_update_pos(seg: Node3D, grid_pos: Vector3i) -> void:
	seg.position = Vector3(grid_pos.x * CELL_SIZE, 0.5, grid_pos.z * CELL_SIZE)


func _spawn_food() -> void:
	# 墙厚1格，有效范围是 1~GRID_SIZE-2
	var valid_positions: Array[Vector3i] = []
	for x in range(1, GRID_SIZE - 1):
		for z in range(1, GRID_SIZE - 1):
			var p := Vector3i(x, 0, z)
			if not (p in snake_body):
				valid_positions.append(p)

	if valid_positions.is_empty():
		return

	_food_position = valid_positions[randi() % valid_positions.size()]
	_food_marker.position = Vector3(_food_position.x * CELL_SIZE, 0.5, _food_position.z * CELL_SIZE)


func _process(delta: float) -> void:
	# 相机跟随蛇头
	if not snake_body.is_empty():
		var head: Vector3i = snake_body[0]
		var target := Vector3(head.x * CELL_SIZE, 15.0, head.z * CELL_SIZE + 8.0)
		_cam_follow.position = _cam_follow.position.lerp(target, delta * 8.0)

	_food_marker.rotate_y(delta * 2.0)

	if not is_alive:
		if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("jump"):
			_restart()
		return

	# 方向输入（缓冲）
	if Input.is_action_just_pressed("move_forward"):
		_try_set_direction(Vector3i(0, 0, -1))
	elif Input.is_action_just_pressed("move_backward"):
		_try_set_direction(Vector3i(0, 0, 1))
	elif Input.is_action_just_pressed("move_left"):
		_try_set_direction(Vector3i(-1, 0, 0))
	elif Input.is_action_just_pressed("move_right"):
		_try_set_direction(Vector3i(1, 0, 0))

	tick_timer += delta
	var speed: float = TICK_INTERVAL * (0.55 if Input.is_action_pressed("sprint") else 1.0)

	if tick_timer >= speed:
		tick_timer = 0.0
		_tick()


func _try_set_direction(new_dir: Vector3i) -> void:
	# 禁止反方向掉头
	if new_dir + direction != Vector3i(0, 0, 0):
		next_direction = new_dir


func _tick() -> void:
	direction = next_direction
	var head: Vector3i = snake_body[0]
	var new_head: Vector3i = head + direction

	# 撞墙
	if new_head.x < 0 or new_head.x >= GRID_SIZE \
		or new_head.z < 0 or new_head.z >= GRID_SIZE:
		_game_over()
		return

	# 撞自己
	if new_head in snake_body:
		_game_over()
		return

	var ate_food: bool = (new_head == _food_position)

	if ate_food:
		score += 10
		_update_ui()
		_spawn_food()

	# 蛇身移动：尾节点移到新头位置
	snake_body.push_front(new_head)
	var tail_seg: Node3D = _segments.pop_back()
	_seg_update_pos(tail_seg, new_head)
	_seg_set_color(tail_seg, true)
	_segments.push_front(tail_seg)

	if not ate_food:
		snake_body.pop_back()   # 没吃东西才缩回去
		if snake_body.size() > 1:
			_seg_set_color(_segments[1], false)   # 原来第二格变普通身体
	else:
		# 吃东西了：尾节点要保留（变长）
		var new_tail: Node3D = _segment_scene.instantiate()
		_seg_set_color(new_tail, false)
		_world_root.add_child(new_tail)
		var last_pos: Vector3i = snake_body[-1]
		_seg_update_pos(new_tail, last_pos)
		_segments.append(new_tail)

	# 新的头是唯一有这个颜色的
	_seg_set_color(_segments[0], true)
	if _segments.size() > 1:
		_seg_set_color(_segments[1], false)


func _game_over() -> void:
	is_alive = false
	_gameover_panel.visible = true
	_gameover_panel.get_node("VBox/Score").text = "分数: %d" % score


func _restart() -> void:
	_gameover_panel.visible = false
	_start_game()


func _update_ui() -> void:
	_ui_label.text = "分数: %d" % score
