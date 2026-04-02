extends Node3D
## 贪吃蛇 — 花哨版：颜色渐变 + 食物特效 + 粒子 + 加速

# ── 地图 ──
const GRID_SIZE: int = 20
const CELL_SIZE: float = 1.0

# ── 蛇 ──
var snake_body: Array[Vector3i] = []
var direction: Vector3i = Vector3i(1, 0, 0)
var next_direction: Vector3i = Vector3i(1, 0, 0)
var is_alive: bool = true
var score: int = 0

# ── 速度（随分数加速） ──
const TICK_BASE: float = 0.15
const TICK_MIN: float = 0.07
var _tick_interval: float = TICK_BASE

# ── 计时器 ──
var tick_timer: float = 0.0

# ── 预制体 ──
var _segment_scene: PackedScene
var _segments: Array[Node3D] = []

# ── 食物特效 ──
var _food_position: Vector3i = Vector3i.ZERO
var _food_scale_target: float = 1.0

# ── 粒子 ──
var _particle_scene: PackedScene

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
	for s in _segments:
		s.queue_free()
	_segments.clear()
	snake_body.clear()

	var start_x: int = GRID_SIZE / 2 - 2
	var start_z: int = GRID_SIZE / 2
	for i in range(3):
		var pos := Vector3i(start_x - i, 0, start_z)
		snake_body.append(pos)
		var seg: Node3D = _segment_scene.instantiate()
		_world_root.add_child(seg)
		_seg_update_pos(seg, pos)
		_seg_color_by_index(seg, i, 0)   # i=0 是头
		_segments.append(seg)

	direction = Vector3i(1, 0, 0)
	next_direction = direction
	is_alive = true
	score = 0
	tick_timer = 0.0
	_tick_interval = TICK_BASE

	_spawn_food()
	_update_ui()


func _seg_color_by_index(seg: Node3D, index: int, total: int) -> void:
	# 头浅蓝 → 尾深绿，线性渐变
	var t: float = 0.0 if total <= 1 else float(index) / float(total - 1)
	var r: float = lerp(0.4, 0.1, t)
	var g: float = lerp(0.8, 0.5, t)
	var b: float = lerp(1.0, 0.2, t)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(r, g, b, 1.0)

	if index == 0:
		mat.emission_enabled = true
		mat.emission = Color(r * 0.5, g * 0.5, b * 0.5, 1.0)
		mat.emission_energy_multiplier = 0.6
	else:
		mat.emission_enabled = false

	seg.set("material_override", mat)


func _seg_update_pos(seg: Node3D, grid_pos: Vector3i) -> void:
	seg.position = Vector3(grid_pos.x * CELL_SIZE, 0.5, grid_pos.z * CELL_SIZE)


func _spawn_food() -> void:
	var valid: Array[Vector3i] = []
	for x in range(1, GRID_SIZE - 1):
		for z in range(1, GRID_SIZE - 1):
			var p := Vector3i(x, 0, z)
			if not (p in snake_body):
				valid.append(p)

	if valid.is_empty():
		return

	_food_position = valid[randi() % valid.size()]
	_food_marker.position = Vector3(_food_position.x * CELL_SIZE, 0.5, _food_position.z * CELL_SIZE)
	_food_marker.scale = Vector3.ONE
	_food_scale_target = 1.0


func _spawn_particles(pos: Vector3) -> void:
	# 简单粒子：8个彩球向四周炸开（同步动画，不卡tick）
	for i in range(8):
		var ball: MeshInstance3D = MeshInstance3D.new()
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		ball.mesh = sphere

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		var rr: float = 1.0
		var rg: float = 0.3 + randf() * 0.4
		var rb: float = 0.1
		mat.albedo_color = Color(rr, rg, rb, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(rr, rg, rb, 1.0)
		mat.emission_energy_multiplier = 2.0
		ball.set("material_override", mat)

		ball.position = pos
		_world_root.add_child(ball)

		var angle: float = i * 2.0 * PI / 8.0
		var target_pos: Vector3 = pos + Vector3(cos(angle), 0.5, sin(angle)) * 1.5

		var tw: Tween = create_tween()
		tw.tween_property(ball, "position", target_pos, 0.5)
		tw.parallel().tween_property(ball, "scale", Vector3.ZERO, 0.5)
		tw.chain().tween_callback(ball.queue_free)


func _process(delta: float) -> void:
	# 相机跟随蛇头（平滑）
	if not snake_body.is_empty():
		var head: Vector3i = snake_body[0]
		var target := Vector3(head.x * CELL_SIZE, 16.0, head.z * CELL_SIZE + 10.0)
		_cam_follow.position = _cam_follow.position.lerp(target, delta * 6.0)

	# 食物脉冲动画
	if is_alive:
		var s: float = _food_marker.scale.x
		s = lerp(s, _food_scale_target, delta * 5.0) as float
		if abs(s - _food_scale_target) < 0.01:
			_food_scale_target = 1.3 if _food_scale_target < 1.2 else 1.0
		_food_marker.scale = Vector3.ONE * s
		_food_marker.rotate_y(delta * 2.5)

	if not is_alive:
		if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("jump"):
			_restart()
		return

	# 方向输入
	if Input.is_action_just_pressed("move_forward"):
		_try_set_direction(Vector3i(0, 0, -1))
	elif Input.is_action_just_pressed("move_backward"):
		_try_set_direction(Vector3i(0, 0, 1))
	elif Input.is_action_just_pressed("move_left"):
		_try_set_direction(Vector3i(-1, 0, 0))
	elif Input.is_action_just_pressed("move_right"):
		_try_set_direction(Vector3i(1, 0, 0))

	tick_timer += delta
	var speed: float = _tick_interval * (0.55 if Input.is_action_pressed("sprint") else 1.0)

	if tick_timer >= speed:
		tick_timer = 0.0
		_tick()


func _try_set_direction(new_dir: Vector3i) -> void:
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
		_tick_interval = max(TICK_MIN, TICK_BASE - score * 0.001)  # 越吃越快
		_update_ui()
		_spawn_particles(Vector3(new_head.x * CELL_SIZE, 0.5, new_head.z * CELL_SIZE))
		_spawn_food()

	# 移动：把尾节点移到新头位置
	snake_body.push_front(new_head)
	var tail_seg: Node3D = _segments.pop_back()
	_seg_update_pos(tail_seg, new_head)
	_segments.push_front(tail_seg)

	if not ate_food:
		snake_body.pop_back()
	else:
		# 变长：新增一个尾节点
		var new_tail: Node3D = _segment_scene.instantiate()
		_world_root.add_child(new_tail)
		_seg_update_pos(new_tail, snake_body[-1])
		_segments.append(new_tail)

	# 重新着色（整体渐变）
	for i in range(_segments.size()):
		_seg_color_by_index(_segments[i], i, _segments.size())


func _game_over() -> void:
	is_alive = false
	_gameover_panel.visible = true
	_gameover_panel.get_node("VBox/Score").text = "分数: %d" % score


func _restart() -> void:
	_gameover_panel.visible = false
	_start_game()


func _update_ui() -> void:
	_ui_label.text = "分数: %d" % score
