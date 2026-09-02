> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/23-flow-control-guide.md) | English

# Flow Control Guide

Fuse provides 14 flow control instructions for implementing conditional branching, loops, game pausing, nested instruction invocation, and similar logic.

## Instruction Overview

### Conditional Branching

| Instruction | Function | Key parameters |
|------|------|----------|
| IfThen | Executes sub-instructions when the condition is true (single branch) | condition, sub-instruction list |
| IfElse | Executes different instructions for true/false conditions (dual branch) | condition, true branch, false branch |
| RunConditionCheck | Runs a condition check; supports "on pass / on fail" modes | condition, check mode, sub-instructions |

### Loops

| Instruction | Function | Key parameters |
|------|------|----------|
| ForLoop | Counting loop (from start to end with a given step size) | start value, end value, step, loop body |
| ForEach | Iterates over each element of an array/group | array source, loop body, current element variable |
| WhileLoop | Condition loop (keeps executing while the condition is true) | condition, loop body |
| Count | Counter (accumulates on each trigger; executes when the target value is reached) | start value, target value, step, on-reached |
| BreakLoop | Breaks out of the current loop | No parameters |
| ContinueLoop | Skips the current iteration and moves to the next one | No parameters |

### Waiting

| Instruction | Function | Key parameters |
|------|------|----------|
| Wait | Waits for the given number of seconds | wait time (seconds) |
| WaitUntil | Waits until the condition is true (polling check) | condition, check interval |

### Game Control

| Instruction | Function | Key parameters |
|------|------|----------|
| PauseGame | Pauses the game (pauses the scene tree) | No parameters |
| ResumeGame | Resumes the game | No parameters |

### Advanced Invocation

| Instruction | Function | Key parameters |
|------|------|----------|
| RunRunner | Triggers another ActionRunner to execute | target ActionRunner resource |

## Common Use Cases

### 1. Enemy AI Decision-Making

```
OnProcess (every frame)
  → IfThen(distance to player < 200)
      → Chase the player
  → IfElse(health <= 30%)
      → True branch: flee
      → False branch: attack
```

### 2. Wave Spawning System

```
Game start → Count(wave counter, start=1, target=5)
  → Per wave: ForLoop(i, 1, enemy count)
      → Spawn an enemy at a random position
  → Wait(3 seconds)
  → Next wave
```

### 3. Pause Menu

```
OnInputKey(ESC)
  → IfThen(game not paused)
      → PauseGame
      → Show the pause menu
  → IfThen(game already paused)
      → ResumeGame
      → Hide the pause menu
```

### 4. Iterating Over All Enemies

```
ForEach(enemy group)
  → Current element stored in variable "current enemy"
  → SetPosition(current enemy, random position)
  → IfThen(current enemy.health <= 0)
      → BreakLoop
```

## Notes

- The condition parameter of IfThen / IfElse requires a Condition resource
- ForEach can obtain the array in three ways: from **variables, node children, or node groups**
- BreakLoop / ContinueLoop only affect the **innermost current loop**
- RunRunner enables instruction reuse by extracting shared logic into a separate ActionRunner
- Wait is an **asynchronous** instruction; subsequent instructions continue executing after the wait finishes
- WhileLoop must ensure the loop condition eventually becomes false, otherwise it will loop forever
- Difference between Count and ForLoop: Count is an event-driven accumulator, while ForLoop is a loop that runs to completion in one go
