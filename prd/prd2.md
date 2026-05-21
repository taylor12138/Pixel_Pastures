# PRD2: 作物生长状态机 + 浇水/枯萎逻辑

> **优先级**: P0 — 核心玩法基础
> **美术依赖**: 无（纯逻辑/数据层，无视觉表现）
> **预计工期**: 4-6 天
> **前置依赖**: PRD1（项目骨架 + 核心数据系统）
> **产出**: CropManager 全局单例 + 作物状态机 + 浇水/枯萎逻辑 + 单元测试场景
> **最后更新**: 2026-04-30

---

## 1. 目标

实现《像素田园》的作物生长核心系统，包含：
- 作物 5 状态机（种子 → 发芽 → 生长中 → 成熟 → 枯萎）
- 浇水驱动的生长机制（不浇水不生长）
- 枯萎判定逻辑（成熟后跨越次日零点未收获则枯萎）
- 离线补偿计算（玩家离线期间的时间推进）
- 地块状态管理（种植/清除/查询）

完成后，可通过代码调用完成完整的「种植 → 浇水 → 等待 → 成熟 → 收获/枯萎」循环，并通过 EventBus 广播所有状态变更。

---

## 2. 核心设计决策（已确认）

以下决策直接约束本 PRD 的实现方式：

| 决策 | 内容 | 来源 |
|------|------|------|
| 浇水为必须操作 | 不浇水作物不会生长，停留在当前阶段 | 《开放问题-回答.md》问题 2 |
| 隔天枯萎 | 成熟后自然时间跨越次日零点未收获则枯萎 | 《开放问题-回答.md》问题 1 |
| 枯萎为软惩罚 | 不扣经验、不扣金币，仅损失该次收益 | 《游戏设计文档》6.2 |
| 每阶段浇水一次 | 每个生长阶段切换都需要玩家手动浇水一次 | 《游戏设计文档》6.2 |
| 时间戳驱动 | 使用真实时间戳记录浇水时间，据此计算阶段推进 | 《游戏设计文档》11.4 |

---

## 3. 功能需求

### 3.1 作物状态机

#### 3.1.1 状态定义

```gdscript
enum CropStage {
    SEED = 0,      # 种子/待浇水 — 已播种，等待第一次浇水
    SPROUT = 1,    # 发芽 — 第一次浇水后开始计时
    GROWING = 2,   # 生长中 — 第二次浇水后开始计时
    MATURE = 3,    # 成熟 — 第三次浇水后到时间，可收获
    WITHERED = 4,  # 枯萎 — 成熟后隔天未收获，仅可清除
}
```

#### 3.1.2 状态转移图

```
                  浇水              计时完成            浇水              计时完成            浇水              计时完成
  [种植] → SEED ------→ SEED(已浇水) --------→ SPROUT ------→ SPROUT(已浇水) --------→ GROWING ------→ GROWING(已浇水) --------→ MATURE
                                                                                                                                  │
                                                                                                                                  │ 跨越次日零点
                                                                                                                                  │ 未收获
                                                                                                                                  ▼
                                                                                                                              WITHERED
                                                                                                                                  │
                                                                                                                                  │ 清除
                                                                                                                                  ▼
                                                                                                                              [空地]
  
  MATURE ──(收获)──→ [空地] + 获得作物
```

**关键规则**:
1. 每个阶段（SEED / SPROUT / GROWING）都有「未浇水」和「已浇水」两个子状态
2. 未浇水时作物冻结在当前阶段，不会推进
3. 浇水后记录 `water_timestamp`，当 `当前时间 >= water_timestamp + growth_time_per_stage` 时推进到下一阶段
4. 推进后重置为未浇水状态，等待下一次浇水
5. MATURE 阶段无需浇水，但需在当天收获，否则跨零点后枯萎

#### 3.1.3 作物数据结构

每块地的作物运行时数据：

```gdscript
## 单块地的作物运行时状态
var crop_data := {
    "crop_id": "",                # 作物 ID（对应 crops.json 的 key）
    "stage": CropStage.SEED,      # 当前生长阶段
    "watered": false,             # 当前阶段是否已浇水
    "water_timestamp": 0.0,       # 最后一次浇水的 Unix 时间戳
    "water_count": 0,             # 累计浇水次数
    "planted_timestamp": 0.0,     # 种下时间戳
    "mature_timestamp": 0.0,      # 进入成熟阶段的时间戳（用于枯萎判定）
}
```

### 3.2 CropManager 全局单例

新增 `scripts/autoload/crop_manager.gd`，注册为 Autoload。

**职责**:
- 管理所有地块的作物状态
- 处理种植/浇水/收获/清除操作
- 驱动生长计时（每帧检查或定时检查）
- 驱动枯萎判定
- 通过 EventBus 广播所有状态变更
- 提供查询接口

#### 3.2.1 公共接口

```gdscript
extends Node

# ─── 核心操作 ───

## 在指定地块种植作物
## 返回 true 表示种植成功
func plant_crop(tile_pos: Vector2i, crop_id: String) -> bool

## 对指定地块浇水
## 返回 true 表示浇水成功（地块有作物且当前阶段未浇水且不是成熟/枯萎）
func water_crop(tile_pos: Vector2i) -> bool

## 收获指定地块的成熟作物
## 返回收获的作物 ID，失败返回空字符串
func harvest_crop(tile_pos: Vector2i) -> String

## 清除指定地块（枯萎作物或任意作物）
## 返回 true 表示清除成功
func clear_crop(tile_pos: Vector2i) -> bool

# ─── 查询接口 ───

## 获取指定地块的作物数据，无作物返回空字典
func get_crop_data(tile_pos: Vector2i) -> Dictionary

## 指定地块是否有作物
func has_crop(tile_pos: Vector2i) -> bool

## 指定地块的作物是否可收获
func is_harvestable(tile_pos: Vector2i) -> bool

## 指定地块的作物是否需要浇水
func needs_water(tile_pos: Vector2i) -> bool

## 获取指定地块作物的生长进度（0.0 ~ 1.0），未浇水返回 0.0
func get_growth_progress(tile_pos: Vector2i) -> float

## 获取所有地块数据（用于存档/UI 渲染）
func get_all_crops() -> Dictionary

## 获取所有成熟作物的地块列表
func get_mature_crops() -> Array[Vector2i]

## 获取所有需要浇水的地块列表
func get_crops_needing_water() -> Array[Vector2i]

# ─── 批量操作 ───

## 离线补偿：根据离线时长批量推进所有作物状态
func process_offline_time(last_online_timestamp: float) -> void

## 零点检查：将所有成熟超期作物标记为枯萎
func check_wither_all() -> void

# ─── 存档集成 ───

## 导出所有作物数据（用于存档）
func export_save_data() -> Dictionary

## 导入作物数据（用于读档）
func import_save_data(data: Dictionary) -> void
```

#### 3.2.2 详细行为规范

##### `plant_crop(tile_pos, crop_id)`

前置条件：
- 地块上无作物（`has_crop(tile_pos) == false`）
- `crop_id` 在 `DataManager` 中存在
- 玩家背包中有对应种子（`GameManager.has_item("seed_" + crop_id)`）

行为：
1. 从背包扣除 1 个对应种子
2. 创建作物数据，阶段设为 `SEED`，`watered = false`
3. 记录 `planted_timestamp = 当前 Unix 时间`
4. 同步到 `GameManager.farm_data`
5. 发射 `EventBus.crop_planted(tile_pos, crop_id)`
6. 返回 `true`

失败时返回 `false`，不修改任何状态。

##### `water_crop(tile_pos)`

前置条件：
- 地块上有作物
- 作物阶段为 SEED / SPROUT / GROWING（即非 MATURE、非 WITHERED）
- 当前阶段尚未浇水（`watered == false`）

行为：
1. 设置 `watered = true`
2. 记录 `water_timestamp = 当前 Unix 时间`
3. 增加 `water_count += 1`
4. 更新 `GameManager.stats["total_water_count"]`
5. 发射 `EventBus.crop_watered(tile_pos, crop_id)`
6. 返回 `true`

失败时返回 `false`，不修改任何状态。

##### `harvest_crop(tile_pos)`

前置条件：
- 地块上有作物
- 作物阶段为 `MATURE`

行为：
1. 读取作物数据获取 `crop_id`
2. 将收获物添加到背包：`GameManager.add_item("harvest_" + crop_id, 1)`
3. 给予经验：`GameManager.add_xp(10, "harvest")`
4. 更新统计：`GameManager.stats["total_harvests"] += 1`
5. 清除地块作物数据
6. 同步 `GameManager.farm_data`
7. 发射 `EventBus.crop_harvested(tile_pos, crop_id, 1)`
8. 返回 `crop_id`

失败时返回空字符串。

##### `clear_crop(tile_pos)`

前置条件：
- 地块上有作物

行为：
1. 清除地块作物数据
2. 同步 `GameManager.farm_data`
3. 发射 `EventBus.crop_cleared(tile_pos)`
4. 返回 `true`

### 3.3 生长计时系统

#### 3.3.1 计时驱动方式

使用 `_process(delta)` 中定时轮询（每 1 秒检查一次，避免每帧计算开销）：

```gdscript
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 1.0  # 每秒检查一次

func _process(delta: float) -> void:
    if GameManager.current_state != GameManager.GameState.PLAYING:
        return
    _check_timer += delta
    if _check_timer >= CHECK_INTERVAL:
        _check_timer = 0.0
        _update_all_crops()
```

#### 3.3.2 阶段推进逻辑

`_update_all_crops()` 遍历所有地块，对每块地执行：

```
如果 作物已浇水 且 阶段 ∈ {SEED, SPROUT, GROWING}:
    当前时间 = Time.get_unix_time_from_system()
    经过时间 = 当前时间 - water_timestamp
    阶段所需时间 = DataManager.get_crop(crop_id)["growth_time_per_stage"]
    
    如果 经过时间 >= 阶段所需时间:
        推进到下一阶段 (stage += 1)
        重置 watered = false
        
        如果 新阶段 == MATURE:
            记录 mature_timestamp = 当前时间
            发射 EventBus.crop_matured(tile_pos, crop_id)
        否则:
            发射 EventBus.crop_grown(tile_pos, crop_id, stage)
```

#### 3.3.3 枯萎判定逻辑

在 `_update_all_crops()` 中同时检查：

```
如果 作物阶段 == MATURE:
    当前日期 = _get_current_date()
    成熟日期 = _timestamp_to_date(mature_timestamp)
    
    如果 当前日期 > 成熟日期:  # 跨越了零点
        标记为 WITHERED
        发射 EventBus.crop_withered(tile_pos, crop_id)
```

**日期比较方法**：

```gdscript
## 获取当前自然日期（年月日）
func _get_current_date() -> Dictionary:
    var datetime = Time.get_datetime_dict_from_system()
    return {"year": datetime["year"], "month": datetime["month"], "day": datetime["day"]}

## 将时间戳转换为日期
func _timestamp_to_date(timestamp: float) -> Dictionary:
    var datetime = Time.get_datetime_dict_from_unix_time(int(timestamp))
    return {"year": datetime["year"], "month": datetime["month"], "day": datetime["day"]}

## 比较两个日期是否为不同天
func _is_different_day(date_a: Dictionary, date_b: Dictionary) -> bool:
    return date_a["year"] != date_b["year"] \
        or date_a["month"] != date_b["month"] \
        or date_a["day"] != date_b["day"]
```

> **注意**: 枯萎使用**自然真实时间**（系统时钟），不依赖 PRD7 的游戏内时间系统。PRD7 实现后，此处可改为使用游戏内日期，但当前阶段直接使用系统时间即可。

### 3.4 离线补偿

玩家重新上线时（游戏启动、读档后），调用 `process_offline_time()` 对所有作物进行时间追赶：

```
对每块有作物的地块:
    如果 作物已浇水 且 阶段 ∈ {SEED, SPROUT, GROWING}:
        循环推进阶段，直到时间用尽或到达 MATURE:
            剩余时间 = 当前时间 - water_timestamp
            如果 剩余时间 >= growth_time_per_stage:
                推进到下一阶段
                如果 新阶段 ∈ {SPROUT, GROWING}:
                    # 离线期间无法浇水，停留在此阶段
                    watered = false
                    跳出循环
                如果 新阶段 == MATURE:
                    记录 mature_timestamp
                    进行枯萎判定

    如果 作物阶段 == MATURE:
        执行枯萎判定（同 3.3.3）
```

**关键约束**: 离线期间玩家无法浇水，所以每次离线最多推进一个阶段（当前已浇水阶段完成后，进入下一阶段等待浇水）。

### 3.5 与 EventBus 的信号交互

#### 3.5.1 CropManager 发射的信号

| 信号 | 时机 | 参数 |
|------|------|------|
| `crop_planted` | 成功种植 | `tile_pos, crop_id` |
| `crop_watered` | 成功浇水 | `tile_pos, crop_id` |
| `crop_grown` | 阶段推进（非成熟） | `tile_pos, crop_id, stage` |
| `crop_matured` | 进入成熟阶段 | `tile_pos, crop_id` |
| `crop_harvested` | 成功收获 | `tile_pos, crop_id, amount` |
| `crop_withered` | 枯萎 | `tile_pos, crop_id` |
| `crop_cleared` | 清除地块 | `tile_pos` |

#### 3.5.2 CropManager 监听的信号

| 信号 | 来源 | 用途 |
|------|------|------|
| `midnight_crossed` | 时间系统（PRD7） | 触发全体枯萎检查 |
| `game_loaded` | GameManager | 触发离线补偿 |

> **PRD7 未实现时**: `midnight_crossed` 信号暂时不会被发射，CropManager 通过自身每秒轮询中的日期比较来检测跨天。PRD7 实现后可改为信号驱动。

### 3.6 与 GameManager 的数据同步

CropManager 是作物逻辑的唯一入口，但存档数据存储在 `GameManager.farm_data` 中。同步规则：

1. **写入**: CropManager 每次修改作物状态后，立即同步到 `GameManager.farm_data`
2. **读取**: CropManager 初始化时从 `GameManager.farm_data` 加载
3. **存档键格式**: `"x,y"` 字符串（与 GameManager 现有格式一致）

```gdscript
## 内部地块字典（运行时权威数据）
var _crops: Dictionary = {}  # Vector2i -> crop_data Dictionary

## 同步到 GameManager
func _sync_to_game_manager() -> void:
    var save_data: Dictionary = {}
    for pos in _crops:
        var key := "%d,%d" % [pos.x, pos.y]
        save_data[key] = _crops[pos].duplicate(true)
    GameManager.farm_data = save_data

## 从 GameManager 加载
func _load_from_game_manager() -> void:
    _crops.clear()
    for key in GameManager.farm_data:
        var parts := key.split(",")
        if parts.size() == 2:
            var pos := Vector2i(int(parts[0]), int(parts[1]))
            _crops[pos] = GameManager.farm_data[key].duplicate(true)
```

### 3.7 Autoload 注册

在 `project.godot` 中新增 CropManager 自动加载，注册顺序更新为：

```
1. EventBus
2. DataManager
3. GameManager
4. CropManager     ← 新增（依赖 DataManager 和 GameManager）
5. SceneManager
6. SaveManager     (占位)
7. AudioManager    (占位)
```

---

## 4. 验收标准

### 4.1 种植验收

- [ ] 调用 `CropManager.plant_crop(Vector2i(0,0), "carrot")` 成功种植
- [ ] 种植后背包中对应种子数量减 1
- [ ] 种植后 `EventBus.crop_planted` 信号被发射
- [ ] 地块无作物时可种植，有作物时种植返回 `false`
- [ ] 背包无种子时种植返回 `false`
- [ ] `DataManager` 中不存在的 `crop_id` 种植返回 `false`

### 4.2 浇水验收

- [ ] SEED 阶段未浇水时，调用 `water_crop()` 返回 `true`，`watered` 变为 `true`
- [ ] 已浇水的地块再次浇水返回 `false`
- [ ] MATURE 阶段浇水返回 `false`
- [ ] WITHERED 阶段浇水返回 `false`
- [ ] 浇水后 `EventBus.crop_watered` 信号被发射
- [ ] 浇水后 `GameManager.stats["total_water_count"]` 增加

### 4.3 生长推进验收

- [ ] 浇水后等待 `growth_time_per_stage` 秒，作物自动推进到下一阶段
- [ ] 阶段推进后 `watered` 重置为 `false`
- [ ] 阶段从 SEED → SPROUT 时发射 `crop_grown` 信号，`stage = 1`
- [ ] 阶段从 SPROUT → GROWING 时发射 `crop_grown` 信号，`stage = 2`
- [ ] 阶段从 GROWING → MATURE 时发射 `crop_matured` 信号
- [ ] 未浇水的作物不会推进（等待任意时长仍停留在原阶段）

### 4.4 收获验收

- [ ] MATURE 阶段调用 `harvest_crop()` 返回作物 ID
- [ ] 收获后背包增加对应收获物（`harvest_carrot` 等）
- [ ] 收获后获得 10 XP
- [ ] 收获后 `total_harvests` 统计增加
- [ ] 收获后地块变为空（`has_crop()` 返回 `false`）
- [ ] 收获后 `EventBus.crop_harvested` 信号被发射
- [ ] 非 MATURE 阶段收获返回空字符串

### 4.5 枯萎验收

- [ ] MATURE 状态的作物跨越自然日零点后变为 WITHERED
- [ ] 枯萎后 `EventBus.crop_withered` 信号被发射
- [ ] 枯萎作物不可收获（`harvest_crop()` 返回空字符串）
- [ ] 枯萎作物不可浇水（`water_crop()` 返回 `false`）
- [ ] 枯萎作物可清除（`clear_crop()` 返回 `true`）
- [ ] 枯萎不扣经验、不扣金币

### 4.6 清除验收

- [ ] 清除后地块变为空
- [ ] 清除后 `EventBus.crop_cleared` 信号被发射
- [ ] 空地块清除返回 `false`

### 4.7 离线补偿验收

- [ ] 离线期间已浇水的阶段正常推进（最多推进一个阶段）
- [ ] 离线期间未浇水的阶段保持不动
- [ ] 离线期间成熟超过一天的作物标记为枯萎
- [ ] 读档后自动执行离线补偿

### 4.8 数据同步验收

- [ ] CropManager 的操作实时同步到 `GameManager.farm_data`
- [ ] 存档后重新加载，作物状态完整恢复
- [ ] `get_all_crops()` 返回所有地块数据

### 4.9 查询接口验收

- [ ] `needs_water()` 对未浇水的 SEED/SPROUT/GROWING 返回 `true`
- [ ] `is_harvestable()` 仅对 MATURE 返回 `true`
- [ ] `get_growth_progress()` 返回 0.0~1.0 的正确进度值
- [ ] `get_mature_crops()` 返回所有成熟作物的坐标列表
- [ ] `get_crops_needing_water()` 返回所有需要浇水的坐标列表

---

## 5. 测试场景

创建 `scenes/test/test_crop_manager.tscn` 和对应脚本 `test_crop_manager.gd`，用于验证 CropManager 的全部逻辑。

### 5.1 测试场景结构

```
test_crop_manager.tscn
└── TestCropManager (Node2D)
    └── Label (显示测试结果)
```

### 5.2 测试用例

测试脚本应在 `_ready()` 中依次执行以下自动化测试：

```gdscript
func _ready() -> void:
    print("=== CropManager 自动化测试 ===")
    
    # 准备：给背包添加测试种子
    GameManager.add_item("seed_carrot", 5)
    GameManager.add_item("seed_tomato", 3)
    
    test_plant_success()
    test_plant_no_seed()
    test_plant_occupied()
    test_plant_invalid_crop()
    test_water_success()
    test_water_already_watered()
    test_water_mature()
    test_harvest_mature()
    test_harvest_not_mature()
    test_clear_crop()
    test_clear_empty()
    test_query_needs_water()
    test_query_is_harvestable()
    
    print("=== 全部测试完成 ===")
```

每个测试函数应：
1. 设置前置条件
2. 执行操作
3. 用 `assert()` 验证结果
4. 清理状态（清除测试地块）
5. 打印通过信息

> **生长推进和枯萎测试**: 因依赖真实时间等待，这两类测试建议手动执行或使用加速时间的辅助方法。可在 CropManager 中提供 `_debug_advance_time(tile_pos, seconds)` 仅在调试模式下可用的接口。

### 5.3 调试辅助接口（仅开发期间使用）

```gdscript
## [调试] 手动推进指定地块的时间，模拟经过 seconds 秒
## 仅在 OS.is_debug_build() 为 true 时可用
func debug_advance_time(tile_pos: Vector2i, seconds: float) -> void

## [调试] 强制触发枯萎检查
func debug_force_wither_check() -> void

## [调试] 打印所有地块状态
func debug_print_all() -> void
```

---

## 6. 技术约束

1. **时间源**:
   - 生长计时使用 `Time.get_unix_time_from_system()` 作为时间源
   - 枯萎判定使用 `Time.get_datetime_dict_from_system()` 获取自然日期
   - PRD7 实现后可切换为游戏内时间，但接口保持不变

2. **性能**:
   - 轮询间隔 1 秒，避免每帧遍历
   - 最大地块数 80（8×10），每秒遍历 80 项无性能压力
   - 地块数据使用 `Dictionary`（Vector2i → crop_data），O(1) 查找

3. **数据不可变原则**:
   - CropManager 读取 DataManager 的作物配置为只读
   - 运行时状态仅在 CropManager 内部维护
   - 外部只能通过公共接口修改作物状态

4. **信号优先原则**:
   - 所有状态变更通过 EventBus 广播
   - 不直接引用 UI 或场景节点

5. **编码规范**:
   - 使用 `class_name CropManager` 注册
   - 变量 snake_case，常量 UPPER_SNAKE_CASE
   - 所有公开方法需有简短注释

---

## 7. 非目标 (Not in Scope)

以下内容**不在** PRD2 范围内：

- 地块的视觉表现（TileMap、颜色变化等）→ PRD8
- 角色种植/浇水/收获动画 → PRD9、PRD15
- 背包 UI（背包数据操作使用 GameManager 现有接口）→ PRD3、PRD11
- 种子购买逻辑（商店系统）→ PRD4
- 经验获取除收获外的其他来源 → PRD5
- 游戏内时间流逝 / 昼夜 / 季节 → PRD7
- 存档系统完整实现 → PRD6
- 偷菜逻辑 → PRD22

PRD2 的目标是：**让作物的完整生命周期逻辑可以通过纯代码调用跑通，后续 PRD 可在此基础上叠加视觉和交互。**

---

## 8. 后续衔接

| 完成 PRD2 后可启动 | 说明 |
|-------------------|------|
| → PRD8 (田园场景) | 用 TileMap 色块可视化地块状态，调用 CropManager 查询数据渲染 |
| → PRD10 (种植交互) | 整合角色操作 + CropManager，实现点击种植/浇水/收获的完整交互流程 |
| → PRD3 (背包数据层) | 已使用 GameManager 的背包接口，PRD3 将扩展为完整背包系统 |

---

## 附录 A: crops.json 字段参考

PRD2 使用 `DataManager.get_crop(crop_id)` 读取以下字段：

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `id` | String | 作物唯一标识 | `"carrot"` |
| `name` | String | 中文名 | `"胡萝卜"` |
| `seed_price` | int | 种子价格 | `10` |
| `sell_price` | int | 收获出售价格 | `25` |
| `growth_time_per_stage` | int | 每阶段生长时间（秒） | `10` |
| `total_water_count` | int | 总浇水次数（固定为 3） | `3` |
| `seasons` | Array | 可种植季节 | `["spring", "autumn"]` |
| `unlock_level` | int | 解锁所需等级 | `1` |

---

## 附录 B: 完整生命周期示例

以胡萝卜（`growth_time_per_stage = 10 秒`）为例：

```
时间 T+0s:   plant_crop(pos, "carrot")    → SEED, watered=false
时间 T+5s:   water_crop(pos)               → SEED, watered=true, water_timestamp=T+5
时间 T+15s:  (自动推进)                     → SPROUT, watered=false
时间 T+20s:  water_crop(pos)               → SPROUT, watered=true, water_timestamp=T+20
时间 T+30s:  (自动推进)                     → GROWING, watered=false
时间 T+35s:  water_crop(pos)               → GROWING, watered=true, water_timestamp=T+35
时间 T+45s:  (自动推进)                     → MATURE, mature_timestamp=T+45
时间 T+45s~次日零点前:  harvest_crop(pos)   → 收获成功，获得 harvest_carrot + 10XP
        或
次日零点后:  (自动判定)                     → WITHERED
             clear_crop(pos)               → 地块清空
```

---

> *本 PRD 完成后，作物的完整「种植 → 浇水 → 等待 → 成熟 → 收获/枯萎」循环可通过代码验证，为后续场景渲染和交互系统提供稳固的数据基础。*
