---
name: fuse-localization-fixer
description: 检查和修复 Fuse 可视化编程插件的指令类、事件类、条件类的本地化问题。用于以下场景：(1) 检查 Fuse 组件（Instruction/Event/Condition）的本地化状态，(2) 识别本地化相关错误和反模式，(3) 修复本地化问题，(4) 添加缺失的翻译键到 CSV，(5) 验证本地化实现符合规范。支持检测硬编码中文字符串、缺失翻译键、错误使用翻译函数等问题。
---

# Fuse 本地化修复技能

检查和修复 Fuse 插件指令、事件、条件类的本地化问题。

## 快速诊断

当用户要求检查或修复本地化时，首先收集信息：

1. **确定目标组件类型**：Instruction（指令）或 Event（事件）或 Condition（条件）
2. **获取组件文件路径**：通常在 `addons/fuse/instructions/`、`addons/fuse/events/`、`addons/fuse/conditions/`
3. **检查翻译文件**：`addons/fuse/localization/translations.csv`

## 工作流程

### 步骤 1：检查本地化状态

读取目标组件文件，检查以下内容：

```gdscript
# ✅ 正确：使用本地化
resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_MY_INSTRUCTION_NAME")

# ❌ 错误：硬编码中文字符串
resource_name = "我的指令名称"
```

检查点：
- [ ] `_update_resource_name()` 是否使用翻译函数
- [ ] `get_description()` 是否使用翻译函数
- [ ] 日志调用是否使用 `_log_*_localized()` 方法
- [ ] 错误设置是否使用 `_set_error_localized()`
- [ ] 元数据是否使用 `*_key` 属性
- [ ] 是否存在硬编码中文字符串

### 步骤 2：识别常见错误

使用以下模式识别问题：

| 错误类型 | 检测模式 |
|---------|---------|
| 硬编码中文 | `resource_name = "[\u4e00-\u9fff]+"` |
| 缺失翻译键 | 代码使用键但 CSV 中不存在 |
| 错误预加载 | `const FuseLocalization = preload(...)` |
| 性能问题 | `_get_property_list()` 中直接调用翻译函数 |
| 非本地化日志 | `_log_info("硬编码文本")` 而非 `_log_info_localized(key, {})` |

### 步骤 3：修复本地化问题

#### 修复硬编码字符串

```gdscript
# 之前
func _update_resource_name() -> void:
    resource_name = "设置变量" if _variable_name.is_empty() else "设置 %s" % _variable_name

# 之后
func _update_resource_name() -> void:
    if _variable_name.is_empty():
        resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_SET_VARIABLE_NAME")
    else:
        resource_name = FuseLocalization.translate_format(
            "FUSE_INSTRUCTION_SET_VARIABLE_WITH_NAME",
            {"name": _variable_name}
        )
```

#### 修复日志调用

```gdscript
# 之前
_log_info("开始执行指令")

# 之后
_log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
```

#### 修复错误消息

```gdscript
# 之前
_set_error("变量不存在", FuseError.ErrorType.VALIDATION_ERROR)

# 之后
_set_error_localized(
    "FUSE_ERROR_VAR_NOT_FOUND",
    FuseError.ErrorType.VALIDATION_ERROR
)
```

#### 修复枚举提示字符串（性能问题）

```gdscript
# 之前（性能问题）
func _get_property_list() -> Array[Dictionary]:
    props.append({
        "name": "my_mode",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": "%s,%s" % [
            FuseLocalization.translate("MODE_A"),
            FuseLocalization.translate("MODE_B")
        ]
    })
    return props

# 之后（使用静态缓存）
static var _cached_enum_modes: Array[String] = []
static var _enum_modes_cached: bool = false

static func _init_enum_modes_cache() -> void:
    if _enum_modes_cached:
        return
    _cached_enum_modes = [
        FuseLocalization.translate("MODE_A"),
        FuseLocalization.translate("MODE_B")
    ]
    _enum_modes_cached = true

func _get_property_list() -> Array[Dictionary]:
    _init_enum_modes_cache()
    var props: Array[Dictionary] = []
    props.append({
        "name": "my_mode",
        "type": TYPE_STRING,
        "hint": PROPERTY_HINT_ENUM,
        "hint_string": ",".join(_cached_enum_modes)
    })
    return props
```

### 步骤 4：添加翻译键到 CSV

修复代码后，在 `addons/fuse/localization/translations.csv` 添加翻译：

```csv
FUSE_INSTRUCTION_SET_VARIABLE_WITH_NAME,设置 {name},Set {name}
```

格式：`key,zh_CN,en_US`

### 步骤 5：验证修复

使用翻译检查工具验证：

```bash
# 在 Godot 编辑器中：项目 → 工具 → 执行脚本
# 选择：addons/fuse/localization/translation_checker.gd
```

检查工具报告：
- 翻译键总数
- 分类统计
- 翻译完整性
- 覆盖率
- 命名规范检查

## 参考文档

详细的本地化规范、翻译键命名规则和最佳实践，参见：
- [INSTRUCTIONS.md](references/INSTRUCTIONS.md) - 指令本地化规范
- [EVENTS.md](references/EVENTS.md) - 事件本地化规范
- [CONDITIONS.md](references/CONDITIONS.md) - 条件本地化规范
- [NAMING.md](references/NAMING.md) - 翻译键命名规范

## 常见问题

**Q: 如何生成翻译键？**
A: 使用 `FUSE_` 前缀 + 组件类型（INSTRUCTION/EVENT/CONDITION）+ 描述性名称，例如 `FUSE_INSTRUCTION_SET_VARIABLE_NAME`

**Q: 所有文本都需要本地化吗？**
A: 用户可见的文本需要本地化，内部调试消息可以保持硬编码

**Q: 可以添加预加载语句吗？**
A: ❌ 不可以。BaseInstruction/BaseEvent/BaseCondition 已提供，不要添加 `const FuseLocalization = preload(...)`

**Q: 如何处理参数化文本？**
A: 使用 `FuseLocalization.translate_format(key, {"param": value})`，翻译文本中使用 `{param}` 占位符
