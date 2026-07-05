# InputMap

**Inherits:** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A singleton that manages all [InputEventAction](https://docs.godotengine.org/en/stable/classes/class_inputeventaction.html#class-inputeventaction)s.

## Description[](#description "Link to this heading")

Manages all [InputEventAction](https://docs.godotengine.org/en/stable/classes/class_inputeventaction.html#class-inputeventaction) which can be created/modified from the project settings menu **Project > Project Settings > Input Map** or in code with [add\_action()](#class-inputmap-method-add-action) and [action\_add\_event()](#class-inputmap-method-action-add-event). See [Node.\_input()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-input).

## Tutorials[](#tutorials "Link to this heading")

*   [Using InputEvent: InputMap](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html#inputmap)
    

## Methods[](#methods "Link to this heading")

---

## Method Descriptions[](#method-descriptions "Link to this heading")

void **action\_add\_event**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) [🔗](#class-inputmap-method-action-add-event)

Adds an [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) to an action. This [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) will trigger the action.

---

void **action\_erase\_event**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) [🔗](#class-inputmap-method-action-erase-event)

Removes an [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) from an action.

---

void **action\_erase\_events**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-inputmap-method-action-erase-events)

Removes all events from an action.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **action\_get\_deadzone**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-inputmap-method-action-get-deadzone)

Returns a deadzone value for the action.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)\] **action\_get\_events**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-inputmap-method-action-get-events)

Returns an array of [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)s associated with a given action.

**Note:** When used in the editor (e.g. a tool script or [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html#class-editorplugin)), this method will return events for the editor action. If you want to access your project's input binds from the editor, read the `input/*` settings from [ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **action\_has\_event**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent)) [🔗](#class-inputmap-method-action-has-event)

Returns `true` if the action has the given [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) associated with it.

---

void **action\_set\_deadzone**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), deadzone: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-inputmap-method-action-set-deadzone)

Sets a deadzone value for the action.

---

void **add\_action**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), deadzone: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) = 0.2) [🔗](#class-inputmap-method-add-action)

Adds an empty action to the **InputMap** with a configurable `deadzone`.

An [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) can then be added to this action with [action\_add\_event()](#class-inputmap-method-action-add-event).

---

void **erase\_action**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-inputmap-method-erase-action)

Removes an action from the **InputMap**.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **event\_is\_action**(event: [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent), action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), exact\_match: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-inputmap-method-event-is-action)

Returns `true` if the given event is part of an existing action. This method ignores keyboard modifiers if the given [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) is not pressed (for proper release detection). See [action\_has\_event()](#class-inputmap-method-action-has-event) if you don't want this behavior.

If `exact_match` is `false`, it ignores additional input modifiers for [InputEventKey](https://docs.godotengine.org/en/stable/classes/class_inputeventkey.html#class-inputeventkey) and [InputEventMouseButton](https://docs.godotengine.org/en/stable/classes/class_inputeventmousebutton.html#class-inputeventmousebutton) events, and the direction for [InputEventJoypadMotion](https://docs.godotengine.org/en/stable/classes/class_inputeventjoypadmotion.html#class-inputeventjoypadmotion) events.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_action\_description**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-inputmap-method-get-action-description)

Returns the human-readable description of the given action.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)\] **get\_actions**() [🔗](#class-inputmap-method-get-actions)

Returns an array of all actions in the **InputMap**.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **has\_action**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-inputmap-method-has-action)

Returns `true` if the **InputMap** has a registered action with the given name.

---

void **load\_from\_project\_settings**() [🔗](#class-inputmap-method-load-from-project-settings)

Clears all [InputEventAction](https://docs.godotengine.org/en/stable/classes/class_inputeventaction.html#class-inputeventaction) in the **InputMap** and load it anew from [ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings).