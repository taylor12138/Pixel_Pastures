## Context

PRD1 已完成项目骨架搭建，包含 EventBus（信号总线）、DataManager（JSON 数据加载）、GameManager（游戏状态管理）等 Autoload 单例。当前需要在此基础上实现作物生长核心逻辑，让「种植→浇水→等待→成熟→收获/枯萎」循环可通过代码跑通。

现有基础设施：
- `EventBus`: 已声明 crop 相关信号（planted/watered/grown/matured/harvested/withered/cleared）
- `DataManager`: 可通过 `get_crop(crop_id)` 获取作物配置（growth_time_per_stage 等）
- `GameManager`: 管理游戏状态、玩家数据，需扩展 farm_data/inventory/stats

## Goals / Non-Goals

**Goals:**
- 实现 CropManager 单例，作为作物逻辑唯一入口
- 实现完整 5 状态机及浇水驱动生长
- 实现枯萎判定（跨自然日零点）
- 实现离线补偿（最多推进一阶段）
- 与 GameManager 双向数据同步
- 提供调试辅助接口用于测试

**Non-Goals:**
- 地块视觉表现（TileMap 渲染）→ PRD8
- 角色动画 → PRD9/PRD15
- 商店/种子购买 → PRD4
- 游戏内时间系统 → PRD7
- 完整存档系统 → PRD6

## Decisions

### Decision 1: 时间戳驱动 vs 帧计数器

**选择**: 使用 `Time.get_unix_time_from_system()` 真实时间戳

**理由**: 时间戳方案天然支持离线补偿（只需对比当前时间与浇水时间），且不受帧率或暂停影响。帧计数器需要额外处理暂停/离线场景。

**替代方案**: Timer 节点 — 每块地一个 Timer 会导致节点数量膨胀（最多 80 个），且暂停后恢复复杂。

### Decision 2: 1 秒轮询 vs 信号驱动

**选择**: `_process(delta)` 中每秒轮询所有地块

**理由**: 最多 80 块地，每秒遍历一次的开销可忽略不计。相比为每块地设置 Timer 或精确到毫秒的事件调度，轮询方案实现简单、易调试、容错性强。

### Decision 3: 数据存储位置

**选择**: 运行时数据在 CropManager 内部 `_crops: Dictionary`（Vector2i → crop_data），每次变更同步到 `GameManager.farm_data`

**理由**: CropManager 作为单一写入者保证数据一致性。GameManager.farm_data 作为持久化出口，供 SaveManager 使用。避免两处数据源冲突。

### Decision 4: 枯萎判定使用系统时间

**选择**: 使用 `Time.get_datetime_dict_from_system()` 获取自然日期进行零点判定

**理由**: PRD7（游戏内时间）尚未实现，使用系统真实时间可解耦。接口设计为内部方法 `_get_current_date()`，PRD7 完成后只需替换该方法实现。

### Decision 5: GameManager 扩展方式

**选择**: 直接在现有 GameManager 中添加 `farm_data`、`stats`、inventory 操作方法

**理由**: 这些是 GameManager 的自然职责（全局玩家数据管理）。拆分为独立 Manager 会增加不必要的间接层，且 PRD1 已将 GameManager 定位为数据中心。

## Risks / Trade-offs

- **[系统时钟篡改]** → 玩家修改系统时间可跳过生长等待或避免枯萎。缓解：当前为单机休闲游戏，不做反作弊。后续可引入服务端时间校验。

- **[信号参数不一致]** → EventBus 现有 crop_watered 信号参数为 `(tile_pos: Vector2i)` 而 PRD2 需要 `(tile_pos, crop_id)`。缓解：本次修改 EventBus 信号签名以匹配 PRD2 需求。

- **[离线补偿边界]** → 离线超长时间（数天）只会推进一个阶段然后停止（等待浇水），玩家回来可能困惑。缓解：后续 PRD 可添加 UI 提示说明离线期间发生了什么。

## File Changes

| 操作 | 文件 | 说明 |
|------|------|------|
| 新增 | `scripts/autoload/crop_manager.gd` | CropManager 单例 |
| 修改 | `scripts/autoload/game_manager.gd` | 添加 farm_data, stats, inventory 方法, add_xp |
| 修改 | `scripts/autoload/event_bus.gd` | 修正 crop 信号参数签名 |
| 修改 | `project.godot` | 注册 CropManager Autoload |
| 新增 | `scenes/test/test_crop_manager.tscn` | 测试场景 |
| 新增 | `scenes/test/test_crop_manager.gd` | 自动化测试脚本 |
