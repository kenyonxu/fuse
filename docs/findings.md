# 研究发现 (Findings)

**Created:** 2026-01-11
**Last Updated:** 2026-01-11

---

## Bricks 系统分析

### 核心机制发现

#### 1. 方法缓存机制 (Method Caching)

**文件:** `addons/bricks/instructions/run_target_node_function.gd`

**关键变量:**
```gdscript
var _method_cache: Dictionary = {}           # 运行时缓存
var serialized_method_cache: Array = []      # 序列化缓存（持久化）
var _cache_valid: bool = false               # 缓存有效性标志
```

**关键发现:**
- **双重缓存设计**: 运行时使用字典快速查找，序列化时转为数组存储
- **增量序列化**: 只序列化必要的方法信息（name, args, return_val, flags）
- **延迟加载**: 编辑器启动时从 `serialized_method_cache` 恢复，避免实时反射

**轻量级方法信息结构:**
```gdscript
{
    "name": "method_name",
    "args": [],  # 参数信息数组
    "return_val": TYPE_NIL,
    "flags": METHOD_FLAG_NORMAL
}
```

**性能优化技巧:**
- 节点路径哈希缓存 (`_target_node_path_hash`) - 避免重复查找
- 时间戳缓存 (`_last_node_lookup_time`) - 减少频繁节点查询
- 方法签名缓存 (`_cached_method_signatures`) - 避免重复获取同一方法

---

#### 2. 动态属性生成 (Dynamic Property Generation)

**实现方式:** `_get_property_list()` + 自定义 `_set()` / `_get()`

**方法选择下拉菜单:**
```gdscript
# 枚举类型提示
properties.append({
    "name": "target_function",
    "type": TYPE_STRING,
    "hint": PROPERTY_HINT_ENUM,
    "hint_string": ",".join(method_names),  # 方法名列表
    "usage": PROPERTY_USAGE_DEFAULT
})
```

**动态参数属性:**
```gdscript
# 为每个参数创建属性
for i in range(param_count):
    properties.append({
        "name": "param_%d" % i,
        "type": param_info.get("type", TYPE_NIL),
        "hint": param_info.get("hint", PROPERTY_HINT_NONE),
        "hint_string": param_info.get("hint_string", ""),
        "default": param_info.get("default_value", null),
        "usage": PROPERTY_USAGE_DEFAULT
    })
```

**关键机制:**
- 使用 `param_` 前缀标识动态参数
- 在 `_set()` 中拦截参数赋值，自动调整数组大小
- 在 `_get()` 中提供默认值，处理 null 情况

---

#### 3. 线程安全机制 (Thread Safety)

**问题:** 编辑器后台线程调用节点方法会崩溃

**解决方案:**

1. **检查路径而非节点实例:**
```gdscript
# ❌ 错误：后台线程会崩溃
if _target_node_instance:  # 可能访问无效节点

# ✅ 正确：只检查路径字符串
if not target_node.is_empty():  # 安全
```

2. **延迟节点查找:**
```gdscript
func _initialize_after_load():
    call_deferred("_update_target_node_info")  # 主线程执行
```

3. **防止属性更新循环:**
```gdscript
var _is_updating_properties: bool = false

func _get_property_list():
    if _is_updating_properties:
        return []  # 防止递归
```

---

#### 4. 参数验证机制 (Parameter Validation)

**类型兼容性检查:**

**支持的类型转换:**
- `NIL` → `OBJECT` (允许 null 对象)
- `INT` ↔ `FLOAT` (数值类型互转)
- `INT`/`FLOAT` ↔ `STRING` (字符串解析)
- `BOOL` ↔ `INT`/`FLOAT` (布尔数值转换)

**验证流程:**
```
1. 检查参数数量
2. 检查每个参数类型
3. 允许兼容的类型转换
4. 返回详细错误信息
```

---

#### 5. 默认值创建 (Default Value Creation)

**类型到默认值映射:**
```gdscript
TYPE_BOOL       → false
TYPE_INT        → 0
TYPE_FLOAT      → 0.0
TYPE_STRING     → ""
TYPE_VECTOR2    → Vector2.ZERO
TYPE_VECTOR3    → Vector3.ZERO
TYPE_COLOR      → Color.WHITE
TYPE_ARRAY      → []
TYPE_DICTIONARY → {}
TYPE_NODE_PATH  → NodePath("")
TYPE_OBJECT     → null
```

**实现模式:**
```gdscript
func create_default_arguments() -> Array:
    var defaults: Array = []
    for i in range(parameter_infos.size()):
        var default_value = get_parameter_default(i)
        if parameter_has_default(i):
            defaults.append(default_value)
        else:
            # 根据类型创建默认值
            var param_type = get_parameter_type(i)
            defaults.append(_create_default_value_for_type(param_type))
    return defaults
```

---

## FunctionInfo 类分析

**文件:** `addons/bricks/utils/function_info.gd`

### 核心职责

1. **数据封装** - 存储 Godot 方法信息字典
2. **便捷访问** - 提供类型安全的方法访问接口
3. **格式化输出** - 生成方法签名和显示名称

### 关键方法

| 方法 | 功能 | 用途 |
|------|------|------|
| `get_method_signature()` | 生成 "method_name(type1, type2) -> return_type" | 调试显示 |
| `get_parameter_property_list()` | 生成 Inspector 属性列表 | 动态 UI |
| `validate_arguments()` | 验证参数数组 | 运行时检查 |
| `create_default_arguments()` | 创建默认参数值 | 初始化 |

### 设计模式

- **不可变对象**: 继承 `RefCounted`，数据初始化后不修改
- **类型安全**: 所有方法都检查边界条件
- **默认值策略**: 优先使用方法签名中的默认值，否则按类型创建

---

## FunctionManager 类分析

**文件:** `addons/bricks/utils/function_manager.gd`

### 核心职责

1. **方法发现** - 反射节点获取可调用方法
2. **方法过滤** - 排除私有和特殊方法
3. **安全调用** - 类型检查后调用方法
4. **类型工具** - 类型名称转换和兼容性检查

### 方法过滤规则

**过滤条件:**
- 空方法名
- 以下划线开头的方法 (`_ready`, `_process` 等)
- 特殊生命周期方法 (`_init`, `_enter_tree`, `_exit_tree` 等)
- 虚方法 (`METHOD_FLAG_VIRTUAL`)
- 非 `METHOD_FLAG_NORMAL` 的方法

**保留条件:**
- 公开的用户定义方法
- 标准公开方法 (非 virtual/static/const)

---

## 可复用的设计模式

### 模式 1: 轻量级缓存

```gdscript
# 只存储必要信息，减少内存占用
var lightweight_method = {
    "name": method.name,
    "args": method.get("args", []),
    "return_val": method.get("return_val", TYPE_NIL),
    "flags": method.get("flags", METHOD_FLAG_NORMAL)
}
```

**优势:**
- 减少 50%+ 内存占用
- 序列化更快
- 离线编辑支持

---

### 模式 2: 属性更新锁

```gdscript
var _is_updating_properties: bool = false

func _update_parameter_defaults():
    if _is_updating_properties:
        return  # 防止递归

    _is_updating_properties = true
    # ... 更新属性
    _is_updating_properties = false
```

**用途:** 防止 `_set()` → `notify_property_list_changed()` → `_get_property_list()` 循环

---

### 模式 3: 分层验证

```
Level 1: 参数数量检查 (快速失败)
Level 2: 参数类型检查 (详细错误)
Level 3: 方法可调用性检查 (运行时安全)
```

---

## JuicyMixer 需要适配的差异

### 差异 1: 上下文系统

**Bricks:**
```gdscript
var target_node: NodePath
var context: ExecutionContext  # 全局执行上下文
```

**JuicyMixer:**
```gdscript
var target_path: NodePath
var context: JuicyContext  # Timeline 上下文，包含参数映射
```

**影响:**
- 需要支持参数映射系统
- 需要在 Timeline 上下文中解析动态参数

---

### 差异 2: 参数映射

**Bricks:** 直接使用值参数
```gdscript
var function_args: Array = [1, "test", Vector2.ZERO]
```

**JuicyMixer:** 支持参数映射
```gdscript
var parameter_mappings: Array[JuicyParameterMapping]
var args: Array = []  # 运行时解析
```

**影响:**
- 参数编辑器需要支持"映射"选项
- UI 需要显示映射标识
- 验证逻辑需要处理映射参数

---

### 差异 3: 时间线集成

**Bricks:** 单次执行指令
```gdscript
func execute(context: ExecutionContext):
    # 执行一次
```

**JuicyMixer:** 在时间线特定时间触发
```gdscript
func trigger_method_with_target(target_node: Node, context: JuicyContext):
    # 支持延迟、重复触发
```

**影响:**
- 方法信息需要在编辑器中缓存
- 参数映射需要在运行时解析
- 支持延迟调用机制

---

## 性能关键点

### 高优先级优化

1. **方法缓存序列化** - 避免每次打开编辑器都反射
2. **节点路径缓存** - 减少重复的 `get_node()` 调用
3. **参数默认值预创建** - 减少运行时分配

### 次要优化

1. **类型名称缓存** - 使用常量字典而非动态 switch
2. **方法签名缓存** - 避免重复获取同一方法签名
3. **属性列表缓存** - 只在必要时刷新

---

## 实现建议

### Phase 1 重点

1. **创建 JuicyMethodInfo**
   - 最小实现：存储方法名、参数列表、返回类型
   - 必须：`get_method_signature()` 和 `create_default_arguments()`

2. **创建 JuicyMethodReflection**
   - 参考 `FunctionManager.get_callable_methods()`
   - 适配 JuicyMixer 的过滤规则

3. **适配 JuicyContext**
   - 在参数验证时考虑参数映射
   - 保持与 Timeline 系统的兼容性

---

## 待研究问题

1. **参数映射在 Inspector 中的表示方式**
   - 选项 A: 特殊值类型 (如 `JuicyMappedParameter` 对象)
   - 选项 B: 字符串前缀 (如 `"@param_name"`)
   - 选项 C: 额外的布尔数组 `is_parameter_mapped[]`

2. **方法缓存失效策略**
   - 选项 A: 监听节点变化信号
   - 选项 B: 手动刷新按钮
   - 选项 C: 定时检查 + 时间戳对比

3. **复杂类型参数的编辑**
   - NodePath: 需要节点选择器
   - Resource: 需要资源选择器
   - Array/Dictionary: 需要内联编辑器

---

## 参考资料

### Godot API

- `Object.get_method_list()` - 获取节点方法列表
- `Object.callv()` - 动态调用方法
- `Object._get_property_list()` - 动态属性生成
- `PROPERTY_HINT_ENUM` - 枚举提示
- `PROPERTY_HINT_NODE_PATH_VALID_TYPES` - 节点路径提示

### 设计模式

- Repository Pattern - 方法信息存储
- Factory Pattern - 默认值创建
- Strategy Pattern - 类型验证策略
