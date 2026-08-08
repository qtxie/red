Red/System [
	Title: "Generated-code unsigned pointer comparison benchmark"
]

hot-pointer-comparison-loop: func [
	base [int-ptr!]
	iterations [integer!]
	return: [integer!]
	/local cursor tail [int-ptr!] count [integer!]
][
	cursor: base
	tail: base + iterations
	count: 0
	while [cursor < tail][
		cursor: cursor + 1
		count: count + 1
	]
	count
]

print-line hot-pointer-comparison-loop (as int-ptr! 4096) 100000000
