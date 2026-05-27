## MODIFIED Requirements

### Requirement: Save data integration
CropManager SHALL export and import all crop tile runtime state through JSON-serializable data using `"x,y"` string keys, and SHALL support post-load offline compensation.

#### Scenario: Crop state exports string-keyed tile data
- **WHEN** `CropManager.export_save_data()` is called
- **THEN** it SHALL return a Dictionary containing `tiles`
- **AND** every tile key SHALL be a string coordinate in `"x,y"` format
- **AND** every tile value SHALL contain JSON-serializable crop runtime state

#### Scenario: Crop state imports string-keyed tile data
- **WHEN** `CropManager.import_save_data(data)` receives a Dictionary containing `tiles`
- **THEN** it SHALL restore crop tile runtime state
- **AND** it SHALL skip invalid coordinates or invalid crop IDs without crashing

#### Scenario: Crop offline compensation runs after load
- **WHEN** SaveManager successfully loads a save containing crop data and a last-online timestamp
- **THEN** `CropManager.process_offline_time(last_online_timestamp)` SHALL run after crop data import
- **AND** mature or withered crop state SHALL be reconciled according to crop lifecycle rules
