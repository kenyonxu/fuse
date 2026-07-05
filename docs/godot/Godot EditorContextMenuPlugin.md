# EditorContextMenuPlugin

*   Godot Engine 4.5 documentation in English
    
    *   [](https://docs.godotengine.org/en/stable/index.html)
    *   [All classes](https://docs.godotengine.org/en/stable/classes/index.html)
    *   EditorContextMenuPlugin

---

**Inherits:** [RefCounted](https://docs.godotengine.org/en/stable/classes/class_refcounted.html#class-refcounted) **<** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

Plugin for adding custom context menus in the editor.

## Description[](#description "Link to this heading")

**EditorContextMenuPlugin** allows for the addition of custom options in the editor's context menu.

Currently, context menus are supported for three commonly used areas: the file system, scene tree, and editor script list panel.

## Methods[](#methods "Link to this heading")

---

## Enumerations[](#enumerations "Link to this heading")

enum **ContextMenuSlot**: [🔗](#enum-editorcontextmenuplugin-contextmenuslot)

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_SCENE\_TREE** = `0`

Context menu of Scene dock. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) will be called with a list of paths to currently selected nodes, while option callback will receive the list of currently selected nodes.

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_FILESYSTEM** = `1`

Context menu of FileSystem dock. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) and option callback will be called with list of paths of the currently selected files.

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_SCRIPT\_EDITOR** = `2`

Context menu of Script editor's script tabs. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) will be called with the path to the currently edited script, while option callback will receive reference to that script.

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_FILESYSTEM\_CREATE** = `3`

The "Create..." submenu of FileSystem dock's context menu, or the "New" section of the main context menu when empty space is clicked. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) and option callback will be called with the path of the currently selected folder. When clicking the empty space, the list of paths for popup method will be empty.

func \_popup\_menu(paths):
	if paths.is\_empty():
		add\_context\_menu\_item("New Image File...", create\_image)
	else:
		add\_context\_menu\_item("Image File...", create\_image)

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_SCRIPT\_EDITOR\_CODE** = `4`

Context menu of Script editor's code editor. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) will be called with the path to the [CodeEdit](https://docs.godotengine.org/en/stable/classes/class_codeedit.html#class-codeedit) node. You can fetch it using this code:

func \_popup\_menu(paths):
	var code\_edit \= Engine.get\_main\_loop().root.get\_node(paths\[0\]);

The option callback will receive reference to that node. You can use [CodeEdit](https://docs.godotengine.org/en/stable/classes/class_codeedit.html#class-codeedit) methods to perform symbol lookups etc.

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_SCENE\_TABS** = `5`

Context menu of scene tabs. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) will be called with the path of the clicked scene, or empty [PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) if the menu was opened on empty space. The option callback will receive the path of the clicked scene, or empty [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) if none was clicked.

[ContextMenuSlot](#enum-editorcontextmenuplugin-contextmenuslot) **CONTEXT\_SLOT\_2D\_EDITOR** = `6`

Context menu of 2D editor's basic right-click menu. [\_popup\_menu()](#class-editorcontextmenuplugin-private-method-popup-menu) will be called with paths to all [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem) nodes under the cursor. You can fetch them using this code:

func \_popup\_menu(paths):
	var canvas\_item \= Engine.get\_main\_loop().root.get\_node(paths\[0\]); \# Replace 0 with the desired index.

The paths array is empty if there weren't any nodes under cursor. The option callback will receive a typed array of [CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem) nodes.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

void **\_popup\_menu**(paths: [PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)) virtual [🔗](#class-editorcontextmenuplugin-private-method-popup-menu)

Called when creating a context menu, custom options can be added by using the [add\_context\_menu\_item()](#class-editorcontextmenuplugin-method-add-context-menu-item) or [add\_context\_menu\_item\_from\_shortcut()](#class-editorcontextmenuplugin-method-add-context-menu-item-from-shortcut) functions. `paths` contains currently selected paths (depending on menu), which can be used to conditionally add options.

---

void **add\_context\_menu\_item**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), callback: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable), icon: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) = null) [🔗](#class-editorcontextmenuplugin-method-add-context-menu-item)

Add custom option to the context menu of the plugin's specified slot. When the option is activated, `callback` will be called. Callback should take single [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) argument; array contents depend on context menu slot.

func \_popup\_menu(paths):
	add\_context\_menu\_item("File Custom options", handle, ICON)

If you want to assign shortcut to the menu item, use [add\_context\_menu\_item\_from\_shortcut()](#class-editorcontextmenuplugin-method-add-context-menu-item-from-shortcut) instead.

---

void **add\_context\_menu\_item\_from\_shortcut**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), shortcut: [Shortcut](https://docs.godotengine.org/en/stable/classes/class_shortcut.html#class-shortcut), icon: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) = null) [🔗](#class-editorcontextmenuplugin-method-add-context-menu-item-from-shortcut)

Add custom option to the context menu of the plugin's specified slot. The option will have the `shortcut` assigned and reuse its callback. The shortcut has to be registered beforehand with [add\_menu\_shortcut()](#class-editorcontextmenuplugin-method-add-menu-shortcut).

func \_init():
	add\_menu\_shortcut(SHORTCUT, handle)

func \_popup\_menu(paths):
	add\_context\_menu\_item\_from\_shortcut("File Custom options", SHORTCUT, ICON)

---

void **add\_context\_submenu\_item**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), menu: [PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html#class-popupmenu), icon: [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d) = null) [🔗](#class-editorcontextmenuplugin-method-add-context-submenu-item)

Add a submenu to the context menu of the plugin's specified slot. The submenu is not automatically handled, you need to connect to its signals yourself. Also the submenu is freed on every popup, so provide a new [PopupMenu](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html#class-popupmenu) every time.

func \_popup\_menu(paths):
	var popup\_menu \= PopupMenu.new()
	popup\_menu.add\_item("Blue")
	popup\_menu.add\_item("White")
	popup\_menu.id\_pressed.connect(\_on\_color\_submenu\_option)

	add\_context\_submenu\_item("Set Node Color", popup\_menu)

---

void **add\_menu\_shortcut**(shortcut: [Shortcut](https://docs.godotengine.org/en/stable/classes/class_shortcut.html#class-shortcut), callback: [Callable](https://docs.godotengine.org/en/stable/classes/class_callable.html#class-callable)) [🔗](#class-editorcontextmenuplugin-method-add-menu-shortcut)

Registers a shortcut associated with the plugin's context menu. This method should be called once (e.g. in plugin's [Object.\_init()](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-private-method-init)). `callback` will be called when user presses the specified `shortcut` while the menu's context is in effect (e.g. FileSystem dock is focused). Callback should take single [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) argument; array contents depend on context menu slot.

func \_init():
	add\_menu\_shortcut(SHORTCUT, handle)