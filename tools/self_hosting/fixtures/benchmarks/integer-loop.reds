Red/System [
	Title: "Generated-code integer loop benchmark"
]

hot-loop: func [
	iterations [integer!]
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < iterations][
		sum: sum + (i and 1023)
		i: i + 1
	]
	sum
]

print-line hot-loop 80000000
