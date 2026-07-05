# AcceptDialog

**Inherits:** [Window](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window) **<** [Viewport](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport) **<** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

**Inherited By:** [ConfirmationDialog](https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html#class-confirmationdialog)

A base dialog used for user notification.

## Description[](#description "Link to this heading")

The default use of **AcceptDialog** is to allow it to only be accepted or closed, with the same result. However, the [confirmed](#class-acceptdialog-signal-confirmed) and [canceled](#class-acceptdialog-signal-canceled) signals allow to make the two actions different, and the [add\_button()](#class-acceptdialog-method-add-button) method allows to add custom buttons and actions.

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

## Theme Properties[](#theme-properties "Link to this heading")

---

## Signals[](#signals "Link to this heading")

**canceled**() [🔗](#class-acceptdialog-signal-canceled)

Emitted when the dialog is closed or the button created with [add\_cancel\_button()](#class-acceptdialog-method-add-cancel-button) is pressed.

---

**confirmed**() [🔗](#class-acceptdialog-signal-confirmed)

Emitted when the dialog is accepted, i.e. the OK button is pressed.

---

**custom\_action**(action: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-acceptdialog-signal-custom-action)

Emitted when a custom button with an action is pressed. See [add\_button()](#class-acceptdialog-method-add-button).

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **dialog\_autowrap** = `false` [🔗](#class-acceptdialog-property-dialog-autowrap)

*   void **set\_autowrap**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **has\_autowrap**()
    

Sets autowrapping for the text in the dialog.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **dialog\_close\_on\_escape** = `true` [🔗](#class-acceptdialog-property-dialog-close-on-escape)

*   void **set\_close\_on\_escape**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_close\_on\_escape**()
    

If `true`, the dialog will be hidden when the `ui_cancel` action is pressed (by default, this action is bound to [@GlobalScope.KEY\_ESCAPE](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-key-escape)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **dialog\_hide\_on\_ok** = `true` [🔗](#class-acceptdialog-property-dialog-hide-on-ok)

*   void **set\_hide\_on\_ok**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_hide\_on\_ok**()
    

If `true`, the dialog is hidden when the OK button is pressed. You can set it to `false` if you want to do e.g. input validation when receiving the [confirmed](#class-acceptdialog-signal-confirmed) signal, and handle hiding the dialog in your own logic.

**Note:** Some nodes derived from this class can have a different default value, and potentially their own built-in logic overriding this setting. For example [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html#class-filedialog) defaults to `false`, and has its own input validation code that is called when you press OK, which eventually hides the dialog if the input is valid. As such, this property can't be used in [FileDialog](https://docs.godotengine.org/en/stable/classes/class_filedialog.html#class-filedialog) to disable hiding the dialog when pressing OK.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **dialog\_text** = `""` [🔗](#class-acceptdialog-property-dialog-text)

*   void **set\_text**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_text**()
    

The text displayed by the dialog.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **ok\_button\_text** = `""` [🔗](#class-acceptdialog-property-ok-button-text)

*   void **set\_ok\_button\_text**(value: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))
    
*   [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_ok\_button\_text**()
    

The text displayed by the OK button (see [get\_ok\_button()](#class-acceptdialog-method-get-ok-button)). If empty, a default text will be used.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) **add\_button**(text: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), right: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, action: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "") [🔗](#class-acceptdialog-method-add-button)

Adds a button with label `text` and a custom `action` to the dialog and returns the created button.

If `action` is not empty, pressing the button will emit the [custom\_action](#class-acceptdialog-signal-custom-action) signal with the specified action string.

If `true`, `right` will place the button to the right of any sibling buttons.

You can use [remove\_button()](#class-acceptdialog-method-remove-button) method to remove a button created with this method from the dialog.

---

[Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) **add\_cancel\_button**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-acceptdialog-method-add-cancel-button)

Adds a button with label `name` and a cancel action to the dialog and returns the created button.

You can use [remove\_button()](#class-acceptdialog-method-remove-button) method to remove a button created with this method from the dialog.

---

[Label](https://docs.godotengine.org/en/stable/classes/class_label.html#class-label) **get\_label**() [🔗](#class-acceptdialog-method-get-label)

Returns the label used for built-in text.

**Warning:** This is a required internal node, removing and freeing it may cause a crash. If you wish to hide it or any of its children, use their [CanvasItem.visible](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-visible) property.

---

[Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) **get\_ok\_button**() [🔗](#class-acceptdialog-method-get-ok-button)

Returns the OK [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) instance.

**Warning:** This is a required internal node, removing and freeing it may cause a crash. If you wish to hide it or any of its children, use their [CanvasItem.visible](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-property-visible) property.

---

void **register\_text\_enter**(line\_edit: [LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit)) [🔗](#class-acceptdialog-method-register-text-enter)

Registers a [LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit) in the dialog. When the enter key is pressed, the dialog will be accepted.

---

void **remove\_button**(button: [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button)) [🔗](#class-acceptdialog-method-remove-button)

Removes the `button` from the dialog. Does NOT free the `button`. The `button` must be a [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) added with [add\_button()](#class-acceptdialog-method-add-button) or [add\_cancel\_button()](#class-acceptdialog-method-add-cancel-button) method. After removal, pressing the `button` will no longer emit this dialog's [custom\_action](#class-acceptdialog-signal-custom-action) or [canceled](#class-acceptdialog-signal-canceled) signals.

---

## Theme Property Descriptions[](#theme-property-descriptions "Link to this heading")

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **buttons\_min\_height** = `0` [🔗](#class-acceptdialog-theme-constant-buttons-min-height)

The minimum height of each button in the bottom row (such as OK/Cancel) in pixels. This can be increased to make buttons with short texts easier to click/tap.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **buttons\_min\_width** = `0` [🔗](#class-acceptdialog-theme-constant-buttons-min-width)

The minimum width of each button in the bottom row (such as OK/Cancel) in pixels. This can be increased to make buttons with short texts easier to click/tap.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **buttons\_separation** = `10` [🔗](#class-acceptdialog-theme-constant-buttons-separation)

The size of the vertical space between the dialog's content and the button row.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **panel** [🔗](#class-acceptdialog-theme-style-panel)

The panel that fills the background of the window.