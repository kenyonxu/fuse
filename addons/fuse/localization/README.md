# Fuse 本地化系统

Fuse 可视化编程插件的轻量级本地化解决方案。

## 特性

- ✅ **轻量级**: 基于 CSV 文件，无需外部依赖
- ✅ **高性能**: 静态缓存优化，0.12μs/次查询
- ✅ **易维护**: 简单的 CSV 格式，易于编辑
- ✅ **自动化**: 三层语言检测，无需手动切换
- ✅ **完整覆盖**: 2498+ 翻译键，100% 覆盖率（Trigger、ExecutionContext、ActionRunner 已完全本地化）

## 快速开始

### 配置语言

编辑项目根目录的 `project.godot`:

```ini
[internationalization]
locale/locale="en"  # 或 "zh_CN"
```

### 基础使用

```gdscript
# 加载并初始化
var FuseLocalization = load("res://addons/fuse/localization/fuse_localization.gd")
FuseLocalization.init()

# 翻译文本
var text = FuseLocalization.translate("FUSE_UI_BTN_ADD")

# 参数化翻译
var error = FuseLocalization.translate_format(
    "FUSE_ERROR_VAR_NOT_FOUND",
    {"name": "my_var"}
)
```

## 文档

- [用户使用指南](USER_GUIDE.md) - 如何使用本地化系统
- [翻译键参考](translation_keys.md) - 所有翻译键列表
- [实施计划](../docs/plans/2026-01-25-localization-stage4-refinement.md) - 架构设计和实现

## 核心类本地化状态

以下核心类已完成本地化：

- ✅ **Trigger** - 触发器核心类（所有日志、错误、验证消息）
- ✅ **ExecutionContext** - 执行上下文类（所有变量操作、节点访问消息）
- ✅ **ActionRunner** - 动作运行器类（所有执行流程、错误处理消息）

这些核心类使用 `_log_*_localized()` 方法输出本地化消息，遵循统一的本地化规范。

**本地化方法**：
- `_log_debug_localized(key, args)` - 本地化调试日志
- `_log_info_localized(key, args)` - 本地化信息日志
- `_log_warning_localized(key, args)` - 本地化警告日志
- `_log_error_localized(key, args)` - 本地化错误日志
- `_create_fuse_error_localized(key, type, context, args)` - 本地化错误创建

**翻译键统计**（截至 2026-01-31）：
- 日志消息 (LOG): 450 个
- 错误消息 (ERROR): 340 个
- UI 文本: 159 个
- 指令相关: 610 个
- 事件相关: 357 个
- 条件相关: 251 个
- 其他: 331 个
- **总计**: 2498 个

## 工具

### 翻译检查工具

位置: `addons/fuse/localization/translation_checker.gd`

在编辑器中执行检查翻译完整性：

1. 点击 **项目 → 工具 → 执行脚本**
2. 选择 `translation_checker.gd`
3. 查看控制台输出

检查工具会报告：
- 翻译键总数
- 分类统计
- 翻译完整性
- 覆盖率（指令和事件）
- 命名规范检查

### 性能基准测试

位置: `test_scripts/performance_localization_benchmark.gd`

测试系统性能和开销：

```bash
E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe --headless --script test_scripts/performance_localization_benchmark.gd
```

## 架构

```
FuseLocalization (核心管理器)
├── CSV 解析器
├── 语言检测器 (三层检测)
├── 翻译缓存 (静态优化)
└── API (translate, translate_format)

使用方:
├── FuseLogger (本地化日志)
├── FuseError (本地化错误)
├── BaseInstruction (便捷方法)
└── BaseEvent (便捷方法)
```

### 三层语言检测

系统按以下优先级检测语言：

1. **项目设置** (最高优先级)
   - 在 `project.godot` 中配置 `locale/locale`

2. **编辑器界面语言**
   - 使用编辑器的语言设置（仅编辑器环境）

3. **操作系统语言** (回退选项)
   - 使用系统语言设置

### 静态缓存优化

- 翻译数据在首次加载时缓存
- 语言检测后保持不变
- 性能提升 70%
- 内存占用: ~30KB (298 个翻译键)

## 性能

| 指标 | 值 |
|------|-----|
| 初始化时间 | < 1ms |
| 翻译查询 | 0.12μs/次 |
| 参数化翻译 | 0.15μs/次 |
| 内存占用 | ~30KB |
| CSV 加载 | 0.13ms |
| CSV 解析 | 0.32ms |

详见 [性能基准测试报告](../../test_scripts/PERFORMANCE_BENCHMARK_REPORT.md)。

## 语言支持

- ✅ 简体中文 (zh_CN)
- ✅ 英语 (en_US)
- 🚧 更多语言（可扩展）

## 开发指南

### 添加新翻译

1. 编辑 `translations.csv`
2. 添加新行: `key,zh_CN,en_US`
3. 运行翻译检查工具验证

示例：
```csv
FUSE_MY_NEW_KEY,我的新翻译,My New Translation
```

### 添加新语言

需要 3 个步骤：

#### 1. 在 CSV 中添加新列

```csv
key,zh_CN,en_US,ja_JP
FUSE_UI_BTN_ADD,添加,Add,追加
```

#### 2. 在 FuseLocalization 中添加语言枚举

在 `fuse_localization.gd` 中：

```gdscript
enum Locale {
    ZH_CN,  # 简体中文
    EN_US,  # 英语
    JA_JP   # 日语（新增）
}
```

#### 3. 更新加载逻辑和显示名称

```gdscript
# 在 _load_translations() 中添加新语言
_translations[key] = {
    Locale.ZH_CN: zh,
    Locale.EN_US: en,
    Locale.JA_JP: ja  # 新增
}

# 在 get_locale_name() 中添加
match locale:
    Locale.ZH_CN: return "简体中文"
    Locale.EN_US: return "English"
    Locale.JA_JP: return "日本語"  # 新增

# 在 _detect_system_locale() 中添加检测逻辑
if os_locale.begins_with("ja"):
    _current_locale = Locale.JA_JP
    return
```

### 在指令中使用本地化

#### 方法1: 使用便捷方法（推荐）

```gdscript
class_name MyInstruction extends BaseInstruction

func execute(context: ExecutionContext):
    _start_execution(context)

    # 本地化日志
    _log_info_localized("FUSE_LOG_EXECUTION_STARTED", {})
    _log_debug_localized("FUSE_LOG_VARIABLE_ACCESS", {"name": "my_var"})

    # 本地化错误
    if has_error():
        _set_error_localized(
            "FUSE_ERROR_VALIDATION_FAILED",
            FuseError.ErrorType.VALIDATION_ERROR
        )
        finished.emit()
        return

    finished.emit()
```

#### 方法2: 直接调用 FuseLocalization

```gdscript
func some_function():
    # 简单翻译
    var text = FuseLocalization.translate("FUSE_UI_BTN_ADD")

    # 参数化翻译
    var error = FuseLocalization.translate_format(
        "FUSE_ERROR_VAR_NOT_FOUND",
        {"name": "my_variable"}
    )
```

#### 方法3: 在元数据中使用

```gdscript
class_name MyCustomInstruction extends BaseInstruction

static func get_metadata() -> InstructionMetadata:
    var metadata = InstructionMetadata.new()
    metadata.name_key = "FUSE_INSTRUCTION_MY_CUSTOM_NAME"
    metadata.category_key = "FUSE_CATEGORY_CUSTOM"
    metadata.description_key = "FUSE_INSTRUCTION_MY_CUSTOM_DESC"
    return metadata
```

## 本地化规范

### 指令 (Instructions) 本地化要求

**必须本地化的内容：**

1. **资源名称动态更新**
   ```gdscript
   func _update_resource_name() -> void:
       resource_name = FuseLocalization.translate_format(
           "FUSE_INSTRUCTION_MY_INSTRUCTION_NAME",
           {"param": _my_parameter}
       )
   ```

2. **指令描述**
   ```gdscript
   func get_description() -> String:
       return FuseLocalization.translate_format(
           "FUSE_INSTRUCTION_MY_INSTRUCTION_DESC",
           {"value": _my_value}
       )
   ```

3. **所有日志输出**
   - `_log_info()` → `_log_info_localized(key, args)`
   - `_log_debug()` → `_log_debug_localized(key, args)`
   - `_log_warning()` → `_log_warning_localized(key, args)`
   - `_log_error()` → `_log_error_localized(key, args)`

4. **验证错误消息**
   ```gdscript
   # ❌ 错误：硬编码错误消息
   _set_error("变量不存在", FuseError.ErrorType.VALIDATION_ERROR)

   # ✅ 正确：使用本地化键
   _set_error_localized(
       "FUSE_ERROR_VAR_NOT_FOUND",
       FuseError.ErrorType.VALIDATION_ERROR
   )
   ```

5. **参数化错误消息**
   ```gdscript
   _set_error_localized(
       "FUSE_ERROR_VAR_NOT_FOUND",
       FuseError.ErrorType.VALIDATION_ERROR,
       {"name": variable_name}  # 参数字典
   )
   ```

6. **元数据**
   - 使用 `InstructionMetadata` 的 `*_key` 属性
   - `name_key`, `category_key`, `description_key`

**注意事项：**
- ❌ **不要**添加 `const FuseLocalization = preload(...)` - 基类已提供
- ✅ 所有翻译键必须添加到 `translations.csv`
- ✅ 翻译键命名：`FUSE_ERROR_*`, `FUSE_LOG_*`, `FUSE_INSTRUCTION_*`
- ⚠️ **常见错误**: `_update_resource_name()` 和 `get_description()` 使用硬编码中文字符串

---

### 事件 (Events) 本地化要求

**必须本地化的内容：**

1. **资源名称动态更新**
   ```gdscript
   func _update_resource_name() -> void:
       resource_name = FuseLocalization.translate_format(
           "FUSE_EVENT_MY_EVENT_NAME",
           {"param": _my_parameter}
       )
   ```

2. **事件描述**
   ```gdscript
   func get_description() -> String:
       return FuseLocalization.translate_format(
           "FUSE_EVENT_MY_EVENT_DESC",
           {"value": _my_value}
       )
   ```

3. **枚举提示字符串 (hint_string)**
   ```gdscript
   # ❌ 错误：在 _get_property_list() 中直接调用翻译函数
   func _get_property_list() -> Array[Dictionary]:
       props.append({
           "name": "my_mode",
           "type": TYPE_STRING,
           "hint": PROPERTY_HINT_ENUM,
           "hint_string": "%s,%s,%s" % [
               FuseLocalization.translate("FUSE_EVENT_MODE_A"),  # 性能问题
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

   **重要说明：**
   - `_get_property_list()` 会被编辑器频繁调用，直接调用翻译函数会导致性能问题
   - 使用静态变量缓存翻译结果，只在首次调用时翻译
   - 在 `_get_property_list()` 中使用缓存的字符串

4. **验证错误**
   ```gdscript
   func validate() -> String:
       if not _target_node:
           return FuseLocalization.translate("FUSE_ERROR_TARGET_NODE_EMPTY")
       return ""
   ```

5. **元数据**
   - 使用 `EventMetadata` 的 `*_key` 属性
   - `name_key`, `category_key`, `description_key`

**关键要求：**
- ❌ **绝对不要**添加 `const FuseLocalization = preload(...)` - `BaseEvent` 已提供
- ✅ **必须**在 CSV 中添加所有使用的翻译键
- ✅ 枚举值需要本地化时，使用动态 `hint_string`
- ⚠️ **常见错误**: 代码中使用了翻译键，但未添加到 CSV → 导致显示键名而非翻译文本

**示例错误：**
```gdscript
# ❌ 错误：只修改了代码，忘记添加翻译键到 CSV
resource_name = FuseLocalization.translate("FUSE_EVENT_MY_EVENT")
# 如果 CSV 中没有此键，资源名称将显示 "FUSE_EVENT_MY_EVENT"
```

---

### 条件 (Conditions) 本地化要求

**必须本地化的内容：**

1. **资源名称动态更新**
   ```gdscript
   func _update_resource_name() -> void:
       resource_name = FuseLocalization.translate_format(
           "FUSE_CONDITION_MY_CONDITION_NAME",
           {"param": _my_parameter}
       )
   ```

2. **元数据系统**
   ```gdscript
   static func get_metadata() -> ConditionMetadata:
       var metadata = ConditionMetadata.new()
       metadata.name_key = "FUSE_CONDITION_MY_CONDITION_NAME"
       metadata.category_key = "FUSE_CATEGORY_MY_CATEGORY"
       metadata.description_key = "FUSE_CONDITION_MY_CONDITION_DESC"
       return metadata
   ```

3. **关键词多语言支持**
   ```gdscript
   static func get_keywords() -> Array[String]:
       return [
           "FUSE_CONDITION_KEYWORD_1",
           "FUSE_CONDITION_KEYWORD_2"
       ]
   ```

4. **验证错误**
   ```gdscript
   func validate() -> String:
       if not _target:
           return FuseLocalization.translate("FUSE_ERROR_TARGET_REQUIRED")
       return ""
   ```

**注意事项：**
- ❌ **不要**添加 `const FuseLocalization = preload(...)` - 基类已提供
- ✅ Condition 系统已 100% 完成本地化，参考现有条件作为模板

---

### 翻译键命名规范

| 前缀 | 用途 | 示例 |
|------|------|------|
| `FUSE_ERROR_*` | 错误消息 | `FUSE_ERROR_VAR_NOT_FOUND` |
| `FUSE_LOG_*` | 日志消息 | `FUSE_LOG_EXECUTION_STARTED` |
| `FUSE_INSTRUCTION_*` | 指令相关 | `FUSE_INSTRUCTION_SET_VARIABLE_NAME` |
| `FUSE_EVENT_*` | 事件相关 | `FUSE_EVENT_ON_INPUT_ACTION_DESC` |
| `FUSE_CONDITION_*` | 条件相关 | `FUSE_CONDITION_COMPARE_VALUES_NAME` |
| `FUSE_CATEGORY_*` | 分类名称 | `FUSE_CATEGORY_ANIMATION` |
| `FUSE_UI_*` | 界面文本 | `FUSE_UI_BTN_ADD` |

---

### 添加翻译的完整流程

1. **修改代码** - 使用 `FuseLocalization.translate()` 或 `_log_*_localized()`
2. **添加翻译键** - 在 `translations.csv` 中添加所有语言翻译
3. **验证完整性** - 运行 `translation_checker.gd` 检查
4. **测试显示** - 在编辑器中验证翻译正确显示

**检查清单：**
- [ ] 代码中使用了本地化方法
- [ ] 所有翻译键已添加到 CSV
- [ ] CSV 中提供了所有语言的翻译
- [ ] 运行了翻译检查工具
- [ ] 在编辑器中验证了显示效果

---

## 文件结构

```
addons/fuse/localization/
├── fuse_localization.gd          # 核心管理器
├── translations.csv                # 翻译数据
├── translation_checker.gd          # 翻译检查工具
├── README.md                       # 本文档
├── USER_GUIDE.md                   # 用户使用指南
├── translation_keys.md             # 翻译键参考文档
└── task_3.4_completion_report.md   # 完成报告
```

## API 参考

### 初始化

```gdscript
FuseLocalization.init()  # 初始化系统（通常在插件加载时调用）
```

### 翻译方法

```gdscript
# 简单翻译
FuseLocalization.translate(key: String) -> String

# 参数化翻译
FuseLocalization.translate_format(key: String, args: Dictionary) -> String

# 设置语言
FuseLocalization.set_locale(locale: Locale)

# 获取当前语言
FuseLocalization.get_current_locale() -> Locale

# 获取语言代码
FuseLocalization.get_locale_code() -> String

# 重新加载翻译
FuseLocalization.reload_translations()
```

### 统计方法

```gdscript
# 获取翻译统计
FuseLocalization.get_translation_stats() -> Dictionary

# 获取缺失翻译
FuseLocalization.get_missing_translations() -> Array
```

## 贡献

### 提交翻译更新

提交翻译更新时，请使用以下格式：

```
docs(localization): 更新翻译键参考文档

- 添加新键: FUSE_EXAMPLE_NEW_KEY
- 更新键数: 298 -> 299
- 更新使用示例

相关任务: #123
```

### 代码规范

- 翻译键使用 `FUSE_` 前缀
- 使用全大写和下划线命名
- 提供所有语言的翻译
- 更新相关文档

## 常见问题

### Q: 如何切换语言？

A: 编辑 `project.godot` 文件，修改 `locale/locale` 的值：

```ini
locale/locale="en"     # 英语
locale/locale="zh_CN"  # 简体中文
```

保存后重新打开项目即可生效。

### Q: 为什么有些文本还是中文/英文？

A: 可能的原因：
1. 该文本的翻译键缺失 - 运行翻译检查工具确认
2. 代码中使用了硬编码文本 - 需要替换为翻译键
3. 翻译系统未初始化 - 确保调用了 `FuseLocalization.init()`

### Q: 性能影响如何？

A: 非常小：
- 初始化: < 1ms（仅首次）
- 翻译查询: 0.12μs/次（使用缓存）
- 内存占用: ~30KB（298 个翻译键）

详见 [性能基准测试报告](../../test_scripts/PERFORMANCE_BENCHMARK_REPORT.md)。

## 相关资源

- [用户使用指南](USER_GUIDE.md) - 详细的使用说明
- [翻译键参考](translation_keys.md) - 所有翻译键列表
- [实施计划](../docs/plans/2026-01-25-localization-stage4-refinement.md) - 系统设计和实现细节

## 许可证

遵循 Fuse 插件的主许可证。

---

**版本**: 1.0
**最后更新**: 2026-01-25
**维护者**: Fuse 本地化团队
