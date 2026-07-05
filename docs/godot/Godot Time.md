# Time

**Inherits:** [Object](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object)

A singleton for working with time data.

## Description[](#description "Link to this heading")

The Time singleton allows converting time between various formats and also getting time information from the system.

This class conforms with as many of the ISO 8601 standards as possible. All dates follow the Proleptic Gregorian calendar. As such, the day before `1582-10-15` is `1582-10-14`, not `1582-10-04`. The year before 1 AD (aka 1 BC) is number `0`, with the year before that (2 BC) being `-1`, etc.

Conversion methods assume "the same timezone", and do not handle timezone conversions or DST automatically. Leap seconds are also not handled, they must be done manually if desired. Suffixes such as "Z" are not handled, you need to strip them away manually.

When getting time information from the system, the time can either be in the local timezone or UTC depending on the `utc` parameter. However, the [get\_unix\_time\_from\_system()](#class-time-method-get-unix-time-from-system) method always uses UTC as it returns the seconds passed since the [Unix epoch](https://en.wikipedia.org/wiki/Unix_time).

**Important:** The `_from_system` methods use the system clock that the user can manually set. **Never use** this method for precise time calculation since its results are subject to automatic adjustments by the user or the operating system. **Always use** [get\_ticks\_usec()](#class-time-method-get-ticks-usec) or [get\_ticks\_msec()](#class-time-method-get-ticks-msec) for precise time calculation instead, since they are guaranteed to be monotonic (i.e. never decrease).

## Methods[](#methods "Link to this heading")

---

## Enumerations[](#enumerations "Link to this heading")

enum **Month**: [🔗](#enum-time-month)

[Month](#enum-time-month) **MONTH\_JANUARY** = `1`

The month of January, represented numerically as `01`.

[Month](#enum-time-month) **MONTH\_FEBRUARY** = `2`

The month of February, represented numerically as `02`.

[Month](#enum-time-month) **MONTH\_MARCH** = `3`

The month of March, represented numerically as `03`.

[Month](#enum-time-month) **MONTH\_APRIL** = `4`

The month of April, represented numerically as `04`.

[Month](#enum-time-month) **MONTH\_MAY** = `5`

The month of May, represented numerically as `05`.

[Month](#enum-time-month) **MONTH\_JUNE** = `6`

The month of June, represented numerically as `06`.

[Month](#enum-time-month) **MONTH\_JULY** = `7`

The month of July, represented numerically as `07`.

[Month](#enum-time-month) **MONTH\_AUGUST** = `8`

The month of August, represented numerically as `08`.

[Month](#enum-time-month) **MONTH\_SEPTEMBER** = `9`

The month of September, represented numerically as `09`.

[Month](#enum-time-month) **MONTH\_OCTOBER** = `10`

The month of October, represented numerically as `10`.

[Month](#enum-time-month) **MONTH\_NOVEMBER** = `11`

The month of November, represented numerically as `11`.

[Month](#enum-time-month) **MONTH\_DECEMBER** = `12`

The month of December, represented numerically as `12`.

---

enum **Weekday**: [🔗](#enum-time-weekday)

[Weekday](#enum-time-weekday) **WEEKDAY\_SUNDAY** = `0`

The day of the week Sunday, represented numerically as `0`.

[Weekday](#enum-time-weekday) **WEEKDAY\_MONDAY** = `1`

The day of the week Monday, represented numerically as `1`.

[Weekday](#enum-time-weekday) **WEEKDAY\_TUESDAY** = `2`

The day of the week Tuesday, represented numerically as `2`.

[Weekday](#enum-time-weekday) **WEEKDAY\_WEDNESDAY** = `3`

The day of the week Wednesday, represented numerically as `3`.

[Weekday](#enum-time-weekday) **WEEKDAY\_THURSDAY** = `4`

The day of the week Thursday, represented numerically as `4`.

[Weekday](#enum-time-weekday) **WEEKDAY\_FRIDAY** = `5`

The day of the week Friday, represented numerically as `5`.

[Weekday](#enum-time-weekday) **WEEKDAY\_SATURDAY** = `6`

The day of the week Saturday, represented numerically as `6`.

---

## Method Descriptions[](#method-descriptions "Link to this heading")

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_date\_dict\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-date-dict-from-system)

Returns the current date as a dictionary of keys: `year`, `month`, `day`, and `weekday`.

The returned values are in the system's local time when `utc` is `false`, otherwise they are in UTC.

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_date\_dict\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-date-dict-from-unix-time)

Converts the given Unix timestamp to a dictionary of keys: `year`, `month`, `day`, and `weekday`.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_date\_string\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-date-string-from-system)

Returns the current date as an ISO 8601 date string (YYYY-MM-DD).

The returned values are in the system's local time when `utc` is `false`, otherwise they are in UTC.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_date\_string\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-date-string-from-unix-time)

Converts the given Unix timestamp to an ISO 8601 date string (YYYY-MM-DD).

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_datetime\_dict\_from\_datetime\_string**(datetime: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string), weekday: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) const [🔗](#class-time-method-get-datetime-dict-from-datetime-string)

Converts the given ISO 8601 date and time string (YYYY-MM-DDTHH:MM:SS) to a dictionary of keys: `year`, `month`, `day`, `weekday`, `hour`, `minute`, and `second`.

If `weekday` is `false`, then the `weekday` entry is excluded (the calculation is relatively expensive).

**Note:** Any decimal fraction in the time string will be ignored silently.

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_datetime\_dict\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-datetime-dict-from-system)

Returns the current date as a dictionary of keys: `year`, `month`, `day`, `weekday`, `hour`, `minute`, `second`, and `dst` (Daylight Savings Time).

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_datetime\_dict\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-datetime-dict-from-unix-time)

Converts the given Unix timestamp to a dictionary of keys: `year`, `month`, `day`, `weekday`, `hour`, `minute`, and `second`.

The returned Dictionary's values will be the same as the [get\_datetime\_dict\_from\_system()](#class-time-method-get-datetime-dict-from-system) if the Unix timestamp is the current time, with the exception of Daylight Savings Time as it cannot be determined from the epoch.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_datetime\_string\_from\_datetime\_dict**(datetime: [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary), use\_space: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool)) const [🔗](#class-time-method-get-datetime-string-from-datetime-dict)

Converts the given dictionary of keys to an ISO 8601 date and time string (YYYY-MM-DDTHH:MM:SS).

The given dictionary can be populated with the following keys: `year`, `month`, `day`, `hour`, `minute`, and `second`. Any other entries (including `dst`) are ignored.

If the dictionary is empty, `0` is returned. If some keys are omitted, they default to the equivalent values for the Unix epoch timestamp 0 (1970-01-01 at 00:00:00).

If `use_space` is `true`, the date and time bits are separated by an empty space character instead of the letter T.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_datetime\_string\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false, use\_space: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-datetime-string-from-system)

Returns the current date and time as an ISO 8601 date and time string (YYYY-MM-DDTHH:MM:SS).

The returned values are in the system's local time when `utc` is `false`, otherwise they are in UTC.

If `use_space` is `true`, the date and time bits are separated by an empty space character instead of the letter T.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_datetime\_string\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int), use\_space: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-datetime-string-from-unix-time)

Converts the given Unix timestamp to an ISO 8601 date and time string (YYYY-MM-DDTHH:MM:SS).

If `use_space` is `true`, the date and time bits are separated by an empty space character instead of the letter T.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_offset\_string\_from\_offset\_minutes**(offset\_minutes: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-offset-string-from-offset-minutes)

Converts the given timezone offset in minutes to a timezone offset string. For example, -480 returns "-08:00", 345 returns "+05:45", and 0 returns "+00:00".

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_ticks\_msec**() const [🔗](#class-time-method-get-ticks-msec)

Returns the amount of time passed in milliseconds since the engine started.

Will always be positive or 0 and uses a 64-bit value (it will wrap after roughly 500 million years).

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_ticks\_usec**() const [🔗](#class-time-method-get-ticks-usec)

Returns the amount of time passed in microseconds since the engine started.

Will always be positive or 0 and uses a 64-bit value (it will wrap after roughly half a million years).

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_time\_dict\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-time-dict-from-system)

Returns the current time as a dictionary of keys: `hour`, `minute`, and `second`.

The returned values are in the system's local time when `utc` is `false`, otherwise they are in UTC.

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_time\_dict\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-time-dict-from-unix-time)

Converts the given time to a dictionary of keys: `hour`, `minute`, and `second`.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_time\_string\_from\_system**(utc: [bool](https://docs.godotengine.org/en/stable/classes/class_bool.html#class-bool) = false) const [🔗](#class-time-method-get-time-string-from-system)

Returns the current time as an ISO 8601 time string (HH:MM:SS).

The returned values are in the system's local time when `utc` is `false`, otherwise they are in UTC.

---

[String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string) **get\_time\_string\_from\_unix\_time**(unix\_time\_val: [int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int)) const [🔗](#class-time-method-get-time-string-from-unix-time)

Converts the given Unix timestamp to an ISO 8601 time string (HH:MM:SS).

---

[Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary) **get\_time\_zone\_from\_system**() const [🔗](#class-time-method-get-time-zone-from-system)

Returns the current time zone as a dictionary of keys: `bias` and `name`.

*   `bias` is the offset from UTC in minutes, since not all time zones are multiples of an hour from UTC.
    
*   `name` is the localized name of the time zone, according to the OS locale settings of the current user.
    

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_unix\_time\_from\_datetime\_dict**(datetime: [Dictionary](https://docs.godotengine.org/en/stable/classes/class_dictionary.html#class-dictionary)) const [🔗](#class-time-method-get-unix-time-from-datetime-dict)

Converts a dictionary of time values to a Unix timestamp.

The given dictionary can be populated with the following keys: `year`, `month`, `day`, `hour`, `minute`, and `second`. Any other entries (including `dst`) are ignored.

If the dictionary is empty, `0` is returned. If some keys are omitted, they default to the equivalent values for the Unix epoch timestamp 0 (1970-01-01 at 00:00:00).

You can pass the output from [get\_datetime\_dict\_from\_unix\_time()](#class-time-method-get-datetime-dict-from-unix-time) directly into this function and get the same as what was put in.

**Note:** Unix timestamps are often in UTC. This method does not do any timezone conversion, so the timestamp will be in the same timezone as the given datetime dictionary.

---

[int](https://docs.godotengine.org/en/stable/classes/class_int.html#class-int) **get\_unix\_time\_from\_datetime\_string**(datetime: [String](https://docs.godotengine.org/en/stable/classes/class_string.html#class-string)) const [🔗](#class-time-method-get-unix-time-from-datetime-string)

Converts the given ISO 8601 date and/or time string to a Unix timestamp. The string can contain a date only, a time only, or both.

**Note:** Unix timestamps are often in UTC. This method does not do any timezone conversion, so the timestamp will be in the same timezone as the given datetime string.

**Note:** Any decimal fraction in the time string will be ignored silently.

---

[float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) **get\_unix\_time\_from\_system**() const [🔗](#class-time-method-get-unix-time-from-system)

Returns the current Unix timestamp in seconds based on the system time in UTC. This method is implemented by the operating system and always returns the time in UTC. The Unix timestamp is the number of seconds passed since 1970-01-01 at 00:00:00, the [Unix epoch](https://en.wikipedia.org/wiki/Unix_time).

**Note:** Unlike other methods that use integer timestamps, this method returns the timestamp as a [float](https://docs.godotengine.org/en/stable/classes/class_float.html#class-float) for sub-second precision.