Red/System [
	Title: "O2 scaled pointer arithmetic fixture"
]

wide-cell!: alias struct! [
	a [integer!]
	b [integer!]
	c [integer!]
	d [integer!]
]

add-int-pointer: func [
	base [int-ptr!]
	index [integer!]
	return: [int-ptr!]
][
	base + index
]

add-byte-pointer: func [
	base [byte-ptr!]
	index [integer!]
	return: [byte-ptr!]
][
	base + index
]

add-cell-pointer: func [
	base [wide-cell!]
	index [integer!]
	return: [wide-cell!]
][
	base + index
]

subtract-int-pointer: func [
	base [int-ptr!]
	index [integer!]
	return: [int-ptr!]
][
	base - index
]

check-int-positive: func [
	return: [integer!]
	/local result [int-ptr!]
][
	result: add-int-pointer (as int-ptr! 1000) 3
	either result = (as int-ptr! 1012) [1][0]
]

check-byte-negative: func [
	return: [integer!]
	/local result [byte-ptr!]
][
	result: add-byte-pointer (as byte-ptr! 1000) -7
	either result = (as byte-ptr! 993) [1][0]
]

check-cell-scale: func [
	return: [integer!]
	/local result [wide-cell!]
][
	result: add-cell-pointer (as wide-cell! 1000) 2
	either result = (as wide-cell! 1032) [1][0]
]

check-subtract: func [
	return: [integer!]
	/local result [int-ptr!]
][
	result: subtract-int-pointer (as int-ptr! 1000) 3
	either result = (as int-ptr! 988) [1][0]
]

check-large-signed-index: func [
	return: [integer!]
	/local base result [int-ptr!]
][
	base: as int-ptr! 1
	result: add-int-pointer base 40000000h
	either result <> base [1][0]
]

print-line check-int-positive
print-line check-byte-negative
print-line check-cell-scale
print-line check-subtract
print-line check-large-signed-index
