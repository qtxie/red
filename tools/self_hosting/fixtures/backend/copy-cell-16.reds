Red/System [
	Title: "O2 16-byte aggregate copy coverage"
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

run-copy-cell16: func [
	/local source [cell16! value] copied [cell16! value]
][
	source/a: 10
	source/b: 20
	source/c: 30
	source/d: 40
	copied: copy-cell16 source
	print-line copied/a + copied/b + copied/c + copied/d
]

run-copy-cell16
