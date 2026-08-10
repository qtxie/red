Red/System [
	Title: "Managed node handle live across a call"
]

node-handle!: alias integer!

clobber: func [
	return: [integer!]
][
	23
]

consume: func [
	handle [node-handle!]
	value [integer!]
	return: [integer!]
][
	handle + value
]

keep-handle: func [
	handle [node-handle!]
	return: [integer!]
][
	consume handle clobber
]

managed: context [
	node-handle!: alias integer!
	managed-handle!: alias node-handle!

	keep-handle: func [
		handle [managed-handle!]
		return: [integer!]
	][
		consume handle clobber
	]
]

handle-layout!: alias struct! [
	leading [integer!]
	handle [node-handle!]
	trailing [integer!]
]

declared-handle: declare node-handle!
declared-handle: 3000
print-line keep-handle 1000
print-line managed/keep-handle 2000
print-line keep-handle declared-handle
print-line size? handle-layout!
