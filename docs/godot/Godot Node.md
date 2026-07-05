# Node

**Inherits:** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

**Inherited By:** [AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer), [AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html#class-audiostreamplayer), [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem), [CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html#class-canvaslayer), [EditorFileSystem](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html#class-editorfilesystem), [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html#class-editorplugin), [EditorResourcePreview](https://docs.godotengine.org/en/stable/classes/class_editorresourcepreview.html#class-editorresourcepreview), [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html#class-httprequest), [InstancePlaceholder](https://docs.godotengine.org/en/stable/classes/class_instanceplaceholder.html#class-instanceplaceholder), [MissingNode](https://docs.godotengine.org/en/stable/classes/class_missingnode.html#class-missingnode), [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html#class-multiplayerspawner), [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html#class-multiplayersynchronizer), [NavigationAgent2D](https://docs.godotengine.org/en/stable/classes/class_navigationagent2d.html#class-navigationagent2d), [NavigationAgent3D](https://docs.godotengine.org/en/stable/classes/class_navigationagent3d.html#class-navigationagent3d), [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d), [ResourcePreloader](https://docs.godotengine.org/en/stable/classes/class_resourcepreloader.html#class-resourcepreloader), [ShaderGlobalsOverride](https://docs.godotengine.org/en/stable/classes/class_shaderglobalsoverride.html#class-shaderglobalsoverride), [StatusIndicator](https://docs.godotengine.org/en/stable/classes/class_statusindicator.html#class-statusindicator), [Timer](https://docs.godotengine.org/en/stable/classes/class_timer.html#class-timer), [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport), [WorldEnvironment](https://docs.godotengine.org/en/stable/classes/class_worldenvironment.html#class-worldenvironment)

Base class for all scene objects.

## Description[](#description "Link to this heading")

Nodes are Godot's building blocks. They can be assigned as the child of another node, resulting in a tree arrangement. A given node can contain any number of nodes as children with the requirement that all siblings (direct children of a node) should have unique names.

A tree of nodes is called a *scene*. Scenes can be saved to the disk and then instantiated into other scenes. This allows for very high flexibility in the architecture and data model of Godot projects.

**Scene tree:** The [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) contains the active tree of nodes. When a node is added to the scene tree, it receives the [NOTIFICATION\_ENTER\_TREE](#class-node-constant-notification-enter-tree) notification and its [\_enter\_tree()](#class-node-private-method-enter-tree) callback is triggered. Child nodes are always added *after* their parent node, i.e. the [\_enter\_tree()](#class-node-private-method-enter-tree) callback of a parent node will be triggered before its child's.

Once all nodes have been added in the scene tree, they receive the [NOTIFICATION\_READY](#class-node-constant-notification-ready) notification and their respective [\_ready()](#class-node-private-method-ready) callbacks are triggered. For groups of nodes, the [\_ready()](#class-node-private-method-ready) callback is called in reverse order, starting with the children and moving up to the parent nodes.

This means that when adding a node to the scene tree, the following order will be used for the callbacks: [\_enter\_tree()](#class-node-private-method-enter-tree) of the parent, [\_enter\_tree()](#class-node-private-method-enter-tree) of the children, [\_ready()](#class-node-private-method-ready) of the children and finally [\_ready()](#class-node-private-method-ready) of the parent (recursively for the entire scene tree).

**Processing:** Nodes can override the "process" state, so that they receive a callback on each frame requesting them to process (do something). Normal processing (callback [\_process()](#class-node-private-method-process), toggled with [set\_process()](#class-node-method-set-process)) happens as fast as possible and is dependent on the frame rate, so the processing time *delta* (in seconds) is passed as an argument. Physics processing (callback [\_physics\_process()](#class-node-private-method-physics-process), toggled with [set\_physics\_process()](#class-node-method-set-physics-process)) happens a fixed number of times per second (60 by default) and is useful for code related to the physics engine.

Nodes can also process input events. When present, the [\_input()](#class-node-private-method-input) function will be called for each input that the program receives. In many cases, this can be overkill (unless used for simple projects), and the [\_unhandled\_input()](#class-node-private-method-unhandled-input) function might be preferred; it is called when the input event was not handled by anyone else (typically, GUI [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) nodes), ensuring that the node only receives the events that were meant for it.

To keep track of the scene hierarchy (especially when instantiating scenes into other scenes), an "owner" can be set for the node with the [owner](#class-node-property-owner) property. This keeps track of who instantiated what. This is mostly useful when writing editors and tools, though.

Finally, when a node is freed with [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free) or [queue\_free()](#class-node-method-queue-free), it will also free all its children.

**Groups:** Nodes can be added to as many groups as you want to be easy to manage, you could create groups like "enemies" or "collectables" for example, depending on your game. See [add\_to\_group()](#class-node-method-add-to-group), [is\_in\_group()](#class-node-method-is-in-group) and [remove\_from\_group()](#class-node-method-remove-from-group). You can then retrieve all nodes in these groups, iterate them and even call methods on groups via the methods on [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

**Networking with nodes:** After connecting to a server (or making one, see [ENetMultiplayerPeer](https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html#class-enetmultiplayerpeer)), it is possible to use the built-in RPC (remote procedure call) system to communicate over the network. By calling [rpc()](#class-node-method-rpc) with a method name, it will be called locally and in all connected peers (peers = clients and the server that accepts connections). To identify which node receives the RPC call, Godot will use its [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) (make sure node names are the same on all peers). Also, take a look at the high-level networking tutorial and corresponding demos.

**Note:** The `script` property is part of the [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object) class, not **Node**. It isn't exposed like most properties but does have a setter and getter (see [Object.set\_script()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-set-script) and [Object.get\_script()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-get-script)).

## Tutorials[](#tutorials "Link to this heading")

*   [Nodes and scenes](https://docs.godotengine.org/en/stable/getting_started/step_by_step/nodes_and_scenes.html)
    
*   [All Demos](https://github.com/godotengine/godot-demo-projects/)
    

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

void

[\_enter\_tree](#class-node-private-method-enter-tree)() virtual

void

[\_exit\_tree](#class-node-private-method-exit-tree)() virtual

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[\_get\_accessibility\_configuration\_warnings](#class-node-private-method-get-accessibility-configuration-warnings)() virtual const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[\_get\_configuration\_warnings](#class-node-private-method-get-configuration-warnings)() virtual const

[RID](https://docs.godotengine.org/en/stable/classes/class_rid.html#class-rid)

[\_get\_focused\_accessibility\_element](#class-node-private-method-get-focused-accessibility-element)() virtual const

void

[\_input](#class-node-private-method-input)(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual

void

[\_physics\_process](#class-node-private-method-physics-process)(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) virtual

void

[\_process](#class-node-private-method-process)(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) virtual

void

[\_ready](#class-node-private-method-ready)() virtual

void

[\_shortcut\_input](#class-node-private-method-shortcut-input)(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual

void

[\_unhandled\_input](#class-node-private-method-unhandled-input)(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual

void

[\_unhandled\_key\_input](#class-node-private-method-unhandled-key-input)(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual

void

[add\_child](#class-node-method-add-child)(node: [Node](#class-node), force\_readable\_name: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, internal: [InternalMode](#enum-node-internalmode) = 0)

void

[add\_sibling](#class-node-method-add-sibling)(sibling: [Node](#class-node), force\_readable\_name: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[add\_to\_group](#class-node-method-add-to-group)(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), persistent: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[atr](#class-node-method-atr)(message: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), context: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = "") const

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[atr\_n](#class-node-method-atr-n)(message: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), plural\_message: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), n: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), context: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = "") const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[call\_deferred\_thread\_group](#class-node-method-call-deferred-thread-group)(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[call\_thread\_safe](#class-node-method-call-thread-safe)(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[can\_auto\_translate](#class-node-method-can-auto-translate)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[can\_process](#class-node-method-can-process)() const

[Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween)

[create\_tween](#class-node-method-create-tween)()

[Node](#class-node)

[duplicate](#class-node-method-duplicate)(flags: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 15) const

[Node](#class-node)

[find\_child](#class-node-method-find-child)(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true, owned: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Node](#class-node)\]

[find\_children](#class-node-method-find-children)(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), type: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "", recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true, owned: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) const

[Node](#class-node)

[find\_parent](#class-node-method-find-parent)(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) const

[RID](https://docs.godotengine.org/en/stable/classes/class_rid.html#class-rid)

[get\_accessibility\_element](#class-node-method-get-accessibility-element)() const

[Node](#class-node)

[get\_child](#class-node-method-get-child)(idx: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_child\_count](#class-node-method-get-child-count)(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Node](#class-node)\]

[get\_children](#class-node-method-get-children)(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)\]

[get\_groups](#class-node-method-get-groups)() const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_index](#class-node-method-get-index)(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window)

[get\_last\_exclusive\_window](#class-node-method-get-last-exclusive-window)() const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_multiplayer\_authority](#class-node-method-get-multiplayer-authority)() const

[Node](#class-node)

[get\_node](#class-node-method-get-node)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)

[get\_node\_and\_resource](#class-node-method-get-node-and-resource)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath))

[Node](#class-node)

[get\_node\_or\_null](#class-node-method-get-node-or-null)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[get\_node\_rpc\_config](#class-node-method-get-node-rpc-config)() const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)\]

[get\_orphan\_node\_ids](#class-node-method-get-orphan-node-ids)() static

[Node](#class-node)

[get\_parent](#class-node-method-get-parent)() const

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)

[get\_path](#class-node-method-get-path)() const

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)

[get\_path\_to](#class-node-method-get-path-to)(node: [Node](#class-node), use\_unique\_path: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_physics\_process\_delta\_time](#class-node-method-get-physics-process-delta-time)() const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_process\_delta\_time](#class-node-method-get-process-delta-time)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[get\_scene\_instance\_load\_placeholder](#class-node-method-get-scene-instance-load-placeholder)() const

[SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)

[get\_tree](#class-node-method-get-tree)() const

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[get\_tree\_string](#class-node-method-get-tree-string)()

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[get\_tree\_string\_pretty](#class-node-method-get-tree-string-pretty)()

[Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport)

[get\_viewport](#class-node-method-get-viewport)() const

[Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window)

[get\_window](#class-node-method-get-window)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[has\_node](#class-node-method-has-node)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[has\_node\_and\_resource](#class-node-method-has-node-and-resource)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_ancestor\_of](#class-node-method-is-ancestor-of)(node: [Node](#class-node)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_displayed\_folded](#class-node-method-is-displayed-folded)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_editable\_instance](#class-node-method-is-editable-instance)(node: [Node](#class-node)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_greater\_than](#class-node-method-is-greater-than)(node: [Node](#class-node)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_in\_group](#class-node-method-is-in-group)(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_inside\_tree](#class-node-method-is-inside-tree)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_multiplayer\_authority](#class-node-method-is-multiplayer-authority)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_node\_ready](#class-node-method-is-node-ready)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_part\_of\_edited\_scene](#class-node-method-is-part-of-edited-scene)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_physics\_interpolated](#class-node-method-is-physics-interpolated)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_physics\_interpolated\_and\_enabled](#class-node-method-is-physics-interpolated-and-enabled)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_physics\_processing](#class-node-method-is-physics-processing)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_physics\_processing\_internal](#class-node-method-is-physics-processing-internal)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing](#class-node-method-is-processing)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing\_input](#class-node-method-is-processing-input)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing\_internal](#class-node-method-is-processing-internal)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing\_shortcut\_input](#class-node-method-is-processing-shortcut-input)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing\_unhandled\_input](#class-node-method-is-processing-unhandled-input)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_processing\_unhandled\_key\_input](#class-node-method-is-processing-unhandled-key-input)() const

void

[move\_child](#class-node-method-move-child)(child\_node: [Node](#class-node), to\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[notify\_deferred\_thread\_group](#class-node-method-notify-deferred-thread-group)(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[notify\_thread\_safe](#class-node-method-notify-thread-safe)(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[print\_orphan\_nodes](#class-node-method-print-orphan-nodes)() static

void

[print\_tree](#class-node-method-print-tree)()

void

[print\_tree\_pretty](#class-node-method-print-tree-pretty)()

void

[propagate\_call](#class-node-method-propagate-call)(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), args: [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) = \[\], parent\_first: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[propagate\_notification](#class-node-method-propagate-notification)(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[queue\_accessibility\_update](#class-node-method-queue-accessibility-update)()

void

[queue\_free](#class-node-method-queue-free)()

void

[remove\_child](#class-node-method-remove-child)(node: [Node](#class-node))

void

[remove\_from\_group](#class-node-method-remove-from-group)(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))

void

[reparent](#class-node-method-reparent)(new\_parent: [Node](#class-node), keep\_global\_transform: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true)

void

[replace\_by](#class-node-method-replace-by)(node: [Node](#class-node), keep\_groups: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[request\_ready](#class-node-method-request-ready)()

void

[reset\_physics\_interpolation](#class-node-method-reset-physics-interpolation)()

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error)

[rpc](#class-node-method-rpc)(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg

void

[rpc\_config](#class-node-method-rpc-config)(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), config: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant))

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error)

[rpc\_id](#class-node-method-rpc-id)(peer\_id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg

void

[set\_deferred\_thread\_group](#class-node-method-set-deferred-thread-group)(property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant))

void

[set\_display\_folded](#class-node-method-set-display-folded)(fold: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_editable\_instance](#class-node-method-set-editable-instance)(node: [Node](#class-node), is\_editable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_multiplayer\_authority](#class-node-method-set-multiplayer-authority)(id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true)

void

[set\_physics\_process](#class-node-method-set-physics-process)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_physics\_process\_internal](#class-node-method-set-physics-process-internal)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process](#class-node-method-set-process)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process\_input](#class-node-method-set-process-input)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process\_internal](#class-node-method-set-process-internal)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process\_shortcut\_input](#class-node-method-set-process-shortcut-input)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process\_unhandled\_input](#class-node-method-set-process-unhandled-input)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_process\_unhandled\_key\_input](#class-node-method-set-process-unhandled-key-input)(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_scene\_instance\_load\_placeholder](#class-node-method-set-scene-instance-load-placeholder)(load\_placeholder: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_thread\_safe](#class-node-method-set-thread-safe)(property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant))

void

[set\_translation\_domain\_inherited](#class-node-method-set-translation-domain-inherited)()

void

[update\_configuration\_warnings](#class-node-method-update-configuration-warnings)()

---

## Signals[](#signals "Link to this heading")

**child\_entered\_tree**(node: [Node](#class-node)) [🔗](#class-node-signal-child-entered-tree)

Emitted when the child `node` enters the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree), usually because this node entered the tree (see [tree\_entered](#class-node-signal-tree-entered)), or [add\_child()](#class-node-method-add-child) has been called.

This signal is emitted *after* the child node's own [NOTIFICATION\_ENTER\_TREE](#class-node-constant-notification-enter-tree) and [tree\_entered](#class-node-signal-tree-entered).

---

**child\_exiting\_tree**(node: [Node](#class-node)) [🔗](#class-node-signal-child-exiting-tree)

Emitted when the child `node` is about to exit the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree), usually because this node is exiting the tree (see [tree\_exiting](#class-node-signal-tree-exiting)), or because the child `node` is being removed or freed.

When this signal is received, the child `node` is still accessible inside the tree. This signal is emitted *after* the child node's own [tree\_exiting](#class-node-signal-tree-exiting) and [NOTIFICATION\_EXIT\_TREE](#class-node-constant-notification-exit-tree).

---

**child\_order\_changed**() [🔗](#class-node-signal-child-order-changed)

Emitted when the list of children is changed. This happens when child nodes are added, moved or removed.

---

**editor\_description\_changed**(node: [Node](#class-node)) [🔗](#class-node-signal-editor-description-changed)

Emitted when the node's editor description field changed.

---

**editor\_state\_changed**() [🔗](#class-node-signal-editor-state-changed)

Emitted when an attribute of the node that is relevant to the editor is changed. Only emitted in the editor.

---

**ready**() [🔗](#class-node-signal-ready)

Emitted when the node is considered ready, after [\_ready()](#class-node-private-method-ready) is called.

---

**renamed**() [🔗](#class-node-signal-renamed)

Emitted when the node's [name](#class-node-property-name) is changed, if the node is inside the tree.

---

**replacing\_by**(node: [Node](#class-node)) [🔗](#class-node-signal-replacing-by)

Emitted when this node is being replaced by the `node`, see [replace\_by()](#class-node-method-replace-by).

This signal is emitted *after* `node` has been added as a child of the original parent node, but *before* all original child nodes have been reparented to `node`.

---

**tree\_entered**() [🔗](#class-node-signal-tree-entered)

Emitted when the node enters the tree.

This signal is emitted *after* the related [NOTIFICATION\_ENTER\_TREE](#class-node-constant-notification-enter-tree) notification.

---

**tree\_exited**() [🔗](#class-node-signal-tree-exited)

Emitted after the node exits the tree and is no longer active.

This signal is emitted *after* the related [NOTIFICATION\_EXIT\_TREE](#class-node-constant-notification-exit-tree) notification.

---

**tree\_exiting**() [🔗](#class-node-signal-tree-exiting)

Emitted when the node is just about to exit the tree. The node is still valid. As such, this is the right place for de-initialization (or a "destructor", if you will).

This signal is emitted *after* the node's [\_exit\_tree()](#class-node-private-method-exit-tree), and *before* the related [NOTIFICATION\_EXIT\_TREE](#class-node-constant-notification-exit-tree).

---

## Enumerations[](#enumerations "Link to this heading")

enum **ProcessMode**: [🔗](#enum-node-processmode)

[ProcessMode](#enum-node-processmode) **PROCESS\_MODE\_INHERIT** = `0`

Inherits [process\_mode](#class-node-property-process-mode) from the node's parent. This is the default for any newly created node.

[ProcessMode](#enum-node-processmode) **PROCESS\_MODE\_PAUSABLE** = `1`

Stops processing when [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused) is `true`. This is the inverse of [PROCESS\_MODE\_WHEN\_PAUSED](#class-node-constant-process-mode-when-paused), and the default for the root node.

[ProcessMode](#enum-node-processmode) **PROCESS\_MODE\_WHEN\_PAUSED** = `2`

Process **only** when [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused) is `true`. This is the inverse of [PROCESS\_MODE\_PAUSABLE](#class-node-constant-process-mode-pausable).

[ProcessMode](#enum-node-processmode) **PROCESS\_MODE\_ALWAYS** = `3`

Always process. Keeps processing, ignoring [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused). This is the inverse of [PROCESS\_MODE\_DISABLED](#class-node-constant-process-mode-disabled).

[ProcessMode](#enum-node-processmode) **PROCESS\_MODE\_DISABLED** = `4`

Never process. Completely disables processing, ignoring [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused). This is the inverse of [PROCESS\_MODE\_ALWAYS](#class-node-constant-process-mode-always).

---

enum **ProcessThreadGroup**: [🔗](#enum-node-processthreadgroup)

[ProcessThreadGroup](#enum-node-processthreadgroup) **PROCESS\_THREAD\_GROUP\_INHERIT** = `0`

Process this node based on the thread group mode of the first parent (or grandparent) node that has a thread group mode that is not inherit. See [process\_thread\_group](#class-node-property-process-thread-group) for more information.

[ProcessThreadGroup](#enum-node-processthreadgroup) **PROCESS\_THREAD\_GROUP\_MAIN\_THREAD** = `1`

Process this node (and child nodes set to inherit) on the main thread. See [process\_thread\_group](#class-node-property-process-thread-group) for more information.

[ProcessThreadGroup](#enum-node-processthreadgroup) **PROCESS\_THREAD\_GROUP\_SUB\_THREAD** = `2`

Process this node (and child nodes set to inherit) on a sub-thread. See [process\_thread\_group](#class-node-property-process-thread-group) for more information.

---

flags **ProcessThreadMessages**: [🔗](#enum-node-processthreadmessages)

[ProcessThreadMessages](#enum-node-processthreadmessages) **FLAG\_PROCESS\_THREAD\_MESSAGES** = `1`

Allows this node to process threaded messages created with [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group) right before [\_process()](#class-node-private-method-process) is called.

[ProcessThreadMessages](#enum-node-processthreadmessages) **FLAG\_PROCESS\_THREAD\_MESSAGES\_PHYSICS** = `2`

Allows this node to process threaded messages created with [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group) right before [\_physics\_process()](#class-node-private-method-physics-process) is called.

[ProcessThreadMessages](#enum-node-processthreadmessages) **FLAG\_PROCESS\_THREAD\_MESSAGES\_ALL** = `3`

Allows this node to process threaded messages created with [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group) right before either [\_process()](#class-node-private-method-process) or [\_physics\_process()](#class-node-private-method-physics-process) are called.

---

enum **PhysicsInterpolationMode**: [🔗](#enum-node-physicsinterpolationmode)

[PhysicsInterpolationMode](#enum-node-physicsinterpolationmode) **PHYSICS\_INTERPOLATION\_MODE\_INHERIT** = `0`

Inherits [physics\_interpolation\_mode](#class-node-property-physics-interpolation-mode) from the node's parent. This is the default for any newly created node.

[PhysicsInterpolationMode](#enum-node-physicsinterpolationmode) **PHYSICS\_INTERPOLATION\_MODE\_ON** = `1`

Enables physics interpolation for this node and for children set to [PHYSICS\_INTERPOLATION\_MODE\_INHERIT](#class-node-constant-physics-interpolation-mode-inherit). This is the default for the root node.

[PhysicsInterpolationMode](#enum-node-physicsinterpolationmode) **PHYSICS\_INTERPOLATION\_MODE\_OFF** = `2`

Disables physics interpolation for this node and for children set to [PHYSICS\_INTERPOLATION\_MODE\_INHERIT](#class-node-constant-physics-interpolation-mode-inherit).

---

enum **DuplicateFlags**: [🔗](#enum-node-duplicateflags)

[DuplicateFlags](#enum-node-duplicateflags) **DUPLICATE\_SIGNALS** = `1`

Duplicate the node's signal connections that are connected with the [Object.CONNECT\_PERSIST](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-constant-connect-persist) flag.

[DuplicateFlags](#enum-node-duplicateflags) **DUPLICATE\_GROUPS** = `2`

Duplicate the node's groups.

[DuplicateFlags](#enum-node-duplicateflags) **DUPLICATE\_SCRIPTS** = `4`

Duplicate the node's script (also overriding the duplicated children's scripts, if combined with [DUPLICATE\_USE\_INSTANTIATION](#class-node-constant-duplicate-use-instantiation)).

[DuplicateFlags](#enum-node-duplicateflags) **DUPLICATE\_USE\_INSTANTIATION** = `8`

Duplicate using [PackedScene.instantiate()](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene-method-instantiate). If the node comes from a scene saved on disk, reuses [PackedScene.instantiate()](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene-method-instantiate) as the base for the duplicated node and its children.

---

enum **InternalMode**: [🔗](#enum-node-internalmode)

[InternalMode](#enum-node-internalmode) **INTERNAL\_MODE\_DISABLED** = `0`

The node will not be internal.

[InternalMode](#enum-node-internalmode) **INTERNAL\_MODE\_FRONT** = `1`

The node will be placed at the beginning of the parent's children, before any non-internal sibling.

[InternalMode](#enum-node-internalmode) **INTERNAL\_MODE\_BACK** = `2`

The node will be placed at the end of the parent's children, after any non-internal sibling.

---

enum **AutoTranslateMode**: [🔗](#enum-node-autotranslatemode)

[AutoTranslateMode](#enum-node-autotranslatemode) **AUTO\_TRANSLATE\_MODE\_INHERIT** = `0`

Inherits [auto\_translate\_mode](#class-node-property-auto-translate-mode) from the node's parent. This is the default for any newly created node.

[AutoTranslateMode](#enum-node-autotranslatemode) **AUTO\_TRANSLATE\_MODE\_ALWAYS** = `1`

Always automatically translate. This is the inverse of [AUTO\_TRANSLATE\_MODE\_DISABLED](#class-node-constant-auto-translate-mode-disabled), and the default for the root node.

[AutoTranslateMode](#enum-node-autotranslatemode) **AUTO\_TRANSLATE\_MODE\_DISABLED** = `2`

Never automatically translate. This is the inverse of [AUTO\_TRANSLATE\_MODE\_ALWAYS](#class-node-constant-auto-translate-mode-always).

String parsing for POT generation will be skipped for this node and children that are set to [AUTO\_TRANSLATE\_MODE\_INHERIT](#class-node-constant-auto-translate-mode-inherit).

---

## Constants[](#constants "Link to this heading")

**NOTIFICATION\_ENTER\_TREE** = `10` [🔗](#class-node-constant-notification-enter-tree)

Notification received when the node enters a [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree). See [\_enter\_tree()](#class-node-private-method-enter-tree).

This notification is received *before* the related [tree\_entered](#class-node-signal-tree-entered) signal.

**NOTIFICATION\_EXIT\_TREE** = `11` [🔗](#class-node-constant-notification-exit-tree)

Notification received when the node is about to exit a [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree). See [\_exit\_tree()](#class-node-private-method-exit-tree).

This notification is received *after* the related [tree\_exiting](#class-node-signal-tree-exiting) signal.

**NOTIFICATION\_MOVED\_IN\_PARENT** = `12` [🔗](#class-node-constant-notification-moved-in-parent)

**Deprecated:** This notification is no longer sent by the engine. Use [NOTIFICATION\_CHILD\_ORDER\_CHANGED](#class-node-constant-notification-child-order-changed) instead.

**NOTIFICATION\_READY** = `13` [🔗](#class-node-constant-notification-ready)

Notification received when the node is ready. See [\_ready()](#class-node-private-method-ready).

**NOTIFICATION\_PAUSED** = `14` [🔗](#class-node-constant-notification-paused)

Notification received when the node is paused. See [process\_mode](#class-node-property-process-mode).

**NOTIFICATION\_UNPAUSED** = `15` [🔗](#class-node-constant-notification-unpaused)

Notification received when the node is unpaused. See [process\_mode](#class-node-property-process-mode).

**NOTIFICATION\_PHYSICS\_PROCESS** = `16` [🔗](#class-node-constant-notification-physics-process)

Notification received from the tree every physics frame when [is\_physics\_processing()](#class-node-method-is-physics-processing) returns `true`. See [\_physics\_process()](#class-node-private-method-physics-process).

**NOTIFICATION\_PROCESS** = `17` [🔗](#class-node-constant-notification-process)

Notification received from the tree every rendered frame when [is\_processing()](#class-node-method-is-processing) returns `true`. See [\_process()](#class-node-private-method-process).

**NOTIFICATION\_PARENTED** = `18` [🔗](#class-node-constant-notification-parented)

Notification received when the node is set as a child of another node (see [add\_child()](#class-node-method-add-child) and [add\_sibling()](#class-node-method-add-sibling)).

**Note:** This does *not* mean that the node entered the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

**NOTIFICATION\_UNPARENTED** = `19` [🔗](#class-node-constant-notification-unparented)

Notification received when the parent node calls [remove\_child()](#class-node-method-remove-child) on this node.

**Note:** This does *not* mean that the node exited the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

**NOTIFICATION\_SCENE\_INSTANTIATED** = `20` [🔗](#class-node-constant-notification-scene-instantiated)

Notification received *only* by the newly instantiated scene root node, when [PackedScene.instantiate()](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene-method-instantiate) is completed.

**NOTIFICATION\_DRAG\_BEGIN** = `21` [🔗](#class-node-constant-notification-drag-begin)

Notification received when a drag operation begins. All nodes receive this notification, not only the dragged one.

Can be triggered either by dragging a [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) that provides drag data (see [Control.\_get\_drag\_data()](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-private-method-get-drag-data)) or using [Control.force\_drag()](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-method-force-drag).

Use [Viewport.gui\_get\_drag\_data()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-gui-get-drag-data) to get the dragged data.

**NOTIFICATION\_DRAG\_END** = `22` [🔗](#class-node-constant-notification-drag-end)

Notification received when a drag operation ends.

Use [Viewport.gui\_is\_drag\_successful()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-gui-is-drag-successful) to check if the drag succeeded.

**NOTIFICATION\_PATH\_RENAMED** = `23` [🔗](#class-node-constant-notification-path-renamed)

Notification received when the node's [name](#class-node-property-name) or one of its ancestors' [name](#class-node-property-name) is changed. This notification is *not* received when the node is removed from the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

**NOTIFICATION\_CHILD\_ORDER\_CHANGED** = `24` [🔗](#class-node-constant-notification-child-order-changed)

Notification received when the list of children is changed. This happens when child nodes are added, moved or removed.

**NOTIFICATION\_INTERNAL\_PROCESS** = `25` [🔗](#class-node-constant-notification-internal-process)

Notification received from the tree every rendered frame when [is\_processing\_internal()](#class-node-method-is-processing-internal) returns `true`.

**NOTIFICATION\_INTERNAL\_PHYSICS\_PROCESS** = `26` [🔗](#class-node-constant-notification-internal-physics-process)

Notification received from the tree every physics frame when [is\_physics\_processing\_internal()](#class-node-method-is-physics-processing-internal) returns `true`.

**NOTIFICATION\_POST\_ENTER\_TREE** = `27` [🔗](#class-node-constant-notification-post-enter-tree)

Notification received when the node enters the tree, just before [NOTIFICATION\_READY](#class-node-constant-notification-ready) may be received. Unlike the latter, it is sent every time the node enters tree, not just once.

**NOTIFICATION\_DISABLED** = `28` [🔗](#class-node-constant-notification-disabled)

Notification received when the node is disabled. See [PROCESS\_MODE\_DISABLED](#class-node-constant-process-mode-disabled).

**NOTIFICATION\_ENABLED** = `29` [🔗](#class-node-constant-notification-enabled)

Notification received when the node is enabled again after being disabled. See [PROCESS\_MODE\_DISABLED](#class-node-constant-process-mode-disabled).

**NOTIFICATION\_RESET\_PHYSICS\_INTERPOLATION** = `2001` [🔗](#class-node-constant-notification-reset-physics-interpolation)

Notification received when [reset\_physics\_interpolation()](#class-node-method-reset-physics-interpolation) is called on the node or its ancestors.

**NOTIFICATION\_EDITOR\_PRE\_SAVE** = `9001` [🔗](#class-node-constant-notification-editor-pre-save)

Notification received right before the scene with the node is saved in the editor. This notification is only sent in the Godot editor and will not occur in exported projects.

**NOTIFICATION\_EDITOR\_POST\_SAVE** = `9002` [🔗](#class-node-constant-notification-editor-post-save)

Notification received right after the scene with the node is saved in the editor. This notification is only sent in the Godot editor and will not occur in exported projects.

**NOTIFICATION\_WM\_MOUSE\_ENTER** = `1002` [🔗](#class-node-constant-notification-wm-mouse-enter)

Notification received when the mouse enters the window.

Implemented for embedded windows and on desktop and web platforms.

**NOTIFICATION\_WM\_MOUSE\_EXIT** = `1003` [🔗](#class-node-constant-notification-wm-mouse-exit)

Notification received when the mouse leaves the window.

Implemented for embedded windows and on desktop and web platforms.

**NOTIFICATION\_WM\_WINDOW\_FOCUS\_IN** = `1004` [🔗](#class-node-constant-notification-wm-window-focus-in)

Notification received from the OS when the node's [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) ancestor is focused. This may be a change of focus between two windows of the same engine instance, or from the OS desktop or a third-party application to a window of the game (in which case [NOTIFICATION\_APPLICATION\_FOCUS\_IN](#class-node-constant-notification-application-focus-in) is also received).

A [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) node receives this notification when it is focused.

**NOTIFICATION\_WM\_WINDOW\_FOCUS\_OUT** = `1005` [🔗](#class-node-constant-notification-wm-window-focus-out)

Notification received from the OS when the node's [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) ancestor is defocused. This may be a change of focus between two windows of the same engine instance, or from a window of the game to the OS desktop or a third-party application (in which case [NOTIFICATION\_APPLICATION\_FOCUS\_OUT](#class-node-constant-notification-application-focus-out) is also received).

A [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) node receives this notification when it is defocused.

**NOTIFICATION\_WM\_CLOSE\_REQUEST** = `1006` [🔗](#class-node-constant-notification-wm-close-request)

Notification received from the OS when a close request is sent (e.g. closing the window with a "Close" button or Alt + F4).

Implemented on desktop platforms.

**NOTIFICATION\_WM\_GO\_BACK\_REQUEST** = `1007` [🔗](#class-node-constant-notification-wm-go-back-request)

Notification received from the OS when a go back request is sent (e.g. pressing the "Back" button on Android).

Implemented only on Android.

**NOTIFICATION\_WM\_SIZE\_CHANGED** = `1008` [🔗](#class-node-constant-notification-wm-size-changed)

Notification received when the window is resized.

**Note:** Only the resized [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) node receives this notification, and it's not propagated to the child nodes.

**NOTIFICATION\_WM\_DPI\_CHANGE** = `1009` [🔗](#class-node-constant-notification-wm-dpi-change)

Notification received from the OS when the screen's dots per inch (DPI) scale is changed. Only implemented on macOS.

**NOTIFICATION\_VP\_MOUSE\_ENTER** = `1010` [🔗](#class-node-constant-notification-vp-mouse-enter)

Notification received when the mouse cursor enters the [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport)'s visible area, that is not occluded behind other [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control)s or [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window)s, provided its [Viewport.gui\_disable\_input](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-gui-disable-input) is `false` and regardless if it's currently focused or not.

**NOTIFICATION\_VP\_MOUSE\_EXIT** = `1011` [🔗](#class-node-constant-notification-vp-mouse-exit)

Notification received when the mouse cursor leaves the [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport)'s visible area, that is not occluded behind other [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control)s or [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window)s, provided its [Viewport.gui\_disable\_input](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-gui-disable-input) is `false` and regardless if it's currently focused or not.

**NOTIFICATION\_WM\_POSITION\_CHANGED** = `1012` [🔗](#class-node-constant-notification-wm-position-changed)

Notification received when the window is moved.

**NOTIFICATION\_OS\_MEMORY\_WARNING** = `2009` [🔗](#class-node-constant-notification-os-memory-warning)

Notification received from the OS when the application is exceeding its allocated memory.

Implemented only on iOS.

**NOTIFICATION\_TRANSLATION\_CHANGED** = `2010` [🔗](#class-node-constant-notification-translation-changed)

Notification received when translations may have changed. Can be triggered by the user changing the locale, changing [auto\_translate\_mode](#class-node-property-auto-translate-mode) or when the node enters the scene tree. Can be used to respond to language changes, for example to change the UI strings on the fly. Useful when working with the built-in translation support, like [Object.tr()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-tr).

**Note:** This notification is received alongside [NOTIFICATION\_ENTER\_TREE](#class-node-constant-notification-enter-tree), so if you are instantiating a scene, the child nodes will not be initialized yet. You can use it to setup translations for this node, child nodes created from script, or if you want to access child nodes added in the editor, make sure the node is ready using [is\_node\_ready()](#class-node-method-is-node-ready).

func \_notification(what):
	if what \== NOTIFICATION\_TRANSLATION\_CHANGED:
		if not is\_node\_ready():
			await ready \# Wait until ready signal.
		$Label.text \= atr("%d Bananas") % banana\_counter

**NOTIFICATION\_WM\_ABOUT** = `2011` [🔗](#class-node-constant-notification-wm-about)

Notification received from the OS when a request for "About" information is sent.

Implemented only on macOS.

**NOTIFICATION\_CRASH** = `2012` [🔗](#class-node-constant-notification-crash)

Notification received from Godot's crash handler when the engine is about to crash.

Implemented on desktop platforms, if the crash handler is enabled.

**NOTIFICATION\_OS\_IME\_UPDATE** = `2013` [🔗](#class-node-constant-notification-os-ime-update)

Notification received from the OS when an update of the Input Method Engine occurs (e.g. change of IME cursor position or composition string).

Implemented only on macOS.

**NOTIFICATION\_APPLICATION\_RESUMED** = `2014` [🔗](#class-node-constant-notification-application-resumed)

Notification received from the OS when the application is resumed.

Specific to the Android and iOS platforms.

**NOTIFICATION\_APPLICATION\_PAUSED** = `2015` [🔗](#class-node-constant-notification-application-paused)

Notification received from the OS when the application is paused.

Specific to the Android and iOS platforms.

**Note:** On iOS, you only have approximately 5 seconds to finish a task started by this signal. If you go over this allotment, iOS will kill the app instead of pausing it.

**NOTIFICATION\_APPLICATION\_FOCUS\_IN** = `2016` [🔗](#class-node-constant-notification-application-focus-in)

Notification received from the OS when the application is focused, i.e. when changing the focus from the OS desktop or a thirdparty application to any open window of the Godot instance.

Implemented on desktop and mobile platforms.

**NOTIFICATION\_APPLICATION\_FOCUS\_OUT** = `2017` [🔗](#class-node-constant-notification-application-focus-out)

Notification received from the OS when the application is defocused, i.e. when changing the focus from any open window of the Godot instance to the OS desktop or a thirdparty application.

Implemented on desktop and mobile platforms.

**NOTIFICATION\_TEXT\_SERVER\_CHANGED** = `2018` [🔗](#class-node-constant-notification-text-server-changed)

Notification received when the [TextServer](https://docs.godotengine.org/en/stable/classes/class_textserver.html#class-textserver) is changed.

**NOTIFICATION\_ACCESSIBILITY\_UPDATE** = `3000` [🔗](#class-node-constant-notification-accessibility-update)

Notification received when an accessibility information update is required.

**NOTIFICATION\_ACCESSIBILITY\_INVALIDATE** = `3001` [🔗](#class-node-constant-notification-accessibility-invalidate)

Notification received when accessibility elements are invalidated. All node accessibility elements are automatically deleted after receiving this message, therefore all existing references to such elements should be discarded.

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[AutoTranslateMode](#enum-node-autotranslatemode) **auto\_translate\_mode** = `0` [🔗](#class-node-property-auto-translate-mode)

*   void **set\_auto\_translate\_mode**(value: [AutoTranslateMode](#enum-node-autotranslatemode))
    
*   [AutoTranslateMode](#enum-node-autotranslatemode) **get\_auto\_translate\_mode**()
    

Defines if any text should automatically change to its translated version depending on the current locale (for nodes such as [Label](https://docs.godotengine.org/en/stable/classes/class_label.html#class-label), [RichTextLabel](https://docs.godotengine.org/en/stable/classes/class_richtextlabel.html#class-richtextlabel), [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window), etc.). Also decides if the node's strings should be parsed for POT generation.

**Note:** For the root node, auto translate mode can also be set via [ProjectSettings.internationalization/rendering/root\_node\_auto\_translate](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-internationalization-rendering-root-node-auto-translate).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **editor\_description** = `""` [🔗](#class-node-property-editor-description)

*   void **set\_editor\_description**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_editor\_description**()
    

An optional description to the node. It will be displayed as a tooltip when hovering over the node in the editor's Scene dock.

---

[MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi) **multiplayer** [🔗](#class-node-property-multiplayer)

*   [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi) **get\_multiplayer**()
    

The [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi) instance associated with this node. See [SceneTree.get\_multiplayer()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-get-multiplayer).

**Note:** Renaming the node, or moving it in the tree, will not move the [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi) to the new path, you will have to update this manually.

---

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **name** [🔗](#class-node-property-name)

*   void **set\_name**(value: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))
    
*   [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **get\_name**()
    

The name of the node. This name must be unique among the siblings (other child nodes from the same parent). When set to an existing sibling's name, the node is automatically renamed.

**Note:** When changing the name, the following characters will be replaced with an underscore: (`.` `:` `@` `/` `"` `%`). In particular, the `@` character is reserved for auto-generated names. See also [String.validate\_node\_name()](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-validate-node-name).

---

[Node](#class-node) **owner** [🔗](#class-node-property-owner)

*   void **set\_owner**(value: [Node](#class-node))
    
*   [Node](#class-node) **get\_owner**()
    

The owner of this node. The owner must be an ancestor of this node. When packing the owner node in a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene), all the nodes it owns are also saved with it. See also [unique\_name\_in\_owner](#class-node-property-unique-name-in-owner).

**Note:** In the editor, nodes not owned by the scene root are usually not displayed in the Scene dock, and will **not** be saved. To prevent this, remember to set the owner after calling [add\_child()](#class-node-method-add-child).

---

[PhysicsInterpolationMode](#enum-node-physicsinterpolationmode) **physics\_interpolation\_mode** = `0` [🔗](#class-node-property-physics-interpolation-mode)

*   void **set\_physics\_interpolation\_mode**(value: [PhysicsInterpolationMode](#enum-node-physicsinterpolationmode))
    
*   [PhysicsInterpolationMode](#enum-node-physicsinterpolationmode) **get\_physics\_interpolation\_mode**()
    

The physics interpolation mode to use for this node. Only effective if [ProjectSettings.physics/common/physics\_interpolation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-physics-interpolation) or [SceneTree.physics\_interpolation](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-physics-interpolation) is `true`.

By default, nodes inherit the physics interpolation mode from their parent. This property can enable or disable physics interpolation individually for each node, regardless of their parents' physics interpolation mode.

**Note:** Some node types like [VehicleWheel3D](https://docs.godotengine.org/en/stable/classes/class_vehiclewheel3d.html#class-vehiclewheel3d) have physics interpolation disabled by default, as they rely on their own custom solution.

**Note:** When teleporting a node to a distant position, it's recommended to temporarily disable interpolation with [reset\_physics\_interpolation()](#class-node-method-reset-physics-interpolation) *after* moving the node. This avoids creating a visual streak between the old and new positions.

---

[ProcessMode](#enum-node-processmode) **process\_mode** = `0` [🔗](#class-node-property-process-mode)

*   void **set\_process\_mode**(value: [ProcessMode](#enum-node-processmode))
    
*   [ProcessMode](#enum-node-processmode) **get\_process\_mode**()
    

The node's processing behavior. To check if the node can process in its current mode, use [can\_process()](#class-node-method-can-process).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **process\_physics\_priority** = `0` [🔗](#class-node-property-process-physics-priority)

*   void **set\_physics\_process\_priority**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_physics\_process\_priority**()
    

Similar to [process\_priority](#class-node-property-process-priority) but for [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process), [\_physics\_process()](#class-node-private-method-physics-process), or [NOTIFICATION\_INTERNAL\_PHYSICS\_PROCESS](#class-node-constant-notification-internal-physics-process).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **process\_priority** = `0` [🔗](#class-node-property-process-priority)

*   void **set\_process\_priority**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_process\_priority**()
    

The node's execution order of the process callbacks ([\_process()](#class-node-private-method-process), [NOTIFICATION\_PROCESS](#class-node-constant-notification-process), and [NOTIFICATION\_INTERNAL\_PROCESS](#class-node-constant-notification-internal-process)). Nodes whose priority value is *lower* call their process callbacks first, regardless of tree order.

---

[ProcessThreadGroup](#enum-node-processthreadgroup) **process\_thread\_group** = `0` [🔗](#class-node-property-process-thread-group)

*   void **set\_process\_thread\_group**(value: [ProcessThreadGroup](#enum-node-processthreadgroup))
    
*   [ProcessThreadGroup](#enum-node-processthreadgroup) **get\_process\_thread\_group**()
    

Set the process thread group for this node (basically, whether it receives [NOTIFICATION\_PROCESS](#class-node-constant-notification-process), [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process), [\_process()](#class-node-private-method-process) or [\_physics\_process()](#class-node-private-method-physics-process) (and the internal versions) on the main thread or in a sub-thread.

By default, the thread group is [PROCESS\_THREAD\_GROUP\_INHERIT](#class-node-constant-process-thread-group-inherit), which means that this node belongs to the same thread group as the parent node. The thread groups means that nodes in a specific thread group will process together, separate to other thread groups (depending on [process\_thread\_group\_order](#class-node-property-process-thread-group-order)). If the value is set is [PROCESS\_THREAD\_GROUP\_SUB\_THREAD](#class-node-constant-process-thread-group-sub-thread), this thread group will occur on a sub thread (not the main thread), otherwise if set to [PROCESS\_THREAD\_GROUP\_MAIN\_THREAD](#class-node-constant-process-thread-group-main-thread) it will process on the main thread. If there is not a parent or grandparent node set to something other than inherit, the node will belong to the *default thread group*. This default group will process on the main thread and its group order is 0.

During processing in a sub-thread, accessing most functions in nodes outside the thread group is forbidden (and it will result in an error in debug mode). Use [Object.call\_deferred()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-call-deferred), [call\_thread\_safe()](#class-node-method-call-thread-safe), [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group) and the likes in order to communicate from the thread groups to the main thread (or to other thread groups).

To better understand process thread groups, the idea is that any node set to any other value than [PROCESS\_THREAD\_GROUP\_INHERIT](#class-node-constant-process-thread-group-inherit) will include any child (and grandchild) nodes set to inherit into its process thread group. This means that the processing of all the nodes in the group will happen together, at the same time as the node including them.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **process\_thread\_group\_order** [🔗](#class-node-property-process-thread-group-order)

*   void **set\_process\_thread\_group\_order**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_process\_thread\_group\_order**()
    

Change the process thread group order. Groups with a lesser order will process before groups with a greater order. This is useful when a large amount of nodes process in sub thread and, afterwards, another group wants to collect their result in the main thread, as an example.

---

BitField\[[ProcessThreadMessages](#enum-node-processthreadmessages)\] **process\_thread\_messages** [🔗](#class-node-property-process-thread-messages)

*   void **set\_process\_thread\_messages**(value: BitField\[[ProcessThreadMessages](#enum-node-processthreadmessages)\])
    
*   BitField\[[ProcessThreadMessages](#enum-node-processthreadmessages)\] **get\_process\_thread\_messages**()
    

Set whether the current thread group will process messages (calls to [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group) on threads), and whether it wants to receive them during regular process or physics process callbacks.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **scene\_file\_path** [🔗](#class-node-property-scene-file-path)

*   void **set\_scene\_file\_path**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_scene\_file\_path**()
    

The original scene's file path, if the node has been instantiated from a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene) file. Only scene root nodes contains this.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **unique\_name\_in\_owner** = `false` [🔗](#class-node-property-unique-name-in-owner)

*   void **set\_unique\_name\_in\_owner**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_unique\_name\_in\_owner**()
    

If `true`, the node can be accessed from any node sharing the same [owner](#class-node-property-owner) or from the [owner](#class-node-property-owner) itself, with special `%Name` syntax in [get\_node()](#class-node-method-get-node).

**Note:** If another node with the same [owner](#class-node-property-owner) shares the same [name](#class-node-property-name) as this node, the other node will no longer be accessible as unique.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

void **\_enter\_tree**() virtual [🔗](#class-node-private-method-enter-tree)

Called when the node enters the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) (e.g. upon instantiating, scene changing, or after calling [add\_child()](#class-node-method-add-child) in a script). If the node has children, its [\_enter\_tree()](#class-node-private-method-enter-tree) callback will be called first, and then that of the children.

Corresponds to the [NOTIFICATION\_ENTER\_TREE](#class-node-constant-notification-enter-tree) notification in [Object.\_notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-notification).

---

void **\_exit\_tree**() virtual [🔗](#class-node-private-method-exit-tree)

Called when the node is about to leave the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) (e.g. upon freeing, scene changing, or after calling [remove\_child()](#class-node-method-remove-child) in a script). If the node has children, its [\_exit\_tree()](#class-node-private-method-exit-tree) callback will be called last, after all its children have left the tree.

Corresponds to the [NOTIFICATION\_EXIT\_TREE](#class-node-constant-notification-exit-tree) notification in [Object.\_notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-notification) and signal [tree\_exiting](#class-node-signal-tree-exiting). To get notified when the node has already left the active tree, connect to the [tree\_exited](#class-node-signal-tree-exited).

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **\_get\_accessibility\_configuration\_warnings**() virtual const [🔗](#class-node-private-method-get-accessibility-configuration-warnings)

The elements in the array returned from this method are displayed as warnings in the Scene dock if the script that overrides it is a `tool` script, and accessibility warnings are enabled in the editor settings.

Returning an empty array produces no warnings.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **\_get\_configuration\_warnings**() virtual const [🔗](#class-node-private-method-get-configuration-warnings)

The elements in the array returned from this method are displayed as warnings in the Scene dock if the script that overrides it is a `tool` script.

Returning an empty array produces no warnings.

Call [update\_configuration\_warnings()](#class-node-method-update-configuration-warnings) when the warnings need to be updated for this node.

@export var energy \= 0:
	set(value):
		energy \= value
		update\_configuration\_warnings()

func \_get\_configuration\_warnings():
	if energy < 0:
		return \["Energy must be 0 or greater."\]
	else:
		return \[\]

---

[RID](https://docs.godotengine.org/en/stable/classes/class_rid.html#class-rid) **\_get\_focused\_accessibility\_element**() virtual const [🔗](#class-node-private-method-get-focused-accessibility-element)

Called during accessibility information updates to determine the currently focused sub-element, should return a sub-element RID or the value returned by [get\_accessibility\_element()](#class-node-method-get-accessibility-element).

---

void **\_input**(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual [🔗](#class-node-private-method-input)

Called when there is an input event. The input event propagates up through the node tree until a node consumes it.

It is only called if input processing is enabled, which is done automatically if this method is overridden, and can be toggled with [set\_process\_input()](#class-node-method-set-process-input).

To consume the input event and stop it propagating further to other nodes, [Viewport.set\_input\_as\_handled()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-set-input-as-handled) can be called.

For gameplay input, [\_unhandled\_input()](#class-node-private-method-unhandled-input) and [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input) are usually a better fit as they allow the GUI to intercept the events first.

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not an orphan).

---

void **\_physics\_process**(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) virtual [🔗](#class-node-private-method-physics-process)

Called once on each physics tick, and allows Nodes to synchronize their logic with physics ticks. `delta` is the logical time between physics ticks in seconds and is equal to [Engine.time\_scale](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale) / [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second).

It is only called if physics processing is enabled for this Node, which is done automatically if this method is overridden, and can be toggled with [set\_physics\_process()](#class-node-method-set-physics-process).

Processing happens in order of [process\_physics\_priority](#class-node-property-process-physics-priority), lower priority values are called first. Nodes with the same priority are processed in tree order, or top to bottom as seen in the editor (also known as pre-order traversal).

Corresponds to the [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process) notification in [Object.\_notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-notification).

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not an orphan).

**Note:** Accumulated `delta` may diverge from real world seconds.

---

void **\_process**(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) virtual [🔗](#class-node-private-method-process)

Called on each idle frame, prior to rendering, and after physics ticks have been processed. `delta` is the time between frames in seconds.

It is only called if processing is enabled for this Node, which is done automatically if this method is overridden, and can be toggled with [set\_process()](#class-node-method-set-process).

Processing happens in order of [process\_priority](#class-node-property-process-priority), lower priority values are called first. Nodes with the same priority are processed in tree order, or top to bottom as seen in the editor (also known as pre-order traversal).

Corresponds to the [NOTIFICATION\_PROCESS](#class-node-constant-notification-process) notification in [Object.\_notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-notification).

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not an orphan).

**Note:** When the engine is struggling and the frame rate is lowered, `delta` will increase. When `delta` is increased, it's capped at a maximum of [Engine.time\_scale](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale) \* [Engine.max\_physics\_steps\_per\_frame](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-physics-steps-per-frame) / [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second). As a result, accumulated `delta` may not represent real world time.

**Note:** When `--fixed-fps` is enabled or the engine is running in Movie Maker mode (see [MovieWriter](https://docs.godotengine.org/en/stable/classes/class_moviewriter.html#class-moviewriter)), process `delta` will always be the same for every frame, regardless of how much time the frame took to render.

**Note:** Frame delta may be post-processed by [OS.delta\_smoothing](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-property-delta-smoothing) if this is enabled for the project.

---

void **\_ready**() virtual [🔗](#class-node-private-method-ready)

Called when the node is "ready", i.e. when both the node and its children have entered the scene tree. If the node has children, their [\_ready()](#class-node-private-method-ready) callbacks get triggered first, and the parent node will receive the ready notification afterwards.

Corresponds to the [NOTIFICATION\_READY](#class-node-constant-notification-ready) notification in [Object.\_notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-notification). See also the `@onready` annotation for variables.

Usually used for initialization. For even earlier initialization, [Object.\_init()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-init) may be used. See also [\_enter\_tree()](#class-node-private-method-enter-tree).

**Note:** This method may be called only once for each node. After removing a node from the scene tree and adding it again, [\_ready()](#class-node-private-method-ready) will **not** be called a second time. This can be bypassed by requesting another call with [request\_ready()](#class-node-method-request-ready), which may be called anywhere before adding the node again.

---

void **\_shortcut\_input**(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual [🔗](#class-node-private-method-shortcut-input)

Called when an [InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html#class-inputeventkey), [InputEventShortcut](https://docs.godotengine.org/en/stable/classes/class_inputeventshortcut.html#class-inputeventshortcut), or [InputEventJoypadButton](https://docs.godotengine.org/en/stable/classes/class_inputeventjoypadbutton.html#class-inputeventjoypadbutton) hasn't been consumed by [\_input()](#class-node-private-method-input) or any GUI [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) item. It is called before [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input) and [\_unhandled\_input()](#class-node-private-method-unhandled-input). The input event propagates up through the node tree until a node consumes it.

It is only called if shortcut processing is enabled, which is done automatically if this method is overridden, and can be toggled with [set\_process\_shortcut\_input()](#class-node-method-set-process-shortcut-input).

To consume the input event and stop it propagating further to other nodes, [Viewport.set\_input\_as\_handled()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-set-input-as-handled) can be called.

This method can be used to handle shortcuts. For generic GUI events, use [\_input()](#class-node-private-method-input) instead. Gameplay events should usually be handled with either [\_unhandled\_input()](#class-node-private-method-unhandled-input) or [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input).

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not orphan).

---

void **\_unhandled\_input**(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual [🔗](#class-node-private-method-unhandled-input)

Called when an [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) hasn't been consumed by [\_input()](#class-node-private-method-input) or any GUI [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) item. It is called after [\_shortcut\_input()](#class-node-private-method-shortcut-input) and after [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input). The input event propagates up through the node tree until a node consumes it.

It is only called if unhandled input processing is enabled, which is done automatically if this method is overridden, and can be toggled with [set\_process\_unhandled\_input()](#class-node-method-set-process-unhandled-input).

To consume the input event and stop it propagating further to other nodes, [Viewport.set\_input\_as\_handled()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-set-input-as-handled) can be called.

For gameplay input, this method is usually a better fit than [\_input()](#class-node-private-method-input), as GUI events need a higher priority. For keyboard shortcuts, consider using [\_shortcut\_input()](#class-node-private-method-shortcut-input) instead, as it is called before this method. Finally, to handle keyboard events, consider using [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input) for performance reasons.

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not an orphan).

---

void **\_unhandled\_key\_input**(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) virtual [🔗](#class-node-private-method-unhandled-key-input)

Called when an [InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html#class-inputeventkey) hasn't been consumed by [\_input()](#class-node-private-method-input) or any GUI [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) item. It is called after [\_shortcut\_input()](#class-node-private-method-shortcut-input) but before [\_unhandled\_input()](#class-node-private-method-unhandled-input). The input event propagates up through the node tree until a node consumes it.

It is only called if unhandled key input processing is enabled, which is done automatically if this method is overridden, and can be toggled with [set\_process\_unhandled\_key\_input()](#class-node-method-set-process-unhandled-key-input).

To consume the input event and stop it propagating further to other nodes, [Viewport.set\_input\_as\_handled()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-set-input-as-handled) can be called.

This method can be used to handle Unicode character input with Alt, Alt + Ctrl, and Alt + Shift modifiers, after shortcuts were handled.

For gameplay input, this and [\_unhandled\_input()](#class-node-private-method-unhandled-input) are usually a better fit than [\_input()](#class-node-private-method-input), as GUI events should be handled first. This method also performs better than [\_unhandled\_input()](#class-node-private-method-unhandled-input), since unrelated events such as [InputEventMouseMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html#class-inputeventmousemotion) are automatically filtered. For shortcuts, consider using [\_shortcut\_input()](#class-node-private-method-shortcut-input) instead.

**Note:** This method is only called if the node is present in the scene tree (i.e. if it's not an orphan).

---

void **add\_child**(node: [Node](#class-node), force\_readable\_name: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, internal: [InternalMode](#enum-node-internalmode) = 0) [🔗](#class-node-method-add-child)

Adds a child `node`. Nodes can have any number of children, but every child must have a unique name. Child nodes are automatically deleted when the parent node is deleted, so an entire scene can be removed by deleting its topmost node.

If `force_readable_name` is `true`, improves the readability of the added `node`. If not named, the `node` is renamed to its type, and if it shares [name](#class-node-property-name) with a sibling, a number is suffixed more appropriately. This operation is very slow. As such, it is recommended leaving this to `false`, which assigns a dummy name featuring `@` in both situations.

If `internal` is different than [INTERNAL\_MODE\_DISABLED](#class-node-constant-internal-mode-disabled), the child will be added as internal node. These nodes are ignored by methods like [get\_children()](#class-node-method-get-children), unless their parameter `include_internal` is `true`. It also prevents these nodes being duplicated with their parent. The intended usage is to hide the internal nodes from the user, so the user won't accidentally delete or modify them. Used by some GUI nodes, e.g. [ColorPicker](https://docs.godotengine.org/en/stable/classes/class_colorpicker.html#class-colorpicker).

**Note:** If `node` already has a parent, this method will fail. Use [remove\_child()](#class-node-method-remove-child) first to remove `node` from its current parent. For example:

var child\_node \= get\_child(0)
if child\_node.get\_parent():
	child\_node.get\_parent().remove\_child(child\_node)
add\_child(child\_node)

If you need the child node to be added below a specific node in the list of children, use [add\_sibling()](#class-node-method-add-sibling) instead of this method.

**Note:** If you want a child to be persisted to a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene), you must set [owner](#class-node-property-owner) in addition to calling [add\_child()](#class-node-method-add-child). This is typically relevant for [tool scripts](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html) and [editor plugins](https://docs.godotengine.org/en/stable/tutorials/plugins/editor/index.html). If [add\_child()](#class-node-method-add-child) is called without setting [owner](#class-node-property-owner), the newly added **Node** will not be visible in the scene tree, though it will be visible in the 2D/3D view.

---

void **add\_sibling**(sibling: [Node](#class-node), force\_readable\_name: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-node-method-add-sibling)

Adds a `sibling` node to this node's parent, and moves the added sibling right below this node.

If `force_readable_name` is `true`, improves the readability of the added `sibling`. If not named, the `sibling` is renamed to its type, and if it shares [name](#class-node-property-name) with a sibling, a number is suffixed more appropriately. This operation is very slow. As such, it is recommended leaving this to `false`, which assigns a dummy name featuring `@` in both situations.

Use [add\_child()](#class-node-method-add-child) instead of this method if you don't need the child node to be added below a specific node in the list of children.

**Note:** If this node is internal, the added sibling will be internal too (see [add\_child()](#class-node-method-add-child)'s `internal` parameter).

---

void **add\_to\_group**(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), persistent: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-node-method-add-to-group)

Adds the node to the `group`. Groups can be helpful to organize a subset of nodes, for example `"enemies"` or `"collectables"`. See notes in the description, and the group methods in [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

If `persistent` is `true`, the group will be stored when saved inside a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene). All groups created and displayed in the Node dock are persistent.

**Note:** To improve performance, the order of group names is *not* guaranteed and may vary between project runs. Therefore, do not rely on the group order.

**Note:** [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)'s group methods will *not* work on this node if not inside the tree (see [is\_inside\_tree()](#class-node-method-is-inside-tree)).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **atr**(message: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), context: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = "") const [🔗](#class-node-method-atr)

Translates a `message`, using the translation catalogs configured in the Project Settings. Further `context` can be specified to help with the translation. Note that most [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) nodes automatically translate their strings, so this method is mostly useful for formatted strings or custom drawn text.

This method works the same as [Object.tr()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-tr), with the addition of respecting the [auto\_translate\_mode](#class-node-property-auto-translate-mode) state.

If [Object.can\_translate\_messages()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-can-translate-messages) is `false`, or no translation is available, this method returns the `message` without changes. See [Object.set\_message\_translation()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-set-message-translation).

For detailed examples, see [Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **atr\_n**(message: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), plural\_message: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), n: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), context: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = "") const [🔗](#class-node-method-atr-n)

Translates a `message` or `plural_message`, using the translation catalogs configured in the Project Settings. Further `context` can be specified to help with the translation.

This method works the same as [Object.tr\_n()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-tr-n), with the addition of respecting the [auto\_translate\_mode](#class-node-property-auto-translate-mode) state.

If [Object.can\_translate\_messages()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-can-translate-messages) is `false`, or no translation is available, this method returns `message` or `plural_message`, without changes. See [Object.set\_message\_translation()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-set-message-translation).

The `n` is the number, or amount, of the message's subject. It is used by the translation system to fetch the correct plural form for the current language.

For detailed examples, see [Localization using gettext](https://docs.godotengine.org/en/stable/tutorials/i18n/localization_using_gettext.html).

**Note:** Negative and [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) numbers may not properly apply to some countable subjects. It's recommended to handle these cases with [atr()](#class-node-method-atr).

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **call\_deferred\_thread\_group**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-node-method-call-deferred-thread-group)

This function is similar to [Object.call\_deferred()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-call-deferred) except that the call will take place when the node thread group is processed. If the node thread group processes in sub-threads, then the call will be done on that thread, right before [NOTIFICATION\_PROCESS](#class-node-constant-notification-process) or [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process), the [\_process()](#class-node-private-method-process) or [\_physics\_process()](#class-node-private-method-physics-process) or their internal versions are called.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **call\_thread\_safe**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-node-method-call-thread-safe)

This function ensures that the calling of this function will succeed, no matter whether it's being done from a thread or not. If called from a thread that is not allowed to call the function, the call will become deferred. Otherwise, the call will go through directly.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **can\_auto\_translate**() const [🔗](#class-node-method-can-auto-translate)

Returns `true` if this node can automatically translate messages depending on the current locale. See [auto\_translate\_mode](#class-node-property-auto-translate-mode), [atr()](#class-node-method-atr), and [atr\_n()](#class-node-method-atr-n).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **can\_process**() const [🔗](#class-node-method-can-process)

Returns `true` if the node can receive processing notifications and input callbacks ([NOTIFICATION\_PROCESS](#class-node-constant-notification-process), [\_input()](#class-node-private-method-input), etc.) from the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) and [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport). The returned value depends on [process\_mode](#class-node-property-process-mode):

*   If set to [PROCESS\_MODE\_PAUSABLE](#class-node-constant-process-mode-pausable), returns `true` when the game is processing, i.e. [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused) is `false`;
    
*   If set to [PROCESS\_MODE\_WHEN\_PAUSED](#class-node-constant-process-mode-when-paused), returns `true` when the game is paused, i.e. [SceneTree.paused](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-paused) is `true`;
    
*   If set to [PROCESS\_MODE\_ALWAYS](#class-node-constant-process-mode-always), always returns `true`;
    
*   If set to [PROCESS\_MODE\_DISABLED](#class-node-constant-process-mode-disabled), always returns `false`;
    
*   If set to [PROCESS\_MODE\_INHERIT](#class-node-constant-process-mode-inherit), use the parent node's [process\_mode](#class-node-property-process-mode) to determine the result.
    

If the node is not inside the tree, returns `false` no matter the value of [process\_mode](#class-node-property-process-mode).

---

[Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween) **create\_tween**() [🔗](#class-node-method-create-tween)

Creates a new [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween) and binds it to this node.

This is the equivalent of doing:

get\_tree().create\_tween().bind\_node(self)

The Tween will start automatically on the next process frame or physics frame (depending on [TweenProcessMode](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-tweenprocessmode)). See [Tween.bind\_node()](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween-method-bind-node) for more info on Tweens bound to nodes.

**Note:** The method can still be used when the node is not inside [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree). It can fail in an unlikely case of using a custom [MainLoop](https://docs.godotengine.org/en/stable/classes/class_mainloop.html#class-mainloop).

---

[Node](#class-node) **duplicate**(flags: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 15) const [🔗](#class-node-method-duplicate)

Duplicates the node, returning a new node with all of its properties, signals, groups, and children copied from the original. The behavior can be tweaked through the `flags` (see [DuplicateFlags](#enum-node-duplicateflags)). Internal nodes are not duplicated.

**Note:** For nodes with a [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script) attached, if [Object.\_init()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-init) has been defined with required parameters, the duplicated node will not have a [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script).

---

[Node](#class-node) **find\_child**(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true, owned: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) const [🔗](#class-node-method-find-child)

Finds the first descendant of this node whose [name](#class-node-property-name) matches `pattern`, returning `null` if no match is found. The matching is done against node names, *not* their paths, through [String.match()](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-match). As such, it is case-sensitive, `"*"` matches zero or more characters, and `"?"` matches any single character.

If `recursive` is `false`, only this node's direct children are checked. Nodes are checked in tree order, so this node's first direct child is checked first, then its own direct children, etc., before moving to the second direct child, and so on. Internal children are also included in the search (see `internal` parameter in [add\_child()](#class-node-method-add-child)).

If `owned` is `true`, only descendants with a valid [owner](#class-node-property-owner) node are checked.

**Note:** This method can be very slow. Consider storing a reference to the found node in a variable. Alternatively, use [get\_node()](#class-node-method-get-node) with unique names (see [unique\_name\_in\_owner](#class-node-property-unique-name-in-owner)).

**Note:** To find all descendant nodes matching a pattern or a class type, see [find\_children()](#class-node-method-find-children).

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Node](#class-node)\] **find\_children**(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), type: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "", recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true, owned: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) const [🔗](#class-node-method-find-children)

Finds all descendants of this node whose names match `pattern`, returning an empty [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) if no match is found. The matching is done against node names, *not* their paths, through [String.match()](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-match). As such, it is case-sensitive, `"*"` matches zero or more characters, and `"?"` matches any single character.

If `type` is not empty, only ancestors inheriting from `type` are included (see [Object.is\_class()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-is-class)).

If `recursive` is `false`, only this node's direct children are checked. Nodes are checked in tree order, so this node's first direct child is checked first, then its own direct children, etc., before moving to the second direct child, and so on. Internal children are also included in the search (see `internal` parameter in [add\_child()](#class-node-method-add-child)).

If `owned` is `true`, only descendants with a valid [owner](#class-node-property-owner) node are checked.

**Note:** This method can be very slow. Consider storing references to the found nodes in a variable.

**Note:** To find a single descendant node matching a pattern, see [find\_child()](#class-node-method-find-child).

---

[Node](#class-node) **find\_parent**(pattern: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) const [🔗](#class-node-method-find-parent)

Finds the first ancestor of this node whose [name](#class-node-property-name) matches `pattern`, returning `null` if no match is found. The matching is done through [String.match()](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-match). As such, it is case-sensitive, `"*"` matches zero or more characters, and `"?"` matches any single character. See also [find\_child()](#class-node-method-find-child) and [find\_children()](#class-node-method-find-children).

**Note:** As this method walks upwards in the scene tree, it can be slow in large, deeply nested nodes. Consider storing a reference to the found node in a variable. Alternatively, use [get\_node()](#class-node-method-get-node) with unique names (see [unique\_name\_in\_owner](#class-node-property-unique-name-in-owner)).

---

[RID](https://docs.godotengine.org/en/stable/classes/class_rid.html#class-rid) **get\_accessibility\_element**() const [🔗](#class-node-method-get-accessibility-element)

Returns main accessibility element RID.

**Note:** This method should be called only during accessibility information updates ([NOTIFICATION\_ACCESSIBILITY\_UPDATE](#class-node-constant-notification-accessibility-update)).

---

[Node](#class-node) **get\_child**(idx: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-node-method-get-child)

Fetches a child node by its index. Each child node has an index relative to its siblings (see [get\_index()](#class-node-method-get-index)). The first child is at index 0. Negative values can also be used to start from the end of the list. This method can be used in combination with [get\_child\_count()](#class-node-method-get-child-count) to iterate over this node's children. If no child exists at the given index, this method returns `null` and an error is generated.

If `include_internal` is `false`, internal children are ignored (see [add\_child()](#class-node-method-add-child)'s `internal` parameter).

\# Assuming the following are children of this node, in order:
\# First, Middle, Last.

var a \= get\_child(0).name  \# a is "First"
var b \= get\_child(1).name  \# b is "Middle"
var b \= get\_child(2).name  \# b is "Last"
var c \= get\_child(\-1).name \# c is "Last"

**Note:** To fetch a node by [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath), use [get\_node()](#class-node-method-get-node).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_child\_count**(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-node-method-get-child-count)

Returns the number of children of this node.

If `include_internal` is `false`, internal children are not counted (see [add\_child()](#class-node-method-add-child)'s `internal` parameter).

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Node](#class-node)\] **get\_children**(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-node-method-get-children)

Returns all children of this node inside an [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array).

If `include_internal` is `false`, excludes internal children from the returned array (see [add\_child()](#class-node-method-add-child)'s `internal` parameter).

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)\] **get\_groups**() const [🔗](#class-node-method-get-groups)

Returns an [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) of group names that the node has been added to.

**Note:** To improve performance, the order of group names is *not* guaranteed and may vary between project runs. Therefore, do not rely on the group order.

**Note:** This method may also return some group names starting with an underscore (`_`). These are internally used by the engine. To avoid conflicts, do not use custom groups starting with underscores. To exclude internal groups, see the following code snippet:

\# Stores the node's non-internal groups only (as an array of StringNames).
var non\_internal\_groups \= \[\]
for group in get\_groups():
	if not str(group).begins\_with("\_"):
		non\_internal\_groups.push\_back(group)

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_index**(include\_internal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-node-method-get-index)

Returns this node's order among its siblings. The first node's index is `0`. See also [get\_child()](#class-node-method-get-child).

If `include_internal` is `false`, returns the index ignoring internal children. The first, non-internal child will have an index of `0` (see [add\_child()](#class-node-method-add-child)'s `internal` parameter).

---

[Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) **get\_last\_exclusive\_window**() const [🔗](#class-node-method-get-last-exclusive-window)

Returns the [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) that contains this node, or the last exclusive child in a chain of windows starting with the one that contains this node.

---

Returns the peer ID of the multiplayer authority for this node. See [set\_multiplayer\_authority()](#class-node-method-set-multiplayer-authority).

---

[Node](#class-node) **get\_node**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const [🔗](#class-node-method-get-node)

Fetches a node. The [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) can either be a relative path (from this node), or an absolute path (from the [SceneTree.root](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-root)) to a node. If `path` does not point to a valid node, generates an error and returns `null`. Attempts to access methods on the return value will result in an *"Attempt to call <method> on a null instance."* error.

**Note:** Fetching by absolute path only works when the node is inside the scene tree (see [is\_inside\_tree()](#class-node-method-is-inside-tree)).

**Example:** Assume this method is called from the Character node, inside the following tree:

┖╴root
   ┠╴Character (you are here!)
   ┃  ┠╴Sword
   ┃  ┖╴Backpack
   ┃     ┖╴Dagger
   ┠╴MyGame
   ┖╴Swamp
      ┠╴Alligator
      ┠╴Mosquito
      ┖╴Goblin

The following calls will return a valid node:

get\_node("Sword")
get\_node("Backpack/Dagger")
get\_node("../Swamp/Alligator")
get\_node("/root/MyGame")

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) **get\_node\_and\_resource**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) [🔗](#class-node-method-get-node-and-resource)

Fetches a node and its most nested resource as specified by the [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)'s subname. Returns an [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) of size `3` where:

*   Element `0` is the **Node**, or `null` if not found;
    
*   Element `1` is the subname's last nested [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource), or `null` if not found;
    
*   Element `2` is the remaining [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath), referring to an existing, non-[Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) property (see [Object.get\_indexed()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-get-indexed)).
    

**Example:** Assume that the child's [Sprite2D.texture](https://docs.godotengine.org/en/stable/classes/class_sprite2d.html#class-sprite2d-property-texture) has been assigned an [AtlasTexture](https://docs.godotengine.org/en/stable/classes/class_atlastexture.html#class-atlastexture):

var a \= get\_node\_and\_resource("Area2D/Sprite2D")
print(a\[0\].name) \# Prints Sprite2D
print(a\[1\])      \# Prints <null>
print(a\[2\])      \# Prints ^""

var b \= get\_node\_and\_resource("Area2D/Sprite2D:texture:atlas")
print(b\[0\].name)        \# Prints Sprite2D
print(b\[1\].get\_class()) \# Prints AtlasTexture
print(b\[2\])             \# Prints ^""

var c \= get\_node\_and\_resource("Area2D/Sprite2D:texture:atlas:region")
print(c\[0\].name)        \# Prints Sprite2D
print(c\[1\].get\_class()) \# Prints AtlasTexture
print(c\[2\])             \# Prints ^":region"

---

[Node](#class-node) **get\_node\_or\_null**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const [🔗](#class-node-method-get-node-or-null)

Fetches a node by [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath). Similar to [get\_node()](#class-node-method-get-node), but does not generate an error if `path` does not point to a valid node.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **get\_node\_rpc\_config**() const [🔗](#class-node-method-get-node-rpc-config)

Returns a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) mapping method names to their RPC configuration defined for this node using [rpc\_config()](#class-node-method-rpc-config).

**Note:** This method only returns the RPC configuration assigned via [rpc\_config()](#class-node-method-rpc-config). See [Script.get\_rpc\_config()](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script-method-get-rpc-config) to retrieve the RPCs defined by the [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script).

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)\] **get\_orphan\_node\_ids**() static [🔗](#class-node-method-get-orphan-node-ids)

Returns object IDs of all orphan nodes (nodes outside the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)). Used for debugging.

**Note:** [get\_orphan\_node\_ids()](#class-node-method-get-orphan-node-ids) only works in debug builds. When called in a project exported in release mode, [get\_orphan\_node\_ids()](#class-node-method-get-orphan-node-ids) will return an empty array.

---

[Node](#class-node) **get\_parent**() const [🔗](#class-node-method-get-parent)

Returns this node's parent node, or `null` if the node doesn't have a parent.

---

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) **get\_path**() const [🔗](#class-node-method-get-path)

Returns the node's absolute path, relative to the [SceneTree.root](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-root). If the node is not inside the scene tree, this method fails and returns an empty [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath).

---

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) **get\_path\_to**(node: [Node](#class-node), use\_unique\_path: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-node-method-get-path-to)

Returns the relative [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) from this node to the specified `node`. Both nodes must be in the same [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) or scene hierarchy, otherwise this method fails and returns an empty [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath).

If `use_unique_path` is `true`, returns the shortest path accounting for this node's unique name (see [unique\_name\_in\_owner](#class-node-property-unique-name-in-owner)).

**Note:** If you get a relative path which starts from a unique node, the path may be longer than a normal relative path, due to the addition of the unique node's name.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_physics\_process\_delta\_time**() const [🔗](#class-node-method-get-physics-process-delta-time)

Returns the time elapsed (in seconds) since the last physics callback. This value is identical to [\_physics\_process()](#class-node-private-method-physics-process)'s `delta` parameter, and is often consistent at run-time, unless [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second) is changed. See also [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process).

**Note:** The returned value will be larger than expected if running at a framerate lower than [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second) / [Engine.max\_physics\_steps\_per\_frame](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-physics-steps-per-frame) FPS. This is done to avoid "spiral of death" scenarios where performance would plummet due to an ever-increasing number of physics steps per frame. This behavior affects both [\_process()](#class-node-private-method-process) and [\_physics\_process()](#class-node-private-method-physics-process). As a result, avoid using `delta` for time measurements in real-world seconds. Use the [Time](https://docs.godotengine.org/en/stable/classes/class_time.html#class-time) singleton's methods for this purpose instead, such as [Time.get\_ticks\_usec()](https://docs.godotengine.org/en/stable/classes/class_time.html#class-time-method-get-ticks-usec).

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_process\_delta\_time**() const [🔗](#class-node-method-get-process-delta-time)

Returns the time elapsed (in seconds) since the last process callback. This value is identical to [\_process()](#class-node-private-method-process)'s `delta` parameter, and may vary from frame to frame. See also [NOTIFICATION\_PROCESS](#class-node-constant-notification-process).

**Note:** The returned value will be larger than expected if running at a framerate lower than [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second) / [Engine.max\_physics\_steps\_per\_frame](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-physics-steps-per-frame) FPS. This is done to avoid "spiral of death" scenarios where performance would plummet due to an ever-increasing number of physics steps per frame. This behavior affects both [\_process()](#class-node-private-method-process) and [\_physics\_process()](#class-node-private-method-physics-process). As a result, avoid using `delta` for time measurements in real-world seconds. Use the [Time](https://docs.godotengine.org/en/stable/classes/class_time.html#class-time) singleton's methods for this purpose instead, such as [Time.get\_ticks\_usec()](https://docs.godotengine.org/en/stable/classes/class_time.html#class-time-method-get-ticks-usec).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_scene\_instance\_load\_placeholder**() const [🔗](#class-node-method-get-scene-instance-load-placeholder)

Returns `true` if this node is an instance load placeholder. See [InstancePlaceholder](https://docs.godotengine.org/en/stable/classes/class_instanceplaceholder.html#class-instanceplaceholder) and [set\_scene\_instance\_load\_placeholder()](#class-node-method-set-scene-instance-load-placeholder).

---

[SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) **get\_tree**() const [🔗](#class-node-method-get-tree)

Returns the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) that contains this node. If this node is not inside the tree, generates an error and returns `null`. See also [is\_inside\_tree()](#class-node-method-is-inside-tree).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_tree\_string**() [🔗](#class-node-method-get-tree-string)

Returns the tree as a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string). Used mainly for debugging purposes. This version displays the path relative to the current node, and is good for copy/pasting into the [get\_node()](#class-node-method-get-node) function. It also can be used in game UI/UX.

May print, for example:

TheGame
TheGame/Menu
TheGame/Menu/Label
TheGame/Menu/Camera2D
TheGame/SplashScreen
TheGame/SplashScreen/Camera2D

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_tree\_string\_pretty**() [🔗](#class-node-method-get-tree-string-pretty)

Similar to [get\_tree\_string()](#class-node-method-get-tree-string), this returns the tree as a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string). This version displays a more graphical representation similar to what is displayed in the Scene Dock. It is useful for inspecting larger trees.

May print, for example:

┖╴TheGame
   ┠╴Menu
   ┃  ┠╴Label
   ┃  ┖╴Camera2D
   ┖╴SplashScreen
      ┖╴Camera2D

---

[Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport) **get\_viewport**() const [🔗](#class-node-method-get-viewport)

Returns the node's closest [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport) ancestor, if the node is inside the tree. Otherwise, returns `null`.

---

[Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) **get\_window**() const [🔗](#class-node-method-get-window)

Returns the [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) that contains this node. If the node is in the main window, this is equivalent to getting the root node (`get_tree().get_root()`).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **has\_node**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const [🔗](#class-node-method-has-node)

Returns `true` if the `path` points to a valid node. See also [get\_node()](#class-node-method-get-node).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **has\_node\_and\_resource**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) const [🔗](#class-node-method-has-node-and-resource)

Returns `true` if `path` points to a valid node and its subnames point to a valid [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource), e.g. `Area2D/CollisionShape2D:shape`. Properties that are not [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) types (such as nodes or other [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) types) are not considered. See also [get\_node\_and\_resource()](#class-node-method-get-node-and-resource).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_ancestor\_of**(node: [Node](#class-node)) const [🔗](#class-node-method-is-ancestor-of)

Returns `true` if the given `node` is a direct or indirect child of this node.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_displayed\_folded**() const [🔗](#class-node-method-is-displayed-folded)

Returns `true` if the node is folded (collapsed) in the Scene dock. This method is intended to be used in editor plugins and tools. See also [set\_display\_folded()](#class-node-method-set-display-folded).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_editable\_instance**(node: [Node](#class-node)) const [🔗](#class-node-method-is-editable-instance)

Returns `true` if `node` has editable children enabled relative to this node. This method is intended to be used in editor plugins and tools. See also [set\_editable\_instance()](#class-node-method-set-editable-instance).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_greater\_than**(node: [Node](#class-node)) const [🔗](#class-node-method-is-greater-than)

Returns `true` if the given `node` occurs later in the scene hierarchy than this node. A node occurring later is usually processed last.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_in\_group**(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-node-method-is-in-group)

Returns `true` if this node has been added to the given `group`. See [add\_to\_group()](#class-node-method-add-to-group) and [remove\_from\_group()](#class-node-method-remove-from-group). See also notes in the description, and the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)'s group methods.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_inside\_tree**() const [🔗](#class-node-method-is-inside-tree)

Returns `true` if this node is currently inside a [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree). See also [get\_tree()](#class-node-method-get-tree).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_multiplayer\_authority**() const [🔗](#class-node-method-is-multiplayer-authority)

Returns `true` if the local system is the multiplayer authority of this node.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_node\_ready**() const [🔗](#class-node-method-is-node-ready)

Returns `true` if the node is ready, i.e. it's inside scene tree and all its children are initialized.

[request\_ready()](#class-node-method-request-ready) resets it back to `false`.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_part\_of\_edited\_scene**() const [🔗](#class-node-method-is-part-of-edited-scene)

Returns `true` if the node is part of the scene currently opened in the editor.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_physics\_interpolated**() const [🔗](#class-node-method-is-physics-interpolated)

Returns `true` if physics interpolation is enabled for this node (see [physics\_interpolation\_mode](#class-node-property-physics-interpolation-mode)).

**Note:** Interpolation will only be active if both the flag is set **and** physics interpolation is enabled within the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree). This can be tested using [is\_physics\_interpolated\_and\_enabled()](#class-node-method-is-physics-interpolated-and-enabled).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_physics\_interpolated\_and\_enabled**() const [🔗](#class-node-method-is-physics-interpolated-and-enabled)

Returns `true` if physics interpolation is enabled (see [physics\_interpolation\_mode](#class-node-property-physics-interpolation-mode)) **and** enabled in the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree).

This is a convenience version of [is\_physics\_interpolated()](#class-node-method-is-physics-interpolated) that also checks whether physics interpolation is enabled globally.

See [SceneTree.physics\_interpolation](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-property-physics-interpolation) and [ProjectSettings.physics/common/physics\_interpolation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-physics-interpolation).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_physics\_processing**() const [🔗](#class-node-method-is-physics-processing)

Returns `true` if physics processing is enabled (see [set\_physics\_process()](#class-node-method-set-physics-process)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_physics\_processing\_internal**() const [🔗](#class-node-method-is-physics-processing-internal)

Returns `true` if internal physics processing is enabled (see [set\_physics\_process\_internal()](#class-node-method-set-physics-process-internal)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing**() const [🔗](#class-node-method-is-processing)

Returns `true` if processing is enabled (see [set\_process()](#class-node-method-set-process)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing\_input**() const [🔗](#class-node-method-is-processing-input)

Returns `true` if the node is processing input (see [set\_process\_input()](#class-node-method-set-process-input)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing\_internal**() const [🔗](#class-node-method-is-processing-internal)

Returns `true` if internal processing is enabled (see [set\_process\_internal()](#class-node-method-set-process-internal)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing\_shortcut\_input**() const [🔗](#class-node-method-is-processing-shortcut-input)

Returns `true` if the node is processing shortcuts (see [set\_process\_shortcut\_input()](#class-node-method-set-process-shortcut-input)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing\_unhandled\_input**() const [🔗](#class-node-method-is-processing-unhandled-input)

Returns `true` if the node is processing unhandled input (see [set\_process\_unhandled\_input()](#class-node-method-set-process-unhandled-input)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_processing\_unhandled\_key\_input**() const [🔗](#class-node-method-is-processing-unhandled-key-input)

Returns `true` if the node is processing unhandled key input (see [set\_process\_unhandled\_key\_input()](#class-node-method-set-process-unhandled-key-input)).

---

void **move\_child**(child\_node: [Node](#class-node), to\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-node-method-move-child)

Moves `child_node` to the given index. A node's index is the order among its siblings. If `to_index` is negative, the index is counted from the end of the list. See also [get\_child()](#class-node-method-get-child) and [get\_index()](#class-node-method-get-index).

**Note:** The processing order of several engine callbacks ([\_ready()](#class-node-private-method-ready), [\_process()](#class-node-private-method-process), etc.) and notifications sent through [propagate\_notification()](#class-node-method-propagate-notification) is affected by tree order. [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem) nodes are also rendered in tree order. See also [process\_priority](#class-node-property-process-priority).

---

void **notify\_deferred\_thread\_group**(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-node-method-notify-deferred-thread-group)

Similar to [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group), but for notifications.

---

void **notify\_thread\_safe**(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-node-method-notify-thread-safe)

Similar to [call\_thread\_safe()](#class-node-method-call-thread-safe), but for notifications.

---

void **print\_orphan\_nodes**() static [🔗](#class-node-method-print-orphan-nodes)

Prints all orphan nodes (nodes outside the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)). Useful for debugging.

**Note:** This method only works in debug builds. Does nothing in a project exported in release mode.

---

void **print\_tree**() [🔗](#class-node-method-print-tree)

Prints the node and its children to the console, recursively. The node does not have to be inside the tree. This method outputs [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)s relative to this node, and is good for copy/pasting into [get\_node()](#class-node-method-get-node). See also [print\_tree\_pretty()](#class-node-method-print-tree-pretty).

May print, for example:

.
Menu
Menu/Label
Menu/Camera2D
SplashScreen
SplashScreen/Camera2D

---

void **print\_tree\_pretty**() [🔗](#class-node-method-print-tree-pretty)

Prints the node and its children to the console, recursively. The node does not have to be inside the tree. Similar to [print\_tree()](#class-node-method-print-tree), but the graphical representation looks like what is displayed in the editor's Scene dock. It is useful for inspecting larger trees.

May print, for example:

┖╴TheGame
   ┠╴Menu
   ┃  ┠╴Label
   ┃  ┖╴Camera2D
   ┖╴SplashScreen
      ┖╴Camera2D

---

void **propagate\_call**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), args: [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) = \[\], parent\_first: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-node-method-propagate-call)

Calls the given `method` name, passing `args` as arguments, on this node and all of its children, recursively.

If `parent_first` is `true`, the method is called on this node first, then on all of its children. If `false`, the children's methods are called first.

---

void **propagate\_notification**(what: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-node-method-propagate-notification)

Calls [Object.notification()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-notification) with `what` on this node and all of its children, recursively.

---

void **queue\_accessibility\_update**() [🔗](#class-node-method-queue-accessibility-update)

Queues an accessibility information update for this node.

---

void **queue\_free**() [🔗](#class-node-method-queue-free)

Queues this node to be deleted at the end of the current frame. When deleted, all of its children are deleted as well, and all references to the node and its children become invalid.

Unlike with [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free), the node is not deleted instantly, and it can still be accessed before deletion. It is also safe to call [queue\_free()](#class-node-method-queue-free) multiple times. Use [Object.is\_queued\_for\_deletion()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-is-queued-for-deletion) to check if the node will be deleted at the end of the frame.

**Note:** The node will only be freed after all other deferred calls are finished. Using this method is not always the same as calling [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free) through [Object.call\_deferred()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-call-deferred).

---

void **remove\_child**(node: [Node](#class-node)) [🔗](#class-node-method-remove-child)

Removes a child `node`. The `node`, along with its children, are **not** deleted. To delete a node, see [queue\_free()](#class-node-method-queue-free).

**Note:** When this node is inside the tree, this method sets the [owner](#class-node-property-owner) of the removed `node` (or its descendants) to `null`, if their [owner](#class-node-property-owner) is no longer an ancestor (see [is\_ancestor\_of()](#class-node-method-is-ancestor-of)).

---

void **remove\_from\_group**(group: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-node-method-remove-from-group)

Removes the node from the given `group`. Does nothing if the node is not in the `group`. See also notes in the description, and the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree)'s group methods.

---

void **reparent**(new\_parent: [Node](#class-node), keep\_global\_transform: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-node-method-reparent)

Changes the parent of this **Node** to the `new_parent`. The node needs to already have a parent. The node's [owner](#class-node-property-owner) is preserved if its owner is still reachable from the new location (i.e., the node is still a descendant of the new parent after the operation).

If `keep_global_transform` is `true`, the node's global transform will be preserved if supported. [Node2D](https://docs.godotengine.org/en/stable/classes/class_node2d.html#class-node2d), [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html#class-node3d) and [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) support this argument (but [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) keeps only position).

---

void **replace\_by**(node: [Node](#class-node), keep\_groups: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-node-method-replace-by)

Replaces this node by the given `node`. All children of this node are moved to `node`.

If `keep_groups` is `true`, the `node` is added to the same groups that the replaced node is in (see [add\_to\_group()](#class-node-method-add-to-group)).

**Warning:** The replaced node is removed from the tree, but it is **not** deleted. To prevent memory leaks, store a reference to the node in a variable, or use [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free).

---

void **request\_ready**() [🔗](#class-node-method-request-ready)

Requests [\_ready()](#class-node-private-method-ready) to be called again the next time the node enters the tree. Does **not** immediately call [\_ready()](#class-node-private-method-ready).

**Note:** This method only affects the current node. If the node's children also need to request ready, this method needs to be called for each one of them. When the node and its children enter the tree again, the order of [\_ready()](#class-node-private-method-ready) callbacks will be the same as normal.

---

void **reset\_physics\_interpolation**() [🔗](#class-node-method-reset-physics-interpolation)

When physics interpolation is active, moving a node to a radically different transform (such as placement within a level) can result in a visible glitch as the object is rendered moving from the old to new position over the physics tick.

That glitch can be prevented by calling this method, which temporarily disables interpolation until the physics tick is complete.

The notification [NOTIFICATION\_RESET\_PHYSICS\_INTERPOLATION](#class-node-constant-notification-reset-physics-interpolation) will be received by the node and all children recursively.

**Note:** This function should be called **after** moving the node, rather than before.

---

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error) **rpc**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-node-method-rpc)

Sends a remote procedure call request for the given `method` to peers on the network (and locally), sending additional arguments to the method called by the RPC. The call request will only be received by nodes with the same [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath), including the exact same [name](#class-node-property-name). Behavior depends on the RPC configuration for the given `method` (see [rpc\_config()](#class-node-method-rpc-config) and [@GDScript.@rpc](https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html#class-gdscript-annotation-rpc)). By default, methods are not exposed to RPCs.

May return [@GlobalScope.OK](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-ok) if the call is successful, [@GlobalScope.ERR\_INVALID\_PARAMETER](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-invalid-parameter) if the arguments passed in the `method` do not match, [@GlobalScope.ERR\_UNCONFIGURED](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-unconfigured) if the node's [multiplayer](#class-node-property-multiplayer) cannot be fetched (such as when the node is not inside the tree), [@GlobalScope.ERR\_CONNECTION\_ERROR](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-connection-error) if [multiplayer](#class-node-property-multiplayer)'s connection is not available.

**Note:** You can only safely use RPCs on clients after you received the [MultiplayerAPI.connected\_to\_server](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi-signal-connected-to-server) signal from the [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi). You also need to keep track of the connection state, either by the [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi) signals like [MultiplayerAPI.server\_disconnected](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi-signal-server-disconnected) or by checking (`get_multiplayer().peer.get_connection_status() == CONNECTION_CONNECTED`).

---

void **rpc\_config**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), config: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) [🔗](#class-node-method-rpc-config)

Changes the RPC configuration for the given `method`. `config` should either be `null` to disable the feature (as by default), or a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) containing the following entries:

*   `rpc_mode`: see [RPCMode](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#enum-multiplayerapi-rpcmode);
    
*   `transfer_mode`: see [TransferMode](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html#enum-multiplayerpeer-transfermode);
    
*   `call_local`: if `true`, the method will also be called locally;
    
*   `channel`: an [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) representing the channel to send the RPC on.
    

**Note:** In GDScript, this method corresponds to the [@GDScript.@rpc](https://docs.godotengine.org/en/stable/classes/class_%40gdscript.html#class-gdscript-annotation-rpc) annotation, with various parameters passed (`@rpc(any)`, `@rpc(authority)`...). See also the [high-level multiplayer](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html) tutorial.

---

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error) **rpc\_id**(peer\_id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-node-method-rpc-id)

Sends a [rpc()](#class-node-method-rpc) to a specific peer identified by `peer_id` (see [MultiplayerPeer.set\_target\_peer()](https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html#class-multiplayerpeer-method-set-target-peer)).

May return [@GlobalScope.OK](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-ok) if the call is successful, [@GlobalScope.ERR\_INVALID\_PARAMETER](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-invalid-parameter) if the arguments passed in the `method` do not match, [@GlobalScope.ERR\_UNCONFIGURED](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-unconfigured) if the node's [multiplayer](#class-node-property-multiplayer) cannot be fetched (such as when the node is not inside the tree), [@GlobalScope.ERR\_CONNECTION\_ERROR](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-connection-error) if [multiplayer](#class-node-property-multiplayer)'s connection is not available.

---

void **set\_deferred\_thread\_group**(property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) [🔗](#class-node-method-set-deferred-thread-group)

Similar to [call\_deferred\_thread\_group()](#class-node-method-call-deferred-thread-group), but for setting properties.

---

void **set\_display\_folded**(fold: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-display-folded)

If set to `true`, the node appears folded in the Scene dock. As a result, all of its children are hidden. This method is intended to be used in editor plugins and tools, but it also works in release builds. See also [is\_displayed\_folded()](#class-node-method-is-displayed-folded).

---

void **set\_editable\_instance**(node: [Node](#class-node), is\_editable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-editable-instance)

Set to `true` to allow all nodes owned by `node` to be available, and editable, in the Scene dock, even if their [owner](#class-node-property-owner) is not the scene root. This method is intended to be used in editor plugins and tools, but it also works in release builds. See also [is\_editable\_instance()](#class-node-method-is-editable-instance).

---

void **set\_multiplayer\_authority**(id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), recursive: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-node-method-set-multiplayer-authority)

Sets the node's multiplayer authority to the peer with the given peer `id`. The multiplayer authority is the peer that has authority over the node on the network. Defaults to peer ID 1 (the server). Useful in conjunction with [rpc\_config()](#class-node-method-rpc-config) and the [MultiplayerAPI](https://docs.godotengine.org/en/stable/classes/class_multiplayerapi.html#class-multiplayerapi).

If `recursive` is `true`, the given peer is recursively set as the authority for all children of this node.

**Warning:** This does **not** automatically replicate the new authority to other peers. It is the developer's responsibility to do so. You may replicate the new authority's information using [MultiplayerSpawner.spawn\_function](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html#class-multiplayerspawner-property-spawn-function), an RPC, or a [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html#class-multiplayersynchronizer). Furthermore, the parent's authority does **not** propagate to newly added children.

---

void **set\_physics\_process**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-physics-process)

If set to `true`, enables physics (fixed framerate) processing. When a node is being processed, it will receive a [NOTIFICATION\_PHYSICS\_PROCESS](#class-node-constant-notification-physics-process) at a fixed (usually 60 FPS, see [Engine.physics\_ticks\_per\_second](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-physics-ticks-per-second) to change) interval (and the [\_physics\_process()](#class-node-private-method-physics-process) callback will be called if it exists).

**Note:** If [\_physics\_process()](#class-node-private-method-physics-process) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called.

---

void **set\_physics\_process\_internal**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-physics-process-internal)

If set to `true`, enables internal physics for this node. Internal physics processing happens in isolation from the normal [\_physics\_process()](#class-node-private-method-physics-process) calls and is used by some nodes internally to guarantee proper functioning even if the node is paused or physics processing is disabled for scripting ([set\_physics\_process()](#class-node-method-set-physics-process)).

**Warning:** Built-in nodes rely on internal processing for their internal logic. Disabling it is unsafe and may lead to unexpected behavior. Use this method if you know what you are doing.

---

void **set\_process**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process)

If set to `true`, enables processing. When a node is being processed, it will receive a [NOTIFICATION\_PROCESS](#class-node-constant-notification-process) on every drawn frame (and the [\_process()](#class-node-private-method-process) callback will be called if it exists).

**Note:** If [\_process()](#class-node-private-method-process) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called.

**Note:** This method only affects the [\_process()](#class-node-private-method-process) callback, i.e. it has no effect on other callbacks like [\_physics\_process()](#class-node-private-method-physics-process). If you want to disable all processing for the node, set [process\_mode](#class-node-property-process-mode) to [PROCESS\_MODE\_DISABLED](#class-node-constant-process-mode-disabled).

---

void **set\_process\_input**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process-input)

If set to `true`, enables input processing.

**Note:** If [\_input()](#class-node-private-method-input) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called. Input processing is also already enabled for GUI controls, such as [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) and [TextEdit](https://docs.godotengine.org/en/stable/classes/class_textedit.html#class-textedit).

---

void **set\_process\_internal**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process-internal)

If set to `true`, enables internal processing for this node. Internal processing happens in isolation from the normal [\_process()](#class-node-private-method-process) calls and is used by some nodes internally to guarantee proper functioning even if the node is paused or processing is disabled for scripting ([set\_process()](#class-node-method-set-process)).

**Warning:** Built-in nodes rely on internal processing for their internal logic. Disabling it is unsafe and may lead to unexpected behavior. Use this method if you know what you are doing.

---

void **set\_process\_shortcut\_input**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process-shortcut-input)

If set to `true`, enables shortcut processing for this node.

**Note:** If [\_shortcut\_input()](#class-node-private-method-shortcut-input) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called.

---

void **set\_process\_unhandled\_input**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process-unhandled-input)

If set to `true`, enables unhandled input processing. It enables the node to receive all input that was not previously handled (usually by a [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control)).

**Note:** If [\_unhandled\_input()](#class-node-private-method-unhandled-input) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called. Unhandled input processing is also already enabled for GUI controls, such as [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) and [TextEdit](https://docs.godotengine.org/en/stable/classes/class_textedit.html#class-textedit).

---

void **set\_process\_unhandled\_key\_input**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-process-unhandled-key-input)

If set to `true`, enables unhandled key input processing.

**Note:** If [\_unhandled\_key\_input()](#class-node-private-method-unhandled-key-input) is overridden, this will be automatically enabled before [\_ready()](#class-node-private-method-ready) is called.

---

void **set\_scene\_instance\_load\_placeholder**(load\_placeholder: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-node-method-set-scene-instance-load-placeholder)

If set to `true`, the node becomes an [InstancePlaceholder](https://docs.godotengine.org/en/stable/classes/class_instanceplaceholder.html#class-instanceplaceholder) when packed and instantiated from a [PackedScene](https://docs.godotengine.org/en/stable/classes/class_packedscene.html#class-packedscene). See also [get\_scene\_instance\_load\_placeholder()](#class-node-method-get-scene-instance-load-placeholder).

---

void **set\_thread\_safe**(property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) [🔗](#class-node-method-set-thread-safe)

Similar to [call\_thread\_safe()](#class-node-method-call-thread-safe), but for setting properties.

---

void **set\_translation\_domain\_inherited**() [🔗](#class-node-method-set-translation-domain-inherited)

Makes this node inherit the translation domain from its parent node. If this node has no parent, the main translation domain will be used.

This is the default behavior for all nodes. Calling [Object.set\_translation\_domain()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-set-translation-domain) disables this behavior.

---

void **update\_configuration\_warnings**() [🔗](#class-node-method-update-configuration-warnings)

Refreshes the warnings displayed for this node in the Scene dock. Use [\_get\_configuration\_warnings()](#class-node-private-method-get-configuration-warnings) to customize the warning messages to display.