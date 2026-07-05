# NodeCanvas 反射调用与类管理系统

NodeCanvas 提供了一套完整的反射调用系统，让你在可视化图中通过类型反射调用任意类的方法或设置参数。本文档分析该系统的架构构成、各层职责以及数据流。

## 概览

整个系统由 5 个层次协同工作：

1. **类型发现与管理** — 自动扫描程序集 + 用户维护首选类型列表
2. **序列化层** — 将 .NET 反射对象（MethodInfo、FieldInfo 等）序列化为字符串
3. **反射包装器** — 将 MethodInfo 包装为可执行的强类型委托
4. **编辑器选择菜单** — 提供类型/方法/字段的浏览与选择 UI
5. **Task 集成** — 反射包装器被 NodeCanvas 的 Task 节点消费

## 第一层：类型发现与管理

### 自动发现

系统**不要求用户主动注册类**。启动时通过 .NET 反射自动扫描当前 AppDomain 中所有程序集的全部导出类型：

```csharp
// ReflectionTools.GetAllTypes()
var assemblies = AppDomain.CurrentDomain.GetAssemblies();
foreach (var asm in assemblies) {
    result.AddRange(asm.GetExportedTypes());
}
```

### 首选类型列表 (Preferred Types)

由于自动发现的结果可能包含数千个类型，NodeCanvas 维护了一个"首选类型列表"作为快捷方式，让用户只需从常用类型中选择。

**核心文件：**

| 文件 | 职责 |
|------|------|
| `TypePrefs.cs` | 存储和检索首选类型列表 |
| `TypePrefsEditorWindow.cs` | 编辑器窗口 UI |
| `EditorUtils.ScriptInfos.cs` | 聚合类型的元信息（名称、命名空间、分类） |

**存储位置（优先级从高到低）：**

1. 项目文件 `Editor Default Resources/PreferredTypes.typePrefs`（JSON 格式，可版本控制）
2. Unity `EditorPrefs`（本地独享）

**默认包含的类型：**

- 基础类型：`object`、`Type`、`string`、`float`、`int`、`bool`
- Unity 数学类型：`Vector2`、`Vector3`、`Vector4`、`Quaternion`、`Color`
- Unity 功能类：`Debug`、`Application`、`Mathf`、`Physics`
- Unity 对象：`GameObject`、`Transform`、`Component`

### TypePrefsEditorWindow 功能

编辑器窗口（菜单路径：ParadoxNotion > Preferences > Type Preferences）提供以下操作：

- **Add New Type** — 弹出按命名空间分类的类型选择菜单
- **拖放添加** — 支持拖入 MonoScript 文件或 Unity 对象，自动提取类型
- **Whole Namespaces** — 一键添加指定命名空间下的所有类型
- **预设保存/加载** — 导入导出首选类型配置
- **重置默认值**
- **AOT 生成** — 为 iOS/WebGL 等 AOT 平台生成 `AOTClasses.cs` 和 `link.xml`

## 第二层：序列化层

Unity 无法直接序列化 .NET 反射对象（`MethodInfo`、`FieldInfo`、`Type`），因此系统用字符串来持久化这些引用。

### 核心文件

| 文件 | 序列化对象 |
|------|-----------|
| `SerializedTypeInfo.cs` | `Type` |
| `SerializedMethodInfo.cs` | `MethodInfo` |
| `SerializedFieldInfo.cs` | `FieldInfo` |
| `SerializedConstructorInfo.cs` | `ConstructorInfo` |
| `SerializedEventInfo.cs` | `EventInfo` |
| `ISerializedReflectedInfo.cs` | 统一接口 |
| `ISerializedMethodBaseInfo.cs` | 方法和构造器的统一接口 |

### SerializedMethodInfo 格式

```
基本信息：声明类型全名 | 方法名 | 返回类型全名
参数列表：参数类型1 | 参数类型2 | ...
泛型参数：泛型参数1 | 泛型参数2 | ...
```

运行时通过 `ReflectionTools.GetType(string)` 解析字符串还原为真正的 `MethodInfo`，支持泛型类型、嵌套类型和程序集迁移等容错处理。

## 第三层：反射包装器系统

反射包装器是整个系统的执行核心，将 `MethodInfo` 包装为强类型委托以实现高效调用。

### 类继承结构

```
ReflectedWrapper (抽象基类)
├── _targetMethod: SerializedMethodInfo
├── Create(MethodInfo, IBlackboard)   ← 工厂方法
├── Init(object instance)             ← 编译委托
│
├── ReflectedActionWrapper (抽象, 返回 void)
│   ├── ReflectedAction               (0 个参数)
│   ├── ReflectedAction<T1>           (1 个参数)
│   ├── ReflectedAction<T1,T2>        (2 个参数)
│   ├── ...
│   └── ReflectedAction<T1..T6>       (最多 6 个参数)
│
└── ReflectedFunctionWrapper (抽象, 有返回值)
    ├── ReflectedFunction<TResult>         (0 个参数 + 返回值)
    ├── ReflectedFunction<T1,TResult>      (1 个参数 + 返回值)
    ├── ...
    └── ReflectedFunction<T1..T6,TResult>  (最多 6 个参数 + 返回值)
```

### 核心文件

| 文件 | 内容 |
|------|------|
| `ReflectedWrapper.cs` | 基类 `ReflectedWrapper`、`ReflectedActionWrapper`、`ReflectedFunctionWrapper` |
| `ReflectedAction.cs` | 各参数数量的 Action 实现 |
| `ReflectedFunction.cs` | 各参数数量的 Function 实现 |

### 工厂方法逻辑

`ReflectedWrapper.Create()` 根据方法的返回类型和参数数量，自动选择对应的泛型包装类实例化：

```csharp
public static ReflectedWrapper Create(MethodInfo method, IBlackboard bb) {
    if (method.ReturnType == typeof(void)) {
        return ReflectedActionWrapper.Create(method, bb);
    }
    return ReflectedFunctionWrapper.Create(method, bb);
}
```

`ReflectedActionWrapper.Create()` 根据参数数量选择泛型类型（最多 6 个），通过 `Activator.CreateInstance` 实例化，并将 `BBParameter` 字段绑定到黑板。

### 执行流程

1. `Create(method, bb)` — 工厂创建正确泛型版本的包装器实例
2. `Init(instance)` — 通过 `RTCreateDelegate<ActionCall<T>>()` 将 MethodInfo 编译为强类型委托（仅执行一次，结果被缓存）
3. `Call()` — 直接调用缓存好的委托，参数值来自 `BBParameter<T>` 字段

### BBParameter 参数绑定

包装器中每个方法参数对应一个 `BBParameter<T>` 字段（`p1`、`p2`、...），支持两种取值方式：

- **直接值** — 在 Inspector 中手动填写固定值
- **黑板变量** — 绑定到 Blackboard 中的变量，运行时动态读取

## 第四层：编辑器选择菜单

### 核心文件

| 文件 | 功能 |
|------|------|
| `EditorUtils.ContextMenus.cs` | 各类右键选择菜单的生成函数 |
| `GenericMenuBrowser.cs` | 带搜索和分类浏览功能的弹出菜单 |

### 主要菜单函数

| 方法 | 用途 |
|------|------|
| `GetTypeSelectionMenu(baseType)` | 列出所有继承自 `baseType` 的类型 |
| `GetPreferedTypesSelectionMenu(baseType)` | 从首选列表中筛选与 `baseType` 兼容的类型 |
| `GetInstanceMethodSelectionMenu()` | 列出指定类型的实例方法（可选包含静态方法） |
| `GetInstanceFieldSelectionMenu()` | 列出指定类型的字段 |
| `GetPropertySelectionMenu()` | 列出指定类型的属性 |

`GetPreferedTypesSelectionMenu` 还会自动为每个首选类型生成 `List<T>` 和 `Dictionary<string,T>` 的变体选项，方便用户直接选择集合类型。

### GenericMenuBrowser

当候选项很多时，`GenericMenuBrowser` 提供以下辅助功能：

- 实时搜索过滤
- 按命名空间/分类浏览
- 收藏常用项

## 第五层：与 NodeCanvas Task 集成

反射包装器最终被 NodeCanvas 的反射类 Task 节点消费。这些 Task 在图中表现为可视化节点，用户交互流程如下：

1. 在图中添加反射节点（如 "Invoke Method" 或 "Get Property"）
2. 在节点上选择目标类型（从首选列表或全部类型中选取）
3. 选择要调用的方法或访问的字段/属性
4. 节点自动暴露对应参数端口（基于 `BBParameter`）
5. 运行时，图执行引擎调用 `wrapper.Init(target)` 接着 `wrapper.Call()`

## 完整数据流

```
[编辑器阶段 - 用户操作]
    │
    ├─ 维护首选类型
    │   └→ TypePrefs.AddType()
    │   └→ 持久化到 EditorPrefs / typePrefs 文件
    │
    └─ 创建反射节点
        ├→ 选择类型 (GetPreferedTypesSelectionMenu)
        ├→ 选择方法/字段/属性 (Get*SelectionMenu)
        ├→ ReflectedWrapper.Create(method, blackboard)
        └→ 序列化为 SerializedMethodInfo (字符串存入图资产)

[运行时阶段 - 图执行]
    │
    └→ SerializedMethodInfo → 还原为 MethodInfo
    └→ ReflectedWrapper.Init(targetInstance)
    └→ RTCreateDelegate → 编译为强类型委托 (缓存)
    └→ Call() → 从 BBParameter 取值 → 调用委托
```

## 关键设计特点

- **无注册设计** — 不需要用户代码做任何注册或声明，通过反射自动发现所有类型。首选列表仅作为快速访问的快捷方式。
- **委托缓存** — 使用 `Expression` 将 MethodInfo 编译为强类型委托，首次调用后缓存结果，避免每次执行都进行反射调用。
- **黑板参数绑定** — 所有方法参数都是 `BBParameter<T>`，既支持硬编码值也支持运行时黑板变量，与 NodeCanvas 的数据流系统天然集成。
- **最多 6 个参数** — 通过泛型特化 `ReflectedAction<T1..T6>` / `ReflectedFunction<T1..T6,TResult>` 实现，覆盖绝大多数使用场景。
- **AOT 兼容** — 通过 `[SpoofAOT]` 属性和 `AOTClassesGenerator` 解决 iOS/WebGL 等 AOT 编译平台的限制。
