Red/System [
	Title: "Generated-code register argument across call benchmark"
]

one: func [return: [integer!]][1]

consume-two: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left + right
]

nested: func [
	value [integer!]
	return: [integer!]
][
	consume-two value (one)
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (nested 1)
		i: i + 1
	]
	sum
]

print-line hot-loop 30000000
