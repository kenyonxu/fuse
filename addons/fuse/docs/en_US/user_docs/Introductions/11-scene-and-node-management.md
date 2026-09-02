> 🌐 [**中文版**](../../../zh_CN/user_docs/Introductions/11-scene-and-node-management.md) | English

# Scene Switching, Background Loading, Node CRUD: Fuse Keeps Your Game World in Order

The previous chapter gave the Trigger its "brain"—the condition system judges "whether to act". But judging is only preparation; actually changing the game world takes "hands": clearing a level means switching to the next one, a boss falling means a burst of loot right where it died, a UI menu sliding in from off screen. Behind all these operations lies the same problem: how to manage scenes and nodes at runtime. After this chapter you can use Fuse's 6 scene management instructions and 22 node operation instructions to put the entire game world in perfect order—from smooth level switches and stutter-free background loading to runtime enemy spawning, batch property changes, and cross-node communication, all without writing a single line of code.

## Scene Management: 6 Instructions Covering the Full Chain

First, the scene management group—6 instructions in total, covering the entire scene operation chain:

- **ChangeScene** (switch scene): jump to a new scene, with delay support.
- **ReloadScene** (reload scene): reload the current scene, for retries.
- **GetScenePath** (get scene path): fetch the current scene's file path or root node path into a variable.
- **AddSceneAsChild** (add scene as child): instantiate a scene under a specified parent node.
- **PreloadSceneInstruction** (preload scene): load asynchronously in the background, exposing the load status.
- **LoadSceneBackground** (background-load scene): load asynchronously, storing the PackedScene directly into a variable.

For basic switching, `ChangeScene` and `ReloadScene` are the most used. Both carry a `delay` parameter, handy for pairing with fade-in/fade-out animations. `ChangeScene` is an async instruction: with a delay set, it completes only after the countdown finishes.

`GetScenePath` looks unremarkable, yet it is the cornerstone of save systems. It has two modes: Current Scene File Path returns `"res://scenes/level_01.tscn"`, and Root Node Path returns `"/root/Level_01"`. When saving, store the file path into a GLOBAL variable; when loading, hand it to `ChangeScene` to switch back—a complete level-resume flow falls into place.

`AddSceneAsChild` solves "slotting a ready-made scene into the current scene tree at runtime". Spawning enemies, placing effects, dynamically adding UI panels—all use it.

## Preloading: No More Stutter on Big Scenes

`PreloadSceneInstruction` goes through `ResourceLoader.load_threaded_request()`, outputting a load status string: `NOT_LOADED`, `LOADING`, `LOADED`, `FAILED`, `TIMEOUT`. It offers two modes: Async Now (blocking wait) and Async Later (non-blocking, returns immediately).

`LoadSceneBackground` takes the other road—storing the loaded PackedScene resource directly into a variable.

The standard four-step preloading flow:

Step one, **start preloading**. Before the player enters the combat area, use `PreloadSceneInstruction` in Async Later mode to load the boss scene.

Step two, **poll the status**. `OnInterval` paired with `CheckPreloadStatus` checks whether it is LOADED.

Step three, **instantiate or switch after loading completes**. Use `AddSceneAsChild` or `ChangeScene` to put it to formal use—with near-zero latency.

Step four, **handle timeout and failure**. On TIMEOUT or FAILED, take the fallback branch.

## Node Operations: 22 Instructions in 7 Categories

Scenes are the coarse grain; node operations are the fine grain. Fuse's node operation instructions total 22, in 7 categories:

Scene instantiation (3): `InstantiateScene`, `RecyclePooledScene`, `WarmUpPool`. Node lookup and enumeration (8): `FindNode`, `GetNode`, `GetAllChildren`, `GetAllChildrenPosition`, `GetChildByIndex`, `GetLastChild`, `GetRandomChild`, `GetChildCount`. Group operations (2): `GetNodesInGroup`, `GetGroupCount`. Node lifecycle (3): `CloneNode`, `QueueFreeNode`, `ReparentNode`. Node properties (3): `SetPropertyValue`, `SetGlobalPosition`, `SetProcessMode`. Node control (2): `EnableDisableNode`, `EmitSignal`. Advanced operations (1): `RunTargetNodeFunction`.

`FindNode` is the most flexible lookup instruction, supporting three search dimensions (by name BY_NAME, by type BY_TYPE, by group BY_GROUP) and three scopes (children CHILDREN, current scene SCENE, whole scene tree GLOBAL).

## Node Communication: EmitSignal and RunTargetNodeFunction

`EmitSignal` emits a signal on a specified node—the loosely coupled way to communicate: just call out, and whoever listens responds.

`RunTargetNodeFunction` is the tightly coupled direct call—dynamically invoking a specified method on the target node, with argument passing and return value capture.

To broadcast, use `EmitSignal`; to call one specific method directly, use `RunTargetNodeFunction`.

## In Practice: An Enemy Wave Spawner

A working combined case: spawn one enemy every 3 seconds, with preloading to avoid stutter.

Step one, `OnReady` runs `PreloadSceneInstruction` to background-load the enemy scene. Step two, `OnInterval` (3 seconds) paired with `CheckPreloadStatus` checks that loading has finished. Step three, `GetRandomPointInRange` computes a random position. Step four, `InstantiateScene` instantiates the enemy.

## A Few Easy-to-Trip Pitfalls

`scene_path` must be a complete `res://` path. `ChangeScene` destroys the current scene tree—save your global variables before switching.

`AddSceneAsChild`'s `target_parent` is a relative path, not an absolute path.

`PreloadSceneInstruction`'s `scene_path` and `status_variable` must match the launch call exactly.

`QueueFreeNode` defers freeing to the end of the frame—don't reference the node after freeing within the same frame. Group names are case-sensitive.

## Summary

Scenes and nodes are the physical substrate of the game world. Fuse covers everyday needs with 6 scene management instructions + 22 node operation instructions. But one question will surface sooner or later—how do custom node methods become visual instructions? Calling them ad hoc via `RunTargetNodeFunction` is one thing; distilling them into reusable instructions is another. The next chapter covers the instruction generator: how your own node methods become full members of the instruction library with one click.
