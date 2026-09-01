# 翻译键命名规范

## 命名规则

所有翻译键必须遵循以下规则：
- 使用 `FUSE_` 前缀
- 全大写字母
- 使用下划线分隔单词
- 描述性命名，清晰表达用途

## 前缀分类

| 前缀 | 用途 | 示例 |
|------|------|------|
| `FUSE_ERROR_*` | 错误消息 | `FUSE_ERROR_VAR_NOT_FOUND` |
| `FUSE_LOG_*` | 日志消息 | `FUSE_LOG_EXECUTION_STARTED` |
| `FUSE_INSTRUCTION_*` | 指令相关 | `FUSE_INSTRUCTION_SET_VARIABLE_NAME` |
| `FUSE_EVENT_*` | 事件相关 | `FUSE_EVENT_ON_INPUT_ACTION_DESC` |
| `FUSE_CONDITION_*` | 条件相关 | `FUSE_CONDITION_COMPARE_VALUES_NAME` |
| `FUSE_CATEGORY_*` | 分类名称 | `FUSE_CATEGORY_ANIMATION` |
| `FUSE_UI_*` | 界面文本 | `FUSE_UI_BTN_ADD` |

## 命名模式

### 指令命名

**格式**：`FUSE_INSTRUCTION_<动作>_<对象>_<类型>`

- `_NAME` - 指令名称（短）
- `_DESC` - 指令描述（长）
- `_WITH_<参数>` - 带参数的名称

示例：
```csv
FUSE_INSTRUCTION_SET_VARIABLE_NAME,设置变量,Set Variable
FUSE_INSTRUCTION_SET_VARIABLE_DESC,设置变量的值，支持从另一个变量复制值或直接设置新值,Sets the value of a variable, supports copying from another variable or setting a new value
FUSE_INSTRUCTION_SET_VARIABLE_WITH_NAME,设置 {name},Set {name}
```

### 事件命名

**格式**：`FUSE_EVENT_<触发器>_<类型>`

- `_NAME` - 事件名称
- `_DESC` - 事件描述
- `_WITH_<参数>` - 带参数的名称

示例：
```csv
FUSE_EVENT_ON_INPUT_ACTION_NAME,输入动作,Input Action
FUSE_EVENT_ON_INPUT_ACTION_DESC,当检测到指定输入动作时触发,Triggers when the specified input action is detected
FUSE_EVENT_ON_INPUT_ACTION_WITH_ACTION,{action} 动作,{action} Action
```

### 条件命名

**格式**：`FUSE_CONDITION_<比较类型>_<类型>`

- `_NAME` - 条件名称
- `_DESC` - 条件描述
- `_WITH_<参数>` - 带参数的名称

示例：
```csv
FUSE_CONDITION_COMPARE_VALUES_NAME,比较值,Compare Values
FUSE_CONDITION_COMPARE_VALUES_DESC,比较两个值的关系,Compares the relationship between two values
FUSE_CONDITION_COMPARE_VALUES_WITH_VARS,{a} {operator} {b},{a} {operator} {b}
```

### 错误消息命名

**格式**：`FUSE_ERROR_<问题描述>`

示例：
```csv
FUSE_ERROR_VAR_NOT_FOUND,未找到变量：{name},Variable not found: {name}
FUSE_ERROR_TARGET_NODE_EMPTY,目标节点为空,Target node is empty
FUSE_ERROR_VAR_NAME_EMPTY,变量名不能为空,Variable name cannot be empty
```

### 日志消息命名

**格式**：`FUSE_LOG_<操作>_<对象>`

示例：
```csv
FUSE_LOG_EXECUTION_STARTED,开始执行指令,Started executing instruction
FUSE_LOG_VARIABLE_ACCESS,访问变量：{name},Accessing variable: {name}
FUSE_LOG_EXECUTION_COMPLETED,指令执行完成,Instruction execution completed
```

### 分类命名

**格式**：`FUSE_CATEGORY_<领域>`

示例：
```csv
FUSE_CATEGORY_VARIABLE,变量,Variable
FUSE_CATEGORY_FLOW_CONTROL,流程控制,Flow Control
FUSE_CATEGORY_ANIMATION,动画,Animation
FUSE_CATEGORY_INPUT,输入,Input
```

### 关键词命名

**格式**：`FUSE_CONDITION_KEYWORD_<词>`

示例：
```csv
FUSE_CONDITION_KEYWORD_COMPARE,比较,Compare
FUSE_CONDITION_KEYWORD_EQUALS,等于,Equals
FUSE_CONDITION_KEYWORD_GREATER,大于,Greater
```

## 参数化翻译

### 占位符格式

使用 `{参数名}` 格式的占位符：

```csv
# 翻译文本
FUSE_ERROR_VAR_NOT_FOUND,未找到变量：{name},Variable not found: {name}

# 代码调用
FuseLocalization.translate_format(
    "FUSE_ERROR_VAR_NOT_FOUND",
    {"name": "my_variable"}
)
# 输出：未找到变量：my_variable
```

### 多参数示例

```csv
FUSE_CONDITION_COMPARE_VALUES_WITH_VARS,{a} {operator} {b},{a} {operator} {b}

# 代码调用
FuseLocalization.translate_format(
    "FUSE_CONDITION_COMPARE_VALUES_WITH_VARS",
    {"a": "health", "operator": ">", "b": "0"}
)
# 输出：health > 0
```

## 添加翻译的完整流程

1. **修改代码** - 使用 `FuseLocalization.translate()` 或 `_log_*_localized()`
2. **添加翻译键** - 在 `translations.csv` 中添加所有语言翻译
3. **验证完整性** - 运行 `translation_checker.gd` 检查
4. **测试显示** - 在编辑器中验证翻译正确显示

### 检查清单

- [ ] 代码中使用了本地化方法
- [ ] 所有翻译键已添加到 CSV
- [ ] CSV 中提供了所有语言的翻译
- [ ] 运行了翻译检查工具
- [ ] 在编辑器中验证了显示效果
