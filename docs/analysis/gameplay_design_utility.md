---
title: GameplayDesignUtilities 架构分析
status: published
author: claude
date: 2026-02-06
order: 1
keywords:
  - wave system
  - formation builder
  - gameplay utilities
  - unity editor tools
---

# GameplayDesignUtilities 架构分析

`GameplayDesignUtilities` 是一个扩展 TopDown Engine 的关卡设计工具包，包含两个核心子系统：**Wave Creator**（波次创建器）和 **Formation Builder**（阵型构建器）。

## 系统概览

```
GameplayDesignUtilities/
├── WaveCreator/           # 波次系统
│   ├── LevelFlow.cs       # 关卡流程容器
│   ├── Wave.cs            # 单个波次配置
│   ├── WaveTriggerConditions.cs  # 触发条件
│   ├── EnemySpawners.cs   # 生成策略
│   └── SpawnPointManager.cs      # 位置管理
└── FormationBuilder/      # 阵型系统
    ├── FormationData.cs   # 阵型数据资源
    └── FormationBuilder.cs    # 可视化构建工具
```

## Wave Creator

Wave Creator 实现了数据驱动的波次配置系统。设计师通过 ScriptableObject 定义关卡流程，运行时系统根据触发条件和生成策略执行敌人生成。

### 核心数据结构

```csharp
// 关卡流程
[CreateAssetMenu(fileName = "LevelFlow", menuName = "GameplayDesignUtilities/LevelFlow")]
public class LevelFlow : ScriptableObject
{
    public float StartDelay;
    public string StartText = "威胁即将来袭！";
    public string WinText = "难关踏破，赢得胜利！";
    public string LoseText = "菜就多练，再来一次！";
    public List<Wave> Waves;
}

// 单个波次
[CreateAssetMenu(fileName = "Wave", menuName = "GameplayDesignUtilities/Wave")]
public class Wave : ScriptableObject
{
    public string description;
    public WaveTrigger trigger;
    public string waveText;
    public List<SpawnGroup> spawnGroups;

    [System.Serializable]
    public class SpawnGroup
    {
        public PLCollection<GameObject> enemyPool;  // RNGNeeds 概率池
        public int totalToSpawn;
        public SpawnType spawnType;  // random / Formation
        public SpawnDistanceCategory spawnDistance;  // Near / Mid / Far
        public FormationData formation;
        public float spawnDelay;
        public float spawnRateMin, spawnRateMax;
    }
}
```

### 触发条件系统

触发条件采用**策略模式**实现，`IWaveTriggerCondition` 接口定义了触发条件的契约：

```csharp
public interface IWaveTriggerCondition
{
    bool ShouldTrigger(WaveStateData previousWave, LevelState levelState, int totalEnemiesAlive);
    float GetTriggerDelay();
    string GetTriggerDescription();
}
```

三种内置触发条件：

| 类型 | 条件 | 适用场景 |
|------|------|----------|
| `ImmediateTriggerCondition` | 关卡进行中即触发 | 首波 |
| `DelayTriggerCondition` | 前一波结束后延迟 N 秒 | 控制节奏 |
| `RemainEnemyTriggerCondition` | 剩余敌人 ≤ X% | 压力叠加 |

```csharp
// 工厂创建
IWaveTriggerCondition condition = WaveTriggerConditionFactory.CreateTriggerCondition(wave.trigger);

// 运行时检查
if (condition.ShouldTrigger(previousWave, levelState, totalEnemiesAlive))
{
    StartWave(currentWave);
}
```

### 生成策略

敌人生成同样使用策略模式，`IEnemySpawner` 接口定义位置计算逻辑：

```csharp
public interface IEnemySpawner
{
    Vector2 GetSpawnPosition(Wave.SpawnGroup spawnGroup, SpawnPointManager spawnManager);
    string GetSpawnDescription();
}
```

| 生成器 | 逻辑 | 配置 |
|--------|------|------|
| `RandomSpawner` | 从 SpawnPointManager 获取随机位置 | `spawnDistance` (Near/Mid/Far) |
| `FormationSpawner` | 按阵型位置循环生成 | `formation` (FormationData) |

```csharp
// 生成管理器统一调度
public class EnemySpawnManager
{
    public Vector2 GetSpawnPosition(Wave.SpawnGroup spawnGroup)
    {
        IEnemySpawner spawner = _spawners[spawnGroup.spawnType];
        return spawner.GetSpawnPosition(spawnGroup, _spawnPointManager);
    }
}
```

### SpawnPointManager

`SpawnPointManager` 基于距离类别提供环形生成区域：

```csharp
public class SpawnPointManager : MonoBehaviourGizmos
{
    public float nearRadiusMin = 8f, nearRadiusMax = 10f;
    public float midRadiusMin = 12f, midRadiusMax = 15f;
    public float farRadiusMin = 18f, farRadiusMax = 20f;

    public Vector2 GetSpawnPosition(SpawnDistanceCategory category)
    {
        // 在指定距离范围内随机生成点
        // 带 10 次重试的安全校验
        // 检查 Obstacles 图层碰撞
    }
}
```

使用 `Drawing` 库在 Scene 视图中可视化范围：

```csharp
public override void DrawGizmos()
{
    Draw.xy.Circle(Vector2.zero, nearRadiusMin, Color.red);
    Draw.xy.Circle(Vector2.zero, nearRadiusMax, Color.red);
    // ...
}
```

## Formation Builder

Formation Builder 是一个**编辑器工具**，用于可视化创建阵型配置。设计师在 Scene 视图中调整参数，工具实时预览点分布，最终保存为 `FormationData` 资源供 Wave 系统使用。

### 形状生成

组件基于 `PolygonCollider2D` 的形状边界进行点填充：

```csharp
[RequireComponent(typeof(PolygonCollider2D))]
[ExecuteInEditMode]
public class FormationBuilder : MonoBehaviour
{
    public ShapeType targetShape = ShapeType.Circle;
    public float radius = 1;

    private Vector2[] GenerateShapeVertices()
    {
        return targetShape switch
        {
            ShapeType.Circle => GenerateCircleVertices(),    // 12 顶点
            ShapeType.Square => GenerateSquareVertices(),    // 4 顶点
            ShapeType.Triangle => GenerateTriangleVertices(), // 3 顶点，支持方向
            ShapeType.Pentagon => GeneratePentagonVertices(), // 5 顶点，支持方向
            ShapeType.Hexagon => GenerateHexagonVertices(),   // 6 顶点
            ShapeType.Octagon => GenerateOctagonVertices(),   // 8 顶点
            _ => GenerateCircleVertices()
        };
    }
}
```

支持自定义 Spline 形状，使用 Catmull-Rom 插值：

```csharp
private Vector2 CatmullRomInterpolate(Vector2 p0, Vector2 p1, Vector2 p2, Vector2 p3, float t)
{
    float t2 = t * t;
    float t3 = t2 * t;

    return 0.5f * (
        (2 * p1) +
        (-p0 + p2) * t +
        (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
        (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    );
}
```

### 点生成模式

两种填充模式在形状边界内生成点：

| 模式 | 算法 | 参数 |
|------|------|------|
| `Grid` | 网格点阵，裁剪到形状内 | `gridRows`, `gridColumns`, `rowSpacing`, `columnSpacing` |
| `Radiant` | 从中心向外辐射 | `degree`, `pointSpacing`, `innerRadius` |

```csharp
private List<Vector2> GenerateGridPoints()
{
    for (int row = 0; row < gridRows; row++)
    {
        for (int col = 0; col < gridColumns; col++)
        {
            Vector2 point = new Vector2(startX + col * columnSpacing, startY + row * rowSpacing);
            point = RotatePoint(point, intersectRotation);
            point += intersectOffset;

            if (IsPointInShape(point))  // PolygonCollider2D.OverlapPoint
                points.Add(point);
        }
    }
}
```

### FormationData 资源

配置完成后保存为 ScriptableObject：

```csharp
[CreateAssetMenu(fileName = "NewFormation", menuName = "GameplayDesignUtilities/Formation Data")]
public class FormationData : ScriptableObject
{
    public FormationBuilder.ShapeType shapeType;
    public float radius;
    public FormationBuilder.IntersectType intersectType;
    public List<Vector2> pointPositions;  // 按距离中心排序

    public List<Vector2> GetFormationPositions() => pointPositions ?? new List<Vector2>();
}
```

## 集成工作流

设计师创建阵型 → 配置波次 → 运行时执行：

```
1. FormationBuilder 工具
   ↓ 调整形状、点模式
   ↓ SaveFormationToAsset()
   ↓

2. FormationData 资源
   ↓ 分配给 Wave.SpawnGroup.formation
   ↓

3. LevelFlow 资源
   ↓ 分配给 EnhancedLevelWavesManager
   ↓

4. 运行时
   ↓ FormationSpawner.GetSpawnPosition()
   ↓ 按阵型位置循环生成敌人
```

## 命名空间分布

| 代码 | 命名空间 | 原因 |
|------|----------|------|
| `LevelFlow`, `Wave`, `FormationData` | `GameplayDesignUtilities` | 可复用的数据结构 |
| `WaveTriggerCondition`, `IEnemySpawner` | `GameplayDesignUtilities` | 接口和工厂 |
| `SpawnPointManager` | `GameplayDesignUtilities` | 独立工具组件 |
| `FormationBuilder` | `GameplayDesignUtilities` | 编辑器工具 |
| `EnhancedLevelWavesManager` | `ProjectOriental2D` | 项目特定实现 |
| `InternalObjectPooler` | `ProjectOriental2D` | 项目特定实现 |

数据结构放在 `GameplayDesignUtilities` 以便复用，运行时管理器放在 `ProjectOriental2D` 作为项目特定逻辑。

## 编辑器集成

自定义编辑器提供优化界面：

```csharp
[CustomEditor(typeof(Wave))]
public class WaveEditor : Editor
{
    public override void OnInspectorGUI()
    {
        // 自定义 SpawnGroup 绘制
        // 带删除按钮的分组显示
        // 浮点数显示为文本框（解决 Slider 滑动条问题）
    }
}
```

FormationBuilder 编辑器支持 Scene 视图交互：

```csharp
private void OnSceneGUI()
{
    // Ctrl+点击添加 Spline 控制点
    if (Event.current.type == EventType.MouseDown && Event.current.button == 0 && Event.current.control)
    {
        // Raycast 添加点
    }

    // Handles.FreeMoveHandle 拖动控制点
}
```

## 设计原则

1. **数据驱动**：所有配置通过 ScriptableObject，无需编程
2. **可视化预览**：Scene 视图实时 Gizmos，所见即所得
3. **策略模式**：触发条件和生成策略可独立扩展
4. **工厂创建**：`WaveTriggerConditionFactory` 和 `EnemySpawnerFactory` 统一创建逻辑
5. **编辑器友好**：自定义 Inspector、快捷键操作、一键保存资源

## 扩展点

添加新触发条件：

```csharp
[System.Serializable]
public class CustomTriggerCondition : IWaveTriggerCondition
{
    public bool ShouldTrigger(...) { /* 你的逻辑 */ }
    public float GetTriggerDelay() { /* ... */ }
    public string GetTriggerDescription() { /* ... */ }
}

// 在 Wave.WaveTriggerType 添加枚举值
// 在 WaveTriggerConditionFactory.CreateTriggerCondition 添加 case
```

添加新生成策略：

```csharp
[System.Serializable]
public class CustomSpawner : IEnemySpawner
{
    public Vector2 GetSpawnPosition(...) { /* 你的逻辑 */ }
    public string GetSpawnDescription() { /* ... */ }
}

// 在 Wave.SpawnGroup.SpawnType 添加枚举值
// 在 EnemySpawnerFactory.CreateSpawner 添加 case
```

---

**相关文档**:
- [EnhancedLevelWavesManager 使用说明](/Plugins/GamePlayDesignUtilities/WaveCreator/EnhancedLevelWavesManager_README.md)
- [FormationBuilder 使用说明](/Plugins/GamePlayDesignUtilities/FormationBuilder/README.md)
