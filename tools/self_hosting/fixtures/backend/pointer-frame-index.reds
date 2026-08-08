Red/System [
	Title: "O2 folded frame pointer index fixture"
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

check-positive: func [
	return: [integer!]
][
	either (add-int-pointer-framed (as int-ptr! 1000) 3) = (as int-ptr! 1012) [1][0]
]

check-negative: func [
	return: [integer!]
][
	either (add-int-pointer-framed (as int-ptr! 1000) -3) = (as int-ptr! 988) [1][0]
]

check-large-signed-index: func [
	return: [integer!]
	/local base result [int-ptr!]
][
	base: as int-ptr! 1
	result: add-int-pointer-framed base 40000000h
	either result <> base [1][0]
]

print-line check-positive
print-line check-negative
print-line check-large-signed-index
