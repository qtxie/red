Red/System [
	Title: "Generated-code qualified-symbol call benchmark"
]

qualified: context [
	base: 1
	add: func [
		value [integer!]
		return: [integer!]
	][
		value + base
	]
]

call-qualified: func [
	value [integer!]
	return: [integer!]
][
	qualified/add value
]

hot-qualified-call-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + call-qualified 0
		index: index + 1
	]
	checksum
]

print-line hot-qualified-call-loop 20000000
