# Fuse 组件名对照表

> 自动扫描 `addons/fuse/{instructions,events,conditions}/` 源码生成。
> 中文名/英文名通过 `addons/fuse/localization/translations.csv` 的翻译键查得。
> 重新生成：运行 `python .tmp_scan_components.py`（临时脚本，用完可删）。

## 概览

| 类型 | 数量 |
|------|------|
| 指令 (Instruction) | 174 |
| 事件 (Event) | 69 |
| 条件 (Condition) | 55 |
| **合计** | **298** |

- 缺失 `name_key` 的组件：**1**（另有 1 个抽象基类，本就无独立显示名，已在表中标注）
- 有 `name_key` 但翻译表中查不到的：**0**

## 指令 (Instruction)

### UI 控制

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `AddRemoveUIChild` | `FUSE_INSTRUCTION_ADD_REMOVE_UI_CHILD_NAME` | 添加/移除 UI 子节点 | Add/Remove UI Child | [instructions/ui/add_remove_ui_child.gd](../../instructions/ui/add_remove_ui_child.gd) |
| `SetUIColor` | `FUSE_INSTRUCTION_SET_UI_COLOR_NAME` | 设置 UI 颜色 | Set UI Color | [instructions/ui/set_ui_color.gd](../../instructions/ui/set_ui_color.gd) |
| `SetUIProgress` | `FUSE_INSTRUCTION_SET_UI_PROGRESS_NAME` | 设置 UI 进度 | Set UI Progress | [instructions/ui/set_ui_progress.gd](../../instructions/ui/set_ui_progress.gd) |
| `SetUIText` | `FUSE_INSTRUCTION_SET_UI_TEXT_NAME` | 设置 UI 文本 | Set UI Text | [instructions/ui/set_ui_text.gd](../../instructions/ui/set_ui_text.gd) |
| `SetUITexture` | `FUSE_INSTRUCTION_SET_UI_TEXTURE_NAME` | 设置 UI 纹理 | Set UI Texture | [instructions/ui/set_ui_texture.gd](../../instructions/ui/set_ui_texture.gd) |
| `ShowHideUI` | `FUSE_INSTRUCTION_SHOW_HIDE_UI_NAME` | 显示/隐藏 UI | Show/Hide UI | [instructions/ui/show_hide_ui.gd](../../instructions/ui/show_hide_ui.gd) |

### tween

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `BaseTweenInstruction` | — | *(基类，无独立显示名)* | — | [instructions/tween/base_tween_instruction.gd](../../instructions/tween/base_tween_instruction.gd) |

### 事件

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `SendEvent` | `FUSE_INSTRUCTION_SEND_EVENT_NAME` | 发送事件 | Send Event | [instructions/event/send_event.gd](../../instructions/event/send_event.gd) |

### 作用域变量

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `GetScopeVariable` | `FUSE_INSTRUCTION_GET_SCOPE_VARIABLE_NAME` | 获取作用域变量 | Get Scope Variable | [instructions/variables/get_scope_variable.gd](../../instructions/variables/get_scope_variable.gd) |
| `SetScopeVariable` | `FUSE_INSTRUCTION_SET_SCOPE_VARIABLE_NAME` | 设置作用域变量 | Set Scope Variable | [instructions/variables/set_scope_variable.gd](../../instructions/variables/set_scope_variable.gd) |

### 动画

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `BlendAnimation` | `FUSE_INSTRUCTION_BLEND_ANIMATION_NAME` | 混合动画 | Blend Animation | [instructions/animation/blend_animation.gd](../../instructions/animation/blend_animation.gd) |
| `PlayAnimation` | `FUSE_INSTRUCTION_PLAY_ANIMATION_NAME` | 播放动画 | Play Animation | [instructions/animation/play_animation.gd](../../instructions/animation/play_animation.gd) |
| `SetAnimationBlendPosition` | `FUSE_INSTRUCTION_SET_ANIM_BLEND_POS_NAME` | 设置动画混合位置 | Set Animation Blend Position | [instructions/animation/set_animation_blend_position.gd](../../instructions/animation/set_animation_blend_position.gd) |
| `SetAnimationSpeed` | `FUSE_INSTRUCTION_SET_ANIMATION_SPEED_NAME` | 设置动画速度 | Set Animation Speed | [instructions/animation/set_animation_speed.gd](../../instructions/animation/set_animation_speed.gd) |
| `SetAnimationTreeParameter` | `FUSE_INSTRUCTION_SET_ANIM_TREE_PARAM_NAME` | 设置动画树参数 | Set AnimTree Parameter | [instructions/animation/set_animation_tree_parameter.gd](../../instructions/animation/set_animation_tree_parameter.gd) |
| `SetSpriteFlip` | `FUSE_INSTRUCTION_SET_SPRITE_FLIP_NAME` | 设置精灵翻转 | Set Sprite Flip | [instructions/animation/set_sprite_flip.gd](../../instructions/animation/set_sprite_flip.gd) |
| `SetSpriteFrame` | `FUSE_INSTRUCTION_SET_SPRITE_FRAME_NAME` | 设置精灵帧 | Set Sprite Frame | [instructions/animation/set_sprite_frame.gd](../../instructions/animation/set_sprite_frame.gd) |
| `StopAnimation` | `FUSE_INSTRUCTION_STOP_ANIMATION_NAME` | 停止动画 | Stop Animation | [instructions/animation/stop_animation.gd](../../instructions/animation/stop_animation.gd) |

### 变换操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `GetPosition` | `FUSE_INSTRUCTION_GET_POSITION_NAME` | 获取位置 | Get Position | [instructions/transform/get_position.gd](../../instructions/transform/get_position.gd) |
| `LookAt` | `FUSE_INSTRUCTION_LOOK_AT_NAME` | 朝向 | Look At | [instructions/transform/look_at.gd](../../instructions/transform/look_at.gd) |
| `MoveBy` | `FUSE_INSTRUCTION_MOVE_BY_NAME` | 相对移动 | Move By | [instructions/transform/move_by.gd](../../instructions/transform/move_by.gd) |
| `RotateBy` | `FUSE_INSTRUCTION_ROTATE_BY_NAME` | 相对旋转 | Rotate By | [instructions/transform/rotate_by.gd](../../instructions/transform/rotate_by.gd) |
| `SetPosition` | `FUSE_INSTRUCTION_SET_POSITION_NAME` | 设置位置 | Set Position | [instructions/transform/set_position.gd](../../instructions/transform/set_position.gd) |
| `SetRotation` | `FUSE_INSTRUCTION_SET_ROTATION_NAME` | 设置旋转 | Set Rotation | [instructions/transform/set_rotation.gd](../../instructions/transform/set_rotation.gd) |
| `SetScale` | `FUSE_INSTRUCTION_SET_SCALE_NAME` | 设置缩放 | Set Scale | [instructions/transform/set_scale.gd](../../instructions/transform/set_scale.gd) |

### 变量

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `AddVariable` | `FUSE_INSTRUCTION_ADD_VARIABLE_NAME` | 增加变量 | Add Variable | [instructions/variables/add_variable.gd](../../instructions/variables/add_variable.gd) |
| `CreateVariable` | `FUSE_INSTRUCTION_CREATE_VARIABLE_NAME` | 创建变量 | Create Variable | [instructions/variables/create_variable.gd](../../instructions/variables/create_variable.gd) |
| `LoadGlobalVariables` | `FUSE_INSTRUCTION_LOAD_GLOBAL_VARIABLES_NAME` | 加载全局变量 | Load Global Variables | [instructions/variables/load_global_variables.gd](../../instructions/variables/load_global_variables.gd) |
| `SaveGlobalVariables` | `FUSE_INSTRUCTION_SAVE_GLOBAL_VARIABLES_NAME` | 保存全局变量 | Save Global Variables | [instructions/variables/save_global_variables.gd](../../instructions/variables/save_global_variables.gd) |
| `SetIntVariable` | `FUSE_INSTRUCTION_SET_INT_VARIABLE_NAME` | 设置整数变量 | Set Int Variable | [instructions/variables/set_int_variable.gd](../../instructions/variables/set_int_variable.gd) |
| `SetVariable` | `FUSE_INSTRUCTION_SET_VARIABLE_NAME` | 设置变量 | Set Variable | [instructions/variables/set_variable.gd](../../instructions/variables/set_variable.gd) |
| `SwapVariables` | `FUSE_INSTRUCTION_SWAP_VARIABLES_NAME` | 交换变量 | Swap Variables | [instructions/variables/swap_variables.gd](../../instructions/variables/swap_variables.gd) |
| `ToggleVariable` | `FUSE_INSTRUCTION_TOGGLE_VARIABLE_NAME` | 切换变量 | Toggle Variable | [instructions/variables/toggle_variable.gd](../../instructions/variables/toggle_variable.gd) |

### 场景管理

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `AddSceneAsChild` | `FUSE_INSTRUCTION_ADD_SCENE_AS_CHILD_NAME` | 添加场景为子节点 | Add Scene as Child | [instructions/scene/add_scene_as_child.gd](../../instructions/scene/add_scene_as_child.gd) |
| `ChangeScene` | `FUSE_INSTRUCTION_CHANGE_SCENE_NAME` | 切换场景 | Change Scene | [instructions/scene_management/change_scene.gd](../../instructions/scene_management/change_scene.gd) |
| `GetScenePath` | `FUSE_INSTRUCTION_GET_SCENE_PATH_NAME` | 获取场景路径 | Get Scene Path | [instructions/scene/get_scene_path.gd](../../instructions/scene/get_scene_path.gd) |
| `LoadSceneBackground` | `FUSE_INSTRUCTION_LOAD_SCENE_BACKGROUND_NAME` | 后台加载场景 | Load Scene Background | [instructions/scene/load_scene_background.gd](../../instructions/scene/load_scene_background.gd) |
| `PreloadSceneInstruction` | `FUSE_INSTRUCTION_PRELOAD_SCENE_NAME` | 预加载场景 | Preload Scene | [instructions/scene/preload_scene_instruction.gd](../../instructions/scene/preload_scene_instruction.gd) |
| `ReloadScene` | `FUSE_INSTRUCTION_RELOAD_SCENE_NAME` | 重载场景 | Reload Scene | [instructions/scene/reload_scene.gd](../../instructions/scene/reload_scene.gd) |

### 字典

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `DictClear` | `FUSE_INSTRUCTION_DICT_CLEAR_NAME` | 清空字典 | Clear Dictionary | [instructions/dictionaries/dict_clear.gd](../../instructions/dictionaries/dict_clear.gd) |
| `DictDuplicate` | `FUSE_INSTRUCTION_DICT_DUPLICATE_NAME` | 复制字典 | Duplicate Dictionary | [instructions/dictionaries/dict_duplicate.gd](../../instructions/dictionaries/dict_duplicate.gd) |
| `DictFromJson` | `FUSE_INSTRUCTION_DICT_FROM_JSON_NAME` | JSON 转字典 | Dict From JSON | [instructions/dictionaries/dict_from_json.gd](../../instructions/dictionaries/dict_from_json.gd) |
| `DictGetByPath` | `FUSE_INSTRUCTION_DICT_GET_BY_PATH_NAME` | 获取字典路径值 | Get Dict Value By Path | [instructions/dictionaries/dict_get_by_path.gd](../../instructions/dictionaries/dict_get_by_path.gd) |
| `DictGetKeys` | `FUSE_INSTRUCTION_DICT_GET_KEYS_NAME` | 获取字典键列表 | Get Dict Keys | [instructions/dictionaries/dict_get_keys.gd](../../instructions/dictionaries/dict_get_keys.gd) |
| `DictGetValue` | `FUSE_INSTRUCTION_DICT_GET_VALUE_NAME` | 获取字典值 | Get Dict Value | [instructions/dictionaries/dict_get_value.gd](../../instructions/dictionaries/dict_get_value.gd) |
| `DictGetValues` | `FUSE_INSTRUCTION_DICT_GET_VALUES_NAME` | 获取字典所有值 | Get Dict Values | [instructions/dictionaries/dict_get_values.gd](../../instructions/dictionaries/dict_get_values.gd) |
| `DictMathOp` | `FUSE_INSTRUCTION_DICT_MATH_OP_NAME` | 字典数学运算 | Dict Math Operation | [instructions/dictionaries/dict_math_op.gd](../../instructions/dictionaries/dict_math_op.gd) |
| `DictMerge` | `FUSE_INSTRUCTION_DICT_MERGE_NAME` | 合并字典 | Merge Dictionaries | [instructions/dictionaries/dict_merge.gd](../../instructions/dictionaries/dict_merge.gd) |
| `DictModifyNumber` | `FUSE_INSTRUCTION_DICT_MODIFY_NUMBER_NAME` | 修改字典数值 | Modify Dict Number | [instructions/dictionaries/dict_modify_number.gd](../../instructions/dictionaries/dict_modify_number.gd) |
| `DictRemoveKey` | `FUSE_INSTRUCTION_DICT_REMOVE_KEY_NAME` | 移除字典键 | Remove Dict Key | [instructions/dictionaries/dict_remove_key.gd](../../instructions/dictionaries/dict_remove_key.gd) |
| `DictSetByPath` | `FUSE_INSTRUCTION_DICT_SET_BY_PATH_NAME` | 设置字典路径值 | Set Dict Value By Path | [instructions/dictionaries/dict_set_by_path.gd](../../instructions/dictionaries/dict_set_by_path.gd) |
| `DictSetKeyValue` | `FUSE_INSTRUCTION_DICT_SET_NAME` | 设置字典键值 | Set Dict key value | [instructions/dictionaries/dict_set_key_value.gd](../../instructions/dictionaries/dict_set_key_value.gd) |
| `DictSize` | `FUSE_INSTRUCTION_DICT_SIZE_NAME` | 获取字典大小 | Get Dict Size | [instructions/dictionaries/dict_size.gd](../../instructions/dictionaries/dict_size.gd) |
| `DictToggleBoolean` | `FUSE_INSTRUCTION_DICT_TOGGLE_BOOLEAN_NAME` | 切换字典布尔值 | Toggle dict boolean value | [instructions/dictionaries/dict_toggle_boolean.gd](../../instructions/dictionaries/dict_toggle_boolean.gd) |
| `DictToJson` | `FUSE_INSTRUCTION_DICT_TO_JSON_NAME` | 字典转 JSON | Dict To JSON | [instructions/dictionaries/dict_to_json.gd](../../instructions/dictionaries/dict_to_json.gd) |

### 字符串

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `StringContainsInstruction` | `FUSE_INSTRUCTION_STRING_CONTAINS_NAME` | 字符串包含 | String Contains | [instructions/string/string_contains.gd](../../instructions/string/string_contains.gd) |
| `StringFormat` | `FUSE_INSTRUCTION_STRING_FORMAT_NAME` | 字符串格式化 | String Format | [instructions/string/string_format.gd](../../instructions/string/string_format.gd) |
| `StringJoin` | `FUSE_INSTRUCTION_STRING_JOIN_NAME` | 合并字符串 | String Join | [instructions/string/string_join.gd](../../instructions/string/string_join.gd) |
| `StringLength` | `FUSE_INSTRUCTION_STRING_LENGTH_NAME` | 字符串长度 | String Length | [instructions/string/string_length.gd](../../instructions/string/string_length.gd) |
| `StringReplace` | `FUSE_INSTRUCTION_STRING_REPLACE_NAME` | 替换字符串 | String Replace | [instructions/string/string_replace.gd](../../instructions/string/string_replace.gd) |
| `StringSplit` | `FUSE_INSTRUCTION_STRING_SPLIT_NAME` | 分割字符串 | String Split | [instructions/string/string_split.gd](../../instructions/string/string_split.gd) |

### 导航

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `NavigateToPosition` | `FUSE_INSTRUCTION_NAVIGATE_TO_POS_NAME` | 导航到位置 | Navigate to Position | [instructions/navigation/navigate_to_position.gd](../../instructions/navigation/navigate_to_position.gd) |

### 摄像机

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CameraFadeIn` | `FUSE_INSTRUCTION_CAMERA_FADE_IN_NAME` | 摄像机淡入 | Camera Fade In | [instructions/camera/camera_fade_in.gd](../../instructions/camera/camera_fade_in.gd) |
| `CameraFadeOut` | `FUSE_INSTRUCTION_CAMERA_FADE_OUT_NAME` | 摄像机淡出 | Camera Fade Out | [instructions/camera/camera_fade_out.gd](../../instructions/camera/camera_fade_out.gd) |
| `CameraFollow` | `FUSE_INSTRUCTION_CAMERA_FOLLOW_NAME` | 相机跟随 | Camera Follow | [instructions/camera/camera_follow.gd](../../instructions/camera/camera_follow.gd) |
| `CameraShake` | `FUSE_INSTRUCTION_CAMERA_SHAKE_NAME` | 相机抖动 | Camera Shake | [instructions/camera/camera_shake.gd](../../instructions/camera/camera_shake.gd) |
| `SetCameraLimit` | `FUSE_INSTRUCTION_SET_CAMERA_LIMIT_NAME` | 设置相机边界 | Set Camera Limit | [instructions/camera/set_camera_limit.gd](../../instructions/camera/set_camera_limit.gd) |
| `SetCameraZoom` | `FUSE_INSTRUCTION_SET_CAMERA_ZOOM_NAME` | 设置相机缩放 | Set Camera Zoom | [instructions/camera/set_camera_zoom.gd](../../instructions/camera/set_camera_zoom.gd) |

### 数学

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `ClampValue` | `FUSE_INSTRUCTION_CLAMP_VALUE_NAME` | 限制数值 | Clamp Value | [instructions/math/clamp_value.gd](../../instructions/math/clamp_value.gd) |
| `GetRandomPointInRange` | `FUSE_INSTRUCTION_GET_RANDOM_POINT_IN_RANGE_NAME` | 获取范围内随机点 | Get Random Point In Range | [instructions/math/get_random_point_in_range.gd](../../instructions/math/get_random_point_in_range.gd) |
| `Lerp` | `FUSE_INSTRUCTION_LERP_NAME` | 线性插值 | Lerp | [instructions/math/lerp.gd](../../instructions/math/lerp.gd) |
| `MathExpression` | `FUSE_INSTRUCTION_MATH_EXPRESSION_NAME` | 数学表达式 | Math Expression | [instructions/math/math_expression.gd](../../instructions/math/math_expression.gd) |
| `MathOperation` | `FUSE_INSTRUCTION_MATH_OPERATION_NAME` | 数学运算 | Math Operation | [instructions/math/math_operation.gd](../../instructions/math/math_operation.gd) |
| `RandomNumber` | `FUSE_INSTRUCTION_RANDOM_NUMBER_NAME` | 随机数 | Random Number | [instructions/math/random_number.gd](../../instructions/math/random_number.gd) |
| `StringExpression` | `FUSE_INSTRUCTION_STRING_EXPRESSION_NAME` | 字符串表达式 | String Expression | [instructions/math/string_expression.gd](../../instructions/math/string_expression.gd) |
| `VectorOperation` | `FUSE_INSTRUCTION_VECTOR_OPERATION_NAME` | 向量运算 | Vector Operation | [instructions/math/vector_operation.gd](../../instructions/math/vector_operation.gd) |

### 数组操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `ArrayAdd` | `FUSE_INSTRUCTION_ARRAY_ADD_NAME` | 添加数组元素 | Array Add | [instructions/arrays/array_add.gd](../../instructions/arrays/array_add.gd) |
| `ArrayClear` | `FUSE_INSTRUCTION_ARRAY_CLEAR_NAME` | 清空数组 | Array Clear | [instructions/arrays/array_clear.gd](../../instructions/arrays/array_clear.gd) |
| `ArrayContains` | `FUSE_INSTRUCTION_ARRAY_CONTAINS_NAME` | 检查数组包含 | Array Contains | [instructions/arrays/array_contains.gd](../../instructions/arrays/array_contains.gd) |
| `ArrayFind` | `FUSE_INSTRUCTION_ARRAY_FIND_NAME` | 查找数组元素 | Array Find | [instructions/arrays/array_find.gd](../../instructions/arrays/array_find.gd) |
| `ArrayGet` | `FUSE_INSTRUCTION_ARRAY_GET_NAME` | 获取数组元素 | Array Get | [instructions/arrays/array_get.gd](../../instructions/arrays/array_get.gd) |
| `ArrayInsert` | `FUSE_INSTRUCTION_ARRAY_INSERT_NAME` | 数组插入 | Array Insert | [instructions/arrays/array_insert.gd](../../instructions/arrays/array_insert.gd) |
| `ArrayNumericGetLargest` | `FUSE_INSTRUCTION_ARRAY_NUMERIC_LARGEST_NAME` | 获取最大值 | Get Largest | [instructions/arrays/array_numeric_get_largest.gd](../../instructions/arrays/array_numeric_get_largest.gd) |
| `ArrayNumericGetSmallest` | `FUSE_INSTRUCTION_ARRAY_NUMERIC_SMALLEST_NAME` | 获取最小值 | Get Smallest | [instructions/arrays/array_numeric_get_smallest.gd](../../instructions/arrays/array_numeric_get_smallest.gd) |
| `ArrayNumericSort` | `FUSE_INSTRUCTION_ARRAY_NUMERIC_SORT_NAME` | 数值排序 | Numeric Sort | [instructions/arrays/array_numeric_sort.gd](../../instructions/arrays/array_numeric_sort.gd) |
| `ArrayRandom` | `FUSE_INSTRUCTION_ARRAY_RANDOM_NAME` | 获取随机元素 | Array Random | [instructions/arrays/array_random.gd](../../instructions/arrays/array_random.gd) |
| `ArrayRemove` | `FUSE_INSTRUCTION_ARRAY_REMOVE_NAME` | 移除数组元素 | Array Remove | [instructions/arrays/array_remove.gd](../../instructions/arrays/array_remove.gd) |
| `ArrayReverse` | `FUSE_INSTRUCTION_ARRAY_REVERSE_NAME` | 反转数组 | Array Reverse | [instructions/arrays/array_reverse.gd](../../instructions/arrays/array_reverse.gd) |
| `ArraySet` | `FUSE_INSTRUCTION_ARRAY_SET_NAME` | 设置数组元素 | Array Set | [instructions/arrays/array_set.gd](../../instructions/arrays/array_set.gd) |
| `ArrayShuffle` | `FUSE_INSTRUCTION_ARRAY_SHUFFLE_NAME` | 打乱数组 | Array Shuffle | [instructions/arrays/array_shuffle.gd](../../instructions/arrays/array_shuffle.gd) |
| `ArraySize` | `FUSE_INSTRUCTION_ARRAY_SIZE_NAME` | 数组大小 | Array Size | [instructions/arrays/array_size.gd](../../instructions/arrays/array_size.gd) |
| `ArrayVectorGetClosest` | `FUSE_INSTRUCTION_ARRAY_VECTOR_CLOSEST_NAME` | 获取最近向量 | Get Closest Vector | [instructions/arrays/array_vector_get_closest.gd](../../instructions/arrays/array_vector_get_closest.gd) |
| `ArrayVectorGetFurthest` | `FUSE_INSTRUCTION_ARRAY_VECTOR_FURTHEST_NAME` | 获取最远向量 | Get Furthest Vector | [instructions/arrays/array_vector_get_furthest.gd](../../instructions/arrays/array_vector_get_furthest.gd) |
| `ArrayVectorSort` | `FUSE_INSTRUCTION_ARRAY_VECTOR_SORT_NAME` | 向量排序 | Vector Sort | [instructions/arrays/array_vector_sort.gd](../../instructions/arrays/array_vector_sort.gd) |

### 时间

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `GetDeltaTime` | `FUSE_INSTRUCTION_GET_DELTA_TIME_NAME` | 获取 Delta 时间 | Get Delta Time | [instructions/time/get_delta_time.gd](../../instructions/time/get_delta_time.gd) |
| `SetTimeScale` | `FUSE_INSTRUCTION_SET_TIME_SCALE_NAME` | 设置时间缩放 | Set Time Scale | [instructions/time/set_time_scale.gd](../../instructions/time/set_time_scale.gd) |

### 流程控制

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `BreakLoop` | `FUSE_INSTRUCTION_BREAK_LOOP_NAME` | 跳出循环 | Break Loop | [instructions/flow_control/break_loop.gd](../../instructions/flow_control/break_loop.gd) |
| `ContinueLoop` | `FUSE_INSTRUCTION_CONTINUE_LOOP_NAME` | 继续循环 | Continue Loop | [instructions/flow_control/continue_loop.gd](../../instructions/flow_control/continue_loop.gd) |
| `Count` | `FUSE_INSTRUCTION_COUNT_NAME` | 计数 | Count | [instructions/flow_control/count.gd](../../instructions/flow_control/count.gd) |
| `ForEach` | `FUSE_INSTRUCTION_FOR_EACH_NAME` | For Each | For Each | [instructions/flow_control/for_each.gd](../../instructions/flow_control/for_each.gd) |
| `ForLoop` | `FUSE_INSTRUCTION_FOR_LOOP_NAME` | For 循环 | For Loop | [instructions/flow_control/for_loop.gd](../../instructions/flow_control/for_loop.gd) |
| `IfElse` | `FUSE_INSTRUCTION_IF_ELSE_NAME` | 如果/否则 | If/Else | [instructions/flow_control/if_else.gd](../../instructions/flow_control/if_else.gd) |
| `IfThen` | `FUSE_INSTRUCTION_IF_THEN_NAME` | 如果/那么 | If/Then | [instructions/flow_control/if_then.gd](../../instructions/flow_control/if_then.gd) |
| `PauseGame` | `FUSE_INSTRUCTION_PAUSE_GAME_NAME` | 暂停游戏 | Pause Game | [instructions/flow_control/pause_game.gd](../../instructions/flow_control/pause_game.gd) |
| `ResumeGame` | `FUSE_INSTRUCTION_RESUME_GAME_NAME` | 恢复游戏 | Resume Game | [instructions/flow_control/resume_game.gd](../../instructions/flow_control/resume_game.gd) |
| `RunConditionCheck` | `FUSE_INSTRUCTION_RUN_CONDITION_CHECK_NAME` | 运行条件检查 | Run Condition Check | [instructions/flow_control/run_condition_check.gd](../../instructions/flow_control/run_condition_check.gd) |
| `RunRunner` | `FUSE_INSTRUCTION_RUN_RUNNER_NAME` | 运行 Runner | Run Runner | [instructions/flow_control/run_runner.gd](../../instructions/flow_control/run_runner.gd) |
| `Wait` | `FUSE_INSTRUCTION_WAIT_NAME` | 等待 | Wait | [instructions/flow_control/wait.gd](../../instructions/flow_control/wait.gd) |
| `WaitUntil` | `FUSE_INSTRUCTION_WAIT_UNTIL_NAME` | 等待直到 | Wait Until | [instructions/flow_control/wait_until.gd](../../instructions/flow_control/wait_until.gd) |
| `WhileLoop` | `FUSE_INSTRUCTION_WHILE_LOOP_NAME` | While 循环 | While Loop | [instructions/flow_control/while_loop.gd](../../instructions/flow_control/while_loop.gd) |

### 渲染

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `ControlParticles` | `FUSE_INSTRUCTION_CONTROL_PARTICLES_NAME` | 控制粒子 | Control Particles | [instructions/rendering/control_particles.gd](../../instructions/rendering/control_particles.gd) |
| `ScreenFlash` | `FUSE_INSTRUCTION_SCREEN_FLASH_NAME` | 屏幕闪烁 | Screen Flash | [instructions/rendering/screen_flash.gd](../../instructions/rendering/screen_flash.gd) |
| `SetLight` | `FUSE_INSTRUCTION_SET_LIGHT_NAME` | 设置灯光 | Set Light | [instructions/rendering/set_light.gd](../../instructions/rendering/set_light.gd) |
| `SetMaterialProperty` | `FUSE_INSTRUCTION_SET_MATERIAL_PROPERTY_NAME` | 设置材质属性 | Set Material Property | [instructions/rendering/set_material_property.gd](../../instructions/rendering/set_material_property.gd) |
| `SetZIndex` | `FUSE_INSTRUCTION_SET_Z_INDEX_NAME` | 设置 Z 索引 | Set Z Index | [instructions/rendering/set_z_index.gd](../../instructions/rendering/set_z_index.gd) |

### 物理

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `ApplyForce` | `FUSE_INSTRUCTION_APPLY_FORCE_NAME` | 施加力 | Apply Force | [instructions/physics/apply_force.gd](../../instructions/physics/apply_force.gd) |
| `ApplyImpulse` | `FUSE_INSTRUCTION_APPLY_IMPULSE_NAME` | 施加冲量 | Apply Impulse | [instructions/physics/apply_impulse.gd](../../instructions/physics/apply_impulse.gd) |
| `EnableDisableCollision` | `FUSE_INSTRUCTION_ENABLE_DISABLE_COLLISION_NAME` | 启用/禁用碰撞 | Enable/Disable Collision | [instructions/physics/enable_disable_collision.gd](../../instructions/physics/enable_disable_collision.gd) |
| `GroundSnap` | `FUSE_INSTRUCTION_GROUND_SNAP_NAME` | 贴地 | Ground Snap | [instructions/physics/ground_snap.gd](../../instructions/physics/ground_snap.gd) |
| `Raycast` | `FUSE_INSTRUCTION_RAYCAST_NAME` | Raycast | 射线检测 | [instructions/physics/raycast.gd](../../instructions/physics/raycast.gd) |
| `SetCollisionLayer` | `FUSE_INSTRUCTION_SET_COLLISION_LAYER_NAME` | Set Collision Layer/Mask | 设置碰撞层/掩码 | [instructions/physics/set_collision_layer.gd](../../instructions/physics/set_collision_layer.gd) |
| `SetCollisionMask` | `FUSE_INSTRUCTION_SET_COLLISION_MASK_ONLY_NAME` | 设置碰撞掩码 | Set Collision Mask | [instructions/physics/set_collision_mask.gd](../../instructions/physics/set_collision_mask.gd) |
| `SetGravityDirection` | `FUSE_INSTRUCTION_SET_GRAVITY_DIRECTION_NAME` | 设置重力方向 | Set Gravity Direction | [instructions/physics/set_gravity_direction.gd](../../instructions/physics/set_gravity_direction.gd) |
| `SetGravityScale` | `FUSE_INSTRUCTION_SET_GRAVITY_SCALE_NAME` | 设置重力缩放 | Set Gravity Scale | [instructions/physics/set_gravity_scale.gd](../../instructions/physics/set_gravity_scale.gd) |
| `SetVelocity` | `FUSE_INSTRUCTION_SET_VELOCITY_NAME` | 设置速度 | Set Velocity | [instructions/physics/set_velocity.gd](../../instructions/physics/set_velocity.gd) |

### 移动

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `MoveCharacterBody2DComposite` | `FUSE_INSTRUCTION_MOVE_CHARACTER_BODY_2D_COMPOSITE_NAME` | 移动 CharacterBody2D（复合） | Move CharacterBody2D (Composite) | [instructions/movement/move_character_body_2d_composite.gd](../../instructions/movement/move_character_body_2d_composite.gd) |

### 系统

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `GetViewportSize` | `FUSE_INSTRUCTION_GET_VIEWPORT_SIZE_NAME` | 获取视口尺寸 | Get Viewport Size | [instructions/system/get_viewport_size.gd](../../instructions/system/get_viewport_size.gd) |
| `LoadResourceByPath` | `FUSE_INSTRUCTION_LOAD_RESOURCE_NAME` | 加载资源 | Load Resource | [instructions/system/load_resource_by_path.gd](../../instructions/system/load_resource_by_path.gd) |
| `MouseWorldPosition` | `FUSE_INSTRUCTION_MOUSE_WORLD_POS_NAME` | 鼠标世界坐标 | Mouse World Position | [instructions/system/mouse_world_position.gd](../../instructions/system/mouse_world_position.gd) |
| `Quit` | `FUSE_INSTRUCTION_QUIT_NAME` | 退出应用程序 | Quit Application | [instructions/system/quit.gd](../../instructions/system/quit.gd) |

### 节点操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CloneNode` | `FUSE_INSTRUCTION_CLONE_NODE_NAME` | 克隆节点 | Clone Node | [instructions/node_operations/clone_node.gd](../../instructions/node_operations/clone_node.gd) |
| `EmitSignal` | `FUSE_INSTRUCTION_EMIT_SIGNAL_NAME` | 发射信号 | Emit Signal | [instructions/node_operations/emit_signal.gd](../../instructions/node_operations/emit_signal.gd) |
| `EnableDisableNode` | `FUSE_INSTRUCTION_ENABLE_DISABLE_NODE_NAME` | 启用/禁用节点 | Enable/Disable Node | [instructions/node_operations/enable_disable_node.gd](../../instructions/node_operations/enable_disable_node.gd) |
| `FindNode` | `FUSE_INSTRUCTION_FIND_NODE_NAME` | 查找节点 | Find Node | [instructions/node_operations/find_node.gd](../../instructions/node_operations/find_node.gd) |
| `GetAllChildren` | `FUSE_INSTRUCTION_GET_ALL_CHILDREN_NAME` | 获取所有子节点 | Get All Children | [instructions/node_operations/get_all_children.gd](../../instructions/node_operations/get_all_children.gd) |
| `GetAllChildrenPosition` | `FUSE_INSTRUCTION_GET_ALL_CHILDREN_POSITION_NAME` | 获取所有子节点位置 | Get All Children Position | [instructions/node_operations/get_all_children_position.gd](../../instructions/node_operations/get_all_children_position.gd) |
| `GetChildByIndex` | `FUSE_INSTRUCTION_GET_CHILD_BY_INDEX_NAME` | 通过索引获取子节点 | Get Child By Index | [instructions/node_operations/get_child_by_index.gd](../../instructions/node_operations/get_child_by_index.gd) |
| `GetChildCount` | `FUSE_INSTRUCTION_GET_CHILD_COUNT_NAME` | 获取子节点数量 | Get Child Count | [instructions/node_operations/get_child_count.gd](../../instructions/node_operations/get_child_count.gd) |
| `GetGroupCount` | `FUSE_INSTRUCTION_GET_GROUP_COUNT_NAME` | 获取组节点数量 | Get Group Count | [instructions/node_operations/get_group_count.gd](../../instructions/node_operations/get_group_count.gd) |
| `GetLastChild` | `FUSE_INSTRUCTION_GET_LAST_CHILD_NAME` | 获取最后一个子节点 | Get Last Child | [instructions/node_operations/get_last_child.gd](../../instructions/node_operations/get_last_child.gd) |
| `GetNodesInGroup` | `FUSE_INSTRUCTION_GET_NODES_IN_GROUP_NAME` | 获取组中节点 | Get Nodes In Group | [instructions/node_operations/get_nodes_in_group.gd](../../instructions/node_operations/get_nodes_in_group.gd) |
| `GetRandomChild` | `FUSE_INSTRUCTION_GET_RANDOM_CHILD_NAME` | 获取随机子节点 | Get Random Child | [instructions/node_operations/get_random_child.gd](../../instructions/node_operations/get_random_child.gd) |
| `InstantiateScene` | `FUSE_INSTRUCTION_INSTANTIATE_SCENE_NAME` | 实例化场景 | Instantiate Scene | [instructions/node_operations/instantiate_scene.gd](../../instructions/node_operations/instantiate_scene.gd) |
| `QueueFreeNode` | `FUSE_INSTRUCTION_QUEUE_FREE_NODE_NAME` | 释放节点 | Queue Free Node | [instructions/node_operations/queue_free_node.gd](../../instructions/node_operations/queue_free_node.gd) |
| `RecyclePooledScene` | `FUSE_INSTRUCTION_RECYCLE_POOLED_SCENE_NAME` | 回收池化场景 | Recycle Pooled Scene | [instructions/node_operations/recycle_pooled_scene.gd](../../instructions/node_operations/recycle_pooled_scene.gd) |
| `ReparentNode` | `FUSE_INSTRUCTION_REPARENT_NODE_NAME` | 重父化节点 | Reparent Node | [instructions/node_operations/reparent_node.gd](../../instructions/node_operations/reparent_node.gd) |
| `RunTargetNodeFunction` | `FUSE_INSTRUCTION_RUN_TARGET_NODE_FUNCTION_NAME` | 运行节点函数 | Run Node Function | [instructions/node_operations/run_target_node_function.gd](../../instructions/node_operations/run_target_node_function.gd) |
| `SetGlobalPosition` | `FUSE_INSTRUCTION_SET_GLOBAL_POSITION_NAME` | 设置全局位置 | Set Global Position | [instructions/node_operations/set_global_position.gd](../../instructions/node_operations/set_global_position.gd) |
| `SetProcessMode` | `FUSE_INSTRUCTION_SET_PROCESS_MODE_NAME` | 设置处理模式 | Set Process Mode | [instructions/node_operations/set_process_mode.gd](../../instructions/node_operations/set_process_mode.gd) |
| `SetPropertyValue` | `FUSE_INSTRUCTION_SET_PROPERTY_VALUE_NAME` | 设置属性值 | Set Property Value | [instructions/node_operations/set_property_value.gd](../../instructions/node_operations/set_property_value.gd) |
| `WarmUpPool` | `FUSE_INSTRUCTION_WARM_UP_POOL_NAME` | 预热对象池 | Warm Up Object Pool | [instructions/node_operations/warm_up_pool.gd](../../instructions/node_operations/warm_up_pool.gd) |

### 补间动画

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `TweenBounceAnimation` | `FUSE_INSTRUCTION_TWEEN_BOUNCE_ANIMATION_NAME` | 弹跳动画 | Bounce Animation | [instructions/tween/tween_bounce_animation.gd](../../instructions/tween/tween_bounce_animation.gd) |
| `TweenColorTransition` | `FUSE_INSTRUCTION_TWEEN_COLOR_TRANSITION_NAME` | 颜色过渡 | Color Transition | [instructions/tween/tween_color_transition.gd](../../instructions/tween/tween_color_transition.gd) |
| `TweenFadeIn` | `FUSE_INSTRUCTION_TWEEN_FADE_IN_NAME` | 淡入 | Fade In | [instructions/tween/tween_fade_in.gd](../../instructions/tween/tween_fade_in.gd) |
| `TweenFadeOut` | `FUSE_INSTRUCTION_TWEEN_FADE_OUT_NAME` | 淡出 | Fade Out | [instructions/tween/tween_fade_out.gd](../../instructions/tween/tween_fade_out.gd) |
| `TweenMoveTo` | `FUSE_INSTRUCTION_TWEEN_MOVE_TO_NAME` | 移动到 | Move To | [instructions/tween/tween_move_to.gd](../../instructions/tween/tween_move_to.gd) |
| `TweenPause` | `FUSE_INSTRUCTION_TWEEN_PAUSE_NAME` | 暂停 Tween | Pause Tween | [instructions/tween/tween_pause.gd](../../instructions/tween/tween_pause.gd) |
| `TweenPopAnimation` | `FUSE_INSTRUCTION_TWEEN_POP_ANIMATION_NAME` | 弹出动画 | Pop Animation | [instructions/tween/tween_pop_animation.gd](../../instructions/tween/tween_pop_animation.gd) |
| `TweenPropertyInstruction` | `FUSE_INSTRUCTION_TWEEN_PROPERTY_NAME` | 属性动画 | Property Animation | [instructions/tween/tween_property.gd](../../instructions/tween/tween_property.gd) |
| `TweenPulseAnimation` | `FUSE_INSTRUCTION_TWEEN_PULSE_ANIMATION_NAME` | 脉冲动画 | Pulse Animation | [instructions/tween/tween_pulse_animation.gd](../../instructions/tween/tween_pulse_animation.gd) |
| `TweenResume` | `FUSE_INSTRUCTION_TWEEN_RESUME_NAME` | 恢复 Tween | Resume Tween | [instructions/tween/tween_resume.gd](../../instructions/tween/tween_resume.gd) |
| `TweenRotateTo` | `FUSE_INSTRUCTION_TWEEN_ROTATE_TO_NAME` | 旋转到 | Rotate To | [instructions/tween/tween_rotate_to.gd](../../instructions/tween/tween_rotate_to.gd) |
| `TweenScaleTo` | `FUSE_INSTRUCTION_TWEEN_SCALE_TO_NAME` | 缩放到 | Scale To | [instructions/tween/tween_scale_to.gd](../../instructions/tween/tween_scale_to.gd) |
| `TweenShakeAnimation` | `FUSE_INSTRUCTION_TWEEN_SHAKE_ANIMATION_NAME` | 震动动画 | Shake Animation | [instructions/tween/tween_shake_animation.gd](../../instructions/tween/tween_shake_animation.gd) |

### 调试

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `BreakpointInstruction` | `FUSE_INSTRUCTION_BREAKPOINT_NAME` | 断点 | Breakpoint | [instructions/debug/breakpoint_instruction.gd](../../instructions/debug/breakpoint_instruction.gd) |
| `Print` | `FUSE_INSTRUCTION_PRINT_NAME` | 打印消息 | Print Message | [instructions/debug/print.gd](../../instructions/debug/print.gd) |
| `PrintVariableValue` | `FUSE_INSTRUCTION_PRINT_VARIABLE_NAME` | 打印变量值 | Print Variable Value | [instructions/debug/print_variable_value.gd](../../instructions/debug/print_variable_value.gd) |

### 音频

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CrossfadeToMusic` | `FUSE_INSTRUCTION_CROSSFADE_TO_MUSIC_NAME` | 交叉淡入淡出音乐 | Crossfade to Music | [instructions/audio/crossfade_to_music.gd](../../instructions/audio/crossfade_to_music.gd) |
| `PauseResumeAudio` | `FUSE_INSTRUCTION_PAUSE_RESUME_AUDIO_NAME` | 暂停/恢复音频 | Pause/Resume Audio | [instructions/audio/pause_resume_audio.gd](../../instructions/audio/pause_resume_audio.gd) |
| `PlayMusic` | `FUSE_INSTRUCTION_PLAY_MUSIC_NAME` | 播放音乐 | Play Music | [instructions/audio/play_music.gd](../../instructions/audio/play_music.gd) |
| `PlayRandomSound` | `FUSE_INSTRUCTION_PLAY_RANDOM_SOUND_NAME` | 随机播放音效 | Play Random Sound | [instructions/audio/play_random_sound.gd](../../instructions/audio/play_random_sound.gd) |
| `PlaySound` | `FUSE_INSTRUCTION_PLAY_SOUND_NAME` | 播放音效 | Play Sound | [instructions/audio/play_sound.gd](../../instructions/audio/play_sound.gd) |
| `SetAudioVolume` | `FUSE_INSTRUCTION_SET_AUDIO_VOLUME_NAME` | 设置音量 | Set Audio Volume | [instructions/audio/set_audio_volume.gd](../../instructions/audio/set_audio_volume.gd) |
| `StopAudio` | `FUSE_INSTRUCTION_STOP_AUDIO_NAME` | 停止音频 | Stop Audio | [instructions/audio/stop_audio.gd](../../instructions/audio/stop_audio.gd) |

## 事件 (Event)

### Tween

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnTweenCompleted` | `FUSE_EVENT_ON_TWEEN_COMPLETED_NAME` | Tween 完成 | Tween Completed | [events/tween/on_tween_completed.gd](../../events/tween/on_tween_completed.gd) |

### UI

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnButtonPressed` | `FUSE_EVENT_ON_BUTTON_PRESSED_NAME` | 按钮按下 | Button Pressed | [events/ui/on_button_pressed.gd](../../events/ui/on_button_pressed.gd) |
| `OnFocus` | `FUSE_EVENT_ON_FOCUS_NAME` | 焦点变化 | Focus Changed | [events/ui/on_focus.gd](../../events/ui/on_focus.gd) |
| `OnItemSelected` | `FUSE_EVENT_ON_ITEM_SELECTED_NAME` | ItemList 选中项改变 | Item List Selection Changed | [events/ui/on_item_selected.gd](../../events/ui/on_item_selected.gd) |
| `OnTextChanged` | `FUSE_EVENT_ON_TEXT_CHANGED_NAME` | 文本改变 | Text Changed | [events/ui/on_text_changed.gd](../../events/ui/on_text_changed.gd) |
| `OnUIMouseEntered` | `FUSE_EVENT_MOUSE_ENTERED_NAME` | 鼠标进入 UI | Mouse Entered UI | [events/ui/on_ui_mouse_entered.gd](../../events/ui/on_ui_mouse_entered.gd) |
| `OnUIMouseExited` | `FUSE_EVENT_MOUSE_EXITED_NAME` | 鼠标离开 UI | Mouse Exited UI | [events/ui/on_ui_mouse_exited.gd](../../events/ui/on_ui_mouse_exited.gd) |
| `OnValueChanged` | `FUSE_EVENT_ON_VALUE_CHANGED_NAME` | 值改变 | Value Changed | [events/ui/on_value_changed.gd](../../events/ui/on_value_changed.gd) |

### 事件

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnReceiveEvent` | `FUSE_EVENT_ON_RECEIVE_EVENT_NAME` | 接收事件 | On Receive Event | [events/event/on_receive_event.gd](../../events/event/on_receive_event.gd) |

### 动画

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnAnimationBlend` | `FUSE_EVENT_ON_ANIMATION_BLEND_NAME` | 动画混合 | Animation Blend | [events/animation/on_animation_blend.gd](../../events/animation/on_animation_blend.gd) |
| `OnAnimationFinished` | `FUSE_EVENT_ON_ANIMATION_FINISHED_NAME` | 动画完成 | Animation Finished | [events/animation/on_animation_finished.gd](../../events/animation/on_animation_finished.gd) |
| `OnAnimationFrameReached` | `FUSE_EVENT_ON_ANIMATION_FRAME_REACHED_NAME` | 动画帧到达 | Animation Frame Reached | [events/animation/on_animation_frame_reached.gd](../../events/animation/on_animation_frame_reached.gd) |
| `OnAnimationLoop` | `FUSE_EVENT_ON_ANIMATION_LOOP_NAME` | 动画循环 | Animation Loop | [events/animation/on_animation_loop.gd](../../events/animation/on_animation_loop.gd) |
| `OnAnimationMarker` | `FUSE_EVENT_ON_ANIMATION_MARKER_NAME` | 动画标记 | Animation Marker | [events/animation/on_animation_marker.gd](../../events/animation/on_animation_marker.gd) |
| `OnAnimationStarted` | `FUSE_EVENT_ON_ANIMATION_STARTED_NAME` | 动画开始 | Animation Started | [events/animation/on_animation_started.gd](../../events/animation/on_animation_started.gd) |

### 场景

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnBackgroundLoadProgress` | `FUSE_EVENT_ON_BACKGROUND_LOAD_PROGRESS_NAME` | 后台加载进度 | Background Load Progress | [events/scene/on_background_load_progress.gd](../../events/scene/on_background_load_progress.gd) |
| `OnNodePausedResumed` | `FUSE_EVENT_ON_NODE_PAUSED_RESUMED_NAME` | 节点暂停/恢复 | Node Paused/Resumed | [events/scene/on_node_paused_resumed.gd](../../events/scene/on_node_paused_resumed.gd) |
| `OnSceneAboutToChange` | `FUSE_EVENT_ON_SCENE_ABOUT_TO_CHANGE_NAME` | 场景切换前 | Scene About To Change | [events/scene/on_scene_about_to_change.gd](../../events/scene/on_scene_about_to_change.gd) |
| `OnSceneLoaded` | `FUSE_EVENT_ON_SCENE_LOADED_NAME` | 场景加载完成 | Scene Loaded | [events/scene/on_scene_loaded.gd](../../events/scene/on_scene_loaded.gd) |
| `OnTreeChanged` | `FUSE_EVENT_ON_TREE_CHANGED_NAME` | 场景树变化 | Tree Changed | [events/scene/on_tree_changed.gd](../../events/scene/on_tree_changed.gd) |

### 导航

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnNavigationTargetReached` | `FUSE_EVENT_NAV_TARGET_REACHED_NAME` | 导航到达目标 | Navigation Target Reached | [events/navigation/on_navigation_target_reached.gd](../../events/navigation/on_navigation_target_reached.gd) |

### 时间

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnCooldownFinished` | `FUSE_EVENT_ON_COOLDOWN_FINISHED_NAME` | 冷却完成 | Cooldown Finished | [events/timing/on_cooldown_finished.gd](../../events/timing/on_cooldown_finished.gd) |
| `OnCountdown` | `FUSE_EVENT_ON_COUNTDOWN_NAME` | 倒计时 | Countdown | [events/timing/on_countdown.gd](../../events/timing/on_countdown.gd) |
| `OnRealtime` | `FUSE_EVENT_ON_REALTIME_NAME` | 实时时间 | Realtime | [events/timing/on_realtime.gd](../../events/timing/on_realtime.gd) |
| `OnTimer` | `FUSE_EVENT_ON_TIMER_NAME` | 定时器 | Timer | [events/timing/on_timer.gd](../../events/timing/on_timer.gd) |

### 物理

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnArea2DEnter` | `FUSE_EVENT_ON_AREA_2D_ENTER_NAME` | 区域进入 | Area Entered | [events/physics/on_area_2d_enter.gd](../../events/physics/on_area_2d_enter.gd) |
| `OnArea2DExited` | `FUSE_EVENT_ON_AREA_2D_EXITED_NAME` | 区域离开 | Area Exited | [events/physics/on_area_2d_exited.gd](../../events/physics/on_area_2d_exited.gd) |
| `OnArea3DEntered` | `FUSE_EVENT_ON_AREA_3D_ENTERED_NAME` | 区域进入（3D） | Area Entered (3D) | [events/physics/on_area_3d_entered.gd](../../events/physics/on_area_3d_entered.gd) |
| `OnArea3DExited` | `FUSE_EVENT_ON_AREA_3D_EXITED_NAME` | 区域离开（3D） | Area Exited (3D) | [events/physics/on_area_3d_exited.gd](../../events/physics/on_area_3d_exited.gd) |
| `OnBodyEntered` | `FUSE_EVENT_ON_BODY_ENTERED_NAME` | 物体进入 | Body Entered | [events/physics/on_body_entered.gd](../../events/physics/on_body_entered.gd) |
| `OnCollision` | `FUSE_EVENT_ON_COLLISION_NAME` | 碰撞 | Collision | [events/physics/on_collision.gd](../../events/physics/on_collision.gd) |
| `OnGroundStateChanged` | `FUSE_EVENT_GROUND_STATE_NAME` | 着地状态变化 | Ground State Changed | [events/physics/on_ground_state_changed.gd](../../events/physics/on_ground_state_changed.gd) |
| `OnOverlappingBodies` | `FUSE_EVENT_ON_OVERLAPPING_BODIES_NAME` | 重叠物体 | Overlapping Bodies | [events/physics/on_overlapping_bodies.gd](../../events/physics/on_overlapping_bodies.gd) |
| `OnRaycastHit` | `FUSE_EVENT_ON_RAYCAST_HIT_NAME` | 射线命中 | Raycast Hit | [events/physics/on_raycast_hit.gd](../../events/physics/on_raycast_hit.gd) |
| `OnScreenEnteredExited` | `FUSE_EVENT_ON_SCREEN_ENTERED_EXITED_NAME` | 屏幕进入/离开 | Screen Entered/Exited | [events/physics/on_screen_entered_exited.gd](../../events/physics/on_screen_entered_exited.gd) |
| `OnShapeCast` | `FUSE_EVENT_ON_SHAPE_CAST_NAME` | 形状投射 | Shape Cast | [events/physics/on_shape_cast.gd](../../events/physics/on_shape_cast.gd) |

### 状态

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnHealthChanged` | `FUSE_EVENT_ON_HEALTH_CHANGED_NAME` | 生命值变化 | Health Changed | [events/gameplay/on_health_changed.gd](../../events/gameplay/on_health_changed.gd) |
| `OnPropertyChanged` | `FUSE_EVENT_ON_PROPERTY_CHANGED_NAME` | 属性变化 | Property Changed | [events/node/on_property_changed.gd](../../events/node/on_property_changed.gd) |
| `OnSoundListened` | `FUSE_EVENT_ON_SOUND_LISTENED_NAME` | 声音被听到 | Sound Listened | [events/gameplay/on_sound_listened.gd](../../events/gameplay/on_sound_listened.gd) |
| `OnVariableChanged` | `FUSE_EVENT_ON_VARIABLE_CHANGED_NAME` | 变量变化 | Variable Changed | [events/variable/on_variable_changed.gd](../../events/variable/on_variable_changed.gd) |

### 生命周期

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnEnterTree` | `FUSE_EVENT_ON_ENTER_TREE_NAME` | 节点进入场景树 | Node Enter Tree | [events/lifecycle/on_enter_tree.gd](../../events/lifecycle/on_enter_tree.gd) |
| `OnExitTree` | `FUSE_EVENT_ON_EXIT_TREE_NAME` | 退出场景树 | Exit Scene Tree | [events/lifecycle/on_exit_tree.gd](../../events/lifecycle/on_exit_tree.gd) |
| `OnInterval` | `FUSE_EVENT_ON_INTERVAL_NAME` | 间隔执行 | Interval | [events/lifecycle/on_interval.gd](../../events/lifecycle/on_interval.gd) |
| `OnIntervalWithVariable` | `FUSE_EVENT_ON_INTERVAL_WITH_VARIABLE_NAME` | 变量间隔执行 | Variable Interval | [events/lifecycle/on_interval_with_variable.gd](../../events/lifecycle/on_interval_with_variable.gd) |
| `OnPhysicsProcess` | `FUSE_EVENT_ON_PHYSICS_PROCESS_NAME` | 物理帧处理 | Physics Process | [events/lifecycle/on_physics_process.gd](../../events/lifecycle/on_physics_process.gd) |
| `OnProcess` | `FUSE_EVENT_ON_PROCESS_NAME` | 每帧处理 | Process | [events/lifecycle/on_process.gd](../../events/lifecycle/on_process.gd) |
| `OnReady` | `FUSE_EVENT_ON_READY_NAME` | 场景就绪 | Scene Ready | [events/lifecycle/on_ready.gd](../../events/lifecycle/on_ready.gd) |

### 节点

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnNodeInstance` | `FUSE_EVENT_ON_NODE_INSTANCE_NAME` | 节点实例化 | Node Instance | [events/node/on_node_instance.gd](../../events/node/on_node_instance.gd) |
| `OnSignalFromGroup` | `FUSE_EVENT_ON_SIGNAL_FROM_GROUP_NAME` | 组信号监听 | Signal From Group | [events/node/on_signal_from_group.gd](../../events/node/on_signal_from_group.gd) |
| `OnTargetSignalEmit` | `FUSE_EVENT_ON_TARGET_SIGNAL_EMIT_NAME` | 目标信号发出 | Target Signal Emitted | [events/node/on_target_signal_emit.gd](../../events/node/on_target_signal_emit.gd) |

### 输入

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnDirectionalInputChanged` | `FUSE_EVENT_DIRECTIONAL_INPUT_NAME` | 方向输入变化 | Directional Input Changed | [events/input/on_directional_input_changed.gd](../../events/input/on_directional_input_changed.gd) |
| `OnGamepadAxis` | `FUSE_EVENT_ON_GAMEPAD_AXIS_NAME` | 游戏手柄轴 | Gamepad Axis | [events/input/on_gamepad_axis.gd](../../events/input/on_gamepad_axis.gd) |
| `OnGamepadButton` | `FUSE_EVENT_ON_GAMEPAD_BUTTON_NAME` | 游戏手柄按键 | Gamepad Button | [events/input/on_gamepad_button.gd](../../events/input/on_gamepad_button.gd) |
| `OnInputAction` | `FUSE_EVENT_ON_INPUT_ACTION_NAME` | 动作输入 | Action Input | [events/input/on_input_action.gd](../../events/input/on_input_action.gd) |
| `OnInputActionComposite` | `FUSE_EVENT_ON_INPUT_ACTION_COMPOSITE_NAME` | 复合输入动作 | On Input Action Composite | [events/input/on_input_action_composite.gd](../../events/input/on_input_action_composite.gd) |
| `OnInputBuffered` | `FUSE_EVENT_ON_INPUT_BUFFERED_NAME` | 输入缓冲 | Input Buffered | [events/input/on_input_buffered.gd](../../events/input/on_input_buffered.gd) |
| `OnInputCombo` | `FUSE_EVENT_ON_INPUT_COMBO_NAME` | 输入连招 | On Input Combo | [events/input/on_input_combo.gd](../../events/input/on_input_combo.gd) |
| `OnInputKey` | `FUSE_EVENT_ON_INPUT_KEY_NAME` | 按键输入 | Key Input | [events/input/on_input_key.gd](../../events/input/on_input_key.gd) |
| `OnInputText` | `FUSE_EVENT_ON_INPUT_TEXT_NAME` | 文本输入 | Input Text | [events/input/on_input_text.gd](../../events/input/on_input_text.gd) |
| `OnMouseButton` | `FUSE_EVENT_ON_MOUSE_BUTTON_NAME` | 鼠标按键 | Mouse Button | [events/input/on_mouse_button.gd](../../events/input/on_mouse_button.gd) |
| `OnMouseEnter` | `FUSE_EVENT_ON_MOUSE_ENTER_NAME` | 鼠标进入 | Mouse Enter | [events/input/on_mouse_enter.gd](../../events/input/on_mouse_enter.gd) |
| `OnMouseExit` | `FUSE_EVENT_ON_MOUSE_EXIT_NAME` | 鼠标离开 | Mouse Exit | [events/input/on_mouse_exit.gd](../../events/input/on_mouse_exit.gd) |
| `OnMouseMove` | `FUSE_EVENT_ON_MOUSE_MOVE_NAME` | 鼠标移动 | Mouse Move | [events/input/on_mouse_move.gd](../../events/input/on_mouse_move.gd) |
| `OnTouch` | `FUSE_EVENT_ON_TOUCH_NAME` | 触摸 | Touch | [events/input/on_touch.gd](../../events/input/on_touch.gd) |
| `OnTouchSwipe` | `FUSE_EVENT_ON_TOUCH_SWIPE_NAME` | 触摸滑动 | Touch Swipe | [events/input/on_touch_swipe.gd](../../events/input/on_touch_swipe.gd) |

### 音频

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `OnAudioBusVolumeChanged` | `FUSE_EVENT_ON_AUDIO_BUS_VOLUME_CHANGED_NAME` | 音频总线音量变化 | Audio Bus Volume Changed | [events/audio/on_audio_bus_volume_changed.gd](../../events/audio/on_audio_bus_volume_changed.gd) |
| `OnAudioFinished` | `FUSE_EVENT_ON_AUDIO_FINISHED_NAME` | 音频播放完成 | Audio Finished | [events/audio/on_audio_finished.gd](../../events/audio/on_audio_finished.gd) |
| `OnAudioStarted` | `FUSE_EVENT_ON_AUDIO_STARTED_NAME` | 音频开始播放 | Audio Started | [events/audio/on_audio_started.gd](../../events/audio/on_audio_started.gd) |
| `OnMusicBeat` | `FUSE_EVENT_ON_MUSIC_BEAT_NAME` | 音乐节拍 | Music Beat | [events/audio/on_music_beat.gd](../../events/audio/on_music_beat.gd) |

## 条件 (Condition)

### UI 控制

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckUIVisible` | `FUSE_CONDITION_UI_VISIBLE_NAME` | 检查 UI 可见 | Check UI Visible | [conditions/ui/check_ui_visible.gd](../../conditions/ui/check_ui_visible.gd) |

### scope

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckScopeVariable` | `—` |  |  | [conditions/scope/check_scope_variable.gd](../../conditions/scope/check_scope_variable.gd) |

### 动画

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckAnimationFinished` | `FUSE_CONDITION_ANIMATION_FINISHED_NAME` | 动画完成 | Animation Finished | [conditions/animation/check_animation_finished.gd](../../conditions/animation/check_animation_finished.gd) |
| `CheckAnimationTreeParameter` | `FUSE_CONDITION_ANIM_TREE_PARAM_NAME` | 检查动画树参数 | Check AnimationTree Parameter | [conditions/animation/check_animation_tree_parameter.gd](../../conditions/animation/check_animation_tree_parameter.gd) |
| `CheckAnimationTreeState` | `FUSE_CONDITION_ANIMATION_TREE_STATE_NAME` | AnimationTree 状态 | AnimationTree State | [conditions/animation/check_animation_tree_state.gd](../../conditions/animation/check_animation_tree_state.gd) |
| `CheckIsAnimation` | `FUSE_CONDITION_IS_ANIMATION_NAME` | 指定动画 | Is Animation | [conditions/animation/check_is_animation.gd](../../conditions/animation/check_is_animation.gd) |
| `CheckIsPlaying` | `FUSE_CONDITION_IS_PLAYING_NAME` | 动画播放中 | Is Playing | [conditions/animation/check_is_playing.gd](../../conditions/animation/check_is_playing.gd) |

### 变量

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckHealthValue` | `FUSE_CONDITION_HEALTH_VALUE_NAME` | 生命值检测 | Health Value | [conditions/variable/check_health_value.gd](../../conditions/variable/check_health_value.gd) |
| `CheckVector2VariableAxis` | `FUSE_CONDITION_VECTOR2_AXIS_CHECK_NAME` | Vector2 轴检查 | Vector2 Axis Check | [conditions/variable/check_vector2_variable_axis.gd](../../conditions/variable/check_vector2_variable_axis.gd) |
| `CompareHealthThreshold` | `FUSE_CONDITION_COMPARE_HEALTH_THRESHOLD_NAME` | 生命值低于/高于 | Compare Health Threshold | [conditions/variable/compare_health_threshold.gd](../../conditions/variable/compare_health_threshold.gd) |
| `CompareVariable` | `FUSE_CONDITION_VARIABLE_COMPARISON_NAME` | 变量比较 | Variable Comparison | [conditions/variable/compare_variable.gd](../../conditions/variable/compare_variable.gd) |

### 变量操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckVariable` | `FUSE_CONDITION_CHECK_VARIABLE_NAME` | 变量检查 | Check Variable | [conditions/variable/check_variable.gd](../../conditions/variable/check_variable.gd) |

### 场景管理

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckPreloadStatus` | `FUSE_CONDITION_CHECK_PRELOAD_STATUS_NAME` | 检查预加载状态 | Check Preload Status | [conditions/scene/check_preload_status.gd](../../conditions/scene/check_preload_status.gd) |

### 复合逻辑

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckAll` | `FUSE_CONDITION_ALL_NAME` | 所有条件满足 | All | [conditions/composite/check_all.gd](../../conditions/composite/check_all.gd) |
| `CheckAny` | `FUSE_CONDITION_ANY_NAME` | 任意条件满足 | Any | [conditions/composite/check_any.gd](../../conditions/composite/check_any.gd) |
| `CheckComposite` | `FUSE_CONDITION_COMPOSITE_NAME` | 条件组合 | Composite | [conditions/composite/check_composite.gd](../../conditions/composite/check_composite.gd) |
| `CheckNot` | `FUSE_CONDITION_NOT_NAME` | 非 | Not | [conditions/composite/check_not.gd](../../conditions/composite/check_not.gd) |

### 字典

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckDictContainsKey` | `FUSE_CONDITION_DICT_CONTAINS_KEY_NAME` | 字典包含键 | Dict Contains Key | [conditions/dictionaries/check_dict_contains_key.gd](../../conditions/dictionaries/check_dict_contains_key.gd) |
| `CheckDictSize` | `FUSE_CONDITION_DICT_SIZE_NAME` | 检查字典大小 | Check Dict Size | [conditions/dictionaries/check_dict_size.gd](../../conditions/dictionaries/check_dict_size.gd) |

### 字符串

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckStringContains` | `FUSE_CONDITION_STRING_CONTAINS_NAME` | 检查字符串包含 | Check String Contains | [conditions/string/check_string_contains.gd](../../conditions/string/check_string_contains.gd) |
| `CheckStringLength` | `FUSE_CONDITION_STRING_LENGTH_NAME` | 检查字符串长度 | Check String Length | [conditions/string/check_string_length.gd](../../conditions/string/check_string_length.gd) |

### 导航

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckPathAvailable` | `FUSE_CONDITION_PATH_AVAILABLE_NAME` | 检查路径可用 | Check Path Available | [conditions/navigation/check_path_available.gd](../../conditions/navigation/check_path_available.gd) |

### 数学

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `ExpressionCondition` | `FUSE_CONDITION_EXPRESSION_NAME` | 表达式条件 | Expression Condition | [conditions/math/expression_condition.gd](../../conditions/math/expression_condition.gd) |

### 数组操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckArrayContains` | `FUSE_CONDITION_ARRAY_CONTAINS_NAME` | 数组包含 | Array Contains | [conditions/arrays/check_array_contains.gd](../../conditions/arrays/check_array_contains.gd) |
| `CheckArraySize` | `FUSE_CONDITION_ARRAY_SIZE_NAME` | 数组大小 | Array Size | [conditions/arrays/check_array_size.gd](../../conditions/arrays/check_array_size.gd) |

### 时间

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckCountdownFinished` | `FUSE_CONDITION_COUNTDOWN_FINISHED_NAME` | 倒计时结束 | Countdown Finished | [conditions/time/check_countdown_finished.gd](../../conditions/time/check_countdown_finished.gd) |
| `CheckGameTime` | `FUSE_CONDITION_GAME_TIME_NAME` | 游戏时间 | Game Time | [conditions/time/check_game_time.gd](../../conditions/time/check_game_time.gd) |
| `CheckTimeRange` | `FUSE_CONDITION_TIME_RANGE_NAME` | 时间段内 | Time Range | [conditions/time/check_time_range.gd](../../conditions/time/check_time_range.gd) |
| `CheckTimeReached` | `FUSE_CONDITION_TIME_REACHED_NAME` | 时间到达 | Time Reached | [conditions/time/check_time_reached.gd](../../conditions/time/check_time_reached.gd) |

### 渲染

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckIsOnScreen` | `FUSE_CONDITION_CHECK_IS_ON_SCREEN_NAME` | 检查是否在屏幕上 | Check Is On Screen | [conditions/rendering/check_is_on_screen.gd](../../conditions/rendering/check_is_on_screen.gd) |

### 物理

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckInAir` | `FUSE_CONDITION_IN_AIR_NAME` | 在空中 | In Air | [conditions/physics/check_in_air.gd](../../conditions/physics/check_in_air.gd) |
| `CheckIsFalling` | `FUSE_CONDITION_IS_FALLING_NAME` | 正在下落 | Is Falling | [conditions/physics/check_is_falling.gd](../../conditions/physics/check_is_falling.gd) |
| `CheckOnFloor` | `FUSE_CONDITION_ON_FLOOR_NAME` | 在地面上 | On Floor | [conditions/physics/check_on_floor.gd](../../conditions/physics/check_on_floor.gd) |
| `CheckOnWall` | `FUSE_CONDITION_ON_WALL_NAME` | 在墙壁上 | On Wall | [conditions/physics/check_on_wall.gd](../../conditions/physics/check_on_wall.gd) |
| `CheckOverlapArea` | `FUSE_CONDITION_CHECK_OVERLAP_AREA_NAME` | 检查区域重叠 | Check Overlap Area | [conditions/physics/check_overlap_area.gd](../../conditions/physics/check_overlap_area.gd) |
| `CheckSlope` | `FUSE_CONDITION_CHECK_SLOPE_NAME` | 检查斜坡 | Check Slope | [conditions/physics/check_slope.gd](../../conditions/physics/check_slope.gd) |
| `CheckVelocity` | `FUSE_CONDITION_VELOCITY_NAME` | 速度检测 | Velocity | [conditions/physics/check_velocity.gd](../../conditions/physics/check_velocity.gd) |

### 系统

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckFrameRate` | `FUSE_CONDITION_FRAME_RATE_NAME` | 检查帧率 | Check Frame Rate | [conditions/system/check_frame_rate.gd](../../conditions/system/check_frame_rate.gd) |
| `CheckPlatform` | `FUSE_CONDITION_PLATFORM_NAME` | 检查平台 | Check Platform | [conditions/system/check_platform.gd](../../conditions/system/check_platform.gd) |

### 节点

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckDirection` | `FUSE_CONDITION_DIRECTION_NAME` | 方位检测 | Direction | [conditions/node/check_direction.gd](../../conditions/node/check_direction.gd) |
| `CheckFacingDirection` | `FUSE_CONDITION_FACING_DIRECTION_NAME` | 方向检测 | Facing Direction | [conditions/node/check_facing_direction.gd](../../conditions/node/check_facing_direction.gd) |
| `CheckIsChildOf` | `FUSE_CONDITION_IS_CHILD_OF_NAME` | 节点层次关系 | Is Child Of | [conditions/node/check_is_child_of.gd](../../conditions/node/check_is_child_of.gd) |

### 节点操作

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckChildCount` | `FUSE_CONDITION_CHILD_COUNT_NAME` | 子节点数量 | Child Count | [conditions/node/check_child_count.gd](../../conditions/node/check_child_count.gd) |
| `CheckGroupCount` | `FUSE_CONDITION_GROUP_COUNT_NAME` | 组成员数量 | Group Count | [conditions/node/check_group_count.gd](../../conditions/node/check_group_count.gd) |
| `CheckNodeActive` | `FUSE_CONDITION_NODE_ACTIVE_NAME` | 节点激活 | Node Active | [conditions/node/check_node_active.gd](../../conditions/node/check_node_active.gd) |
| `CheckNodeExists` | `FUSE_CONDITION_NODE_EXISTS_NAME` | 节点存在性检查 | Node Exists Check | [conditions/node/check_node_exists.gd](../../conditions/node/check_node_exists.gd) |
| `CheckNodeInGroup` | `FUSE_CONDITION_NODE_IN_GROUP_NAME` | 节点组检测 | In Group | [conditions/node/check_node_in_group.gd](../../conditions/node/check_node_in_group.gd) |
| `CheckNodeProperty` | `FUSE_CONDITION_NODE_PROPERTY_CHECK_NAME` | 节点属性检查 | Node Property Check | [conditions/node/check_node_property.gd](../../conditions/node/check_node_property.gd) |

### 距离

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckDistance` | `FUSE_CONDITION_DISTANCE_NAME` | 对象距离 | Distance | [conditions/distance/check_distance.gd](../../conditions/distance/check_distance.gd) |

### 输入

| class_name | 翻译键 | 中文名 | 英文名 | 文件 |
|------------|--------|--------|--------|------|
| `CheckAnyInput` | `FUSE_CONDITION_ANY_INPUT_NAME` | 任意输入 | Any Input | [conditions/input/check_any_input.gd](../../conditions/input/check_any_input.gd) |
| `CheckInputDirection` | `FUSE_CONDITION_INPUT_DIRECTION_NAME` | 检查输入方向 | Check Input Direction | [conditions/input/check_input_direction.gd](../../conditions/input/check_input_direction.gd) |
| `CheckInputHeld` | `FUSE_CONDITION_INPUT_HELD_NAME` | 按键持续按住 | Input Held | [conditions/input/check_input_held.gd](../../conditions/input/check_input_held.gd) |
| `CheckInputMagnitude` | `FUSE_CONDITION_INPUT_MAGNITUDE_NAME` | 检查输入大小 | Check Input Magnitude | [conditions/input/check_input_magnitude.gd](../../conditions/input/check_input_magnitude.gd) |
| `CheckInputPressed` | `FUSE_CONDITION_INPUT_PRESSED_NAME` | 按键按下 | Input Pressed | [conditions/input/check_input_pressed.gd](../../conditions/input/check_input_pressed.gd) |
| `CheckInputReleased` | `FUSE_CONDITION_INPUT_RELEASED_NAME` | 按键释放 | Input Released | [conditions/input/check_input_released.gd](../../conditions/input/check_input_released.gd) |

## 附录：需要补全的组件

### 缺失 `name_key`（无法定位翻译键）

- `CheckScopeVariable` — conditions/scope/check_scope_variable.gd
