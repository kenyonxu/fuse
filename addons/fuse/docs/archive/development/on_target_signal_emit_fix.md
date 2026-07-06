# OnTargetSignalEmit 编辑器节点选择修复文档

## 问题描述

在 Fuse 可视化编程插件中，`OnTargetSignalEmit` 事件在编辑器中选择目标节点时出现以下问题：

1. **无限循环刷新** - 切换节点后疯狂刷新信号列表，导致编辑器锁死
2. **信号列表消失** - 连续切换节点后，信号列表永久消失
3. **target_node 无法选择** - 信号列表消失后，节点选择器也无法正常使用

## 问题分析

### 问题 1：无限循环

**循环链条：**
```
_editor_refresh_signals()
  → notify_property_list_changed()
    → _get_property_list() 被触发
      → _get_signal_names() 被调用
        → _refresh_signal_cache() 被调用
          → call_deferred("_editor_refresh_signals")  ← 又调用自己！
```

每次 `_editor_refresh_signals` 完成后，调用 `notify_property_list_changed()` 会触发 `_get_property_list()`，然后 `_get_signal_names()` 又会调用 `_refresh_signal_cache()`，再次调度 `_editor_refresh_signals`，形成无限循环。

### 问题 2：信号列表消失

**根本原因：SignalManager 缓存引用问题**

1. 第一次查询 HintBreath 节点：
   - `SignalManager.get_node_signals()` 返回 `_available_signals` 引用（15个信号）
   - SignalManager 缓存了这个数组引用
   - 某处代码调用 `_available_signals.clear()`
   - 由于是引用，SignalManager 的缓存也被清空了！

2. 第二次查询 HintBreath 节点：
   - 命中缓存（cache_key 相同）
   - 但缓存中的数组已被清空
   - 返回 0 个信号 ❌

### 问题 3：target_node 选择器失效

由于无限循环导致编辑器卡死，节点选择器无法响应用户操作。

## 解决方案

### 修复 1：添加刷新锁

在 `OnTargetSignalEmit` 中添加 `_is_refreshing` 锁，防止重复调度：

```gdscript
var _is_refreshing: bool = false

# 在 setter 中
if Engine.is_editor_hint() and not target_node.is_empty() and not _is_refreshing:
    _is_refreshing = true  # 立即设置锁
    call_deferred("_editor_refresh_signals")

# 在 _refresh_signal_cache() 中
if _is_refreshing:
    return  # 防止重复调度

# 在 _editor_refresh_signals() 结尾
_is_refreshing = false  # 释放锁
```

### 修复 2：调整 setter 逻辑

不在 setter 中立即调用 `notify_property_list_changed()`，让刷新完成后再通知：

```gdscript
var target_node: NodePath:
	set(value):
    target_node = value
    _update_resource_name()
    # 不要在这里 notify_property_list_changed()
    # 在 _editor_refresh_signals() 完成后通知
```

### 修复 3：SignalManager 返回副本

修改 `SignalManager.get_node_signals()` 返回数组副本，而不是引用：

```gdscript
# 修改前
return cached  # 返回引用，外部修改会影响缓存

# 修改后
return cached.duplicate()  # 返回副本，保护缓存
return signals.duplicate()  # 返回副本，保护缓存
```

## 修改的文件

### 1. addons/fuse/events/node/on_target_signal_emit.gd

**添加：**
- `_is_refreshing: bool = false` - 刷新锁（第54行）
- `_instance_id: int = 0` - 实例ID用于调试（第56行）

**修改：**
- `target_node` setter - 调整刷新逻辑（第7-24行）
- `_get_signal_names()` - 检查刷新锁并避免主动刷新（第313-321行）
- `_refresh_signal_cache()` - 添加锁检查（第324-351行）
- `_editor_refresh_signals()` - 添加锁释放和日志（第362-389行）
- `_clear_signal_cache()` - 添加锁重置（第492-498行）

### 2. addons/fuse/utils/fuse_node_utils.gd

**新建文件：**
- 递归节点查找工具类
- `find_node_by_relative_path()` - 在编辑器场景中按名称查找节点
- `_recursive_find_node_by_name()` - 递归查找实现

### 3. addons/fuse/utils/signal_manager.gd

**修改：**
- `get_node_signals()` - 返回数组副本，保护缓存（第20、37行）

### 4. addons/fuse/plugin.gd

**添加：**
- 注册 `FuseNodeUtils` 为全局类（第89行）

## 关键技术点

### 1. 编辑器中的节点路径解析

在编辑器中，Resource 可能还未实例化到场景，无法直接使用相对路径。解决方案：
- 递归遍历整个编辑场景树
- 按节点名称匹配（`FuseNodeUtils.find_node_by_relative_path()`）

### 2. Godot 数组引用 vs 副本

**问题：**
```gdscript
var array1 = [1, 2, 3]
var array2 = array1  # 引用，不是副本
array2.clear()  # 会影响 array1！
```

**解决：**
```gdscript
return array.duplicate()  # 返回深拷贝
```

### 3. 延迟调用的线程安全

在编辑器中使用 `call_deferred()` 避免在后台线程访问场景树：
```gdscript
call_deferred("_editor_refresh_signals")  # 延迟到主线程执行
```

## 测试验证

修复后的行为：
1. ✓ 第一次选择节点 → 正常加载信号
2. ✓ 切换到其他节点 → 正常加载信号
3. ✓ 切换回原节点 → 从缓存正确读取信号
4. ✓ 节点没有信号 → 显示"无信号"提示，不会崩溃
5. ✓ 不会出现无限循环
6. ✓ 节点选择器始终可用

## 经验总结

1. **缓存引用问题** - 当缓存可变对象（如数组）时，始终返回副本或只读视图
2. **编辑器异步操作** - 使用 `call_deferred()` 确保主线程安全
3. **状态锁机制** - 在可能产生循环的调用链中添加锁
4. **调试策略** - 添加实例ID和详细日志，快速定位问题

## 相关 Issue

- Fuse 可视化编程插件 - OnTargetSignalEmit 事件
- 编辑器节点选择和信号列表显示
- Godot 4.6 编辑器环境

## 修复日期

2026-02-02

## 修复人员

Claude (AI Assistant)
