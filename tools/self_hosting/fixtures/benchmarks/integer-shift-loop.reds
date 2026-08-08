Red/System [
	Title: "Generated-code constant-count integer shift benchmark"
]

mix-hash: func [
	value [integer!]
	return: [integer!]
][
	value: value xor (value -** 16)
	value: value * 85EBCA6Bh
	value: value xor (value -** 13)
	value: value * C2B2AE35h
	value xor (value -** 16)
]

hot-shift-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum xor mix-hash index
		index: index + 1
	]
	checksum
]

print-line hot-shift-loop 20000000
