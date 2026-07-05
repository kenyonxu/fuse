@tool
class_name FuseAudioContainer
extends RefCounted

## Fuse 音频持久化容器
##
## 管理 /root/Fuse_Audio 容器节点，用于存放跨场景存活的音乐播放器。
## 音效播放器（Fuse_AudioPlayer*）仍然放在 current_scene 中，随场景切换销毁。

const CONTAINER_NAME := "Fuse_Audio"
const MUSIC_PLAYER_PREFIX := "Fuse_MusicPlayer"
const SOUND_PLAYER_PREFIX := "Fuse_AudioPlayer"


## 获取或创建音频容器节点
## 容器挂在 scene_tree.root 下，跨场景持久化
static func get_container() -> Node:
	var scene_tree = Engine.get_main_loop()
	if not scene_tree:
		return null

	var root = scene_tree.root
	if root.has_node(CONTAINER_NAME):
		return root.get_node(CONTAINER_NAME)

	var container = Node.new()
	container.name = CONTAINER_NAME
	root.add_child(container)
	return container


## 添加音乐播放器到容器
static func add_music_player(player: AudioStreamPlayer) -> void:
	var container = get_container()
	if container and player:
		container.add_child(player)


## 从容器中移除音乐播放器
static func remove_music_player(player: AudioStreamPlayer) -> void:
	if player and is_instance_valid(player) and player.get_parent():
		player.get_parent().remove_child(player)


## 在容器中查找音乐播放器
## [param pattern]: 名称匹配模式，支持通配符。默认查找所有 Fuse_MusicPlayer*
static func find_music_players(pattern: String = "") -> Array:
	var container = get_container()
	if not container:
		return []

	if pattern.is_empty():
		pattern = MUSIC_PLAYER_PREFIX + "*"

	var regex_pattern = "^%s$" % pattern.replace("*", ".*")
	var regex = RegEx.new()
	regex.compile(regex_pattern)

	var result: Array[AudioStreamPlayer] = []
	for child in container.get_children():
		if child is AudioStreamPlayer and regex.search(child.name):
			result.append(child)
	return result


## 查找所有音频播放器（容器 + current_scene）
## 同时搜索持久化容器中的音乐播放器和当前场景中的音效播放器
static func find_all_audio_players() -> Array:
	var all_players = []

	# 搜索容器中的音乐播放器
	var music_players = find_music_players()
	all_players.append_array(music_players)

	# 搜索 current_scene 中的音效播放器
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree.current_scene:
		_find_audio_players_recursive(scene_tree.current_scene, all_players)

	return all_players


## 按条件查找音频播放器（容器 + current_scene）
## [param bus_filter]: 总线过滤，空字符串表示不限
## [param name_pattern_filter]: 名称模式过滤，空字符串表示不限
## [param playing_only]: 是否只返回正在播放的
static func find_audio_players_filtered(
	bus_filter: String = "",
	name_pattern_filter: String = "",
	playing_only: bool = false
) -> Array:
	var all_players = find_all_audio_players()
	var filtered = []

	for player in all_players:
		if playing_only and not player.playing:
			continue
		if not bus_filter.is_empty() and player.get_bus() != bus_filter:
			continue
		if not name_pattern_filter.is_empty() and not _matches_pattern(player.name, name_pattern_filter):
			continue
		filtered.append(player)

	return filtered


## 停止所有容器中的音乐播放器
## [param fade_out]: 是否淡出停止
## [param fade_duration]: 淡出时长（秒）
static func stop_all_music(fade_out: bool = false, fade_duration: float = 0.5) -> void:
	var music_players = find_music_players()
	var scene_tree = Engine.get_main_loop()

	for player in music_players:
		if not is_instance_valid(player):
			continue

		if fade_out and scene_tree:
			var tween = scene_tree.create_tween()
			var original_volume = player.volume_db
			tween.tween_property(player, "volume_db", -60.0, fade_duration)
			tween.tween_callback(func():
				if is_instance_valid(player):
					player.stop()
					player.volume_db = original_volume
					player.queue_free()
			)
		else:
			player.stop()
			player.queue_free()


## 递归搜索节点树中的所有音频播放器
static func _find_audio_players_recursive(node: Node, players: Array) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			players.append(child)
		_find_audio_players_recursive(child, players)


## 匹配名称模式（支持通配符 *）
static func _matches_pattern(name: String, pattern: String) -> bool:
	var regex_pattern = pattern.replace("*", ".*")
	var regex = RegEx.new()
	regex.compile("^%s$" % regex_pattern)
	var result = regex.search(name)
	return result != null
