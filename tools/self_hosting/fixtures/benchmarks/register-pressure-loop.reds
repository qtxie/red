Red/System [
	Title: "Generated-code register-pressure O2 benchmark"
]

integer-pressure: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	g [integer!]
	h [integer!]
	i [integer!]
	return: [integer!]
][
	a + (b + (c + (d + (e + (f + (g + (h + i)))))))
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index total
][
	index: 0
	total: 0
	while [index < iterations][
		total: total + (integer-pressure index 2 3 4 5 6 7 8 9)
		index: index + 1
	]
	total
]

print-line hot-loop 40000000
