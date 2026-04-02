# SPEC: 3D 移动演示 — Godot 4.x

## 1. 项目概述

- **类型**: 3D 第一人称/第三人称移动演示
- **核心功能**: 玩家在 3D 场景中自由行走、跳跃、环顾
- **目标平台**: Linux (HTML5 导出为 Web)

## 2. 视觉与场景

### 环境

- 无限地面（GridMap 或大型 StaticBody3D plane）
- 周围随机放置彩色立方体/圆柱作为参照物
- 天空盒（Engine.default_clear_color 或 Sky）
- 基础光照：DirectionalLight3D + Ambient

### 材质

- 地面：深灰绿色 GridMaterial
- 物体：随机饱和色（红/蓝/黄/绿）BasicStandardMaterial
- 玩家胶囊：白色，略带发光

## 3. 角色控制

### 移动

- WASD 前后左右
- Space 跳跃（仅在地面上）
- 鼠标移动控制视角（Pointer Lock）
- Shift 加速跑

### 参数

| 参数 | 值 |
|---|---|
| 行走速度 | 8.0 m/s |
| 跑酷速度 | 16.0 m/s |
| 跳跃力 | 10.0 |
| 重力 | 20.0 |
| 鼠标灵敏度 | 0.3 |

## 4. 交互

- 点击 Canvas 开始 Pointer Lock
- ESC 释放鼠标锁
- UI 显示操作说明

## 5. 技术栈

- Godot 4.x GDScript
- CharacterBody3D 玩家节点
- CSGBox3D / CSGCylinder3D 环境几何体
- SubViewport + Scene 渲染 HTML5

## 6. 文件结构

```
godot-3d-demo/
├── project.godot
├── SPEC.md
├── scenes/
│   ├── main.tscn        # 主场景（世界+玩家）
│   └── player.tscn      # 玩家预制体
└── scripts/
    └── player.gd        # 玩家控制器脚本
```
