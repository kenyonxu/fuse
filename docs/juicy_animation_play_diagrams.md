# JuicyAnimationPlay 组件图表

## 1. 类图

### 1.1 核心类关系图

```mermaid
classDiagram
    class JuicyFeedbackResource {
        <<abstract>>
        +duration: float
        +channel: String
        +priority: int
        +interruption_policy: InterruptionPolicy
        +create_drivers()* Array
        +validate_config() ValidationResult
        +get_duration()* float
    }
    
    class JuicyAnimationPlayResource {
        +animation_data: Array[AnimationPlayData]
        +loop: bool
        +loop_delay: float
        +create_drivers() Array
        +validate_config() ValidationResult
        +get_duration() float
        +add_animation_data() AnimationPlayData
        +remove_animation_data() bool
    }
    
    class AnimationPlayData {
        <<Resource>>
        +target: NodePath
        +target_animation: String
        +play_mode: PlayMode
        +end_at: float
        +blend_in_time: float
        +blend_out_time: float
        +validate() Dictionary
        +get_animation_player() AnimationPlayer
        +get_animation_list() Array[String]
        +get_animation_length() float
    }
    
    class JuicyDriver {
        <<abstract>>
        +driver_name: String
        +supported_properties: Array[String]
        +required_context_data: Array[String]
        +prepare(context, delta, buffer)* void
        +process(context, delta, buffer)* void
        +cleanup(context)* void
        +validate_context() Dictionary
        +_initialize_driver_time() void
        +_update_driver_time() float
        +_is_time_based_complete() bool
    }
    
    class JuicyAnimationPlayDriver {
        +driver_name: String
        +animation_states: Dictionary
        +current_animation_index: Dictionary
        +prepare(context, delta, buffer) void
        +process(context, delta, buffer) void
        +cleanup(context) void
        -_initialize_animation_states() void
        -_start_current_animation() void
        -_play_animation_normal() void
        -_play_animation_sync() void
        -_process_animation() void
        -_move_to_next_animation() void
    }
    
    class AnimationPlayState {
        +animation_player: AnimationPlayer
        +animation_data: AnimationPlayData
        +start_time: float
        +current_time: float
        +is_playing: bool
        +is_completed: bool
        +blend_start_time: float
        +is_blending_in: bool
        +is_blending_out: bool
    }
    
    class AnimationPlayer {
        <<Godot Node>>
        +play(name, custom_blend, custom_speed, from_end) void
        +stop(keep_state) void
        +seek(seconds, update, update_only) void
        +is_playing() bool
        +get_animation(name) Animation
        +get_animation_list() PackedStringArray
        +animation_finished: Signal
    }
    
    class JuicyContext {
        +context_id: String
        +resource: JuicyFeedbackResource
        +target: Node
        +owner: Node
        +time_scale: float
        +start_time: float
        +current_time: float
        +progress: float
        +is_active: bool
        +is_completed: bool
    }
    
    %% 继承关系
    JuicyFeedbackResource <|-- JuicyAnimationPlayResource
    JuicyDriver <|-- JuicyAnimationPlayDriver
    
    %% 组合关系
    JuicyAnimationPlayResource *-- AnimationPlayData : contains
    JuicyAnimationPlayDriver *-- AnimationPlayState : manages
    AnimationPlayState *-- AnimationPlayer : uses
    AnimationPlayState *-- AnimationPlayData : references
    
    %% 依赖关系
    JuicyAnimationPlayDriver ..> JuicyContext : processes
    AnimationPlayData ..> AnimationPlayer : queries
    JuicyAnimationPlayResource ..> JuicyAnimationPlayDriver : creates
```

### 1.2 播放模式枚举图

```mermaid
enumDiagram
    PlayMode {
        NORMAL
        SYNC
    }
    
    note for PlayMode "NORMAL: 使用AnimationPlayer.play()\nSYNC: 使用AnimationPlayer.seek()受时间缩放影响"
```

### 1.3 状态转换图

```mermaid
stateDiagram-v2
    [*] --> Initializing: prepare()
    Initializing --> Playing: _start_current_animation()
    
    Playing --> Processing: process()
    Processing --> Playing: continue
    Processing --> Completed: animation finished
    
    state Playing {
        [*] --> NormalMode: play_mode == NORMAL
        [*] --> SyncMode: play_mode == SYNC
        
        NormalMode --> WaitingForSignal: play()
        WaitingForSignal --> [*]: animation_finished
        
        SyncMode --> Seeking: seek()
        Seeking --> [*]: time elapsed
    }
    
    Completed --> NextAnimation: more animations
    Completed --> Looping: loop enabled
    Completed --> [*]: sequence complete
    
    NextAnimation --> Initializing: _move_to_next_animation()
    Looping --> Initializing: reset states
```

## 2. 时序图

### 2.1 基本播放流程

```mermaid
sequenceDiagram
    participant User
    participant JuicyMixer
    participant JuicyDirector
    participant JuicyAnimationPlayResource
    participant JuicyAnimationPlayDriver
    participant AnimationPlayer
    participant TargetNode
    
    User->>JuicyMixer: play(resource, target)
    JuicyMixer->>JuicyDirector: create_context()
    JuicyDirector->>JuicyAnimationPlayResource: create_drivers()
    JuicyAnimationPlayResource-->>JuicyDirector: [JuicyAnimationPlayDriver]
    JuicyDirector->>JuicyAnimationPlayDriver: prepare(context, delta, buffer)
    
    JuicyAnimationPlayDriver->>JuicyAnimationPlayResource: get animation_data
    JuicyAnimationPlayResource-->>JuicyAnimationPlayDriver: [AnimationPlayData]
    
    loop for each AnimationPlayData
        JuicyAnimationPlayDriver->>AnimationPlayData: get_animation_player(target)
        AnimationPlayData->>TargetNode: get_node(target)
        TargetNode-->>AnimationPlayData: target_node
        AnimationPlayData->>TargetNode: get_animation_player()
        TargetNode-->>AnimationPlayData: AnimationPlayer
        AnimationPlayData-->>JuicyAnimationPlayDriver: AnimationPlayer
        
        JuicyAnimationPlayDriver->>AnimationPlayer: play(animation_name)
        AnimationPlayer-->>JuicyAnimationPlayDriver: playing
    end
    
    JuicyDirector->>JuicyAnimationPlayDriver: process(context, delta, buffer)
    
    loop each frame
        JuicyAnimationPlayDriver->>AnimationPlayer: is_playing()
        AnimationPlayer-->>JuicyAnimationPlayDriver: status
        alt animation finished
            JuicyAnimationPlayDriver->>JuicyAnimationPlayDriver: _move_to_next_animation()
        end
    end
    
    JuicyAnimationPlayDriver->>JuicyDirector: context.complete()
    JuicyDirector-->>User: context_id
```

### 2.2 两种播放模式对比

```mermaid
sequenceDiagram
    participant Driver
    participant AnimationData
    participant AnimationPlayer
    participant Context
    
    Note over Driver,Context: NORMAL模式流程
    Driver->>AnimationData: get_animation_player()
    AnimationData-->>Driver: AnimationPlayer
    Driver->>AnimationPlayer: play(animation, blend_time)
    Driver->>AnimationPlayer: connect(animation_finished)
    Note over AnimationPlayer: 自动播放，不受时间缩放影响
    AnimationPlayer-->>Driver: animation_finished signal
    
    Note over Driver,Context: SYNC模式流程
    Driver->>AnimationData: get_animation_player()
    AnimationData-->>Driver: AnimationPlayer
    Driver->>AnimationPlayer: seek(0.0)
    Driver->>AnimationPlayer: play(animation, blend_time)
    Driver->>AnimationPlayer: speed_scale = 0.0
    Note over Driver: 每帧手动控制播放进度
    loop each frame
        Driver->>Context: get time_scale
        Context-->>Driver: time_scale
        Driver->>AnimationPlayer: seek(calculated_position)
    end
```

### 2.3 循环播放流程

```mermaid
sequenceDiagram
    participant Driver
    participant Resource
    participant AnimationState
    participant Context
    
    Note over Driver,Context: 循环播放流程
    Driver->>Resource: get loop settings
    Resource-->>Driver: loop=true, loop_delay=0.5
    
    loop animation sequence
        Driver->>AnimationState: play current animation
        AnimationState-->>Driver: animation completed
        
        alt more animations available
            Driver->>Driver: _move_to_next_animation()
        else no more animations
            Driver->>Resource: check loop enabled
            Resource-->>Driver: loop enabled
            Driver->>Driver: wait loop_delay
            Driver->>AnimationState: reset all states
            Driver->>Driver: start from first animation
        end
    end
```

### 2.4 错误处理流程

```mermaid
sequenceDiagram
    participant Driver
    participant AnimationData
    participant TargetNode
    participant Context
    
    Driver->>AnimationData: get_animation_player(target)
    AnimationData->>TargetNode: get_node(target)
    TargetNode-->>AnimationData: null (node not found)
    
    AnimationData-->>Driver: null
    Driver->>Driver: log warning
    
    alt target node exists but no AnimationPlayer
        AnimationData->>TargetNode: get_animation_player()
        TargetNode-->>AnimationData: null
        AnimationData->>TargetNode: find_child_animation_player()
        TargetNode-->>AnimationData: null
        AnimationData-->>Driver: null
        Driver->>Driver: log warning, skip this animation
    end
    
    Driver->>Context: check if any valid animations
    alt no valid animations
        Driver->>Context: complete()
    else some valid animations
        Driver->>Driver: continue with valid animations
    end
```

## 3. 数据流图

### 3.1 配置数据流

```mermaid
flowchart TD
    A[User Configuration] --> B[JuicyAnimationPlayResource]
    B --> C[AnimationPlayData Array]
    C --> D[AnimationPlayData 1]
    C --> E[AnimationPlayData 2]
    C --> F[AnimationPlayData N]
    
    D --> G[target: NodePath]
    D --> H[target_animation: String]
    D --> I[play_mode: PlayMode]
    D --> J[end_at: float]
    D --> K[blend_in_time: float]
    D --> L[blend_out_time: float]
    
    E --> M[target: NodePath]
    E --> N[target_animation: String]
    E --> O[play_mode: PlayMode]
    E --> P[end_at: float]
    E --> Q[blend_in_time: float]
    E --> R[blend_out_time: float]
    
    B --> S[loop: bool]
    B --> T[loop_delay: float]
```

### 3.2 运行时数据流

```mermaid
flowchart TD
    A[JuicyContext] --> B[JuicyAnimationPlayDriver]
    B --> C[AnimationPlayState Array]
    C --> D[AnimationPlayState 1]
    C --> E[AnimationPlayState 2]
    C --> F[AnimationPlayState N]
    
    D --> G[AnimationPlayer]
    D --> H[AnimationPlayData]
    D --> I[start_time: float]
    D --> J[current_time: float]
    D --> K[is_playing: bool]
    D --> L[is_completed: bool]
    
    G --> M[Target Node]
    H --> N[Animation Configuration]
    
    B --> O[current_animation_index]
    O --> P[Current State Index]
```

## 4. 组件交互图

### 4.1 系统架构交互

```mermaid
graph TB
    subgraph "用户层"
        A[User Code]
    end
    
    subgraph "API层"
        B[JuicyMixer]
        C[JuicyDirector]
    end
    
    subgraph "中间件层"
        D[Middleware Pipeline]
        E[ValidationMiddleware]
        F[InterruptionMiddleware]
        G[StateRestorationMiddleware]
    end
    
    subgraph "驱动器层"
        H[JuicyAnimationPlayDriver]
        I[Other Drivers]
    end
    
    subgraph "资源层"
        J[JuicyAnimationPlayResource]
        K[AnimationPlayData]
        L[Other Resources]
    end
    
    subgraph "目标层"
        M[Target Node]
        N[AnimationPlayer]
        O[Animation Resources]
    end
    
    A --> B
    B --> C
    C --> D
    D --> E
    D --> F
    D --> G
    C --> H
    C --> I
    H --> J
    I --> L
    J --> K
    H --> M
    M --> N
    N --> O
    
    style H fill:#e1f5fe
    style J fill:#e8f5e8
    style K fill:#fff3e0
```

### 4.2 时序管理交互

```mermaid
graph LR
    subgraph "时间管理"
        A[Context.time_scale]
        B[Driver Time State]
        C[Effective Delta]
    end
    
    subgraph "动画播放"
        D[NORMAL Mode]
        E[SYNC Mode]
        F[Animation Progress]
    end
    
    subgraph "动画系统"
        G[AnimationPlayer.play]
        H[AnimationPlayer.seek]
        I[Animation Speed]
    end
    
    A --> C
    B --> C
    C --> D
    C --> E
    D --> G
    E --> H
    C --> F
    F --> I
    
    style A fill:#ffebee
    style B fill:#ffebee
    style C fill:#ffebee
    style D fill:#e8f5e8
    style E fill:#e8f5e8
    style F fill:#e8f5e8
```

这些图表提供了JuicyAnimationPlay组件的完整可视化表示，包括类关系、时序流程、数据流向和系统交互，有助于理解整个系统的工作原理和组件间的协作关系。