Red/System [
	Title: "O2 16-byte aggregate copy coverage"
]

cell16!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

cell24!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
	e [integer!]
	f [integer!]
]

copy-cell16: func [
	value [cell16! value]
	return: [cell16! value]
][
	value
]

copy-cell24: func [
	value [cell24! value]
	return: [cell24! value]
][
	value
]

run-copy-cell16: func [
	return: [integer!]
	/local source [cell16! value] copied [cell16! value]
][
	source/a: 10
	source/b: 20
	source/c: 30
	source/d: 40
	copied: copy-cell16 source
	copied/a + copied/b + copied/c + copied/d
]

run-copy-cell24: func [
	return: [integer!]
	/local source [cell24! value] copied [cell24! value]
][
	source/a: 1
	source/b: 2
	source/c: 4
	source/d: 8
	source/e: 16
	source/f: 32
	copied: copy-cell24 source
	copied/a + copied/b + copied/c + copied/d + copied/e + copied/f
]

print-line run-copy-cell16
print-line run-copy-cell24
