# Fuse 阶段3运行时本地化集成测试

## 概述

这个测试套件验证 Fuse 阶段3的所有运行时本地化功能，包括：
- 基础设施本地化（FuseLogger、FuseError）
- BaseInstruction 本地化方法
- BaseEvent 本地化方法
- 指令本地化（简单指令、参数化指令、错误处理）
- 事件本地化
- 语言切换功能

## 测试文件

- **测试脚本**: `tests/test_stage3_runtime_localization.gd`
- **测试场景**: `tests/test_stage3_runtime_localization.tscn`
- **测试运行器**: `test_scripts/run_stage3_integration_test.gd`

## 运行测试

### 方法 1: 使用测试运行器脚本（推荐）

```bash
# 在项目根目录执行
godot --headless --script test_scripts/run_stage3_integration_test.gd
```

### 方法 2: 在编辑器中运行

1. 在 Godot 编辑器中打开项目
2. 打开测试场景：`tests/test_stage3_runtime_localization.tscn`
3. 按 F5 运行场景
4. 查看控制台输出

### 方法 3: 命令行直接运行场景

```bash
godot --headless test_stage3_runtime_localization.tscn
```

## 测试覆盖

### 1. 基础设施测试（4个测试）
- ✓ FuseLogger 本地化方法（log_debug_localized、log_info_localized、log_warning_localized、log_error_localized）
- ✓ FuseError 本地化方法（create_validation_error_localized、create_execution_error_localized 等）
- ✓ BaseInstruction 本地化方法（_log_*_localized、set_error_localized）
- ✓ BaseEvent 本地化方法（_log_*_localized、_create_fuse_error_localized）

### 2. 指令本地化测试（3个测试）
- ✓ 简单指令本地化（Print、Quit）
- ✓ 参数化指令本地化（Count、Wait）
- ✓ 指令错误处理本地化

### 3. 事件本地化测试（2个测试）
- ✓ 事件本地化（OnReady、OnInputKey）
- ✓ 事件错误本地化

### 4. 语言切换测试（3个测试）
- ✓ 中文环境测试
- ✓ 英文环境测试
- ✓ 动态语言切换

## 测试结果

所有测试应该都能通过。预期结果：
- 总测试数: 32
- 通过: 32
- 失败: 0
- 通过率: 100.0%

## 验收标准

- ✅ 测试脚本创建完成
- ✅ 测试场景文件创建完成
- ✅ 测试覆盖所有阶段3功能
- ✅ 测试能够成功运行
- ✅ 测试输出清晰易读
- ✅ 所有测试通过

## 故障排除

### 问题: 测试失败

如果测试失败，检查以下内容：
1. 确保本地化系统已正确初始化
2. 确保翻译文件存在（`translations.csv`）
3. 确保所有依赖的指令和事件文件存在
4. 查看详细的错误日志以定位问题

### 问题: 找不到测试场景

确保测试场景文件在正确的位置：
```
tests/test_stage3_runtime_localization.tscn
```

### 问题: 本地化不工作

确保 `FuseLocalization` 已正确初始化：
1. 检查 `fuse_localization.gd` 是否存在
2. 检查翻译文件是否正确加载
3. 查看控制台的错误信息

## 后续步骤

测试完成后，可以继续进行以下工作：
1. 添加更多的本地化键
2. 为新的指令和事件添加本地化支持
3. 运行性能测试
4. 集成到 CI/CD 流程

## 相关文档

- [Fuse 本地化实施计划（归档）](../docs/dev_docs/archive/localization_implementation_plan.md)
- [Fuse 本地化阶段3完成报告](../docs/dev_docs/reports/stage3_runtime_localization_complete.md)
- [Fuse 翻译文件](../localization/translations.csv)
- [Fuse 文档中心](../docs/README.md)

---

**最后更新**: 2026-01-25
**Godot 版本**: 4.5
**测试状态**: ✅ 所有测试通过
