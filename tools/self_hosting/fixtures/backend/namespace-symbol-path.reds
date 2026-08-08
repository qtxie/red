Red/System [
	Title: "O2 namespace-symbol path fixture"
]

qualified: context [
	base: 40

	add: func [
		value [integer!]
		return: [integer!]
	][
		value + base
	]
]

call-qualified: func [
	value [integer!]
	return: [integer!]
][
	qualified/add value
]

load-qualified: func [return: [integer!]][
	qualified/base
]

read-pointer: func [
	value [pointer! [integer!]]
	return: [integer!]
][
	value/value
]

box: 7
print-line call-qualified 2
print-line load-qualified
print-line read-pointer :box
