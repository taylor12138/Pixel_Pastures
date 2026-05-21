## AudioManager — 音频管理（BGM + SFX）
## 后续 PRD 会增加音频资产，目前先搭好框架
extends Node

## 音量设置 (0.0 - 1.0)
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var master_muted: bool = false

## 内部播放器
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 4


func _ready() -> void:
	# 创建 BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	add_child(_bgm_player)

	# 创建 SFX 播放器池
	for i in MAX_SFX_PLAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

	print("[AudioManager] Initialized with %d SFX channels" % MAX_SFX_PLAYERS)


## 播放背景音乐
func play_bgm(stream: AudioStream, _fade_in: bool = false) -> void:
	if master_muted:
		return
	_bgm_player.stream = stream
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	_bgm_player.play()


## 停止背景音乐
func stop_bgm() -> void:
	_bgm_player.stop()


## 播放音效
func play_sfx(stream: AudioStream) -> void:
	if master_muted:
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return
	# 所有通道都忙，强制用第一个
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


## 设置 BGM 音量
func set_bgm_volume(vol: float) -> void:
	bgm_volume = clampf(vol, 0.0, 1.0)
	_bgm_player.volume_db = linear_to_db(bgm_volume)


## 设置 SFX 音量
func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)


## 静音/取消静音
func toggle_mute() -> void:
	master_muted = not master_muted
	if master_muted:
		_bgm_player.stop()
