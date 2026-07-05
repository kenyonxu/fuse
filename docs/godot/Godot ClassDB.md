# ClassDB

**Inherits:** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A class information repository.

## Description[](#description "Link to this heading")

Provides access to metadata stored for every available engine class.

**Note:** Script-defined classes with `class_name` are not part of **ClassDB**, so they will not return reflection data such as a method or property list. However, [GDExtension](https://docs.godotengine.org/en/stable/classes/class_gdextension.html#class-gdextension)\-defined classes *are* part of **ClassDB**, so they will return reflection data.

## Methods[](#methods "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[can\_instantiate](#class-classdb-method-can-instantiate)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[class\_call\_static](#class-classdb-method-class-call-static)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[class\_exists](#class-classdb-method-class-exists)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[APIType](#enum-classdb-apitype)

[class\_get\_api\_type](#class-classdb-method-class-get-api-type)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[class\_get\_enum\_constants](#class-classdb-method-class-get-enum-constants)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), enum: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[class\_get\_enum\_list](#class-classdb-method-class-get-enum-list)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[class\_get\_integer\_constant](#class-classdb-method-class-get-integer-constant)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)

[class\_get\_integer\_constant\_enum](#class-classdb-method-class-get-integer-constant-enum)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[class\_get\_integer\_constant\_list](#class-classdb-method-class-get-integer-constant-list)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)

[class\_get\_method\_argument\_count](#class-classdb-method-class-get-method-argument-count)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\]

[class\_get\_method\_list](#class-classdb-method-class-get-method-list)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[class\_get\_property](#class-classdb-method-class-get-property)(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[class\_get\_property\_default\_value](#class-classdb-method-class-get-property-default-value)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)

[class\_get\_property\_getter](#class-classdb-method-class-get-property-getter)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\]

[class\_get\_property\_list](#class-classdb-method-class-get-property-list)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)

[class\_get\_property\_setter](#class-classdb-method-class-get-property-setter)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname))

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)

[class\_get\_signal](#class-classdb-method-class-get-signal)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), signal: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\]

[class\_get\_signal\_list](#class-classdb-method-class-get-signal-list)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[class\_has\_enum](#class-classdb-method-class-has-enum)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[class\_has\_integer\_constant](#class-classdb-method-class-has-integer-constant)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[class\_has\_method](#class-classdb-method-class-has-method)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[class\_has\_signal](#class-classdb-method-class-has-signal)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), signal: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error)

[class\_set\_property](#class-classdb-method-class-set-property)(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[get\_class\_list](#class-classdb-method-get-class-list)() const

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray)

[get\_inheriters\_from\_class](#class-classdb-method-get-inheriters-from-class)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)

[get\_parent\_class](#class-classdb-method-get-parent-class)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)

[instantiate](#class-classdb-method-instantiate)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_class\_enabled](#class-classdb-method-is-class-enabled)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_class\_enum\_bitfield](#class-classdb-method-is-class-enum-bitfield)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), enum: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)

[is\_parent\_class](#class-classdb-method-is-parent-class)(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), inherits: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const

---

## Enumerations[](#enumerations "Link to this heading")

enum **APIType**: [🔗](#enum-classdb-apitype)

[APIType](#enum-classdb-apitype) **API\_CORE** = `0`

Native Core class type.

[APIType](#enum-classdb-apitype) **API\_EDITOR** = `1`

Native Editor class type.

[APIType](#enum-classdb-apitype) **API\_EXTENSION** = `2`

GDExtension class type.

[APIType](#enum-classdb-apitype) **API\_EDITOR\_EXTENSION** = `3`

GDExtension Editor class type.

[APIType](#enum-classdb-apitype) **API\_NONE** = `4`

Unknown class type.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **can\_instantiate**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-can-instantiate)

Returns `true` if objects can be instantiated from the specified `class`, otherwise returns `false`.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **class\_call\_static**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), ...) vararg [🔗](#class-classdb-method-class-call-static)

Calls a static method on a class.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **class\_exists**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-exists)

Returns whether the specified `class` is available or not.

---

[APIType](#enum-classdb-apitype) **class\_get\_api\_type**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-get-api-type)

Returns the API type of the specified `class`.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **class\_get\_enum\_constants**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), enum: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-enum-constants)

Returns an array with all the keys in `enum` of `class` or its ancestry.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **class\_get\_enum\_list**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-enum-list)

Returns an array with all the enums of `class` or its ancestry.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **class\_get\_integer\_constant**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-get-integer-constant)

Returns the value of the integer constant `name` of `class` or its ancestry. Always returns 0 when the constant could not be found.

---

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **class\_get\_integer\_constant\_enum**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-integer-constant-enum)

Returns which enum the integer constant `name` of `class` or its ancestry belongs to.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **class\_get\_integer\_constant\_list**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-integer-constant-list)

Returns an array with the names all the integer constants of `class` or its ancestry.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **class\_get\_method\_argument\_count**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-method-argument-count)

Returns the number of arguments of the method `method` of `class` or its ancestry if `no_inheritance` is `false`.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\] **class\_get\_method\_list**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-method-list)

Returns an array with all the methods of `class` or its ancestry if `no_inheritance` is `false`. Every element of the array is a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) with the following keys: `args`, `default_args`, `flags`, `id`, `name`, `return: (class_name, hint, hint_string, name, type, usage)`.

**Note:** In exported release builds the debug info is not available, so the returned dictionaries will contain only method names.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **class\_get\_property**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-get-property)

Returns the value of `property` of `object` or its ancestry.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **class\_get\_property\_default\_value**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-get-property-default-value)

Returns the default value of `property` of `class` or its ancestor classes.

---

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **class\_get\_property\_getter**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-classdb-method-class-get-property-getter)

Returns the getter method name of `property` of `class`.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\] **class\_get\_property\_list**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-property-list)

Returns an array with all the properties of `class` or its ancestry if `no_inheritance` is `false`.

---

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **class\_get\_property\_setter**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) [🔗](#class-classdb-method-class-get-property-setter)

Returns the setter method name of `property` of `class`.

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **class\_get\_signal**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), signal: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-get-signal)

Returns the `signal` data of `class` or its ancestry. The returned value is a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) with the following keys: `args`, `default_args`, `flags`, `id`, `name`, `return: (class_name, hint, hint_string, name, type, usage)`.

---

[Array](https://docs.godotengine.org/en/stable/classes/class_array.html#class-array)\[[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)\] **class\_get\_signal\_list**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-get-signal-list)

Returns an array with all the signals of `class` or its ancestry if `no_inheritance` is `false`. Every element of the array is a [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) as described in [class\_get\_signal()](#class-classdb-method-class-get-signal).

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **class\_has\_enum**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-has-enum)

Returns whether `class` or its ancestry has an enum called `name` or not.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **class\_has\_integer\_constant**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), name: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-has-integer-constant)

Returns whether `class` or its ancestry has an integer constant called `name` or not.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **class\_has\_method**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), method: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-class-has-method)

Returns whether `class` (or its ancestry if `no_inheritance` is `false`) has a method called `method` or not.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **class\_has\_signal**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), signal: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-class-has-signal)

Returns whether `class` or its ancestry has a signal called `signal` or not.

---

[Error](https://docs.godotengine.org/en/stable/classes/class_%40globalscope.html#enum-globalscope-error) **class\_set\_property**(object: [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object), property: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), value: [Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant)) const [🔗](#class-classdb-method-class-set-property)

Sets `property` value of `object` to `value`.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **get\_class\_list**() const [🔗](#class-classdb-method-get-class-list)

Returns the names of all engine classes available.

**Note:** Script-defined classes with `class_name` are not included in this list. Use [ProjectSettings.get\_global\_class\_list()](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-method-get-global-class-list) to get a list of script-defined classes instead.

---

[PackedStringArray](https://docs.godotengine.org/en/stable/classes/class_packedstringarray.html#class-packedstringarray) **get\_inheriters\_from\_class**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-get-inheriters-from-class)

Returns the names of all engine classes that directly or indirectly inherit from `class`.

---

[StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname) **get\_parent\_class**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-get-parent-class)

Returns the parent class of `class`.

---

[Variant](https://docs.godotengine.org/en/stable/classes/class_variant.html#class-variant) **instantiate**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-instantiate)

Creates an instance of `class`.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_class\_enabled**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-is-class-enabled)

Returns whether this `class` is enabled or not.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_class\_enum\_bitfield**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), enum: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), no\_inheritance: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-classdb-method-is-class-enum-bitfield)

Returns whether `class` (or its ancestor classes if `no_inheritance` is `false`) has an enum called `enum` that is a bitfield.

---

[bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) **is\_parent\_class**(class: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname), inherits: [StringName](https://docs.godotengine.org/en/stable/classes/class_stringname.html#class-stringname)) const [🔗](#class-classdb-method-is-parent-class)

Returns whether `inherits` is an ancestor of `class` or not.