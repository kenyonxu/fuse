# Tree

**Inherits:** [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) **<** [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem) **<** [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A control used to show a set of internal [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)s in a hierarchical structure.

## Description[](#description "Link to this heading")

A control used to show a set of internal [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)s in a hierarchical structure. The tree items can be selected, expanded and collapsed. The tree can have multiple columns with custom controls like [LineEdit](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit)s, buttons and popups. It can be useful for structured displays and interactions.

Trees are built via code, using [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) objects to create the structure. They have a single root, but multiple roots can be simulated with [hide\_root](#class-tree-property-hide-root):

func \_ready():
	var tree \= Tree.new()
	var root \= tree.create\_item()
	tree.hide\_root \= true
	var child1 \= tree.create\_item(root)
	var child2 \= tree.create\_item(root)
	var subchild1 \= tree.create\_item(child1)
	subchild1.set\_text(0, "Subchild1")

To iterate over all the [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) objects in a **Tree** object, use [TreeItem.get\_next()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-get-next) and [TreeItem.get\_first\_child()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-get-first-child) after getting the root through [get\_root()](#class-tree-method-get-root). You can use [Object.free()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free) on a [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) to remove it from the **Tree**.

**Incremental search:** Like [ItemList](https://docs.godotengine.org/en/stable/classes/class_itemlist.html#class-itemlist) and [PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html#class-popupmenu), **Tree** supports searching within the list while the control is focused. Press a key that matches the first letter of an item's name to select the first item starting with the given letter. After that point, there are two ways to perform incremental search: 1) Press the same key again before the timeout duration to select the next item starting with the same letter. 2) Press letter keys that match the rest of the word before the timeout duration to match to select the item in question directly. Both of these actions will be reset to the beginning of the list if the timeout duration has passed since the last keystroke was registered. You can adjust the timeout duration by changing [ProjectSettings.gui/timers/incremental\_search\_max\_interval\_msec](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-gui-timers-incremental-search-max-interval-msec).

## Properties[](#properties "Link to this heading")

## Methods[](#methods "Link to this heading")

void

[clear](#class-tree-method-clear)()

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[create\_item](#class-tree-method-create-item)(parent: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) = null, index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1)

void

[deselect\_all](#class-tree-method-deselect-all)()

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[edit\_selected](#class-tree-method-edit-selected)(force\_edit: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[ensure\_cursor\_is\_visible](#class-tree-method-ensure-cursor-is-visible)()

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_button\_id\_at\_position](#class-tree-method-get-button-id-at-position)(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_column\_at\_position](#class-tree-method-get-column-at-position)(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_column\_expand\_ratio](#class-tree-method-get-column-expand-ratio)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[get\_column\_title](#class-tree-method-get-column-title)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment)

[get\_column\_title\_alignment](#class-tree-method-get-column-title-alignment)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection)

[get\_column\_title\_direction](#class-tree-method-get-column-title-direction)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)

[get\_column\_title\_language](#class-tree-method-get-column-title-language)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_column\_width](#class-tree-method-get-column-width)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2)

[get\_custom\_popup\_rect](#class-tree-method-get-custom-popup-rect)() const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_drop\_section\_at\_position](#class-tree-method-get-drop-section-at-position)(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[get\_edited](#class-tree-method-get-edited)() const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_edited\_column](#class-tree-method-get-edited-column)() const

[Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2)

[get\_item\_area\_rect](#class-tree-method-get-item-area-rect)(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1, button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1) const

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[get\_item\_at\_position](#class-tree-method-get-item-at-position)(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[get\_next\_selected](#class-tree-method-get-next-selected)(from: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem))

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_pressed\_button](#class-tree-method-get-pressed-button)() const

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[get\_root](#class-tree-method-get-root)() const

[Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)

[get\_scroll](#class-tree-method-get-scroll)() const

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)

[get\_selected](#class-tree-method-get-selected)() const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[get\_selected\_column](#class-tree-method-get-selected-column)() const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_column\_clipping\_content](#class-tree-method-is-column-clipping-content)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_column\_expanding](#class-tree-method-is-column-expanding)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const

void

[scroll\_to\_item](#class-tree-method-scroll-to-item)(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), center\_on\_item: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false)

void

[set\_column\_clip\_content](#class-tree-method-set-column-clip-content)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_column\_custom\_minimum\_width](#class-tree-method-set-column-custom-minimum-width)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), min\_width: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[set\_column\_expand](#class-tree-method-set-column-expand)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), expand: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))

void

[set\_column\_expand\_ratio](#class-tree-method-set-column-expand-ratio)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), ratio: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

void

[set\_column\_title](#class-tree-method-set-column-title)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), title: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))

void

[set\_column\_title\_alignment](#class-tree-method-set-column-title-alignment)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), title\_alignment: [HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment))

void

[set\_column\_title\_direction](#class-tree-method-set-column-title-direction)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), direction: [TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection))

void

[set\_column\_title\_language](#class-tree-method-set-column-title-language)(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), language: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string))

void

[set\_selected](#class-tree-method-set-selected)(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))

## Theme Properties[](#theme-properties "Link to this heading")

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[children\_hl\_line\_color](#class-tree-theme-color-children-hl-line-color)

`Color(0.27, 0.27, 0.27, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[custom\_button\_font\_highlight](#class-tree-theme-color-custom-button-font-highlight)

`Color(0.95, 0.95, 0.95, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[drop\_position\_color](#class-tree-theme-color-drop-position-color)

`Color(1, 1, 1, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_color](#class-tree-theme-color-font-color)

`Color(0.7, 0.7, 0.7, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_disabled\_color](#class-tree-theme-color-font-disabled-color)

`Color(0.875, 0.875, 0.875, 0.5)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_hovered\_color](#class-tree-theme-color-font-hovered-color)

`Color(0.95, 0.95, 0.95, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_hovered\_dimmed\_color](#class-tree-theme-color-font-hovered-dimmed-color)

`Color(0.875, 0.875, 0.875, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_hovered\_selected\_color](#class-tree-theme-color-font-hovered-selected-color)

`Color(1, 1, 1, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_outline\_color](#class-tree-theme-color-font-outline-color)

`Color(0, 0, 0, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[font\_selected\_color](#class-tree-theme-color-font-selected-color)

`Color(1, 1, 1, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[guide\_color](#class-tree-theme-color-guide-color)

`Color(0.7, 0.7, 0.7, 0.25)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[parent\_hl\_line\_color](#class-tree-theme-color-parent-hl-line-color)

`Color(0.27, 0.27, 0.27, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[relationship\_line\_color](#class-tree-theme-color-relationship-line-color)

`Color(0.27, 0.27, 0.27, 1)`

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color)

[title\_button\_color](#class-tree-theme-color-title-button-color)

`Color(0.875, 0.875, 0.875, 1)`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[button\_margin](#class-tree-theme-constant-button-margin)

`4`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[children\_hl\_line\_width](#class-tree-theme-constant-children-hl-line-width)

`1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[draw\_guides](#class-tree-theme-constant-draw-guides)

`1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[draw\_relationship\_lines](#class-tree-theme-constant-draw-relationship-lines)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[h\_separation](#class-tree-theme-constant-h-separation)

`4`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[icon\_max\_width](#class-tree-theme-constant-icon-max-width)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[inner\_item\_margin\_bottom](#class-tree-theme-constant-inner-item-margin-bottom)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[inner\_item\_margin\_left](#class-tree-theme-constant-inner-item-margin-left)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[inner\_item\_margin\_right](#class-tree-theme-constant-inner-item-margin-right)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[inner\_item\_margin\_top](#class-tree-theme-constant-inner-item-margin-top)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[item\_margin](#class-tree-theme-constant-item-margin)

`16`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[outline\_size](#class-tree-theme-constant-outline-size)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[parent\_hl\_line\_margin](#class-tree-theme-constant-parent-hl-line-margin)

`0`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[parent\_hl\_line\_width](#class-tree-theme-constant-parent-hl-line-width)

`1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[relationship\_line\_width](#class-tree-theme-constant-relationship-line-width)

`1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scroll\_border](#class-tree-theme-constant-scroll-border)

`4`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scroll\_speed](#class-tree-theme-constant-scroll-speed)

`12`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_h\_separation](#class-tree-theme-constant-scrollbar-h-separation)

`4`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_margin\_bottom](#class-tree-theme-constant-scrollbar-margin-bottom)

`-1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_margin\_left](#class-tree-theme-constant-scrollbar-margin-left)

`-1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_margin\_right](#class-tree-theme-constant-scrollbar-margin-right)

`-1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_margin\_top](#class-tree-theme-constant-scrollbar-margin-top)

`-1`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[scrollbar\_v\_separation](#class-tree-theme-constant-scrollbar-v-separation)

`4`

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[v\_separation](#class-tree-theme-constant-v-separation)

`4`

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font)

[font](#class-tree-theme-font-font)

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font)

[title\_button\_font](#class-tree-theme-font-title-button-font)

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[font\_size](#class-tree-theme-font-size-font-size)

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[title\_button\_font\_size](#class-tree-theme-font-size-title-button-font-size)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[arrow](#class-tree-theme-icon-arrow)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[arrow\_collapsed](#class-tree-theme-icon-arrow-collapsed)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[arrow\_collapsed\_mirrored](#class-tree-theme-icon-arrow-collapsed-mirrored)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[checked](#class-tree-theme-icon-checked)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[checked\_disabled](#class-tree-theme-icon-checked-disabled)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[indeterminate](#class-tree-theme-icon-indeterminate)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[indeterminate\_disabled](#class-tree-theme-icon-indeterminate-disabled)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[select\_arrow](#class-tree-theme-icon-select-arrow)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[unchecked](#class-tree-theme-icon-unchecked)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[unchecked\_disabled](#class-tree-theme-icon-unchecked-disabled)

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)

[updown](#class-tree-theme-icon-updown)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[button\_hover](#class-tree-theme-style-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[button\_pressed](#class-tree-theme-style-button-pressed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[cursor](#class-tree-theme-style-cursor)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[cursor\_unfocused](#class-tree-theme-style-cursor-unfocused)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[custom\_button](#class-tree-theme-style-custom-button)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[custom\_button\_hover](#class-tree-theme-style-custom-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[custom\_button\_pressed](#class-tree-theme-style-custom-button-pressed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[focus](#class-tree-theme-style-focus)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[hovered](#class-tree-theme-style-hovered)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[hovered\_dimmed](#class-tree-theme-style-hovered-dimmed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[hovered\_selected](#class-tree-theme-style-hovered-selected)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[hovered\_selected\_focus](#class-tree-theme-style-hovered-selected-focus)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[panel](#class-tree-theme-style-panel)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[selected](#class-tree-theme-style-selected)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[selected\_focus](#class-tree-theme-style-selected-focus)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[title\_button\_hover](#class-tree-theme-style-title-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[title\_button\_normal](#class-tree-theme-style-title-button-normal)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox)

[title\_button\_pressed](#class-tree-theme-style-title-button-pressed)

---

## Signals[](#signals "Link to this heading")

**button\_clicked**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), id: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), mouse\_button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-button-clicked)

Emitted when a button on the tree was pressed (see [TreeItem.add\_button()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-add-button)).

---

**cell\_selected**() [🔗](#class-tree-signal-cell-selected)

Emitted when a cell is selected.

---

**check\_propagated\_to\_item**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-check-propagated-to-item)

Emitted when [TreeItem.propagate\_check()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-propagate-check) is called. Connect to this signal to process the items that are affected when [TreeItem.propagate\_check()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-propagate-check) is invoked. The order that the items affected will be processed is as follows: the item that invoked the method, children of that item, and finally parents of that item.

---

**column\_title\_clicked**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), mouse\_button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-column-title-clicked)

Emitted when a column's title is clicked with either [@GlobalScope.MOUSE\_BUTTON\_LEFT](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-mouse-button-left) or [@GlobalScope.MOUSE\_BUTTON\_RIGHT](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-mouse-button-right).

---

**custom\_item\_clicked**(mouse\_button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-custom-item-clicked)

Emitted when an item with [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) is clicked with a mouse button.

---

Emitted when a cell with the [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) is clicked to be edited.

---

**empty\_clicked**(click\_position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2), mouse\_button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-empty-clicked)

Emitted when a mouse button is clicked in the empty space of the tree.

---

**item\_activated**() [🔗](#class-tree-signal-item-activated)

Emitted when an item is double-clicked, or selected with a `ui_accept` input event (e.g. using Enter or Space on the keyboard).

---

**item\_collapsed**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)) [🔗](#class-tree-signal-item-collapsed)

Emitted when an item is expanded or collapsed by clicking on the folding arrow or through code.

**Note:** Despite its name, this signal is also emitted when an item is expanded.

---

**item\_edited**() [🔗](#class-tree-signal-item-edited)

Emitted when an item is edited.

---

**item\_icon\_double\_clicked**() [🔗](#class-tree-signal-item-icon-double-clicked)

Emitted when an item's icon is double-clicked. For a signal that emits when any part of the item is double-clicked, see [item\_activated](#class-tree-signal-item-activated).

---

**item\_mouse\_selected**(mouse\_position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2), mouse\_button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-signal-item-mouse-selected)

Emitted when an item is selected with a mouse button.

---

**item\_selected**() [🔗](#class-tree-signal-item-selected)

Emitted when an item is selected.

---

**multi\_selected**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), selected: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-tree-signal-multi-selected)

Emitted instead of [item\_selected](#class-tree-signal-item-selected) if [select\_mode](#class-tree-property-select-mode) is set to [SELECT\_MULTI](#class-tree-constant-select-multi).

---

**nothing\_selected**() [🔗](#class-tree-signal-nothing-selected)

Emitted when a left mouse button click does not select any item.

---

## Enumerations[](#enumerations "Link to this heading")

enum **SelectMode**: [🔗](#enum-tree-selectmode)

[SelectMode](#enum-tree-selectmode) **SELECT\_SINGLE** = `0`

Allows selection of a single cell at a time. From the perspective of items, only a single item is allowed to be selected. And there is only one column selected in the selected item.

The focus cursor is always hidden in this mode, but it is positioned at the current selection, making the currently selected item the currently focused item.

[SelectMode](#enum-tree-selectmode) **SELECT\_ROW** = `1`

Allows selection of a single row at a time. From the perspective of items, only a single items is allowed to be selected. And all the columns are selected in the selected item.

The focus cursor is always hidden in this mode, but it is positioned at the first column of the current selection, making the currently selected item the currently focused item.

[SelectMode](#enum-tree-selectmode) **SELECT\_MULTI** = `2`

Allows selection of multiple cells at the same time. From the perspective of items, multiple items are allowed to be selected. And there can be multiple columns selected in each selected item.

The focus cursor is visible in this mode, the item or column under the cursor is not necessarily selected.

---

enum **DropModeFlags**: [🔗](#enum-tree-dropmodeflags)

[DropModeFlags](#enum-tree-dropmodeflags) **DROP\_MODE\_DISABLED** = `0`

Disables all drop sections, but still allows to detect the "on item" drop section by [get\_drop\_section\_at\_position()](#class-tree-method-get-drop-section-at-position).

**Note:** This is the default flag, it has no effect when combined with other flags.

[DropModeFlags](#enum-tree-dropmodeflags) **DROP\_MODE\_ON\_ITEM** = `1`

Enables the "on item" drop section. This drop section covers the entire item.

When combined with [DROP\_MODE\_INBETWEEN](#class-tree-constant-drop-mode-inbetween), this drop section halves the height and stays centered vertically.

[DropModeFlags](#enum-tree-dropmodeflags) **DROP\_MODE\_INBETWEEN** = `2`

Enables "above item" and "below item" drop sections. The "above item" drop section covers the top half of the item, and the "below item" drop section covers the bottom half.

When combined with [DROP\_MODE\_ON\_ITEM](#class-tree-constant-drop-mode-on-item), these drop sections halves the height and stays on top / bottom accordingly.

---

## Property Descriptions[](#property-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **allow\_reselect** = `false` [🔗](#class-tree-property-allow-reselect)

*   void **set\_allow\_reselect**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_allow\_reselect**()
    

If `true`, the currently selected cell may be selected again.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **allow\_rmb\_select** = `false` [🔗](#class-tree-property-allow-rmb-select)

*   void **set\_allow\_rmb\_select**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_allow\_rmb\_select**()
    

If `true`, a right mouse button click can select items.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **allow\_search** = `true` [🔗](#class-tree-property-allow-search)

*   void **set\_allow\_search**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **get\_allow\_search**()
    

If `true`, allows navigating the **Tree** with letter keys through incremental search.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **auto\_tooltip** = `true` [🔗](#class-tree-property-auto-tooltip)

*   void **set\_auto\_tooltip**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_auto\_tooltip\_enabled**()
    

If `true`, tree items with no tooltip assigned display their text as their tooltip. See also [TreeItem.get\_tooltip\_text()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-get-tooltip-text) and [TreeItem.get\_button\_tooltip\_text()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-get-button-tooltip-text).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **column\_titles\_visible** = `false` [🔗](#class-tree-property-column-titles-visible)

*   void **set\_column\_titles\_visible**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **are\_column\_titles\_visible**()
    

If `true`, column titles are visible.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **columns** = `1` [🔗](#class-tree-property-columns)

*   void **set\_columns**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_columns**()
    

The number of columns.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **drop\_mode\_flags** = `0` [🔗](#class-tree-property-drop-mode-flags)

*   void **set\_drop\_mode\_flags**(value: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int))
    
*   [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_drop\_mode\_flags**()
    

The drop mode as an OR combination of flags. See [DropModeFlags](#enum-tree-dropmodeflags) constants. Once dropping is done, reverts to [DROP\_MODE\_DISABLED](#class-tree-constant-drop-mode-disabled). Setting this during [Control.\_can\_drop\_data()](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-private-method-can-drop-data) is recommended.

This controls the drop sections, i.e. the decision and drawing of possible drop locations based on the mouse position.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **enable\_recursive\_folding** = `true` [🔗](#class-tree-property-enable-recursive-folding)

*   void **set\_enable\_recursive\_folding**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_recursive\_folding\_enabled**()
    

If `true`, recursive folding is enabled for this **Tree**. Holding down Shift while clicking the fold arrow or using `ui_right`/`ui_left` shortcuts collapses or uncollapses the [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and all its descendants.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **hide\_folding** = `false` [🔗](#class-tree-property-hide-folding)

*   void **set\_hide\_folding**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_folding\_hidden**()
    

If `true`, the folding arrow is hidden.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **hide\_root** = `false` [🔗](#class-tree-property-hide-root)

*   void **set\_hide\_root**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_root\_hidden**()
    

If `true`, the tree's root is hidden.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **scroll\_horizontal\_enabled** = `true` [🔗](#class-tree-property-scroll-horizontal-enabled)

*   void **set\_h\_scroll\_enabled**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_h\_scroll\_enabled**()
    

If `true`, enables horizontal scrolling.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **scroll\_vertical\_enabled** = `true` [🔗](#class-tree-property-scroll-vertical-enabled)

*   void **set\_v\_scroll\_enabled**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_v\_scroll\_enabled**()
    

If `true`, enables vertical scrolling.

---

[SelectMode](#enum-tree-selectmode) **select\_mode** = `0` [🔗](#class-tree-property-select-mode)

*   void **set\_select\_mode**(value: [SelectMode](#enum-tree-selectmode))
    
*   [SelectMode](#enum-tree-selectmode) **get\_select\_mode**()
    

Allows single or multiple selection. See the [SelectMode](#enum-tree-selectmode) constants.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

void **clear**() [🔗](#class-tree-method-clear)

Clears the tree. This removes all items.

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **create\_item**(parent: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) = null, index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1) [🔗](#class-tree-method-create-item)

Creates an item in the tree and adds it as a child of `parent`, which can be either a valid [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) or `null`.

If `parent` is `null`, the root item will be the parent, or the new item will be the root itself if the tree is empty.

The new item will be the `index`\-th child of parent, or it will be the last child if there are not enough siblings.

---

void **deselect\_all**() [🔗](#class-tree-method-deselect-all)

Deselects all tree items (rows and columns). In [SELECT\_MULTI](#class-tree-constant-select-multi) mode also removes selection cursor.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **edit\_selected**(force\_edit: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-tree-method-edit-selected)

Edits the selected tree item as if it was clicked.

Either the item must be set editable with [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable) or `force_edit` must be `true`.

Returns `true` if the item could be edited. Fails if no item is selected.

---

void **ensure\_cursor\_is\_visible**() [🔗](#class-tree-method-ensure-cursor-is-visible)

Makes the currently focused cell visible.

This will scroll the tree if necessary. In [SELECT\_ROW](#class-tree-constant-select-row) mode, this will not do horizontal scrolling, as all the cells in the selected row is focused logically.

**Note:** Despite the name of this method, the focus cursor itself is only visible in [SELECT\_MULTI](#class-tree-constant-select-multi) mode.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_button\_id\_at\_position**(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const [🔗](#class-tree-method-get-button-id-at-position)

Returns the button ID at `position`, or -1 if no button is there.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_column\_at\_position**(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const [🔗](#class-tree-method-get-column-at-position)

Returns the column index at `position`, or -1 if no item is there.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_column\_expand\_ratio**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-expand-ratio)

Returns the expand ratio assigned to the column.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_column\_title**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-title)

Returns the column's title.

---

[HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment) **get\_column\_title\_alignment**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-title-alignment)

Returns the column title alignment.

---

[TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection) **get\_column\_title\_direction**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-title-direction)

Returns column title base writing direction.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_column\_title\_language**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-title-language)

Returns column title language code.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_column\_width**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-get-column-width)

Returns the column's width in pixels.

---

Returns the rectangle for custom popups. Helper to create custom cell controls that display a popup. See [TreeItem.set\_cell\_mode()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-cell-mode).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_drop\_section\_at\_position**(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const [🔗](#class-tree-method-get-drop-section-at-position)

Returns the drop section at `position`, or -100 if no item is there.

Values -1, 0, or 1 will be returned for the "above item", "on item", and "below item" drop sections, respectively. See [DropModeFlags](#enum-tree-dropmodeflags) for a description of each drop section.

To get the item which the returned drop section is relative to, use [get\_item\_at\_position()](#class-tree-method-get-item-at-position).

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **get\_edited**() const [🔗](#class-tree-method-get-edited)

Returns the currently edited item. Can be used with [item\_edited](#class-tree-signal-item-edited) to get the item that was modified.

func \_ready():
	$Tree.item\_edited.connect(on\_Tree\_item\_edited)

func on\_Tree\_item\_edited():
	print($Tree.get\_edited()) \# This item just got edited (e.g. checked).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_edited\_column**() const [🔗](#class-tree-method-get-edited-column)

Returns the column for the currently edited item.

---

[Rect2](https://docs.godotengine.org/en/stable/classes/class_rect2.html#class-rect2) **get\_item\_area\_rect**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1, button\_index: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1) const [🔗](#class-tree-method-get-item-area-rect)

Returns the rectangle area for the specified [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem). If `column` is specified, only get the position and size of that column, otherwise get the rectangle containing all columns. If a button index is specified, the rectangle of that button will be returned.

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **get\_item\_at\_position**(position: [Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2)) const [🔗](#class-tree-method-get-item-at-position)

Returns the tree item at the specified position (relative to the tree origin position).

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **get\_next\_selected**(from: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem)) [🔗](#class-tree-method-get-next-selected)

Returns the next selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) after the given one, or `null` if the end is reached.

If `from` is `null`, this returns the first selected item.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_pressed\_button**() const [🔗](#class-tree-method-get-pressed-button)

Returns the last pressed button's index.

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **get\_root**() const [🔗](#class-tree-method-get-root)

Returns the tree's root item, or `null` if the tree is empty.

---

[Vector2](https://docs.godotengine.org/en/stable/classes/class_vector2.html#class-vector2) **get\_scroll**() const [🔗](#class-tree-method-get-scroll)

Returns the current scrolling position.

---

[TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) **get\_selected**() const [🔗](#class-tree-method-get-selected)

Returns the currently focused item, or `null` if no item is focused.

In [SELECT\_ROW](#class-tree-constant-select-row) and [SELECT\_SINGLE](#class-tree-constant-select-single) modes, the focused item is same as the selected item. In [SELECT\_MULTI](#class-tree-constant-select-multi) mode, the focused item is the item under the focus cursor, not necessarily selected.

To get the currently selected item(s), use [get\_next\_selected()](#class-tree-method-get-next-selected).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_selected\_column**() const [🔗](#class-tree-method-get-selected-column)

Returns the currently focused column, or -1 if no column is focused.

In [SELECT\_SINGLE](#class-tree-constant-select-single) mode, the focused column is the selected column. In [SELECT\_ROW](#class-tree-constant-select-row) mode, the focused column is always 0 if any item is selected. In [SELECT\_MULTI](#class-tree-constant-select-multi) mode, the focused column is the column under the focus cursor, and there are not necessarily any column selected.

To tell whether a column of an item is selected, use [TreeItem.is\_selected()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-is-selected).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_column\_clipping\_content**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-is-column-clipping-content)

Returns `true` if the column has enabled clipping (see [set\_column\_clip\_content()](#class-tree-method-set-column-clip-content)).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_column\_expanding**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-tree-method-is-column-expanding)

Returns `true` if the column has enabled expanding (see [set\_column\_expand()](#class-tree-method-set-column-expand)).

---

void **scroll\_to\_item**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), center\_on\_item: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-tree-method-scroll-to-item)

Causes the **Tree** to jump to the specified [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem).

---

void **set\_column\_clip\_content**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), enable: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-tree-method-set-column-clip-content)

Allows to enable clipping for column's content, making the content size ignored.

---

void **set\_column\_custom\_minimum\_width**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), min\_width: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-method-set-column-custom-minimum-width)

Overrides the calculated minimum width of a column. It can be set to `0` to restore the default behavior. Columns that have the "Expand" flag will use their "min\_width" in a similar fashion to [Control.size\_flags\_stretch\_ratio](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-size-flags-stretch-ratio).

---

void **set\_column\_expand**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), expand: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-tree-method-set-column-expand)

If `true`, the column will have the "Expand" flag of [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control). Columns that have the "Expand" flag will use their expand ratio in a similar fashion to [Control.size\_flags\_stretch\_ratio](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-size-flags-stretch-ratio) (see [set\_column\_expand\_ratio()](#class-tree-method-set-column-expand-ratio)).

---

void **set\_column\_expand\_ratio**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), ratio: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-method-set-column-expand-ratio)

Sets the relative expand ratio for a column. See [set\_column\_expand()](#class-tree-method-set-column-expand).

---

void **set\_column\_title**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), title: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-tree-method-set-column-title)

Sets the title of a column.

---

void **set\_column\_title\_alignment**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), title\_alignment: [HorizontalAlignment](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-horizontalalignment)) [🔗](#class-tree-method-set-column-title-alignment)

Sets the column title alignment. Note that [@GlobalScope.HORIZONTAL\_ALIGNMENT\_FILL](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-horizontal-alignment-fill) is not supported for column titles.

---

void **set\_column\_title\_direction**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), direction: [TextDirection](https://docs.godotengine.org/en/stable/classes/class_control.html#enum-control-textdirection)) [🔗](#class-tree-method-set-column-title-direction)

Sets column title base writing direction.

---

void **set\_column\_title\_language**(column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), language: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-tree-method-set-column-title-language)

Sets language code of column title used for line-breaking and text shaping algorithms, if left empty current locale is used instead.

---

void **set\_selected**(item: [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem), column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-tree-method-set-selected)

Selects the specified [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and column.

---

## Theme Property Descriptions[](#theme-property-descriptions "Link to this heading")

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **children\_hl\_line\_color** = `Color(0.27, 0.27, 0.27, 1)` [🔗](#class-tree-theme-color-children-hl-line-color)

The [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the relationship lines between the selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and its children.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **custom\_button\_font\_highlight** = `Color(0.95, 0.95, 0.95, 1)` [🔗](#class-tree-theme-color-custom-button-font-highlight)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) for a [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) mode cell when it's hovered.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **drop\_position\_color** = `Color(1, 1, 1, 1)` [🔗](#class-tree-theme-color-drop-position-color)

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) used to draw possible drop locations. See [DropModeFlags](#enum-tree-dropmodeflags) constants for further description of drop locations.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_color** = `Color(0.7, 0.7, 0.7, 1)` [🔗](#class-tree-theme-color-font-color)

Default text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the item.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_disabled\_color** = `Color(0.875, 0.875, 0.875, 0.5)` [🔗](#class-tree-theme-color-font-disabled-color)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) for a [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell when it's non-editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_hovered\_color** = `Color(0.95, 0.95, 0.95, 1)` [🔗](#class-tree-theme-color-font-hovered-color)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) used when the item is hovered and not selected yet.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_hovered\_dimmed\_color** = `Color(0.875, 0.875, 0.875, 1)` [🔗](#class-tree-theme-color-font-hovered-dimmed-color)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) used when the item is hovered, while a button of the same item is hovered as the same time.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_hovered\_selected\_color** = `Color(1, 1, 1, 1)` [🔗](#class-tree-theme-color-font-hovered-selected-color)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) used when the item is hovered and selected.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_outline\_color** = `Color(0, 0, 0, 1)` [🔗](#class-tree-theme-color-font-outline-color)

The tint of text outline of the item.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **font\_selected\_color** = `Color(1, 1, 1, 1)` [🔗](#class-tree-theme-color-font-selected-color)

Text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) used when the item is selected.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **guide\_color** = `Color(0.7, 0.7, 0.7, 0.25)` [🔗](#class-tree-theme-color-guide-color)

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the guideline.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **parent\_hl\_line\_color** = `Color(0.27, 0.27, 0.27, 1)` [🔗](#class-tree-theme-color-parent-hl-line-color)

The [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the relationship lines between the selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and its parents.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **relationship\_line\_color** = `Color(0.27, 0.27, 0.27, 1)` [🔗](#class-tree-theme-color-relationship-line-color)

The default [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the relationship lines.

---

[Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) **title\_button\_color** = `Color(0.875, 0.875, 0.875, 1)` [🔗](#class-tree-theme-color-title-button-color)

Default text [Color](https://docs.godotengine.org/en/stable/classes/class_color.html#class-color) of the title button.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **button\_margin** = `4` [🔗](#class-tree-theme-constant-button-margin)

The horizontal space between each button in a cell.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **children\_hl\_line\_width** = `1` [🔗](#class-tree-theme-constant-children-hl-line-width)

The width of the relationship lines between the selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and its children.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **draw\_guides** = `1` [🔗](#class-tree-theme-constant-draw-guides)

Draws the guidelines if not zero, this acts as a boolean. The guideline is a horizontal line drawn at the bottom of each item.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **draw\_relationship\_lines** = `0` [🔗](#class-tree-theme-constant-draw-relationship-lines)

Draws the relationship lines if not zero, this acts as a boolean. Relationship lines are drawn at the start of child items to show hierarchy.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **h\_separation** = `4` [🔗](#class-tree-theme-constant-h-separation)

The horizontal space between item cells. This is also used as the margin at the start of an item when folding is disabled.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **icon\_max\_width** = `0` [🔗](#class-tree-theme-constant-icon-max-width)

The maximum allowed width of the icon in item's cells. This limit is applied on top of the default size of the icon, but before the value set with [TreeItem.set\_icon\_max\_width()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-icon-max-width). The height is adjusted according to the icon's ratio.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **inner\_item\_margin\_bottom** = `0` [🔗](#class-tree-theme-constant-inner-item-margin-bottom)

The inner bottom margin of a cell.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **inner\_item\_margin\_left** = `0` [🔗](#class-tree-theme-constant-inner-item-margin-left)

The inner left margin of a cell.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **inner\_item\_margin\_right** = `0` [🔗](#class-tree-theme-constant-inner-item-margin-right)

The inner right margin of a cell.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **inner\_item\_margin\_top** = `0` [🔗](#class-tree-theme-constant-inner-item-margin-top)

The inner top margin of a cell.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **item\_margin** = `16` [🔗](#class-tree-theme-constant-item-margin)

The horizontal margin at the start of an item. This is used when folding is enabled for the item.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **outline\_size** = `0` [🔗](#class-tree-theme-constant-outline-size)

The size of the text outline.

**Note:** If using a font with [FontFile.multichannel\_signed\_distance\_field](https://docs.godotengine.org/en/stable/classes/class_fontfile.html#class-fontfile-property-multichannel-signed-distance-field) enabled, its [FontFile.msdf\_pixel\_range](https://docs.godotengine.org/en/stable/classes/class_fontfile.html#class-fontfile-property-msdf-pixel-range) must be set to at least *twice* the value of [outline\_size](#class-tree-theme-constant-outline-size) for outline rendering to look correct. Otherwise, the outline may appear to be cut off earlier than intended.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **parent\_hl\_line\_margin** = `0` [🔗](#class-tree-theme-constant-parent-hl-line-margin)

The space between the parent relationship lines for the selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and the relationship lines to its siblings that are not selected.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **parent\_hl\_line\_width** = `1` [🔗](#class-tree-theme-constant-parent-hl-line-width)

The width of the relationship lines between the selected [TreeItem](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem) and its parents.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **relationship\_line\_width** = `1` [🔗](#class-tree-theme-constant-relationship-line-width)

The default width of the relationship lines.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scroll\_border** = `4` [🔗](#class-tree-theme-constant-scroll-border)

The maximum distance between the mouse cursor and the control's border to trigger border scrolling when dragging.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scroll\_speed** = `12` [🔗](#class-tree-theme-constant-scroll-speed)

The speed of border scrolling.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_h\_separation** = `4` [🔗](#class-tree-theme-constant-scrollbar-h-separation)

The horizontal separation of tree content and scrollbar.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_margin\_bottom** = `-1` [🔗](#class-tree-theme-constant-scrollbar-margin-bottom)

The bottom margin of the scrollbars. When negative, uses [panel](#class-tree-theme-style-panel) bottom margin.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_margin\_left** = `-1` [🔗](#class-tree-theme-constant-scrollbar-margin-left)

The left margin of the horizontal scrollbar. When negative, uses [panel](#class-tree-theme-style-panel) left margin.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_margin\_right** = `-1` [🔗](#class-tree-theme-constant-scrollbar-margin-right)

The right margin of the scrollbars. When negative, uses [panel](#class-tree-theme-style-panel) right margin.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_margin\_top** = `-1` [🔗](#class-tree-theme-constant-scrollbar-margin-top)

The top margin of the vertical scrollbar. When negative, uses [panel](#class-tree-theme-style-panel) top margin.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **scrollbar\_v\_separation** = `4` [🔗](#class-tree-theme-constant-scrollbar-v-separation)

The vertical separation of tree content and scrollbar.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **v\_separation** = `4` [🔗](#class-tree-theme-constant-v-separation)

The vertical padding inside each item, i.e. the distance between the item's content and top/bottom border.

---

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font) **font** [🔗](#class-tree-theme-font-font)

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font) of the item's text.

---

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font) **title\_button\_font** [🔗](#class-tree-theme-font-title-button-font)

[Font](https://docs.godotengine.org/en/stable/classes/class_font.html#class-font) of the title button's text.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **font\_size** [🔗](#class-tree-theme-font-size-font-size)

Font size of the item's text.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **title\_button\_font\_size** [🔗](#class-tree-theme-font-size-title-button-font-size)

Font size of the title button's text.

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **arrow** [🔗](#class-tree-theme-icon-arrow)

The arrow icon used when a foldable item is not collapsed.

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **arrow\_collapsed** [🔗](#class-tree-theme-icon-arrow-collapsed)

The arrow icon used when a foldable item is collapsed (for left-to-right layouts).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **arrow\_collapsed\_mirrored** [🔗](#class-tree-theme-icon-arrow-collapsed-mirrored)

The arrow icon used when a foldable item is collapsed (for right-to-left layouts).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **checked** [🔗](#class-tree-theme-icon-checked)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is checked and editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **checked\_disabled** [🔗](#class-tree-theme-icon-checked-disabled)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is checked and non-editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **indeterminate** [🔗](#class-tree-theme-icon-indeterminate)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is indeterminate and editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **indeterminate\_disabled** [🔗](#class-tree-theme-icon-indeterminate-disabled)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is indeterminate and non-editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **select\_arrow** [🔗](#class-tree-theme-icon-select-arrow)

The arrow icon to display for the [TreeItem.CELL\_MODE\_RANGE](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-range) mode cell.

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **unchecked** [🔗](#class-tree-theme-icon-unchecked)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is unchecked and editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **unchecked\_disabled** [🔗](#class-tree-theme-icon-unchecked-disabled)

The check icon to display when the [TreeItem.CELL\_MODE\_CHECK](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-check) mode cell is unchecked and non-editable (see [TreeItem.set\_editable()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-editable)).

---

[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) **updown** [🔗](#class-tree-theme-icon-updown)

The updown arrow icon to display for the [TreeItem.CELL\_MODE\_RANGE](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-range) mode cell.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **button\_hover** [🔗](#class-tree-theme-style-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used when a button in the tree is hovered.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **button\_pressed** [🔗](#class-tree-theme-style-button-pressed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used when a button in the tree is pressed.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **cursor** [🔗](#class-tree-theme-style-cursor)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used for the cursor, when the **Tree** is being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **cursor\_unfocused** [🔗](#class-tree-theme-style-cursor-unfocused)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used for the cursor, when the **Tree** is not being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **custom\_button** [🔗](#class-tree-theme-style-custom-button)

Default [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for a [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) mode cell when button is enabled with [TreeItem.set\_custom\_as\_button()](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-method-set-custom-as-button).

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **custom\_button\_hover** [🔗](#class-tree-theme-style-custom-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for a [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) mode button cell when it's hovered.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **custom\_button\_pressed** [🔗](#class-tree-theme-style-custom-button-pressed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for a [TreeItem.CELL\_MODE\_CUSTOM](https://docs.godotengine.org/en/stable/classes/class_treeitem.html#class-treeitem-constant-cell-mode-custom) mode button cell when it's pressed.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **focus** [🔗](#class-tree-theme-style-focus)

The focused style for the **Tree**, drawn on top of everything.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **hovered** [🔗](#class-tree-theme-style-hovered)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the item being hovered, but not selected.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **hovered\_dimmed** [🔗](#class-tree-theme-style-hovered-dimmed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the item being hovered, while a button of the same item is hovered as the same time.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **hovered\_selected** [🔗](#class-tree-theme-style-hovered-selected)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the hovered and selected items, used when the **Tree** is not being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **hovered\_selected\_focus** [🔗](#class-tree-theme-style-hovered-selected-focus)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the hovered and selected items, used when the **Tree** is being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **panel** [🔗](#class-tree-theme-style-panel)

The background style for the **Tree**.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **selected** [🔗](#class-tree-theme-style-selected)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the selected items, used when the **Tree** is not being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **selected\_focus** [🔗](#class-tree-theme-style-selected-focus)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the selected items, used when the **Tree** is being focused.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **title\_button\_hover** [🔗](#class-tree-theme-style-title-button-hover)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used when the title button is being hovered.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **title\_button\_normal** [🔗](#class-tree-theme-style-title-button-normal)

Default [StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) for the title button.

---

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) **title\_button\_pressed** [🔗](#class-tree-theme-style-title-button-pressed)

[StyleBox](https://docs.godotengine.org/en/stable/classes/class_stylebox.html#class-stylebox) used when the title button is being pressed.