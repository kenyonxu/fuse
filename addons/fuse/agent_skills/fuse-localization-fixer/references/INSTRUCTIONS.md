# 指令（Instruction）本地化规范

## 必须本地化的内容

### 1. 资源名称动态更新 (`_update_resource_name()`)

**要求**：必须使用 `FuseLocalization.translate()` 或 `translate_format()`

```gdscript
# ✅ 正确
func _update_resource_name() -> void:
    if _variable_name.is_empty():
        resource_name = FuseLocalization.translate("FUSE_INSTRUCTION_SET_VARIABLE_NAME")
    else:
        resource_name = FuseLocalization.translate_format(
            "FUSE_INSTRUCTION_SET_VARIABLE_WITH_NAME",
            {"name": _variable_name}
        )

# ❌ 错误：硬编码中文字符串
func _update_resource_name() -> void:
    resource_name = "设置变量"
```

### 2. 指令描述 (`get_description()`)

**要求**：返回本地化的描述文本

```gdscript
# ✅ 正确
func get_description() -> String:
    return FuseLocalization.translate_format(
        "FUSE_INSTRUCTION_SET_VARIABLE_DESC",
        {"variable": _variable_name}
    )

# ❌ 错误：硬编码中文字符串
func get_description() -> String:
    return "设置变量的值"
```

### 3. 所有日志输出

**要求**：使用 `_log_*_localized()` 便捷方法

| 原方法 | 本地化方法 |
|-------|-----------|
| `_log_info(msg)` | `_log_info_localized(key, args)` |
| `_log_debug(msg)` | `_log_debug_localized(key, args)` |
| `_log_warning(msg)` | `_log_warning_localized(key, args)` |
| `_log_error(msg)` | `_log_error_localized(key, args)` |

```gdscript
# ✅ 正确
func execute(context: ExecutionContext):
    _start_execution(context)
    _log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
    _log_debug_localized("FUSE_LOG_VARIABLE_ACCESS", {"name": _variable_name})

# ❌ 错误：硬编码日志
func execute(context: ExecutionContext):
    _log_info("开始执行")
    _log_debug("访问变量: " + _variable_name)
```

### 4. 验证错误消息

**要求**：使用 `_set_error_localized()` 而非 `_set_error()`

```gdscript
# ✅ 正确
func validate() -> String:
    if _variable_name.is_empty():
        _set_error_localized(
            "FUSE_ERROR_VAR_NAME_EMPTY",
            FuseError.ErrorType.VALIDATION_ERROR
        )
        return "Validation failed"
    return ""

# ❌ 错误：硬编码错误
func validate() -> String:
    if _variable_name.is_empty():
        _set_error("变量名不能为空", FuseError.ErrorType.VALIDATION_ERROR)
        return "Validation failed"
    return ""
```

### 5. 参数化错误消息

**要求**：使用字典传递参数

```gdscript
# ✅ 正确
_set_error_localized(
    "FUSE_ERROR_VAR_NOT_FOUND",
    FuseError.ErrorType.VALIDATION_ERROR,
    {"name": variable_name}
)

# ❌ 错误：不使用参数化
_set_error_localized(
    "FUSE_ERROR_VAR_NOT_FOUND",
    FuseError.ErrorType.VALIDATION_ERROR
)
```

### 6. 元数据

**要求**：使用 `InstructionMetadata` 的 `*_key` 属性

```gdscript
# ✅ 正确
static func get_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_SET_VARIABLE_NAME"
    metadata.category_key = "FUSE_CATEGORY_VARIABLE"
    metadata.description_key = "FUSE_INSTRUCTION_SET_VARIABLE_DESC"
    return metadata

# ❌ 错误：使用硬编码字符串
static func get_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name = "设置变量"
    metadata.category = "变量"
    metadata.description = "设置变量的值"
    return metadata
```

## 禁止事项

- ❌ **不要**添加 `const FuseLocalization = preload(...)` - 基类已提供
- ❌ **不要**使用硬编码中文字符串
- ❌ **不要**在元数据中使用 `name`/`category`/`description` 而非 `*_key`

## 检查清单

- [ ] `_update_resource_name()` 使用翻译函数
- [ ] `get_description()` 使用翻译函数
- [ ] 所有 `_log_*()` 调用改为 `_log_*_localized()`
- [ ] 所有 `_set_error()` 改为 `_set_error_localized()`
- [ ] 元数据使用 `*_key` 属性
- [ ] 翻译键已添加到 `translations.csv`
- [ ] 翻译键命名符合规范（`FUSE_INSTRUCTION_*` 或 `FUSE_ERROR_*` 或 `FUSE_LOG_*`）
