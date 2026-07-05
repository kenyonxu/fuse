# InputEventKey

**Inherits:** [InputEventWithModifiers](https://docs.godotengine.org/en/stable/classes/class_inputeventwithmodifiers.html#class-inputeventwithmodifiers) **<** [InputEventFromWindow](https://docs.godotengine.org/en/stable/classes/class_inputeventfromwindow.html#class-inputeventfromwindow) **<** [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html#class-inputevent) **<** [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) **<** [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html#class-refcounted) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

Represents a key on a keyboard being pressed or released.

## Description[](#description "Link to this heading")

An input event for keys on a keyboard. Supports key presses, key releases and [echo](#class-inputeventkey-property-echo) events. It can also be received in [Node.\_unhandled\_key\_input()](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-private-method-unhandled-key-input).

**Note:** Events received from the keyboard usually have all properties set. Event mappings should have only one of the [keycode](#class-inputeventkey-property-keycode), [physical\_keycode](#class-inputeventkey-property-physical-keycode) or [unicode](#class-inputeventkey-property-unicode) set.

When events are compared, properties are checked in the following priority - [keycode](#class-inputeventkey-property-keycode), [physical\_keycode](#class-inputeventkey-property-physical-keycode) and [unicode](#class-inputeventkey-property-unicode). Events with the first matching value will be considered equal.

## Tutorials[](#tutorials "Link to this heading")

*   [Using InputEvent](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html)
    

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **echo** = `false` [🔗](#class-inputeventkey-property-echo)

*   void **set\_echo**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_echo**()
    

If `true`, the key was already pressed before this event. An echo event is a repeated key event sent when the user is holding down the key.

**Note:** The rate at which echo events are sent is typically around 20 events per second (after holding down the key for roughly half a second). However, the key repeat delay/speed can be changed by the user or disabled entirely in the operating system settings. To ensure your project works correctly on all configurations, do not assume the user has a specific key repeat configuration in your project's behavior.

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **key\_label** = `0` [🔗](#class-inputeventkey-property-key-label)

*   void **set\_key\_label**(value: [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key))
    
*   [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_key\_label**()
    

Represents the localized label printed on the key in the current keyboard layout, which corresponds to one of the [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) constants or any valid Unicode character.

For keyboard layouts with a single label on the key, it is equivalent to [keycode](#class-inputeventkey-property-keycode).

To get a human-readable representation of the **InputEventKey**, use `OS.get_keycode_string(event.key_label)` where `event` is the **InputEventKey**.

+-----+ +-----+
| Q   | | Q   | - "Q" - keycode
|   Й | |  ض | - "Й" and "ض" - key\_label
+-----+ +-----+

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **keycode** = `0` [🔗](#class-inputeventkey-property-keycode)

*   void **set\_keycode**(value: [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key))
    
*   [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_keycode**()
    

Latin label printed on the key in the current keyboard layout, which corresponds to one of the [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) constants.

To get a human-readable representation of the **InputEventKey**, use `OS.get_keycode_string(event.keycode)` where `event` is the **InputEventKey**.

+-----+ +-----+
| Q   | | Q   | - "Q" - keycode
|   Й | |  ض | - "Й" and "ض" - key\_label
+-----+ +-----+

---

[KeyLocation](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-keylocation) **location** = `0` [🔗](#class-inputeventkey-property-location)

*   void **set\_location**(value: [KeyLocation](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-keylocation))
    
*   [KeyLocation](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-keylocation) **get\_location**()
    

Represents the location of a key which has both left and right versions, such as Shift or Alt.

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **physical\_keycode** = `0` [🔗](#class-inputeventkey-property-physical-keycode)

*   void **set\_physical\_keycode**(value: [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key))
    
*   [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_physical\_keycode**()
    

Represents the physical location of a key on the 101/102-key US QWERTY keyboard, which corresponds to one of the [Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) constants.

To get a human-readable representation of the **InputEventKey**, use [OS.get\_keycode\_string()](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-keycode-string) in combination with [DisplayServer.keyboard\_get\_keycode\_from\_physical()](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-keyboard-get-keycode-from-physical):

func \_input(event):
	if event is InputEventKey:
		var keycode \= DisplayServer.keyboard\_get\_keycode\_from\_physical(event.physical\_keycode)
		print(OS.get\_keycode\_string(keycode))

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **pressed** = `false` [🔗](#class-inputeventkey-property-pressed)

*   void **set\_pressed**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_pressed**()
    

If `true`, the key's state is pressed. If `false`, the key's state is released.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **unicode** = `0` [🔗](#class-inputeventkey-property-unicode)

*   void **set\_unicode**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_unicode**()
    

The key Unicode character code (when relevant), shifted by modifier keys. Unicode character codes for composite characters and complex scripts may not be available unless IME input mode is active. See [Window.set\_ime\_active()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-set-ime-active) for more information.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **as\_text\_key\_label**() const [🔗](#class-inputeventkey-method-as-text-key-label)

Returns a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) representation of the event's [key\_label](#class-inputeventkey-property-key-label) and modifiers.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **as\_text\_keycode**() const [🔗](#class-inputeventkey-method-as-text-keycode)

Returns a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) representation of the event's [keycode](#class-inputeventkey-property-keycode) and modifiers.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **as\_text\_location**() const [🔗](#class-inputeventkey-method-as-text-location)

Returns a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) representation of the event's [location](#class-inputeventkey-property-location). This will be a blank string if the event is not specific to a location.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **as\_text\_physical\_keycode**() const [🔗](#class-inputeventkey-method-as-text-physical-keycode)

Returns a [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) representation of the event's [physical\_keycode](#class-inputeventkey-property-physical-keycode) and modifiers.

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_key\_label\_with\_modifiers**() const [🔗](#class-inputeventkey-method-get-key-label-with-modifiers)

Returns the localized key label combined with modifier keys such as Shift or Alt. See also [InputEventWithModifiers](https://docs.godotengine.org/en/stable/classes/class_inputeventwithmodifiers.html#class-inputeventwithmodifiers).

To get a human-readable representation of the **InputEventKey** with modifiers, use `OS.get_keycode_string(event.get_key_label_with_modifiers())` where `event` is the **InputEventKey**.

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_keycode\_with\_modifiers**() const [🔗](#class-inputeventkey-method-get-keycode-with-modifiers)

Returns the Latin keycode combined with modifier keys such as Shift or Alt. See also [InputEventWithModifiers](https://docs.godotengine.org/en/stable/classes/class_inputeventwithmodifiers.html#class-inputeventwithmodifiers).

To get a human-readable representation of the **InputEventKey** with modifiers, use `OS.get_keycode_string(event.get_keycode_with_modifiers())` where `event` is the **InputEventKey**.

---

[Key](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-key) **get\_physical\_keycode\_with\_modifiers**() const [🔗](#class-inputeventkey-method-get-physical-keycode-with-modifiers)

Returns the physical keycode combined with modifier keys such as Shift or Alt. See also [InputEventWithModifiers](https://docs.godotengine.org/en/stable/classes/class_inputeventwithmodifiers.html#class-inputeventwithmodifiers).

To get a human-readable representation of the **InputEventKey** with modifiers, use `OS.get_keycode_string(event.get_physical_keycode_with_modifiers())` where `event` is the **InputEventKey**.