# EditorInspector

**Inherits:** [ScrollContainer](https://docs.godotengine.org/en/stable/classes/class_scrollcontainer.html#class-scrollcontainer) **<** [Container](https://docs.godotengine.org/en/stable/classes/class_container.html#class-container) **<** [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) **<** [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem) **<** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A control used to edit properties of an object.

## Description[](#description "Link to this heading")

This is the control that implements property editing in the editor's Settings dialogs, the Inspector dock, etc. To get the **EditorInspector** used in the editor's Inspector dock, use [EditorInterface.get\_inspector()](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html#class-editorinterface-method-get-inspector).

**EditorInspector** will show properties in the same order as the array returned by [Object.get\_property\_list()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-get-property-list).

If a property's name is path-like (i.e. if it contains forward slashes), **EditorInspector** will create nested sections for "directories" along the path. For example, if a property is named `highlighting/gdscript/node_path_color`, it will be shown as "Node Path Color" inside the "GDScript" section nested inside the "Highlighting" section.

If a property has [@GlobalScope.PROPERTY\_USAGE\_GROUP](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-property-usage-group) usage, it will group subsequent properties whose name starts with the property's hint string. The group ends when a property does not start with that hint string or when a new group starts. An empty group name effectively ends the current group. **EditorInspector** will create a top-level section for each group. For example, if a property with group usage is named `Collide With` and its hint string is `collide_with_`, a subsequent `collide_with_area` property will be shown as "Area" inside the "Collide With" section. There is also a special case: when the hint string contains the name of a property, that property is grouped too. This is mainly to help grouping properties like `font`, `font_color` and `font_size` (using the hint string `font_`).

If a property has [@GlobalScope.PROPERTY\_USAGE\_SUBGROUP](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-property-usage-subgroup) usage, a subgroup will be created in the same way as a group, and a second-level section will be created for each subgroup.

**Note:** Unlike sections created from path-like property names, **EditorInspector** won't capitalize the name for sections created from groups. So properties with group usage usually use capitalized names instead of snake\_cased names.

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

---

## Signals[](#signals "Link to this heading")

**edited\_object\_changed**() [🔗](#class-editorinspector-signal-edited-object-changed)

Emitted when the object being edited by the inspector has changed.

---

**object\_id\_selected**(id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-editorinspector-signal-object-id-selected)

Emitted when the Edit button of an [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object) has been pressed in the inspector. This is mainly used in the remote scene tree Inspector.

---

**property\_deleted**(property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinspector-signal-property-deleted)

Emitted when a property is removed from the inspector.

---

**property\_edited**(property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinspector-signal-property-edited)

Emitted when a property is edited in the inspector.

---

**property\_keyed**(property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant), advance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-editorinspector-signal-property-keyed)

Emitted when a property is keyed in the inspector. Properties can be keyed by clicking the "key" icon next to a property when the Animation panel is toggled.

---

**property\_selected**(property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinspector-signal-property-selected)

Emitted when a property is selected in the inspector.

---

**property\_toggled**(property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), checked: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-editorinspector-signal-property-toggled)

Emitted when a boolean property is toggled in the inspector.

**Note:** This signal is never emitted if the internal `autoclear` property enabled. Since this property is always enabled in the editor inspector, this signal is never emitted by the editor itself.

---

**resource\_selected**(resource: [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource), path: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinspector-signal-resource-selected)

Emitted when a resource is selected in the inspector.

---

**restart\_requested**() [🔗](#class-editorinspector-signal-restart-requested)

Emitted when a property that requires a restart to be applied is edited in the inspector. This is only used in the Project Settings and Editor Settings.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

void **edit**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)) [🔗](#class-editorinspector-method-edit)

Shows the properties of the given `object` in this inspector for editing. To clear the inspector, call this method with `null`.

**Note:** If you want to edit an object in the editor's main inspector, use the `edit_*` methods in [EditorInterface](https://docs.godotengine.org/en/stable/classes/class_editorinterface.html#class-editorinterface) instead.

---

[Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object) **get\_edited\_object**() [🔗](#class-editorinspector-method-get-edited-object)

Returns the object currently selected in this inspector.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_selected\_path**() const [🔗](#class-editorinspector-method-get-selected-path)

Gets the path of the currently selected property.

---

[EditorProperty](https://docs.godotengine.org/en/stable/classes/class_editorproperty.html#class-editorproperty) **instantiate\_property\_editor**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), type: [Variant.Type](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type), path: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), hint: [PropertyHint](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-propertyhint), hint\_text: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), usage: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), wide: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) static [🔗](#class-editorinspector-method-instantiate-property-editor)

Creates a property editor that can be used by plugin UI to edit the specified property of an `object`.