## Context

PRD1 骨架已完成，EventBus / DataManager / GameManager 可用。需要在此基础上实现作物核心逻辑层。

项目目录：`/Users/linzizhan/Desktop/coco_project/像素风田园游戏/pixel-farm/`

**约束条件**:
- 引擎: Godot 4.6, GDScript
- 零美术依赖（纯逻辑层）
- 使用真实 Unix 时间戳驱动（非游戏内时间）
- Autoload 单例模式

## Goals / Non-Goals

**Goals:**
- 实现完整 5 状态机（SEED/SPROUT/GROWING/MATURE/WITHERED）
- 浇水驱动生长（每阶段需浇水一次，浇水后计时推进）
- 枯萎判定（成熟后跨自然日零点未收获）
- 离线补偿（最多推进一个阶段）
- 与 GameManager.farm_data 双向同步
- 测试场景验证全部逻辑

**Non-Goals:**
- 不实现视觉表现（TileMap/动画属于 PRD8+）
- 不实现种植交互（属于 PRD10）
- 不实现游戏内时间系统（属于 PRD7）

## Decisions

### 1. 计时驱动方式: _process 轮询 vs Timer 节点

**决定**: _process(delta) + 1秒间隔轮询

**理由**: 更简单，无需额外 Timer 节点，80 地块每秒遍历无性能压力

### 2. 数据权威: CropManager 内部 vs GameManager.farm_data

**决定**: CropManager._crops 为运行时权威数据，每次操作后单向同步到 GameManager.farm_data

**理由**: 避免双源冲突，CropManager 是唯一写入口

### 3. 枯萎时间源: 系统时钟 vs 游戏内时间

**决定**: 使用 Time.get_unix_time_from_system() 系统真实时间

**理由**: PRD7 游戏内时间尚未实现，先用系统时间，接口不变后续可替换

### 4. class_name 使用

**决定**: 不使用 class_name（Autoload 脚本不能声明 class_name）

**理由**: Godot 4.x 中 Autoload 单例已注册全局名，class_name 会冲突

## Risks

| 风险 | 缓解 |
|------|------|
| 系统时间被篡改导致作物异常 | 可接受，休闲游戏不需要严格防作弊 |
| 离线时间过长导致大量枯萎 | 设计如此（软惩罚），后续可加"冷冻"道具 |
