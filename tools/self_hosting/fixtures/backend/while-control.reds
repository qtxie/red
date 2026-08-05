Red/System [
	Title: "O2 while control-flow semantic coverage"
]

count-lt: func [
	return: [integer!]
	/local i count
][
	i: -3
	count: 0
	while [i < 4][
		count: count + 1
		i: i + 1
	]
	count
]

count-le: func [
	return: [integer!]
	/local i count
][
	i: -2
	count: 0
	while [i <= 2][
		count: count + 1
		i: i + 1
	]
	count
]

count-gt: func [
	return: [integer!]
	/local i count
][
	i: 3
	count: 0
	while [i > -2][
		count: count + 1
		i: i - 1
	]
	count
]

count-ge: func [
	return: [integer!]
	/local i count
][
	i: 2
	count: 0
	while [i >= -2][
		count: count + 1
		i: i - 1
	]
	count
]

count-ne: func [
	return: [integer!]
	/local i count
][
	i: 0
	count: 0
	while [i <> 5][
		count: count + 1
		i: i + 1
	]
	count
]

count-eq: func [
	return: [integer!]
	/local i count
][
	i: 0
	count: 0
	while [i = 0][
		count: count + 1
		i: 1
	]
	count
]

nested-count: func [
	return: [integer!]
	/local i j sum
][
	i: 0
	sum: 0
	while [i < 4][
		j: 0
		while [j < 3][
			sum: sum + ((i * 10) + j)
			j: j + 1
		]
		i: i + 1
	]
	sum
]

conditional-count: func [
	return: [integer!]
	/local i sum
][
	i: 0
	sum: 0
	while [i < 10][
		if (i and 1) = 0 [sum: sum + i]
		i: i + 1
	]
	sum
]

constant-false: func [
	return: [integer!]
	/local result
][
	result: 1
	if 3 = 4 [result: 99]
	result
]

constant-true: func [
	return: [integer!]
	/local result
][
	result: 1
	if 4 = 4 [result: 99]
	result
]

print-line count-lt
print-line count-le
print-line count-gt
print-line count-ge
print-line count-ne
print-line count-eq
print-line nested-count
print-line conditional-count
print-line constant-false
print-line constant-true
