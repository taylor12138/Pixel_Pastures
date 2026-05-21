# PRD1: 项目骨架 + 核心数据系统

> **优先级**: P0 — 所有后续 PRD 的基础
> **美术依赖**: ❌ 无（纯代码/配置）
> **预计工期**: 3-5 天
> **前置依赖**: 无
> **产出**: 可运行的 Godot 4.4 空项目 + 全局管理器 + 数据加载系统
> **最后更新**: 2026-04-28

---

## 1. 目标

建立《像素田园》的 Godot 4.4 项目骨架，包含：
- 正确的项目配置（像素风必需设置）
- 完整的目录结构
- InputMap 输入映射
- 全局单例（Autoload）框架
- 游戏数据表加载系统（JSON → GDScript 数据对象）
- 信号总线（事件系统）

完成后，项目应能正常运行（显示空场景），所有全局管理器已注册并可通过代码访问。

---

## 2. 功能需求

### 2.1 Godot 项目配置

#### 2.1.1 project.godot 关键设置

| 配置项 | 值 | 说明 |
|--------|---|------|
| `display/window/size/viewport_width` | 480 | 基础分辨率宽 |
| `display/window/size/viewport_height` | 320 | 基础分辨率高 |
| `display/window/size/window_width_override` | 1920 | 实际窗口宽(4x) |
| `display/window/size/window_height_override` | 1280 | 实际窗口高(4x) |
| `display/window/stretch/mode` | `viewport` | 像素完美缩放 |
| `display/window/stretch/aspect` | `keep` | 保持纵横比 |
| `rendering/textures/canvas_textures/default_texture_filter` | `0` (Nearest) | 像素风必须 |
| `rendering/renderer/rendering_method` | `gl_compatibility` | 兼容模式 |
| `display/window/size/resizable` | `true` | 允许窗口缩放 |
| `editor/grid/size` | 16 | 编辑器网格对齐 16px |

#### 2.1.2 InputMap 配置

以下 Action 必须在 project.godot 中预定义：

```
move_up:       W, Up
move_down:     S, Down
move_left:     A, Left
move_right:    D, Right
interact:      E
cancel:        Mouse Right, Escape
open_bag:      Tab
open_map:      M
open_menu:     Escape
hotbar_1:      1
hotbar_2:      2
hotbar_3:      3
hotbar_4:      4
hotbar_5:      5
hotbar_6:      6
hotbar_7:      7
hotbar_8:      8
hotbar_9:      9
zoom_in:       Mouse Wheel Up
zoom_out:      Mouse Wheel Down
```

### 2.2 目录结构

```
pixel-farm/
├── project.godot
├── scenes/
│   ├── main.tscn                    # 入口场景（仅含 Node2D）
│   ├── farm/
│   ├── room/
│   ├── shop/
│   └── plaza/
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd          # 全局游戏状态
│   │   ├── data_manager.gd          # 数据表加载
│   │   ├── event_bus.gd             # 信号总线
│   │   ├── save_manager.gd          # 存档管理 (PRD6 实现，此处仅注册)
│   │   └── audio_manager.gd         # 音频管理 (PRD19 实现，此处仅注册)
│   ├── crop/
│   ├── character/
│   ├── social/
│   ├── inventory/
│   └── ui/
├── assets/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── crops/
│   │   ├── animals/
│   │   └── vfx/
│   ├── tilesets/
│   ├── audio/
│   │   ├── bgm/
│   │   ├── sfx/
│   │   └── ambient/
│   ├── ui/
│   │   ├── icons/
│   │   ├── panels/
│   │   └── buttons/
│   └── fonts/
├── data/
│   ├── crops.json
│   ├── items.json
│   ├── levels.json
│   └── achievements.json
├── addons/
└── export_presets.cfg
```

### 2.3 全局单例 (Autoload)

#### 2.3.1 GameManager (`game_manager.gd`)

全局游戏状态管理器。

**职责**:
- 维护当前游戏状态（主菜单 / 游戏中 / 暂停）
- 持有玩家核心数据引用（金币、等级、经验）
- 提供游戏初始化/重置方法

**接口**:

```gdscript
# 游戏状态枚举
enum GameState { MAIN_MENU, PLAYING, PAUSED }

# 属性
var current_state: GameState
var player_gold: int = 100           # 初始金币
var player_level: int = 1
var player_xp: int = 0
var player_energy: int = 100         # 精力值
var player_max_energy: int = 100

# 方法
func start_new_game() -> void        # 初始化新游戏
func pause_game() -> void            # 暂停
func resume_game() -> void           # 恢复
func reset_to_default() -> void      # 重置所有数据
```

#### 2.3.2 DataManager (`data_manager.gd`)

数据表加载器。从 `data/` 目录读取 JSON 文件并解析为 GDScript 字典/数组。

**职责**:
- 启动时加载所有 JSON 数据表
- 提供按 ID/名称查询数据的接口
- 数据只读，不可运行时修改

**接口**:

```gdscript
# 属性 (加载后的数据)
var crops: Dictionary = {}           # crop_id -> CropData
var items: Dictionary = {}           # item_id -> ItemData
var levels: Array = []               # [LevelData, ...]
var achievements: Dictionary = {}    # achievement_id -> AchievementData

# 方法
func load_all_data() -> void                    # 启动时调用
func get_crop(crop_id: String) -> Dictionary    # 获取作物数据
func get_item(item_id: String) -> Dictionary    # 获取道具数据
func get_level_data(level: int) -> Dictionary   # 获取等级数据
func get_all_crops() -> Array                   # 获取所有作物列表
func get_crops_by_season(season: String) -> Array  # 按季节查询
func get_unlocked_crops(player_level: int) -> Array # 按等级查询可用作物
```

#### 2.3.3 EventBus (`event_bus.gd`)

全局信号总线，用于解耦各系统间通信。

**职责**:
- 定义全局信号
- 各系统通过 EventBus emit/connect，避免直接耦合

**信号定义**:

```gdscript
# 作物相关
signal crop_planted(tile_pos: Vector2i, crop_id: String)
signal crop_watered(tile_pos: Vector2i)
signal crop_grown(tile_pos: Vector2i, new_stage: int)
signal crop_matured(tile_pos: Vector2i, crop_id: String)
signal crop_harvested(tile_pos: Vector2i, crop_id: String, amount: int)
signal crop_withered(tile_pos: Vector2i)
signal crop_cleared(tile_pos: Vector2i)

# 经济相关
signal gold_changed(new_amount: int, delta: int)
signal item_purchased(item_id: String, price: int)
signal item_sold(item_id: String, price: int)

# 背包相关
signal inventory_changed(slot_index: int)
signal inventory_full()

# 等级相关
signal xp_gained(amount: int, new_total: int)
signal level_up(new_level: int, unlocks: Array)

# 时间相关
signal hour_changed(new_hour: int)
signal day_changed(new_day: int)
signal season_changed(new_season: String)
signal midnight_crossed()          # 跨越零点（枯萎检测用）

# 交互相关
signal interaction_started(target: Node)
signal interaction_ended()

# 存档相关
signal game_saved()
signal game_loaded()
```

#### 2.3.4 SaveManager (`save_manager.gd`) — 框架占位

```gdscript
# PRD6 中实现具体逻辑，此处仅提供空框架

func save_game(slot: int = 0) -> bool:
    push_warning("SaveManager: 尚未实现 (PRD6)")
    return false

func load_game(slot: int = 0) -> bool:
    push_warning("SaveManager: 尚未实现 (PRD6)")
    return false

func has_save(slot: int = 0) -> bool:
    return false
```

#### 2.3.5 AudioManager (`audio_manager.gd`) — 框架占位

```gdscript
# PRD19 中实现具体逻辑，此处仅提供空框架

func play_bgm(track_name: String) -> void:
    push_warning("AudioManager: 尚未实现 (PRD19)")

func play_sfx(sfx_name: String) -> void:
    push_warning("AudioManager: 尚未实现 (PRD19)")

func stop_bgm() -> void:
    pass
```

### 2.4 数据表定义 (JSON Schema)

#### 2.4.1 `data/crops.json`

```json
{
  "carrot": {
    "id": "carrot",
    "name": "胡萝卜",
    "name_en": "Carrot",
    "seed_price": 10,
    "sell_price": 25,
    "growth_time_per_stage": 10,
    "total_water_count": 3,
    "seasons": ["spring", "autumn"],
    "unlock_level": 1,
    "description": "基础作物，生长快速"
  },
  "tomato": {
    "id": "tomato",
    "name": "番茄",
    "name_en": "Tomato",
    "seed_price": 15,
    "sell_price": 40,
    "growth_time_per_stage": 15,
    "total_water_count": 3,
    "seasons": ["summer"],
    "unlock_level": 2,
    "description": "夏季作物，收益不错"
  },
  "cabbage": {
    "id": "cabbage",
    "name": "白菜",
    "name_en": "Cabbage",
    "seed_price": 8,
    "sell_price": 20,
    "growth_time_per_stage": 8,
    "total_water_count": 3,
    "seasons": ["autumn", "winter"],
    "unlock_level": 1,
    "description": "便宜实惠的基础作物"
  },
  "corn": {
    "id": "corn",
    "name": "玉米",
    "name_en": "Corn",
    "seed_price": 20,
    "sell_price": 55,
    "growth_time_per_stage": 20,
    "total_water_count": 3,
    "seasons": ["summer"],
    "unlock_level": 1,
    "description": "生长较慢但收益高"
  },
  "potato": {
    "id": "potato",
    "name": "土豆",
    "name_en": "Potato",
    "seed_price": 12,
    "sell_price": 30,
    "growth_time_per_stage": 13,
    "total_water_count": 3,
    "seasons": ["spring", "autumn"],
    "unlock_level": 1,
    "description": "朴实可靠的根茎作物"
  },
  "strawberry": {
    "id": "strawberry",
    "name": "草莓",
    "name_en": "Strawberry",
    "seed_price": 25,
    "sell_price": 65,
    "growth_time_per_stage": 17,
    "total_water_count": 3,
    "seasons": ["spring"],
    "unlock_level": 3,
    "description": "春季限定，高收益"
  },
  "pepper": {
    "id": "pepper",
    "name": "辣椒",
    "name_en": "Pepper",
    "seed_price": 18,
    "sell_price": 45,
    "growth_time_per_stage": 18,
    "total_water_count": 3,
    "seasons": ["summer"],
    "unlock_level": 4,
    "description": "火辣的夏季作物"
  },
  "pumpkin": {
    "id": "pumpkin",
    "name": "南瓜",
    "name_en": "Pumpkin",
    "seed_price": 35,
    "sell_price": 90,
    "growth_time_per_stage": 30,
    "total_water_count": 3,
    "seasons": ["autumn"],
    "unlock_level": 5,
    "description": "秋季之王，最高收益"
  },
  "eggplant": {
    "id": "eggplant",
    "name": "茄子",
    "name_en": "Eggplant",
    "seed_price": 22,
    "sell_price": 50,
    "growth_time_per_stage": 22,
    "total_water_count": 3,
    "seasons": ["summer"],
    "unlock_level": 4,
    "description": "紫色的夏日蔬菜"
  },
  "broccoli": {
    "id": "broccoli",
    "name": "西兰花",
    "name_en": "Broccoli",
    "seed_price": 28,
    "sell_price": 60,
    "growth_time_per_stage": 23,
    "total_water_count": 3,
    "seasons": ["spring", "autumn"],
    "unlock_level": 6,
    "description": "高级蔬菜，营养丰富"
  }
}
```

#### 2.4.2 `data/levels.json`

```json
[
  {
    "level": 1,
    "name": "新手农夫",
    "xp_required": 0,
    "unlocks": {
      "crops": ["carrot", "cabbage", "corn", "potato"],
      "features": ["basic_farm"],
      "farm_slots": 12
    }
  },
  {
    "level": 2,
    "name": "小园丁",
    "xp_required": 100,
    "unlocks": {
      "crops": ["tomato"],
      "features": ["watering_can_upgrade"],
      "farm_slots": 16
    }
  },
  {
    "level": 3,
    "name": "种植能手",
    "xp_required": 250,
    "unlocks": {
      "crops": ["strawberry"],
      "features": ["decoration_mode"],
      "farm_slots": 24
    }
  },
  {
    "level": 4,
    "name": "田园达人",
    "xp_required": 500,
    "unlocks": {
      "crops": ["pepper", "eggplant"],
      "features": ["steal_crops", "expand_land"],
      "farm_slots": 36
    }
  },
  {
    "level": 5,
    "name": "农场主",
    "xp_required": 800,
    "unlocks": {
      "crops": ["pumpkin"],
      "features": ["animal_companion"],
      "farm_slots": 48
    }
  },
  {
    "level": 6,
    "name": "园艺大师",
    "xp_required": 1200,
    "unlocks": {
      "crops": ["broccoli"],
      "features": ["public_plaza"],
      "farm_slots": 64
    }
  },
  {
    "level": 7,
    "name": "传说农夫",
    "xp_required": 1800,
    "unlocks": {
      "crops": [],
      "features": ["golden_decoration", "special_title"],
      "farm_slots": 80
    }
  }
]
```

#### 2.4.3 `data/items.json`

```json
{
  "watering_can": {
    "id": "watering_can",
    "name": "水壶",
    "type": "tool",
    "stackable": false,
    "max_stack": 1,
    "description": "浇灌作物的基本工具"
  },
  "seed_carrot": {
    "id": "seed_carrot",
    "name": "胡萝卜种子",
    "type": "seed",
    "crop_id": "carrot",
    "stackable": true,
    "max_stack": 99,
    "description": "种下后浇水即可生长"
  },
  "seed_tomato": {
    "id": "seed_tomato",
    "name": "番茄种子",
    "type": "seed",
    "crop_id": "tomato",
    "stackable": true,
    "max_stack": 99,
    "description": "夏季种植效果最佳"
  },
  "seed_cabbage": {
    "id": "seed_cabbage",
    "name": "白菜种子",
    "type": "seed",
    "crop_id": "cabbage",
    "stackable": true,
    "max_stack": 99,
    "description": "秋冬季的好选择"
  },
  "seed_corn": {
    "id": "seed_corn",
    "name": "玉米种子",
    "type": "seed",
    "crop_id": "corn",
    "stackable": true,
    "max_stack": 99,
    "description": "高大的夏季作物"
  },
  "seed_potato": {
    "id": "seed_potato",
    "name": "土豆种子",
    "type": "seed",
    "crop_id": "potato",
    "stackable": true,
    "max_stack": 99,
    "description": "春秋两季皆可种植"
  },
  "seed_strawberry": {
    "id": "seed_strawberry",
    "name": "草莓种子",
    "type": "seed",
    "crop_id": "strawberry",
    "stackable": true,
    "max_stack": 99,
    "description": "春季限定高价值作物"
  },
  "seed_pepper": {
    "id": "seed_pepper",
    "name": "辣椒种子",
    "type": "seed",
    "crop_id": "pepper",
    "stackable": true,
    "max_stack": 99,
    "description": "火辣的夏季作物"
  },
  "seed_pumpkin": {
    "id": "seed_pumpkin",
    "name": "南瓜种子",
    "type": "seed",
    "crop_id": "pumpkin",
    "stackable": true,
    "max_stack": 99,
    "description": "秋季之王"
  },
  "seed_eggplant": {
    "id": "seed_eggplant",
    "name": "茄子种子",
    "type": "seed",
    "crop_id": "eggplant",
    "stackable": true,
    "max_stack": 99,
    "description": "紫色的夏日蔬菜"
  },
  "seed_broccoli": {
    "id": "seed_broccoli",
    "name": "西兰花种子",
    "type": "seed",
    "crop_id": "broccoli",
    "stackable": true,
    "max_stack": 99,
    "description": "高级蔬菜"
  },
  "harvest_carrot": {
    "id": "harvest_carrot",
    "name": "胡萝卜",
    "type": "harvest",
    "crop_id": "carrot",
    "stackable": true,
    "max_stack": 99,
    "sell_price": 25,
    "description": "新鲜收获的胡萝卜"
  },
  "harvest_tomato": {
    "id": "harvest_tomato",
    "name": "番茄",
    "type": "harvest",
    "crop_id": "tomato",
    "stackable": true,
    "max_stack": 99,
    "sell_price": 40,
    "description": "红彤彤的番茄"
  },
  "harvest_cabbage": {
    "id": "harvest_cabbage",
    "name": "白菜",
    "type": "harvest",
    "crop_id": "cabbage",
    "stackable": true,
    "max_stack": 99,
    "sell_price": 20,
    "description": "翠绿的大白菜"
  },
  "harvest_corn": {
    "id": "harvest_corn",
    "name": "玉米",
    "type": "harvest",
    "crop_id": "corn",
    "stackable": true,
    "max_stack": 99,
    "sell_price": 55,
    "description": "金黄的玉米棒"
  },
  "harvest_potato": {
    "id": "harvest_potato",
    "name": "土豆",
    "type": "harvest",
    "crop_id": "potato",
    "stackable": true,
    "max_stack": 99,
    "sell_price": 30,
    "description": "圆滚滚的土豆"
  }
}
```

#### 2.4.4 `data/achievements.json`

```json
{
  "first_seed": {
    "id": "first_seed",
    "name": "第一颗种子",
    "description": "首次种下种子",
    "condition_type": "plant_count",
    "condition_value": 1,
    "icon": "🌱"
  },
  "harvest_100": {
    "id": "harvest_100",
    "name": "丰收喜悦",
    "description": "收获100个作物",
    "condition_type": "harvest_count",
    "condition_value": 100,
    "icon": "🌾"
  },
  "first_steal": {
    "id": "first_steal",
    "name": "偷菜新手",
    "description": "首次偷菜",
    "condition_type": "steal_count",
    "condition_value": 1,
    "icon": "🤫"
  },
  "steal_50": {
    "id": "steal_50",
    "name": "菜园盗贼",
    "description": "偷菜50次",
    "condition_type": "steal_count",
    "condition_value": 50,
    "icon": "🦝"
  },
  "visit_20": {
    "id": "visit_20",
    "name": "社交达人",
    "description": "拜访20个好友",
    "condition_type": "visit_count",
    "condition_value": 20,
    "icon": "🤝"
  },
  "all_crops": {
    "id": "all_crops",
    "name": "园艺大师",
    "description": "解锁全部作物",
    "condition_type": "unlock_all_crops",
    "condition_value": 10,
    "icon": "🏆"
  },
  "millionaire": {
    "id": "millionaire",
    "name": "百万富翁",
    "description": "累计获得100万金币",
    "condition_type": "total_gold_earned",
    "condition_value": 1000000,
    "icon": "💰"
  },
  "decorator": {
    "id": "decorator",
    "name": "装饰大师",
    "description": "放置50个装饰物",
    "condition_type": "decoration_count",
    "condition_value": 50,
    "icon": "🎨"
  }
}
```

### 2.5 入口场景 (main.tscn)

```
main.tscn
└── Main (Node2D)
    └── Label "像素田园 - 项目骨架已就绪"  (调试用，确认项目可运行)
```

运行后控制台应输出：
```
[GameManager] 初始化完成
[DataManager] 已加载 10 种作物数据
[DataManager] 已加载 7 个等级数据
[DataManager] 已加载 N 个道具数据
[DataManager] 已加载 8 个成就数据
[EventBus] 信号总线就绪
[SaveManager] 占位初始化
[AudioManager] 占位初始化
```

---

## 3. 验收标准

### 3.1 项目配置验收

- [ ] Godot 4.4 项目可正常打开且无报错
- [ ] 运行项目后窗口以 4x 缩放正确显示（1920×1280 窗口，480×320 内容）
- [ ] 纹理过滤为 Nearest（任何图片放大后显示为锐利像素块，无模糊）
- [ ] 所有 InputMap Action 已注册且可通过 `Input.is_action_pressed()` 检测

### 3.2 目录结构验收

- [ ] 所有目录按规范创建完毕
- [ ] `data/` 目录下 4 个 JSON 文件存在且可被 Godot 正常读取

### 3.3 全局单例验收

- [ ] 5 个 Autoload 脚本已注册且无语法错误
- [ ] `GameManager` 可在任意脚本中通过 `GameManager.player_gold` 访问
- [ ] `DataManager.get_crop("carrot")` 返回正确的胡萝卜数据字典
- [ ] `DataManager.get_unlocked_crops(1)` 返回 4 种初始作物
- [ ] `DataManager.get_crops_by_season("summer")` 返回夏季作物列表
- [ ] `EventBus` 信号可正常 emit 和 connect（用测试脚本验证）

### 3.4 数据完整性验收

- [ ] `crops.json` 包含 10 种作物，字段完整
- [ ] `levels.json` 包含 7 个等级，解锁关系正确
- [ ] `items.json` 包含水壶 + 10 种种子 + 至少 5 种收获物
- [ ] `achievements.json` 包含 8 个成就

---

## 4. 技术约束

1. **GDScript 代码规范**:
   - 使用 `class_name` 注册自定义类
   - 变量使用 snake_case
   - 信号使用 past tense (如 `crop_planted` 而非 `plant_crop`)
   - 所有公开方法需有简短注释

2. **数据不可变原则**:
   - `DataManager` 加载的数据为只读
   - 运行时状态由各系统管理器维护，不修改原始数据表

3. **信号优先原则**:
   - 系统间通信优先使用 `EventBus` 信号
   - 避免系统间直接引用（除 DataManager 查询外）

4. **Autoload 注册顺序**:
   ```
   1. EventBus       (最先加载，其他系统依赖它)
   2. DataManager    (加载数据)
   3. GameManager    (初始化游戏状态)
   4. SaveManager    (占位)
   5. AudioManager   (占位)
   ```

---

## 5. 非目标 (Not in Scope)

以下内容**不在** PRD1 范围内：

- ❌ 任何视觉表现（场景搭建、Sprite、TileMap）
- ❌ 角色移动/物理
- ❌ 作物生长逻辑（PRD2）
- ❌ 背包增删改查逻辑（PRD3）
- ❌ 金币交易逻辑（PRD4）
- ❌ 等级升级逻辑（PRD5）
- ❌ 实际存档读写（PRD6）
- ❌ 时间流逝逻辑（PRD7）
- ❌ UI 面板
- ❌ 音频播放

PRD1 的目标是：**让项目骨架 100% 就绪，后续 PRD 可以直接在此基础上开发，无需再改基础配置。**

---

## 6. 后续衔接

| 完成 PRD1 后可并行启动 | 说明 |
|----------------------|------|
| → PRD2 (作物状态机) | 使用 DataManager 读取作物数据，使用 EventBus 发送信号 |
| → PRD3 (背包数据层) | 使用 DataManager 读取物品数据 |
| → PRD5 (等级系统) | 使用 DataManager 读取等级数据 |
| → PRD7 (时间系统) | 使用 EventBus 广播时间事件 |

---

> *本 PRD 完成后，项目应处于「可运行、可访问数据、可发送信号」的状态，为所有后续系统开发奠定基础。*
