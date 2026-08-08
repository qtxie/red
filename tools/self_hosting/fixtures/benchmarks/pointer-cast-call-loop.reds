Red/System [
	Title: "Generated-code pointer cast call benchmark"
]

wide-cell!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

cell-identity: func [
	value [wide-cell!]
	return: [wide-cell!]
][
	value
]

cast-call-wrapper: func [
	value [byte-ptr!]
	return: [byte-ptr!]
][
	as byte-ptr! cell-identity (as wide-cell! value)
]

hot-cast-call-loop: func [
	value [byte-ptr!]
	iterations [integer!]
	return: [byte-ptr!]
	/local index [integer!]
][
	index: 0
	while [index < iterations][
		value: cast-call-wrapper value
		index: index + 1
	]
	value
]

print-line as integer! hot-cast-call-loop (as byte-ptr! 4096) 20000000
