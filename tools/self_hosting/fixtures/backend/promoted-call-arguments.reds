Red/System [
	Title: "O2 promoted-local call argument coverage"
]

sum-three: func [
	a [integer!]
	b [integer!]
	c [integer!]
	return: [integer!]
][
	a + b + c
]

call-with-promoted-size: func [
	size [integer!]
	return: [integer!]
][
	if size = 0 [size: 16]
	sum-three size 1 0
]

print-line call-with-promoted-size 0
print-line call-with-promoted-size 7
