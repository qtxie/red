Red/System [
	Title: "Generated-code floating-point comparison call-loop benchmark"
]

less-f64?: func [
	a [float!]
	b [float!]
	return: [logic!]
][
	a < b
]

hot-float-compare-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index count left right
][
	index: 0
	count: 0
	left: 1.0
	right: 2.0
	while [index < iterations][
		if less-f64? left right [count: count + 1]
		index: index + 1
	]
	count
]

print-line hot-float-compare-loop 100000000
