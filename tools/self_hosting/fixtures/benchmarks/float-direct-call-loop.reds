Red/System [
	Title: "Generated-code direct scalar XMM call benchmark"
]

float-step: func [
	value [float!]
	adjustment [float!]
	return: [float!]
][
	value + adjustment
]

float-wrapper: func [
	value [float!]
	factor [float!]
	adjustment [float!]
	return: [float!]
][
	float-step (value * factor) adjustment
]

i: 0
value: 1.25
while [i < 25000000][
	value: float-wrapper value 1.00000001 0.0
	i: i + 1
]

print-line value
