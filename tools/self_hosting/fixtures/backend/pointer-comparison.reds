Red/System [
	Title: "O2 unsigned pointer comparison fixture"
]

pointer-less?: func [
	left [int-ptr!]
	right [int-ptr!]
	return: [logic!]
][
	left < right
]

pointer-greater?: func [
	left [int-ptr!]
	right [int-ptr!]
	return: [logic!]
][
	left > right
]

pointer-less-or-equal?: func [
	left [int-ptr!]
	right [int-ptr!]
	return: [logic!]
][
	left <= right
]

pointer-greater-or-equal?: func [
	left [int-ptr!]
	right [int-ptr!]
	return: [logic!]
][
	left >= right
]

print-line either pointer-less? (as int-ptr! 1) (as int-ptr! -1) [1][0]
print-line either pointer-greater? (as int-ptr! -1) (as int-ptr! 1) [1][0]
print-line either pointer-less-or-equal? (as int-ptr! 1) (as int-ptr! 1) [1][0]
print-line either pointer-greater-or-equal? (as int-ptr! -1) (as int-ptr! -1) [1][0]
