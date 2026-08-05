Red/System [
	Title: "Generated-code nested scalar call benchmark"
]

one: func [return: [integer!]][1]

increment: func [
	value [integer!]
	return: [integer!]
][
	value + 1
]

nested: func [return: [integer!]][
	increment (one)
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (nested)
		i: i + 1
	]
	sum
]

print-line hot-loop 30000000
