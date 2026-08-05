Red/System [
	Title: "Generated-code six-argument call benchmark"
]

mix-six: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	return: [integer!]
][
	a + b + c + d + e + f
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (mix-six i 1 2 3 4 5)
		i: i + 1
	]
	sum
]

print-line hot-loop 40000000
