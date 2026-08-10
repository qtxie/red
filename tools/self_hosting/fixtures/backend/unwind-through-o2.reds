Red/System [
	Title: "Machine-IR x64 unwind through an O2-selected frame"
]

thrower: func [
	value [integer!]
	return: [integer!]
][
	throw value
]

o2-wrapper: func [
	value [integer!]
	return: [integer!]
	/local left right [integer!]
][
	left: (value + 3) * 5
	right: thrower 7
	left + right
]

system/thrown: 0
catch 7 [o2-wrapper 11]
print-line system/thrown
unless system/thrown = 7 [quit 1]
