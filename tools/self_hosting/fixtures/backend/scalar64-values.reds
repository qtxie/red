Red/System [
	Title: "O2 64-bit scalar transport coverage"
]

pointer-identity: func [
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
][
	value
]

pointer-call: func [
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
][
	pointer-identity value
]

i64-identity: func [
	value [int64!]
	return: [int64!]
][
	value
]

value: 12345
value-pointer: :value
result-pointer: pointer-call value-pointer
print-line result-pointer/value
value: -9876
result-pointer: pointer-call value-pointer
print-line result-pointer/value
