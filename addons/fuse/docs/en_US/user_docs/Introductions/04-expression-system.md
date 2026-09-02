> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/04-表达式系统.md) | English

# Damage Formulas Without Writing a Line of Code: Fuse's Expression System in Practice

By the end of this chapter you will have mastered the most "code-like" part of Fuse that never touches code — the expression engine. An RPG's damage settlement `(attack - defense) * crit multiplier`, a floating text `"-15 HP"`, an ASCII progress bar `[####----] 45%`, a grade check `score > 90 ? "S" : "A"` — in traditional visual tools these either require a long pipeline of "add node → subtract node → multiply node → condition node", or simply can't be built and you fall back to a `.gd` file. Fuse solves this in one stroke with the **MathExpression / StringExpression / ExpressionCondition trio** plus a unified `{local:hp}` variable reference syntax. This is precisely the core moat separating it from similar visual tools, so this chapter gets extra depth.

Carrying over from the previous chapter: we just finished the LOCAL / SCOPE / GLOBAL three-layer variables. Variables solve "where data lives", but variables are only a warehouse; what truly sets data in motion — computing damage, composing text, making judgments — is computation, and computation's ultimate form is the expression.

## Why Expressions Are the Litmus Test for Visual Programming Systems

Start with a pain point most people only discover after stepping on it. In visual programming tools, "actions" like assigning values, moving, and playing animations are all easy; but the moment a slightly math-flavored piece of logic appears, the experience falls off a cliff.

Take a real scenario: you need to compute final damage, formula `(attack - defense) * crit_multiplier`, where the crit multiplier also requires a random roll first. In a pure node-based tool, that means dragging in three operator nodes, wiring them, then a random number node, a comparison node, a select node… just to compute one damage value, your screen is crawling with a dozen-plus nodes. Strings are even more annoying: to compose the damage into `"-15 HP"` for floating text, you drag another string of "string concat" nodes. Once the logic gets slightly complex, the visual graph smears into mush — harder to read than code.

Fuse's solution is direct: **put a complete mathematical expression into a single component**. Fill one line — `(attack - defense) * crit_multiplier` — in the Inspector; underneath it calls Godot engine's built-in `Expression` evaluation engine, so the syntax you write and the functions available are almost exactly the same as in GDScript — the only difference being that this line doesn't go into a `.gd`, needs no compilation, and takes effect immediately after editing.

This is not a "barely usable" calculator — it's, in my view, the most cleanly designed and most deserving of its own chapter among Fuse's trio of strengths. It has three features that genuinely constitute a moat; I'll cover the usage first, then give them dedicated weight at the end.

## The Trio: A Formula, a Text, and a Judgment

Fuse's expression system has exactly three components, with crystal-clear division of labor:

| Component | Type | What it does | Output |
|------|------|--------|------|
| **MathExpression** | Instruction | Evaluates a math formula | Float / Int / Vector2 / Vector3 |
| **StringExpression** | Instruction | Composes and formats text | String |
| **ExpressionCondition** | Condition | Evaluates a boolean judgment | bool |

Note their categorization: the first two are instructions (Instruction — answering "what to do"), the last is a condition (Condition — answering "under what condition to do"). All three run on the same expression engine underneath, so **the variable reference syntax is completely identical** — that's moat feature number one; hold that thought, we'll expand later.

They all live in the Inspector's Math category, with a `Code` icon. Add a MathExpression to your instruction list and you'll see an `expression` text box, an `output type` dropdown, and a `save to variable` plus `save to scope` output configuration. StringExpression and ExpressionCondition have similar panels.

## Unified Variable Reference Syntax: One Key Shared by All Three

This is the most important thing to remember in the whole chapter. All three components reference variables with the same curly-brace notation:

```
{local:hp}        # local variable (on the ExecutionContext)
{scope:name}      # scope variable (on the VariableScopeContainer)
{global:max_hp}   # global variable
```

The variable naming rules are conventional: start with a letter or underscore, contain only letters, digits, and underscores. `{local:hp}`, `{scope:player_name}`, `{global:max_count}` are all valid; `{local:123}`, `{scope:player-name}` (with a hyphen), `{global:player name}` (with a space) are not.

Why is "unified" a moat? Because it means the `{local:attack}` you reference in a damage formula and the `{local:attack}` you reference while composing floating text in a StringExpression are the same variable, written the same way. You don't learn two variable addressing schemes between "math nodes" and "text nodes", and you never worry about mismatched data types.

When the expression contains `{scope:xxx}`, you must also tell it which scope container to fetch from. Fuse provides four `scope_source` options:

| Source | Description |
|------|------|
| Nearest | The nearest scope container (default) |
| Custom ID | Specify a scope_id |
| Trigger Scope | The scope on the Trigger node itself |
| Target Node | The scope along the target node's path |

This step looks redundant but is actually a reflection of the rigor of Fuse's scope model — scope variables can hang on many containers, and the engine needs to know which one you mean.

## MathExpression: A Damage Formula in One Line

MathExpression handles math, storing the result into a variable in the scope you specify.

Its arithmetic operators and functions are nearly identical to GDScript's. Arithmetic has `+ - * / %` and parentheses; the functions are directly Godot's built-ins:

```
abs(-5)          # absolute value → 5.0
min(3, 7)        # minimum → 3.0
max(3, 7)        # maximum → 7.0
round(3.6)       # round to nearest → 4.0
floor(3.6)       # round down → 3.0
ceil(3.2)        # round up → 4.0
sqrt(16)         # square root → 4.0
pow(2, 3)        # power → 8.0
clamp(5, 0, 10)  # clamp → 5.0
sin(0)           # sine (radians)
```

**Practical example 1: damage calculation.** The complete expression for the formula `(attack - defense) * multiplier`:

```
Expression:    ({local:attack} - {local:defense}) * {local:multiplier}
Output type:   Float
Save to:       damage (Local)
```

Just that one line. If `attack=20, defense=5, multiplier=2`, the result is `damage=30.0`. No dragging three operator nodes, no drawing three wires.

**Practical example 2: HP normalization.** For a percentage health bar, map `hp` from `0~max_hp` to `0~1`:

```
Expression:    remap({local:hp}, 0, {local:max_hp}, 0, 1)
Output type:   Float
Save to:       hp_ratio (Local)
```

Note the use of `remap` here. This is not a Godot built-in — it's one of the **game extension functions** Fuse injects into the expression engine. That's moat feature number two, covered separately below. Beyond it, the commonly used extension functions include:

| Function | Purpose | Example |
|------|------|------|
| `vec2(x, y)` / `vec3(x,y,z)` | Construct vectors | `vec2({local:x}, {local:y})` |
| `normalize(v)` | Normalize | `normalize({local:vel})` |
| `distance(a, b)` | Distance between two points | `distance(vec2(0,0), {local:pos})` |
| `direction(a, b)` | Direction vector | `direction(vec2(0,0), {local:target})` |
| `remap(v, a, b, c, d)` | Remap value range | `remap({local:hp}, 0, 100, 0, 1)` |
| `inverse_lerp(a, b, v)` | Inverse lerp | `inverse_lerp(0, 10, {local:hp})` |
| `snap(v, step)` | Snap to step | `snap({local:x}, 0.5)` |
| `format_num(v, d)` | Number formatting | `format_num(3.14159, 2)` → `"3.14"` |
| `pad_left(s, len, c)` | Left padding | `pad_left("42", 6, "0")` → `"000042"` |

MathExpression also supports four output types: Float (default), Int (truncates decimals), Vector2, Vector3. The vector types accept constructors like `vec2(1, 2)`, which pairs with `direction()` to compute movement direction:

```
Expression:    direction(vec2(0, 0), vec2({local:tx}, {local:ty}))
Output type:   Vector2
Save to:       move_dir (Local)
```

## StringExpression: Floating Text, Progress Bars, and Zero Padding Are All Concatenation

StringExpression handles text exclusively, and its output is always a String. Its core capabilities are "variable interpolation + concatenation + formatting functions".

**Practical example 3: damage floating text.** After a hit, float `-15 HP` above the character's head:

```
Expression:    "-" + str({local:damage}) + " HP"
Save to:       damage_text (Local)
```

One pitfall to remember here: in StringExpression, numeric variables **cannot be added to strings directly** — you must wrap them in `str()`. `str({local:damage})` converts the number to text, and then you concatenate. String variables (like a player name) can be used directly: `{local:player_name} + " joined"`.

**Practical example 4: progress bar text.** To draw a `[####------] 40%` progress bar on the console or a plain-text Label, use `pad_left`:

```
Expression:    "[" + pad_left("", {local:percent}, "#") + pad_left("", 100 - {local:percent}, "-") + "] " + str({local:percent}) + "%"
Save to:       progress_bar (Local)
```

With `percent=40`, the result is `[####------+...] 40%`. `pad_left("", n, "#")` means "pad characters on the left of the empty string until the length is n" — here it's cleverly used to generate n hash marks. Even pure code would take a couple of twists to do this; in Fuse it's one line.

**Practical example 5: level zero-padding.** For displaying levels in a zero-padded format like `Lv.005`:

```
Expression:    "Lv." + pad_left(str({local:level}), 3, "0")
Save to:       level_text (Local)
```

`level=5` → `"Lv.005"`, `level=42` → `"Lv.042"`. Zero-padding, slot-filling, right-alignment — all in the `pad_left` / `pad_right` family.

StringExpression also supports ternary operations, which leads to the third practical direction — conditional text.

## ExpressionCondition: Judgments in One Line Too

ExpressionCondition is a condition, and its output must be a boolean. Its operators are comparisons (`> >= < <= == !=`) and logic (`and or not`), and combined they can express fairly complex judgments.

**Practical example 6: score grading.** This is the example from the chapter opening — S/A/B grading with nested ternaries. But note: in ExpressionCondition, the ternary must be written in Godot style, `a if cond else b`. If you only want to generate "grade text", StringExpression with the C-style ternary is the better fit:

```
# In a StringExpression (generating text)
Expression:    {local:score} > 90 ? "S" : ({local:score} > 70 ? "A" : "B")
```

`score=85` → `"A"`, `score=95` → `"S"`, `score=50` → `"B"`. One expression handles three grade tiers — no nesting three IfElse blocks.

If what you want is "judge whether satisfied", use ExpressionCondition:

```
# In an ExpressionCondition (judging a boolean)
Expression:    {local:mp} >= {local:skill_cost} and not {local:silenced} and {local:cooldown} <= 0
```

This one line expresses the composite judgment "enough mana, not silenced, cooldown ready" required to cast a skill. The style is identical to a GDScript `if` condition. Expressions whose result isn't a boolean (say, `{local:hp} + {local:mp}`) raise an error and return false, so always include a comparison operator.

## A Runnable Example: The Complete Damage Settlement Chain

Stringing the pieces above together, let's build a damage settlement that actually runs in a scene. The scene has an enemy node carrying a Trigger, fired by OnHealthChanged or a hit signal. The instruction sequence:

1. **RandomNumber** — roll for crit: range `[0.0, 1.0]`, stored to `crit_roll`.
2. **MathExpression** — set the crit multiplier: `{local:crit_roll} < {local:crit_chance} ? 2.0 : 1.0`, stored to `multiplier`.
3. **MathExpression** — compute final damage: `({local:attack} - {local:defense}) * {local:multiplier}`, stored to `damage`.
4. **ClampValue** — damage floor: clamp `damage` to `[1, 9999]`.
5. **MathExpression** — deduct health: `{local:hp} - {local:damage}`, stored back to `hp`.
6. **StringExpression** — compose floating text: `"-" + str({local:damage}) + " HP"`, stored to `damage_text`.
7. **SetUIText** — display `damage_text` on the overhead Label.

Run the scene, take a hit, and the floating text pops out as `-15 HP` — or `-30 HP` on a crit. The whole process never opened a `.gd` file and never dragged a single node wire. That's the power of the expression trio: of the seven instructions, four have one-line expressions at their core.

## The Moat, Expanded: Three Designs That Set Fuse's Expressions Apart

This is a moat chapter; the features were mentioned in passing above — here they're pulled out and given extra weight, because they are what truly puts Fuse's expression system ahead of similar tools.

**Moat feature one: unified variable reference syntax.** As noted, the trio shares the `{local:hp}` `{scope:name}` `{global:max}` notation. Learn the syntax once and it works across math computation, text composition, and condition judgment. Many visual tools give their "math nodes" and "string nodes" different variable addressing schemes, and data flowing between nodes still needs extra wiring — in Fuse you just write curly braces, and the engine fetches values from the three-layer scopes itself. That's compound interest from design consistency.

**Moat feature two: the game extension function library.** Godot's `Expression` engine only exposes basic math functions. On top of the engine, Fuse injects a batch of functions designed for game scenarios: `vec2` / `vec3` construct vectors, `normalize` normalizes, `distance` / `direction` compute distance and direction, `remap` / `inverse_lerp` map value ranges, `snap` aligns to steps, and `format_num` / `pad_left` / `pad_right` format output. None of these can be written in pure Godot Expression — you'd have to go back to hand-written code. Fuse lays them directly into the expression sandbox, which is why you can finish HP normalization, damage floating text, and level zero-padding in one Inspector line each.

**Moat feature three: safe degradation — one missing variable never crashes anything.** An easily underestimated but practically vital feature. If an expression references `{local:hp}` but `hp` hasn't been created yet, the engine does **not** throw an exception and abort the instruction chain; in a math context it substitutes `0`, keeps computing, and just logs a warning. So an initialization-order timing issue can never crash your whole damage settlement. In a string context it substitutes an empty string; in a boolean context, false. Of course, if you truly want to guarantee a variable exists, pair with `SetVariable` or `CreateVariable` to initialize first — but the default safe degradation keeps rapid prototyping from being wrecked by nulls.

Stack these three together, and Fuse's expressions aren't just "able to add and subtract" — they can "write real game logic formulas inside a visual environment".

## Common Pitfalls

A few details worth noting when writing expressions — they'll save you detours:

String literals must be quoted. `{local:state} == "idle"` is correct; `{local:state} == idle` treats `idle` as a variable name to look up, and the result is always not-equal. In string concatenation, `"Hello" + " " + "World"` needs quotes; `Hello + World` doesn't work.

Division by zero doesn't crash, but yields `inf` or `nan`. To avoid it, wrap in a ternary: `{local:b} != 0 ? {local:a} / {local:b} : 0`.

`move_toward_val` rather than `move_toward`. Godot Expression's built-ins already occupy the name `move_toward`, so Fuse's extended version takes the `_val` suffix to avoid the clash — same functionality, but with automatic type conversion added.

Result saving offers all three scopes — Local / Scope / Global; choosing Scope surfaces an extra `save_scope_source`, used the same way as when reading.

## Next Chapter: Give Your Logic Branches and Loops

Expressions solve "how to compute", but real game logic is more than formulas — there's also "flee if health drops below 30%", "spawn 5 enemies each wave", "iterate all enemies checking whether they're all dead". These are flow control's job, requiring If, loops, arrays, and dictionaries.

**In the next chapter, I'll cover Fuse's flow control and data structures in depth: how IfElse / ForLoop / WhileLoop build branches and loops, how the 18 array operations and 16 dictionary operations manage collection data, and why "a visual system can still write real logic".** At that point, Fuse's logical skeleton is thoroughly complete.
