Red/System [
	Title: "Generated-code nested relocation ordering benchmark"
]

global-left: 7
global-right: 11

increment: func [
	value [integer!]
	return: [integer!]
][
	value + 1
]

combine: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left + right
]

nested-call-order: func [
	return: [integer!]
][
	combine global-left (increment global-right)
]

hot-nested-relocation-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index total [integer!]
][
	index: 0
	total: 0
	while [index < iterations][
		total: total + nested-call-order
		index: index + 1
	]
	total
]

print-line hot-nested-relocation-loop 100000000
