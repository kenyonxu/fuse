# 剩余组件修复指南

## ✅ 已完成（7/7）

1. ✅ random_number.gd
2. ✅ set_variable.gd
3. ✅ get_scene_path.gd
4. ✅ clamp_value.gd
5. ✅ math_operation.gd
6. ✅ lerp.gd
7. ✅ vector_operation.gd

## ⏳ 待修复（0/7）

### 修复模式（相同）

对于每个组件，需要执行以下4个修改：

#### 1. 添加 save_to_scope 属性

**位置：** 在 `save_to_variable` 属性声明之后添加

```gdscript
## 保存到作用域
@export var save_to_scope: BaseVariable.VariableScope = BaseVariable.VariableScope.LOCAL:
	set(value):
		save_to_scope = value
		_update_resource_name()
		notify_property_list_changed()

## 作用域来源（仅当 save_to_scope == SCOPE 时使用）
var scope_source: ScopeSource = ScopeSource.NEAREST:
	set(value):
		scope_source = value
		_update_resource_name()
		notify_property_list_changed()
```

#### 2. 修改 _get_property_list()

在 `save_to_variable` 属性之后，添加：

```gdscript
properties.append({
		name = "save_to_scope",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Local,Scope,Global",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
})

# 只在 save_to_scope == SCOPE 时显示 ScopeSource 配置
if save_to_scope == BaseVariable.VariableScope.SCOPE:
	properties.append({
		name = "scope_source",
		type = TYPE_INT,
		hint = PROPERTY_HINT_ENUM,
		hint_string = "Nearest,Custom ID,Trigger Scope,Target Node",
		usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	})

	# 根据作用域来源添加额外属性
	if scope_source == ScopeSource.CUSTOM_ID:
		properties.append({
			name = "custom_scope_id",
			type = TYPE_STRING,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
	elif scope_source == ScopeSource.TARGET_NODE:
		properties.append({
			name = "target_node_path",
			type = TYPE_NODE_PATH,
			hint = PROPERTY_HINT_NONE,
			usage = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
		})
```

#### 3. 修改执行逻辑

将原来的保存变量逻辑替换为：

```gdscript
# 根据作用域类型保存变量
match save_to_scope:
	BaseVariable.VariableScope.LOCAL:
		# 保存到 LOCAL 变量
		var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.LOCAL, result)
		if not success:
			_log_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("FUSE_ERROR_SET_LOCAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			finished.emit()
			return

	BaseVariable.VariableScope.SCOPE:
		# 保存到 SCOPE 变量
		if scope_source == ScopeSource.NEAREST:
			VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.SCOPE, result)
		else:
			var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
			var scope_container = VariableScopeUtils.get_scope_container_by_source(
				context, utils_scope_source, custom_scope_id, target_node_path
			)
			if scope_container == null:
				_log_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", {})
				set_error_localized("FUSE_ERROR_SCOPE_CONTAINER_NOT_FOUND", FuseError.ErrorType.RUNTIME_ERROR, {})
				finished.emit()
				return
			var success = scope_container.set_variable(save_to_variable, result)
			if not success:
				_log_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", {"name": save_to_variable})
				set_error_localized("FUSE_ERROR_SET_SCOPE_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
				finished.emit()
				return

	BaseVariable.VariableScope.GLOBAL:
		# 保存到 GLOBAL 变量
		var success = VariableOperations.set_variable(context, save_to_variable, BaseVariable.VariableScope.GLOBAL, result)
		if not success:
			_log_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", {"name": save_to_variable})
			set_error_localized("FUSE_ERROR_SET_GLOBAL_VARIABLE_FAILED", FuseError.ErrorType.RUNTIME_ERROR, {"name": save_to_variable})
			finished.emit()
			return
```

**注意：** 将 `result` 替换为各组件的实际结果变量名：
- math_operation.gd: `result`
- lerp.gd: `result`
- vector_operation.gd: `result`

#### 4. 修改 _get_scope_source_string()

```gdscript
## 获取作用域来源字符串
func _get_scope_source_string() -> String:
	# 根据 save_to_scope 返回不同的作用域字符串
	match save_to_scope:
		BaseVariable.VariableScope.LOCAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_LOCAL_STR")
		BaseVariable.VariableScope.GLOBAL:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_GLOBAL_STR")
		BaseVariable.VariableScope.SCOPE:
			# SCOPE 作用域时，使用 ScopeSource 获取具体域信息
			return VariableScopeUtils.get_scope_source_string(
				scope_source as VariableScopeUtils.ScopeSource,
				custom_scope_id,
				target_node_path
			)
		_:
			return FuseLocalization.translate("FUSE_VARIABLE_SCOPE_UNKNOWN")
```

#### 5. 修改 validate()

在现有的 ScopeSource 验证之前添加条件判断：

```gdscript
# 只在 SCOPE 作用域时验证 ScopeSource 相关参数
if save_to_scope == BaseVariable.VariableScope.SCOPE:
	var utils_scope_source = scope_source as VariableScopeUtils.ScopeSource
	errors.append_array(VariableScopeUtils.validate_scope_source_params(
		utils_scope_source,
		custom_scope_id,
		target_node_path
	))
```

#### 6. 修改 _validate_property()

```gdscript
func _validate_property(property: Dictionary) -> void:
	# 只在 SCOPE 作用域时验证 ScopeSource 相关属性
	if save_to_scope == BaseVariable.VariableScope.SCOPE:
		VariableScopeUtils.validate_scope_source_property(property, scope_source as VariableScopeUtils.ScopeSource)
	else:
		# 非 SCOPE 作用域时隐藏 ScopeSource 相关属性
		if property.name in ["scope_source", "custom_scope_id", "target_node_path"]:
			property.usage = PROPERTY_USAGE_NO_EDITOR
```

---

## 文件位置

### math_operation.gd
**文件：** `addons/fuse/instructions/math/math_operation.gd`
- 保留 `operand_a_scope`, `operand_b_scope`（读取操作数，已正确）
- 添加 `save_to_scope`（写入结果）
- 修改执行逻辑中保存变量的部分（约在第 384-410 行）

### lerp.gd
**文件：** `addons/fuse/instructions/math/lerp.gd`
- 保留 `from_scope`, `to_scope`, `weight_scope`（读取输入，已正确）
- 添加 `save_to_scope`（写入结果）
- 修改执行逻辑中保存变量的部分

### vector_operation.gd
**文件：** `addons/fuse/instructions/math/vector_operation.gd`
- 保留 `vector_a_scope`, `vector_b_scope`（读取向量，已正确）
- 添加 `save_to_scope`（写入结果）
- 修改执行逻辑中保存变量的部分

---

## 快速查找关键位置

使用以下命令快速定位需要修改的位置：

```bash
# 查找"保存到变量"注释
grep -n "# 保存到变量" addons/fuse/instructions/math/math_operation.gd
grep -n "# 保存到变量" addons/fuse/instructions/math/lerp.gd
grep -n "# 保存到变量" addons/fuse/instructions/math/vector_operation.gd

# 查找作用域来源枚举
grep -n "^enum ScopeSource" addons/fuse/instructions/math/math_operation.gd
grep -n "^enum ScopeSource" addons/fuse/instructions/math/lerp.gd
grep -n "^enum ScopeSource" addons/fuse/instructions/math/vector_operation.gd
```

---

## 验证方法

修改完成后，运行语法检查：

```bash
"E:\Godot\Godot_v4.6-stable_mono_win64\Godot_v4.6-stable_mono_win64.exe" --headless --check-only --quit
```

---

**参考完成示例：**
- `addons/fuse/instructions/math/random_number.gd` ✅
- `addons/fuse/instructions/math/clamp_value.gd` ✅
