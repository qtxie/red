Red/System [
	Title: "Generated-code short-circuit comparison benchmark"
]

any-word-logic?: func [
	type [integer!]
	return: [logic!]
][
	any [
		type = 15
		type = 18
		type = 16
		type = 17
		type = 19
		type = 20
	]
]

hot-short-circuit-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		if any-word-logic? 15 [checksum: checksum + 1]
		if any-word-logic? 17 [checksum: checksum + 1]
		if any-word-logic? 20 [checksum: checksum + 1]
		if any-word-logic? 14 [checksum: checksum + 1]
		index: index + 1
	]
	checksum
]

print-line hot-short-circuit-loop 20000000
