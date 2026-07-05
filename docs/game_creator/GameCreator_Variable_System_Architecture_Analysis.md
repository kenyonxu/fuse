# Game Creator 2 变量系统架构分析

## 概述

Game Creator 2 的变量系统是一个高度灵活、类型安全且可扩展的系统，它支持多种变量类型、作用域和访问模式。该系统采用了多态性设计，允许在运行时动态处理不同类型的变量，并与指令系统紧密集成。

## 核心架构

### 1. 基础类层次结构

#### 1.1 TValue - 值类型基类

[`TValue`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Values/TValue.cs:11) 是所有变量值类型的抽象基类，提供了以下核心功能：

- **类型安全**: 通过 `TypeID` 和 `Type` 属性确保类型一致性
- **值访问**: 通过 `Value` 属性提供统一的值访问接口
- **事件系统**: 通过 `EventChange` 事件监听值变化
- **类型注册**: 使用静态查找表(LUT)管理类型映射

```csharp
public abstract class TValue : TPolymorphicItem<TValue>
{
    public object Value { get; set; }
    public abstract IdString TypeID { get; }
    public abstract Type Type { get; }
    public event Action<object> EventChange;
}
```

具体实现包括：
- [`ValueBool`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Values/ValueBool.cs:12) - 布尔值
- [`ValueNumber`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Values/ValueNumber.cs:13) - 数值(double)
- [`ValueString`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Values/ValueString.cs:12) - 字符串
- [`ValueGameObject`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Values/ValueGameObject.cs) - 游戏对象
- 等等...

#### 1.2 TVariable - 变量基类

[`TVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Variables/TVariable.cs:9) 是所有变量类型的抽象基类：

```csharp
public abstract class TVariable : TPolymorphicItem<TVariable>
{
    [SerializeReference] protected TValue m_Value = new ValueNull();
    
    public object Value { get; set; }
    public IdString TypeID => this.m_Value.TypeID;
    public Type Type => this.m_Value.Type;
    public abstract TVariable Copy { get; }
}
```

主要实现：
- [`NameVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Variables/NameVariable.cs:8) - 命名变量
- [`IndexVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Variables/IndexVariable.cs:7) - 索引变量

#### 1.3 TList - 列表基类

[`TList<T>`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Lists/TList.cs:9) 提供列表变量的基础功能：

```csharp
public abstract class TList<T> : TPolymorphicList<T> where T : TVariable
{
    [SerializeReference] private List<T> m_Source = new List<T>();
    
    public T Get(int index) { return this.m_Source[index]; }
    public void Set(int index, T value) { this.m_Source[index] = value; }
    public void Add(T value) { this.m_Source.Add(value); }
}
```

主要实现：
- [`NameList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Lists/NameList.cs:7) - 命名变量列表
- [`IndexList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Lists/IndexList.cs:8) - 索引变量列表

### 2. 运行时管理系统

#### 2.1 TVariableRuntime - 运行时基类

[`TVariableRuntime<T>`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Runtimes/TVariableRuntime.cs:8) 提供运行时变量管理：

```csharp
public abstract class TVariableRuntime<T> : IEnumerable<T> where T : TVariable
{
    public abstract void OnStartup();
    public abstract IEnumerator<T> GetEnumerator();
}
```

#### 2.2 具体运行时实现

- [`ListVariableRuntime`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Runtimes/ListVariableRuntime.cs:10) - 管理索引列表变量
- [`NameVariableRuntime`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Runtimes/NameVariableRuntime.cs:9) - 管理命名变量

## 多态性实现

### 1. 字段访问系统

#### 1.1 获取字段 (Get Fields)

[`TFieldGetVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Get/TFieldGetVariable.cs:8) 是所有获取字段的抽象基类：

```csharp
public abstract class TFieldGetVariable
{
    [SerializeField] protected IdString m_TypeID = ValueNull.TYPE_ID;
    
    public T Get<T>(Args args) { /* 类型转换逻辑 */ }
    public abstract object Get(Args args);
}
```

具体实现：
- [`FieldGetGlobalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Get/FieldGetGlobalList.cs:8) - 获取全局列表变量
- [`FieldGetGlobalName`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Get/FieldGetGlobalName.cs:8) - 获取全局命名变量
- [`FieldGetLocalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Get/FieldGetLocalList.cs:8) - 获取本地列表变量

#### 1.2 设置字段 (Set Fields)

[`TFieldSetVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Set/TFieldSetVariable.cs:8) 是所有设置字段的抽象基类：

```csharp
public abstract class TFieldSetVariable
{
    [SerializeField] protected IdString m_TypeID = ValueNull.TYPE_ID;
    
    public abstract void Set(object value, Args args);
    public abstract object Get(Args args);
}
```

具体实现：
- [`FieldSetGlobalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Set/FieldSetGlobalList.cs:8) - 设置全局列表变量
- [`FieldSetGlobalName`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Set/FieldSetGlobalName.cs:8) - 设置全局命名变量
- [`FieldSetLocalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Fields/Set/FieldSetLocalList.cs:8) - 设置本地列表变量

### 2. 属性系统

#### 2.1 获取属性 (Get Properties)

属性系统通过多态性实现类型安全的变量访问。例如：

```csharp
[Serializable]
public class GetBoolGlobalList : PropertyTypeGetBool
{
    [SerializeField] protected FieldGetGlobalList m_Variable;
    
    public override bool Get(Args args) => this.m_Variable.Get<bool>(args);
}
```

类似实现包括：
- [`GetBoolGlobalName`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Properties/Get/Bool/GetBoolGlobalName.cs:14)
- [`GetStringGlobalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Properties/Get/String/GetStringGlobalList.cs)
- [`GetGameObjectGlobalList`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Polymorphism/Properties/Get/GameObject/GetGameObjectGlobalList.cs)

#### 2.2 设置属性 (Set Properties)

设置属性系统允许类型安全的变量修改：

```csharp
[Serializable]
public class SetBoolGlobalList : PropertyTypeSetBool
{
    [SerializeField] protected FieldSetGlobalList m_Variable;
    
    public override void Set(bool value, Args args) => this.m_Variable.Set(value, args);
    public override bool Get(Args args) => (bool)this.m_Variable.Get(args);
}
```

## 变量系统与指令系统集成

### 1. 指令基类

所有指令都继承自 [`Instruction`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Instruction.cs:14)：

```csharp
public abstract class Instruction : TPolymorphicItem<Instruction>
{
    protected abstract Task Run(Args args);
    public async Task<InstructionResult> Schedule(Args args, InstructionList parent)
    {
        // 执行逻辑
        if (this.IsEnabled) await this.Run(args);
        // 返回结果
    }
}
```

### 2. 变量相关指令

变量系统通过专门的指令类与指令系统集成：

#### 2.1 变量操作指令

- [`InstructionVariablesClear`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesClear.cs:21) - 清空列表变量
- [`InstructionVariablesMove`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesMove.cs:21) - 移动列表元素
- [`InstructionVariablesRemove`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesRemove.cs:20) - 移除列表元素
- [`InstructionVariablesChangeId`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesChangeId.cs:21) - 更改变量ID

#### 2.2 集成模式

变量指令通过以下模式与系统集成：

1. **收集器模式**: 使用 [`CollectorListVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Utilities/Collectors/CollectorListVariable.cs:9) 收集变量数据
2. **字段访问模式**: 通过字段类获取/设置变量值
3. **类型安全模式**: 使用泛型确保类型一致性

### 3. 收集器和检测器系统

#### 3.1 收集器 (Collectors)

[`CollectorListVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Utilities/Collectors/CollectorListVariable.cs:9) 提供统一的变量收集接口：

```csharp
public class CollectorListVariable
{
    public List<object> Get(Args args) { /* 获取列表数据 */ }
    public void Fill(object[] values, Args args) { /* 填充列表数据 */ }
    public void Clear(Args args) { /* 清空列表 */ }
}
```

#### 3.2 检测器 (Detectors)

检测器系统用于识别和定位变量：

- [`DetectorGlobalListVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Utilities/Detectors/DetectorGlobalListVariable.cs:6) - 检测全局列表变量
- [`DetectorGlobalNameVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Utilities/Detectors/DetectorGlobalNameVariable.cs) - 检测全局命名变量

## 编辑器支持

### 1. 自定义绘制器

编辑器通过自定义属性绘制器提供变量系统的可视化支持：

- [`FieldGetGlobalListDrawer`](Assets/Plugins/GameCreator/Packages/Core/Editor/Variables/Drawers/Fields/Get/FieldGetGlobalListDrawer.cs:9) - 全局列表变量获取字段绘制器

```csharp
[CustomPropertyDrawer(typeof(FieldGetGlobalList))]
public class FieldGetGlobalListDrawer : PropertyDrawer
{
    public override VisualElement CreatePropertyGUI(SerializedProperty property)
    {
        // 创建UI元素
    }
}
```

### 2. 编辑器工具

编辑器工具提供变量管理的辅助功能：
- 变量创建向导
- 变量类型转换工具
- 变量引用检查工具

## 系统特点

### 1. 类型安全

- 编译时类型检查
- 运行时类型验证
- 自动类型转换

### 2. 灵活性

- 支持多种变量类型
- 动态类型注册
- 可扩展的属性系统

### 3. 性能优化

- 静态查找表(LUT)优化类型查找
- 延迟初始化
- 事件驱动的更新机制

### 4. 序列化支持

- 完整的序列化/反序列化
- 版本兼容性
- 跨场景数据持久化

## 工作流程

1. **变量定义**: 通过编辑器或代码创建变量
2. **类型注册**: 系统自动注册变量类型
3. **运行时初始化**: 启动时初始化变量运行时
4. **访问操作**: 通过字段类进行变量访问
5. **指令执行**: 通过指令系统修改变量
6. **事件通知**: 变量变化触发事件
7. **序列化保存**: 保存变量状态

## 总结

Game Creator 2 的变量系统是一个设计精良、高度模块化的系统，它通过多态性、类型安全和事件驱动的设计模式，为游戏开发提供了强大而灵活的变量管理能力。该系统与指令系统的无缝集成，使得在视觉脚本中使用变量变得简单直观，同时保持了代码的清晰性和可维护性。