# Changelog

All notable changes to the Fuse addon will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> 🌐 中文（本页） · [English](CHANGELOG.en.md)

## [Unreleased]

## [1.1.0] - 2026-09-04

### Added
- **变量监视器运行时编辑**：运行游戏中 local/scope/global 标量变量可在监视器双击直达写回游戏进程（桥反向 `set_var` 通道；fire-and-forget + 0.5s 推送回显；JSON float 按目标类型收窄、非标量槽位闸门、短写断连自愈）
- **Trigger/MultiEventTrigger 最近执行上下文**：BaseTrigger/Runner 统一持有 `current_execution_context(_at_ms)`，三类核心组件的 local 变量对监视器可见（终值 + 新鲜度）
- **变量监视器 v3 宿主直报**（桥协议 v3）：推送按 `containers`/`units`/`global` 三块直报——ScopeVariableContainer 容器直扫（未触发子树可见声明默认值）、root 全树单遍三判收集、`scene` 当前场景名字段（场景归组）、`__complex` 非标量只读编码、恒定推送；写回按 `target` 三分发（container/unit/global）
- **变量监视器 UI 重做**：Godot 原生 Tree 三级结构（场景 → 宿主 → 变量，GLOBAL 平级根，当前/附加尾注）、增量就地更新（不闪不重建）、折叠跨刷新持久、大小写不敏感搜索、选中变量展开可拖高折线图（✕/Esc 收起）、双击编辑覆盖层精确定位值单元格、编辑器主题自适应（亮暗切换实时更新、零硬编码色）

### Changed
- 桥推送协议 v2 → v3（`runners[]` 结构退役；同一插件两侧同版本，不做跨版本兼容）；`get_cached_vars()` 返回 `{scene, containers, units}`
- `variable_watcher.gd` 789 → 约 460 行，展示层拆分至 `variable_watcher_tree.gd`（数据层纯函数与编辑分发语义不变）
- 运行时 Global 区数据源按桥连接切换（游戏侧实时快照 ↔ 编辑器侧定义）；`_write_back_global` 改值优先保留变量元数据
- 状态栏、场景尾注、空态提示接入本地化（新增 3 key）

### Removed
- 变量监视器的静态声明区（编辑期视图）与变量快照落盘功能
- CSV 退役 12 个无引用 key；scope"名+值"去重逻辑与全部自绘 UI 工厂代码

### Fixed
- 运行时写回 Object 槽位崩溃（游戏侧非标量闸门 + 容器混型安全比较）
- 共享容器变量被多个 Runner 重复显示（v3 容器直扫后根除）
- 面板早退路径返回无类型数组导致每 0.5s 刷类型错误
- 双击编辑输入框坐标系错配（viewport 坐标误赋局部位置，输入框落在面板外）

## [1.0.0] - 2026-09-03

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
- `fuse_error.gd`: 上下文输出改为剔除内部字段（message_key/message_args/component/timestamp）的 `key=value` 扁平格式，不再整包 dict str()

### Fixed
- 错误/警告日志在 Errors 面板只能看到硬编码占位（"发现错误!"）的问题：`push_error`/`push_warning` 改为携带完整结构化纯文本消息，ERROR 级附首发位置 `(at res://...:行)`（跳过 Fuse 内部帧，无调试器时省略）；info/debug 维持 `print_rich` 富文本，error/warning 不再双份输出
- `fuse_error.gd`: `create_with_context` 双份记录（`_init` 已记录后又手动补记）
- `fuse_logger.gd`: 富文本格式串把 `[/color]` 多包一层方括号的笔误（渲染残留多余 `]`）
