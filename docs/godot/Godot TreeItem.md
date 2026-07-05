# TreeItem

## Enumerations[](#enumerations "Link to this heading")

enum **TreeCellMode**: [🔗](#enum-treeitem-treecellmode)

[TreeCellMode](#enum-treeitem-treecellmode) **CELL\_MODE\_STRING** = `0`

Cell shows a string label, optionally with an icon. When editable, the text can be edited using a [LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit), or a [TextEdit](https://docs.godotengine.org/en/stable/classes/class_textedit.html#class-textedit) popup if [set\_edit\_multiline()](#class-treeitem-method-set-edit-multiline) is used.

[TreeCellMode](#enum-treeitem-treecellmode) **CELL\_MODE\_CHECK** = `1`

Cell shows a checkbox, optionally with text and an icon. The checkbox can be pressed, released, or indeterminate (via [set\_indeterminate()](#class-treeitem-method-set-indeterminate)). The checkbox can't be clicked unless the cell is editable.

[TreeCellMode](#enum-treeitem-treecellmode) **CELL\_MODE\_RANGE** = `2`

Cell shows a numeric range. When editable, it can be edited using a range slider. Use [set\_range()](#class-treeitem-method-set-range) to set the value and [set\_range\_config()](#class-treeitem-method-set-range-config) to configure the range.

This cell can also be used in a text dropdown mode when you assign a text with [set\_text()](#class-treeitem-method-set-text). Separate options with a comma, e.g. `"Option1,Option2,Option3"`.

[TreeCellMode](#enum-treeitem-treecellmode) **CELL\_MODE\_ICON** = `3`

Cell shows an icon. It can't be edited nor display text. The icon is always centered within the cell.

[TreeCellMode](#enum-treeitem-treecellmode) **CELL\_MODE\_CUSTOM** = `4`

Cell shows as a clickable button. It will display an arrow similar to [OptionButton](https://docs.godotengine.org/en/stable/classes/class_optionbutton.html#class-optionbutton), but doesn't feature a dropdown (for that you can use [CELL\_MODE\_RANGE](#class-treeitem-constant-cell-mode-range)). Clicking the button emits the [Tree.item\_edited](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree-signal-item-edited) signal. The button is flat by default, you can use [set\_custom\_as\_button()](#class-treeitem-method-set-custom-as-button) to display it with a [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox).

This mode also supports custom drawing using [set\_custom\_draw\_callback()](#class-treeitem-method-set-custom-draw-callback).

## Property Descriptions[](#property-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **collapsed** [🔗](#class-treeitem-property-collapsed)

*   void **set\_collapsed**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_collapsed**()
    

If `true`, the TreeItem is collapsed.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **custom\_minimum\_height** [🔗](#class-treeitem-property-custom-minimum-height)

*   void **set\_custom\_minimum\_height**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_custom\_minimum\_height**()
    

The custom minimum height.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **disable\_folding** [🔗](#class-treeitem-property-disable-folding)

*   void **set\_disable\_folding**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_folding\_disabled**()
    

If `true`, folding is disabled for this TreeItem.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **visible** [🔗](#class-treeitem-property-visible)

*   void **set\_visible**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_visible**()
    

If `true`, the **TreeItem** is visible (default).

Note that if a **TreeItem** is set to not be visible, none of its children will be visible either.

## Method Descriptions[](#method-descriptions "Link to this heading")

void **add\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d), id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1, disabled: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, tooltip\_text: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "", description: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "") [🔗](#class-treeitem-method-add-button)

Adds a button with [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) `button` to the end of the cell at column `column`. The `id` is used to identify the button in the according [Tree.button\_clicked](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree-signal-button-clicked) signal and can be different from the buttons index. If not specified, the next available index is used, which may be retrieved by calling [get\_button\_count()](#class-treeitem-method-get-button-count) immediately before this method. Optionally, the button can be `disabled` and have a `tooltip_text`. `description` is used as the button description for assistive apps.

---

void **add\_child**(child: [TreeItem](#class-treeitem)) [🔗](#class-treeitem-method-add-child)

Adds a previously unparented **TreeItem** as a direct child of this one. The `child` item must not be a part of any [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree) or parented to any **TreeItem**. See also [remove\_child()](#class-treeitem-method-remove-child).

---

void **call\_recursive**(method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-treeitem-method-call-recursive)

Calls the `method` on the actual TreeItem and its children recursively. Pass parameters as a comma separated list.

---

void **clear\_buttons**() [🔗](#class-treeitem-method-clear-buttons)

Removes all buttons from all columns of this item.

---

void **clear\_custom\_bg\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-clear-custom-bg-color)

Resets the background color for the given column to default.

---

void **clear\_custom\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-clear-custom-color)

Resets the color for the given column to default.

---

[TreeItem](#class-treeitem) **create\_child**(index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1) [🔗](#class-treeitem-method-create-child)

Creates an item and adds it as a child.

The new item will be inserted as position `index` (the default value `-1` means the last position), or it will be the last child if `index` is higher than the child count.

---

void **deselect**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-deselect)

Deselects the given column.

---

void **erase\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-erase-button)

Removes the button at index `button_index` in column `column`.

---

[AutoTranslateMode](https://docs.godotengine.org/en/stable/classes/class_node.html#enum-node-autotranslatemode) **get\_auto\_translate\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-auto-translate-mode)

Returns the column's auto translate mode.

---

[AutowrapMode](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-autowrapmode) **get\_autowrap\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-autowrap-mode)

Returns the text autowrap mode in the given `column`. By default it is [TextServer.AUTOWRAP\_OFF](https://docs.godotengine.org/en/stable/classes/class_textserver.html#class-textserver-constant-autowrap-off).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **get\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button)

Returns the [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) of the button at index `button_index` in column `column`.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_button\_by\_id**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button-by-id)

Returns the button index if there is a button with ID `id` in column `column`, otherwise returns -1.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **get\_button\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button-color)

Returns the color of the button with ID `id` in column `column`. If the specified button does not exist, returns [Color.BLACK](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color-constant-black).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_button\_count**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button-count)

Returns the number of buttons in column `column`.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_button\_id**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button-id)

Returns the ID for the button at index `button_index` in column `column`.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_button\_tooltip\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-button-tooltip-text)

Returns the tooltip text for the button at index `button_index` in column `column`.

---

[TreeCellMode](#enum-treeitem-treecellmode) **get\_cell\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-cell-mode)

Returns the column's cell mode.

---

[TreeItem](#class-treeitem) **get\_child**(index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-get-child)

Returns a child item by its `index` (see [get\_child\_count()](#class-treeitem-method-get-child-count)). This method is often used for iterating all children of an item.

Negative indices access the children from the last one.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_child\_count**() [🔗](#class-treeitem-method-get-child-count)

Returns the number of child items.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[TreeItem](#class-treeitem)\] **get\_children**() [🔗](#class-treeitem-method-get-children)

Returns an array of references to the item's children.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **get\_custom\_bg\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-custom-bg-color)

Returns the custom background color of column `column`.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **get\_custom\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-custom-color)

Returns the custom color of column `column`.

---

[Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable) **get\_custom\_draw\_callback**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-custom-draw-callback)

Returns the custom callback of column `column`.

---

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font) **get\_custom\_font**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-custom-font)

Returns custom font used to draw text in the column `column`.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_custom\_font\_size**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-custom-font-size)

Returns custom font size used to draw text in the column `column`.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_description**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-description)

Returns the given column's description for assistive apps.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_expand\_right**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-expand-right)

Returns `true` if `expand_right` is set.

---

[TreeItem](#class-treeitem) **get\_first\_child**() const [🔗](#class-treeitem-method-get-first-child)

Returns the TreeItem's first child.

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **get\_icon**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-icon)

Returns the given column's icon [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d). Error if no icon is set.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_icon\_max\_width**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-icon-max-width)

Returns the maximum allowed width of the icon in the given `column`.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **get\_icon\_modulate**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-icon-modulate)

Returns the [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) modulating the column's icon.

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **get\_icon\_overlay**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-icon-overlay)

Returns the given column's icon overlay [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d).

---

[Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2) **get\_icon\_region**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-icon-region)

Returns the icon [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) region as [Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_index**() [🔗](#class-treeitem-method-get-index)

Returns the node's order in the tree. For example, if called on the first child item the position is `0`.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_language**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-language)

Returns item's text language code.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **get\_metadata**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-metadata)

Returns the metadata value that was set for the given column using [set\_metadata()](#class-treeitem-method-set-metadata).

---

[TreeItem](#class-treeitem) **get\_next**() const [🔗](#class-treeitem-method-get-next)

Returns the next sibling TreeItem in the tree or a `null` object if there is none.

---

[TreeItem](#class-treeitem) **get\_next\_in\_tree**(wrap: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-get-next-in-tree)

Returns the next TreeItem in the tree (in the context of a depth-first search) or a `null` object if there is none.

If `wrap` is enabled, the method will wrap around to the first element in the tree when called on the last element, otherwise it returns `null`.

---

[TreeItem](#class-treeitem) **get\_next\_visible**(wrap: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-get-next-visible)

Returns the next visible TreeItem in the tree (in the context of a depth-first search) or a `null` object if there is none.

If `wrap` is enabled, the method will wrap around to the first visible element in the tree when called on the last visible element, otherwise it returns `null`.

---

[TreeItem](#class-treeitem) **get\_parent**() const [🔗](#class-treeitem-method-get-parent)

Returns the parent TreeItem or a `null` object if there is none.

---

[TreeItem](#class-treeitem) **get\_prev**() [🔗](#class-treeitem-method-get-prev)

Returns the previous sibling TreeItem in the tree or a `null` object if there is none.

---

[TreeItem](#class-treeitem) **get\_prev\_in\_tree**(wrap: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-get-prev-in-tree)

Returns the previous TreeItem in the tree (in the context of a depth-first search) or a `null` object if there is none.

If `wrap` is enabled, the method will wrap around to the last element in the tree when called on the first visible element, otherwise it returns `null`.

---

[TreeItem](#class-treeitem) **get\_prev\_visible**(wrap: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-get-prev-visible)

Returns the previous visible sibling TreeItem in the tree (in the context of a depth-first search) or a `null` object if there is none.

If `wrap` is enabled, the method will wrap around to the last visible element in the tree when called on the first visible element, otherwise it returns `null`.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_range**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-range)

Returns the value of a [CELL\_MODE\_RANGE](#class-treeitem-constant-cell-mode-range) column.

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_range\_config**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-get-range-config)

Returns a dictionary containing the range parameters for a given column. The keys are "min", "max", "step", and "expr".

---

[StructuredTextParser](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-structuredtextparser) **get\_structured\_text\_bidi\_override**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-structured-text-bidi-override)

Returns the BiDi algorithm override set for this cell.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) **get\_structured\_text\_bidi\_override\_options**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-structured-text-bidi-override-options)

Returns the additional BiDi options set for this cell.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_suffix**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-suffix)

Gets the suffix string shown after the column value.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-text)

Returns the given column's text.

---

[HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment) **get\_text\_alignment**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-text-alignment)

Returns the given column's text alignment.

---

[TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection) **get\_text\_direction**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-text-direction)

Returns item's text base writing direction.

---

[OverrunBehavior](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-overrunbehavior) **get\_text\_overrun\_behavior**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-text-overrun-behavior)

Returns the clipping behavior when the text exceeds the item's bounding rectangle in the given `column`. By default it is [TextServer.OVERRUN\_TRIM\_ELLIPSIS](https://docs.godotengine.org/en/stable/classes/class_textserver.html#class-textserver-constant-overrun-trim-ellipsis).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_tooltip\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-get-tooltip-text)

Returns the given column's tooltip text.

---

[Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree) **get\_tree**() const [🔗](#class-treeitem-method-get-tree)

Returns the [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree) that owns this TreeItem.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_any\_collapsed**(only\_visible: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-is-any-collapsed)

Returns `true` if this **TreeItem**, or any of its descendants, is collapsed.

If `only_visible` is `true` it ignores non-visible **TreeItem**s.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_button\_disabled**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-button-disabled)

Returns `true` if the button at index `button_index` for the given `column` is disabled.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_checked**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-checked)

Returns `true` if the given `column` is checked.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_custom\_set\_as\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-custom-set-as-button)

Returns `true` if the cell was made into a button with [set\_custom\_as\_button()](#class-treeitem-method-set-custom-as-button).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_edit\_multiline**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-edit-multiline)

Returns `true` if the given `column` is multiline editable.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_editable**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-is-editable)

Returns `true` if the given `column` is editable.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_indeterminate**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-indeterminate)

Returns `true` if the given `column` is indeterminate.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_selectable**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-treeitem-method-is-selectable)

Returns `true` if the given `column` is selectable.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_selected**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-is-selected)

Returns `true` if the given `column` is selected.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_visible\_in\_tree**() const [🔗](#class-treeitem-method-is-visible-in-tree)

Returns `true` if [visible](#class-treeitem-property-visible) is `true` and all its ancestors are also visible.

---

void **move\_after**(item: [TreeItem](#class-treeitem)) [🔗](#class-treeitem-method-move-after)

Moves this TreeItem right after the given `item`.

**Note:** You can't move to the root or move the root.

---

void **move\_before**(item: [TreeItem](#class-treeitem)) [🔗](#class-treeitem-method-move-before)

Moves this TreeItem right before the given `item`.

**Note:** You can't move to the root or move the root.

---

void **propagate\_check**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), emit\_signal: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-treeitem-method-propagate-check)

Propagates this item's checked status to its children and parents for the given `column`. It is possible to process the items affected by this method call by connecting to [Tree.check\_propagated\_to\_item](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree-signal-check-propagated-to-item). The order that the items affected will be processed is as follows: the item invoking this method, children of that item, and finally parents of that item. If `emit_signal` is `false`, then [Tree.check\_propagated\_to\_item](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree-signal-check-propagated-to-item) will not be emitted.

---

void **remove\_child**(child: [TreeItem](#class-treeitem)) [🔗](#class-treeitem-method-remove-child)

Removes the given child **TreeItem** and all its children from the [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree). Note that it doesn't free the item from memory, so it can be reused later (see [add\_child()](#class-treeitem-method-add-child)). To completely remove a **TreeItem** use [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free).

**Note:** If you want to move a child from one [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree) to another, then instead of removing and adding it manually you can use [move\_before()](#class-treeitem-method-move-before) or [move\_after()](#class-treeitem-method-move-after).

---

void **select**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-select)

Selects the given `column`.

---

void **set\_auto\_translate\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), mode: [AutoTranslateMode](https://docs.godotengine.org/en/stable/classes/class_node.html#enum-node-autotranslatemode)) [🔗](#class-treeitem-method-set-auto-translate-mode)

Sets the given column's auto translate mode to `mode`.

All columns use [Node.AUTO\_TRANSLATE\_MODE\_INHERIT](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node-constant-auto-translate-mode-inherit) by default, which uses the same auto translate mode as the [Tree](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree) itself.

---

void **set\_autowrap\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), autowrap\_mode: [AutowrapMode](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-autowrapmode)) [🔗](#class-treeitem-method-set-autowrap-mode)

Sets the autowrap mode in the given `column`. If set to something other than [TextServer.AUTOWRAP\_OFF](https://docs.godotengine.org/en/stable/classes/class_textserver.html#class-textserver-constant-autowrap-off), the text gets wrapped inside the cell's bounding rectangle.

---

void **set\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)) [🔗](#class-treeitem-method-set-button)

Sets the given column's button [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) at index `button_index` to `button`.

---

void **set\_button\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), color: [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)) [🔗](#class-treeitem-method-set-button-color)

Sets the given column's button color at index `button_index` to `color`.

---

void **set\_button\_description**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), description: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-button-description)

Sets the given column's button description at index `button_index` for assistive apps.

---

void **set\_button\_disabled**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), disabled: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-button-disabled)

If `true`, disables the button at index `button_index` in the given `column`.

---

void **set\_button\_tooltip\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), tooltip: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-button-tooltip-text)

Sets the tooltip text for the button at index `button_index` in the given `column`.

---

void **set\_cell\_mode**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), mode: [TreeCellMode](#enum-treeitem-treecellmode)) [🔗](#class-treeitem-method-set-cell-mode)

Sets the given column's cell mode to `mode`. This determines how the cell is displayed and edited.

---

void **set\_checked**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), checked: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-checked)

If `checked` is `true`, the given `column` is checked. Clears column's indeterminate status.

---

void **set\_collapsed\_recursive**(enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-collapsed-recursive)

Collapses or uncollapses this **TreeItem** and all the descendants of this item.

---

void **set\_custom\_as\_button**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-custom-as-button)

Makes a cell with [CELL\_MODE\_CUSTOM](#class-treeitem-constant-cell-mode-custom) display as a non-flat button with a [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox).

---

void **set\_custom\_bg\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), color: [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color), just\_outline: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-set-custom-bg-color)

Sets the given column's custom background color and whether to just use it as an outline.

---

void **set\_custom\_color**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), color: [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)) [🔗](#class-treeitem-method-set-custom-color)

Sets the given column's custom color.

---

void **set\_custom\_draw**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), callback: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-treeitem-method-set-custom-draw)

**Deprecated:** Use [set\_custom\_draw\_callback()](#class-treeitem-method-set-custom-draw-callback) instead.

Sets the given column's custom draw callback to the `callback` method on `object`.

The method named `callback` should accept two arguments: the **TreeItem** that is drawn and its position and size as a [Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2).

---

void **set\_custom\_draw\_callback**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), callback: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable)) [🔗](#class-treeitem-method-set-custom-draw-callback)

Sets the given column's custom draw callback. Use an empty [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable) (`Callable()`) to clear the custom callback. The cell has to be in [CELL\_MODE\_CUSTOM](#class-treeitem-constant-cell-mode-custom) to use this feature.

The `callback` should accept two arguments: the **TreeItem** that is drawn and its position and size as a [Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2).

---

void **set\_custom\_font**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), font: [Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font)) [🔗](#class-treeitem-method-set-custom-font)

Sets custom font used to draw text in the given `column`.

---

void **set\_custom\_font\_size**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), font\_size: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-set-custom-font-size)

Sets custom font size used to draw text in the given `column`.

---

void **set\_description**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), description: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-description)

Sets the given column's description for assistive apps.

---

void **set\_edit\_multiline**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), multiline: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-edit-multiline)

If `multiline` is `true`, the given `column` is multiline editable.

**Note:** This option only affects the type of control ([LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit) or [TextEdit](https://docs.godotengine.org/en/stable/classes/class_textedit.html#class-textedit)) that appears when editing the column. You can set multiline values with [set\_text()](#class-treeitem-method-set-text) even if the column is not multiline editable.

---

void **set\_editable**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), enabled: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-editable)

If `enabled` is `true`, the given `column` is editable.

---

void **set\_expand\_right**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-expand-right)

If `enable` is `true`, the given `column` is expanded to the right.

---

void **set\_icon**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), texture: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)) [🔗](#class-treeitem-method-set-icon)

Sets the given cell's icon [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d). If the cell is in [CELL\_MODE\_ICON](#class-treeitem-constant-cell-mode-icon) mode, the icon is displayed in the center of the cell. Otherwise, the icon is displayed before the cell's text. [CELL\_MODE\_RANGE](#class-treeitem-constant-cell-mode-range) does not display an icon.

---

void **set\_icon\_max\_width**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), width: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-treeitem-method-set-icon-max-width)

Sets the maximum allowed width of the icon in the given `column`. This limit is applied on top of the default size of the icon and on top of [Tree.icon\_max\_width](https://docs.godotengine.org/en/stable/classes/class_tree.html#class-tree-theme-constant-icon-max-width). The height is adjusted according to the icon's ratio.

---

void **set\_icon\_modulate**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), modulate: [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)) [🔗](#class-treeitem-method-set-icon-modulate)

Modulates the given column's icon with `modulate`.

---

void **set\_icon\_overlay**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), texture: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)) [🔗](#class-treeitem-method-set-icon-overlay)

Sets the given cell's icon overlay [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d). The cell has to be in [CELL\_MODE\_ICON](#class-treeitem-constant-cell-mode-icon) mode, and icon has to be set. Overlay is drawn on top of icon, in the bottom left corner.

---

void **set\_icon\_region**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), region: [Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2)) [🔗](#class-treeitem-method-set-icon-region)

Sets the given column's icon's texture region.

---

void **set\_indeterminate**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), indeterminate: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-indeterminate)

If `indeterminate` is `true`, the given `column` is marked indeterminate.

**Note:** If set `true` from `false`, then column is cleared of checked status.

---

void **set\_language**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), language: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-language)

Sets language code of item's text used for line-breaking and text shaping algorithms, if left empty current locale is used instead.

---

void **set\_metadata**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), meta: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) [🔗](#class-treeitem-method-set-metadata)

Sets the metadata value for the given column, which can be retrieved later using [get\_metadata()](#class-treeitem-method-get-metadata). This can be used, for example, to store a reference to the original data.

---

void **set\_range**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), value: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float)) [🔗](#class-treeitem-method-set-range)

Sets the value of a [CELL\_MODE\_RANGE](#class-treeitem-constant-cell-mode-range) column.

---

void **set\_range\_config**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), min: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), max: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), step: [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float), expr: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-treeitem-method-set-range-config)

Sets the range of accepted values for a column. The column must be in the [CELL\_MODE\_RANGE](#class-treeitem-constant-cell-mode-range) mode.

If `expr` is `true`, the edit mode slider will use an exponential scale as with [Range.exp\_edit](https://docs.godotengine.org/en/stable/classes/class_range.html#class-range-property-exp-edit).

---

void **set\_selectable**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), selectable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-treeitem-method-set-selectable)

If `selectable` is `true`, the given `column` is selectable.

---

void **set\_structured\_text\_bidi\_override**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), parser: [StructuredTextParser](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-structuredtextparser)) [🔗](#class-treeitem-method-set-structured-text-bidi-override)

Set BiDi algorithm override for the structured text. Has effect for cells that display text.

---

void **set\_structured\_text\_bidi\_override\_options**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), args: [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)) [🔗](#class-treeitem-method-set-structured-text-bidi-override-options)

Set additional options for BiDi override. Has effect for cells that display text.

---

void **set\_suffix**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), text: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-suffix)

Sets a string to be shown after a column's value (for example, a unit abbreviation).

---

void **set\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), text: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-text)

Sets the given column's text value.

---

void **set\_text\_alignment**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), text\_alignment: [HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment)) [🔗](#class-treeitem-method-set-text-alignment)

Sets the given column's text alignment to `text_alignment`.

---

void **set\_text\_direction**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), direction: [TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection)) [🔗](#class-treeitem-method-set-text-direction)

Sets item's text base writing direction.

---

void **set\_text\_overrun\_behavior**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), overrun\_behavior: [OverrunBehavior](https://docs.godotengine.org/en/stable/classes/class_textserver.html#enum-textserver-overrunbehavior)) [🔗](#class-treeitem-method-set-text-overrun-behavior)

Sets the clipping behavior when the text exceeds the item's bounding rectangle in the given `column`.

---

void **set\_tooltip\_text**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), tooltip: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-treeitem-method-set-tooltip-text)

Sets the given column's tooltip text.

---

void **uncollapse\_tree**() [🔗](#class-treeitem-method-uncollapse-tree)

Uncollapses all **TreeItem**s necessary to reveal this **TreeItem**, i.e. all ancestor **TreeItem**s.