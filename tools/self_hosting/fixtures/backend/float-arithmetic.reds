Red/System [
	Title: "O2 scalar XMM arithmetic coverage"
]

float64-chain: func [
	a [float!]
	b [float!]
	c [float!]
	d [float!]
	return: [float!]
][
	a + b * c - d
]

float32-chain: func [
	a [float32!]
	b [float32!]
	c [float32!]
	return: [float32!]
][
	a * b + c
]

float64-local: func [
	a [float!]
	b [float!]
	return: [float!]
	/local sum
][
	sum: a + b
	sum * b
]

float64-frame: func [
	condition [integer!]
	a [float!]
	b [float!]
	return: [float!]
	/local result
][
	result: a
	if condition > 0 [result: result + b]
	result * b
]

float64-add: func [
	a [float!]
	b [float!]
	return: [float!]
][
	a + b
]

float64-call: func [
	a [float!]
	b [float!]
	c [float!]
	return: [float!]
][
	float64-add (a * b) c
]

float32-add: func [
	a [float32!]
	b [float32!]
	return: [float32!]
][
	a + b
]

float32-call: func [
	a [float32!]
	b [float32!]
	return: [float32!]
][
	float32-add a b
]

mixed-value: func [
	tag [integer!]
	value [float!]
	return: [float!]
][
	value
]

mixed-call: func [
	tag [integer!]
	value [float!]
	adjustment [float!]
	return: [float!]
][
	mixed-value tag (value + adjustment)
]

print-line float64-chain 1.5 2.0 3.0 4.0
print-line float32-chain 1.5 2.0 3.0
print-line float64-local 1.5 2.0
print-line float64-frame 1 1.5 2.0
print-line float64-frame 0 1.5 2.0
print-line float64-call 1.5 2.0 4.0
print-line float32-call 1.5 2.5
print-line mixed-call 3 2.5 1.5
