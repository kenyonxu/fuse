# Inspector plugins

The inspector dock allows you to create custom widgets to edit properties through plugins. This can be beneficial when working with custom datatypes and resources, although you can use the feature to change the inspector widgets for built-in types. You can design custom controls for specific properties, entire objects, and even separate controls associated with particular datatypes.

This guide explains how to use the [EditorInspectorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorinspectorplugin.html#class-editorinspectorplugin) and [EditorProperty](https://docs.godotengine.org/en/stable/classes/class_editorproperty.html#class-editorproperty) classes to create a custom interface for integers, replacing the default behavior with a button that generates random values between 0 and 99.

![../../../_images/inspector_plugin_example.png](https://docs.godotengine.org/en/stable/_images/inspector_plugin_example.png)

The default behavior on the left and the end result on the right.[](#id1 "Link to this image")

## Setting up your plugin[](#setting-up-your-plugin "Link to this heading")

Create a new empty plugin to get started.

Let's assume you've called your plugin folder `my_inspector_plugin`. If so, you should end up with a new `addons/my_inspector_plugin` folder that contains two files: `plugin.cfg` and `plugin.gd`.

As before, `plugin.gd` is a script extending [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html#class-editorplugin) and you need to introduce new code for its `_enter_tree` and `_exit_tree` methods. To set up your inspector plugin, you must load its script, then create and add the instance by calling `add_inspector_plugin()`. If the plugin is disabled, you should remove the instance you have added by calling `remove_inspector_plugin()`.

Note

Here, you are loading a script and not a packed scene. Therefore you should use `new()` instead of `instantiate()`.

\# plugin.gd
@tool
extends EditorPlugin

var plugin

func \_enter\_tree():
	plugin \= preload("res://addons/my\_inspector\_plugin/my\_inspector\_plugin.gd").new()
	add\_inspector\_plugin(plugin)

func \_exit\_tree():
	remove\_inspector\_plugin(plugin)

## Interacting with the inspector[](#interacting-with-the-inspector "Link to this heading")

To interact with the inspector dock, your `my_inspector_plugin.gd` script must extend the [EditorInspectorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorinspectorplugin.html#class-editorinspectorplugin) class. This class provides several virtual methods that affect how the inspector handles properties.

To have any effect at all, the script must implement the `_can_handle()` method. This function is called for each edited [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object) and must return `true` if this plugin should handle the object or its properties.

Note

This includes any [Resource](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource) attached to the object.

You can implement four other methods to add controls to the inspector at specific positions. The `_parse_begin()` and `_parse_end()` methods are called only once at the beginning and the end of parsing for each object, respectively. They can add controls at the top or bottom of the inspector layout by calling `add_custom_control()`.

As the editor parses the object, it calls the `_parse_category()` and `_parse_property()` methods. There, in addition to `add_custom_control()`, you can call both `add_property_editor()` and `add_property_editor_for_multiple_properties()`. Use these last two methods to specifically add [EditorProperty](https://docs.godotengine.org/en/stable/classes/class_editorproperty.html#class-editorproperty)\-based controls.

\# my\_inspector\_plugin.gd
extends EditorInspectorPlugin

var RandomIntEditor \= preload("res://addons/my\_inspector\_plugin/random\_int\_editor.gd")

func \_can\_handle(object):
	\# We support all objects in this example.
	return true

func \_parse\_property(object, type, name, hint\_type, hint\_string, usage\_flags, wide):
	\# We handle properties of type integer.
	if type \== TYPE\_INT:
		\# Create an instance of the custom property editor and register
		\# it to a specific property path.
		add\_property\_editor(name, RandomIntEditor.new())
		\# Inform the editor to remove the default property editor for
		\# this property type.
		return true
	else:
		return false

## Adding an interface to edit properties[](#adding-an-interface-to-edit-properties "Link to this heading")

The [EditorProperty](https://docs.godotengine.org/en/stable/classes/class_editorproperty.html#class-editorproperty) class is a special type of [Control](https://docs.godotengine.org/en/stable/classes/class_control.html#class-control) that can interact with the inspector dock's edited objects. It doesn't display anything but can house any other control nodes, including complex scenes.

There are three essential parts to the script extending [EditorProperty](https://docs.godotengine.org/en/stable/classes/class_editorproperty.html#class-editorproperty):

1.  You must define the `_init()` method to set up the control nodes' structure.
    
2.  You should implement the `_update_property()` to handle changes to the data from the outside.
    
3.  A signal must be emitted at some point to inform the inspector that the control has changed the property using `emit_changed`.
    

You can display your custom widget in two ways. Use just the default `add_child()` method to display it to the right of the property name, and use `add_child()` followed by `set_bottom_editor()` to position it below the name.

\# random\_int\_editor.gd
extends EditorProperty

\# The main control for editing the property.
var property\_control \= Button.new()
\# An internal value of the property.
var current\_value \= 0
\# A guard against internal changes when the property is updated.
var updating \= false

func \_init():
	\# Add the control as a direct child of EditorProperty node.
	add\_child(property\_control)
	\# Make sure the control is able to retain the focus.
	add\_focusable(property\_control)
	\# Setup the initial state and connect to the signal to track changes.
	refresh\_control\_text()
	property\_control.pressed.connect(\_on\_button\_pressed)

func \_on\_button\_pressed():
	\# Ignore the signal if the property is currently being updated.
	if (updating):
		return

	\# Generate a new random integer between 0 and 99.
	current\_value \= randi() % 100
	refresh\_control\_text()
	emit\_changed(get\_edited\_property(), current\_value)

func \_update\_property():
	\# Read the current value from the property.
	var new\_value \= get\_edited\_object()\[get\_edited\_property()\]
	if (new\_value \== current\_value):
		return

	\# Update the control with the new value.
	updating \= true
	current\_value \= new\_value
	refresh\_control\_text()
	updating \= false

func refresh\_control\_text():
	property\_control.text \= "Value: " + str(current\_value)

Using the example code above you should be able to make a custom widget that replaces the default [SpinBox](https://docs.godotengine.org/en/stable/classes/class_spinbox.html#class-spinbox) control for integers with a [Button](https://docs.godotengine.org/en/stable/classes/class_button.html#class-button) that generates random values.