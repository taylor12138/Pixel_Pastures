# save-system Specification Delta

## ADDED Requirements

### Requirement: Farm grid save payload contract
FarmGridManager SHALL 提供可被 SaveManager 接入的 `farm_grid` 存档数据契约，且该数据必须完全 JSON 可序列化。

#### 场景:FarmGridManager 导出 farm_grid 数据
- **WHEN** `FarmGridManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary suitable for a save root field named `farm_grid`
- **AND** the Dictionary SHALL contain `schema_version`, `map_width`, `map_height`, `tile_size`, `farm_origin`, `unlocked_plot_count`, and `tiles`
- **AND** `farm_origin` SHALL be represented as a JSON object with `x` and `y` fields
- **AND** `tiles` SHALL use string coordinate keys such as `"5,5"`

#### 场景:Farm grid save data is JSON serializable
- **WHEN** farm grid data is exported for persistence
- **THEN** the payload SHALL contain only JSON-serializable values
- **AND** it SHALL NOT contain Node, Resource, Signal, Callable, or raw Vector2i values

#### 场景:Farm grid tile save fields
- **WHEN** an individual farm grid tile is exported
- **THEN** the tile payload SHALL include `terrain_type`, `plot_state`, `unlocked`, `occupied`, and `crop_tile_ref`
- **AND** missing optional runtime-only fields SHALL NOT prevent save serialization

### Requirement: Farm grid import compatibility
FarmGridManager SHALL 能够从 `farm_grid` 存档数据恢复地块状态，并兼容缺失、非法或旧版本数据。

#### 场景:缺少 farm_grid 时使用默认田园
- **WHEN** a loaded save does not contain `farm_grid` data or provides an empty farm grid payload
- **THEN** FarmGridManager SHALL initialize the default PRD8 grid
- **AND** the default grid SHALL contain 12 initially unlocked empty plots

#### 场景:导入 farm_grid 恢复地块状态
- **WHEN** `FarmGridManager.import_save_data(data)` receives valid farm grid data with a tile saved as `wet_soil`
- **THEN** the corresponding runtime tile SHALL be restored with `plot_state="wet_soil"`
- **AND** grid rendering state SHALL be refreshed after import

#### 场景:导入非法 farm_grid 坐标跳过
- **WHEN** imported farm grid data contains an invalid coordinate key or a coordinate outside the current map bounds
- **THEN** FarmGridManager SHALL skip that tile
- **AND** it SHALL continue importing other valid tiles
- **AND** it SHALL NOT crash the load process

#### 场景:导入缺失字段补默认值
- **WHEN** imported farm grid tile data is missing supported fields
- **THEN** FarmGridManager SHALL fill missing fields from the default tile data for that coordinate
- **AND** the import operation SHALL complete without crashing

### Requirement: SaveManager may persist farm_grid without breaking old saves
SaveManager SHALL allow 后续实现把 FarmGridManager 导出的数据挂载到保存根结构的 `farm_grid` 字段，且旧存档不得因缺少该字段而失效。

#### 场景:保存根结构可包含 farm_grid
- **WHEN** SaveManager integrates PRD8 farm grid persistence
- **THEN** the save root MAY include `farm_grid` populated from `FarmGridManager.export_save_data()`
- **AND** the save root SHALL remain JSON serializable

#### 场景:旧存档缺少 farm_grid 不失败
- **WHEN** SaveManager loads an older valid save without a `farm_grid` root field
- **THEN** validation SHALL NOT fail only because `farm_grid` is missing
- **AND** FarmGridManager SHALL be allowed to initialize default farm grid data
