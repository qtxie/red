Red/System [
	Title: "Generated-code floating comparison bitcast call-loop benchmark"
]

less-f64-integer: func [
	a [float!]
	b [float!]
	return: [integer!]
][
	as integer! a < b
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
		count: count + less-f64-integer left right
		index: index + 1
	]
	count
]

print-line hot-float-compare-loop 100000000
