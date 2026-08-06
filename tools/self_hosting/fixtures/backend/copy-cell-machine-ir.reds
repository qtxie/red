Red/System [
	Title: "O2 x64 machine-IR copy-cell coverage"
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

run-copy-cell-ir: func [
	/local source destination copied same [cell16!]
][
	source: declare cell16!
	destination: declare cell16!
	source/a: 10
	source/b: 20
	source/c: 30
	source/d: 40
	copied: red/copy-cell-ir source destination
	same: red/copy-cell-ir source source
	print-line destination/a + destination/b + destination/c + destination/d + copied/a + same/b
]

run-copy-cell-ir
