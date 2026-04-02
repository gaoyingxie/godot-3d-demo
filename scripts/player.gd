extends CharacterBody3D
## 第一人称/第三人称混合玩家控制器
## WASD移动 + 鼠标视角 + 跳跃

@export var walk_speed: float = 8.0
@export var sprint_speed: float = 16.0
@export var jump_force: float = 10.0
@export var mouse_sensitivity: float = 0.3
@export var sprint_enabled: bool = true

var _speed: float = 8.0
var _gravity: float = 20.0
var _falling: bool = false

# 节点引用
@onready var _cam_pivot: Node3D = $CamPivot
@onready var _camera: Camera3D = $CamPivot/Camera3D
@onready var _mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	# 锁定并隐藏鼠标
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 打印操作说明
	_print_controls()


func _print_controls() -> void:
	print("━━━ 3D 移动演示 ━━━")
	print("WASD   移动")
	print("Space  跳跃")
	print("Shift   加速跑")
	print("ESC    释放鼠标")
	print("点击画面  锁定鼠标")
	print("━━━━━━━━━━━━━━━━━")


func _input(event: InputEvent) -> void:
	# 鼠标移动 → 视角旋转
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# 水平旋转（整个角色）
		rotate_y(-event.relative.x * mouse_sensitivity * 0.01)
		# 垂直旋转（仅摄像头 pitch）
		_cam_pivot.rotate_x(-event.relative.y * mouse_sensitivity * 0.01)
		_cam_pivot.rotation.x = clamp(_cam_pivot.rotation.x, -PI / 2.2, PI / 2.2)

	# 点击 → 锁定鼠标
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# ESC → 释放鼠标
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		_falling = false

	# 移动方向输入
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 转换到世界坐标方向（考虑角色朝向）
	var move_dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# 速度模式
	_speed = sprint_speed if (sprint_enabled and Input.is_action_pressed("sprint") and input_dir.length() > 0.1) else walk_speed

	# 设置水平速度
	velocity.x = move_dir.x * _speed
	velocity.z = move_dir.z * _speed

	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force
		_falling = false

	move_and_slide()

	# 简单落地检测
	if velocity.y < -1.0 and not _falling:
		_falling = true
