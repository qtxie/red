Red/System [
	Title: "O2 x64 resolver intrinsic coverage"
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

run-resolver-intrinsics: func [
	/local score [integer!] entry [ptr-ptr!] node resolved [node!]
		payload series [int-ptr!]
][
	score: 0
	entry: as ptr-ptr! allocate size? int-ptr!
	node: as node! allocate size? node!
	payload: as int-ptr! allocate size? integer!
	payload/value: 37
	node/value: payload
	entry/value: as int-ptr! node
	red/node-registry/entries: entry
	red/node-registry/capacity: 1
	red/node-registry/next: 2
	red/node-registry/free: 0

	resolved: red/resolve-node-ir 1
	if resolved/value/value = 37 [score: score + 1]
	if null? red/resolve-node-ir 0 [score: score + 1]
	if null? red/resolve-node-ir -1 [score: score + 1]
	if null? red/resolve-node-ir 2 [score: score + 1]

	series: red/resolve-series-ir 1
	if series/value = 37 [score: score + 1]
	if null? red/resolve-series-ir 0 [score: score + 1]

	entry/value: null
	if null? red/resolve-node-ir 1 [score: score + 1]
	if null? red/resolve-series-ir 1 [score: score + 1]

	free as byte-ptr! payload
	free as byte-ptr! node
	free as byte-ptr! entry
	print-line score
]

run-resolver-intrinsics
