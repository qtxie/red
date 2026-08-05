Red/System [
	Title: "Generated-code straight-line O2 fixture"
]

mix: func [
	a [integer!]
	b [integer!]
	return: [integer!]
	/local c [integer!] d [integer!]
][
	c: a + b
	d: c + 0
	d: d * 3
	d
]

print-line mix 7 5
