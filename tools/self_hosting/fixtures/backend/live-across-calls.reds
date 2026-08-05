Red/System [
	Title: "O2 values live across native calls"
]

one: func [return: [integer!]][1]
two: func [return: [integer!]][2]
increment: func [value [integer!] return: [integer!]][value + 1]
consume-two: func [left [integer!] right [integer!] return: [integer!]][left + right]

add-after-call: func [
	value [integer!]
	return: [integer!]
][
	value + (one)
]

add-two-calls: func [return: [integer!]][
	(one) + (two)
]

nested-call: func [return: [integer!]][
	increment (one)
]

register-argument-across-call: func [
	value [integer!]
	return: [integer!]
][
	consume-two value (one)
]

print-line add-after-call 41
print-line add-two-calls
print-line nested-call
print-line register-argument-across-call 41
