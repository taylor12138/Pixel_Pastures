# 像素田园 (Pixel Farm)

像素风田园休闲游戏 - Godot 4.6 项目

## 环境要求

- **Godot Engine 4.6+**（Compatibility 渲染器）
- macOS / Windows / Linux

## 安装 Godot

1. 前往 [Godot 官网下载页](https://godotengine.org/download)
2. 下载 **Godot 4.6 Standard** 版本（不需要 .NET 版）
3. macOS 用户：解压后将 `Godot.app` 拖入「应用程序」文件夹

## 打开项目

### 方式一：通过 Godot 项目管理器

1. 打开 Godot 应用
2. 在项目管理器中点击「导入」
3. 浏览到此目录，选择 `project.godot` 文件
4. 点击「导入并编辑」

### 方式二：命令行启动

```bash
# macOS（假设 Godot 在应用程序目录）
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/linzizhan/Desktop/coco_project/像素风田园游戏/pixel-farm

# 或者直接双击 project.godot 文件（需关联 Godot）
open project.godot
```

## 运行游戏

项目在 Godot 编辑器中打开后：

1. **按 F5**（或点击右上角的 ▶ 播放按钮）运行主场景
2. 游戏窗口将以 **1920x1280** 像素打开
3. 左上角会显示调试信息：`像素田园 | 新游戏 | Lv.1 | 金币:100 | 第1天`

### 快捷键

| 按键 | 功能 |
|------|------|
| F5 | 运行游戏 |
| F6 | 运行当前场景 |
| Esc | 保存游戏（运行时） |
| Cmd+Q / Alt+F4 | 退出游戏 |

## 项目结构

```
pixel-farm/
├── project.godot          # 项目配置文件（入口）
├── data/                  # 游戏数据表 (JSON)
│   ├── crops.json         # 作物数据（10种）
│   ├── items.json         # 道具数据
│   ├── levels.json        # 等级数据（7级）
│   └── achievements.json  # 成就数据
├── scripts/
│   └── autoload/          # 全局单例脚本
│       ├── event_bus.gd   # 信号总线
│       ├── data_manager.gd # 数据加载管理器
│       ├── game_manager.gd # 游戏状态管理器
│       ├── scene_manager.gd # 场景切换管理器
│       └── audio_manager.gd # 音频管理器
├── scenes/
│   └── main/              # 入口场景
│       ├── main.tscn
│       └── main.gd
└── assets/                # 美术资源（待添加）
    ├── sprites/
    ├── tilesets/
    ├── audio/
    └── ui/
```

## Autoload 加载顺序

项目启动时，以下全局管理器按顺序自动加载：

1. **EventBus** - 信号总线，跨系统通信
2. **DataManager** - 加载 JSON 数据表
3. **GameManager** - 玩家状态、金币、存档
4. **SceneManager** - 场景切换
5. **AudioManager** - 音频播放

## 验证项目运行正常

运行后在 Godot 底部「输出」面板应看到：

```
[DataManager] All data tables loaded: ["crops", "items", "levels", "achievements"]
[GameManager] Initialized
[SceneManager] Initialized
[AudioManager] Initialized with 4 SFX channels
=== 像素田园 ===
[Main] Game starting...
[GameManager] No save file found, starting fresh
[Main] Ready! Press F5 in Godot to run.
```

## 开发状态

- [x] PRD1: 项目骨架 + 核心数据系统
- [ ] PRD2: 时间系统 + 基础种植流程
- [ ] PRD3: 背包系统
- [ ] PRD4-28: 后续功能开发中...

## 技术栈

- **引擎**: Godot 4.6 (GL Compatibility)
- **语言**: GDScript
- **分辨率**: 480x320 视口，4x 放大至 1920x1280
- **数据格式**: JSON
- **架构模式**: Autoload 单例 + EventBus 信号解耦
