Red/System [
	Title: "Generated-code direct-call loop benchmark"
]

add-two: func [
	a [integer!]
	b [integer!]
	return: [integer!]
][
	a + b
]

hot-call-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i dummy
][
	i: 0
	dummy: 0
	while [i < iterations][
		dummy: add-two i (i + 1)
		i: i - (-1)
	]
	dummy
]

print-line hot-call-loop 20000000
