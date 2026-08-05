Red/System [
	Title: "O2 pointer root metadata across a nested call"
]

one: func [return: [integer!]][1]

consume-pointer: func [
	value [pointer! [integer!]]
	ignored [integer!]
	return: [pointer! [integer!]]
][
	value
]

pointer-across-call: func [
	value [pointer! [integer!]]
	return: [pointer! [integer!]]
][
	consume-pointer value (one)
]

value: 2468
result: pointer-across-call :value
print-line result/value
