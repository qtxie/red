Red/System [
	Title: "Generated-code 16-byte aggregate copy benchmark"
]

cell16!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

copy-cell16: func [
	value [cell16! value]
	return: [cell16! value]
][
	value
]

hot-copy-cell16-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum [integer!] source [cell16! value] copied [cell16! value]
][
	index: 0
	checksum: 0
	source/a: 10
	source/b: 20
	source/c: 30
	source/d: 40
	while [index < iterations][
		copied: copy-cell16 source
		checksum: checksum + copied/d
		index: index + 1
	]
	checksum
]

print-line hot-copy-cell16-loop 50000000
