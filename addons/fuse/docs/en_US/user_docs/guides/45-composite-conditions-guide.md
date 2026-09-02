> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/45-composite-conditions-guide.md) | English

# Composite Conditions Guide

Fuse provides 4 composite conditions for building complex decision logic through logical combination. Composite conditions can be nested to build condition trees of arbitrary depth.

## Condition Overview

| Condition | Logic | Description |
|------|------|------|
| CheckAll | AND | Returns true when all child conditions are satisfied |
| CheckAny | OR | Returns true when any child condition is satisfied |
| CheckNot | NOT | Negates the child condition |
| CheckComposite | Custom combination | Supports custom logic combinations |

## Usage

The core parameter of a composite condition is the `conditions` array, where you can add multiple child conditions in the Inspector.

### CheckAll - All must pass

Requires **all** child conditions to return true for the whole condition to be true.

```
Use case: the character can attack
  CheckAll:
    - Condition 1: health > 0        (alive)
    - Condition 2: mana >= 10        (has mana)
    - Condition 3: not on cooldown   (skill ready)
  → all satisfied → perform the attack
```

### CheckAny - Any one passes

If **any one** child condition returns true, the whole condition is true.

```
Use case: the player dies
  CheckAny:
    - Condition 1: health <= 0
    - Condition 2: fell off screen
    - Condition 3: timed out
  → any satisfied → game over
```

### CheckNot - Logical negation

Negates the result of the child condition.

```
Use case: the enemy is out of sight
  CheckNot:
    - Condition: distance to player < sight range
  → a true result means "the enemy is out of sight"
```

### CheckComposite - Custom combination

Supports more flexible combination modes, useful for building complex condition trees.

```
Use case: complex combat state evaluation
  CheckComposite:
    - custom combination logic
```

## Nested Combination

Composite conditions **support nesting**: a composite condition can be placed inside child conditions to build arbitrarily complex logic.

### Example: Smart enemy seeking

```
CheckAll:
  - CheckAny:                           # enemy state
    - health > 0                          (alive)
    - respawning                          (can be revived)
  - CheckNot:                            # not invincible
    - invincibility time > 0
  - CheckAny:                           # distance conditions
    - distance < attack range
    - CheckNot:                          # and not on cooldown
      - cooldown time > 0
```

### Example: Picking up items

```
CheckAll:
  - item within range
  - CheckNot:                           # inventory not full
    - inventory size >= max capacity
  - CheckAny:                           # item type allowed
    - item type == "Weapon"
    - item type == "Armor"
    - item type == "Consumable"
```

## Notes

- CheckAll returns immediately at the first false (short-circuit evaluation) and does not evaluate the remaining conditions
- CheckAny returns immediately at the first true (short-circuit evaluation) and does not evaluate the remaining conditions
- Excessively deep nesting can hurt readability; consider splitting complex conditions into multiple layers
- All composite conditions support batch evaluation (`validate_batch` / `check_batch`) for performance optimization in multi-Trigger scenarios
