extends SceneTree
## TDD 测试运行器 — headless 模式
## 用法: godot --headless --script test/runner.gd
## 输出示例:
##   ✓ test_snake_starts_with_3_segments
##   ✓ test_food_not_in_wall
##   ✗ test_collision: Expected 0 got 1
##   ...
##   ---- 4 passed, 1 failed ----

const PASS_COLOR = "2e8b57"   # 绿色
const FAIL_COLOR = "dc143c"   # 红色
const RESET = "c"

var _passed: int = 0
var _failed: int = 0
var _game: Node3D


func _init():
    print("━━━ Godot 4 Snake TDD 测试 ━━━\n")
    _game = load("res://scenes/main.tscn").instantiate()
    root.add_child(_game)

    # 等 onready 执行完毕，下一帧再跑测试
    call_deferred("_run_and_exit")


func _run_and_exit() -> void:
    # 等两帧确保 onready 完成
    await process_frame
    await process_frame
    await process_frame

    _run_tests()
    _print_summary()
    quit(0 if _failed == 0 else 1)


func _run_tests() -> void:
    # ── 测试：蛇初始长度 ──
    _test("snake初始3节",
        func():
            var body: Array = _game.snake_body
            return body.size() == 3,
        "蛇身体应有3节，当前=" + str(_game.snake_body.size()))

    # ── 测试：蛇头朝右 ──
    _test("初始方向向右",
        func():
            return _game.direction == Vector3i(1, 0, 0),
        "方向应为 (1,0,0)，当前=" + str(_game.direction))

    # ── 测试：食物生成在有效范围（1~18） ──
    _test("食物不在墙内",
        func():
            var fp: Vector3i = _game._food_position
            return fp.x >= 1 and fp.x <= 18 and fp.z >= 1 and fp.z <= 18,
        "食物应在 1~18 范围内，当前=(" + str(_game._food_position.x) + "," + str(_game._food_position.z) + ")")

    # ── 测试：食物不和蛇身重叠 ──
    _test("食物不与蛇身重叠",
        func():
            return not (_game._food_position in _game.snake_body),
        "食物位置不应在蛇身体上")

    # ── 测试：_tick 正常推进（向右走一格）──
    _test("_tick向右移动一格",
        func():
            var before: Vector3i = _game.snake_body[0]
            _game._tick()
            var after: Vector3i = _game.snake_body[0]
            return after == before + Vector3i(1, 0, 0),
        "蛇头应向右移动一格")

    # ── 测试：撞墙 Game Over ──
    _test("蛇头向左撞墙触发 Game Over",
        func():
            # 把蛇头强制移到 x=0（左墙）
            _game.snake_body[0] = Vector3i(0, 0, 10)
            for seg in _game._segments:
                seg.position = Vector3.ZERO  # 避免报错
            var was_alive: bool = _game.is_alive
            _game.direction = Vector3i(-1, 0, 0)
            _game.next_direction = Vector3i(-1, 0, 0)
            _game._tick()
            return not _game.is_alive,
        "撞墙后 is_alive 应为 false")

    # ── 测试：吃食物后分数+10 ──
    _test("吃食物分数+10",
        func():
            _game._start_game()  # 重置状态
            # 把食物放到蛇头前方一格，然后手动 _tick
            var head: Vector3i = _game.snake_body[0]
            var dir: Vector3i = _game.direction
            _game._food_position = head + dir
            _game.tick_timer = 0.0   # 重置计时器，防止自动 tick 抢跑
            _game._tick()
            return _game.score == 10,
        "吃食物后分数应为10，当前=" + str(_game.score))

    # ── 测试：吃食物后蛇身变长 ──
    _test("吃食物蛇身+1节",
        func():
            _game._start_game()  # 重置状态
            var before_len: int = _game.snake_body.size()
            var head: Vector3i = _game.snake_body[0]
            _game._food_position = head + _game.direction
            _game.tick_timer = 0.0
            _game._tick()
            return _game.snake_body.size() == before_len + 1,
        "吃食物后蛇身应+1，当前长度=" + str(_game.snake_body.size()))

    # ── 测试：不能反方向掉头 ──
    _test("向右走时不能直接向左",
        func():
            _game.direction = Vector3i(1, 0, 0)
            _game.next_direction = Vector3i(1, 0, 0)
            _game._try_set_direction(Vector3i(-1, 0, 0))
            return _game.next_direction == Vector3i(1, 0, 0),
        "尝试反方向应被拒绝")

    # ── 测试：撞自己 Game Over ──
    _test("撞自己身体触发 Game Over",
        func():
            _game._start_game()  # 重置
            # 把食物放蛇头前面，然后制造蛇身第二格位置等于新头位置
            var head: Vector3i = _game.snake_body[0]
            var dir: Vector3i = _game.direction
            # 把食物放到安全位置避免干扰
            _game._food_position = Vector3i(50, 0, 50)
            # 人为让蛇撞自己：把第三格位置设到蛇头下一格
            _game.snake_body[2] = head + dir  # 第三格放到头部下一个位置
            _game._tick()
            return not _game.is_alive,
        "撞自己后 is_alive 应为 false")

    # ── 测试：重新开始恢复初始状态 ──
    _test("重新开始后状态重置",
        func():
            _game._game_over()
            _game._restart()
            return _game.is_alive and _game.score == 0 and _game.snake_body.size() == 3,
        "重启后 is_alive=true, score=0, 长度=3")

    # ── 测试：分数显示正常更新 ──
    _test("分数UI文本正常",
        func():
            return "分数" in _game._ui_label.text,
        "UI文本应包含'分数'")


func _test(name: String, condition: Callable, detail: String = "") -> void:
    var ok: bool = condition.call()
    if ok:
        _passed += 1
        _print_color("✓ " + name, PASS_COLOR)
    else:
        _failed += 1
        _print_color("✗ " + name + (": " + detail if detail else ""), FAIL_COLOR)


func _print_color(text: String, color: String) -> void:
    print("[" + color + "]> " + text + "[" + RESET + "]")


func _print_summary() -> void:
    print("\n━━━ 测试结果 ━━━")
    _print_color("  ✓ passed: " + str(_passed), PASS_COLOR)
    _print_color("  ✗ failed: " + str(_failed), FAIL_COLOR)
    print("━━━━━━━━━━━━━━━━━")
    if _failed == 0:
        _print_color("  🎉 全部通过！", PASS_COLOR)
    else:
        _print_color("  ⚠️  " + str(_failed) + " 个测试失败", FAIL_COLOR)
