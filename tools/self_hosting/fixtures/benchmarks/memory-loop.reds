Red/System [
	Title: "Generated-code frame-memory operand benchmark"
]

hot-memory-loop: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: a + b + c + d + e + f
	while [i < iterations][
		sum: (sum xor e) + f
		i: i + 1
	]
	sum
]

print-line hot-memory-loop 1 2 3 4 5 7 80000000
