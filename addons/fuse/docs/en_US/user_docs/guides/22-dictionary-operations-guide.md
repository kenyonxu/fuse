> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/22-dictionary-operations-guide.md) | English

# Dictionary Operations Guide

Fuse provides 16 Dictionary operation instructions covering key-value insertion/removal, nested path access, JSON conversion, and math operations.

## Instruction Overview

### Basic Operations

| Instruction | Function | Key parameters |
|------|------|----------|
| DictSetKeyValue | Set a key-value pair (creates the dictionary automatically if missing) | dictionary source, key, value |
| DictGetValue | Get the value of a key (default value supported) | dictionary source, key, default value, target variable |
| DictRemoveKey | Remove a key (warns only if missing) | dictionary source, key |
| DictClear | Clear all key-value pairs | dictionary source |
| DictSize | Get the number of key-value pairs | dictionary source, target variable |
| DictDuplicate | Create a deep or shallow copy | dictionary source, deep copy or not, target variable |

### Bulk Operations

| Instruction | Function | Key parameters |
|------|------|----------|
| DictGetKeys | Get an array of all keys | dictionary source, target variable |
| DictGetValues | Get an array of all values | dictionary source, target variable |
| DictMerge | Merge the source dictionary into the target dictionary | target dictionary, source dictionary, whether to overwrite existing keys |

### Nested Path Access

| Instruction | Function | Key parameters |
|------|------|----------|
| DictGetByPath | Get a value via a nested path | dictionary source, path, default value, target variable |
| DictSetByPath | Set a value via a nested path | dictionary source, path, new value |

Path format: `"player/stats/hp"` is equivalent to `dict["player"]["stats"]["hp"]`

### Numeric Operations

| Instruction | Function | Key parameters |
|------|------|----------|
| DictModifyNumber | Add to/subtract from a numeric key | dictionary source, key, operand (positive adds, negative subtracts) |
| DictMathOp | Multiply/divide/modulo a numeric key | dictionary source, key, operation type, operand |
| DictToggleBoolean | Toggle a boolean key (true/false swap) | dictionary source, key |

### JSON Conversion

| Instruction | Function | Key parameters |
|------|------|----------|
| DictToJson | Convert a dictionary to a JSON string | dictionary source, whether to format, target variable |
| DictFromJson | Parse a JSON string into a dictionary | JSON source, target variable |

## Common Use Cases

### 1. Player Data Management

```
Initialize → DictSetKeyValue(player_data, "name", "勇者")
             DictSetKeyValue(player_data, "level", 1)
             DictSetKeyValue(player_data, "hp", 100)

Level up → DictModifyNumber(player_data, "level", +1)
           DictSetKeyValue(player_data, "hp", max HP)

Save → DictToJson(player_data) → SaveGlobalVariables
Load → LoadGlobalVariables → DictFromJson → DictGetValue
```

### 2. Game Configuration Table

```
Load config → DictFromJson(config JSON) → store into config_dict
Read difficulty → DictGetByPath(config_dict, "settings/difficulty")
Change a setting → DictSetByPath(config_dict, "settings/difficulty", "hard")
Save → DictToJson(config_dict) → write to file
```

### 3. Inventory System

```
Add item → DictSetKeyValue(inventory, item_id, quantity)
Use item → DictModifyNumber(inventory, item_id, -1)
Check ownership → DictGetValue(inventory, item_id) > 0
Quantity is 0 → DictRemoveKey(inventory, item_id)
```

## Dictionary Sources

All Dict instructions can obtain the dictionary from the following sources:
- **Scope Variable** - scope variable
- **Global Variable** - global variable

## Notes

- DictSetKeyValue **automatically creates** a new dictionary when it does not exist
- DictGetValue supports a **default value** parameter, returning the default instead of erroring when the key is missing
- DictRemoveKey only logs a warning when the key is missing, without interrupting execution
- DictModifyNumber and DictMathOp only work on keys with **numeric** values
- DictToggleBoolean defaults to setting `true` when the key does not exist
- DictMerge does not overwrite existing keys by default; control this with the `overwrite_existing` option
- JSON conversion only supports standard JSON types (string, number, boolean, array, dictionary, null)
