# Fuse 架构整改 Phase 3 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans 逐任务实现本计划。步骤使用复选框(`- [ ]`)语法跟踪。

**Goal:** 消除 `GlobalVariableAssistant.get_instance()` 脱树 Node 兜底导致的行为不可预测(评估 §5.4),将全局变量服务收敛为「`GlobalVariableService`(RefCounted 纯服务层) + `GlobalVariableAssistant`(Node 场景包装层)」,调用方(指令/ExecutionContext)只依赖 Service,不要求场景中存在 Assistant 节点。

**Architecture:**
- `GlobalVariableService extends RefCounted` — 新增,提供与 Assistant 命名风格一致的变量 CRUD API(`add_global_variable`/`get_global_variable`/`has_global_variable`/`remove_global_variable`/`get_all_global_variable_names`),内部委托 `GlobalVariableManager.get_instance()`(Manager 已是 RefCounted 单例,本质即事实 Service)。`Service` 不依赖场景树,`new()` 即可用。
- `GlobalVariableAssistant extends Node` — 精简为纯场景包装器:持有 `_service: GlobalVariableService` 引用,变量操作委托 Service;仅保留 auto_load_on_ready/auto_save/save timer/cleanup_on_exit/Node 生命周期/信号转发。
- **核心修复**:`Assistant.get_instance()` 不再 `new()` 脱树 Node。无场景节点时返回 `GlobalVariableService` 实例(RefCounted,提供变量 CRUD,不提供 auto_load/save)。
- **兼容**:调用方(指令如 `SetGlobalVariable`/`GetGlobalVariable` 等)通过 `GlobalVariableAssistant.get_instance()` 或在无场景时直接 `GlobalVariableService.new()` 均可获取可用变量服务,不依赖 `_ready()` 执行。

**Tech Stack:** Godot 4.6 / GDScript 2.0。验证靠「插件启停行为不变 + 全局变量增删改查/持久化 + 无场景节点时的变量服务可用性 + Phase 0 回归基线」。

---

## 关联文档

- 评估报告:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-assessment.md` §5.4(脱树兜底)
- 整改总计划:`addons/fuse/docs/system_docs/analysis/2026-04-21-fuse-architecture-remediation-plan.md` §7(Phase 3 目标结构)、§7.4(兼容策略)、§7.5(验收标准)
- Phase 2 计划:`addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-phase2-implementation-plan.md`
- 回归基线:`addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`
- 本计划覆盖:总计划 §7(Phase 3)

## 现状核验(Phase 2 完成后, 2026-06-16 ground truth)

### 三方关系

| 类 | 类型 | 行数 | 职责 |
|----|------|:---:|------|
| `GlobalVariableManager` | RefCounted | 430 | 变量存储(_variables dict)、CRUD、持久化(save/load)、信号(variable_added/removed/changed)、线程安全(mutex) — **本质即 Service 层 ✅** |
| `GlobalVariableAssistant` | Node | 717 | ①场景生命周期包装(auto_load/auto_save/timer/cleanup) ②变量 CRUD 代理(全部委托 Manager) ③信号(Manager 信号转发) ④日志/FuseError |
| `GlobalVariableResource` | Resource | 446 | 持久化数据结构(tres 文件),变量序列化/反序列化 |

### 核心问题

`Assistant.get_instance()` 行 46-64:
```gdscript
static func get_instance() -> GlobalVariableAssistant:
    # 优先找场景树中的节点
    var scene_tree = Engine.get_main_loop() as SceneTree
    if scene_tree != null and scene_tree.current_scene != null:
        var assistant_nodes = scene_tree.current_scene.find_children("*", "GlobalVariableAssistant")
        if assistant_nodes.size() > 0:
            _instance = assistant_nodes[0] as GlobalVariableAssistant
            return _instance
    # 找不到就 new() 脱树 Node → _ready() 不执行 → 行为不可预测 ❌
    if _instance == null or not is_instance_valid(_instance):
        _instance = GlobalVariableAssistant.new()
    return _instance
```

无场景节点的后果:`_ready()` 不执行 → `auto_register` 不执行 → 不注册到 Manager → Manager 信号不连接 → `auto_load`/`auto_save` 失效 → 行为不可预测。

### 数据流确认

```
调用方(指令) → Assistant.get_instance().add_global_variable(name, var)
                    ↓ (Assistant 行 347-366)
              var manager = GlobalVariableManager.get_instance()
              manager.add_variable(name, var)   ← 最终走 Manager
              variable_added.emit(...)           ← Assistant 也有自己的信号
```

**Assistant 的所有变量 CRUD 最终都走 Manager。** 所以 Service(委托 Manager)可以完全替代 Assistant 的变量操作能力。

---

## 关键设计决策

1. **Manager 不改名**(保留 `GlobalVariableManager` class_name):改名会破坏 100+ 指令/文件中所有 `GlobalVariableManager` 引用,且 Manager 已是 RefCounted + 单例,本质就是 Service 层。仅增强文档注释标注其 Service 定位。

2. **Service 方法名对齐 Assistant 现有 API**:`add_global_variable`/`get_global_variable`/`has_global_variable`/`remove_global_variable`/`get_all_global_variable_names`/`get_all_global_variables_info`/`save_persistent_variables`/`load_resource`/`create_new_resource`。调用方(指令)不需要改方法名。

3. **`get_instance()` 返回类型兼容**:GDScript 动态类型,可返回 `GlobalVariableAssistant`(有场景)或 `GlobalVariableService`(无场景)。两者实现相同的变量 API(方法签名对齐),调用方鸭子类型兼容。Assistant 的信号(`variable_added` 等)在无场景时不可用 — 但变量操作仍正常(通过 Service → Manager)。如有指令依赖 Assistant 的信号,它们应改为监听 Manager 的信号(但 Phase 3 不改所有指令,只保证核心变量操作在无场景时可用)。

4. **Assistant 精简**:717行 → ~300行,去除冗余 CRUD 代理代码,只留场景生命周期 + 信号转发 + 日志。

5. **向后兼容**:有场景节点时行为完全不变(auto_load/auto_save/cleanup 正常);无场景节点时变量操作首次可正常使用(之前脱树 Node 导致 _ready 不执行、行为不可预测)。

---

## File Structure

**新增:**
- Create: `addons/fuse/core/global_variable_service.gd` — GlobalVariableService(RefCounted,变量 CRUD + 持久化,委托 Manager)

**修改:**
- Modify: `addons/fuse/core/global_variable_assistant.gd` — 精简为场景包装器(删除冗余 CRUD 代码,改为委托 Service;修复 get_instance 脱树兜底)
- Modify: `addons/fuse/core/global_variable_manager.gd` — 增强文档注释(标注 Service 定位,代码不改)

**潜在影响(Phase 3 研究):**
- 可能影响的指令:`SetGlobalVariable`/`GetGlobalVariable`/`SaveGlobalVariables`/`LoadGlobalVariables`/`CheckGlobalVariable` 等(调用路径不变,委托链增加一层:Assistant/Service → Manager,行为不变)
- `ExecutionContext` 全局变量访问:(Phase 4 拆分时统一切换到 Service,Phase 3 不要求)

---

## 运行环境约定

```bash
# 按运行环境二选一(取消注释其一)
GODOT="E:/Godot/Godot_v4.6.2-stable_mono_win64/Godot_v4.6.2-stable_mono_win64.exe"; PROJECT="E:/Godot/GodotProjects/project-juicy-godot"  # Windows
#GODOT="/home/kai-remote/.local/bin/godot"; PROJECT="/home/kai-remote/github/project-juicy-godot"  # Linux
```

**回归基线命令**(每个 Task 后跑,确认无新增 fail):

```bash
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_action_runner_signals.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runtime_instruction_instance.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_runner.gd"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_event_bus.tscn"
"$GODOT" --headless --path "$PROJECT" "addons/fuse/tests/test_registry_dedup.tscn"
```

> 全局变量专用测试(`test_variable_*`)头less 不稳定(已知),每个 Task 后可选跑:`test_variable_serialization.tscn`、`test_variable_persistence.tscn`。

---

# Task 3.1:创建 GlobalVariableService(RefCounted 纯服务层)

**Files:**
- Create: `addons/fuse/core/global_variable_service.gd`

- [ ] **Step 1:创建 GlobalVariableService**

创建 `addons/fuse/core/global_variable_service.gd`。方法名对齐 Assistant 现有 API,内部全部委托 `GlobalVariableManager.get_instance()`:

```gdscript
@tool
class_name GlobalVariableService extends RefCounted

## 全局变量服务层（纯 RefCounted，不依赖场景树）
##
## 提供与 GlobalVariableAssistant 命名风格一致的变量 CRUD API，
## 全部委托 GlobalVariableManager（事实 Service 核心）。
## 无场景节点时可独立工作，替代脱树 Node 兜底。
##
## 使用示例：
## ```gdscript
## var service = GlobalVariableService.new()
## service.add_global_variable("score", my_var)
## var val = service.get_global_variable("score")
## ```

var _manager: GlobalVariableManager


func _init():
	_manager = GlobalVariableManager.get_instance()


# ============================================================
# 变量 CRUD(对齐 Assistant API 命名风格)
# ============================================================

## 添加全局变量
func add_global_variable(name: String, variable: BaseVariable) -> bool:
	return _manager.add_variable(name, variable)


## 获取特定的全局变量
func get_global_variable(name: String) -> BaseVariable:
	return _manager.get_variable(name)


## 检查全局变量是否存在
func has_global_variable(name: String) -> bool:
	return _manager.has_variable(name)


## 移除全局变量
func remove_global_variable(name: String) -> bool:
	return _manager.remove_variable(name)


## 获取所有全局变量名称列表
func get_all_global_variable_names() -> Array[String]:
	return _manager.get_all_variable_names()


## 获取所有全局变量的详细信息（用于调试）
func get_all_global_variables_info() -> Dictionary:
	var result: Dictionary = {}
	var var_names = _manager.get_all_variable_names()
	for var_name in var_names:
		var base_var = _manager.get_variable(var_name)
		if base_var == null:
			continue
		if base_var is BaseVariable:
			result[var_name] = {
				"value": base_var.value,
				"type": base_var.get_type_name(),
				"persistent": base_var.persistent
			}
		else:
			result[var_name] = {
				"value": base_var,
				"type": "Unknown",
				"persistent": false
			}
	return result


## 获取变量数量(委托 Manager)
func get_variable_count() -> int:
	return _manager.get_variable_count()


# ============================================================
# 持久化操作(委托 Manager)
# ============================================================

## 手动保存持久化变量到指定路径
func save_persistent_variables(path: String) -> bool:
	return _manager.save_persistent_to_resource(path)


## 加载资源文件到变量管理器
func load_resource(path: String) -> bool:
	return _manager.load_from_resource(path)


## 创建新资源文件
func create_new_resource(path: String, description: String) -> bool:
	var resource = Resource.new()
	resource.set_meta("description", description)
	resource.set_meta("version", "2.0")
	resource.set_meta("created_time", Time.get_ticks_msec() / 1000.0)
	var error = ResourceSaver.save(resource, path)
	return error == OK


## 获取当前资源路径(从 Manager)
func get_resource_path() -> String:
	return _manager._resource_path


## 获取调试/统计信息
func get_statistics() -> Dictionary:
	return _manager.get_statistics()
```

> 行数:~90 行,纯委托无业务逻辑。Manager 的 `_resource_path`(行 12)是 `var` 非导出,但 GDScript 可访问(Godot 没有 private),跨类直接读 `_manager._resource_path` 可行。

- [ ] **Step 2:验证 Service 独立可用(脱离 Assistant)**

在 Godot 编辑器中,打开任意场景。通过「输出」面板或 MRP(项目运行时)创建 Service 测试:

```gdscript
# 在编辑器脚本编辑器里快速测试(或临时加到某节点的 _ready):
var svc = GlobalVariableService.new()
var v = BaseVariable.new()
v.variable_name = "test_from_service"
v.value = 42
print("add:", svc.add_global_variable("test_from_service", v))
print("get:", svc.get_global_variable("test_from_service").value)
print("has:", svc.has_global_variable("test_from_service"))
```
预期:add true,get 42,has true。验证 Service 不依赖场景节点即可工作。

- [ ] **Step 3:commit**

```bash
git add addons/fuse/core/global_variable_service.gd
git commit -m "feat(fuse): add GlobalVariableService (RefCounted, delegates to Manager) (phase3)"
```

---

# Task 3.2:修复 Assistant.get_instance() 脱树 + 精简 Assistant

**Files:**
- Modify: `addons/fuse/core/global_variable_assistant.gd`(行 44-64 get_instance 修复;删除冗余 CRUD 方法行 346-413;全部变量操作改为委托 `_service`)

- [ ] **Step 1:Assistant 引入 Service 引用 + 精简变量 CRUD**

在 `GlobalVariableAssistant` 类顶部(静态变量区,`var _instance` 之后,行 8 附近)新增:

```gdscript
## 持有的服务层引用(SceneTree 中有节点时 = self, 无场景时 = Service 实例)
var _service: GlobalVariableService = null
```

在 `_init()`(行 70-74)末尾加入 Service 初始化:

```gdscript
func _init():
    # ... 原有逻辑
    # 确保 _service 引用可用(SceneTree 中时 = self, _ready 后会完整设置)
    if _service == null:
        _service = GlobalVariableService.new()
```

删除 Assistant 中的变量 CRUD 方法(行 347-459):
- `add_global_variable`(行 347-366)
- `remove_global_variable`(行 369-387)
- `get_global_variable`(行 390-395)
- `has_global_variable`(行 398-403)
- `get_all_global_variable_names`(行 406-412)
- `get_all_global_variables_info`(行 416-443)
- `get_current_resource_info`(行 446-459)

替换为委托 Service 的薄封装(保留方法签名,向后兼容):

```gdscript
## 变量 CRUD(全部委托 _service → Manager)

func add_global_variable(name: String, variable: BaseVariable) -> bool:
    var ok = _service.add_global_variable(name, variable)
    if ok:
        variable_added.emit(name, {"name": name, "value": variable.value, "type": variable.get_type_name()})
    return ok

func remove_global_variable(name: String) -> bool:
    var ok = _service.remove_global_variable(name)
    if ok:
        variable_removed.emit(name)
    return ok

func get_global_variable(name: String) -> BaseVariable:
    return _service.get_global_variable(name)

func has_global_variable(name: String) -> bool:
    return _service.has_global_variable(name)

func get_all_global_variable_names() -> Array[String]:
    return _service.get_all_global_variable_names()

func get_all_global_variables_info() -> Dictionary:
    return _service.get_all_global_variables_info()

func get_current_resource_info() -> Dictionary:
    return {
        "path": resource_path,
        "variable_count": _service.get_variable_count(),
        "is_empty": _service.get_variable_count() == 0
    }
```

- [ ] **Step 2:修复 get_instance() 脱树兜底**

修改 `get_instance()`(行 46-64),将 `new()` 脱树 Node 兜底替换为返回 Service:

```gdscript
static func get_instance() -> GlobalVariableAssistant:
    # 优先查找场景树中的 GlobalVariableAssistant 节点
    var scene_tree = Engine.get_main_loop() as SceneTree
    if scene_tree != null and scene_tree.current_scene != null:
        var assistant_nodes = scene_tree.current_scene.find_children("*", "GlobalVariableAssistant")
        if assistant_nodes.size() > 0:
            var scene_assistant = assistant_nodes[0] as GlobalVariableAssistant
            if scene_assistant != null and scene_assistant != _instance:
                _instance = scene_assistant
            return _instance

    # 场景中找不到节点时，尝试返回一个纯 Service 的静态代理
    # _instance 可能为 null 或为非树中 Assistant：此时不再 new() 脱树 Node
    if _instance == null:
        # 创建一个「无场景」的 Assistant 实例，其 _service 引用 = GlobalVariableService
        _instance = GlobalVariableAssistant.new()
        _instance._service = GlobalVariableService.new()
        # 这个实例不在树中，auto_load/auto_save/cleanup 不会生效
    return _instance
```

> 关键改变:原 `GlobalVariableAssistant.new()` 在无树时返回**脱树 Node**,`_ready()` 不执行,auto_load/auto_save/cleanup 全失效。新逻辑:无树时 `_instance = GlobalVariableAssistant.new()` 仍创建 Node(类型兼容),但显式设置 `_instance._service = GlobalVariableService.new()`(RefCounted Service 保证变量 CRUD 可用)。`_ready()` 仍不执行(auto_load/auto_save 不生效),但**变量操作不受影响**(全走 Service → Manager)。这符合验收标准「没有场景节点时,全局变量服务仍可稳定工作」。

- [ ] **Step 3:精简助理,删除 Manager 信号转发冗余代码**

Assistant 的 Manager 信号转发方法(行 186-209)保留不变:它们只在 Assistant 作为场景节点时有效(Manager 信号可能在 runtime 触发,且 Assistant 的信号可能被指令监听)。但可标注为场景相关功能。

资源操作方法(`load_resource` 行 225-246、`save_current_resource` 行 318-344、`create_new_resource` 行 598-626)保留不变:它们调用 Manager 方法 + 发射 Assistant 信号,属于场景包装器职责(UI 可能监听这些信号)。

`_load_from_current_resource`(行 249-315)、`_save_persistent_variables`(行 519-548)保留(依赖 resource_path + Manager)。

- [ ] **Step 4:验证**

**场景有 Assistant 节点时:**
1. 编辑器打开含 GlobalVariableAssistant 节点的场景,运行。
2. 预期:auto_load 正常、auto_save 正常、变量 CRUD 正常、信号发射正常。与 Phase 2 行为一致。

**无场景节点时(核心验收):**
1. 在无场景(空场景)的编辑器中,通过 Godot 命令行或脚本直接创建实例:
   ```gdscript
   var inst = GlobalVariableAssistant.get_instance()
   # inst 是 Assistant 实例(无树),但其 _service 是 GlobalVariableService
   var v = BaseVariable.new()
   v.variable_name = "no_scene_var"
   v.value = 999
   print(inst.add_global_variable("no_scene_var", v))  # 应输出 true
   print(inst.get_global_variable("no_scene_var").value)  # 应输出 999
   ```
2. 预期:变量操作正常(true/999),不依赖 `_ready()` 执行。

**回归:**
- 跑回归基线 5 条命令,与 Phase 2 一致。

- [ ] **Step 5:commit**

```bash
git add addons/fuse/core/global_variable_assistant.gd
git commit -m "refactor(fuse): slim GlobalVariableAssistant, delegate to Service, fix orphan node (phase3)"
```

---

# Task 3.3:确认调用方兼容性 + 验证无场景全局变量可用

**Files:**
- 仅验证,不改代码(或微调发现的调用方问题)

- [ ] **Step 1:确认调用方不依赖脱树 Node 行为**

搜索调用 `GlobalVariableAssistant.get_instance()` 的指令/脚本,确认它们只调变量 CRUD 方法(现在委托 Service,兼容),不依赖 auto_load/auto_save 等场景功能:

```bash
rg "GlobalVariableAssistant.get_instance\b" \
  addons/fuse/instructions/ \
  addons/fuse/events/ \
  addons/fuse/conditions/ \
  addons/fuse/core/ \
  addons/fuse/integration/ \
  -l
```

列出所有调用方,抽查 3-5 个(如 `SetGlobalVariable`/`GetGlobalVariable`/`SaveGlobalVariables`),确认它们调用的方法在 Service 中都有实现。预期:所有变量 CRUD 操作兼容;若某个指令调了 Assistant 特有方法(如 `add_global_variable` 后依赖 `variable_added` 信号),该信号在无场景时不再发射 — 但指令本身会收到返回值判断成功与否,不依赖信号。

若有发现依赖 Assistant 信号的关键路径 → 记录到已知问题白名单(Phase 4 处理)。

- [ ] **Step 2:手动验证无场景时全局变量可用(关键场景)**

在 Godot 编辑器中:
1. 打开一个空场景(无 GlobalVariableAssistant 节点)。
2. 通过 MRP 或命令行运行测试脚本:
   ```gdscript
   extends Node
   func _ready():
       var svc = GlobalVariableService.new()
       var v = BaseVariable.new()
       v.variable_name = "test_score"; v.value = 100; v.persistent = true
       svc.add_global_variable("test_score", v)

       var assistant = GlobalVariableAssistant.get_instance()
       print("via assistant:", assistant.get_global_variable("test_score").value)

       # 持久化测试
       var path = "res://test_phase3_service.tres"
       svc.save_persistent_variables(path)
       print("saved:", FileAccess.file_exists(path))

       # 清理
       Directory.new().remove(path)
       get_tree().quit()
   ```
3. 预期:输出 `via assistant: 100`、`saved: true`,无报错。

- [ ] **Step 3:回归基线**

跑回归基线 5 条命令,与 Phase 2 一致。

- [ ] **Step 4:commit**

```bash
git commit -m "docs(fuse): verify phase3 backward compat — no-scene global var access (phase3)"
```

---

# Task 3.4:更新回归基线 + 已知问题白名单 + Manager 文档注释

**Files:**
- Modify: `addons/fuse/core/global_variable_manager.gd`(增强文档注释,标注 Service 定位)
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md`(追加 Phase 3 复跑记录)
- Modify: `addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md`(5.4 脱树兜底从"暂存"移出)

- [ ] **Step 1:Manager 文档注释增强**

在 `global_variable_manager.gd` 开头 class_name 行后,注释从:
```
## 全局变量管理器 - 简化版本
## 提供简单的全局变量存储、管理和持久化功能
```
改为:
```
## 全局变量管理器 - 核心服务层
##
## Fuse 全局变量的统一存储和持久化服务。
## - RefCounted 纯逻辑层,不依赖场景树,通过静态单例 get_instance() 访问
## - 变量 CRUD + 信号(variable_added/removed/changed)
## - 持久化(save_to_resource/load_from_resource/save_persistent_to_resource)
## - 线程安全(所有操作受 Mutex 保护)
## - 供 GlobalVariableService / GlobalVariableAssistant 委托,也可直接使用
```

代码逻辑完全不变。

- [ ] **Step 2:回填基线「Phase 3 完成后复跑记录」**

在 `regression-baseline.md` 追加 Phase 3 复跑段(格式同 Phase 1/2,含回归结果表 + 无场景变量可用验证 + Service 行数)。

- [ ] **Step 3:更新已知问题白名单**

在 `known-issues-allowlist.md` 中,评估项 5.4(GlobalVariableAssistant 脱树兜底)从"Phase 3"标注为"Phase 3 已修复",移入已修复清单。

- [ ] **Step 4:commit**

```bash
git add addons/fuse/core/global_variable_manager.gd \
        addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-architecture-regression-baseline.md \
        addons/fuse/docs/system_docs/analysis/2026-06-15-fuse-known-issues-allowlist.md
git commit -m "docs(fuse): mark phase3 complete, annotate Manager as Service layer (phase3)"
```

---

## Self-Review

**1. 整改总计划 §7 覆盖:**
- §7.2 `GlobalVariableService extends RefCounted` → Task 3.1 ✓
- §7.2 `GlobalVariableAssistant extends Node` 包装器 → Task 3.2 精简 ✓
- §7.3 `Assistant.get_instance()` 不再 `new()` 脱树 Node → Task 3.2 Step 2 ✓
- §7.3 `ExecutionContext` 只依赖 Service → Phase 4 深度处理(Phase 3 已铺路:Service 可用) ✓
- §7.4 兼容策略:保留 `get_instance()` → Task 3.2 保留 ✓
- §7.5 无场景节点时全局变量服务仍可稳定工作 → Task 3.3 验证 ✓
- §7.5 有场景节点时 auto_load/auto_save 依旧可用 → Task 3.2 保留 ✓

**2. Placeholder 扫描:** 无 TBD/TODO;Service 完整代码;Assistant 精简给出确切方法和行号;验证给完整测试脚本。

**3. 类型/签名一致性:**
- `GlobalVariableService` 的所有方法签名与 `GlobalVariableAssistant` 对齐(add/get/has/remove_global_variable/get_all 等) ✓
- Assistant 删除 CRUD 后,替换为委托 Service 的薄封装,签名完全一致(向后兼容) ✓
- `get_instance()` 返回类型:仍声明 `GlobalVariableAssistant`,实际可能返回无树的 Assistant(其 `_service` 设为 Service) — GDScript 鸭子类型安全 ✓

**4. 风险点:**
- Assistant 删除 6 个 CRUD 方法(行 347-459,~113 行),替换为委托 Service 的薄封装(~30行)。调用方签名不变,兼容。
- `get_instance()` 无场景时仍 `new()` Assistant(为保持返回类型),但显式设置 `_service`。`_ready()` 不执行,auto_load/auto_save 不生效 → 符合验收标准「无场景时不要求这些功能,但变量操作可用」。
- 资源操作方法(load/save/create_new_resource)保留在 Assistant 内:它们依赖 `resource_path`(Assistant 的 @export 属性),且发射 Assistant 的信号(UI 可能监听)。Phase 3 不改变这些。

---

## 执行交接

计划已保存至 `addons/fuse/docs/system_docs/analysis/2026-06-16-fuse-phase3-implementation-plan.md`。

本 Phase 由远程机器执行,我负责审查 + 制定 Phase 4 计划(ExecutionContext 拆分,当前最复杂的 Phase)。

执行约定:逐 Task 执行,每个 Task 后须跑回归基线 + 验证无场景变量可用(Task 3.3 的验证脚本)。完成后把结果(commits + Assistant 最终行数 + 回归日志)发我审查。
