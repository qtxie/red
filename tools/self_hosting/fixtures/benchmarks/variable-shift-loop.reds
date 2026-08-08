Red/System [
	Title: "Generated-code variable-count integer shift benchmark"
]

shift-variable: func [
	value [integer!]
	count [integer!]
	return: [integer!]
][
	value << count
]

hot-variable-shift-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + (shift-variable index (index and 31))
		index: index + 1
	]
	checksum
]

print-line hot-variable-shift-loop 20000000
