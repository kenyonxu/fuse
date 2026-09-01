# Fuse 本地化系统测试

## 概述

本目录包含 Fuse 本地化系统的测试脚本。

## 测试文件

### 1. run_localization_tests.gd
独立运行的测试脚本，不依赖外部测试框架。

### 2. test_localization.tscn
测试场景，可以在 Godot 编辑器中直接运行。

### 3. test_fuse_localization.gd.backup
原始的 GUT 测试框架版本（保留作为参考）。

## 如何运行测试

### 方法 1：在编辑器中运行（推荐）

1. 打开 Godot 编辑器
2. 导航到 `tests/`
3. 双击 `test_localization.tscn` 打开测试场景
4. 按 F5 或点击"运行当前场景"按钮
5. 查看控制台输出

### 方法 2：从命令行运行

```bash
# Windows
"E:\Godot\Godot_v4.5.1-stable_mono_win64\Godot_v4.5.1-stable_mono_win64.exe" --path "E:\Godot\GodotProjects\project-juicy-godot" "tests/test_localization.tscn"

# Linux/Mac
godot --path /path/to/project tests/test_localization.tscn
```

## 测试覆盖

测试套件包含以下测试：

| 测试名称 | 描述 |
|---------|------|
| 加载翻译 | 验证翻译文件正确加载 |
| 中文翻译 | 验证中文翻译功能 |
| 英文翻译 | 验证英文翻译功能 |
| 参数化翻译(英文) | 验证英文参数化翻译 |
| 参数化翻译(中文) | 验证中文参数化翻译 |
| 语言切换 | 验证语言切换功能 |
| 缺失翻译回退 | 验证缺失翻译时的回退行为 |
| 语言显示名称 | 验证语言显示名称 |
| 语言代码 | 验证语言代码 |
| 翻译覆盖率 | 验证翻译完整性 |
| InstructionMetadata 本地化 | 验证元数据本地化 |
| InstructionMetadata 向后兼容 | 验证向后兼容性 |
| 多参数替换 | 验证参数替换功能 |

## 预期输出

运行测试后，您应该在控制台中看到类似以下输出：

```
============================================================
Fuse 本地化系统测试
============================================================

初始化本地化系统...
✓ 本地化系统初始化成功

翻译统计:
  总翻译键: 118
  中文翻译: 118 (100.0%)
  英文翻译: 118 (100.0%)
  当前语言: zh_CN

开始运行测试...

✓ 加载翻译
  应该加载至少一个翻译键
  总键数: 118

✓ 中文翻译
  应该翻译为中文
  期望: '打印消息' | 实际: '打印消息'

✓ 英文翻译
  应该翻译为英文
  期望: 'Print Message' | 实际: 'Print Message'

...

============================================================
测试完成
============================================================

总测试数: 13
通过: 13
失败: 0
耗时: 0.125 秒

🎉 所有测试通过！
============================================================
```

## 故障排除

### 问题：测试场景无法运行

**解决方案**：
1. 确保 Fuse 插件已启用
2. 确保所有必要的文件都存在：
   - `addons/fuse/localization/fuse_localization.gd`
   - `addons/fuse/localization/translations.csv`
   - `addons/fuse/editor/instruction_selector/instructions_metadata.gd`

### 问题：某些测试失败

**解决方案**：
1. 检查 Godot 编辑器输出面板的详细错误信息
2. 确认本地化系统正确初始化
3. 验证 translations.csv 文件格式正确
4. 尝试重新加载插件

### 问题：测试显示"缺失翻译"警告

**解决方案**：
1. 这是正常的，表明系统检测到了缺失的翻译
2. 如果所有测试都通过，可以忽略这些警告
3. 如果需要，可以在 translations.csv 中添加缺失的翻译

## 添加新测试

要添加新的测试，在 `run_localization_tests.gd` 中添加新的测试函数：

```gdscript
func test_my_new_feature():
    var test_name = "我的新功能测试"
    var FuseLocalization_class = load("res://addons/fuse/localization/fuse_localization.gd")

    # 测试逻辑
    var result = FuseLocalization_class.some_method()
    var expected = "expected_value"
    var passed = result == expected

    _record_test(test_name, passed, "测试描述", "详细信息")
```

然后在 `_run_all_tests()` 函数中调用：

```gdscript
func _run_all_tests():
    # ... 其他测试
    test_my_new_feature()
```

## 使用 GUT 测试框架（可选）

如果您想使用 GUT 测试框架：

1. 安装 GUT：从 https://github.com/bitwes/Gut 下载最新版本
2. 解压到 `addons/gut/` 目录
3. 在项目设置中启用 GUT 插件
4. 使用 `test_fuse_localization.gd.backup` 作为参考

---

**最后更新**: 2026-01-22
