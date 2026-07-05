# Fuse 反射系统优化计划

**创建日期:** 2026-03-21
**基于:** 与 NodeCanvas 反射系统的对比分析
**状态:** Phase 1 ✅ | Phase 2 ✅ | Phase 3 ✅
**完成日期:** 2026-03-21

---

## 背景与动机

Fuse 的可视化编程系统通过 `FunctionManager`、`PropertyManager`、`SignalManager` 三个工具类提供运行时反射能力，被 `RunTargetNodeFunction`、`SetPropertyValue`、`OnTargetSignalEmit` 等核心组件消费。与 NodeCanvas（C#/Unity）的反射系统对比后，识别出三个可优化的方向：

1. **Callable 缓存** — 避免每次执行都走字符串查找
2. **统一缓存策略** — 消除内存泄漏，统一管理
3. **参数绑定抽象** — 减少每个 Instruction 的参数管理样板代码

详细对比分析见 [nodecanvas-reflection-system.md](../../docs/nodecanvas-reflection-system.md)。

---

## 当前问题清单

### 问题 1：每次调用都走字符串查找

`FunctionManager.call_method_safe()` 每次执行都执行以下路径：

```
call_method_safe() → _get_method_info() 遍历 method_list → 匹配 → callv()
```

对于高频执行场景（循环、批量指令），字符串查找的开销会累积。

### 问题 2：缓存策略分散且不一致

| 缓存 | 位置 | 持久化 | 清理机制 |
|------|------|--------|---------|
| `_method_cache` | `RunTargetNodeFunction` 实例 | `@export_storage` | 手动 |
| `_cached_properties` | `SetPropertyValue` 实例 | 无 | 无 |
| `_editor_available_signals` | `OnTargetSignalEmit` 实例 | 无 | 无 |
| `_property_cache` | `PropertyManager` 静态 | 无 | 无（内存泄漏） |
| `_signal_cache` | `SignalManager` 静态 | 无 | LRU 100 上限 |
| `_cached_method_signatures` | `RunTargetNodeFunction` 实例 | 无 | 无（内存泄漏） |

`PropertyManager._property_cache` 使用 instance_id 做 key，Node 被释放后 key 失效但不会清理。

### 问题 3：参数管理代码大量重复

`RunTargetNodeFunction` 的 1616 行中有约 500 行是参数管理相关：
- `_set` / `_get` 动态参数处理
- 序列化 / 反序列化逻辑
- 参数属性列表生成
- 参数默认值管理
- 参数验证

`SetPropertyValue` 的 587 行中也有约 150 行类似逻辑。每次创建新的反射类指令时，这些代码都需要重新编写或复制。

---

## 优化计划

### Phase 1: Callable 缓存（P1 — 低成本高回报）

**目标:** 缓存 `Callable` 对象，跳过运行时字符串查找。

**修改文件:**

- `addons/fuse/utils/function_manager.gd` — 新增 Callable 缓存
- `addons/fuse/instructions/node_operations/run_target_node_function.gd` — 使用缓存

**具体改动:**

#### 1.1 FunctionManager 新增 Callable 缓存接口

```gdscript
## Callable 缓存（实例级）
static var _callable_cache: Dictionary = {}  # {instance_id:method_name: Callable}

## 获取缓存的 Callable
static func get_cached_callable(node: Node, method_name: String) -> Callable:
    var cache_key = "%s:%s" % [node.get_instance_id(), method_name]
    if _callable_cache.has(cache_key):
        return _callable_cache[cache_key]

    # 验证方法可调用
    if not is_method_callable(node, method_name):
        return Callable()

    var callable = Callable(node, method_name)
    _callable_cache[cache_key] = callable
    return callable

## 清除指定节点的 Callable 缓存
static func clear_callable_cache(node: Node):
    var instance_id = str(node.get_instance_id())
    var keys_to_remove = []
    for key in _callable_cache:
        if key.begins_with(instance_id + ":"):
            keys_to_remove.append(key)
    for key in keys_to_remove:
        _callable_cache.erase(key)
```

#### 1.2 RunTargetNodeFunction 使用缓存的 Callable

```gdscript
# _refresh_method_cache() 中新增 Callable 缓存
var target_instance = _target_node_instance  # 已有
for method_name in _method_cache.keys():
    if target_instance.has_method(method_name):
        _callable_cache[method_name] = Callable(target_instance, method_name)

# _call_target_function() 中优先使用缓存
func _call_target_function(target: Node) -> Dictionary:
    if _callable_cache.has(target_function):
        var result = _callable_cache[target_function].callv(function_args)
        return {"success": true, "result": result}
    # fallback 到原有逻辑
    ...
```

**验证:**
- 现有测试 `test_run_target_node_function.gd` 全部通过
- 确认 Callable 在目标节点释放后不会持有悬空引用（`is_instance_valid` 检查）

**预估工作量:** 小（约 50 行改动）

---

### Phase 2: 统一缓存策略（P2 — 中等复杂度）

**目标:** 建立统一的缓存管理器，解决内存泄漏和缓存不一致问题。

**新增文件:**

- `addons/fuse/utils/reflection_cache.gd` — 统一反射缓存管理器

**修改文件:**

- `addons/fuse/utils/property_manager.gd` — 迁移缓存逻辑
- `addons/fuse/utils/signal_manager.gd` — 迁移缓存逻辑
- `addons/fuse/utils/function_manager.gd` — 迁移 Callable 缓存
- `addons/fuse/plugin.gd` — 注册缓存清理钩子

#### 2.1 ReflectionCache 统一管理器设计

```gdscript
class_name ReflectionCache
extends RefCounted

## 统一缓存入口
## 管理方法、属性、信号的缓存，提供自动清理和统计

enum CacheType {
    METHOD,      # 方法列表和 Callable
    PROPERTY,    # 属性列表
    SIGNAL,      # 信号列表
    SIGNATURE    # 方法签名
}

# 缓存存储
var _caches: Dictionary = {
    CacheType.METHOD: {},      # {instance_id: {method_name: info}}
    CacheType.PROPERTY: {},    # {instance_id: [PropertyInfo]}
    CacheType.SIGNAL: {},      # {instance_id: [SignalInfo]}
    CacheType.SIGNATURE: {},   # {instance_id:method_name: signature}
}

# LRU 配置
var _max_entries: int = 200
var _access_order: Dictionary = {
    CacheType.METHOD: [],
    CacheType.PROPERTY: [],
    CacheType.SIGNAL: [],
}

## 获取缓存
func get(cache_type: CacheType, node: Node, key: String = "") -> Variant:
    var instance_key = str(node.get_instance_id())
    var cache = _caches[cache_type]
    if not cache.has(instance_key):
        return null
    if key.is_empty():
        return cache[instance_key]
    return cache[instance_key].get(key, null)

## 设置缓存
func set(cache_type: CacheType, node: Node, key: String, value: Variant):
    var instance_key = str(node.get_instance_id())
    if not _caches[cache_type].has(instance_key):
        _evict_if_needed(cache_type)
        _caches[cache_type][instance_key] = {}
    _caches[cache_type][instance_key][key] = value

## 清理指定节点的所有缓存
func clear_node(node: Node):
    var instance_key = str(node.get_instance_id())
    for cache_type in _caches:
        _caches[cache_type].erase(instance_key)

## 清理所有缓存
func clear_all():
    for cache_type in _caches:
        _caches[cache_type].clear()

## 获取缓存统计
func get_stats() -> Dictionary:
    return {
        "method_entries": _caches[CacheType.METHOD].size(),
        "property_entries": _caches[CacheType.PROPERTY].size(),
        "signal_entries": _caches[CacheType.SIGNAL].size(),
        "signature_entries": _caches[CacheType.SIGNATURE].size(),
        "max_entries": _max_entries
    }
```

#### 2.2 自动清理机制

在 `plugin.gd` 的 `_enter_tree()` 中注册场景树监听：

```gdscript
func _enter_tree():
    # 监听节点删除，自动清理缓存
    get_tree().node_removed.connect(_on_node_removed)

func _on_node_removed(node: Node):
    ReflectionCache.clear_node(node)
```

#### 2.3 迁移 PropertyManager 缓存

```gdscript
# 将 _property_cache 迁移到 ReflectionCache
static func get_all_properties(node: Node) -> Array[PropertyInfo]:
    var cached = ReflectionCache.get(ReflectionCache.CacheType.PROPERTY, node)
    if cached != null:
        return cached as Array[PropertyInfo]

    # 原有逻辑...
    var properties = ...

    ReflectionCache.set(ReflectionCache.CacheType.PROPERTY, node, "", properties)
    return properties
```

#### 2.4 迁移 SignalManager 缓存

SignalManager 已有 LRU 实现，迁移时保留其 LRU 逻辑到 ReflectionCache 中，移除 SignalManager 自身的缓存代码。

**验证:**
- 现有测试全部通过：`test_property_system_common_classes.gd`、`test_signal_system.gd`、`test_signal_cache.gd`
- 内存泄漏测试：创建并释放 1000 个 Node，确认缓存不增长
- `ReflectionCache.get_stats()` 返回正确统计

**预估工作量:** 中（新文件约 150 行，迁移改动约 200 行）

---

### Phase 3: 参数绑定抽象（P3 — 高回报高复杂度） ✅

**完成日期:** 2026-03-21

**目标:** 抽取参数声明、序列化、Inspector 暴露、变量绑定的通用逻辑，减少 Instruction 的样板代码。

**实施结果:**

| 子项 | 状态 | 说明 |
|------|------|------|
| 3.1 变量绑定字段 | ✅ | BoundParameter 新增 `use_variable`、`variable_name`、`variable_scope`、`scope_source`、`custom_scope_id`、`scope_target_path` |
| 3.2 序列化/反序列化 | ✅ | `to_dict()`/`from_dict()` 完整支持变量绑定字段，兼容旧格式 |
| 3.3 Inspector 属性 | ✅ | `get_inspector_properties(include_variable_bindings)` 控制变量绑定属性暴露 |
| 3.4 handle_set/handle_get | ✅ | 自动处理 `param_N_use_variable`、`param_N_variable_name`、`param_N_variable_scope` |
| 3.5 运行时变量解析 | ✅ | `get_runtime_args(context)` 通过 `VariableOperations.get_variable()` 解析变量值 |
| 3.6 向后兼容 | ✅ | `context` 参数可选，现有调用无需修改 |

**新增文件:**

- `addons/fuse/utils/parameter_binding.gd` — 参数绑定框架（含 `BoundParameter` + `ParameterBindingManager` + `ScopeSource` 枚举）

**修改文件:**

- `addons/fuse/instructions/node_operations/run_target_node_function.gd` — 已集成 `ParameterBindingManager`
- `addons/fuse/instructions/node_operations/set_property_value.gd` — 无需迁移（仅管理单个属性值，非参数列表）

**未实施（计划调整）:**

- `parameter_binding_mixin.gd` — GDScript 无 mixin 支持，组合模式已足够

**新增文件:**

- `addons/fuse/utils/parameter_binding.gd` — 参数绑定框架
- `addons/fuse/utils/parameter_binding_mixin.gd` — 可混入的参数管理接口（GDScript 无 mixin，用组合模式）

**修改文件:**

- `addons/fuse/instructions/node_operations/run_target_node_function.gd` — 使用参数绑定框架
- `addons/fuse/instructions/node_operations/set_property_value.gd` — 使用参数绑定框架

#### 3.1 ParameterBinding 框架设计（已实施）

> 设计草案代码块已移除。实际实现见 `addons/fuse/utils/parameter_binding.gd`。

**核心类：**
- `BoundParameter` — 单参数绑定（值 + 变量绑定 + 序列化）
- `ParameterBindingManager` — 参数列表管理（Inspector 属性生成、_set/_get、运行时参数解析）
- `ScopeSource` 枚举 — 作用域来源（Target/Custom/Path）

**关键设计决策：**
- `get_runtime_args(context)` 的 `context` 参数可选，向后兼容现有调用
- `handle_set` 自动扩展 `_binding_manager`，解决资源加载顺序问题
- `from_dict()` 兼容旧序列化格式（`default` → `default_value`，增强格式 name 提取）

---

## 实施顺序与依赖关系

```
Phase 1: Callable 缓存
    │
    ├── 独立，可立即开始
    │
    ▼
Phase 2: 统一缓存策略
    │
    ├── 依赖 Phase 1（将 Callable 缓存纳入统一管理）
    │
    ▼
Phase 3: 参数绑定抽象
    │
    ├── 独立于 Phase 2，但建议在统一缓存完成后做
    │   （可复用 ReflectionCache 做参数元数据缓存）
    │
    ▼
完成
```

## 风险评估

| 风险 | 级别 | 缓解措施 |
|------|------|---------|
| Callable 悬空引用 | 中 | 缓存中存储 instance_id，使用前 `is_instance_valid` 检查 |
| 缓存清理时机不当 | 低 | 通过 `node_removed` 信号触发，不依赖手动清理 |
| 参数绑定框架过度设计 | 中 | 仅在 Phase 3 实施后评估，保留现有代码作为 fallback |
| 迁移过程中破坏现有功能 | 中 | 每个 Phase 独立验证，现有测试作为回归基准 |
| GDScript 性能瓶颈 | 低 | 反射操作本身不是性能热点，缓存主要减少重复计算 |

## 成功指标

1. **代码量减少** — `RunTargetNodeFunction` 从 1616 行降至约 1000 行以下 ✅（参数管理委托给 ParameterBindingManager）
2. **零内存泄漏** — 长时间运行后 `ReflectionCache.get_stats()` 显示稳定 ✅（LRU 淘汰 + node_removed 自动清理）
3. **调用性能** — 缓存命中时方法调用跳过字符串查找 ✅（Callable 缓存）
4. **开发效率** — 新建反射类指令的参数管理代码减少 70%+ ✅（ParameterBindingManager 组合即可）
5. **向后兼容** — 所有现有测试通过，已有场景无需修改 ✅（兼容旧序列化格式，context 参数可选）

## 不做的事

- 不照搬 NodeCanvas 的 `ReflectedWrapper` 委托编译模式（GDScript 不支持）
- 不引入全局类型扫描（Godot 的 `ClassDB` 已足够）
- 不修改 Instruction 基类的公共接口
- 不改变序列化格式（`@export_storage` 保持不变）
