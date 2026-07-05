# GDScript Lambda 函数使用规范

## 基本语法

```gdscript
var lambda = func (x: int) -> void:
	print(x)
lambda.call(42)  # 必须用 .call() 调用
```

## 适用场景

### ✅ 推荐使用

| 场景 | 示例 |
|------|------|
| 简单回调（1-3 行代码） | 临时信号连接 |
| 只在一处使用的回调 | 一次性事件处理 |
| 临时信号连接 | 属性变化监听 |

```gdscript
# 示例：简单回调，直接使用 lambda
node.property_list_changed.connect(func(n: Node): clear_cache(n))
node.tree_exiting.connect(func(n: Node): clear_cache(n))
```

### ⚠️ 谨慎使用

| 场景 | 风险 |
|------|------|
| 需要捕获外部变量 | Lambda 按值捕获，不会更新 |

```gdscript
var x = 42
var lambda = func (): print(x)  # 捕获 x=42
x = 100
lambda.call()  # 仍打印 42，不是 100！
```

### ❌ 不推荐使用

| 场景 | 原因 | 建议 |
|------|------|------|
| 复杂逻辑（>5 行代码） | 可读性差 | 提取为独立方法 |
| 需要多处复用的回调 | 代码重复 | 创建独立方法 |
| 需要修改外部捕获变量 | 会触发警告 | 使用独立方法 |

```gdscript
# ❌ 不推荐：lambda 逻辑太复杂
timer.timeout.connect(func():
	var count = _runtime_instance_ref.runtime_state.get("count", 0)
	if count > 10:
		_cleanup()
	else:
		count += 1
		_runtime_instance_ref.set_runtime_state("count", count)
	triggered.emit()
)

# ✅ 推荐：提取为独立方法
timer.timeout.connect(_on_timer_timeout)

func _on_timer_timeout() -> void:
	var count = _runtime_instance_ref.runtime_state.get("count", 0)
	if count > 10:
		_cleanup()
	else:
		count += 1
		_runtime_instance_ref.set_runtime_state("count", count)
	triggered.emit()
```

## 重要限制

### 1. 调用方式

```gdscript
# ❌ 错误 - 不能直接使用 ()
lambda()

# ✅ 正确 - 必须使用 .call()
lambda.call()
```

### 2. 变量捕获

Lambda 按值捕获变量，捕获后不会更新：

```gdscript
var counter = 0
var lambda = func(): print(counter)  # 捕获 counter=0
counter = 10
lambda.call()  # 打印 0，不是 10
```

### 3. 捕获变量重新赋值

重新赋值外部捕获的变量会触发 `CONFUSABLE_CAPTURE_REASSIGNMENT` 警告：

```gdscript
# ⚠️ 会触发警告
var x = 0
var lambda = func():
	x = 10  # CONFUSABLE_CAPTURE_REASSIGNMENT
```

### 4. 引用类型的共享

对于引用类型（数组、字典、对象），内容修改是共享的：

```gdscript
var arr = [1, 2, 3]
var lambda = func(): arr.append(4)  # 修改的是同一个数组
lambda.call()
print(arr)  # [1, 2, 3, 4]
```

## 最佳实践

1. **保持简单** - Lambda 只用于 1-3 行的简单逻辑
2. **避免捕获** - 尽量不要依赖外部变量
3. **提取复杂逻辑** - 超过 5 行就提取为独立方法
4. **明确意图** - 如果回调需要复用，直接创建方法

---

**相关文档:**
- [GDScript 编码风格](../CLAUDE.md#代码规范)
