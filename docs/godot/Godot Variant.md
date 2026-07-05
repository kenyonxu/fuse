# Variant

The most important data type in Godot.

## Description[](#description "Link to this heading")

In computer programming, a Variant class is a class that is designed to store a variety of other types. Dynamic programming languages like PHP, Lua, JavaScript and GDScript like to use them to store variables' data on the backend. With these Variants, properties are able to change value types freely.

var foo \= 2 \# foo is dynamically an integer
foo \= "Now foo is a string!"
foo \= RefCounted.new() \# foo is an Object
var bar: int \= 2 \# bar is a statically typed integer.
\# bar = "Uh oh! I can't make statically typed variables become a different type!"

Godot tracks all scripting API variables within Variants. Without even realizing it, you use Variants all the time. When a particular language enforces its own rules for keeping data typed, then that language is applying its own custom logic over the base Variant scripting API.

*   GDScript automatically wrap values in them. It keeps all data in plain Variants by default and then optionally enforces custom static typing rules on variable types.
    
*   C# is statically typed, but uses its own implementation of the Variant type in place of Godot's **Variant** class when it needs to represent a dynamic value. C# Variant can be assigned any compatible type implicitly but converting requires an explicit cast.
    

The global [@GlobalScope.typeof()](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#class-globalscope-method-typeof) function returns the enumerated value of the Variant type stored in the current variable (see [Variant.Type](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-variant-type)).

var foo \= 2
match typeof(foo):
	TYPE\_NIL:
		print("foo is null")
	TYPE\_INT:
		print("foo is an integer")
	TYPE\_OBJECT:
		\# Note that Objects are their own special category.
		\# To get the name of the underlying Object type, you need the \`get\_class()\` method.
		print("foo is a(n) %s" % foo.get\_class()) \# inject the class name into a formatted string.
		\# Note that this does not get the script's \`class\_name\` global identifier.
		\# If the \`class\_name\` is needed, use \`foo.get\_script().get\_global\_name()\` instead.

A Variant takes up only 20 bytes and can store almost any engine datatype inside of it. Variants are rarely used to hold information for long periods of time. Instead, they are used mainly for communication, editing, serialization and moving data around.

Godot has specifically invested in making its Variant class as flexible as possible; so much so that it is used for a multitude of operations to facilitate communication between all of Godot's systems.

A Variant:

*   Can store almost any datatype.
    
*   Can perform operations between many variants. GDScript uses Variant as its atomic/native datatype.
    
*   Can be hashed, so it can be compared quickly to other variants.
    
*   Can be used to convert safely between datatypes.
    
*   Can be used to abstract calling methods and their arguments. Godot exports all its functions through variants.
    
*   Can be used to defer calls or move data between threads.
    
*   Can be serialized as binary and stored to disk, or transferred via network.
    
*   Can be serialized to text and use it for printing values and editable settings.
    
*   Can work as an exported property, so the editor can edit it universally.
    
*   Can be used for dictionaries, arrays, parsers, etc.
    

**Containers (Array and Dictionary):** Both are implemented using variants. A [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) can match any datatype used as key to any other datatype. An [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) just holds an array of Variants. Of course, a Variant can also hold a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) and an [Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array) inside, making it even more flexible.

Modifications to a container will modify all references to it. A [Mutex](https://docs.godotengine.org/en/stable/classes/class_mutex.html#class-mutex) should be created to lock it if multi-threaded access is desired.

## Tutorials[](#tutorials "Link to this heading")

*   [Variant class introduction](https://docs.godotengine.org/en/stable/engine_details/architecture/variant_class.html)