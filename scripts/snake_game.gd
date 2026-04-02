extends Node3D
## 贪吃蛇主控制器 — 管理蛇身、食物、分数、游戏状态

# ── 地图 ──
const GRID_SIZE: int = 20          # 20×20 格子
const CELL_SIZE: float = 1.0      # 每格 1 米

# ── 蛇 ──
var snake_body: Array[Vector3i] = []  # 每节对应的格子坐标 (x, y=0, z)
var direction: Vector3i = Vector3i(1, 0, 0)  # 当前方向
var next_direction: Vector3i = Vector3i(1, 0, 0)  # 下一帧方向（缓冲）
var is_alive: bool = true
var score: int = 0

# ── 计时器 ──
const TICK_INTERVAL: float = 0.22   # 每次移动间隔（秒）
var tick_timer: float = 0.0

# ── 预制体 ──
var _segment_scene: PackedScene
var _segments: Array[Node3D] = []  # 已实例化的节点

# ── 食物 ──
var _food_position: Vector3i = Vector3i.ZERO
var _food_mesh: Node3D

# ── 节点 ──
@onready var _world_root: Node3D = $SnakeWorld
@onready var _cam_follow: Node3D = $CameraAnchor
@onready var _camera: Camera3D = $CameraAnchor/Camera3D
@onready var _ui_label: Label = $UI/ScoreLabel
@onready var _gameover_panel: Control = $UI/GameOverPanel
@onready var _food_marker: Node3D = $Food

func _ready() -> void:
	_segment_scene = preload("res://snake/snake_segment.tscn")
	_gameover_panel.visible = false
	_start_game()


func _start_game() -> void:
	# 重置蛇
	for s in _segments:
		s.queue_free()
	_segments.clear()
	snake_body.clear()

	# 蛇头放中间偏左，面向右
	var start_pos := Vector3i(GRID_SIZE / 2 - 2, 0, GRID_SIZE / 2)
	for i in range(3):
		var pos := Vector3i(start_pos.x - i, 0, start_pos.z)
		snake_body.append(pos)
		_add_segment(pos, i == 0)

	direction = Vector3i(1, 0, 0)
	next_direction = direction
	is_alive = true
	score = 0
	tick_timer = 0.0

	_spawn_food()
	_update_ui()


func _add_segment(grid_pos: Vector3i, is_head: bool) -> void:
	var seg: Node3D = _segment_scene.instantiate()
	_seg_set_color(seg, is_head)
	_world_root.add_child(seg)
	_seg_update_world_pos(seg, grid_pos)
	_segments.append(seg)


func _seg_set_color(seg: Node3D, is_head: bool) -> void:
	var mat := StandardMaterial3D.new()
	if is_head:
		mat.albedo_color = Color(0.4, 0.8, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 0.8)
		mat.emission_energy_multiplier = 0.5
	else:
		mat.albedo_color = Color(0.3, 0.7, 0.4)
	seg.material_override = mat


func _seg_update_world_pos(seg: Node3D, grid_pos: Vector3i) -> void:
	seg.position = Vector3(grid_pos.x * CELL_SIZE, 0.5, grid_pos.z * CELL_SIZE)


func _spawn_food() -> void:
	var valid_positions: Array[Vector3i] = []
	for x in range(GRID_SIZE):
		for z in range(GRID_SIZE):
			var p := Vector3i(x, 0, z)
			if not _is_occupied(p):
				valid_positions.append(p)

	if valid_positions.is_empty():
		return  # 满了（理论上不会发生）

	_food_position = valid_positions[randi() % valid_positions.size()]
	_food_marker.position = Vector3(_food_position.x * CELL_SIZE, 0.5, _food_position.z * CELL_SIZE)


func _is_occupied(pos: Vector3i) -> bool:
	return pos in snake_body


func _process(delta: float) -> void:
	# 相机跟随
	var head_world := Vector3(snake_body[0].x * CELL_SIZE, 0, snake_body[0].z * CELL_SIZE)
	_cam_follow.position = _cam_follow.position.lerp(
		Vector3(head_world.x, 15.0, head_world.z + 8.0), delta * 8.0
	)
	_food_marker.rotate_y(delta * 2.0)

	if not is_alive:
		if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("jump"):
			_restart()
		return

	# 方向输入（缓冲，防止一帧内按多次导致倒退）
	if Input.is_action_just_pressed("move_forward"):
		_try_set_direction(Vector3i(0, 0, -1))
	elif Input.is_action_just_pressed("move_backward"):
		_try_set_direction(Vector3i(0, 0, 1))
	elif Input.is_action_just_pressed("move_left"):
		_try_set_direction(Vector3i(-1, 0, 0))
	elif Input.is_action_just_pressed("move_right"):
		_try_set_direction(Vector3i(1, 0, 0))

	tick_timer += delta
	var speed: float = TICK_INTERVAL * (0.6 if Input.is_action_pressed("sprint") else 1.0)

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

	# 撞自己（排除尾巴，因为尾巴会移走）
	if new_head in snake_body:
		_game_over()
		return

	# 移动蛇：pop 尾，unshift 头
	var tail: Vector3i = snake_body.pop_back()
	_segments[-1].queue_free()
	_segments.pop_back()

	snake_body.push_front(new_head)
	_add_segment(new_head, true)
	# 新的头是唯一有这个颜色的，原来第二格变成普通身体
	if snake_body.size() > 1:
		_seg_set_color(_segments[1], false)

	# 吃食物
	if new_head == _food_position:
		score += 10
		_update_ui()
		# 尾巴不退，把刚才 pop 的尾巴加回去
		snake_body.push_back(tail)
		var old_tail_seg: Node3D = _segment_scene.instantiate()
		_seg_set_color(old_tail_seg, false)
		_world_root.add_child(old_tail_seg)
		_seg_update_world_pos(old_tail_seg, tail)
		_segments.append(old_tail_seg)
		_spawn_food()


func _game_over() -> void:
	is_alive = false
	_gameover_panel.visible = true
	_gameover_panel.get_node("VBox/Score").text = "分数: %d" % score


func _restart() -> void:
	_gameover_panel.visible = false
	_start_game()


func _update_ui() -> void:
	_ui_label.text = "分数: %d" % score



