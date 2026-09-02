# Changelog

All notable changes to the Fuse addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🌐 中文（本页） · [English](CHANGELOG.en.md)

## [Unreleased]

### Added
- CharacterBody2D 移动控制系统
  - OnInputActionComposite 事件：支持多方向输入监听（上/下/左/右）
  - MoveCharacterBody2DComposite 指令：支持三种移动模式（DIRECT/SMOOTH/ACCELERATION）
  - 完整的用户文档和开发者文档
  - 集成测试和示例场景
- **Stage 7: 变量监视器 V2 + 静态声明融合**
  - 7a: 双击编辑变量值（global 变量随时可写，local/scope 需场景运行；类型转换 int/float/bool/String）
  - 7b: 数值变量 60s 历史折线图（HistoryGraph 自定义 _draw，120 点 / 0.5s 采样，选中变量行显示）
  - 7c: 指令链静态变量声明注入（InstructionAnalyzer.build_topology 数据源，独立「指令引用(静态)」分区，5s 刷新节流）
  - 7d: get_snapshot() 补全 runners/local/scope 快照（抽 _collect_runtime_variables 复用 _refresh 和快照）
- **FuseRuntimeBridge TCP 变量桥**（方案 C，见本地归档 `addons/fuse/docs/archive/roadmap/2026-06-27-runtime-variable-tcp-bridge-plan.md`）
  - 双模式 Autoload：编辑器 TCPServer listen 127.0.0.1:24563，运行游戏 TCP 客户端 push JSON line
  - JSON line 协议（`\n` 分隔）：`{"t":"vars","runners":[{"name":"...","local":{...},"scope":{...}}]}`
  - TCP 读缓冲处理粘包/半包，断开连接自动清空缓存
  - 运行游戏侧 0.5s 收集 Runner 的 local/scope 变量快照推送
  - V1 只读（local/scope 编辑需反向通道，后续任务）
- **变量监视器 local/scope 运行时可见**：通过 FuseRuntimeBridge 缓存读取运行游戏实例的变量
  - replace `EditorInterface.get_edited_scene_root()` 扫 Runner → bridge `get_cached_vars()`

### Changed
- 改进输入系统架构，支持复合输入事件
- 添加 37 个新的本地化键用于移动系统（事件 9 个 + 指令 8 个 + 其他 20 个）
- `variable_watcher.gd`: 值列 Label → `_make_value_panel`（双击 LineEdit 编辑，回车/失焦提交）
- `variable_watcher.gd`: `_render_static_declarations` 分区，汇总 Trigger 指令链引用的全局/局部/作用域变量
- `variable_watcher.gd`: `get_snapshot()` 新增 runners 数组（含每个 Runner 的 local/scope 快照）
- `variable_watcher.gd`: `_collect_runtime_variables` 改读 `FuseRuntimeBridge.get_cached_vars()`（替代 EditorInterface 扫描场景 Runner，V1 local/scope context 传 null 只读）
- `variable_watcher.gd`: `_make_row_data` 新增 `runner` 字段标识变量来源
- `fuse_runtime_bootstrap.gd`: 增加 `_register_runtime_bridge()/_unregister_runtime_bridge()`，在插件启停时注册/注销 FuseRuntimeBridge Autoload
