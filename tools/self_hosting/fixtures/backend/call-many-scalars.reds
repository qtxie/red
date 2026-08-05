Red/System [
	Title: "O2 scalar stack-argument coverage"
]

sum-six: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	return: [integer!]
][
	a + b + c + d + e + f
]

call-sum-six: func [
	x [integer!]
	return: [integer!]
][
	sum-six x (x + 1) (x + 2) (x + 3) (x + 4) (x + 5)
]

last-of-five: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	value [float!]
	return: [float!]
][
	value
]

call-last-of-five: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	value [float!]
	return: [float!]
][
	last-of-five a b c d value
]

print-line call-sum-six 10
print-line call-last-of-five 1 2 3 4 6.25
