# 条件（Condition）本地化规范

## 必须本地化的内容

### 1. 资源名称动态更新 (`_update_resource_name()`)

**要求**：必须使用 `FuseLocalization.translate()` 或 `translate_format()`

```gdscript
# ✅ 正确
func _update_resource_name() -> void:
    if _variable_a.is_empty() or _variable_b.is_empty():
        resource_name = FuseLocalization.translate("FUSE_CONDITION_COMPARE_VALUES_NAME")
    else:
        resource_name = FuseLocalization.translate_format(
            "FUSE_CONDITION_COMPARE_VALUES_WITH_VARS",
            {"a": _variable_a, "b": _variable_b}
        )

# ❌ 错误：硬编码中文字符串
func _update_resource_name() -> void:
    resource_name = "比较值"
```

### 2. 元数据系统

**要求**：使用 `ConditionMetadata` 的 `*_key` 属性

```gdscript
# ✅ 正确
static func get_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name_key = "FUSE_CONDITION_COMPARE_VALUES_NAME"
    metadata.category_key = "FUSE_CATEGORY_COMPARISON"
    metadata.description_key = "FUSE_CONDITION_COMPARE_VALUES_DESC"
    return metadata

# ❌ 错误：使用硬编码字符串
static func get_metadata() -> ConditionMetadata:
    var metadata = ConditionMetadata.new()
    metadata.name = "比较值"
    metadata.category = "比较"
    metadata.description = "比较两个值"
    return metadata
```

### 3. 关键词多语言支持

**要求**：`get_keywords()` 返回翻译键数组，而非硬编码关键词

```gdscript
# ✅ 正确：返回翻译键
static func get_keywords() -> Array[String]:
    return [
        "FUSE_CONDITION_KEYWORD_COMPARE",
        "FUSE_CONDITION_KEYWORD_EQUALS",
        "FUSE_CONDITION_KEYWORD_GREATER"
    ]

# ❌ 错误：返回硬编码关键词
static func get_keywords() -> Array[String]:
    return ["比较", "等于", "大于"]
```

**注意**：Condition 系统会自动翻译这些键。

### 4. 验证错误 (`validate()`)

**要求**：返回本地化的错误消息

```gdscript
# ✅ 正确
func validate() -> String:
    if not _target:
        return FuseLocalization.translate("FUSE_ERROR_TARGET_REQUIRED")
    return ""

# ❌ 错误：硬编码错误
func validate() -> String:
    if not _target:
        return "目标不能为空"
    return ""
```

## 注意事项

- ❌ **不要**添加 `const FuseLocalization = preload(...)` - 基类已提供
- ✅ Condition 系统已 100% 完成本地化，参考现有条件作为模板
- ✅ 关键词系统会自动处理翻译

## 检查清单

- [ ] `_update_resource_name()` 使用翻译函数
- [ ] 元数据使用 `*_key` 属性
- [ ] `get_keywords()` 返回翻译键数组
- [ ] `validate()` 返回本地化错误
- [ ] 翻译键已添加到 `translations.csv`
- [ ] 翻译键命名符合规范（`FUSE_CONDITION_*` 或 `FUSE_ERROR_*`）

## 参考模板

Condition 系统已完成本地化，参考以下现有条件：

- `CompareValues` - 比较两个值
- `CheckVariable` - 检查变量
- `NodeExists` - 节点存在性检查

这些条件展示了正确的本地化实现模式。
