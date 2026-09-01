extends Node

func _ready():
	print("=== Scope Variable System Basic Test ===")
	test_basic_operations()
	test_scope_registration()
	test_scope_lookup()
	print("=== All Tests Passed ===")

func test_basic_operations():
	print("Test: Basic Operations")
	var container = ScopeVariableContainer.new()
	container.scope_id = "test_scope"

	# Test set and get
	container.set_variable("test_var", 42)
	assert(container.get_variable("test_var") == 42, "Set/Get failed")

	# Test has_variable
	assert(container.has_variable("test_var") == true, "has_variable failed")

	# Test remove
	container.remove_variable("test_var")
	assert(container.has_variable("test_var") == false, "remove failed")

	print("  ✓ Basic operations passed")

func test_scope_registration():
	print("Test: Scope Registration")
	var manager = ScopeVariableManager.get_instance()

	var container1 = ScopeVariableContainer.new()
	container1.scope_id = "scope_1"
	add_child(container1)

	await get_tree().process_frame

	assert(manager.get_scope_by_id("scope_1") == container1, "Registration failed")

	container1.queue_free()
	await get_tree().process_frame

	assert(manager.get_scope_by_id("scope_1") == null, "Unregistration failed")

	print("  ✓ Registration passed")

func test_scope_lookup():
	print("Test: Scope Lookup")
	var manager = ScopeVariableManager.get_instance()

	var parent = ScopeVariableContainer.new()
	parent.scope_id = "parent_scope"
	add_child(parent)

	await get_tree().process_frame

	var child = Node.new()
	parent.add_child(child)

	var found = manager.find_nearest_scope(child)
	assert(found == parent, "Lookup failed")

	child.queue_free()
	parent.queue_free()
	await get_tree().process_frame

	print("  ✓ Lookup passed")
