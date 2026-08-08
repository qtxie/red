Red/System [
	Title: "O2 nested relocation ordering fixture"
]

global-left: 7
global-right: 11
stored-result: 0

increment: func [
	value [integer!]
	return: [integer!]
][
	value + 1
]

combine: func [
	left [integer!]
	right [integer!]
	return: [integer!]
][
	left + right
]

nested-call-order: func [
	return: [integer!]
][
	combine global-left (increment global-right)
]

nested-store-order: func [
	return: [integer!]
][
	stored-result: increment global-left
	stored-result
]

print-line nested-call-order
print-line nested-store-order
