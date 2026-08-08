Red/System [
	Title: "Generated-code resolver intrinsic benchmark"
]

node!: alias struct! [
	value [int-ptr!]
]

red: context [
	node-registry: declare struct! [
		entries   [ptr-ptr!]
		free-next [int-ptr!]
		capacity  [integer!]
		next      [integer!]
		free      [integer!]
	]

	resolve-node: func [
		handle [integer!]
		return: [node!]
		/local entry [ptr-ptr!]
	][
		if zero? handle [return null]
		if any [handle < 1 handle >= node-registry/next][return null]
		entry: node-registry/entries + (handle - 1)
		as node! entry/value
	]

	resolve-series: func [
		handle [integer!]
		return: [int-ptr!]
		/local node [node!]
	][
		if zero? handle [return null]
		node: resolve-node handle
		if null? node [return null]
		node/value
	]

	resolve-node-ir: func [
		handle [integer!]
		return: [node!]
	][
		resolve-node handle
	]

	resolve-series-ir: func [
		handle [integer!]
		return: [int-ptr!]
	][
		resolve-series handle
	]
]

hot-resolver-loop: func [
	iterations [integer!]
	return: [integer!]
	/local index checksum [integer!] entry [ptr-ptr!] node resolved [node!]
		payload series [int-ptr!]
][
	index: 0
	checksum: 0
	entry: as ptr-ptr! allocate size? int-ptr!
	node: as node! allocate size? node!
	payload: as int-ptr! allocate size? integer!
	payload/value: 7
	node/value: payload
	entry/value: as int-ptr! node
	red/node-registry/entries: entry
	red/node-registry/capacity: 1
	red/node-registry/next: 2
	red/node-registry/free: 0

	while [index < iterations][
		resolved: red/resolve-node-ir 1
		series: red/resolve-series-ir 1
		checksum: checksum + resolved/value/value + series/value
		index: index + 1
	]

	free as byte-ptr! payload
	free as byte-ptr! node
	free as byte-ptr! entry
	checksum
]

print-line hot-resolver-loop 50000000
