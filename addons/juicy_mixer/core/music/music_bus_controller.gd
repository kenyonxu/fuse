class_name MusicBusController
extends RefCounted

## 音乐总线控制器
##
## 管理 Godot AudioBus 创建和路由

# =============================================================================
# 常量
# =============================================================================

const MUSIC_BUS_NAME = &"Music"
const MUSIC_LPF_BUS_NAME = &"Music_LPF"
const LAYER_BUS_PREFIX = &"Music_Layer"
const DEFAULT_MAX_LAYERS: int = 4

# =============================================================================
# 总线索引
# =============================================================================

var _music_bus_index: int = -1
var _music_lpf_bus_index: int = -1
var _layer_bus_indices: Dictionary = {}  # {layer_index: bus_index}
var _max_layers: int = DEFAULT_MAX_LAYERS

# =============================================================================
# AudioServer 引用
# =============================================================================

var _audio_server: AudioServer

# =============================================================================
# 初始化
# =============================================================================

func _init():
	# _audio_server = AudioServer
	pass
## 设置总线结构
func setup_buses() -> void:
	"""
	创建音乐总线结构

	Music (主音乐总线)
	  ├── Music_LPF (带低通滤波器)
	  ├── Music_Layer1 (叠加层1)
	  ├── Music_Layer2 (叠加层2)
	  └── ...
	"""
	# 创建主音乐总线
	_music_bus_index = _create_bus_if_not_exists(MUSIC_BUS_NAME, &"Master")

	# 创建 LPF 总线
	_music_lpf_bus_index = _create_bus_if_not_exists(MUSIC_LPF_BUS_NAME, MUSIC_BUS_NAME)
	_setup_lpf_effect()

	# 创建层总线
	for i in range(_max_layers):
		var layer_bus_name: StringName = str(LAYER_BUS_PREFIX, i + 1)
		var bus_index: int = _create_bus_if_not_exists(layer_bus_name, MUSIC_BUS_NAME)
		_layer_bus_indices[i] = bus_index

	print("[MusicBusController] 总线设置完成")
	print("  Music 总线索引: ", _music_bus_index)
	print("  LPF 总线索引: ", _music_lpf_bus_index)
	print("  层总线: ", _layer_bus_indices)

# =============================================================================
# 总线创建辅助
# =============================================================================

func _create_bus_if_not_exists(bus_name: StringName, parent_bus: StringName = &"Master") -> int:
	"""创建总线（如果不存在）"""
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		bus_index = AudioServer.bus_count
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, parent_bus)
		print("[MusicBusController] 创建总线: ", bus_name, " -> ", parent_bus)

	return bus_index

# =============================================================================
# LPF 效果器设置
# =============================================================================

func _setup_lpf_effect() -> void:
	"""在 LPF 总线上添加低通滤波器效果"""
	if _music_lpf_bus_index == -1:
		return

	# 检查是否已有 Effect
	var effect_count: int = AudioServer.get_bus_effect_count(_music_lpf_bus_index)
	if effect_count > 0:
		return  # 已有效果器，跳过

	# 添加低通滤波器
	var lpf: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	AudioServer.add_bus_effect(_music_lpf_bus_index, lpf, 0)
	print("[MusicBusController] 添加 LPF 效果器到总线 ", _music_lpf_bus_index)

# =============================================================================
# 路由控制
# =============================================================================

## 切换到 LPF 总线
func route_to_lpf() -> void:
	"""将播放器路由到 LPF 总线（由外部设置 player.bus）"""
	pass  # 实际路由由播放器设置 bus 属性

## 恢复正常总线
func route_to_normal() -> void:
	"""将播放器路由到正常总线（由外部设置 player.bus）"""
	pass  # 实际路由由播放器设置 bus 属性

## 获取层总线
func get_layer_bus(layer_index: int) -> int:
	"""获取音乐层总线索引"""
	if layer_index in _layer_bus_indices:
		return _layer_bus_indices[layer_index]

	# 动态创建新层总线
	var new_bus_name: StringName = str(LAYER_BUS_PREFIX, layer_index + 1)
	var bus_index: int = _create_bus_if_not_exists(new_bus_name, MUSIC_BUS_NAME)
	_layer_bus_indices[layer_index] = bus_index
	return bus_index

# =============================================================================
# 效果控制
# =============================================================================

## 设置 LPF 截止频率
func set_lpf_cutoff(hz: float) -> void:
	"""设置 LPF 截止频率"""
	if _music_lpf_bus_index == -1:
		return

	# 查找 LPF 效果器（我们添加在索引 0）
	var effect_count: int = AudioServer.get_bus_effect_count(_music_lpf_bus_index)
	if effect_count == 0:
		return

	# 遍历所有效果器，找到 AudioEffectLowPassFilter
	for i in range(effect_count):
		var effect: AudioEffect = AudioServer.get_bus_effect(_music_lpf_bus_index, i)
		if effect is AudioEffectLowPassFilter:
			effect.cutoff_hz = hz
			return

## 设置 LPF 共振
func set_lpf_resonance_db(db: float) -> void:
	"""设置 LPF 共振"""
	if _music_lpf_bus_index == -1:
		return

	# 查找 LPF 效果器
	var effect_count: int = AudioServer.get_bus_effect_count(_music_lpf_bus_index)
	if effect_count == 0:
		return

	for i in range(effect_count):
		var effect: AudioEffect = AudioServer.get_bus_effect(_music_lpf_bus_index, i)
		if effect is AudioEffectLowPassFilter:
			effect.resonance = db
			return

## 启用/禁用 LPF
func set_lpf_enabled(enabled: bool) -> void:
	"""启用或禁用 LPF 效果"""
	if _music_lpf_bus_index == -1:
		return

	# 查找 LPF 效果器
	var effect_count: int = AudioServer.get_bus_effect_count(_music_lpf_bus_index)
	if effect_count == 0:
		return

	for i in range(effect_count):
		var effect: AudioEffect = AudioServer.get_bus_effect(_music_lpf_bus_index, i)
		if effect is AudioEffectLowPassFilter:
			AudioServer.set_bus_effect_enabled(_music_lpf_bus_index, i, enabled)
			return

# =============================================================================
# 获取器
# =============================================================================

## 获取主音乐总线索引
func get_music_bus_index() -> int:
	return _music_bus_index

## 获取 LPF 总线索引
func get_lpf_bus_index() -> int:
	return _music_lpf_bus_index

## 获取所有层总线
func get_all_layer_buses() -> Dictionary:
	return _layer_bus_indices.duplicate()
