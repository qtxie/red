Red/System [
	Title: "Generated-code values-live-across-calls benchmark"
]

one: func [return: [integer!]][1]
two: func [return: [integer!]][2]

pair: func [return: [integer!]][
	(one) + (two)
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (pair)
		i: i + 1
	]
	sum
]

print-line hot-loop 30000000
