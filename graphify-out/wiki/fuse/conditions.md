# Fuse 条件系统

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `BaseCondition` | 14 | 所有条件的基类 |
| `CheckVariable` | 17 | 变量检查条件 |
| `ComparisonOperator` | 17 | 比较运算符枚举 |

## ComparisonOperator 枚举

| 值 | 说明 |
|----|------|
| `EQUALS` | 等于 |
| `NOT_EQUALS` | 不等于 |
| `GREATER_THAN` | 大于 |
| `LESS_THAN` | 小于 |
| `GREATER_OR_EQUALS` | 大于等于 |
| `LESS_OR_EQUALS` | 小于等于 |

## 社区结构

Community 14 (~93 nodes) 包含:
- BaseCondition 基类
- FuseLocalization 本地化
- VariableOperations 变量操作

Community 17 (~77 nodes) 包含:
- CheckVariable
- ComparisonOperator

## 使用示例

```gdscript
# Fuse 条件指令通常返回 ExecutionStatus
func evaluate(context: ExecutionContext) -> ExecutionStatus:
    pass
```

## 查询示例

```bash
graphify explain "BaseCondition"
graphify path "BaseCondition" "CheckVariable"
```