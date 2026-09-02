> 🌐 [**中文版**](../../../zh_CN/user_docs/guides/06-instruction-generator-guide.md) | English

# Instruction Generator Usage Guide

Automatically generate Fuse instructions by right-clicking a scene tree node. Pick a method or property of the node and one-click generate a ready-to-use instruction file—no hand-written code needed.

## Quick Start

1. **Right-click** any node in the scene tree
2. Choose **"Generate Instructions..."**
3. Pick a method or property in the dialog
4. Click **"Generate Instructions"**

Generated instructions are registered with the Fuse system automatically and can be found under the **"User Generated"** category in the instruction selector.

---

## Dialog Interface

The dialog title shows the target node's name and class, e.g. "Generate instructions for Player (CharacterBody2D)".

The interface has two tabs:

### Methods Tab

Browse all available methods of the node. Methods are grouped by inheritance chain, subclasses first.

```
▸ CharacterBody2D (5)
    ▸ move_and_slide
    ▸ velocity
▸ Node2D (12)
    ▸ global_position
    ▸ look_at
    ▸ rotate
```

After selecting a method, the info panel on the right shows the method signature, defining class, and parameter list.

### Properties Tab

Browse all writable properties of the node, also grouped by inheritance chain.

After selecting a property, the info panel on the right shows the property type, hint type, default value, and range (for numeric types).

The bottom offers three generation modes:

| Mode | Description |
|------|------|
| SET | Generates an instruction that sets the property value |
| GET | Generates an instruction that reads the property value into a variable |
| Generate Both | Generates both a SET and a GET instruction |

---

## Generation Options

### Use Variables

The **"Use Variables"** checkbox at the bottom of the dialog controls where parameter values come from.

**Unchecked** — generates the direct-value version. Parameter values are entered directly in the Inspector:

```gdscript
# Direct-value version — speed_scale is set to a fixed value in the Inspector
@export var speed_scale_value: float = 1.0

func execute(context: ExecutionContext):
    node.speed_scale = speed_scale_value
```

**Checked** — generates the variable-binding version. Each parameter supports two sources:

| Source | Description |
|------|------|
| Direct value | A fixed value entered in the Inspector |
| Variable | The value is read from a variable at runtime |

After choosing the "Variable" source, you can specify the variable name and scope:

| Scope | Description |
|--------|------|
| Local | Reads a local variable |
| Global | Reads a global variable |
| Scope | Reads a scope variable |

The Scope scope supports four source locations:

| Source | Description |
|------|------|
| Nearest | Uses the nearest scope container |
| Custom ID | Specifies a custom scope ID |
| Trigger Scope | Uses the scope of the trigger |
| Target Node | Specifies the path of a target node |

In the Inspector, the variable-binding version's properties are shown and hidden dynamically according to the choice—choosing "Direct value" hides the variable-related fields, choosing "Variable" hides the direct-value field. This is exactly the same dual-track behavior as built-in instructions; see the [Variable Binding Usage Guide](07-variable-binding-guide.md) for the general mechanism.

### Variable Binding in the Methods Tab

Generates source options independently for each method parameter. For example, `AnimatedSprite2D.play(name, custom_speed, from_end)` gets a source enum plus the corresponding value/variable fields for each of its three parameters.

### Variable Binding in the Properties Tab

Only applies to SET mode. When checked, the generated SET instruction can read the property value from a variable.

GET instructions always use the variable system (because the whole point of GET is to store a value into a variable), so no extra checkbox is needed.

---

## Generated Files

### Location

All generated instructions are saved under `res://fuse_generated/instructions/`, in subdirectories named after the node class:

```
fuse_generated/instructions/
└── animatedsprite2d/
    ├── animated_sprite2d_play.gd                  # method instruction
    ├── animated_sprite2d_play_with_variable.gd     # method instruction (variable version)
    ├── set_animated_sprite2d_speed_scale.gd        # SET instruction
    ├── set_animated_sprite2d_speed_scale_with_variable.gd  # SET instruction (variable version)
    └── get_animated_sprite2d_speed_scale.gd        # GET instruction
```

### File Naming Rules

| Instruction Type | Naming Format |
|----------|---------|
| Method | `{class_name}_{method_name}.gd` |
| Method (variable version) | `{class_name}_{method_name}_with_variable.gd` |
| SET property | `set_{class_name}_{property_name}.gd` |
| SET property (variable version) | `set_{class_name}_{property_name}_with_variable.gd` |
| GET property | `get_{class_name}_{property_name}.gd` |

### Automatic Registration

After generation, instructions are registered with the InstructionRegistry automatically—no manual action needed. On editor restart, the `fuse_generated/instructions/` directory is rescanned and all generated instructions are loaded.

---

## File Conflicts

If the target file already exists (an instruction with the same name was generated before), clicking "Generate Instructions" pops up a confirmation dialog:

```
The following instruction files already exist:
  res://fuse_generated/instructions/.../xxx.gd
Overwrite?
```

- **Confirm** — overwrite the existing file
- **Skip** — cancel the operation

---

## Instruction Types in Detail

### Method Instructions

Call a specific method of the node.

**Inspector configuration:**
- `target_node` — path of the target node
- Each parameter — one per method parameter, with types and defaults matching the method signature

**Methods with return values** additionally provide:
- `result_variable` — variable name to store the return value (optional)
- `result_variable_scope` — storage scope (Local / Scope / Global)

### SET Property Instructions

Set a node's property value.

**Direct-value version:**
- `target_node` — target node path
- `{property_name}_value` — the value to set, with a type matching the property

**Variable-binding version:**
- `target_node` — target node path
- `{property_name}_source` — "Direct value" or "Variable"
- `{property_name}_value` — input for direct-value mode
- `{property_name}_variable` — variable name
- `{property_name}_scope` — variable scope

### GET Property Instructions

Read a node's property value into a variable.

**Inspector configuration:**

Target category:
- `target_node` — target node path

Save To category:
- `save_to_variable` — variable name to save into
- `save_to_scope` — storage scope (Local / Scope / Global)
- `scope_source` — source location for the Scope scope (shown only when the scope is SCOPE)
- `custom_scope_id` — custom scope ID (shown only in Custom ID mode)
- `save_target_node_path` — target node path (shown only in Target Node mode)

---

## Usage Examples

### Example 1: Generating a play Method Instruction

Generate a `play()` method call for an `AnimatedSprite2D` target node:

1. Right-click the AnimatedSprite2D node → "Generate Instructions..."
2. Find `play` in the Methods tab
3. The info panel shows the signature: `play(name: StringName = &"", custom_speed: float = 0.0, from_end: bool = false)`
4. Click "Generate Instructions"

When using this instruction in a Trigger, point `target_node` at the AnimatedSprite2D node and configure the parameters.

### Example 2: Generating a SET Instruction with Variables

Read the `speed_scale` value from a variable at runtime:

1. Right-click the AnimatedSprite2D node → "Generate Instructions..."
2. Switch to the Properties tab and find `speed_scale`
3. Check **"Use Variables"**
4. Choose SET as the generation mode
5. Click "Generate Instructions"

When using it in a Trigger, set `speed_scale_source` to "Variable" and fill in the variable name and scope to read the value dynamically at runtime.

### Example 3: Generating a GET Instruction to Read Position

Store a `CharacterBody2D`'s `position` into a variable:

1. Right-click the CharacterBody2D node → "Generate Instructions..."
2. Switch to the Properties tab and find `position`
3. Choose GET as the generation mode
4. Click "Generate Instructions"

When using it in a Trigger, configure `target_node` and `save_to_variable` (e.g. "player_pos") and pick the storage scope. After running, that variable's value updates to the node's current position.

---

## Search

Both the method and property lists support search. Typing a keyword filters the list, e.g. typing "speed" quickly finds `speed_scale`, `max_speed`, and similar properties.

Search matches both property names and type names. Typing "vector" finds all properties of type Vector2/Vector3.

---

## Notes

- Generated files are marked "auto-generated"; manual edits may be overwritten the next time you generate
- Generated instructions do not use `class_name`; they are registered by file path and cause no global name conflicts
- The method list automatically filters out private, virtual, and static methods, showing only directly callable instance methods
- The property list shows only writable properties; read-only properties do not appear
- Internal properties (starting with `_`) are filtered out automatically

---

**Last updated**: 2026-03-17
