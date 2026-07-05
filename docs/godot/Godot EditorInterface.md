# EditorInterface

Godot editor's interface.

## Property Descriptions[](#property-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **distraction\_free\_mode** [🔗](#class-editorinterface-property-distraction-free-mode)

*   void **set\_distraction\_free\_mode**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_distraction\_free\_mode\_enabled**()
    

If `true`, enables distraction-free mode which hides side docks to increase the space available for the main view.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **movie\_maker\_enabled** [🔗](#class-editorinterface-property-movie-maker-enabled)

*   void **set\_movie\_maker\_enabled**(value: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool))
    
*   [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_movie\_maker\_enabled**()
    

If `true`, the Movie Maker mode is enabled in the editor. See [MovieWriter](https://docs.godotengine.org/en/stable/classes/class_moviewriter.html#class-moviewriter) for more information.

## Method Descriptions[](#method-descriptions "Link to this heading")

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error) **close\_scene**() [🔗](#class-editorinterface-method-close-scene)

Closes the currently active scene, discarding any pending changes in the process. Returns [@GlobalScope.OK](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-ok) on success or [@GlobalScope.ERR\_DOES\_NOT\_EXIST](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-does-not-exist) if there is no scene to close.

---

void **edit\_node**(node: [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node)) [🔗](#class-editorinterface-method-edit-node)

Edits the given [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node). The node will be also selected if it's inside the scene tree.

---

void **edit\_resource**(resource: [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource)) [🔗](#class-editorinterface-method-edit-resource)

Edits the given [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource). If the resource is a [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script) you can also edit it with [edit\_script()](#class-editorinterface-method-edit-script) to specify the line and column position.

---

void **edit\_script**(script: [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script), line: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = -1, column: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 0, grab\_focus: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-editorinterface-method-edit-script)

Edits the given [Script](https://docs.godotengine.org/en/stable/classes/class_script.html#class-script). The line and column on which to open the script can also be specified. The script will be open with the user-configured editor for the script's language which may be an external editor.

---

[Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) **get\_base\_control**() const [🔗](#class-editorinterface-method-get-base-control)

Returns the main container of Godot editor's window. For example, you can use it to retrieve the size of the container and place your controls accordingly.

**Warning:** Removing and freeing this node will render the editor useless and may cause a crash.

---

[EditorCommandPalette](https://docs.godotengine.org/en/stable/classes/class_editorcommandpalette.html#class-editorcommandpalette) **get\_command\_palette**() const [🔗](#class-editorinterface-method-get-command-palette)

Returns the editor's [EditorCommandPalette](https://docs.godotengine.org/en/stable/classes/class_editorcommandpalette.html#class-editorcommandpalette) instance.

**Warning:** Removing and freeing this node will render a part of the editor useless and may cause a crash.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_current\_directory**() const [🔗](#class-editorinterface-method-get-current-directory)

Returns the current directory being viewed in the [FileSystemDock](https://docs.godotengine.org/en/stable/classes/class_filesystemdock.html#class-filesystemdock). If a file is selected, its base directory will be returned using [String.get\_base\_dir()](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string-method-get-base-dir) instead.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_current\_feature\_profile**() const [🔗](#class-editorinterface-method-get-current-feature-profile)

Returns the name of the currently activated feature profile. If the default profile is currently active, an empty string is returned instead.

In order to get a reference to the [EditorFeatureProfile](https://docs.godotengine.org/en/stable/classes/class_editorfeatureprofile.html#class-editorfeatureprofile), you must load the feature profile using [EditorFeatureProfile.load\_from\_file()](https://docs.godotengine.org/en/stable/classes/class_editorfeatureprofile.html#class-editorfeatureprofile-method-load-from-file).

**Note:** Feature profiles created via the user interface are loaded from the `feature_profiles` directory, as a file with the `.profile` extension. The editor configuration folder can be found by using [EditorPaths.get\_config\_dir()](https://docs.godotengine.org/en/stable/classes/class_editorpaths.html#class-editorpaths-method-get-config-dir).

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_current\_path**() const [🔗](#class-editorinterface-method-get-current-path)

Returns the current path being viewed in the [FileSystemDock](https://docs.godotengine.org/en/stable/classes/class_filesystemdock.html#class-filesystemdock).

---

[Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) **get\_edited\_scene\_root**() const [🔗](#class-editorinterface-method-get-edited-scene-root)

Returns the edited (current) scene's root [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node).

---

[VBoxContainer](https://docs.godotengine.org/en/stable/classes/class_vboxcontainer.html#class-vboxcontainer) **get\_editor\_main\_screen**() const [🔗](#class-editorinterface-method-get-editor-main-screen)

Returns the editor control responsible for main screen plugins and tools. Use it with plugins that implement [EditorPlugin.\_has\_main\_screen()](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html#class-editorplugin-private-method-has-main-screen).

**Note:** This node is a [VBoxContainer](https://docs.godotengine.org/en/stable/classes/class_vboxcontainer.html#class-vboxcontainer), which means that if you add a [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) child to it, you need to set the child's [Control.size\_flags\_vertical](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-property-size-flags-vertical) to [Control.SIZE\_EXPAND\_FILL](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control-constant-size-expand-fill) to make it use the full available space.

**Warning:** Removing and freeing this node will render a part of the editor useless and may cause a crash.

---

[EditorPaths](https://docs.godotengine.org/en/stable/classes/class_editorpaths.html#class-editorpaths) **get\_editor\_paths**() const [🔗](#class-editorinterface-method-get-editor-paths)

Returns the [EditorPaths](https://docs.godotengine.org/en/stable/classes/class_editorpaths.html#class-editorpaths) singleton.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_editor\_scale**() const [🔗](#class-editorinterface-method-get-editor-scale)

Returns the actual scale of the editor UI (`1.0` being 100% scale). This can be used to adjust position and dimensions of the UI added by plugins.

**Note:** This value is set via the [EditorSettings.interface/editor/display\_scale](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings-property-interface-editor-display-scale) and [EditorSettings.interface/editor/custom\_display\_scale](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings-property-interface-editor-custom-display-scale) settings. The editor must be restarted for changes to be properly applied.

---

[EditorSettings](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings) **get\_editor\_settings**() const [🔗](#class-editorinterface-method-get-editor-settings)

Returns the editor's [EditorSettings](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings) instance.

---

[Theme](https://docs.godotengine.org/en/stable/classes/class_theme.html#class-theme) **get\_editor\_theme**() const [🔗](#class-editorinterface-method-get-editor-theme)

Returns the editor's [Theme](https://docs.godotengine.org/en/stable/classes/class_theme.html#class-theme).

**Note:** When creating custom editor UI, prefer accessing theme items directly from your GUI nodes using the `get_theme_*` methods.

---

[EditorToaster](https://docs.godotengine.org/en/stable/classes/class_editortoaster.html#class-editortoaster) **get\_editor\_toaster**() const [🔗](#class-editorinterface-method-get-editor-toaster)

Returns the editor's [EditorToaster](https://docs.godotengine.org/en/stable/classes/class_editortoaster.html#class-editortoaster).

---

[EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html#class-editorundoredomanager) **get\_editor\_undo\_redo**() const [🔗](#class-editorinterface-method-get-editor-undo-redo)

Returns the editor's [EditorUndoRedoManager](https://docs.godotengine.org/en/stable/classes/class_editorundoredomanager.html#class-editorundoredomanager).

---

[SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html#class-subviewport) **get\_editor\_viewport\_2d**() const [🔗](#class-editorinterface-method-get-editor-viewport-2d)

Returns the 2D editor [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html#class-subviewport). It does not have a camera. Instead, the view transforms are done directly and can be accessed with [Viewport.global\_canvas\_transform](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-global-canvas-transform).

---

[SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html#class-subviewport) **get\_editor\_viewport\_3d**(idx: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) = 0) const [🔗](#class-editorinterface-method-get-editor-viewport-3d)

Returns the specified 3D editor [SubViewport](https://docs.godotengine.org/en/stable/classes/class_subviewport.html#class-subviewport), from `0` to `3`. The viewport can be used to access the active editor cameras with [Viewport.get\_camera\_3d()](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-camera-3d).

---

[FileSystemDock](https://docs.godotengine.org/en/stable/classes/class_filesystemdock.html#class-filesystemdock) **get\_file\_system\_dock**() const [🔗](#class-editorinterface-method-get-file-system-dock)

Returns the editor's [FileSystemDock](https://docs.godotengine.org/en/stable/classes/class_filesystemdock.html#class-filesystemdock) instance.

**Warning:** Removing and freeing this node will render a part of the editor useless and may cause a crash.

---

[EditorInspector](https://docs.godotengine.org/en/stable/classes/class_editorinspector.html#class-editorinspector) **get\_inspector**() const [🔗](#class-editorinterface-method-get-inspector)

Returns the editor's [EditorInspector](https://docs.godotengine.org/en/stable/classes/class_editorinspector.html#class-editorinspector) instance.

**Warning:** Removing and freeing this node will render a part of the editor useless and may cause a crash.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node)\] **get\_open\_scene\_roots**() const [🔗](#class-editorinterface-method-get-open-scene-roots)

Returns an array with references to the root nodes of the currently opened scenes.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **get\_open\_scenes**() const [🔗](#class-editorinterface-method-get-open-scenes)

Returns an array with the file paths of the currently opened scenes.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_playing\_scene**() const [🔗](#class-editorinterface-method-get-playing-scene)

Returns the name of the scene that is being played. If no scene is currently being played, returns an empty string.

---

[EditorFileSystem](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html#class-editorfilesystem) **get\_resource\_filesystem**() const [🔗](#class-editorinterface-method-get-resource-filesystem)

Returns the editor's [EditorFileSystem](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html#class-editorfilesystem) instance.

---

[EditorResourcePreview](https://docs.godotengine.org/en/stable/classes/class_editorresourcepreview.html#class-editorresourcepreview) **get\_resource\_previewer**() const [🔗](#class-editorinterface-method-get-resource-previewer)

Returns the editor's [EditorResourcePreview](https://docs.godotengine.org/en/stable/classes/class_editorresourcepreview.html#class-editorresourcepreview) instance.

---

[ScriptEditor](https://docs.godotengine.org/en/stable/classes/class_scripteditor.html#class-scripteditor) **get\_script\_editor**() const [🔗](#class-editorinterface-method-get-script-editor)

Returns the editor's [ScriptEditor](https://docs.godotengine.org/en/stable/classes/class_scripteditor.html#class-scripteditor) instance.

**Warning:** Removing and freeing this node will render a part of the editor useless and may cause a crash.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **get\_selected\_paths**() const [🔗](#class-editorinterface-method-get-selected-paths)

Returns an array containing the paths of the currently selected files (and directories) in the [FileSystemDock](https://docs.godotengine.org/en/stable/classes/class_filesystemdock.html#class-filesystemdock).

---

[EditorSelection](https://docs.godotengine.org/en/stable/classes/class_editorselection.html#class-editorselection) **get\_selection**() const [🔗](#class-editorinterface-method-get-selection)

Returns the editor's [EditorSelection](https://docs.godotengine.org/en/stable/classes/class_editorselection.html#class-editorselection) instance.

---

void **inspect\_object**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), for\_property: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) = "", inspector\_only: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-editorinterface-method-inspect-object)

Shows the given property on the given `object` in the editor's Inspector dock. If `inspector_only` is `true`, plugins will not attempt to edit `object`.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_multi\_window\_enabled**() const [🔗](#class-editorinterface-method-is-multi-window-enabled)

Returns `true` if multiple window support is enabled in the editor. Multiple window support is enabled if *all* of these statements are true:

*   [EditorSettings.interface/multi\_window/enable](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings-property-interface-multi-window-enable) is `true`.
    
*   [EditorSettings.interface/editor/single\_window\_mode](https://docs.godotengine.org/en/stable/classes/class_editorsettings.html#class-editorsettings-property-interface-editor-single-window-mode) is `false`.
    
*   [Viewport.gui\_embed\_subwindows](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-property-gui-embed-subwindows) is `false`. This is forced to `true` on platforms that don't support multiple windows such as Web, or when the `--single-window` [command line argument](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html) is used.
    

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_playing\_scene**() const [🔗](#class-editorinterface-method-is-playing-scene)

Returns `true` if a scene is currently being played, `false` otherwise. Paused scenes are considered as being played.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_plugin\_enabled**(plugin: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) const [🔗](#class-editorinterface-method-is-plugin-enabled)

Returns `true` if the specified `plugin` is enabled. The plugin name is the same as its directory name.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)\] **make\_mesh\_previews**(meshes: [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Mesh](https://docs.godotengine.org/en/stable/classes/class_mesh.html#class-mesh)\], preview\_size: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) [🔗](#class-editorinterface-method-make-mesh-previews)

Returns mesh previews rendered at the given size as an [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) of [Texture2D](https://docs.godotengine.org/en/stable/classes/class_texture2d.html#class-texture2d)s.

---

void **mark\_scene\_as\_unsaved**() [🔗](#class-editorinterface-method-mark-scene-as-unsaved)

Marks the current scene tab as unsaved.

---

void **open\_scene\_from\_path**(scene\_filepath: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), set\_inherited: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) [🔗](#class-editorinterface-method-open-scene-from-path)

Opens the scene at the given path. If `set_inherited` is `true`, creates a new inherited scene.

---

void **play\_current\_scene**() [🔗](#class-editorinterface-method-play-current-scene)

Plays the currently active scene.

---

void **play\_custom\_scene**(scene\_filepath: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinterface-method-play-custom-scene)

Plays the scene specified by its filepath.

---

void **play\_main\_scene**() [🔗](#class-editorinterface-method-play-main-scene)

Plays the main scene.

---

**Experimental:** This method may be changed or removed in future versions.

Pops up an editor dialog for creating an object.

The `callback` must take a single argument of type [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) which will contain the type name of the selected object or be empty if no item is selected.

The `base_type` specifies the base type of objects to display. For example, if you set this to "Resource", all types derived from [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) will display in the create dialog.

The `current_type` will be passed in the search box of the create dialog, and the specified type can be immediately selected when the dialog pops up. If the `current_type` is not derived from `base_type`, there will be no result of the type in the dialog.

The `dialog_title` allows you to define a custom title for the dialog. This is useful if you want to accurately hint the usage of the dialog. If the `dialog_title` is an empty string, the dialog will use "Create New 'Base Type'" as the default title.

The `type_blocklist` contains a list of type names, and the types in the blocklist will be hidden from the create dialog.

**Note:** Trying to list the base type in the `type_blocklist` will hide all types derived from the base type from the create dialog.

---

Pops up the `dialog` in the editor UI with [Window.popup\_exclusive()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-popup-exclusive). The dialog must have no current parent, otherwise the method fails.

See also [Window.set\_unparent\_when\_invisible()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-set-unparent-when-invisible).

---

Pops up the `dialog` in the editor UI with [Window.popup\_exclusive\_centered()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-popup-exclusive-centered). The dialog must have no current parent, otherwise the method fails.

See also [Window.set\_unparent\_when\_invisible()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-set-unparent-when-invisible).

---

Pops up the `dialog` in the editor UI with [Window.popup\_exclusive\_centered\_clamped()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-popup-exclusive-centered-clamped). The dialog must have no current parent, otherwise the method fails.

See also [Window.set\_unparent\_when\_invisible()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-set-unparent-when-invisible).

---

Pops up the `dialog` in the editor UI with [Window.popup\_exclusive\_centered\_ratio()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-popup-exclusive-centered-ratio). The dialog must have no current parent, otherwise the method fails.

See also [Window.set\_unparent\_when\_invisible()](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-method-set-unparent-when-invisible).

---

Pops up an editor dialog for selecting a method from `object`. The `callback` must take a single argument of type [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) which will contain the name of the selected method or be empty if the dialog is canceled. If `current_value` is provided, the method will be selected automatically in the method list, if it exists.

---

Pops up an editor dialog for selecting a [Node](https://docs.godotengine.org/en/stable/classes/class_node.html#class-node) from the edited scene. The `callback` must take a single argument of type [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath). It is called on the selected [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath) or the empty path `^""` if the dialog is canceled. If `valid_types` is provided, the dialog will only show Nodes that match one of the listed Node types. If `current_value` is provided, the Node will be automatically selected in the tree, if it exists.

**Example:** Display the node selection dialog as soon as this node is added to the tree for the first time:

func \_ready():
	if Engine.is\_editor\_hint():
		EditorInterface.popup\_node\_selector(\_on\_node\_selected, \["Button"\])

func \_on\_node\_selected(node\_path):
	if node\_path.is\_empty():
		print("node selection canceled")
	else:
		print("selected ", node\_path)

---

Pops up an editor dialog for selecting properties from `object`. The `callback` must take a single argument of type [NodePath](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath). It is called on the selected property path (see [NodePath.get\_as\_property\_path()](https://docs.godotengine.org/en/stable/classes/class_nodepath.html#class-nodepath-method-get-as-property-path)) or the empty path `^""` if the dialog is canceled. If `type_filter` is provided, the dialog will only show properties that match one of the listed [Variant.Type](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type) values. If `current_value` is provided, the property will be selected automatically in the property list, if it exists.

func \_ready():
	if Engine.is\_editor\_hint():
		EditorInterface.popup\_property\_selector(this, \_on\_property\_selected, \[TYPE\_INT\])

func \_on\_property\_selected(property\_path):
	if property\_path.is\_empty():
		print("property selection canceled")
	else:
		print("selected ", property\_path)

---

Pops up an editor dialog for quick selecting a resource file. The `callback` must take a single argument of type [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) which will contain the path of the selected resource or be empty if the dialog is canceled. If `base_types` is provided, the dialog will only show resources that match these types. Only types deriving from [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) are supported.

---

void **reload\_scene\_from\_path**(scene\_filepath: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinterface-method-reload-scene-from-path)

Reloads the scene at the given path.

---

void **restart\_editor**(save: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-editorinterface-method-restart-editor)

Restarts the editor. This closes the editor and then opens the same project. If `save` is `true`, the project will be saved before restarting.

---

void **save\_all\_scenes**() [🔗](#class-editorinterface-method-save-all-scenes)

Saves all opened scenes in the editor.

---

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error) **save\_scene**() [🔗](#class-editorinterface-method-save-scene)

Saves the currently active scene. Returns either [@GlobalScope.OK](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-ok) or [@GlobalScope.ERR\_CANT\_CREATE](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-constant-err-cant-create).

---

void **save\_scene\_as**(path: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), with\_preview: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = true) [🔗](#class-editorinterface-method-save-scene-as)

Saves the currently active scene as a file at `path`.

---

void **select\_file**(file: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinterface-method-select-file)

Selects the file, with the path provided by `file`, in the FileSystem dock.

---

void **set\_current\_feature\_profile**(profile\_name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinterface-method-set-current-feature-profile)

Selects and activates the specified feature profile with the given `profile_name`. Set `profile_name` to an empty string to reset to the default feature profile.

A feature profile can be created programmatically using the [EditorFeatureProfile](https://docs.godotengine.org/en/stable/classes/class_editorfeatureprofile.html#class-editorfeatureprofile) class.

**Note:** The feature profile that gets activated must be located in the `feature_profiles` directory, as a file with the `.profile` extension. If a profile could not be found, an error occurs. The editor configuration folder can be found by using [EditorPaths.get\_config\_dir()](https://docs.godotengine.org/en/stable/classes/class_editorpaths.html#class-editorpaths-method-get-config-dir).

---

void **set\_main\_screen\_editor**(name: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) [🔗](#class-editorinterface-method-set-main-screen-editor)

Sets the editor's current main screen to the one specified in `name`. `name` must match the title of the tab in question exactly (e.g. `2D`, `3D`, `Script`, `Game`, or `AssetLib` for default tabs).

---

void **set\_plugin\_enabled**(plugin: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), enabled: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) [🔗](#class-editorinterface-method-set-plugin-enabled)

Sets the enabled status of a plugin. The plugin name is the same as its directory name.

---

void **stop\_playing\_scene**() [🔗](#class-editorinterface-method-stop-playing-scene)

Stops the scene that is currently playing.