> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/21-array-operations-guide.md) | English

# Array Operations Guide

Fuse provides 18 Array operation instructions covering element insertion/removal, lookup, sorting, numeric statistics, and vector math. Most instructions support negative indices (counting from the end).

## Instruction Overview

### Basic Operations

| Instruction | Function | Key parameters |
|------|------|----------|
| ArrayGet | Get the element at the given index | array source, index, target variable |
| ArraySet | Set the element at the given index | array source, index, new value |
| ArrayAdd | Append an element to the end (push_back) | array source, value to add |
| ArrayInsert | Insert an element at the given position | array source, insertion position, new value |
| ArrayRemove | Remove an element by index or by value | array source, removal mode (index/value) |
| ArrayClear | Clear all elements of the array | array source |
| ArraySize | Get the array size | array source, target variable |

### Lookup & Detection

| Instruction | Function | Key parameters |
|------|------|----------|
| ArrayFind | Find an element's index (returns -1 if not found) | array source, value to find, target variable |
| ArrayContains | Check whether the array contains a given element | array source, value to find, target variable |
| ArrayRandom | Get a random element | array source, target variable |

### Sorting & Reordering

| Instruction | Function | Key parameters |
|------|------|----------|
| ArrayReverse | Reverse the array (in place) | array source |
| ArrayShuffle | Shuffle randomly (Fisher-Yates algorithm) | array source |
| ArrayNumericSort | Sort a numeric array (in place) | array source, sort order (ascending/descending) |
| ArrayVectorSort | Sort a vector array by distance to a reference point | array source, reference point, sort order (near to far / far to near) |

### Numeric Statistics

| Instruction | Function | Key parameters |
|------|------|----------|
| ArrayNumericGetSmallest | Get the smallest value | array source, target variable |
| ArrayNumericGetLargest | Get the largest value | array source, target variable |

### Vector Operations

| Instruction | Function | Key parameters |
|------|------|----------|
| ArrayVectorGetClosest | Get the vector closest to the reference point | array source, reference point, target variable |
| ArrayVectorGetFurthest | Get the vector furthest from the reference point | array source, reference point, target variable |

## Common Use Cases

### 1. Managing an Enemy List

```
Game start → ArrayClear(enemy_list)
Enemy spawns → ArrayAdd(enemy_list, new_enemy)
Enemy dies → ArrayRemove(enemy_list, enemy)
Wave check → ArraySize(enemy_list) == 0 → trigger the next wave
Random target → ArrayRandom(enemy_list) → SetPosition
```

### 2. Leaderboard System

```
Add score → ArrayAdd(score_list, new_score)
Sort → ArrayNumericSort(score_list, descending)
Get the top score → ArrayNumericGetLargest(score_list) → display
```

### 3. Finding the Nearest Enemy

```
Get all enemies → GetNodesInGroup → store into a position array
ArrayVectorGetClosest(position_array, player_position) → nearest enemy position
LookAt(nearest_enemy_position)
```

## Array Sources

All Array instructions support three array sources:
- **Variable** - from a Scope Variable or Global Variable
- **Node children** - from the children of a target node
- **Node group** - from a group in the scene tree

## Notes

- ArrayGet / ArraySet / ArrayInsert / ArrayRemove support **negative indices** (-1 means the last element)
- ArrayNumericSort and ArrayVectorSort are **in-place sorts** that modify the original array directly
- ArrayRemove removes by index by default, and can be switched to remove by value (removes the first match)
- Numeric statistic instructions only support arrays of `int` and `float`
- Vector operation instructions support arrays of `Vector2` and `Vector3`
