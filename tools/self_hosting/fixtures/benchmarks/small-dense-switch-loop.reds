Red/System [
	Title: "Generated-code small dense switch benchmark"
]

small-dense-switch: func [
	value [integer!]
	return: [integer!]
][
	switch value [
		2 [16]
		3 [20]
		4 [32]
		5 [48]
		6 [64]
		default [0]
	]
]

hot-small-switch-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + (small-dense-switch 2)
		checksum: checksum + (small-dense-switch 4)
		checksum: checksum + (small-dense-switch 6)
		checksum: checksum + (small-dense-switch 7)
		index: index + 1
	]
	checksum
]

print-line hot-small-switch-loop 10000000
