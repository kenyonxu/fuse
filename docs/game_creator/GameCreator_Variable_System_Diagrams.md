# Game Creator 2 变量系统图表分析

## 概述

本文档通过图表形式展示Game Creator 2变量系统的架构关系、工作流程和类层次结构，帮助理解系统的整体设计和各组件之间的交互关系。

## 类关系图

### 1. 核心类层次结构

```mermaid
classDiagram
    class TPolymorphicItem~T~ {
        <<abstract>>
    }
    
    class TValue {
        <<abstract>>
        +object Value
        +IdString TypeID
        +Type Type
        +event Action~object~ EventChange
        +abstract object Get()
        +abstract void Set(object value)
        +static TValue CreateValue(IdString typeID, object value)
    }
    
    class TVariable {
        <<abstract>>
        +TValue m_Value
        +object Value
        +IdString TypeID
        +Type Type
        +abstract TVariable Copy
    }
    
    class TList~T~ {
        <<abstract>>
        +List~T~ m_Source
        +int Length
        +T Get(int index)
        +void Set(int index, T value)
        +void Add(T value)
        +void Remove(int index)
    }
    
    class TVariableRuntime~T~ {
        <<abstract>>
        +abstract void OnStartup()
        +abstract IEnumerator~T~ GetEnumerator()
    }
    
    TPolymorphicItem~T~ <|-- TValue
    TPolymorphicItem~T~ <|-- TVariable
    TPolymorphicList~T~ <|-- TList~T~
    
    TValue <|-- TVariable : contains
    TVariable <|-- NameVariable
    TVariable <|-- IndexVariable
    TList~T~ <|-- NameList
    TList~T~ <|-- IndexList
    TVariableRuntime~T~ <|-- NameVariableRuntime
    TVariableRuntime~T~ <|-- ListVariableRuntime
```

### 2. 具体值类型类

```mermaid
classDiagram
    class TValue {
        <<abstract>>
    }
    
    class ValueBool {
        +static IdString TYPE_ID
        +bool m_Value
        +override IdString TypeID
        +override Type Type
        +override bool CanSave
    }
    
    class ValueNumber {
        +static IdString TYPE_ID
        +double m_Value
        +override IdString TypeID
        +override Type Type
        +override bool CanSave
    }
    
    class ValueString {
        +static IdString TYPE_ID
        +string m_Value
        +override IdString TypeID
        +override Type Type
        +override bool CanSave
    }
    
    class ValueGameObject {
        +static IdString TYPE_ID
        +GameObject m_Value
        +override IdString TypeID
        +override Type Type
        +override bool CanSave
    }
    
    TValue <|-- ValueBool
    TValue <|-- ValueNumber
    TValue <|-- ValueString
    TValue <|-- ValueGameObject
```

### 3. 字段访问系统

```mermaid
classDiagram
    class TFieldGetVariable {
        <<abstract>>
        +IdString m_TypeID
        +T Get~T~(Args args)
        +abstract object Get(Args args)
        +abstract string ToString()
    }
    
    class TFieldSetVariable {
        <<abstract>>
        +IdString m_TypeID
        +abstract void Set(object value, Args args)
        +abstract object Get(Args args)
        +abstract string ToString()
    }
    
    class FieldGetGlobalList {
        +GlobalListVariables m_Variable
        +TListGetPick m_Select
        +override object Get(Args args)
    }
    
    class FieldGetGlobalName {
        +GlobalNameVariables m_Variable
        +IdPathString m_Name
        +override object Get(Args args)
    }
    
    class FieldGetLocalList {
        +PropertyGetGameObject m_Variable
        +TListGetPick m_Select
        +override object Get(Args args)
    }
    
    class FieldSetGlobalList {
        +GlobalListVariables m_Variable
        +TListSetPick m_Select
        +override void Set(object value, Args args)
    }
    
    TFieldGetVariable <|-- FieldGetGlobalList
    TFieldGetVariable <|-- FieldGetGlobalName
    TFieldGetVariable <|-- FieldGetLocalList
    TFieldSetVariable <|-- FieldSetGlobalList
```

### 4. 属性系统

```mermaid
classDiagram
    class PropertyTypeGetBool {
        <<abstract>>
        +abstract bool Get(Args args)
        +abstract string String
    }
    
    class PropertyTypeSetBool {
        <<abstract>>
        +abstract void Set(bool value, Args args)
        +abstract bool Get(Args args)
    }
    
    class GetBoolGlobalList {
        +FieldGetGlobalList m_Variable
        +override bool Get(Args args)
        +override string String
    }
    
    class GetBoolGlobalName {
        +FieldGetGlobalName m_Variable
        +override bool Get(Args args)
        +override string String
    }
    
    class SetBoolGlobalList {
        +FieldSetGlobalList m_Variable
        +override void Set(bool value, Args args)
        +override bool Get(Args args)
    }
    
    PropertyTypeGetBool <|-- GetBoolGlobalList
    PropertyTypeGetBool <|-- GetBoolGlobalName
    PropertyTypeSetBool <|-- SetBoolGlobalList
```

## 工作流程图

### 1. 变量创建和初始化流程

```mermaid
flowchart TD
    A[启动游戏] --> B[变量系统初始化]
    B --> C[注册变量类型]
    C --> D[创建变量运行时]
    D --> E[加载变量数据]
    E --> F[初始化变量容器]
    F --> G[变量系统就绪]
    
    C --> C1[ValueBool注册]
    C --> C2[ValueNumber注册]
    C --> C3[ValueString注册]
    C --> C4[其他类型注册]
    
    D --> D1[NameVariableRuntime]
    D --> D2[ListVariableRuntime]
    
    E --> E1[本地变量加载]
    E --> E2[全局变量加载]
    E --> E3[持久化变量加载]
```

### 2. 变量访问流程

```mermaid
flowchart TD
    A[指令请求变量访问] --> B{访问类型}
    B -->|获取| C[创建获取字段]
    B -->|设置| D[创建设置字段]
    
    C --> E[FieldGetGlobalList]
    C --> F[FieldGetGlobalName]
    C --> G[FieldGetLocalList]
    
    D --> H[FieldSetGlobalList]
    D --> I[FieldSetGlobalName]
    D --> J[FieldSetLocalList]
    
    E --> K[访问全局列表变量]
    F --> L[访问全局命名变量]
    G --> M[访问本地列表变量]
    
    H --> N[设置全局列表变量]
    I --> O[设置全局命名变量]
    J --> P[设置本地列表变量]
    
    K --> Q[类型转换]
    L --> Q
    M --> Q
    N --> R[类型验证]
    O --> R
    P --> R
    
    Q --> S[返回值]
    R --> T[触发事件]
    T --> U[完成操作]
```

### 3. 指令执行流程

```mermaid
flowchart TD
    A[指令调度] --> B[检查指令状态]
    B --> C{指令是否启用?}
    C -->|否| D[跳过指令]
    C -->|是| E[执行指令]
    
    E --> F[获取变量收集器]
    F --> G[访问变量数据]
    G --> H[执行变量操作]
    H --> I[更新变量值]
    I --> J[触发变化事件]
    J --> K[返回执行结果]
    
    D --> L[返回默认结果]
    K --> M[继续下一个指令]
    L --> M
```

### 4. 变量事件系统流程

```mermaid
flowchart TD
    A[变量值变化] --> B[检查值是否真的改变]
    B --> C{值是否改变?}
    C -->|否| D[忽略变化]
    C -->|是| E[触发EventChange事件]
    
    E --> F[通知所有监听器]
    F --> G[执行监听器回调]
    G --> H[更新UI显示]
    G --> I[触发相关指令]
    G --> J[保存变量状态]
    
    H --> K[事件处理完成]
    I --> K
    J --> K
    D --> K
```

## 系统交互图

### 1. 指令与变量系统交互

```mermaid
sequenceDiagram
    participant I as Instruction
    participant C as CollectorListVariable
    participant F as FieldGetGlobalList
    participant V as GlobalListVariables
    participant R as ListVariableRuntime
    
    I->>C: Get(args)
    C->>F: Get(args)
    F->>V: Get(select, args)
    V->>R: Get(index)
    R-->>V: 返回值
    V-->>F: 返回值
    F-->>C: 返回值
    C-->>I: 返回List<object>
    
    I->>C: Fill(values, args)
    C->>V: Set(select, value, args)
    V->>R: Set(index, value)
    R->>R: 触发EventChange
    R-->>V: 完成
    V-->>C: 完成
    C-->>I: 完成
```

### 2. 属性系统交互

```mermaid
sequenceDiagram
    participant I as Instruction
    participant P as PropertyTypeGetBool
    participant F as FieldGetGlobalList
    participant V as GlobalListVariables
    participant T as TValue
    
    I->>P: Get(args)
    P->>F: Get<bool>(args)
    F->>V: Get(select, args)
    V->>T: Value
    T-->>V: 返回object
    V-->>F: 返回object
    F->>F: 类型转换
    F-->>P: 返回bool
    P-->>I: 返回bool
```

## 数据流图

### 1. 变量系统数据流

```mermaid
flowchart LR
    A[编辑器数据] --> B[序列化数据]
    B --> C[运行时数据]
    C --> D[变量值]
    
    E[指令系统] --> F[变量操作]
    F --> G[字段访问]
    G --> H[变量容器]
    H --> D
    
    D --> I[事件系统]
    I --> J[UI更新]
    I --> K[其他系统]
    
    D --> L[持久化系统]
    L --> M[保存数据]
    M --> B
```

### 2. 类型系统数据流

```mermaid
flowchart TD
    A[类型注册] --> B[静态查找表]
    B --> C[类型ID映射]
    B --> D[类型映射]
    
    E[变量创建] --> F[类型ID查询]
    F --> B
    B --> G[类型数据]
    G --> H[创建实例]
    
    I[类型转换] --> J[类型检查]
    J --> K[兼容性验证]
    K --> L[执行转换]
    
    M[序列化] --> N[类型信息保存]
    N --> O[数据持久化]
    
    P[反序列化] --> Q[类型信息读取]
    Q --> R[类型重建]
```

## 组件关系图

### 1. 系统整体架构

```mermaid
graph TB
    subgraph "指令系统"
        I[Instruction]
        IL[InstructionList]
        IR[InstructionResult]
    end
    
    subgraph "变量系统"
        subgraph "核心类"
            TV[TValue]
            TVAR[TVariable]
            TL[TList]
            TVR[TVariableRuntime]
        end
        
        subgraph "访问层"
            FG[TFieldGetVariable]
            FS[TFieldSetVariable]
            PG[PropertyTypeGet]
            PS[PropertyTypeSet]
        end
        
        subgraph "工具类"
            CL[CollectorListVariable]
            D[Detector]
            UT[Utilities]
        end
    end
    
    subgraph "编辑器系统"
        ED[Editor Drawers]
        ET[Editor Tools]
        EV[Editor Views]
    end
    
    I --> FG
    I --> FS
    I --> CL
    FG --> TVAR
    FS --> TVAR
    CL --> TVR
    TVAR --> TV
    TVR --> TL
    
    PG --> FG
    PS --> FS
    
    ED --> FG
    ED --> FS
    ET --> TV
    EV --> TVR
```

### 2. 变量类型层次

```mermaid
graph TD
    subgraph "值类型"
        TV[TValue]
        VB[ValueBool]
        VN[ValueNumber]
        VS[ValueString]
        VG[ValueGameObject]
        VM[ValueMaterial]
        VT[ValueTexture]
        VNULL[ValueNull]
    end
    
    subgraph "变量类型"
        TVAR[TVariable]
        NV[NameVariable]
        IV[IndexVariable]
    end
    
    subgraph "列表类型"
        TL[TList]
        NL[NameList]
        IL[IndexList]
    end
    
    subgraph "运行时类型"
        TVR[TVariableRuntime]
        NVR[NameVariableRuntime]
        LVR[ListVariableRuntime]
    end
    
    TV --> VB
    TV --> VN
    TV --> VS
    TV --> VG
    TV --> VM
    TV --> VT
    TV --> VNULL
    
    TVAR --> NV
    TVAR --> IV
    
    TL --> NL
    TL --> IL
    
    TVR --> NVR
    TVR --> LVR
```

## 总结

通过以上图表，我们可以清晰地看到Game Creator 2变量系统的以下特点：

1. **层次化设计**: 系统采用清晰的层次结构，从抽象基类到具体实现，职责分离明确
2. **多态性支持**: 通过抽象类和接口实现多态性，支持多种变量类型和访问模式
3. **事件驱动**: 使用事件系统实现响应式更新，保持系统各组件的松耦合
4. **类型安全**: 通过泛型和类型检查确保类型安全，避免运行时错误
5. **扩展性**: 通过工厂模式和策略模式支持系统扩展，便于添加新功能

这些设计使得变量系统既强大又灵活，能够满足游戏开发中的各种需求，同时保持代码的清晰性和可维护性。