Red/System [
	Title: "Generated-code call-heavy O2 benchmark"
]

mix: func [
	a [integer!]
	b [integer!]
	return: [integer!]
][
	a + b * 3
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (mix i (i and 255))
		i: i + 1
	]
	sum
]

print-line hot-loop 80000000
