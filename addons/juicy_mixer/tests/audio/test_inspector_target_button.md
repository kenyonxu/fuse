# Task 3 测试指南：JuicyAudioPlayerInspector 目标节点管理功能

## 测试目标
验证 JuicyAudioPlayerInspector 中新增的目标节点显示和"设置为父节点"按钮功能。

## 测试前准备
1. 打开 Godot 编辑器
2. 打开项目：`E:\Godot\GodotProjects\project-juicy-godot`
3. 创建测试场景或使用现有场景

## 测试步骤

### 测试 1：显示目标节点信息
1. 创建一个 Node2D 节点，命名为 "Player"
2. 为 Player 添加一个子节点：JuicyAudioPlayer
3. 选择 JuicyAudioPlayer 节点
4. 查看 Inspector 底部的状态面板

**预期结果：**
- 显示 "父节点: Player"
- 显示 "目标节点: Player (默认父节点)"
- 显示 "绑定数量: 0"（如果没有 AudioComponent）
- 显示两个按钮："🔄 设置为父节点" 和 "🧪 测试所有绑定"

### 测试 2：点击"设置为父节点"按钮
1. 在测试 1 的场景中
2. 点击 "🔄 设置为父节点" 按钮

**预期结果：**
- 控制台输出：`[JuicyAudioPlayerInspector] Target 已设置为父节点: Player`
- Inspector 中的 "目标节点" 标签更新为 "目标节点: Player (显式指定)"
- JuicyAudioPlayer 的 `target` 属性被设置为 Player 节点

### 测试 3：显式设置 target 后显示
1. 在 Inspector 中找到 JuicyAudioPlayer 的 `target` 属性
2. 将其设置为 Player 节点（如果之前没有设置）
3. 查看状态面板

**预期结果：**
- 显示 "目标节点: Player (显式指定)"

### 测试 4：无父节点情况
1. 创建一个单独的 JuicyAudioPlayer 节点（不是任何节点的子节点）
2. 选择这个节点
3. 查看 Inspector

**预期结果：**
- 显示 "父节点: 无"
- 显示 "目标节点: 未设置"
- 点击 "🔄 设置为父节点" 按钮时，控制台显示警告

### 测试 5：有 AudioComponent 的情况
1. 在 Player 下创建 JuicyAudioPlayer
2. 创建一个 AudioComponent 资源（如果还没有）
3. 添加几个 AudioBinding 到组件
4. 将 AudioComponent 分配给 JuicyAudioPlayer
5. 查看 Inspector

**预期结果：**
- 显示正确的绑定数量
- 所有其他功能正常工作

## 测试完成后检查清单
- [ ] 父节点信息正确显示
- [ ] 目标节点信息正确显示（包括显式和默认状态）
- [ ] "设置为父节点" 按钮功能正常
- [ ] 点击按钮后 target 属性被正确设置
- [ ] 目标节点标签实时更新
- [ ] 测试按钮仍然正常工作
- [ ] 所有标签对齐正确（使用 HORIZONTAL_ALIGNMENT_LEFT）
- [ ] 按钮布局正确（使用 HBoxContainer）

## 手动测试命令行
如果需要在命令行中启动 Godot 编辑器进行测试：

```bash
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --path "E:\Godot\GodotProjects\project-juicy-godot" --editor
```

## 预期文件修改
- `addons/juicy_mixer/editor/juicy_audio_player_inspector.gd` - 已修改
  - 添加了目标节点标签显示
  - 添加了 "设置为父节点" 按钮
  - 添加了 `_on_set_parent_as_target()` 回调方法
  - 改进了 UI 布局（使用 HBoxContainer）

## 提交检查
完成测试后，提交信息应为：

```
feat(audio): 在 Inspector 添加目标节点管理功能

- 显示当前目标节点（显式或默认父节点）
- 添加"设置为父节点"快速操作按钮
- 改进状态面板 UI，显示更多信息
- 支持快速配置目标节点

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```
