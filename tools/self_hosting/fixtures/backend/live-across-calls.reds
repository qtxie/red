Red/System [
	Title: "O2 values live across native calls"
]

one: func [return: [integer!]][1]
two: func [return: [integer!]][2]
increment: func [value [integer!] return: [integer!]][value + 1]
consume-two: func [left [integer!] right [integer!] return: [integer!]][left + right]

atomic-state: 0

atomic-store-value: func [value [integer!] return: [integer!]][
	system/atomic/store :atomic-state value
	value
]

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

two-values-across-atomic-call: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left + (right + atomic-store-value 0)
]

print-line add-after-call 41
print-line add-two-calls
print-line nested-call
print-line register-argument-across-call 41
print-line two-values-across-atomic-call 20 30
