## 1. Data and Autoload Setup

- [x] 1.1 Add `pixel-farm/scripts/autoload/level_manager.gd` with no `class_name` and initialize it as the XP, level, and unlock business authority.
- [x] 1.2 Register `LevelManager` in `pixel-farm/project.godot` after `EconomyManager` and before `SceneManager` / `AudioManager`.
- [x] 1.3 Extend `DataManager` with safe-copy level and crop query helpers required by LevelManager, including `get_all_levels()`, `get_max_level()`, and `get_all_crops()` if missing.
- [x] 1.4 Verify level configuration is read from `pixel-farm/data/levels.json` and crop compatibility data is read from `pixel-farm/data/crops.json` without mutating source data.

## 2. Level Progression Core

- [x] 2.1 Implement `LevelManager.add_xp(amount, source)` with validation, stable result Dictionary fields, XP stat updates, EventBus XP emission, and no side effects on failure.
- [x] 2.2 Implement `LevelManager.check_level_up()` using cumulative `xp_required` thresholds with support for multiple level-ups in one XP operation.
- [x] 2.3 Implement `LevelManager.recalculate_level()` for load/debug repair without upgrade rewards or unlock signal emissions.
- [x] 2.4 Implement `set_progress()`, `get_current_level_data()`, `get_next_level_data()`, `get_max_level()`, `is_max_level()`, and `get_xp_progress()`.
- [x] 2.5 Implement `calculate_xp()` and `grant_xp()` for `plant`, `harvest`, `sell`, `steal`, and `manual` sources.
- [x] 2.6 Implement `export_save_data()`, `import_save_data()`, and `debug_reset_progress()` for level-system persistence and testing.

## 3. Content Unlocks

- [x] 3.1 Implement `get_level_unlocks(level)` and `get_accumulated_unlocks(level = -1)` with deduplicated crops/features and inherited farm-slot capacity.
- [x] 3.2 Implement crop unlock APIs: `is_crop_unlocked()`, `get_crop_unlock_level()`, `get_unlocked_crops()`, and `get_locked_crops()`.
- [x] 3.3 Implement feature unlock APIs: `is_feature_unlocked()` and `get_unlocked_features()`.
- [x] 3.4 Implement `get_unlocked_farm_slots()` with configured values for levels 1 through 7.
- [x] 3.5 Ensure all arrays and Dictionaries returned from unlock query APIs are safe copies.

## 4. EventBus and GameManager Integration

- [x] 4.1 Add `EventBus` signals `unlocks_changed`, `crop_unlocked`, `feature_unlocked`, and `farm_slots_changed`.
- [x] 4.2 Adjust or preserve `EventBus.xp_gained(amount, source)` and `EventBus.level_up(new_level)` signatures for PRD5 compatibility.
- [x] 4.3 Emit `level_up` once per gained level and unlock signals only when XP operations actually unlock content.
- [x] 4.4 Modify `GameManager.add_xp()` to delegate to `LevelManager.add_xp()` when available while retaining legacy fallback behavior.
- [x] 4.5 Update `GameManager` save/load payload handling to include and restore `level_system` data when `LevelManager` exists.
- [x] 4.6 Ensure `reset_to_default()` restores `GameManager.xp` to `0` and `GameManager.level` to `1`.

## 5. Crop and Economy Integration

- [x] 5.1 Update `CropManager.plant_crop()` to reject locked crops through `LevelManager.is_crop_unlocked()` when available.
- [x] 5.2 Grant plant XP via `LevelManager.grant_xp("plant", {"crop_id": crop_id})` only after successful planting.
- [x] 5.3 Grant harvest XP via `LevelManager.grant_xp("harvest", {"crop_id": crop_id})` only after successful harvest.
- [x] 5.4 Update `EconomyManager.buy_seed()` and seed shop listing to use `LevelManager.is_crop_unlocked()` when available, with legacy fallback when unavailable.
- [x] 5.5 Grant sell XP via `LevelManager.grant_xp("sell", context)` only after successful harvest-item sale transactions.
- [x] 5.6 Verify failed crop and economy operations do not grant XP or emit success-only level progression side effects.

## 6. Automated Test Scene

- [x] 6.1 Create `pixel-farm/scenes/test/test_level_manager.gd` with automated tests for initial state, XP gain, invalid XP, single upgrade, multi-upgrade, max-level behavior, and XP source calculation.
- [x] 6.2 Add unlock tests for crop unlock levels, current unlocked crops, locked crops, feature unlocks, farm slots, and accumulated unlocks.
- [x] 6.3 Add signal tests for `xp_gained`, per-level `level_up`, `unlocks_changed`, `crop_unlocked`, `feature_unlocked`, and `farm_slots_changed`.
- [x] 6.4 Add save/import tests for `export_save_data()`, `import_save_data()`, and `recalculate_level()` repair.
- [x] 6.5 Create `pixel-farm/scenes/test/test_level_manager.tscn` with a `TestLevelManager` root and label output matching existing test scene conventions.

## 7. Verification

- [x] 7.1 Run or inspect the LevelManager test scene to confirm all PRD5 tests pass without errors.
- [x] 7.2 Run existing crop, inventory, and economy test scenes or equivalent checks to confirm PRD2-PRD4 behavior remains compatible.
- [x] 7.3 Verify OpenSpec requirements are satisfied for `level-progression`, `content-unlocks`, `event-bus`, `game-state`, `crop-state-machine`, `shop-economy`, and `data-loading`.
