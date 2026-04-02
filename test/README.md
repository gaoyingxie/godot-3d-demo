# 测试指南

## 运行全部测试

```bash
godot --headless --script test/runner.gd
```

## 测试覆盖范围

| 测试 | 说明 |
|---|---|
| ✓ snake初始3节 | 初始蛇身长度为 3 |
| ✓ 初始方向向右 | 默认向右 |
| ✓ 食物不在墙内 | 食物坐标在 1~18 范围内 |
| ✓ 食物不与蛇身重叠 | 食物不生成在蛇身上 |
| ✓ _tick向右移动一格 | 单次 tick 正确移动 |
| ✓ 撞墙 Game Over | 碰到边界触发结束 |
| ✓ 吃食物分数+10 | 吃食物加 10 分 |
| ✓ 吃食物蛇身+1节 | 吃食物身体增长 |
| ✓ 不能反方向掉头 | 禁止 180° 掉头 |
| ✓ 撞自己 Game Over | 碰到自身触发结束 |
| ✓ 重开状态重置 | Game Over 后重开数据清零 |
| ✓ 分数UI文本 | Label 正常显示 |

## TDD 工作流

1. **写新功能前先写测试**，在 `runner.gd` 的 `_run_tests()` 里加 `_test()` 调用
2. 运行 `godot --headless --script test/runner.gd` — 新测试应失败（RED）
3. 写实现让测试通过（GREEN）
4. 可选：重构代码，保持测试通过（REFACTOR）
5. 提交前确保 `全部通过`

## 添加新测试

在 `_run_tests()` 中添加：

```gdscript
_test("描述",
    func():
        return 你的断言条件,
    "失败时的详细信息")
```
