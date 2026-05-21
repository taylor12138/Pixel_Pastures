## Why

《像素田园》已经完成 PRD1 项目骨架与核心数据系统，并完成 PRD2 作物生长状态机。当前仍缺少正式的背包/库存数据层，导致“收获物进入背包、种子消耗、物品查询、快捷栏选择、后续商店交易”等核心流程无法形成稳定闭环。

PRD3 需要引入 `InventoryManager` 作为物品管理的唯一权威，替代当前 `GameManager.inventory` 的简单 `item_id -> quantity` 字典模型，同时保持向后兼容同步。该系统是后续 PRD4（经济系统）、PRD10（种植/浇水/收获交互）、PRD11（背包 UI）、PRD13（HUD 快捷栏）的基础能力。

此外，PRD1 遗留的 `data/items.json` 物品表仍缺少完整种子和收获物条目，也缺少统一的 `stackable` / `max_stack` 字段。若不补齐，背包系统无法可靠地判断堆叠规则、工具不可堆叠、作物收获物入包等行为。

## What Changes

- 新增 `InventoryManager` Autoload 单例（`pixel-farm/scripts/autoload/inventory_manager.gd`）。
- 实现固定 20 格背包槽位，空格为 `null`，非空格为 `{ "item_id": String, "quantity": int }`。
- 实现物品堆叠规则：可堆叠物品优先合并到已有同类格，不可堆叠工具每个占用独立格。
- 实现核心增删改查 API：添加、移除、指定格移除、交换、移动、合并、智能放置、丢弃、查询数量、查询空格、查询可添加数量、按类型筛选等。
- 实现 9 格快捷栏数据层：快捷栏映射背包 slot 0-8，不独立存储，只提供被动 `select_hotbar()` 接口。
- 新增导入/导出存档数据接口，并与 `GameManager.inventory` 保持兼容同步。
- 修改 `EventBus`：新增 `hotbar_selected`、`item_added`、`item_removed` 信号，并使用已有 `inventory_changed`、`inventory_full` 信号。
- 修改 `data/items.json`：补齐 10 个种子物品、10 个收获物品，并为现有物品补充 `stackable` / `max_stack` 字段。
- 修改 `project.godot`：注册 `InventoryManager` Autoload，保持加载顺序为 `EventBus → DataManager → GameManager → CropManager → InventoryManager → SceneManager → AudioManager`。
- 修改 `CropManager` 集成点：种植扣种子与收获入包改为调用 `InventoryManager`。
- 创建 `scenes/test/test_inventory_manager.tscn` 与 `test_inventory_manager.gd`，覆盖 PRD3 指定的库存、堆叠、快捷栏、导入导出、边界情况测试。

## Capabilities

### New Capabilities

- `inventory-data`: 背包数据层，包含 20 格槽位、堆叠/容量规则、增删改查、槽位移动合并、丢弃、查询、存档导入导出。
- `inventory-hotbar`: 快捷栏数据层，包含 slot 0-8 映射、当前选择项、选中物品查询、使用当前物品。

### Modified Capabilities

- `item-data`: 扩展物品数据表，补齐种子/收获物条目，并统一提供 `stackable` / `max_stack` 元数据。
- `event-bus`: 扩展库存与快捷栏相关信号，用于 UI、HUD、经济系统等后续模块解耦监听。
- `game-state`: 将 `InventoryManager` 作为运行时物品权威，同时同步维护 `GameManager.inventory` 以兼容已有系统与存档数据。
- `crop-state-machine`: 调整种植和收获流程的背包交互入口，由 `GameManager` 切换为 `InventoryManager`。

## Impact

- **代码**:
  - 新增 `pixel-farm/scripts/autoload/inventory_manager.gd`
  - 新增 `pixel-farm/scenes/test/test_inventory_manager.gd`
  - 修改 `pixel-farm/scripts/autoload/event_bus.gd`
  - 修改 `pixel-farm/scripts/autoload/crop_manager.gd`
  - 可能小幅修改 `pixel-farm/scripts/autoload/game_manager.gd` 以支持兼容同步
- **配置**:
  - 修改 `pixel-farm/project.godot`，新增 `InventoryManager` Autoload 注册
- **数据**:
  - 修改 `pixel-farm/data/items.json`，补齐种子、收获物和堆叠元数据
- **测试**:
  - 新增 `pixel-farm/scenes/test/test_inventory_manager.tscn`
  - 新增 InventoryManager 自动化测试脚本，覆盖 PRD3 测试清单
- **后续影响**:
  - PRD4 经济系统可直接调用 `InventoryManager.add_item()` / `remove_item()` 完成买卖
  - PRD10 种植交互可通过快捷栏选中种子并调用库存接口扣除
  - PRD11 背包 UI 可监听 `EventBus.inventory_changed` 渲染槽位
  - PRD13 HUD 可监听 `hotbar_selected` 并读取 `get_hotbar_slots()` 渲染快捷栏
