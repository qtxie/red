Red/System [
	Title: "O2 direct native call coverage"
]

add-two: func [
	a [integer!]
	b [integer!]
	return: [integer!]
][
	a + b
]

call-add-two: func [
	x [integer!]
	y [integer!]
	return: [integer!]
][
	add-two (x + 1) (y * 2)
]

print-line call-add-two 3 4
