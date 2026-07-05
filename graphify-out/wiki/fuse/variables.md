# Fuse 变量系统

## 核心类

| 类 | 社区 | 说明 |
|----|------|------|
| `VariableContainer` | 8 | 变量容器 |
| `BaseVariable` | 15 | 变量基类 |
| `GlobalVariableAssistant` | 18 | 全局变量助手 |

## VariableScope 枚举

| 值 | 说明 |
|----|------|
| `LOCAL` | 局部变量 |
| `SCOPE` | 作用域变量 |
| `GLOBAL` | 全局变量 |

## VariableContainer

**职责**: 统一管理三层变量访问

**关键属性**:
- `_variables_data` - 统一数据源
- 8 个旧字典已废弃

**关键方法**:
- `get_variable(name, scope)` - 获取变量
- `set_variable(name, value, scope)` - 设置变量

## 社区结构

Community 8 (~98 nodes) 包含:
- VariableContainer
- VariableScope (LOCAL/SCOPE/GLOBAL)
- ScopeVariableContainer
- ScopeVariableManager

Community 15 (~92 nodes) 包含:
- BaseVariable
- variable_name, value, description

Community 18 (~74 nodes) 包含:
- GlobalVariableAssistant
- _instance 单例
- current_resource, resource_path

## 变量操作统一

`VariableOperations` 工具类统一了三层变量访问:
- LOCAL → ExecutionContext.local_variables
- SCOPE → ScopeVariableContainer
- GLOBAL → GlobalVariableAssistant

## 查询示例

```bash
graphify explain "VariableContainer"
graphify explain "GlobalVariableAssistant"
```