> 🌐 中文 | [**English**](../../../en_US/user_docs/guides/22-dictionary-operations-guide.md)

# Dictionary 操作指南

Fuse 提供 16 个 Dictionary 操作指令，涵盖键值对增删、嵌套路径访问、JSON 转换和数学运算等场景。

## 指令总览

### 基础操作

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| DictSetKeyValue | 设置键值对（不存在则自动创建字典） | 字典来源、键、值 |
| DictGetValue | 获取指定键的值（支持默认值） | 字典来源、键、默认值、目标变量 |
| DictRemoveKey | 移除指定键（不存在仅警告） | 字典来源、键 |
| DictClear | 清空所有键值对 | 字典来源 |
| DictSize | 获取键值对数量 | 字典来源、目标变量 |
| DictDuplicate | 创建深拷贝或浅拷贝 | 字典来源、是否深拷贝、目标变量 |

### 批量操作

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| DictGetKeys | 获取所有键组成的数组 | 字典来源、目标变量 |
| DictGetValues | 获取所有值组成的数组 | 字典来源、目标变量 |
| DictMerge | 合并源字典到目标字典 | 目标字典、源字典、是否覆盖已存在键 |

### 嵌套路径访问

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| DictGetByPath | 通过嵌套路径获取值 | 字典来源、路径、默认值、目标变量 |
| DictSetByPath | 通过嵌套路径设置值 | 字典来源、路径、新值 |

路径格式: `"player/stats/hp"` 等同于 `dict["player"]["stats"]["hp"]`

### 数值运算

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| DictModifyNumber | 对数值键进行加/减操作 | 字典来源、键、操作数（正数加、负数减） |
| DictMathOp | 对数值键进行乘/除/取模 | 字典来源、键、运算类型、运算数 |
| DictToggleBoolean | 切换布尔键（true/false 互换） | 字典来源、键 |

### JSON 转换

| 指令 | 功能 | 关键参数 |
|------|------|----------|
| DictToJson | 字典转 JSON 字符串 | 字典来源、是否格式化、目标变量 |
| DictFromJson | JSON 字符串解析为字典 | JSON 来源、目标变量 |

## 常见用例

### 1. 玩家数据管理

```
初始化 → DictSetKeyValue(玩家数据, "name", "勇者")
         DictSetKeyValue(玩家数据, "level", 1)
         DictSetKeyValue(玩家数据, "hp", 100)

升级 → DictModifyNumber(玩家数据, "level", +1)
       DictSetKeyValue(玩家数据, "hp", 最大HP)

存档 → DictToJson(玩家数据) → SaveGlobalVariables
读档 → LoadGlobalVariables → DictFromJson → DictGetValue
```

### 2. 游戏配置表

```
加载配置 → DictFromJson(配置JSON) → 存入配置字典
读取难度 → DictGetByPath(配置字典, "settings/difficulty")
修改设置 → DictSetByPath(配置字典, "settings/difficulty", "hard")
保存 → DictToJson(配置字典) → 写入文件
```

### 3. 物品栏系统

```
添加物品 → DictSetKeyValue(物品栏, 物品ID, 数量)
使用物品 → DictModifyNumber(物品栏, 物品ID, -1)
检查是否拥有 → DictGetValue(物品栏, 物品ID) > 0
物品数量为 0 → DictRemoveKey(物品栏, 物品ID)
```

## 字典来源

所有 Dict 指令支持从以下来源获取字典：
- **Scope Variable** - 作用域变量
- **Global Variable** - 全局变量

## 注意事项

- DictSetKeyValue 在字典不存在时会**自动创建**新字典
- DictGetValue 支持**默认值**参数，键不存在时返回默认值而非报错
- DictRemoveKey 在键不存在时仅记录警告，不会中断执行
- DictModifyNumber 和 DictMathOp 仅对**数值类型**键有效
- DictToggleBoolean 在键不存在时默认设置为 `true`
- DictMerge 默认不覆盖已存在的键，可通过 `overwrite_existing` 选项控制
- JSON 转换仅支持标准 JSON 类型（字符串、数值、布尔、数组、字典、null）
