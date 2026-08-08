Red/System [
	Title: "O2 casted call argument-order regression"
]

qualified: context [
	pair: func [
		[cdecl]
		left [integer!]
		right [integer!]
		return: [integer!]
	][
		(left * 100) + right
	]
]

cast-pair: func [
	left [integer!]
	right [integer!]
	return: [integer!]
	/local result
][
	result: as integer! qualified/pair left right
	result
]

print-line cast-pair 1 2
