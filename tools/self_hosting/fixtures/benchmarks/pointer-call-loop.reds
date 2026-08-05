Red/System [
	Title: "Generated-code pointer scalar call benchmark"
]

pointer-step: func [
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
][
	value
]

pointer-loop: func [
	iterations [integer!]
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
	/local i
][
	i: 0
	while [i < iterations][
		value: pointer-step value
		i: i + 1
	]
	value
]

value: 1
value-pointer: :value
result-pointer: pointer-loop 40000000 value-pointer
print-line result-pointer/value
