Red/System [
	Title: "Generated-code folded frame pointer index benchmark"
]

identity-int-pointer: func [
	value [int-ptr!]
	return: [int-ptr!]
][
	value
]

add-int-pointer-framed: func [
	base [int-ptr!]
	index [integer!]
	return: [int-ptr!]
	/local result [int-ptr!]
][
	result: base + index
	identity-int-pointer result
]

hot-pointer-frame-index-loop: func [
	base [int-ptr!]
	iterations [integer!]
	return: [int-ptr!]
	/local index offset [integer!] cursor [int-ptr!]
][
	index: 0
	cursor: base
	while [index < iterations][
		offset: index and 7
		cursor: add-int-pointer-framed cursor offset
		index: index + 1
	]
	cursor
]

print-line as integer! hot-pointer-frame-index-loop (as int-ptr! 4096) 100000000
