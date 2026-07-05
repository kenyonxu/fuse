# Bricks 组件自动化审查工具

## 概述

`check_bricks_components.py` 是一个自动化审查脚本，用于检查所有 Bricks 指令组件是否应用了必要的标准修复模式。

## 检查项目

### 1. 节点查找方法（高严重性）
**问题描述**: 组件使用 `get_node()` 而非 `find_node_by_relative_path()`

**风险**: 可能导致 Resource 上下文下的节点查找失败

**示例**:
```gdscript
# ❌ 错误
var target = get_node(target_node)

# ✅ 正确
var target = BricksNodeUtils.find_node_by_relative_path(self, target_node)
```

### 2. 场景加载顺序检查（中严重性）
**问题描述**: 缺少场景加载顺序检查

**风险**: 可能导致属性信息在场景加载时丢失

**示例**:
```gdscript
# ❌ 错误
func execute(context: ExecutionContext):
    var target = get_node(target_node)  # 可能为 null

# ✅ 正确
func execute(context: ExecutionContext):
    if Engine.is_editor_hint() or not _target_node_instance:
        _update_target_node_info()
    var target = _target_node_instance
```

### 3. 缓存机制（低严重性）
**问题描述**: 缺少缓存机制

**风险**: 影响编辑器性能（Inspector 重复刷新）

**示例**:
```gdscript
# ❌ 错误
func _get_property_list():
    var props = _compute_properties()  # 每次都重新计算

# ✅ 正确
var _cached_properties: Array[PropertyInfo] = []
var _cached_node: Node = null

func _get_property_list():
    if _cached_node == _target_node and not _cached_properties.is_empty():
        return _cached_properties
    # 计算并缓存...
```

## 使用方法

### 基本用法

```bash
# 检查所有指令组件
python tools/check_bricks_components.py

# 保存结果到文件
python tools/check_bricks_components.py > tools/check_results.txt
```

### 输出格式

```
================================================================================
Bricks 组件自动化审查
================================================================================
找到 77 个 GDScript 文件

开始检查...

================================================================================
检查结果摘要
================================================================================

检查的文件总数: 77
有问题的文件数: 63

按严重性分类:
  高: 35
  中: 0
  低: 60
  总计: 95

================================================================================
详细问题列表
================================================================================

[高严重性问题]
  [高] instructions\animation\blend_animation.gd:140 - 节点查找方法: 使用 get_node() 而非 find_node_by_relative_path()，可能存在 Resource 上下文问题
  ...

[中严重性问题]
  (无)

[低严重性问题]
  [低] instructions\animation\blend_animation.gd:38 - 缓存机制: 缺少缓存机制，可能影响编辑器性能
  ...

================================================================================
检查完成
================================================================================
```

### 退出码

- **0**: 所有问题已修复或仅有低严重性问题
- **1**: 存在高严重性问题（需要立即修复）

## 验证测试

### 测试已知修复的组件

```bash
python -c "
from check_bricks_components import BricksComponentChecker

checker = BricksComponentChecker('addons/bricks')

# 测试已修复的组件
issues = checker.check_file('addons/bricks/instructions/node_operations/set_property_value.gd')
print(f'SetPropertyValue: {\"通过\" if len(issues) == 0 else \"失败\"}')"
```

### 测试需要修复的组件

```bash
python -c "
from check_bricks_components import BricksComponentChecker

checker = BricksComponentChecker('addons/bricks')

# 测试需要修复的组件
issues = checker.check_file('addons/bricks/instructions/animation/play_animation.gd')
print(f'PlayAnimation: 发现 {len(issues)} 个问题')
for issue in issues:
    print(f'  - {issue}')"
```

## 修复优先级

### 高优先级（高严重性）
- **必须修复**: 这些问题会导致运行时错误
- **预计影响**: 35 个文件需要修复
- **参考修复**: 查看 `SetPropertyValue` 或 `RunTargetNodeFunction`

### 中优先级（中严重性）
- **建议修复**: 这些问题可能导致属性丢失
- **预计影响**: 当前为 0 个文件

### 低优先级（低严重性）
- **可选修复**: 这些问题仅影响编辑器性能
- **预计影响**: 60 个文件需要修复
- **参考修复**: 查看 `SetPropertyValue` 的缓存实现

## 技术细节

### 文件扫描
- 递归扫描 `addons/bricks/instructions/` 目录
- 检查所有 `.gd` 文件
- 自动过滤非指令文件

### 正则表达式模式
- **节点查找**: `\.get_node\s*\(` 和 `\.has_node\s\(`
- **场景加载**: `Engine\.is_editor_hint\()` 和 `_\w+_instance == null`
- **缓存变量**: `_cached_\w+` 和 `_\w+_cache`

### 性能
- 扫描 77 个文件耗时约 2-3 秒
- 每个文件平均检查 3 个项目
- 支持并行检查（可扩展）

## 开发者信息

### 扩展检查项目

要添加新的检查项目，在 `BricksComponentChecker` 类中添加新方法：

```python
def _check_new_pattern(self, file_path: str, content: str, lines: List[str]) -> List[Issue]:
    """检查新模式"""
    issues = []
    # 实现检查逻辑
    return issues
```

然后在 `check_file()` 方法中调用：

```python
issues.extend(self._check_new_pattern(file_path, content, lines))
```

### 自定义严重性级别

在 `Severity` 枚举中添加新级别：

```python
class Severity(Enum):
    CRITICAL = "严重"  # 添加新的严重性级别
    HIGH = "高"
    MEDIUM = "中"
    LOW = "低"
```

## 相关文档

- [Bricks 系统文档](../addons/bricks/docs/)
- [节点路径解析问题](../addons/bricks/docs/development/node_path_resolution_problem.md)
- [属性持久化问题](../addons/bricks/docs/development/property_persistence_problem.md)
- [SetPropertyValue 修复参考](../addons/bricks/docs/development/set_property_value_fix_reference.md)

## 维护

最后更新: 2026-02-05
维护者: AI Assistant
版本: 1.0.0
