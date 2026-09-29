Red [
	Title: "Red/System node handle runtime test"
	File:  %node-handle-test.red
]

#system [
	#include %../../../quick-test/quick-test.reds

	~~~start-file~~~ "node handles"

	===start-group=== "registry"

	--test-- "node-handle-resolve"
		node: alloc-bytes 8
		handle: node-handle-of node
		--assert handle > 0
		--assert (as-integer resolve-node handle) = as-integer node

	--test-- "node-handle-series-backref"
		node: alloc-cells 2
		handle: node-handle-of node
		series: as series! node/value
		--assert series/node = handle
		--assert (as-integer resolve-series handle) = as-integer series

	--test-- "node-handle-cell-layout"
		--assert (size? node-handle!) = 4
		--assert (size? red-series!) = 16
		--assert (size? red-string!) = 16
		--assert (size? red-file!) = 16
		--assert (size? red-url!) = 16
		--assert (size? red-tag!) = 16
		--assert (size? red-email!) = 16
		--assert (size? red-ref!) = 16
		--assert (size? red-binary!) = 16
		--assert (size? red-bitset!) = 16
		--assert (size? red-symbol!) = 16
		--assert (size? red-block!) = 16
		--assert (size? red-paren!) = 16
		--assert (size? red-path!) = 16
		--assert (size? red-lit-path!) = 16
		--assert (size? red-set-path!) = 16
		--assert (size? red-get-path!) = 16
		--assert (size? red-context!) = 16
		--assert (size? red-object!) = 16
		--assert (size? red-word!) = 16
		--assert (size? red-refinement!) = 16
		--assert (size? red-action!) = 16
		--assert (size? red-native!) = 16
		--assert (size? red-op!) = 16
		--assert (size? red-function!) = 16
		--assert (size? red-routine!) = 16
		--assert (size? red-vector!) = 16
		--assert (size? red-hash!) = 16
		--assert (size? red-image!) = 16
		--assert (size? red-slice!) = 16

	--test-- "node-handle-stack-context-offset"
		--assert (stack/store-values stack/bottom) = 1
		stack-slot: stack/bottom + 3
		stack-offset: stack/store-values stack-slot
		--assert stack-offset = 4
		--assert (as-integer stack/get-values stack-offset) = as-integer stack-slot
		--assert null? stack/get-values 0

	--test-- "node-handle-slot-is-registry-entry"
		node: alloc-bytes 8
		handle: node-handle-of node
		slot: registry-slot handle
		--assert slot = node									;-- the entry *is* the node record
		--assert (as-integer resolve-node handle) = as-integer slot
		series: as series! node/value
		--assert series/node = handle
		--assert (as-integer resolve-series handle) = as-integer series
		--assert null? resolve-node 0							;-- an unbound handle names no node

	--test-- "node-handle-chunk-growth"
		chunks: node-registry/count
		grown-node: alloc-bytes 8
		grown-handle: node-handle-of grown-node
		grown-slot: registry-slot grown-handle
		registry-grow
		--assert node-registry/count > chunks
		--assert (as-integer registry-slot grown-handle) = as-integer grown-slot
		--assert (as-integer resolve-node grown-handle) = as-integer grown-slot
		chunk-a: node-registry/chunks
		chunk-b: chunk-a + 1
		boundary: chunk-a/slots + (registry-chunk-slots - 1)
		--assert (as-integer registry-slot registry-chunk-slots) = as-integer boundary
		--assert (as-integer registry-slot (registry-chunk-slots + 1)) = as-integer chunk-b/slots

	--test-- "node-handle-release-and-reuse"
		old-node: alloc-bytes 8
		stable-handle: node-handle-of old-node
		stable-slot: registry-slot stable-handle
		--assert stable-slot = old-node
		slot-address: as-integer stable-slot
		holder: as red-binary! stack/push*
		holder/header: TYPE_BINARY
		holder/head: 0
		holder/node: stable-handle
		collector/do-cycle									;-- rooted, and compacted: the slot cannot move
		moved: resolve-node stable-handle
		--assert moved = stable-slot
		--assert holder/node = stable-handle					;-- the cell keeps naming the same handle
		moved-series: as series! moved/value
		--assert moved-series/node = stable-handle

		external-type: externals/register-node "node-handle-test" null
		external-id: externals/store-node stable-handle external-type
		external-record: externals/list + external-id
		--assert external-record/node = stable-handle			;-- a node record names an entry, never a buffer
		--assert null? external-record/handle

		used-before: node-registry/used
		free-before: node-registry/free
		holder/header: TYPE_UNSET
		stack/pop 1
		old-node: null
		stable-slot: null
		moved: null
		moved-series: null
		external-record: null
		collector/do-cycle									;-- unreachable: record and entry released together

		external-record: externals/list + external-id
		--assert external-record/node = 0						;-- the sweep dropped the record...
		--assert null? external-record/handle
		--assert null? resolve-node stable-handle				;-- ...then the entry came loose
		--assert node-registry/used < used-before
		--assert node-registry/free <> free-before

		on-free?: no
		walk: node-registry/free
		wlink: registry-link walk
		steps: node-registry/next
		while [all [walk > 0 steps > 0]][
			if walk = stable-handle [on-free?: yes]
			wlink: registry-link walk
			walk: wlink/value
			steps: steps - 1
		]
		--assert on-free?										;-- queued for reuse, nothing to rewrite

		head: node-registry/free
		reused-node: alloc-bytes 8
		reused-handle: node-handle-of reused-node
		--assert reused-handle = head							;-- allocation takes the free-list head
		--assert reused-node = registry-slot reused-handle
		--assert (as-integer registry-slot reused-handle) = slot-address
		--assert (as-integer resolve-node reused-handle) = as-integer reused-node
		backref: as series! reused-node/value
		--assert backref/node = reused-handle

	--test-- "node-handle-used-accounting"						;-- runs last: every release above is counted
		bound: 0
		h: 1
		p: registry-slot 1
		while [h < node-registry/next][
			p: registry-slot h
			if p/value <> null [bound: bound + 1]
			h: h + 1
		]
		--assert node-registry/used = bound						;-- memory-info reads only this counter

	===end-group===

	~~~end-file~~~
]
