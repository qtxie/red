Red/System [
	Title: "Generated-code RIP-relative global memory benchmark"
]

global-total: 0

hot-global-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index
][
	index: 0
	while [index < iterations][
		global-total: global-total + 1
		index: index + 1
	]
	global-total
]

print-line hot-global-loop 500000000
