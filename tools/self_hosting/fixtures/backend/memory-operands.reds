Red/System [
	Title: "O2 direct frame-memory operand coverage"
]

combine-six: func [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
	return: [integer!]
	/local result
][
	result: b + c
	result: result + d
	if a = e [result: result + f]
	result
]

print-line combine-six 2 3 4 5 2 7
print-line combine-six 1 3 4 5 2 7
