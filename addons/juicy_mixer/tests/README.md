# Timeline系统测试套件

本目录包含了Timeline系统的完整测试套件，确保所有组件都能正常工作。

## 测试文件结构

### 核心测试文件

1. **`test_timeline_system.gd`** - Timeline核心功能测试
   - 测试JuicyTimelineResource的基本功能
   - 测试轨道的添加、删除、重排序
   - 测试时间轴配置和循环模式
   - 测试参数预设系统

2. **`test_timeline_tracks.gd`** - 轨道类型测试
   - 测试属性轨道的曲线和关键帧功能
   - 测试反馈轨道的子效果触发
   - 测试方法轨道的方法调用
   - 测试事件轨道的事件触发

3. **`test_timeline_driver.gd`** - Timeline驱动器测试
   - 测试JuicyTimelineDriver的生命周期
   - 测试时间推进和循环处理
   - 测试轨道处理逻辑
   - 测试性能和批处理

4. **`test_timeline_parameter_mapping.gd`** - 参数映射集成测试
   - 测试轨道级参数映射
   - 测试参数映射与Timeline的集成
   - 测试实时参数更新
   - 测试参数映射性能

5. **`test_timeline_editor.gd`** - 编辑器功能测试
   - 测试编辑器插件的基本功能
   - 测试时间轴画布的交互
   - 测试轨道编辑器
   - 测试属性检查器扩展

6. **`test_timeline_integration.gd`** - 集成测试和性能测试
   - 测试Timeline与JuicyMixer V3的集成
   - 测试复杂场景的执行
   - 性能基准测试
   - 内存泄漏检测

7. **`test_timeline_examples.gd`** - 示例和演示测试
   - 测试各种使用示例
   - 验证文档中的示例代码
   - 测试边界条件和异常情况

### 辅助文件

8. **`test_timeline_runner.gd`** - 测试运行器和报告系统
   - 自动化测试运行器
   - 测试覆盖率报告
   - 性能基准报告
   - 测试文档生成

9. **`test_target_methods.gd`** - 测试目标方法脚本
   - 为Timeline示例测试提供测试目标和方法
   - 包含各种游戏常用的方法

## 运行测试

### 方法1：使用测试运行器（推荐）

```gdscript
# 在场景中创建一个节点，附加以下脚本
extends Node

func _ready():
    var runner = preload("res://addons/juicy_mixer/tests/test_timeline_runner.gd").new()
    add_child(runner)
    runner.run_complete_test_suite()
```

### 方法2：运行单个测试套件

```gdscript
# 运行特定的测试套件
extends Node

func _ready():
    var test_suite = preload("res://addons/juicy_mixer/tests/test_timeline_system.gd").new()
    add_child(test_suite)
    test_suite.run_all_tests()
```

### 方法3：在编辑器中运行

1. 打开Godot编辑器
2. 创建一个新场景
3. 添加一个Node节点
4. 附加测试脚本
5. 运行场景

## 测试报告

测试运行器会自动生成以下报告：

- **HTML报告** (`reports/timeline_test_report.html`) - 可视化测试结果
- **JSON报告** (`reports/timeline_test_report.json`) - 机器可读的测试数据
- **XML报告** (`reports/timeline_test_report.xml`) - CI/CD集成格式

## 测试覆盖率

测试运行器会分析以下文件的覆盖率：

- `juicy_timeline_resource.gd`
- `juicy_timeline_driver.gd`
- `juicy_track.gd`
- `juicy_property_track.gd`
- `juicy_feedback_track.gd`
- `juicy_method_track.gd`
- `juicy_event_track.gd`
- `juicy_parameter_mapping.gd`

## 性能基准

测试运行器会运行以下性能基准测试：

1. **Timeline创建性能** - 测试创建Timeline实例的速度
2. **轨道添加性能** - 测试添加轨道到Timeline的速度
3. **Timeline播放性能** - 测试播放Timeline的CPU使用情况
4. **参数映射性能** - 测试参数映射的计算速度
5. **内存使用性能** - 测试内存分配和泄漏

## 测试覆盖范围

### 功能测试
- ✅ 所有轨道类型的基本功能
- ✅ 时间轴配置和循环
- ✅ 参数映射和实时更新
- ✅ 事件触发和方法调用
- ✅ 编辑器界面交互

### 性能测试
- ✅ 大量轨道的处理性能
- ✅ 长时间轴的执行性能
- ✅ 参数映射的性能影响
- ✅ 内存使用和GC压力

### 边界测试
- ✅ 空Timeline处理
- ✅ 极端时间值处理
- ✅ 无效配置的错误处理
- ✅ 并发访问安全性

### 集成测试
- ✅ 与现有JuicyMixer组件的兼容性
- ✅ 中间件管道的集成
- ✅ 事件系统的交互
- ✅ 池化管理的影响

## 故障排除

### 常见问题

1. **测试脚本加载失败**
   - 确保所有测试文件都在正确的路径中
   - 检查文件权限

2. **测试运行缓慢**
   - 某些性能测试可能需要较长时间
   - 可以在测试运行器中禁用特定的测试套件

3. **内存泄漏误报**
   - 确保在测试后正确清理资源
   - 多次运行测试以确认一致性

### 调试技巧

1. **启用详细日志**
   ```gdscript
   # 在测试脚本中添加
   func _ready():
       OS.set_stdout_verbose(true)
   ```

2. **单独运行失败的测试**
   - 修改测试运行器中的`test_suites`数组
   - 只启用失败的测试套件

3. **检查测试环境**
   - 确保所有依赖项都已正确加载
   - 验证测试资源的存在

## 贡献指南

### 添加新测试

1. 在相应的测试文件中添加新的测试方法
2. 遵循现有的命名约定：`test_<功能名称>`
3. 使用提供的断言函数
4. 更新测试覆盖率分析

### 性能测试

1. 在`test_timeline_integration.gd`中添加性能测试
2. 在`test_timeline_runner.gd`中添加基准测试
3. 确保测试具有可重复的结果

### 文档

1. 更新本README文件
2. 为新测试添加注释
3. 更新测试覆盖率报告

## 许可证

本测试套件遵循与JuicyMixer V3相同的许可证。