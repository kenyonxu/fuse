# AnimationPlayer

**Inherits:** [AnimationMixer](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer) **<** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A node used for animation playback.

## Description[](#description "Link to this heading")

An animation player is used for general-purpose playback of animations. It contains a dictionary of [AnimationLibrary](https://docs.godotengine.org/en/stable/classes/class_animationlibrary.html#class-animationlibrary) resources and custom blend times between animation transitions.

Some methods and properties use a single key to reference an animation directly. These keys are formatted as the key for the library, followed by a forward slash, then the key for the animation within the library, for example `"movement/run"`. If the library's key is an empty string (known as the default library), the forward slash is omitted, being the same key used by the library.

**AnimationPlayer** is better-suited than [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween) for more complex animations, for example ones with non-trivial timings. It can also be used over [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html#class-tween) if the animation track editor is more convenient than doing it in code.

Updating the target properties of animations occurs at the process frame.

## Tutorials[](#tutorials "Link to this heading")

*   [2D Sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)
    
*   [Animation documentation index](https://docs.godotengine.org/en/stable/tutorials/animation/index.html)
    
*   [Third Person Shooter (TPS) Demo](https://godotengine.org/asset-library/asset/2710)
    

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)

[animation\_get\_next](#class-animationplayer-method-animation-get-next)(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

void

[animation\_set\_next](#class-animationplayer-method-animation-set-next)(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))

void

[clear\_queue](#class-animationplayer-method-clear-queue)()

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_blend\_time](#class-animationplayer-method-get-blend-time)(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode)

[get\_method\_call\_mode](#class-animationplayer-method-get-method-call-mode)() const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_playing\_speed](#class-animationplayer-method-get-playing-speed)() const

[AnimationProcessCallback](#enum-animationplayer-animationprocesscallback)

[get\_process\_callback](#class-animationplayer-method-get-process-callback)() const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[get\_queue](#class-animationplayer-method-get-queue)()

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)

[get\_root](#class-animationplayer-method-get-root)() const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_section\_end\_time](#class-animationplayer-method-get-section-end-time)() const

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)

[get\_section\_start\_time](#class-animationplayer-method-get-section-start-time)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[has\_section](#class-animationplayer-method-has-section)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_playing](#class-animationplayer-method-is-playing)() const

void

[pause](#class-animationplayer-method-pause)()

void

[play](#class-animationplayer-method-play)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[play\_backwards](#class-animationplayer-method-play-backwards)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1)

void

[play\_section](#class-animationplayer-method-play-section)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[play\_section\_backwards](#class-animationplayer-method-play-section-backwards)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1)

void

[play\_section\_with\_markers](#class-animationplayer-method-play-section-with-markers)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[play\_section\_with\_markers\_backwards](#class-animationplayer-method-play-section-with-markers-backwards)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1)

void

[play\_with\_capture](#class-animationplayer-method-play-with-capture)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1.0, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, trans\_type: [TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype) = 0, ease\_type: [EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype) = 0)

void

[queue](#class-animationplayer-method-queue)(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))

void

[reset\_section](#class-animationplayer-method-reset-section)()

void

[seek](#class-animationplayer-method-seek)(seconds: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), update: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, update\_only: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[set\_blend\_time](#class-animationplayer-method-set-blend-time)(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), sec: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))

void

[set\_method\_call\_mode](#class-animationplayer-method-set-method-call-mode)(mode: [AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode))

void

[set\_process\_callback](#class-animationplayer-method-set-process-callback)(mode: [AnimationProcessCallback](#enum-animationplayer-animationprocesscallback))

void

[set\_root](#class-animationplayer-method-set-root)(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath))

void

[set\_section](#class-animationplayer-method-set-section)(start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1)

void

[set\_section\_with\_markers](#class-animationplayer-method-set-section-with-markers)(start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"")

void

[stop](#class-animationplayer-method-stop)(keep\_state: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

---

## Signals[](#signals "Link to this heading")

**animation\_changed**(old\_name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), new\_name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-animationplayer-signal-animation-changed)

Emitted when a queued animation plays after the previous animation finished. See also [queue()](#class-animationplayer-method-queue).

**Note:** The signal is not emitted when the animation is changed via [play()](#class-animationplayer-method-play) or by an [AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html#class-animationtree).

---

**current\_animation\_changed**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-animationplayer-signal-current-animation-changed)

Emitted when [current\_animation](#class-animationplayer-property-current-animation) changes.

---

## Enumerations[](#enumerations "Link to this heading")

enum **AnimationProcessCallback**: [🔗](#enum-animationplayer-animationprocesscallback)

[AnimationProcessCallback](#enum-animationplayer-animationprocesscallback) **ANIMATION\_PROCESS\_PHYSICS** = `0`

**Deprecated:** See [AnimationMixer.ANIMATION\_CALLBACK\_MODE\_PROCESS\_PHYSICS](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-constant-animation-callback-mode-process-physics).

[AnimationProcessCallback](#enum-animationplayer-animationprocesscallback) **ANIMATION\_PROCESS\_IDLE** = `1`

**Deprecated:** See [AnimationMixer.ANIMATION\_CALLBACK\_MODE\_PROCESS\_IDLE](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-constant-animation-callback-mode-process-idle).

[AnimationProcessCallback](#enum-animationplayer-animationprocesscallback) **ANIMATION\_PROCESS\_MANUAL** = `2`

**Deprecated:** See [AnimationMixer.ANIMATION\_CALLBACK\_MODE\_PROCESS\_MANUAL](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-constant-animation-callback-mode-process-manual).

---

enum **AnimationMethodCallMode**: [🔗](#enum-animationplayer-animationmethodcallmode)

[AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode) **ANIMATION\_METHOD\_CALL\_DEFERRED** = `0`

**Deprecated:** See [AnimationMixer.ANIMATION\_CALLBACK\_MODE\_METHOD\_DEFERRED](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-constant-animation-callback-mode-method-deferred).

[AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode) **ANIMATION\_METHOD\_CALL\_IMMEDIATE** = `1`

**Deprecated:** See [AnimationMixer.ANIMATION\_CALLBACK\_MODE\_METHOD\_IMMEDIATE](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-constant-animation-callback-mode-method-immediate).

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **assigned\_animation** [🔗](#class-animationplayer-property-assigned-animation)

*   void **set\_assigned\_animation**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_assigned\_animation**()
    

If playing, the current animation's key, otherwise, the animation last played. When set, this changes the animation, but will not play it unless already playing. See also [current\_animation](#class-animationplayer-property-current-animation).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **autoplay** = `""` [🔗](#class-animationplayer-property-autoplay)

*   void **set\_autoplay**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_autoplay**()
    

The key of the animation to play when the scene loads.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **current\_animation** = `""` [🔗](#class-animationplayer-property-current-animation)

*   void **set\_current\_animation**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_current\_animation**()
    

The key of the currently playing animation. If no animation is playing, the property's value is an empty string. Changing this value does not restart the animation. See [play()](#class-animationplayer-method-play) for more information on playing animations.

**Note:** While this property appears in the Inspector, it's not meant to be edited, and it's not saved in the scene. This property is mainly used to get the currently playing animation, and internally for animation playback tracks. For more information, see [Animation](https://docs.godotengine.org/en/stable/classes/class_animation.html#class-animation).

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **current\_animation\_length** [🔗](#class-animationplayer-property-current-animation-length)

*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_current\_animation\_length**()
    

The length (in seconds) of the currently playing animation.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **current\_animation\_position** [🔗](#class-animationplayer-property-current-animation-position)

*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_current\_animation\_position**()
    

The position (in seconds) of the currently playing animation.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **movie\_quit\_on\_finish** = `false` [🔗](#class-animationplayer-property-movie-quit-on-finish)

*   void **set\_movie\_quit\_on\_finish\_enabled**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_movie\_quit\_on\_finish\_enabled**()
    

If `true` and the engine is running in Movie Maker mode (see [MovieWriter](https://docs.godotengine.org/en/stable/classes/class_moviewriter.html#class-moviewriter)), exits the engine with [SceneTree.quit()](https://docs.godotengine.org/en/stable/classes/class_scenetree.html#class-scenetree-method-quit) as soon as an animation is done playing in this **AnimationPlayer**. A message is printed when the engine quits for this reason.

**Note:** This obeys the same logic as the [AnimationMixer.animation\_finished](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-signal-animation-finished) signal, so it will not quit the engine if the animation is set to be looping.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **playback\_auto\_capture** = `true` [🔗](#class-animationplayer-property-playback-auto-capture)

*   void **set\_auto\_capture**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_auto\_capture**()
    

If `true`, performs [AnimationMixer.capture()](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-method-capture) before playback automatically. This means just [play\_with\_capture()](#class-animationplayer-method-play-with-capture) is executed with default arguments instead of [play()](#class-animationplayer-method-play).

**Note:** Capture interpolation is only performed if the animation contains a capture track. See also [Animation.UPDATE\_CAPTURE](https://docs.godotengine.org/en/stable/classes/class_animation.html#class-animation-constant-update-capture).

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **playback\_auto\_capture\_duration** = `-1.0` [🔗](#class-animationplayer-property-playback-auto-capture-duration)

*   void **set\_auto\_capture\_duration**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_auto\_capture\_duration**()
    

See also [play\_with\_capture()](#class-animationplayer-method-play-with-capture) and [AnimationMixer.capture()](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-method-capture).

If [playback\_auto\_capture\_duration](#class-animationplayer-property-playback-auto-capture-duration) is negative value, the duration is set to the interval between the current position and the first key.

---

[EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype) **playback\_auto\_capture\_ease\_type** = `0` [🔗](#class-animationplayer-property-playback-auto-capture-ease-type)

*   void **set\_auto\_capture\_ease\_type**(value: [EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype))
    
*   [EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype) **get\_auto\_capture\_ease\_type**()
    

The ease type of the capture interpolation. See also [EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype).

---

[TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype) **playback\_auto\_capture\_transition\_type** = `0` [🔗](#class-animationplayer-property-playback-auto-capture-transition-type)

*   void **set\_auto\_capture\_transition\_type**(value: [TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype))
    
*   [TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype) **get\_auto\_capture\_transition\_type**()
    

The transition type of the capture interpolation. See also [TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype).

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **playback\_default\_blend\_time** = `0.0` [🔗](#class-animationplayer-property-playback-default-blend-time)

*   void **set\_default\_blend\_time**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_default\_blend\_time**()
    

The default time in which to blend animations. Ranges from 0 to 4096 with 0.01 precision.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **speed\_scale** = `1.0` [🔗](#class-animationplayer-property-speed-scale)

*   void **set\_speed\_scale**(value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float))
    
*   [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_speed\_scale**()
    

The speed scaling ratio. For example, if this value is `1`, then the animation plays at normal speed. If it's `0.5`, then it plays at half speed. If it's `2`, then it plays at double speed.

If set to a negative value, the animation is played in reverse. If set to `0`, the animation will not advance.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **animation\_get\_next**(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-animationplayer-method-animation-get-next)

Returns the key of the animation which is queued to play after the `animation_from` animation.

---

void **animation\_set\_next**(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-animationplayer-method-animation-set-next)

Triggers the `animation_to` animation when the `animation_from` animation completes.

---

void **clear\_queue**() [🔗](#class-animationplayer-method-clear-queue)

Clears all queued, unplayed animations.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_blend\_time**(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-animationplayer-method-get-blend-time)

Returns the blend time (in seconds) between two animations, referenced by their keys.

---

[AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode) **get\_method\_call\_mode**() const [🔗](#class-animationplayer-method-get-method-call-mode)

**Deprecated:** Use [AnimationMixer.callback\_mode\_method](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-callback-mode-method) instead.

Returns the call mode used for "Call Method" tracks.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_playing\_speed**() const [🔗](#class-animationplayer-method-get-playing-speed)

Returns the actual playing speed of current animation or `0` if not playing. This speed is the [speed\_scale](#class-animationplayer-property-speed-scale) property multiplied by `custom_speed` argument specified when calling the [play()](#class-animationplayer-method-play) method.

Returns a negative value if the current animation is playing backwards.

---

[AnimationProcessCallback](#enum-animationplayer-animationprocesscallback) **get\_process\_callback**() const [🔗](#class-animationplayer-method-get-process-callback)

**Deprecated:** Use [AnimationMixer.callback\_mode\_process](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-callback-mode-process) instead.

Returns the process notification in which to update animations.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **get\_queue**() [🔗](#class-animationplayer-method-get-queue)

Returns a list of the animation keys that are currently queued to play.

---

[NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) **get\_root**() const [🔗](#class-animationplayer-method-get-root)

**Deprecated:** Use [AnimationMixer.root\_node](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-root-node) instead.

Returns the node which node path references will travel from.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_section\_end\_time**() const [🔗](#class-animationplayer-method-get-section-end-time)

Returns the end time of the section currently being played.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_section\_start\_time**() const [🔗](#class-animationplayer-method-get-section-start-time)

Returns the start time of the section currently being played.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **has\_section**() const [🔗](#class-animationplayer-method-has-section)

Returns `true` if an animation is currently playing with a section.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_playing**() const [🔗](#class-animationplayer-method-is-playing)

Returns `true` if an animation is currently playing (even if [speed\_scale](#class-animationplayer-property-speed-scale) and/or `custom_speed` are `0`).

---

void **pause**() [🔗](#class-animationplayer-method-pause)

Pauses the currently playing animation. The [current\_animation\_position](#class-animationplayer-property-current-animation-position) will be kept and calling [play()](#class-animationplayer-method-play) or [play\_backwards()](#class-animationplayer-method-play-backwards) without arguments or with the same animation name as [assigned\_animation](#class-animationplayer-property-assigned-animation) will resume the animation.

See also [stop()](#class-animationplayer-method-stop).

---

void **play**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-animationplayer-method-play)

Plays the animation with key `name`. Custom blend times and speed can be set.

The `from_end` option only affects when switching to a new animation track, or if the same track but at the start or end. It does not affect resuming playback that was paused in the middle of an animation. If `custom_speed` is negative and `from_end` is `true`, the animation will play backwards (which is equivalent to calling [play\_backwards()](#class-animationplayer-method-play-backwards)).

The **AnimationPlayer** keeps track of its current or last played animation with [assigned\_animation](#class-animationplayer-property-assigned-animation). If this method is called with that same animation `name`, or with no `name` parameter, the assigned animation will resume playing if it was paused.

**Note:** The animation will be updated the next time the **AnimationPlayer** is processed. If other variables are updated at the same time this is called, they may be updated too early. To perform the update immediately, call `advance(0)`.

---

void **play\_backwards**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1) [🔗](#class-animationplayer-method-play-backwards)

Plays the animation with key `name` in reverse.

This method is a shorthand for [play()](#class-animationplayer-method-play) with `custom_speed = -1.0` and `from_end = true`, so see its description for more information.

---

void **play\_section**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-animationplayer-method-play-section)

Plays the animation with key `name` and the section starting from `start_time` and ending on `end_time`. See also [play()](#class-animationplayer-method-play).

Setting `start_time` to a value outside the range of the animation means the start of the animation will be used instead, and setting `end_time` to a value outside the range of the animation means the end of the animation will be used instead. `start_time` cannot be equal to `end_time`.

---

void **play\_section\_backwards**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1) [🔗](#class-animationplayer-method-play-section-backwards)

Plays the animation with key `name` and the section starting from `start_time` and ending on `end_time` in reverse.

This method is a shorthand for [play\_section()](#class-animationplayer-method-play-section) with `custom_speed = -1.0` and `from_end = true`, see its description for more information.

---

void **play\_section\_with\_markers**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-animationplayer-method-play-section-with-markers)

Plays the animation with key `name` and the section starting from `start_marker` and ending on `end_marker`.

If the start marker is empty, the section starts from the beginning of the animation. If the end marker is empty, the section ends on the end of the animation. See also [play()](#class-animationplayer-method-play).

---

void **play\_section\_with\_markers\_backwards**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1) [🔗](#class-animationplayer-method-play-section-with-markers-backwards)

Plays the animation with key `name` and the section starting from `start_marker` and ending on `end_marker` in reverse.

This method is a shorthand for [play\_section\_with\_markers()](#class-animationplayer-method-play-section-with-markers) with `custom_speed = -1.0` and `from_end = true`, see its description for more information.

---

void **play\_with\_capture**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", duration: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1.0, custom\_blend: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, custom\_speed: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 1.0, from\_end: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, trans\_type: [TransitionType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-transitiontype) = 0, ease\_type: [EaseType](https://docs.godotengine.org/en/stable/classes/class_tween.html#enum-tween-easetype) = 0) [🔗](#class-animationplayer-method-play-with-capture)

See also [AnimationMixer.capture()](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-method-capture).

You can use this method to use more detailed options for capture than those performed by [playback\_auto\_capture](#class-animationplayer-property-playback-auto-capture). When [playback\_auto\_capture](#class-animationplayer-property-playback-auto-capture) is `false`, this method is almost the same as the following:

capture(name, duration, trans\_type, ease\_type)
play(name, custom\_blend, custom\_speed, from\_end)

If `name` is blank, it specifies [assigned\_animation](#class-animationplayer-property-assigned-animation).

If `duration` is a negative value, the duration is set to the interval between the current position and the first key, when `from_end` is `true`, uses the interval between the current position and the last key instead.

**Note:** The `duration` takes [speed\_scale](#class-animationplayer-property-speed-scale) into account, but `custom_speed` does not, because the capture cache is interpolated with the blend result and the result may contain multiple animations.

---

void **queue**(name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-animationplayer-method-queue)

Queues an animation for playback once the current animation and all previously queued animations are done.

**Note:** If a looped animation is currently playing, the queued animation will never play unless the looped animation is stopped somehow.

---

void **reset\_section**() [🔗](#class-animationplayer-method-reset-section)

Resets the current section. Does nothing if a section has not been set.

---

void **seek**(seconds: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), update: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, update\_only: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-animationplayer-method-seek)

Seeks the animation to the `seconds` point in time (in seconds). If `update` is `true`, the animation updates too, otherwise it updates at process time. Events between the current frame and `seconds` are skipped.

If `update_only` is `true`, the method / audio / animation playback tracks will not be processed.

**Note:** Seeking to the end of the animation doesn't emit [AnimationMixer.animation\_finished](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-signal-animation-finished). If you want to skip animation and emit the signal, use [AnimationMixer.advance()](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-method-advance).

---

void **set\_blend\_time**(animation\_from: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), animation\_to: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), sec: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-animationplayer-method-set-blend-time)

Specifies a blend time (in seconds) between two animations, referenced by their keys.

---

void **set\_method\_call\_mode**(mode: [AnimationMethodCallMode](#enum-animationplayer-animationmethodcallmode)) [🔗](#class-animationplayer-method-set-method-call-mode)

**Deprecated:** Use [AnimationMixer.callback\_mode\_method](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-callback-mode-method) instead.

Sets the call mode used for "Call Method" tracks.

---

void **set\_process\_callback**(mode: [AnimationProcessCallback](#enum-animationplayer-animationprocesscallback)) [🔗](#class-animationplayer-method-set-process-callback)

**Deprecated:** Use [AnimationMixer.callback\_mode\_process](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-callback-mode-process) instead.

Sets the process notification in which to update animations.

---

void **set\_root**(path: [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath)) [🔗](#class-animationplayer-method-set-root)

**Deprecated:** Use [AnimationMixer.root\_node](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html#class-animationmixer-property-root-node) instead.

Sets the node which node path references will travel from.

---

void **set\_section**(start\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1, end\_time: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = -1) [🔗](#class-animationplayer-method-set-section)

Changes the start and end times of the section being played. The current playback position will be clamped within the new section. See also [play\_section()](#class-animationplayer-method-play-section).

---

void **set\_section\_with\_markers**(start\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"", end\_marker: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) = &"") [🔗](#class-animationplayer-method-set-section-with-markers)

Changes the start and end markers of the section being played. The current playback position will be clamped within the new section. See also [play\_section\_with\_markers()](#class-animationplayer-method-play-section-with-markers).

If the argument is empty, the section uses the beginning or end of the animation. If both are empty, it means that the section is not set.

---

void **stop**(keep\_state: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-animationplayer-method-stop)

Stops the currently playing animation. The animation position is reset to `0` and the `custom_speed` is reset to `1.0`. See also [pause()](#class-animationplayer-method-pause).

If `keep_state` is `true`, the animation state is not updated visually.

**Note:** The method / audio / animation playback tracks will not be processed by this method.