Red/System [
	Title: "Generated-code scalar XMM call benchmark"
]

float-step: func [
	value [float!]
	bias [float!]
	scale [float!]
	adjustment [float!]
	return: [float!]
][
	value + bias * scale - adjustment
]

hot-float-call-loop: func [
	iterations [integer!]
	return: [float!]
	/local i value
][
	i: 0
	value: 1.25
	while [i < iterations][
		value: float-step value 0.5 1.00000001 0.5
		i: i + 1
	]
	value
]

print-line hot-float-call-loop 25000000
