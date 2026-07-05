

**Inherits:** [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html#class-refcounted) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

Lightweight object used for general-purpose animation via script, using [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s.

## Description[](#description "Link to this heading")

Tweens are mostly useful for animations requiring a numerical property to be interpolated over a range of values. The name *tween* comes from *in-betweening*, an animation technique where you specify *keyframes* and the computer interpolates the frames that appear between them. Animating something with a **Tween** is called tweening.

**Tween** is more suited than [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer) for animations where you don't know the final values in advance. For example, interpolating a dynamically-chosen camera zoom value is best done with a **Tween**; it would be difficult to do the same thing with an [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer) node. Tweens are also more light-weight than [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer), so they are very much suited for simple animations or general tasks that don't require visual tweaking provided by the editor. They can be used in a "fire-and-forget" manner for some logic that normally would be done by code. You can e.g. make something shoot periodically by using a looped [CallbackTweener](https://docs.godotengine.org/en/stable/classes/class_callbacktweener.html#class-callbacktweener) with a delay.

A **Tween** can be created by using either [SceneTree.create\_tween()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-create-tween) or [Node.create\_tween()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-create-tween). **Tween**s created manually (i.e. by using `Tween.new()`) are invalid and can't be used for tweening values.

A tween animation is created by adding [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s to the **Tween** object, using [tween\_property()](#class-tween-method-tween-property), [tween\_interval()](#class-tween-method-tween-interval), [tween\_callback()](#class-tween-method-tween-callback) or [tween\_method()](#class-tween-method-tween-method):

var tween \= get\_tree().create\_tween()
tween.tween\_property($Sprite, "modulate", Color.RED, 1.0)
tween.tween\_property($Sprite, "scale", Vector2(), 1.0)
tween.tween\_callback($Sprite.queue\_free)

This sequence will make the `$Sprite` node turn red, then shrink, before finally calling [Node.queue\_free()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-queue-free) to free the sprite. [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s are executed one after another by default. This behavior can be changed using [parallel()](#class-tween-method-parallel) and [set\_parallel()](#class-tween-method-set-parallel).

When a [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener) is created with one of the `tween_*` methods, a chained method call can be used to tweak the properties of this [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener). For example, if you want to set a different transition type in the above example, you can use [set\_trans()](#class-tween-method-set-trans):

var tween \= get\_tree().create\_tween()
tween.tween\_property($Sprite, "modulate", Color.RED, 1.0).set\_trans(Tween.TRANS\_SINE)
tween.tween\_property($Sprite, "scale", Vector2(), 1.0).set\_trans(Tween.TRANS\_BOUNCE)
tween.tween\_callback($Sprite.queue\_free)

Most of the **Tween** methods can be chained this way too. In the following example the **Tween** is bound to the running script's node and a default transition is set for its [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s:

var tween \= get\_tree().create\_tween().bind\_node(self).set\_trans(Tween.TRANS\_ELASTIC)
tween.tween\_property($Sprite, "modulate", Color.RED, 1.0)
tween.tween\_property($Sprite, "scale", Vector2(), 1.0)
tween.tween\_callback($Sprite.queue\_free)

Another interesting use for **Tween**s is animating arbitrary sets of objects:

var tween \= create\_tween()
for sprite in get\_children():
	tween.tween\_property(sprite, "position", Vector2(0, 0), 1.0)

In the example above, all children of a node are moved one after another to position `(0, 0)`.

You should avoid using more than one **Tween** per object's property. If two or more tweens animate one property at the same time, the last one created will take priority and assign the final value. If you want to interrupt and restart an animation, consider assigning the **Tween** to a variable:

var tween
func animate():
	if tween:
		tween.kill() \# Abort the previous animation.
	tween \= create\_tween()

Some [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s use transitions and eases. The first accepts a [TransitionType](#enum-tween-transitiontype) constant, and refers to the way the timing of the animation is handled (see [easings.net](https://easings.net/) for some examples). The second accepts an [EaseType](#enum-tween-easetype) constant, and controls where the `trans_type` is applied to the interpolation (in the beginning, the end, or both). If you don't know which transition and easing to pick, you can try different [TransitionType](#enum-tween-transitiontype) constants with [EASE\_IN\_OUT](#class-tween-constant-ease-in-out), and use the one that looks best.

[Tween easing and transition types cheatsheet](https://raw.githubusercontent.com/godotengine/godot-docs/master/img/tween_cheatsheet.webp)

**Note:** Tweens are not designed to be reused and trying to do so results in an undefined behavior. Create a new Tween for each animation and every time you replay an animation from start. Keep in mind that Tweens start immediately, so only create a Tween when you want to start animating.

**Note:** The tween is processed after all of the nodes in the current frame, i.e. node's [Node.\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-process) method would be called before the tween (or [Node.\_physics\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-physics-process) depending on the value passed to [set\_process\_mode()](#class-tween-method-set-process-mode)).

## Methods[](#methods "Link to this heading")

[Tween](#class-tween)

[bind\_node](#class-tween-method-bind-node)(node: [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node))

[Tween](#class-tween)

[chain](#class-tween-method-chain)()

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[custom\_step](#class-tween-method-custom-step)(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_loops\_left](#class-tween-method-get-loops-left)() const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_total\_elapsed\_time](#class-tween-method-get-total-elapsed-time)() const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[interpolate\_value](#class-tween-method-interpolate-value)(initial\_value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), delta\_value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), elapsed\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), trans\_type: [TransitionType](#enum-tween-transitiontype), ease\_type: [EaseType](#enum-tween-easetype)) static

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_running](#class-tween-method-is-running)()

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_valid](#class-tween-method-is-valid)()

void

[kill](#class-tween-method-kill)()

[Tween](#class-tween)

[parallel](#class-tween-method-parallel)()

void

[pause](#class-tween-method-pause)()

void

[play](#class-tween-method-play)()

[Tween](#class-tween)

[set\_ease](#class-tween-method-set-ease)(ease: [EaseType](#enum-tween-easetype))

[Tween](#class-tween)

[set\_ignore\_time\_scale](#class-tween-method-set-ignore-time-scale)(ignore: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true)

[Tween](#class-tween)

[set\_loops](#class-tween-method-set-loops)(loops: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 0)

[Tween](#class-tween)

[set\_parallel](#class-tween-method-set-parallel)(parallel: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true)

[Tween](#class-tween)

[set\_pause\_mode](#class-tween-method-set-pause-mode)(mode: [TweenPauseMode](#enum-tween-tweenpausemode))

[Tween](#class-tween)

[set\_process\_mode](#class-tween-method-set-process-mode)(mode: [TweenProcessMode](#enum-tween-tweenprocessmode))

[Tween](#class-tween)

[set\_speed\_scale](#class-tween-method-set-speed-scale)(speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

[Tween](#class-tween)

[set\_trans](#class-tween-method-set-trans)(trans: [TransitionType](#enum-tween-transitiontype))

void

[stop](#class-tween-method-stop)()

[CallbackTweener](https://docs.godotengine.org/en/stable/classes/class_callbacktweener.html#class-callbacktweener)

[tween\_callback](#class-tween-method-tween-callback)(callback: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable))

[IntervalTweener](https://docs.godotengine.org/en/stable/classes/class_intervaltweener.html#class-intervaltweener)

[tween\_interval](#class-tween-method-tween-interval)(time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

[MethodTweener](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener)

[tween\_method](#class-tween-method-tween-method)(method: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable), from: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), to: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

[PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener)

[tween\_property](#class-tween-method-tween-property)(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath), final\_val: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

[SubtweenTweener](https://docs.godotengine.org/en/stable/classes/class_subtweentweener.html#class-subtweentweener)

[tween\_subtween](#class-tween-method-tween-subtween)(subtween: [Tween](#class-tween))

---

## Signals[](#signals "Link to this heading")

**finished**() [🔗](#class-tween-signal-finished)

Emitted when the **Tween** has finished all tweening. Never emitted when the **Tween** is set to infinite looping (see [set\_loops()](#class-tween-method-set-loops)).

---

**loop\_finished**(loop\_count: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tween-signal-loop-finished)

Emitted when a full loop is complete (see [set\_loops()](#class-tween-method-set-loops)), providing the loop index. This signal is not emitted after the final loop, use [finished](#class-tween-signal-finished) instead for this case.

---

**step\_finished**(idx: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tween-signal-step-finished)

Emitted when one step of the **Tween** is complete, providing the step index. One step is either a single [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener) or a group of [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s running in parallel.

---

## Enumerations[](#enumerations "Link to this heading")

enum **TweenProcessMode**: [🔗](#enum-tween-tweenprocessmode)

[TweenProcessMode](#enum-tween-tweenprocessmode) **TWEEN\_PROCESS\_PHYSICS** = `0`

The **Tween** updates after each physics frame (see [Node.\_physics\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-physics-process)).

[TweenProcessMode](#enum-tween-tweenprocessmode) **TWEEN\_PROCESS\_IDLE** = `1`

The **Tween** updates after each process frame (see [Node.\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-process)).

---

enum **TweenPauseMode**: [🔗](#enum-tween-tweenpausemode)

[TweenPauseMode](#enum-tween-tweenpausemode) **TWEEN\_PAUSE\_BOUND** = `0`

If the **Tween** has a bound node, it will process when that node can process (see [Node.process\_mode](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-property-process-mode)). Otherwise it's the same as [TWEEN\_PAUSE\_STOP](#class-tween-constant-tween-pause-stop).

[TweenPauseMode](#enum-tween-tweenpausemode) **TWEEN\_PAUSE\_STOP** = `1`

If [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) is paused, the **Tween** will also pause.

[TweenPauseMode](#enum-tween-tweenpausemode) **TWEEN\_PAUSE\_PROCESS** = `2`

The **Tween** will process regardless of whether [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) is paused.

---

enum **TransitionType**: [🔗](#enum-tween-transitiontype)

[TransitionType](#enum-tween-transitiontype) **TRANS\_LINEAR** = `0`

The animation is interpolated linearly.

[TransitionType](#enum-tween-transitiontype) **TRANS\_SINE** = `1`

The animation is interpolated using a sine function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_QUINT** = `2`

The animation is interpolated with a quintic (to the power of 5) function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_QUART** = `3`

The animation is interpolated with a quartic (to the power of 4) function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_QUAD** = `4`

The animation is interpolated with a quadratic (to the power of 2) function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_EXPO** = `5`

The animation is interpolated with an exponential (to the power of x) function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_ELASTIC** = `6`

The animation is interpolated with elasticity, wiggling around the edges.

[TransitionType](#enum-tween-transitiontype) **TRANS\_CUBIC** = `7`

The animation is interpolated with a cubic (to the power of 3) function.

[TransitionType](#enum-tween-transitiontype) **TRANS\_CIRC** = `8`

The animation is interpolated with a function using square roots.

[TransitionType](#enum-tween-transitiontype) **TRANS\_BOUNCE** = `9`

The animation is interpolated by bouncing at the end.

[TransitionType](#enum-tween-transitiontype) **TRANS\_BACK** = `10`

The animation is interpolated backing out at ends.

[TransitionType](#enum-tween-transitiontype) **TRANS\_SPRING** = `11`

The animation is interpolated like a spring towards the end.

---

enum **EaseType**: [🔗](#enum-tween-easetype)

[EaseType](#enum-tween-easetype) **EASE\_IN** = `0`

The interpolation starts slowly and speeds up towards the end.

[EaseType](#enum-tween-easetype) **EASE\_OUT** = `1`

The interpolation starts quickly and slows down towards the end.

[EaseType](#enum-tween-easetype) **EASE\_IN\_OUT** = `2`

A combination of [EASE\_IN](#class-tween-constant-ease-in) and [EASE\_OUT](#class-tween-constant-ease-out). The interpolation is slowest at both ends.

[EaseType](#enum-tween-easetype) **EASE\_OUT\_IN** = `3`

A combination of [EASE\_IN](#class-tween-constant-ease-in) and [EASE\_OUT](#class-tween-constant-ease-out). The interpolation is fastest at both ends.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[Tween](#class-tween) **bind\_node**(node: [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node)) [🔗](#class-tween-method-bind-node)

Binds this **Tween** with the given `node`. **Tween**s are processed directly by the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree), so they run independently of the animated nodes. When you bind a [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) with the **Tween**, the **Tween** will halt the animation when the object is not inside tree and the **Tween** will be automatically killed when the bound object is freed. Also [TWEEN\_PAUSE\_BOUND](#class-tween-constant-tween-pause-bound) will make the pausing behavior dependent on the bound node.

For a shorter way to create and bind a **Tween**, you can use [Node.create\_tween()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-method-create-tween).

---

[Tween](#class-tween) **chain**() [🔗](#class-tween-method-chain)

Used to chain two [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s after [set\_parallel()](#class-tween-method-set-parallel) is called with `true`.

var tween \= create\_tween().set\_parallel(true)
tween.tween\_property(...)
tween.tween\_property(...) \# Will run parallelly with above.
tween.chain().tween\_property(...) \# Will run after two above are finished.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **custom\_step**(delta: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-tween-method-custom-step)

Processes the **Tween** by the given `delta` value, in seconds. This is mostly useful for manual control when the **Tween** is paused. It can also be used to end the **Tween** animation immediately, by setting `delta` longer than the whole duration of the **Tween** animation.

Returns `true` if the **Tween** still has [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s that haven't finished.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_loops\_left**() const [🔗](#class-tween-method-get-loops-left)

Returns the number of remaining loops for this **Tween** (see [set\_loops()](#class-tween-method-set-loops)). A return value of `-1` indicates an infinitely looping **Tween**, and a return value of `0` indicates that the **Tween** has already finished.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_total\_elapsed\_time**() const [🔗](#class-tween-method-get-total-elapsed-time)

Returns the total time in seconds the **Tween** has been animating (i.e. the time since it started, not counting pauses etc.). The time is affected by [set\_speed\_scale()](#class-tween-method-set-speed-scale), and [stop()](#class-tween-method-stop) will reset it to `0`.

**Note:** As it results from accumulating frame deltas, the time returned after the **Tween** has finished animating will be slightly greater than the actual **Tween** duration.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **interpolate\_value**(initial\_value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), delta\_value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), elapsed\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), trans\_type: [TransitionType](#enum-tween-transitiontype), ease\_type: [EaseType](#enum-tween-easetype)) static [🔗](#class-tween-method-interpolate-value)

This method can be used for manual interpolation of a value, when you don't want **Tween** to do animating for you. It's similar to [@GlobalScope.lerp()](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-method-lerp), but with support for custom transition and easing.

`initial_value` is the starting value of the interpolation.

`delta_value` is the change of the value in the interpolation, i.e. it's equal to `final_value - initial_value`.

`elapsed_time` is the time in seconds that passed after the interpolation started and it's used to control the position of the interpolation. E.g. when it's equal to half of the `duration`, the interpolated value will be halfway between initial and final values. This value can also be greater than `duration` or lower than 0, which will extrapolate the value.

`duration` is the total time of the interpolation.

**Note:** If `duration` is equal to `0`, the method will always return the final value, regardless of `elapsed_time` provided.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_running**() [🔗](#class-tween-method-is-running)

Returns whether the **Tween** is currently running, i.e. it wasn't paused and it's not finished.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_valid**() [🔗](#class-tween-method-is-valid)

Returns whether the **Tween** is valid. A valid **Tween** is a **Tween** contained by the scene tree (i.e. the array from [SceneTree.get\_processed\_tweens()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-get-processed-tweens) will contain this **Tween**). A **Tween** might become invalid when it has finished tweening, is killed, or when created with `Tween.new()`. Invalid **Tween**s can't have [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s appended.

---

void **kill**() [🔗](#class-tween-method-kill)

Aborts all tweening operations and invalidates the **Tween**.

---

[Tween](#class-tween) **parallel**() [🔗](#class-tween-method-parallel)

Makes the next [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener) run parallelly to the previous one.

var tween \= create\_tween()
tween.tween\_property(...)
tween.parallel().tween\_property(...)
tween.parallel().tween\_property(...)

All [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s in the example will run at the same time.

You can make the **Tween** parallel by default by using [set\_parallel()](#class-tween-method-set-parallel).

---

void **pause**() [🔗](#class-tween-method-pause)

Pauses the tweening. The animation can be resumed by using [play()](#class-tween-method-play).

**Note:** If a Tween is paused and not bound to any node, it will exist indefinitely until manually started or invalidated. If you lose a reference to such Tween, you can retrieve it using [SceneTree.get\_processed\_tweens()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-get-processed-tweens).

---

void **play**() [🔗](#class-tween-method-play)

Resumes a paused or stopped **Tween**.

---

[Tween](#class-tween) **set\_ease**(ease: [EaseType](#enum-tween-easetype)) [🔗](#class-tween-method-set-ease)

Sets the default ease type for [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener)s and [MethodTweener](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener)s appended after this method.

Before this method is called, the default ease type is [EASE\_IN\_OUT](#class-tween-constant-ease-in-out).

var tween \= create\_tween()
tween.tween\_property(self, "position", Vector2(300, 0), 0.5) \# Uses EASE\_IN\_OUT.
tween.set\_ease(Tween.EASE\_IN)
tween.tween\_property(self, "rotation\_degrees", 45.0, 0.5) \# Uses EASE\_IN.

---

[Tween](#class-tween) **set\_ignore\_time\_scale**(ignore: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-tween-method-set-ignore-time-scale)

If `ignore` is `true`, the tween will ignore [Engine.time\_scale](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-time-scale) and update with the real, elapsed time. This affects all [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s and their delays. Default value is `false`.

---

[Tween](#class-tween) **set\_loops**(loops: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 0) [🔗](#class-tween-method-set-loops)

Sets the number of times the tweening sequence will be repeated, i.e. `set_loops(2)` will run the animation twice.

Calling this method without arguments will make the **Tween** run infinitely, until either it is killed with [kill()](#class-tween-method-kill), the **Tween**'s bound node is freed, or all the animated objects have been freed (which makes further animation impossible).

**Warning:** Make sure to always add some duration/delay when using infinite loops. To prevent the game freezing, 0-duration looped animations (e.g. a single [CallbackTweener](https://docs.godotengine.org/en/stable/classes/class_callbacktweener.html#class-callbacktweener) with no delay) are stopped after a small number of loops, which may produce unexpected results. If a **Tween**'s lifetime depends on some node, always use [bind\_node()](#class-tween-method-bind-node).

---

[Tween](#class-tween) **set\_parallel**(parallel: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-tween-method-set-parallel)

If `parallel` is `true`, the [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s appended after this method will by default run simultaneously, as opposed to sequentially.

**Note:** Just like with [parallel()](#class-tween-method-parallel), the tweener added right before this method will also be part of the parallel step.

tween.tween\_property(self, "position", Vector2(300, 0), 0.5)
tween.set\_parallel()
tween.tween\_property(self, "modulate", Color.GREEN, 0.5) \# Runs together with the position tweener.

---

[Tween](#class-tween) **set\_pause\_mode**(mode: [TweenPauseMode](#enum-tween-tweenpausemode)) [🔗](#class-tween-method-set-pause-mode)

Determines the behavior of the **Tween** when the [SceneTree](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree) is paused.

Default value is [TWEEN\_PAUSE\_BOUND](#class-tween-constant-tween-pause-bound).

---

[Tween](#class-tween) **set\_process\_mode**(mode: [TweenProcessMode](#enum-tween-tweenprocessmode)) [🔗](#class-tween-method-set-process-mode)

Determines whether the **Tween** should run after process frames (see [Node.\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-process)) or physics frames (see [Node.\_physics\_process()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-physics-process)).

Default value is [TWEEN\_PROCESS\_IDLE](#class-tween-constant-tween-process-idle).

---

[Tween](#class-tween) **set\_speed\_scale**(speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-tween-method-set-speed-scale)

Scales the speed of tweening. This affects all [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s and their delays.

---

[Tween](#class-tween) **set\_trans**(trans: [TransitionType](#enum-tween-transitiontype)) [🔗](#class-tween-method-set-trans)

Sets the default transition type for [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener)s and [MethodTweener](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener)s appended after this method.

Before this method is called, the default transition type is [TRANS\_LINEAR](#class-tween-constant-trans-linear).

var tween \= create\_tween()
tween.tween\_property(self, "position", Vector2(300, 0), 0.5) \# Uses TRANS\_LINEAR.
tween.set\_trans(Tween.TRANS\_SINE)
tween.tween\_property(self, "rotation\_degrees", 45.0, 0.5) \# Uses TRANS\_SINE.

---

void **stop**() [🔗](#class-tween-method-stop)

Stops the tweening and resets the **Tween** to its initial state. This will not remove any appended [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s.

**Note:** This does *not* reset targets of [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener)s to their values when the **Tween** first started.

var tween \= create\_tween()

\# Will move from 0 to 500 over 1 second.
position.x \= 0.0
tween.tween\_property(self, "position:x", 500, 1.0)

\# Will be at (about) 250 when the timer finishes.
await get\_tree().create\_timer(0.5).timeout

\# Will now move from (about) 250 to 500 over 1 second,
\# thus at half the speed as before.
tween.stop()
tween.play()

**Note:** If a Tween is stopped and not bound to any node, it will exist indefinitely until manually started or invalidated. If you lose a reference to such Tween, you can retrieve it using [SceneTree.get\_processed\_tweens()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-get-processed-tweens).

---

[CallbackTweener](https://docs.godotengine.org/en/stable/classes/class_callbacktweener.html#class-callbacktweener) **tween\_callback**(callback: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable)) [🔗](#class-tween-method-tween-callback)

Creates and appends a [CallbackTweener](https://docs.godotengine.org/en/stable/classes/class_callbacktweener.html#class-callbacktweener). This method can be used to call an arbitrary method in any object. Use [Callable.bind()](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable-method-bind) to bind additional arguments for the call.

**Example:** Object that keeps shooting every 1 second:

var tween \= get\_tree().create\_tween().set\_loops()
tween.tween\_callback(shoot).set\_delay(1.0)

**Example:** Turning a sprite red and then blue, with 2 second delay:

var tween \= get\_tree().create\_tween()
tween.tween\_callback($Sprite.set\_modulate.bind(Color.RED)).set\_delay(2)
tween.tween\_callback($Sprite.set\_modulate.bind(Color.BLUE)).set\_delay(2)

---

[IntervalTweener](https://docs.godotengine.org/en/stable/classes/class_intervaltweener.html#class-intervaltweener) **tween\_interval**(time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-tween-method-tween-interval)

Creates and appends an [IntervalTweener](https://docs.godotengine.org/en/stable/classes/class_intervaltweener.html#class-intervaltweener). This method can be used to create delays in the tween animation, as an alternative to using the delay in other [Tweener](https://docs.godotengine.org/en/stable/classes/class_tweener.html#class-tweener)s, or when there's no animation (in which case the **Tween** acts as a timer). `time` is the length of the interval, in seconds.

**Example:** Creating an interval in code execution:

\# ... some code
await create\_tween().tween\_interval(2).finished
\# ... more code

**Example:** Creating an object that moves back and forth and jumps every few seconds:

var tween \= create\_tween().set\_loops()
tween.tween\_property($Sprite, "position:x", 200.0, 1.0).as\_relative()
tween.tween\_callback(jump)
tween.tween\_interval(2)
tween.tween\_property($Sprite, "position:x", \-200.0, 1.0).as\_relative()
tween.tween\_callback(jump)
tween.tween\_interval(2)

---

[MethodTweener](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener) **tween\_method**(method: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable), from: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), to: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-tween-method-tween-method)

Creates and appends a [MethodTweener](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener). This method is similar to a combination of [tween\_callback()](#class-tween-method-tween-callback) and [tween\_property()](#class-tween-method-tween-property). It calls a method over time with a tweened value provided as an argument. The value is tweened between `from` and `to` over the time specified by `duration`, in seconds. Use [Callable.bind()](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable-method-bind) to bind additional arguments for the call. You can use [MethodTweener.set\_ease()](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener-method-set-ease) and [MethodTweener.set\_trans()](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener-method-set-trans) to tweak the easing and transition of the value or [MethodTweener.set\_delay()](https://docs.godotengine.org/en/stable/classes/class_methodtweener.html#class-methodtweener-method-set-delay) to delay the tweening.

**Example:** Making a 3D object look from one point to another point:

var tween \= create\_tween()
tween.tween\_method(look\_at.bind(Vector3.UP), Vector3(\-1, 0, \-1), Vector3(1, 0, \-1), 1.0) \# The look\_at() method takes up vector as second argument.

**Example:** Setting the text of a [Label](https://docs.godotengine.org/en/stable/classes/class_label.html#class-label), using an intermediate method and after a delay:

func \_ready():
	var tween \= create\_tween()
	tween.tween\_method(set\_label\_text, 0, 10, 1.0).set\_delay(1.0)

func set\_label\_text(value: int):
	$Label.text \= "Counting " + str(value)

---

[PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener) **tween\_property**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath), final\_val: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-tween-method-tween-property)

Creates and appends a [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener). This method tweens a `property` of an `object` between an initial value and `final_val` in a span of time equal to `duration`, in seconds. The initial value by default is the property's value at the time the tweening of the [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener) starts.

var tween \= create\_tween()
tween.tween\_property($Sprite, "position", Vector2(100, 200), 1.0)
tween.tween\_property($Sprite, "position", Vector2(200, 300), 1.0)

will move the sprite to position (100, 200) and then to (200, 300). If you use [PropertyTweener.from()](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener-method-from) or [PropertyTweener.from\_current()](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener-method-from-current), the starting position will be overwritten by the given value instead. See other methods in [PropertyTweener](https://docs.godotengine.org/en/stable/classes/class_propertytweener.html#class-propertytweener) to see how the tweening can be tweaked further.

**Note:** You can find the correct property name by hovering over the property in the Inspector. You can also provide the components of a property directly by using `"property:component"` (eg. `position:x`), where it would only apply to that particular component.

**Example:** Moving an object twice from the same position, with different transition types:

var tween \= create\_tween()
tween.tween\_property($Sprite, "position", Vector2.RIGHT \* 300, 1.0).as\_relative().set\_trans(Tween.TRANS\_SINE)
tween.tween\_property($Sprite, "position", Vector2.RIGHT \* 300, 1.0).as\_relative().from\_current().set\_trans(Tween.TRANS\_EXPO)

---

[SubtweenTweener](https://docs.godotengine.org/en/stable/classes/class_subtweentweener.html#class-subtweentweener) **tween\_subtween**(subtween: [Tween](#class-tween)) [🔗](#class-tween-method-tween-subtween)

Creates and appends a [SubtweenTweener](https://docs.godotengine.org/en/stable/classes/class_subtweentweener.html#class-subtweentweener). This method can be used to nest `subtween` within this **Tween**, allowing for the creation of more complex and composable sequences.

\# Subtween will rotate the object.
var subtween \= create\_tween()
subtween.tween\_property(self, "rotation\_degrees", 45.0, 1.0)
subtween.tween\_property(self, "rotation\_degrees", 0.0, 1.0)

\# Parent tween will execute the subtween as one of its steps.
var tween \= create\_tween()
tween.tween\_property(self, "position:x", 500, 3.0)
tween.tween\_subtween(subtween)
tween.tween\_property(self, "position:x", 300, 2.0)

**Note:** The methods [pause()](#class-tween-method-pause), [stop()](#class-tween-method-stop), and [set\_loops()](#class-tween-method-set-loops) can cause the parent **Tween** to get stuck on the subtween step; see the documentation for those methods for more information.

**Note:** The pause and process modes set by [set\_pause\_mode()](#class-tween-method-set-pause-mode) and [set\_process\_mode()](#class-tween-method-set-process-mode) on `subtween` will be overridden by the parent **Tween**'s settings.