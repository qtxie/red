Red/System [
	Title: "O2 enum argument and logic result coverage"
]

enum-context: context [
	#enum value! [zero]

	is-zero?: func [
		value [value!]
		return: [logic!]
	][
		zero? value
	]
]

print-line enum-context/is-zero? 0
print-line enum-context/is-zero? 1
