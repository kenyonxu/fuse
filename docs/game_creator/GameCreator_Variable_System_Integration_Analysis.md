# Game Creator 2 变量系统与指令系统集成分析

## 概述

Game Creator 2 的变量系统与指令系统通过精心设计的架构实现了无缝集成。这种集成允许在视觉脚本中安全、高效地操作变量，同时保持类型安全和代码清晰性。本文档深入分析这两个系统之间的集成机制、设计模式和使用方式。

## 集成架构

### 1. 基础集成模式

变量系统与指令系统的集成基于以下核心模式：

#### 1.1 指令作为变量操作的入口点

所有变量操作都通过指令系统进行，指令作为变量系统的高级接口：

```csharp
public abstract class Instruction : TPolymorphicItem<Instruction>
{
    protected abstract Task Run(Args args);
    public async Task<InstructionResult> Schedule(Args args, InstructionList parent)
    {
        if (this.IsEnabled) await this.Run(args);
        return InstructionResult.Default;
    }
}
```

#### 1.2 Args 参数作为上下文传递

[`Args`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Common/Args.cs) 参数在指令和变量系统之间传递上下文信息：

```csharp
public class Args
{
    public GameObject Self { get; }
    public GameObject Target { get; }
    public GameObject Caller { get; }
    // 其他上下文信息
}
```

### 2. 变量访问抽象层

#### 2.1 字段访问模式

变量系统通过字段类提供统一的访问接口，指令系统通过这些字段类操作变量：

```csharp
// 获取变量
public abstract class TFieldGetVariable
{
    public abstract object Get(Args args);
    public T Get<T>(Args args) { /* 类型安全转换 */ }
}

// 设置变量
public abstract class TFieldSetVariable
{
    public abstract void Set(object value, Args args);
    public abstract object Get(Args args);
}
```

#### 2.2 属性访问模式

属性系统为特定类型提供类型安全的访问：

```csharp
public abstract class PropertyTypeGetBool
{
    public abstract bool Get(Args args);
    public abstract string String { get; }
}

public abstract class PropertyTypeSetBool
{
    public abstract void Set(bool value, Args args);
    public abstract bool Get(Args args);
}
```

## 具体集成实现

### 1. 变量操作指令

#### 1.1 列表变量操作指令

##### InstructionVariablesClear - 清空列表

[`InstructionVariablesClear`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesClear.cs:21) 展示了基本的变量操作模式：

```csharp
[Serializable]
public class InstructionVariablesClear : Instruction
{
    [SerializeField] private CollectorListVariable m_ListVariable = new CollectorListVariable();

    public override string Title => $"Clear {this.m_ListVariable}";

    protected override Task Run(Args args)
    {
        this.m_ListVariable.Clear(args);
        return DefaultResult;
    }
}
```

**集成特点**：
- 使用 `CollectorListVariable` 作为变量收集器
- 通过 `Args` 传递执行上下文
- 返回 `DefaultResult` 表示执行成功

##### InstructionVariablesMove - 移动列表元素

[`InstructionVariablesMove`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesMove.cs:21) 展示了复杂的变量操作：

```csharp
[Serializable]
public class InstructionVariablesMove : Instruction
{
    [SerializeField] private CollectorListVariable m_ListVariable = new CollectorListVariable();
    [SerializeReference] private TListGetPick m_From = new GetPickLast();
    [SerializeReference] private TListGetPick m_To = new GetPickLast();

    protected override Task Run(Args args)
    {
        List<object> elements = this.m_ListVariable.Get(args);
        int index1 = this.m_From.GetIndex(elements.Count, args);
        int index2 = this.m_To.GetIndex(elements.Count, args);
        
        object value = elements[index1];
        elements.RemoveAt(index1);
        elements.Insert(index2, value);
        
        this.m_ListVariable.Fill(elements.ToArray(), args);
        return DefaultResult;
    }
}
```

**集成特点**：
- 使用 `TListGetPick` 多态选择器
- 通过收集器获取和设置变量数据
- 支持复杂的列表操作

#### 1.2 变量属性操作

##### InstructionVariablesChangeId - 更改变量ID

[`InstructionVariablesChangeId`](Assets/Plugins/GameCreator/Packages/Core/Runtime/VisualScripting/Instructions/Collection/Variables/InstructionVariablesChangeId.cs:21) 展示了变量元数据操作：

```csharp
[Serializable]
public class InstructionVariablesChangeId : Instruction
{
    [SerializeField] private PropertyGetGameObject m_LocalVariables = GetGameObjectInstance.Create();
    [SerializeField] private PropertyGetString m_ID = GetStringGuid.Create;

    protected override Task Run(Args args)
    {
        TLocalVariables variables = this.m_LocalVariables.Get<TLocalVariables>(args);
        if (variables == null) return DefaultResult;

        string id = this.m_ID.Get(args);
        if (string.IsNullOrEmpty(id)) return DefaultResult;

        IdString idString = new IdString(id);
        variables.ChangeId(idString);

        return DefaultResult;
    }
}
```

**集成特点**：
- 使用属性获取器访问变量容器
- 支持变量元数据修改
- 类型安全的容器访问

### 2. 变量访问指令模式

#### 2.1 属性获取模式

变量系统通过属性类提供类型安全的访问，指令系统通过这些属性类读取变量：

```csharp
[Serializable]
public class GetBoolGlobalList : PropertyTypeGetBool
{
    [SerializeField] protected FieldGetGlobalList m_Variable = new FieldGetGlobalList(ValueBool.TYPE_ID);

    public override bool Get(Args args) => this.m_Variable.Get<bool>(args);
    public override string String => this.m_Variable.ToString();
}
```

**集成流程**：
1. 指令创建属性实例
2. 属性通过字段类访问变量
3. 字段类执行类型转换
4. 返回类型安全的结果

#### 2.2 属性设置模式

变量设置通过类似的模式实现：

```csharp
[Serializable]
public class SetBoolGlobalList : PropertyTypeSetBool
{
    [SerializeField] protected FieldSetGlobalList m_Variable = new FieldSetGlobalList(ValueBool.TYPE_ID);

    public override void Set(bool value, Args args) => this.m_Variable.Set(value, args);
    public override bool Get(Args args) => (bool)this.m_Variable.Get(args);
}
```

### 3. 收集器集成模式

#### 3.1 CollectorListVariable 的作用

[`CollectorListVariable`](Assets/Plugins/GameCreator/Packages/Core/Runtime/Variables/Classes/Utilities/Collectors/CollectorListVariable.cs:9) 作为变量系统与指令系统之间的桥梁：

```csharp
public class CollectorListVariable
{
    public List<object> Get(Args args)
    {
        // 根据类型获取本地或全局列表变量
        switch (this.m_ListVariable)
        {
            case Type.LocalList:
                LocalListVariables localList = this.m_LocalList.Get<LocalListVariables>(args);
                // 收集本地列表数据
                break;
            case Type.GlobalList:
                GlobalListVariables globalList = this.m_GlobalList;
                // 收集全局列表数据
                break;
        }
    }
    
    public void Fill(object[] values, Args args)
    {
        // 填充变量数据
    }
}
```

**集成优势**：
- 统一的变量访问接口
- 支持本地和全局变量
- 类型安全的数据操作

#### 3.2 多态选择器集成

选择器系统提供灵活的元素选择机制：

```csharp
public abstract class TListGetPick
{
    public abstract int GetIndex(int count, Args args);
}

public class GetPickFirst : TListGetPick
{
    public override int GetIndex(int count, Args args) => 0;
}

public class GetPickLast : TListGetPick
{
    public override int GetIndex(int count, Args args) => count - 1;
}
```

## 设计模式分析

### 1. 策略模式

变量访问使用策略模式，不同的访问方式实现不同的策略：

- **字段策略**: `TFieldGetVariable` 和 `TFieldSetVariable`
- **属性策略**: `PropertyTypeGetBool` 和 `PropertyTypeSetBool`
- **收集器策略**: `CollectorListVariable`

### 2. 模板方法模式

指令系统使用模板方法模式，定义执行流程：

```csharp
public async Task<InstructionResult> Schedule(Args args, InstructionList parent)
{
    this.NextInstruction = DEFAULT_NEXT_INSTRUCTION;
    this.Parent = parent;
    
    if (this.Breakpoint) Debug.Break();
    if (this.IsEnabled) await this.Run(args); // 模板方法
    
    if (this.IsCanceled) return InstructionResult.Stop;
    // 返回结果
}
```

### 3. 工厂模式

变量类型使用工厂模式创建：

```csharp
public static TValue CreateValue(IdString typeID, object value = default)
{
    return LUT_ID_TO_DATA.TryGetValue(typeID, out TypeData data)
        ? data.callback(value) 
        : new ValueNull();
}
```

### 4. 观察者模式

变量系统使用观察者模式监听变化：

```csharp
public event Action<object> EventChange;

public object Value
{
    get => this.Get();
    set
    {
        this.Set(value);
        this.EventChange?.Invoke(this.Get()); // 通知观察者
    }
}
```

## 性能优化

### 1. 静态查找表优化

变量类型使用静态查找表(LUT)优化类型查找：

```csharp
private static readonly Type_LUT LUT_ID_TO_DATA = new Type_LUT();
private static readonly ID_LUT LUT_TYPE_TO_ID = new ID_LUT();
```

### 2. 延迟初始化

变量运行时使用延迟初始化：

```csharp
public override void OnStartup()
{
    this.Variables = new Dictionary<string, NameVariable>();
    for (int i = 0; i < this.m_List.Length; ++i)
    {
        // 延迟初始化变量
    }
}
```

### 3. 事件驱动更新

变量变化通过事件驱动，避免轮询：

```csharp
public event Action<string> EventChange;

public void Set(string name, object value)
{
    // 设置值
    this.EventChange?.Invoke(name); // 事件通知
}
```

## 扩展性设计

### 1. 新变量类型扩展

添加新变量类型只需要：

1. 继承 `TValue` 实现新类型
2. 注册类型到系统
3. 创建对应的属性类

```csharp
[Serializable]
public class ValueCustom : TValue
{
    public static readonly IdString TYPE_ID = new IdString("custom");
    
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
    private static void RuntimeInit() => RegisterValueType(
        TYPE_ID, 
        new TypeData(typeof(ValueCustom), CreateValue),
        typeof(CustomType)
    );
}
```

### 2. 新指令扩展

添加新变量操作指令只需要：

1. 继承 `Instruction`
2. 实现变量操作逻辑
3. 使用现有的访问模式

```csharp
[Serializable]
public class InstructionVariablesCustom : Instruction
{
    [SerializeField] private CollectorListVariable m_ListVariable = new CollectorListVariable();
    
    protected override Task Run(Args args)
    {
        // 自定义变量操作
        return DefaultResult;
    }
}
```

## 错误处理

### 1. 类型安全检查

系统在编译时和运行时都进行类型检查：

```csharp
public T Get<T>(Args args)
{
    object value = this.Get(args);
    if (value == null) return default;
    
    return value switch
    {
        T valueTyped => valueTyped,
        _ => Convert.ChangeType(value, typeof(T)) is T valueConverted
            ? valueConverted
            : default
    };
}
```

### 2. 空值检查

系统提供完善的空值检查：

```csharp
public override object Get(Args args)
{
    return this.m_Variable != null ? m_Variable.Get(this.m_Select, args) : null;
}
```

### 3. 异常处理

指令系统提供异常处理机制：

```csharp
public async Task Run(Args args)
{
    try
    {
        await this.ExecInstructions(args);
    }
    catch (Exception exception)
    {
        Debug.LogError(exception.ToString(), this);
    }
}
```

## 总结

Game Creator 2 的变量系统与指令系统集成是一个设计精良的架构，它通过以下关键特性实现了高效、安全、可扩展的变量操作：

1. **类型安全**: 通过泛型和类型检查确保类型一致性
2. **多态性**: 通过抽象类和接口支持多种访问模式
3. **事件驱动**: 通过事件系统实现响应式更新
4. **性能优化**: 通过静态查找表和延迟初始化提高性能
5. **扩展性**: 通过工厂模式和策略模式支持系统扩展

这种集成设计使得在视觉脚本中操作变量变得简单直观，同时保持了代码的清晰性和可维护性，为游戏开发提供了强大而灵活的变量管理能力。