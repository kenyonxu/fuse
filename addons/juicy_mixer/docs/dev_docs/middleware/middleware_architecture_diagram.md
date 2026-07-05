# JuicyMixer V3 中间件系统架构图

## 整体系统架构

```mermaid
graph TB
    subgraph "JuicyMixer V3 系统架构"
        subgraph "用户接口层"
            API[JuicyMixer API]
            Editor[编辑器接口]
        end
        
        subgraph "调度层"
            Director[JuicyDirector]
            Pipeline[Middleware Pipeline]
        end
        
        subgraph "中间件层"
            Validation[ValidationMiddleware<br/>优先级: 1000]
            Channel[ChannelMiddleware<br/>优先级: 900]
            TimeScale[TimeScaleMiddleware<br/>优先级: 800]
            LOD[LODMiddleware<br/>优先级: 700]
        end
        
        subgraph "执行层"
            Drivers[Driver系统<br/>Tween/Shake/Spring]
            Buffer[PropertyBuffer]
        end
        
        subgraph "数据层"
            Context[JuicyContext]
            Resources[资源系统<br/>FeedbackResource]
            Config[配置资源<br/>Channel/TimeGroup/LOD]
        end
    end
    
    API --> Director
    Editor --> Director
    Director --> Pipeline
    Pipeline --> Validation
    Validation --> Channel
    Channel --> TimeScale
    TimeScale --> LOD
    LOD --> Drivers
    Drivers --> Buffer
    Buffer --> Context
    Director --> Context
    Resources --> Context
    Config --> Channel
    Config --> TimeScale
    Config --> LOD
```

## 中间件执行流程

```mermaid
sequenceDiagram
    participant User
    participant Director
    participant Pipeline
    participant Validation as ValidationMW
    participant Channel as ChannelMW
    participant TimeScale as TimeScaleMW
    participant LOD as LODMW
    participant Drivers
    participant Buffer
    participant Context
    
    User->>Director: play(resource, target)
    Director->>Context: create Context
    Director->>Pipeline: execute(context)
    
    Pipeline->>Validation: process(context, next)
    Validation->>Validation: validate_basic_requirements()
    Validation->>Validation: validate_target_node()
    Validation->>Validation: validate_resource_config()
    Validation->>Validation: validate_time_parameters()
    Validation->>Validation: validate_custom_rules()
    Validation->>Channel: next.call(context)
    
    Channel->>Channel: check_channel_limits()
    Channel->>Channel: apply_priority_rules()
    Channel->>Channel: manage_queue()
    Channel->>TimeScale: next.call(context)
    
    TimeScale->>TimeScale: apply_global_time_scale()
    TimeScale->>TimeScale: apply_time_group_scale()
    TimeScale->>TimeScale: update_animations()
    TimeScale->>LOD: next.call(context)
    
    LOD->>LOD: calculate_distance()
    LOD->>LOD: apply_frustum_culling()
    LOD->>LOD: apply_distance_culling()
    LOD->>LOD: adjust_intensity()
    LOD->>Drivers: next.call(context)
    
    Drivers->>Drivers: execute_drivers()
    Drivers->>Buffer: write_properties()
    Buffer->>Buffer: blend_properties()
    Buffer->>Context: apply_final_values()
    
    Drivers-->>Pipeline: execution_complete
    Pipeline-->>Director: pipeline_complete
    Director-->>User: context_id
```

## 中间件优先级和依赖关系

```mermaid
graph LR
    subgraph "中间件优先级 (从高到低)"
        V[ValidationMiddleware<br/>优先级: 1000]
        C[ChannelMiddleware<br/>优先级: 900]
        T[TimeScaleMiddleware<br/>优先级: 800]
        L[LODMiddleware<br/>优先级: 700]
    end
    
    subgraph "配置资源依赖"
        ChannelConfig[JuicyChannelConfig]
        TimeGroupConfig[JuicyTimeGroupConfig]
        LODConfig[JuicyLODConfig]
    end
    
    subgraph "系统依赖"
        Registry[DriverRegistry]
        Camera[Camera2D]
        Mixer[JuicyMixer]
    end
    
    C --> ChannelConfig
    T --> TimeGroupConfig
    L --> LODConfig
    
    V --> Registry
    C --> Mixer
    L --> Camera
    
    V --> C
    C --> T
    T --> L
```

## 数据流图

```mermaid
flowchart TD
    subgraph "输入数据"
        Resource[JuicyFeedbackResource]
        Target[Target Node]
        Config[配置资源]
    end
    
    subgraph "Context数据"
        Context[JuicyContext]
        DriverData[driver_cache]
        PropertyData[property_cache]
        MiddlewareData[middleware_data]
    end
    
    subgraph "中间件处理"
        ValidData[验证结果]
        ChannelData[通道状态]
        TimeData[时间缩放]
        LODData[LOD调整]
    end
    
    subgraph "Driver处理"
        DriverOutput[Driver输出]
        PropertySamples[属性采样]
    end
    
    subgraph "最终输出"
        FinalProperties[最终属性值]
        VisualEffects[视觉效果]
    end
    
    Resource --> Context
    Target --> Context
    Config --> Context
    
    Context --> DriverData
    Context --> PropertyData
    Context --> MiddlewareData
    
    MiddlewareData --> ValidData
    ValidData --> ChannelData
    ChannelData --> TimeData
    TimeData --> LODData
    
    LODData --> DriverOutput
    DriverData --> DriverOutput
    PropertyData --> DriverOutput
    
    DriverOutput --> PropertySamples
    PropertySamples --> FinalProperties
    FinalProperties --> VisualEffects
```

## 错误处理流程

```mermaid
flowchart TD
    Start[开始执行中间件]
    Execute[执行中间件.process()]
    
    subgraph "错误检测"
        CheckError{是否有错误?}
        CheckCritical{是否为关键错误?}
        CheckRecovery{是否有恢复机制?}
    end
    
    subgraph "错误处理"
        LogError[记录错误日志]
        TryRecovery[尝试错误恢复]
        SkipMiddleware[跳过当前中间件]
        StopPipeline[停止管道执行]
        ReturnError[返回错误结果]
    end
    
    subgraph "继续执行"
        Continue[继续执行下一个中间件]
        Success[管道执行成功]
    end
    
    Start --> Execute
    Execute --> CheckError
    
    CheckError -->|无错误| Continue
    CheckError -->|有错误| CheckCritical
    
    CheckCritical -->|关键错误| LogError
    CheckCritical -->|非关键错误| CheckRecovery
    
    LogError --> StopPipeline
    StopPipeline --> ReturnError
    
    CheckRecovery -->|有恢复机制| TryRecovery
    CheckRecovery -->|无恢复机制| SkipMiddleware
    
    TryRecovery -->|恢复成功| Continue
    TryRecovery -->|恢复失败| SkipMiddleware
    
    SkipMiddleware --> Continue
    Continue --> Success
```

## 性能监控架构

```mermaid
graph TB
    subgraph "性能数据收集"
        MiddlewarePerf[中间件性能]
        PipelinePerf[管道性能]
        DriverPerf[Driver性能]
        SystemPerf[系统性能]
    end
    
    subgraph "性能指标"
        ExecTime[执行时间]
        MemoryUse[内存使用]
        CallCount[调用次数]
        ErrorRate[错误率]
    end
    
    subgraph "性能分析"
        RealTime[实时监控]
        Historical[历史数据]
        Alerts[性能预警]
        Reports[性能报告]
    end
    
    subgraph "性能优化"
        Cache[缓存优化]
        LazyLoad[懒加载]
        Batch[批处理]
        Pool[对象池]
    end
    
    MiddlewarePerf --> ExecTime
    PipelinePerf --> ExecTime
    DriverPerf --> ExecTime
    SystemPerf --> MemoryUse
    
    ExecTime --> RealTime
    MemoryUse --> RealTime
    CallCount --> Historical
    ErrorRate --> Alerts
    
    RealTime --> Reports
    Historical --> Reports
    Alerts --> Reports
    
    Reports --> Cache
    Reports --> LazyLoad
    Reports --> Batch
    Reports --> Pool
```

---

**图表说明**:
- 所有图表均基于JuicyMixer V3的中间件系统设计
- 优先级数字越小表示优先级越高
- 数据流展示了从输入到输出的完整处理过程
- 错误处理流程确保系统稳定性
- 性能监控架构支持系统优化和调优