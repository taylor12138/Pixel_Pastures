## MODIFIED Requirements

### Requirement: 存档一致性修复
系统 MUST 在 FarmGridManager 完成默认初始化或存档恢复之后，保持 CropManager、FarmGridManager 和 InventoryManager 状态一致，并提供作物 / 地块状态修复。

#### Scenario: 作物存在时地块恢复占用
- **WHEN** `reconcile_grid_with_crops()` 发现 CropManager 某地块存在作物
- **AND** 该坐标是合法的可解锁 farm plot
- **AND** FarmGridManager 对应地块未标记 occupied
- **THEN** 控制器 MUST 将该地块恢复为 occupied

#### Scenario: 旧存档作物位于默认锁定地块
- **WHEN** 旧存档没有 `farm_grid`
- **AND** CropManager 在默认 12 格之外的合法可解锁 farm plot 上有作物
- **AND** FarmGridManager 默认初始化后该地块为 locked
- **THEN** 一致性修复 MUST 先恢复该地块为 unlocked
- **AND** MUST 再将该地块标记为 occupied
- **AND** 作物数据 MUST 保持不变

#### Scenario: 无作物但地块占用时清理地块
- **WHEN** `reconcile_grid_with_crops()` 发现 FarmGridManager 某个已解锁地块标记 occupied
- **AND** CropManager 对应地块没有作物
- **THEN** 控制器 MUST 清理该地块为空闲

#### Scenario: 非占用网格状态保持存档值
- **WHEN** FarmGridManager 已从存档恢复已解锁的 `dry_soil`、`wet_soil` 或 `empty` 地块
- **AND** CropManager 对应地块没有作物
- **THEN** 一致性修复 MUST 保持该非 occupied 状态
- **AND** MUST NOT 把所有无作物地块统一重置为默认状态

#### Scenario: 恢复顺序先网格后修复
- **WHEN** 农场场景进入或活动农场中完成读档
- **THEN** FarmGridManager MUST 先完成存档导入或默认初始化
- **AND** `reconcile_grid_with_crops()` MUST 随后执行
- **AND** 占位视觉 MUST 在修复后刷新

#### Scenario: PRD10 不保存临时交互选择
- **WHEN** 游戏保存
- **THEN** 作物、农田网格、库存和玩家进度 MUST 通过各自既有导出接口保存
- **AND** 控制器自身的临时选择、悬停和选中状态 MUST NOT 成为必须保存的数据

### Requirement: FarmInteractionController 测试场景
系统 MUST 提供 PRD10 自动化 / 半自动化测试场景，覆盖核心闭环、错误回滚和存档恢复后的一致性修复。

#### Scenario: 测试场景文件存在
- **WHEN** 项目文件被检查
- **THEN** `res://scenes/test/test_farm_interaction_controller.tscn` MUST 存在
- **AND** `res://scenes/test/test_farm_interaction_controller.gd` MUST 存在

#### Scenario: 测试覆盖核心闭环
- **WHEN** `test_farm_interaction_controller.tscn` 运行
- **THEN** 测试 MUST 覆盖空地种植成功、无种子种植失败、未解锁地块种植失败、重复种植失败、浇水成功、重复浇水失败、未成熟收获失败、成熟收获成功、背包满收获失败、枯萎清除成功、自动交互优先级和存档一致性修复

#### Scenario: 测试覆盖旧存档锁定作物格修复
- **WHEN** 测试准备一个无 `farm_grid` 但 CropManager 在默认解锁区之外存在作物的状态
- **THEN** 一致性修复测试 MUST 验证该地块恢复为 unlocked 和 occupied

#### Scenario: 测试覆盖恢复状态保护
- **WHEN** 测试准备一个已恢复的无作物 `wet_soil` 或 `dry_soil` 地块
- **THEN** 一致性修复测试 MUST 验证该地块状态不会被清空或默认初始化覆盖
