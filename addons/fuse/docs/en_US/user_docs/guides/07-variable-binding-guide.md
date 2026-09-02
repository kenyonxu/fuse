> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/07-variable-binding-guide.md) | English

# Variable Binding Usage Guide

> **Goal**: explain the "dual-track" capability of Fuse instruction parameters—the same parameter can take a fixed value or be switched to read from a variable at runtime. This is the key step that turns static configuration into dynamic logic.
>
> **Audience**: Fuse plugin users

---

## What Is This?

Most instruction parameters can be filled in two ways: a **direct value** (DIRECT, a number/string/node hard-coded in the Inspector) or a **variable** (VARIABLE, read from the three-layer variable system at runtime). The same instruction therefore serves both scenarios—designers fill in direct values for fixed behavior, while logic that needs dynamic computation binds variables. One instruction does the work of two.

How to recognize it in the Inspector: an instruction whose parameter group has a `use_variable_for_xxx` checkbox supports the dual track. It appears across most instruction domains—transform, animation, UI, audio, camera, and more—and also covers a good share of condition components.

## What It Looks Like in the Inspector

Take `SetScale` (set scale) as an example:

```
☑ use_variable_for_target     ← unchecked: target directly picks a node
                                 checked: target_variable (variable name) + target_scope (scope) appear
offset: (1.0, 1.0)            ← the offset parameter itself can also have its own use_variable_for_offset track
```

Another example is `SetUIText` (set UI text): the text content can be read from a variable—health numbers, countdowns, player names; anything that changes should go through the variable track instead of writing a value and re-triggering the instruction every time.

Three key points:

1. **Independent switch per parameter**: `use_variable_for_target` and `use_variable_for_offset` do not affect each other; you can bind "position" to a variable while leaving "offset" as a fixed value.
2. **Checking the box switches the parameter area's form**: the direct-value input disappears, replaced by a variable name + scope dropdown; unchecking returns to the direct value without losing the original value.
3. **Variable names are not checked for existence at edit time**: variables are resolved at runtime; a misspelled name raises no error in the Inspector, but the value cannot be read at execution time—use the variable watcher to investigate (see the FAQ at the end).

## Choosing a Scope

Binding a variable requires choosing a scope, with the same rules as the [Variable System Guide](01-variable-system-guide.md):

| Scope | When to Use |
|--------|-----------|
| LOCAL | Default. Intermediate values stored by `SetVariable` within the current instruction sequence; gone when the sequence ends |
| GLOBAL | State shared across scenes: health, coins, progress, and other persistent data |
| SCOPE | Shared within a scene subtree: multiple Triggers under the same container read and write the same values; cleaned up automatically when the subtree is destroyed |

A practical rule of thumb: **who writes, who reads**. Writer and reader are in the same logical line → LOCAL; the writer is in another scene/system → GLOBAL; the writer is another Trigger in the same subtree → SCOPE.

## Division of Labor with the Expression System

The [expression system](05-expression-guide.md) (`MathExpression` / `StringExpression` / `ExpressionCondition`) and variable binding solve two different kinds of "dynamic":

- **Variable binding = reference**: the parameter's value **comes from** an existing variable, without processing.
- **Expressions = computation**: the parameter's value needs to be **computed** (multi-variable operations, formatting, conditional evaluation); the result can be stored back into a variable and then referenced by a binding.

The typical combination is a three-stage pipeline: an expression computes the result → `SetVariable` stores it → downstream instructions bind their parameters to that variable. For on-the-spot computation, just use the expression's output directly—no need to detour through a variable.

## Relationship with the Instruction Generator

When the [instruction generator](06-instruction-generator-guide.md) generates instructions for your custom node methods, you can check "Use Variables" to produce the **variable-binding version**—the generated instructions carry the same `use_variable_for_xxx` tracks and behave exactly like built-in instructions' dual track. Built-in vs generated, direct value vs variable—all four quadrants are isomorphic in this system.

## FAQ

### Bound a Variable but No Value Comes Through?

Nine times out of ten the scope is wrong: the variable is in GLOBAL, but LOCAL was chosen when binding. First use the [variable watcher](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) (editor bottom dock, tabs per scope) to confirm which layer the variable actually lives in, then come back and align the scope dropdown.

### Runtime Reports "Variable Not Found" but the Watcher Shows It?

Check that the spelling and scope match exactly; if the variable is created during execution, confirm that the binding instruction runs after `CreateVariable` / `SetVariable`.

### Switching Back and Forth Between Direct Value and Variable—Which One Takes Effect?

The checkbox's current state decides: checked = read the variable at runtime (the direct value is ignored); unchecked = use the direct value. Both configurations are kept; switching is non-destructive.

---

**Related docs:**

- [Variable System Guide](01-variable-system-guide.md) —— full rules of the three-layer variables
- [Expression System Usage Guide](05-expression-guide.md) —— computed dynamic sources
- [Instruction Generator Usage Guide](06-instruction-generator-guide.md) —— generating the variable-binding version of instructions
- [Variable Watcher Guide](../../../zh_CN/user_docs/guides/56-variable-watcher-guide.md) —— the first-choice tool for runtime variable troubleshooting
