# 动画播放测试说明

## 测试场景

本测试使用 `third_party_resources/TestChar.tscn` 中的3D角色模型，该场景包含：
- 一个带有骨骼动画的Chibi女孩模型
- AnimationPlayer组件，包含两个动画：
  - `Chibi-Girl_Base_CombatIdle02` (1.6秒) - 待机动画
  - `Chibi-Girl_Base_Combat_Combo00_0` (1.07秒) - 攻击连击动画

## 测试文件

### 1. 测试场景
- **文件**: `test_animation_play_scene.tscn`
- **描述**: 包含测试角色、摄像机和测试运行器的完整场景
- **用法**: 直接在Godot中打开此场景并运行

### 2. 测试运行器
- **文件**: `test_animation_play_runner.gd`
- **描述**: 自动执行所有测试用例的脚本
- **功能**: 
  - 验证AnimationPlayData的创建和属性设置
  - 测试JuicyAnimationPlayResource的创建和配置
  - 验证JuicyAnimationPlayDriver的基本功能
  - 实际播放测试（需要JuicyMixer系统）
  - 不同播放模式（NORMAL和SYNC）的测试

## 测试用例

### 测试1: AnimationPlayData创建
- ✅ 验证基本属性设置（目标路径、动画名称、播放模式等）
- ✅ 测试验证方法
- ✅ 测试描述方法
- ✅ 验证动画播放器获取
- ✅ 验证动画列表获取

### 测试2: JuicyAnimationPlayResource创建
- ✅ 验证资源属性（循环、延迟等）
- ✅ 测试动画数据管理
- ✅ 验证资源配置
- ✅ 测试驱动器创建

### 测试3: JuicyAnimationPlayDriver创建
- ✅ 验证驱动器名称
- ✅ 验证支持的属性列表

### 测试4: 实际动画播放
- ⚠️ 需要完整的JuicyMixer系统集成
- 测试实际的动画播放功能
- 验证播放状态和停止功能

### 测试5: 不同播放模式
- ⚠️ 需要完整的JuicyMixer系统集成
- 测试NORMAL模式播放
- 测试SYNC模式播放

## 运行测试

1. **在Godot编辑器中运行**:
   - 打开 `test_animation_play_scene.tscn`
   - 点击运行按钮
   - 查看输出窗口的测试结果

2. **命令行运行**（如果支持）:
   ```bash
   godot --path your/project/path addons/juicy_mixer/tests/test_animation_play_scene.tscn
   ```

## 测试结果解读

- ✅ **通过**: 测试成功完成，功能正常
- ❌ **失败**: 测试失败，需要检查错误信息
- ⚠️ **警告**: 测试部分成功，可能有非关键问题

## 故障排除

### JuicyMixer不可用
如果测试显示"JuicyMixer不可用"，请检查：
1. JuicyMixer插件是否已启用
2. 必要的类文件是否存在：
   - `JuicyMixer`
   - `JuicyAnimationPlayResource`
   - `JuicyAnimationPlayDriver`

### 动画播放失败
1. 检查TestChar场景是否正确加载
2. 验证AnimationPlayer是否包含预期的动画
3. 检查JuicyMixer系统是否完全初始化

### 场景加载问题
1. 确保 `third_party_resources/TestChar.tscn` 存在
2. 检查场景文件路径是否正确
3. 验证所有依赖资源是否可用

## 扩展测试

要添加新的测试用例，可以：

1. 在 `test_animation_play_runner.gd` 中添加新的测试函数
2. 在 `start_tests()` 函数中调用新的测试函数
3. 遵循现有的测试模式：设置 → 执行 → 验证 → 记录结果

## 注意事项

- 测试会自动清理创建的资源和状态
- 测试运行时间约为5-10秒（包含等待时间）
- 建议在干净的Godot项目中运行测试
- 测试结果会显示在输出窗口中