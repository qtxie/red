Red/System [
	Title: "Generated-code scaled pointer arithmetic benchmark"
]

wide-cell!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

hot-pointer-arithmetic-loop: func [
	base [wide-cell!]
	iterations [integer!]
	return: [wide-cell!]
	/local index [integer!] cursor [wide-cell!]
][
	index: 0
	cursor: base
	while [index < iterations][
		cursor: cursor + 1
		index: index + 1
	]
	cursor
]

print-line as integer! hot-pointer-arithmetic-loop (as wide-cell! 4096) 20000000
