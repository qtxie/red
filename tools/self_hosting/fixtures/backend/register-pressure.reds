Red/System [
	Title: "O2 typed-register spill coverage"
]

integer-pressure: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	g [integer!]
	h [integer!]
	i [integer!]
	return: [integer!]
][
	a + (b + (c + (d + (e + (f + (g + (h + i)))))))
]

float-pressure: func [
	a [float!]
	b [float!]
	c [float!]
	d [float!]
	e [float!]
	f [float!]
	g [float!]
	h [float!]
	return: [float!]
][
	a + (b + (c + (d + (e + (f + (g + h))))))
]

integer-spill-pressure: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	g [integer!]
	h [integer!]
	return: [integer!]
][
	(a - b - c - d - e - f - g - h) + (a + b + c + d + e + f + g + h)
]

float-spill-pressure: func [
	a [float!]
	b [float!]
	c [float!]
	d [float!]
	e [float!]
	f [float!]
	g [float!]
	return: [float!]
][
	(a - b - c - d - e - f - g) + (a + b + c + d + e + f + g)
]

print-line integer-pressure 1 2 3 4 5 6 7 8 9
print-line float-pressure 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0
print-line integer-spill-pressure 1 2 3 4 5 6 7 8
print-line float-spill-pressure 1.0 2.0 3.0 4.0 5.0 6.0 7.0
