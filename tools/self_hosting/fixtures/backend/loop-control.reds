Red/System [
	Title: "O2 counted, until, break, and continue control-flow coverage"
]

counted-iterations: func [
	count [integer!]
	return: [integer!]
	/local total
][
	total: 0
	loop count [total: total + 1]
	total
]

counted-break-continue: func [
	count [integer!]
	return: [integer!]
	/local i total
][
	i: 0
	total: 0
	loop count [
		i: i + 1
		if i = 2 [continue]
		if i = 5 [break]
		total: total + i
	]
	total
]

until-count: func [
	limit [integer!]
	return: [integer!]
	/local i
][
	i: 0
	until [
		i: i + 1
		i >= limit
	]
	i
]

until-continue-break: func [
	return: [integer!]
	/local i
][
	i: 0
	until [
		i: i + 1
		if i < 3 [continue]
		if i = 5 [break]
		false
	]
	i
]

while-break-continue: func [
	count [integer!]
	return: [integer!]
	/local i total
][
	i: 0
	total: 0
	while [i < count][
		i: i + 1
		if i = 2 [continue]
		if i = 5 [break]
		total: total + i
	]
	total
]

print-line counted-iterations 5
print-line counted-iterations 0
print-line counted-iterations -2
print-line counted-break-continue 10
print-line counted-break-continue 3
print-line until-count 4
print-line until-count 0
print-line until-continue-break
print-line while-break-continue 10
print-line while-break-continue 3
