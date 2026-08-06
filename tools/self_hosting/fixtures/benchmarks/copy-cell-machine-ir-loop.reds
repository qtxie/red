Red/System [
	Title: "Generated-code machine-IR copy-cell benchmark"
]

cell16!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

red: context [
	copy-cell: func [
		src [cell16!]
		dst [cell16!]
		return: [cell16!]
		/local source target [pointer! [int64!]]
	][
		if src = dst [return dst]
		source: as [pointer! [int64!]] src
		target: as [pointer! [int64!]] dst
		target/1: source/1
		target/2: source/2
		dst
	]

	copy-cell-ir: func [
		src [cell16!]
		dst [cell16!]
		return: [cell16!]
	][
		copy-cell src dst
	]
]

hot-copy-cell-ir-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum [integer!] source destination [cell16!]
][
	index: 0
	checksum: 0
	source: declare cell16!
	destination: declare cell16!
	source/a: 10
	source/b: 20
	source/c: 30
	source/d: 40
	while [index < iterations][
		red/copy-cell-ir source destination
		index: index + 1
	]
	checksum: destination/a + destination/b + destination/c + destination/d
	checksum
]

print-line hot-copy-cell-ir-loop 50000000
