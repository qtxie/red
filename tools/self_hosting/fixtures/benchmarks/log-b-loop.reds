Red/System [
	Title: "Generated-code log-b and variable-shift benchmark"
]

next-power-of-two: func [
	value [integer!]
	return: [integer!]
	/local result [integer!]
][
	result: 1 << log-b value
	if value <> result [result: result << 1]
	result
]

hot-log-b-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum value
][
	index: 0
	checksum: 0
	while [index < iterations][
		value: (index and 0000FFFFh) + 1
		checksum: checksum + next-power-of-two value
		index: index + 1
	]
	checksum
]

print-line hot-log-b-loop 20000000
