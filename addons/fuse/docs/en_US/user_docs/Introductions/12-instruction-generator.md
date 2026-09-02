> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/12-instruction-generator.md) | English

# Don't Want to Wait for Official Instructions? Turn Node Methods into Instructions with One Click Using the Fuse Generator

The previous chapter managed the whole game world with 22 node operation instructions, but left one problem behind: when your project is stuffed with custom nodes, each carrying a pile of proprietary methods—the character's `dash()`, the weapon's `combo_attack()`, the trap's `trigger()`—you can of course call them ad hoc with `RunTargetNodeFunction`, but every time you must fill in the method name, configure parameters, and set a return-value variable in the Inspector: repetitive, tedious, and unreadable for designers. After this chapter you'll understand why Fuse is not a "feature pile-up" plugin: it puts extension power directly into your hands. A node method you wrote becomes, with one right-click, a formal, reusable instruction resource with a parameter panel in the instruction library. You never wait for official updates again. This is Fuse's moat—the instruction generator.

## The Old Problem of Plugin Ecosystems

Traditional Godot plugins, however well made, share one ceiling: however many instructions the author provided, that's all you get. Your project has a unique "fishing minigame" node, and you want designers to call it from a Trigger—sorry, the plugin has no such instruction.

This passive "wait for the officials to ship new instructions" situation is broken in Fuse. The generator's core idea: **the nodes you write are your instruction library**. Any node's public methods and writable properties can become full members of the instruction selector after a few clicks—with categories, with icons, with parameter panels, treated exactly the same as built-in instructions.

## Entry Point: Right-Click a Scene Tree Node

The generator's entry is feather-light. Right-click any node in the scene tree and choose "Generate Instructions..." to open the dialog.

The dialog that pops up has two tabs: **the Methods tab** and **the Properties tab**.

The Methods tab lists all available methods of the node, grouped by inheritance chain. Select any method and the right side shows its complete signature and parameter list. The Properties tab lists all writable properties, likewise grouped by inheritance chain; read-only properties and underscore-prefixed internal properties are filtered out automatically.

## Three Generation Modes

At the bottom of the Properties tab are three generation modes: **SET** (generate a property-set instruction), **GET** (generate a property-read instruction), and **generate both**. The Methods tab generates call instructions directly; methods with return values automatically get a `result_variable` to store the return value.

## Variable Binding: The Moat within the Moat

If "being able to generate instructions" is the surface-level convenience, "variable binding" is where the generator truly differentiates.

Unchecked, it generates a "direct assignment" version with parameters hard-coded in the Inspector. Checked, it generates a "variable binding" version where every parameter can choose its source: a direct value or a variable. After choosing a variable, you can specify the variable name and scope (Local/Global/Scope).

This design means one generated instruction serves two scenarios at once: designers fill in direct values when they want fixed numbers, and bind variables when they want runtime-dynamic computation. One instruction does the work of two.

## Naming Rules and File Locations

Generated instructions are stored under `res://fuse_generated/instructions/`, in subdirectories by node class name. Naming is tidy: method instructions are `{ClassName}_{method_name}.gd`, SET properties are `set_{ClassName}_{property_name}.gd`, GET properties are `get_{ClassName}_{property_name}.gd`.

After generation they are automatically registered with the InstructionRegistry; find them under the "User Generated" category in the instruction selector. Restarting the editor triggers an automatic rescan; for team collaboration, just commit `fuse_generated/` to Git.

## In Practice: Generate a dash Instruction for Your Character

Suppose you wrote a Player node with a custom method `dash(direction: Vector2, distance: float) -> void`.

Step one, right-click the Player node and choose "Generate Instructions...". Step two, search for "dash" in the Methods tab. Step three, check "Use Variables" (the direction is read dynamically from input). Step four, click Generate, and the file lands at `res://fuse_generated/instructions/player/player_dash_with_variable.gd`. Step five, in any Trigger's instruction selector, drag this instruction in from the "User Generated" category and configure its parameters.

The whole process takes under a minute. The instruction is now a full member of your project's instruction library.

## Comparison with RunTargetNodeFunction

`RunTargetNodeFunction` is the "ad hoc call"—flexible, use-and-go, but reconfigured every time, and when the method signature changes, every reference needs fixing.

The generator produces "distilled resources"—generate once, reuse everywhere, with a name, category, icon, and parameter panel. When the method signature changes, regenerate and overwrite.

One-line summary: `RunTargetNodeFunction` is "phoning someone to get it done"; the generator is "writing the procedure into the rulebook".

## Side Note: The Icon Manager

Generated instructions need icons to look professional. Fuse provides two icon systems: built-in icons referencing the thousands of icons bundled with Godot, and custom icons drawn from an icon library. Three companion tool scripts manage icon synchronization.

## Why This Is the Moat

It's not the 185 built-in instructions—other plugins can pile up numbers too. It's not the visual editing—that stopped being novel long ago. The real moat is this: **Fuse lowered the barrier to extending the instruction library to a single right-click**.

That means two things. First, Fuse's instruction ecosystem is "user-driven"; every team can grow its own dedicated instruction library. Second, the division of labor between programmers and designers is redefined: programmers write node methods, designers use the generator to turn methods into instructions and build logic—no "please ask the programmer to add an instruction" communication tax in between.

## Summary

With the trio of "right-click generation + variable binding + auto registration", the instruction generator turns your node methods into an infinitely growing instruction library. But the more instructions you stack, the sooner problems appear—the next chapter covers how to hunt these bugs down: Fuse's breakpoints, execution tracing, and the live variable watcher, so visual logic can be debugged step by step just like code.
