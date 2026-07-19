# 事件（Event）本地化规范

## 必须本地化的内容

### 1. 资源名称动态更新 (`_update_resource_name()`)

**要求**：必须使用 `FuseLocalization.translate()` 或 `translate_format()`

```gdscript
# ✅ 正确
func _update_resource_name() -> void:
    if _target_node_path.is_empty():
        resource_name = FuseLocalization.translate("FUSE_EVENT_ON_INPUT_ACTION_NAME")
    else:
        resource_name = FuseLocalization.translate_format(
            "FUSE_EVENT_ON_INPUT_ACTION_WITH_TARGET",
            {"target": _target_node_path}
        )

# ❌ 错误：硬编码中文字符串
func _update_resource_name() -> void:
    resource_name = "输入动作"
```

### 2. 事件描述 (`get_description()`)

**要求**：返回本地化的描述文本

```gdscript
# ✅ 正确
func get_description() -> String:
    return FuseLocalization.translate_format(
        "FUSE_EVENT_ON_INPUT_ACTION_DESC",
        {"action": _action_name}
    )

# ❌ 错误：硬编码中文字符串
func get_description() -> String:
    return "当检测到输入动作时触发"
```

### 3. 枚举提示字符串 (`hint_string`)

**关键性能要求**：`_get_property_list()` 会被编辑器频繁调用，必须使用静态缓存

```gdscript
# ❌ 错误：性能问题 - 每次都调用翻译函数
func _get_property_list() -> Array[Dictionary]:
    var props: Array[Dictionary] = []
    props.append({
        "name": "my_mode",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "%s,%s,%s" % [
            FuseLocalization.translate("FUSE_EVENT_MODE_A"),
            FuseLocalization.translate("FUSE_EVENT_MODE_B"),
            FuseLocalization.translate("FUSE_EVENT_MODE_C")
        ]
    })
    return props

# ✅ 正确：使用静态缓存
static var _cached_enum_modes: Array[String] = []
static var _enum_modes_cached: bool = false

static func _init_enum_modes_cache() -> void:
    if _enum_modes_cached:
        return
    _cached_enum_modes = [
        FuseLocalization.translate("FUSE_EVENT_MODE_A"),
        FuseLocalization.translate("FUSE_EVENT_MODE_B"),
        FuseLocalization.translate("FUSE_EVENT_MODE_C")
    ]
    _enum_modes_cached = true

func _get_property_list() -> Array[Dictionary]:
    _init_enum_modes_cache()  # 初始化缓存
    var props: Array[Dictionary] = []
    props.append({
        "name": "my_mode",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": ",".join(_cached_enum_modes)  # 使用缓存
    })
    return props
```

**重要说明**：
- `_get_property_list()` 会被编辑器频繁调用
- 直接调用翻译函数会导致严重性能问题
- 使用静态变量缓存翻译结果，只在首次调用时翻译

### 4. 验证错误 (`validate()`)

**要求**：返回本地化的错误消息

```gdscript
# ✅ 正确
func validate() -> String:
    if not _target_node:
        return FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY")
    return ""

# ❌ 错误：硬编码错误
func validate() -> String:
    if not _target_node:
        return "目标节点为空"
    return ""
```

### 5. 元数据

**要求**：使用 `EventMetadata` 的 `*_key` 属性

```gdscript
# ✅ 正确
static func get_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name_key = "FUSE_EVENT_ON_INPUT_ACTION_NAME"
    metadata.category_key = "FUSE_CATEGORY_INPUT"
    metadata.description_key = "FUSE_EVENT_ON_INPUT_ACTION_DESC"
    return metadata

# ❌ 错误：使用硬编码字符串
static func get_metadata() -> EventMetadata:
    var metadata = EventMetadata.new()
    metadata.name = "输入动作"
    metadata.category = "输入"
    metadata.description = "当检测到输入时触发"
    return metadata
```

## 禁止事项

- ❌ **绝对不要**添加 `const FuseLocalization = preload(...)` - `BaseEvent` 已提供
- ❌ **不要**在 `_get_property_list()` 中直接调用翻译函数（性能问题）
- ❌ **不要**使用硬编码中文字符串
- ❌ **不要**在元数据中使用 `name`/`category`/`description` 而非 `*_key`

## 常见错误

### 错误 1：代码中使用翻译键，但未添加到 CSV

```gdscript
# ❌ 错误：只修改了代码，忘记添加翻译键
resource_name = FuseLocalization.translate("FUSE_EVENT_MY_EVENT")
# 如果 CSV 中没有此键，资源名称将显示 "FUSE_EVENT_MY_EVENT"
```

**修复**：在 `translations.csv` 中添加：
```csv
FUSE_EVENT_MY_EVENT,我的事件,My Event
```

### 错误 2：枚举值未本地化

```gdscript
# ❌ 错误：枚举提示使用硬编码
"hint_string": "Mode A,Mode B,Mode C"

# ✅ 正确：枚举提示使用翻译（带缓存）
"hint_string": ",".join(_cached_enum_modes)
```

## 检查清单

- [ ] `_update_resource_name()` 使用翻译函数
- [ ] `get_description()` 使用翻译函数
- [ ] `_get_property_list()` 中的枚举使用静态缓存翻译
- [ ] `validate()` 返回本地化错误
- [ ] 元数据使用 `*_key` 属性
- [ ] 翻译键已添加到 `translations.csv`
- [ ] 翻译键命名符合规范（`FUSE_EVENT_*` 或 `FUSE_ERROR_*`）
