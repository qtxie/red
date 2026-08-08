Red/System [
	Title: "O2 pointer representation cast fixture"
]

wide-cell!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

other-cell!: alias struct! [
	first [integer!]
	second [integer!]
	third [integer!]
	fourth [integer!]
]

byte-to-cell: func [
	base [byte-ptr!]
	return: [wide-cell!]
][
	as wide-cell! base
]

cell-to-byte: func [
	base [wide-cell!]
	return: [byte-ptr!]
][
	as byte-ptr! base
]

cell-to-other: func [
	base [wide-cell!]
	return: [other-cell!]
][
	as other-cell! base
]

other-to-cell: func [
	base [other-cell!]
	return: [wide-cell!]
][
	as wide-cell! base
]

base: as byte-ptr! 1000
cell: byte-to-cell base
other: cell-to-other cell
back: other-to-cell other
byte-result: cell-to-byte back
print-line either byte-result = base [1][0]
cell: byte-to-cell base
byte-result: cell-to-byte cell
print-line either byte-result = base [1][0]
other: cell-to-other cell
cell: other-to-cell other
byte-result: cell-to-byte cell
print-line either byte-result = base [1][0]
byte-result: cell-to-byte back
cell: byte-to-cell byte-result
byte-result: cell-to-byte cell
print-line either byte-result = base [1][0]
