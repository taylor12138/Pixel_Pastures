## Context

PRD6 introduces the first concrete persistence layer for the Godot 4.4 Pixel Farm project. PRD1 created SaveManager only as a placeholder, while PRD2-5 established crop, inventory, economy, and level systems with save import/export hooks or saveable state expectations.

The implementation must work before save UI and Steam Cloud exist. It therefore focuses on a deterministic local JSON contract, stable manager APIs, explicit error results, and automated tests that can validate persistence entirely through code.

## Goals / Non-Goals

**Goals:**

- Replace the SaveManager placeholder with a real Autoload responsible for local JSON save/load orchestration.
- Persist PRD1-5 runtime state through a versioned JSON document under `user://saves/`.
- Support three manual slots and one auto-save slot with metadata, listing, deletion, overwrite backup, validation, and migration hooks.
- Ensure failed load operations do not mutate the active runtime state.
- Keep SaveManager as an orchestration layer that delegates domain data import/export to GameManager, CropManager, InventoryManager, EconomyManager, and LevelManager.
- Broadcast save lifecycle outcomes through EventBus.
- Provide automated SaveManager tests for success paths and failure paths.

**Non-Goals:**

- No save slot UI, confirmation dialogs, settings UI, or screenshot thumbnails.
- No Steam Cloud API integration or cross-device conflict resolution.
- No encryption, compression, anti-cheat, or tamper-proofing.
- No new crop, inventory, economy, or level gameplay rules beyond persistence hooks.

## Decisions

### Decision 1: Use standalone JSON files in `user://saves/`

Save files will be plain JSON files named `slot_0.json`, `slot_1.json`, `slot_2.json`, and `auto_save.json`, with backups under `user://saves/backup/`.

- Rationale: JSON matches PRD6, is easy to inspect during development, and can be synchronized by future Steam Cloud work without a database or binary format.
- Alternative considered: A single combined save database file. Rejected because independent files make slot management, backup, deletion, and cloud sync simpler.

### Decision 2: SaveManager owns persistence orchestration only

SaveManager will build the save root, call each manager's export/import functions, validate files, write/read disk, and emit signals. It will not compute crop growth, item stack rules, economy transaction rules, or level unlock rules.

- Rationale: Existing managers already own domain behavior. SaveManager should not duplicate business rules or become a god object.
- Alternative considered: SaveManager directly reads and writes private manager fields. Rejected because it would tightly couple persistence to implementation details and make future refactors risky.

### Decision 3: Return structured result dictionaries instead of booleans

Save, load, delete, list, read, write, validate, and migration operations will return dictionaries with stable fields including `success`, `operation`, `slot`, `path`, `timestamp`, `metadata`, `message`, and `error_code` where applicable.

- Rationale: Tests, future UI, and logging need explicit failure causes, not only true/false.
- Alternative considered: Use exceptions or push_error only. Rejected because GDScript call sites and UI flows benefit from data-first results.

### Decision 4: Validate and migrate before applying runtime state

`load_game(slot)` will read, parse, validate schema version, migrate if needed, and validate again before applying data to managers. Invalid JSON, missing required roots, unsupported future schema versions, or failed migrations return errors without mutating current state.

- Rationale: Prevent corrupted or future-version files from damaging the current session.
- Alternative considered: Apply partial data as fields are parsed. Rejected because partial mutation is hard to roll back and difficult to test reliably.

### Decision 5: Use a versioned root schema with extension fields

All saves include `schema_version`, `game_version`, timestamps, slot, metadata, `game`, `inventory`, `crops`, `economy`, `level_system`, `settings`, and `future`.

- Rationale: The schema captures current PRD1-5 data while reserving forward-compatible locations for settings and later systems.
- Alternative considered: Store only manager blobs without a root contract. Rejected because metadata, migration, and slot listing require a stable top-level structure.

### Decision 6: Auto-save is a dedicated slot

Auto-save always writes to slot `-1` / `auto_save.json` and never overwrites manual slots.

- Rationale: Prevents accidental manual save loss and gives future UI a clear distinction between player-controlled saves and background saves.
- Alternative considered: Auto-save into the most recent manual slot. Rejected because it can unexpectedly destroy player intent.

### Decision 7: EventBus signals use typed save lifecycle outcomes

EventBus will expose save success, load success, save failure, load failure, delete, auto-save success, and auto-save failure signals.

- Rationale: Future UI and test code need to observe persistence without directly coupling to SaveManager internals.
- Alternative considered: Only return result dictionaries. Rejected because global UX notifications and async observers are easier through EventBus.

## Risks / Trade-offs

- Corrupted files or unsupported schemas could block loading → Validate before applying state and return stable error codes.
- GDScript file replacement is not fully atomic on every platform → Write to a temporary file, verify by reading/parsing, then replace the target, preserving backup files.
- Existing manager save APIs may differ slightly from PRD assumptions → Add or adapt export/import methods behind each manager's public interface, not by reading private fields from SaveManager.
- Existing `game_saved()` / `game_loaded()` signals may be no-arg placeholders → Upgrade to typed signals and keep compatibility wrappers if existing code still emits or awaits no-arg signals.
- Runtime rollback after partial import can be complex → Prefer full validation before import, then import in a deterministic order; tests must cover failed JSON and invalid schema no-mutation behavior.
- JSON is human-editable and not tamper-proof → Accept for PRD6 because anti-cheat and encryption are explicitly out of scope.

## Migration Plan

1. Add `save_manager.gd` with constants, path helpers, result helpers, directory creation, validation, migration stub, read/write helpers, metadata helpers, and public APIs.
2. Register SaveManager in `project.godot` after gameplay managers and before AudioManager.
3. Add or verify save export/import methods in GameManager, CropManager, InventoryManager, EconomyManager, and LevelManager.
4. Extend EventBus with save lifecycle signals.
5. Add SaveManager test scene and script.
6. Run tests for directory creation, slot pathing, save/load round trips, backup creation, deletion, listing, invalid slots, missing files, corrupted JSON, validation, migration, auto-save, and signals.

Rollback strategy: remove SaveManager registration, restore placeholder SaveManager if needed, and delete runtime `user://saves/` files generated during testing. Existing source data files are not migrated by this change.

## Open Questions

- Whether PRD6 should keep no-argument compatibility signals for `game_saved()` and `game_loaded()` in addition to typed signals depends on the current EventBus implementation and test references.
- Whether LevelManager already exists in the codebase or must be added as part of this implementation should be confirmed during implementation against current project files.
