Red/System [
	Title: "Machine-IR x64 C variadic call fixture"
]

c-variadic-sink: func [
	[cdecl variadic]
	return: [integer!]
][
	1
]

call-c-variadic: func [
	tag [integer!]
	value [float!]
	return: [integer!]
][
	c-variadic-sink [tag value]
]

format-mixed: func [
	buffer [c-string!]
	format [c-string!]
	a [integer!]
	b [float!]
	c [integer!]
	return: [integer!]
][
	sprintf [buffer format a b c]
]

format-nine-floats: func [
	buffer [c-string!]
	format [c-string!]
	a [float!]
	b [float!]
	c [float!]
	d [float!]
	e [float!]
	f [float!]
	g [float!]
	h [float!]
	i [float!]
	return: [integer!]
][
	sprintf [buffer format a b c d e f g h i]
]

buffer: as c-string! allocate 256
print-line call-c-variadic 7 1.5
format-mixed buffer "%d %.1f %d" 7 1.5 9
print-line buffer
format-nine-floats buffer "%.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f"
	1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0
print-line buffer
