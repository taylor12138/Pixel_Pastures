## 1. Project Configuration (project.godot)

- [x] 1.1 Configure viewport size: viewport_width=480, viewport_height=320
- [x] 1.2 Configure window size override: window_width_override=1920, window_height_override=1280
- [x] 1.3 Configure stretch mode=viewport, aspect=keep
- [x] 1.4 Configure texture filter: default_texture_filter=0 (Nearest)
- [x] 1.5 Ensure renderer is gl_compatibility
- [x] 1.6 Configure window resizable=true
- [x] 1.7 Configure InputMap: interact (Mouse Left Click)
- [x] 1.8 Configure InputMap: ui_pause (Escape)
- [ ] 1.9 Configure InputMap: hotbar_1 through hotbar_9 (number keys 1-9) — deferred to PRD2
- [ ] 1.10 Configure InputMap: zoom_in/zoom_out — deferred to PRD2

## 2. Directory Structure

- [x] 2.1 Create scenes/ directory with subdirs: farm/, room/, shop/, plaza/
- [x] 2.2 Create scripts/ directory with subdirs: autoload/, crop/, character/, social/, inventory/, ui/
- [x] 2.3 Create assets/ directory with subdirs: sprites/characters/, sprites/crops/, sprites/animals/, sprites/vfx/, tilesets/, audio/bgm/, audio/sfx/, audio/ambient/, ui/icons/, ui/panels/, ui/buttons/, fonts/
- [x] 2.4 Create data/ directory
- [x] 2.5 Create addons/ directory
- [x] 2.6 Add .gitkeep placeholder files to ensure empty dirs are tracked

## 3. Data Files (JSON)

- [x] 3.1 Create data/crops.json with 10 crops (carrot, tomato, cabbage, corn, potato, strawberry, pepper, pumpkin, eggplant, broccoli)
- [x] 3.2 Create data/levels.json with 7 levels (新手农夫 through 传说农夫)
- [x] 3.3 Create data/items.json with watering_can + fertilizer + decorations
- [x] 3.4 Create data/achievements.json with 5 achievements

## 4. EventBus Autoload

- [x] 4.1 Create scripts/autoload/event_bus.gd extending Node
- [x] 4.2 Define crop lifecycle signals: crop_planted, crop_watered, crop_grown, crop_harvested, crop_withered
- [x] 4.3 Define economy signals: gold_changed, item_purchased, item_sold
- [x] 4.4 Define level signals: xp_gained, level_up, achievement_unlocked
- [x] 4.5 Define time signals: day_started, season_changed
- [x] 4.6 Define UI signals: ui_notification, dialog_opened, dialog_closed
- [x] 4.7 Define social signals: friend_visited, crop_stolen
- [x] 4.8 Define game state signals: game_saved, game_loaded, game_paused, game_resumed

## 5. DataManager Autoload

- [x] 5.1 Create scripts/autoload/data_manager.gd extending Node
- [x] 5.2 Implement _ready() that calls _load_all_tables()
- [x] 5.3 Implement _load_json() with FileAccess and error handling
- [x] 5.4 Implement get_table(table_name) → Variant
- [x] 5.5 Implement get_entry(table_name, entry_id) → Variant
- [x] 5.6 Implement get_crop(crop_id) → Dictionary
- [x] 5.7 Implement get_item(item_id) → Dictionary
- [x] 5.8 Implement get_level_data(level) → Dictionary
- [x] 5.9 Implement get_max_level() → int
- [x] 5.10 Implement reload_table() for hot-reload debugging

## 6. GameManager Autoload

- [x] 6.1 Create scripts/autoload/game_manager.gd extending Node
- [x] 6.2 Define player state: gold, xp, level, current_day, current_season, inventory, farm_data
- [x] 6.3 Implement gold operations: add_gold(), spend_gold(), can_afford()
- [x] 6.4 Implement XP & level-up: add_xp(), _check_level_up(), get_xp_progress()
- [x] 6.5 Implement inventory: add_item(), remove_item(), has_item(), get_item_count()
- [x] 6.6 Implement save/load: save_game(), load_game(), has_save(), delete_save()
- [x] 6.7 Implement new_game() to reset all state

## 7. SceneManager Autoload

- [x] 7.1 Create scripts/autoload/scene_manager.gd extending Node
- [x] 7.2 Implement change_scene(scene_name) with path registry
- [x] 7.3 Implement reload_current_scene() and quit_game()

## 8. AudioManager Placeholder

- [x] 8.1 Create scripts/autoload/audio_manager.gd extending Node
- [x] 8.2 Implement play_bgm(stream) with AudioStreamPlayer
- [x] 8.3 Implement play_sfx(stream) with SFX player pool
- [x] 8.4 Implement volume controls and mute toggle

## 9. Register Autoloads in project.godot

- [x] 9.1 Add [autoload] section with correct order: EventBus, DataManager, GameManager, SceneManager, AudioManager
- [x] 9.2 Verify all paths point to correct script files

## 10. Entry Scene

- [x] 10.1 Create scenes/main/main.tscn with root Node2D + Camera2D + CanvasLayer + DebugLabel
- [x] 10.2 Create scenes/main/main.gd with init flow + debug display
- [x] 10.3 Set main.tscn as the project's main scene in project.godot

## 11. Verification

- [ ] 11.1 Run project: verify window opens at 1920×1280 with debug label visible
- [ ] 11.2 Verify console output shows all 5 Autoload init logs in correct order
- [ ] 11.3 Verify DataManager loads all JSON tables without errors
- [ ] 11.4 Test save/load: press Esc to save, restart to verify load