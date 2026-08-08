Red/System [
	Title: "Generated-code C variadic call benchmark"
]

variadic-value: 1.5

c-variadic-sink: func [
	[cdecl variadic]
	return: [integer!]
][
	1
]

hot-variadic-call-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + c-variadic-sink [
			index variadic-value index index index
		]
		index: index + 1
	]
	checksum
]

print-line hot-variadic-call-loop 20000000
