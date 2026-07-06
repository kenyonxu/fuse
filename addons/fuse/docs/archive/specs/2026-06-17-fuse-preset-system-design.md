# Fuse 预设系统 V1 设计文档

**日期:** 2026-06-17
**状态:** 设计完成,待审核
**关联:** [Fuse 新特性路线图](../roadmap/20206-03-20-future-features-roadmap.md)、[Fuse 推进路线图](../roadmap/2026-06-16-fuse-development-roadmap.md) Stage 2b
**Brainstorm 记录:** `.superpowers/brainstorm/812-1781682707/content/`

---

## 1. 核心目标

让用户将 ActionRunner 中的指令序列保存为可复用预设(Logic Template),应用到不同场景时通过 NodePath 映射对话框自动适配节点引用。同时支持 JSON 格式让 AI(Claude Code)批量生成预设。

---

## 2. 架构概览

```
用户操作                         文件层                         导入
─────────────────────────────────────────────────────────────────
Inspector             →    presets/combat/         →    预设面板(Dock)
[导出为预设]按钮            ├── bullet_spawn.tres         [按分类浏览]
弹出对话框                  ├── bullet_spawn.json         [搜索/过滤]
(名称/分类/描述/图标)       ├── dash_attack.tres          [应用预设]
                            └── dash_attack.json         (触发映射对话框)
                            
                    ↑                                ↑
              FusePreset Resource             FuseComponentScanner
              (to_json/from_json)             (扫描 presets/ 同机制)
```

---

## 3. FusePreset Resource

### 3.1 文件位置

`addons/fuse/core/resources/fuse_preset.gd`

### 3.2 GDScript 定义

```gdscript
@tool
class_name FusePreset
extends Resource

## 预设名称(显示在面板中)
@export var display_name: String = ""

## 分类标识(对应翻译键 FUSE_CATEGORY_*)
@export var category: String = ""

## 描述(显示在 tooltip 和映射对话框中)
@export var description: String = ""

## 图标(FuseIconManager builtin_icon 名称)
@export var icon_name: String = ""

## 版本号(兼容性检查)
@export var version: String = "1.0"

## 变量声明: {"local": ["name1","name2"], "scope": [{"name":"hp","container":"../Player"}], "global": ["level"]}
@export var variables: Dictionary = {}

## 指令序列
@export var instructions: Array[BaseInstruction] = []


# ---- 序列化(Resource → JSON) ----

func to_json() -> Dictionary:
	var data: Dictionary = {
		"format_version": version,
		"display_name": display_name,
		"category": category,
		"description": description,
		"icon_name": icon_name,
		"variables": variables,
		"instructions": _serialize_instructions()
	}
	return data


func _serialize_instructions() -> Array:
	var result: Array = []
	for inst in instructions:
		var entry: Dictionary = {"type": inst.get_script().get_global_name()}
		for prop in inst.get_property_list():
			var pname: String = prop.name
			if pname.begins_with("_") or prop.usage & PROPERTY_USAGE_STORAGE == 0:
				continue
			var val = inst.get(pname)
			if val is NodePath:
				entry[pname] = str(val)
			elif val is Resource:
				entry[pname] = _serialize_resource(val)
			else:
				entry[pname] = val
		result.append(entry)
	return result


# ---- 反序列化(JSON → Resource) ----

static func from_json(data: Dictionary) -> FusePreset:
	var preset := FusePreset.new()
	preset.version = data.get("format_version", "1.0")
	preset.display_name = data.get("display_name", "")
	preset.category = data.get("category", "")
	preset.description = data.get("description", "")
	preset.icon_name = data.get("icon_name", "")
	preset.variables = data.get("variables", {})
	preset.instructions = _deserialize_instructions(data.get("instructions", []))
	return preset


static func _deserialize_instructions(raw: Array) -> Array[BaseInstruction]:
	var result: Array[BaseInstruction] = []
	for entry in raw:
		var type_name: String = entry.get("type", "")
		var inst := _instantiate_instruction(type_name)
		if inst == null:
			push_warning("FusePreset: 无法创建指令类型 '%s'" % type_name)
			continue
		for key in entry:
			if key == "type":
				continue
			var val = entry[key]
			if val is String and val.begins_with("uid://"):
				# UID 引用 → 还原为 Resource
				pass  # 具体实现: ResourceUID.get_id_path(text_to_id(val)) → load
			inst.set(key, val)
		result.append(inst)
	return result


# ---- NodePath 映射(跨场景复用) ----

## 收集所有指令中的唯一 NodePath
func collect_unique_nodepaths() -> Array[NodePath]:
	var result: Array[NodePath] = []
	for inst in instructions:
		for prop in inst.get_property_list():
			if prop.type == TYPE_NODE_PATH:
				var np: NodePath = inst.get(prop.name)
				if not np.is_empty() and np not in result:
					result.append(np)
	return result


## 应用 NodePath 映射(替换所有指令中的对应路径)
func apply_nodepath_mapping(mapping: Dictionary) -> void:
	for inst in instructions:
		for prop in inst.get_property_list():
			if prop.type == TYPE_NODE_PATH:
				var np: NodePath = inst.get(prop.name)
				if mapping.has(str(np)):
					inst.set(prop.name, mapping[str(np)])


# ---- 变量收集(保存时) ----

## 扫描所有指令,按作用域收集变量名
func collect_variables() -> Dictionary:
	var result := {"local": [], "scope": [], "global": []}
	for inst in instructions:
		if "variable_name" in inst and "variable_scope" in inst:
			var name: String = inst.variable_name
			var scope: int = inst.variable_scope  # BaseVariable.VariableScope
			match scope:
				0: _append_unique(result["local"], name)   # LOCAL
				1:                                          # SCOPE
					var container := ""
					if "target_node" in inst:
						container = str(inst.target_node)
					result["scope"].append({"name": name, "container": container})
				2: _append_unique(result["global"], name)  # GLOBAL
	return result
```

### 3.3 JSON 格式

```json
{
  "format_version": "1.0",
  "display_name": "弹幕生成器",
  "category": "combat",
  "description": "间隔生成三方向弹幕,适配弹幕射击游戏",
  "icon_name": "Bullet",
  "variables": {
    "local": ["temp", "count"],
    "scope": [{"name": "hp", "container": "../Player"}],
    "global": ["game_level"]
  },
  "instructions": [
    {
      "type": "OnInterval",
      "interval_seconds": 1.5,
      "trigger_on_start": true
    },
    {
      "type": "Instantiate",
      "target_node": "../spawn_point",
      "scene": "uid://bullet_scene"
    }
  ]
}
```

### 3.4 指令反序列化策略

JSON → BaseInstruction 重建是最复杂的一步。策略:

1. **查找指令类**:遍历 `InstructionRegistry.get_all_instructions()` 找到 `class_name == type` 的脚本
2. **创建实例**:`script.new()` 创建指令实例
3. **还原属性**:遍历 JSON entry 的 key-value,调 `inst.set(key, value)`。NodePath 类型自动从字符串还原。
4. **Resource 引用**:值为 `uid://xxx` 格式的字符串,通过 `ResourceUID.get_id_path(ResourceUID.text_to_id(uid))` 还原为完整路径,再 `load()`。

> **注意**:`_instantiate_instruction(type)` 是私有辅助方法,应缓存 `type_name → GDScript` 映射避免每次遍历 registry。

### 3.5 辅助方法

`_serialize_resource(val: Resource) -> String`: 若 Resource 有 `resource_path`,返回该路径(`uid://...` 或 `res://...`);否则返回 `""` 并 push_warning(不支持内联 Resource 序列化)。

`_append_unique(arr: Array, val) -> void`: 仅在 `val` 不在 `arr` 中时追加。

---

## 4. 变量处理策略

| 作用域 | 保存内容 | 导入行为 |
|--------|---------|----------|
| **Local** | 仅变量名 | 无需处理。运行时由 `SetVariable`/`AddVariable` 自动创建 |
| **Scope** | 变量名 + ScopeVariableContainer 节点路径 | 导入时检查容器是否存在。缺失时提示用户 |
| **Global** | 仅变量名 | 无需处理。`GlobalVariableService` 项目级存在 |

**关键原则:** 预设保存逻辑(指令序列 + 变量名),不保存状态(变量值)。值属于运行时上下文,不属于模板。

---

## 5. 文件存储

### 5.1 目录结构

```
addons/fuse/presets/
├── combat/
│   ├── bullet_spawn.tres   ← Resource 格式(编辑器原生)
│   ├── bullet_spawn.json   ← JSON 格式(AI 可读写)
│   ├── dash_attack.tres
│   └── dash_attack.json
├── movement/
│   └── platform_jump.{tres,json}
└── ui/
    └── button_hover.{tres,json}
```

### 5.2 双文件生成

导出时同时写入 `.tres` 和 `.json`。`.tres` 由 `ResourceSaver.save(preset, path)` 生成。`.json` 由 `preset.to_json()` → `FileAccess.open(path, WRITE)` 写入。

### 5.3 扫描注册

`FuseComponentScanner` 的 `_register_all_instructions()` 现扫描 `instructions/`。预设系统新增一个 `_register_all_presets()` 方法扫描 `presets/` 目录,注册到 `PresetRegistry`(新增类,类似 `InstructionRegistry` 模式)。或者直接在 `FuseComponentScanner` 中增加预设扫描。

**建议:** 新增静态方法 `PresetRegistry.scan_presets()`,在 `plugin.gd` 的 scanner 中调用。不与指令扫描混在一起。

---

## 6. 导出流程

### 6.1 触发入口

`instructions_array_property.gd` — 现有"添加/编辑/删除"三个按钮,新增第四个"导出为预设"按钮。

### 6.2 导出对话框

弹出 `AcceptDialog`,收集:

| 字段 | 类型 | 说明 |
|------|------|------|
| display_name | String | 预设名称 |
| category | String | 分类(自由文本,建议用现有 FUSE_CATEGORY_* 值) |
| description | String | 描述文本 |
| icon_name | String | FuseIconManager builtin_icon 名称 |

对话框底部自动显示扫描结果:"检测到 N 个唯一 NodePath, M 个变量"。

### 6.3 导出动作

1. 从 `object.get(property_name)` 获取 ActionRunner
2. 创建 `FusePreset` 实例,填充 metadata
3. `preset.instructions = action_runner.instructions.duplicate()`
4. `preset.variables = preset.collect_variables()`
5. 确保目录 `addons/fuse/presets/{category}/` 存在
6. `ResourceSaver.save(preset, "res://addons/fuse/presets/{category}/{name}.tres")`
7. 写入同名 `.json` 文件
8. 刷新预设面板

---

## 7. 导入流程

### 7.1 预设面板

右侧 Dock 面板,底部 `add_control_to_bottom_panel()` 或 `EditorInspector` 底部区域。

**V1 功能:**
- 按 `category` 分组折叠
- 每项显示:图标 + display_name + 指令数量
- 搜索框(过滤 display_name)
- "应用预设"按钮
- "导入 JSON"按钮(选择 .json 文件 → 反序列化为 FusePreset → 自动保存 .tres)

### 7.2 映射对话框

点击"应用预设"触发:

1. 收集 `preset.collect_unique_nodepaths()`
2. 对每个 NodePath,在当前场景中查找同名同类型节点 → 自动匹配
3. 未自动匹配的,提供节点选择下拉
4. 变量检查:scope 变量的容器是否存在
5. 用户确认 → `preset.apply_nodepath_mapping()` → 指令复制到目标 ActionRunner

### 7.3 预设面板 UI 位置

建议放在 Inspector 底部或右侧 Docker。具体实现用 Godot `EditorPlugin.add_control_to_bottom_panel()` 或 `add_control_to_dock()`。

---

## 8. 与现有系统的集成点

| 系统 | 集成方式 | 改动量 |
|------|---------|:---:|
| `instructions_array_property.gd` | 加"导出为预设"按钮 + 导出逻辑 | ~50 行 |
| `FuseComponentScanner` / 新增 `PresetRegistry` | 扫描 `presets/` 目录 | ~40 行 |
| `plugin.gd` | 注册预设面板 Dock | ~5 行 |
| `FuseIconManager` | 预设使用现有 builtin_icon | 0 |
| `FuseLocalization` | 预设分类/显示名可用翻译键(可选) | 0 |
| 5 个 CC 技能 | AI 读写 JSON → 生成预设 | 0(JSON 即接口) |

---

## 9. 分层依赖

```
FusePreset (Resource)
    ├── BaseInstruction (已有)
    ├── FuseIconManager (已有)
    └── PresetRegistry (新增,RefCounted)
            
instructions_array_property.gd ← 加导出按钮
    └── FusePreset

PresetPanel (新增,Control)
    └── FusePreset + PresetRegistry + NodePath 映射对话框

plugin.gd ← 注册 PresetPanel + 扫描 presets/
```

---

## 10. 不做什么(V1 范围)

- ❌ 在线预设商店/分享(留 V2)
- ❌ Behavior Pack(参数映射 + 嵌套预设)(留 V2)
- ❌ 预设版本自动迁移(只做 `format_version` 校验+提示)
- ❌ 历史/最近使用(MRU)
- ❌ 预设预览(执行前预览)
- ❌ Snippet(部分指令片段) — 那是 Stage 4 的独立特性

---

## 11. 验收标准

- [ ] `instructions_array_property.gd` 有"导出为预设"按钮,点击弹出填写对话框
- [ ] 导出后在 `presets/{category}/` 下生成 `.tres` + `.json` 双文件
- [ ] 预设面板可浏览、搜索、按分类折叠所有预设
- [ ] "应用预设"触发 NodePath 映射对话框,自动匹配同名节点
- [ ] 跨场景应用:同名节点自动映射,未匹配的手动选择
- [ ] Scope 变量容器存在性检查+提示
- [ ] JSON 格式与 Godot 可互转(`to_json()` ↔ `from_json()`)
- [ ] `format_version` 不匹配时提示用户
- [ ] 现有 143 个组件不受影响(回归)

---

**文档版本:** 1.0
**最后更新:** 2026-06-17
**审核状态:** 待审核
