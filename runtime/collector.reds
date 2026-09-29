Red/System [
	Title:   "Red memory garbage collector"
	Author:  "Nenad Rakocevic"
	File: 	 %collector.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2015-2017 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
	Notes: "Implements the naive Mark&Sweep method."
]

collector: context [
	#define GC_DONE		0
	#define GC_RUNNING	1

	verbose: 0
	active?: no
	state: GC_DONE
	gc-frame: as ptr-ptr! 0							;-- frame that requested the current cycle
	
	#enum frame-type! [
		FRAME_NODES
		FRAME_SERIES
	]

	stats: declare struct! [
		cycles		 [integer!]							;-- nb or GC runs
		pinned-frames [integer!]						;-- conservatively retained series frames in current cycle
		pinned-bytes  [integer!]						;-- bytes retained by conservative frame pins
		mark-time	 [float!]							;-- cumulative marking seconds		(RED_GC_STATS)
		scan-time	 [float!]							;-- cumulative native stack scan seconds
		sweep-time	 [float!]							;-- cumulative sweep/compaction seconds
		moved-series [integer!]							;-- series buffers relocated by compaction
		moved-bytes  [integer!]							;-- payload bytes relocated
		stack-slots  [integer!]							;-- conservative stack words examined
		stack-roots  [integer!]							;-- stack words that rooted a series
		queue-peak	 [integer!]							;-- widest marking queue, in cell ranges
		handle-bits	 [integer!]							;-- declared slots the handle bitmap named
		probe-roots  [integer!]							;-- handles the range probe rooted that it did not
		probe-new    [integer!]							;-- of those, ones nothing else had marked yet
		probe-alias  [integer!]							;-- hits rejected: the word is wider than an index
		gap-words	 [integer!]							;-- words below a frame's declared slots examined
		gap-frames	 [integer!]							;-- frames whose window was walked at all
		gap-stores	 [integer!]							;-- of those, ones recorded for rewriting
		gap-pins	 [integer!]							;-- of those, ones that pinned a series frame
		gap-depth	 [integer!]							;-- deepest recorded word, in slots below the locals
		gap-scan	 [integer!]							;-- deepest word walked, same measure
		gap-bound	 [integer!]							;-- frames whose walk stopped at their own bottom
		gap-unpub	 [integer!]							;-- frames whose record published no bound
		gap-refused  [integer!]							;-- published bounds that contradicted the callee
	]
	
	ext-size: 100
	ext-markers: as ptr-ptr! allocate ext-size * size? int-ptr!
	ext-top: ext-markers
	
	;-- Marking worklist: pairs of (head tail) cell pointers still to walk.
	;-- Marking used to recurse through one native frame per nesting level, so a
	;-- deep block chain was a stack overflow with no diagnostic, and the mark
	;-- phase could not be resumed. Depth is now bounded by this buffer, which
	;-- the allocator owns as raw memory: a managed series would be relocated by
	;-- the compaction that follows marking.
	mark-queue: context [
		list:  as ptr-ptr! 0							;-- (head tail) pairs
		count: 0										;-- ranges waiting to be walked
		size:  0										;-- allocated ranges
	]
	walking?: no										;-- a drain owns the queue


	indent: 0

	stress?: no										;-- RED_GC_STRESS: run GC passes at a forced pace
	stress-period: 1								;-- GC every Nth allocation while stressed
	stress-count: 0

	stats?: no										;-- RED_GC_STATS: accumulate per-phase timings and counters
	stats-countdown: 1								;-- dump every Nth cycle (1 = the first one)

	#define GC_STATS_PERIOD 100

	read-stress-env: func [
		period [int-ptr!]
		return: [logic!]
		/local
			len n i b [integer!]
			buf [c-string!]
	][
		#either OS = 'Windows [
			len: platform/get-env #u16 "RED_GC_STRESS" 0 0
		][
			len: platform/get-env "RED_GC_STRESS" 0 0
		]
		if len <= 0 [period/value: 1 return no]
		if len > 120 [period/value: 1 return yes]
		buf: as c-string! allocate 256
		fill as byte-ptr! buf (as byte-ptr! buf) + 256 #"^(00)"
		#either OS = 'Windows [
			platform/get-env #u16 "RED_GC_STRESS" buf 128	;-- valsize is in UTF-16 units
		][
			platform/get-env "RED_GC_STRESS" buf 128
		]
		n: 0
		i: 0
		while [i < 256][							;-- digit filter: reads ASCII and UTF-16 alike
			b: as-integer buf/i
			if all [b >= as-integer #"0" b <= as-integer #"9"][
				if n < 100000000 [n: (n * 10) + (b - as-integer #"0")]
			]
			i: i + 1
		]
		free as byte-ptr! buf
		period/value: either n < 1 [1][n]
		yes
	]

	read-stats-env: func [
		return: [logic!]
		/local len [integer!]
	][
		#either OS = 'Windows [
			len: platform/get-env #u16 "RED_GC_STATS" 0 0
		][
			len: platform/get-env "RED_GC_STATS" 0 0
		]
		len > 0											;-- presence only: any value switches it on
	]

	check-abi: does [
		;-- Startup invariant check. The one thing `#if` cannot express today is a
		;-- compile-time size assertion -- the preprocessor only knows its own
		;-- symbols, not `size?` -- so the value-cell contract is checked once at
		;-- init instead. It is what catches a struct whose width silently changed
		;-- on one target (the macOS-arm64 float32!/float! case) and moved every
		;-- stack slot the pointer bitmap describes with it.
		unless size? cell! = 16 [
			print-line ["*** ABI violation: size? cell! = " size? cell! ", expected 16"]
			quit -1
		]
		unless size? node-handle! = 4 [
			print-line ["*** ABI violation: size? node-handle! = " size? node-handle! ", expected 4"]
			quit -1
		]
		unless all [
			size? red-series!	= 16
			size? red-block!	= 16
			size? red-string!	= 16
			size? red-object!	= 16
			size? red-context!	= 16
			size? red-function!	= 16
			size? red-word!		= 16
		][
			print-line ["*** ABI violation: a value cell is not 16 bytes"]
			quit -1
		]
	]

	init: func [][
		stats/cycles: 			0
		stats/pinned-frames:	0
		stats/pinned-bytes:	0
		stats/mark-time:		0.0
		stats/scan-time:		0.0
		stats/sweep-time:		0.0
		stats/moved-series:		0
		stats/moved-bytes:		0
		stats/stack-slots:		0
		stats/stack-roots:		0
		stats/handle-bits:		0
		stats/probe-roots:		0
		stats/probe-new:		0
		stats/probe-alias:		0
		stats/gap-words:		0
		stats/gap-frames:		0
		stats/gap-stores:		0
		stats/gap-pins:			0
		stats/gap-depth:		0
		stats/gap-scan:			0
		stats/gap-bound:		0
		stats/gap-unpub:		0
		stats/gap-refused:		0
		stress?: read-stress-env :stress-period
		stats?:  read-stats-env
		check-abi
	]

	compare-cb: func [
		[cdecl]
		a [int-ptr!]
		b [int-ptr!]
		return: [integer!]
		/local pa pb [ptr-ptr!]
	][
		pa: as ptr-ptr! a
		pb: as ptr-ptr! b
		SIGN_COMPARE_RESULT(pa/value pb/value)
	]
	
	frames-list: context [
		min-size:  1000
		fit-cache: 16									;-- nb of pointers fitting into a typical 64 bytes L1 cache

		#either any [target = 'X86-64 target = 'ARM64] [
			series-frame-from-slot: func [slot [ptr-ptr!] return: [series-frame!]][
				as series-frame! (as byte-ptr! slot/value)
			]
		][
			series-frame-from-slot: func [
				slot	[ptr-ptr!]
				return: [series-frame!]
				/local frame [series-frame!]
			][
				frame: as series-frame! (as byte-ptr! slot/value)
				frame
			]
		]

		list!: alias struct! [
			list  [ptr-ptr!] 							;-- array of native-width frame pointers
			size  [integer!]							;-- size of list (in pointers)
			count [integer!]							;-- current number of stored frames
		]
		nodes:  declare list!
		series: declare list!
		pinned: declare list!
		nodes/size:  min-size
		series/size: min-size
		pinned/size: fit-cache
		
		rebuild: func [									;-- build an array of registry chunk and frame pointers
			/local
				frm	[series-frame!]
				chunk [registry-chunk!]
				pos [ptr-ptr!]
				s	[list!]
				cnt [integer!]
				k	[integer!]
				process [subroutine!]
		][
			;-- allocation alignement not guaranteed, so L1 cache optmization is only eventual.
			if null? nodes/list  [nodes/list:  as ptr-ptr! allocate min-size * size? int-ptr!]
			if null? series/list [series/list: as ptr-ptr! allocate min-size * size? int-ptr!]
			if null? pinned/list [pinned/list: as ptr-ptr! allocate pinned/size * size? int-ptr!]
			pinned/count: 0
			stats/pinned-frames: 0
			stats/pinned-bytes: 0
			
			process: [
				until [
					pos/value: as int-ptr! frm
					pos: pos + 1
					cnt: cnt + 1
					if cnt >= s/size [
						s/size: s/size * 2
						s/list: as ptr-ptr! realloc as byte-ptr! s/list s/size * size? int-ptr!
						pos: s/list + cnt
					]
					frm: frm/next
					frm = null
				]
				if all [cnt > min-size cnt * 3 < s/size][	;-- shrink buffer if 2/3 or more are not used
					s/size: cnt
					s/list: as ptr-ptr! realloc as byte-ptr! s/list s/size * size? int-ptr!
				]
				qsort as byte-ptr! s/list cnt size? int-ptr! :compare-cb	;-- sort the array
				s/count: cnt
			]
			
			s: nodes									;-- registry chunks
			chunk: node-registry/chunks
			k: node-registry/count
			cnt: 0
			pos: s/list
			while [k > 0][								;-- a chunk is a fixed-width record, unlike a frame
				pos/value: as int-ptr! chunk/slots
				pos: pos + 1
				cnt: cnt + 1
				if cnt >= s/size [
					s/size: s/size * 2
					s/list: as ptr-ptr! realloc as byte-ptr! s/list s/size * size? int-ptr!
					pos: s/list + cnt
				]
				chunk: chunk + 1
				k: k - 1
			]
			qsort as byte-ptr! s/list cnt size? int-ptr! :compare-cb
			s/count: cnt
			
			s: series									;-- regular series frames
			frm: memory/s-head			
			cnt: 0
			pos: s/list
			process
			
			if memory/b-head <> null [					;-- big series
				frm: as series-frame! memory/b-head
				pos: s/list + cnt
				process
			]
		]

		big-frame?: func [
			base [int-ptr!]
			return: [logic!]
			/local frame [big-frame!]
		][
			frame: memory/b-head
			while [frame <> null][
				if base = as int-ptr! frame [return yes]
				frame: frame/next
			]
			no
		]

		;-- Return the containing series or big-series frame without interpreting
		;-- the candidate as a series header. The sorted predecessor lookup keeps
		;-- conservative stack values from causing arbitrary memory reads.
		find-series-frame: func [
			ptr [int-ptr!]
			return: [int-ptr!]
			/local
				b e p [ptr-ptr!]
				base [int-ptr!]
				regular [series-frame!]
				big [big-frame!]
				finish [byte-ptr!]
		][
			if zero? series/count [return null]
			b: series/list
			e: b + series/count
			while [b < e][
				p: b + (((as-integer e - b) / size? int-ptr!) / 2)
				either p/value <= ptr [b: p + 1][e: p]
			]
			if b = series/list [return null]
			p: b - 1
			base: p/value
			either big-frame? base [
				big: as big-frame! base
				finish: (as byte-ptr! big) + (size? big-frame!) + big/size
			][
				regular: as series-frame! base
				finish: (as byte-ptr! regular) + regular/size
			]
			either all [base <= ptr ptr < as int-ptr! finish][base][null]
		]

		pin: func [
			ptr [int-ptr!]
			return: [logic!]
			/local base [int-ptr!] p tail [ptr-ptr!] frame [series-frame!] big [big-frame!]
		][
			base: find-series-frame ptr
			if null? base [return no]
			p: pinned/list
			tail: p + pinned/count
			while [p < tail][
				if p/value = base [return yes]
				p: p + 1
			]
			if pinned/count = pinned/size [
				pinned/size: pinned/size * 2
				pinned/list: as ptr-ptr! realloc as byte-ptr! pinned/list pinned/size * size? int-ptr!
			]
			p: pinned/list + pinned/count
			p/value: base
			pinned/count: pinned/count + 1
			stats/pinned-frames: stats/pinned-frames + 1
			either big-frame? base [
				big: as big-frame! base
				stats/pinned-bytes: stats/pinned-bytes + big/size + size? big-frame!
			][
				frame: as series-frame! base
				stats/pinned-bytes: stats/pinned-bytes + frame/size
			]
			yes
		]

		pinned?: func [
			frame [int-ptr!]
			return: [logic!]
			/local p tail [ptr-ptr!]
		][
			p: pinned/list
			tail: p + pinned/count
			while [p < tail][
				if p/value = frame [return yes]
				p: p + 1
			]
			no
		]
		
		find: func [
			ptr		[int-ptr!]
			type	[frame-type!]
			return: [logic!]
			/local
				sfrm		 [series-frame!]
				frm			 [int-ptr!]
				p b e		 [ptr-ptr!]
				tail		 [byte-ptr!]
				s			 [list!]
				w h			 [integer!]
				end? series? [logic!]
		][
			series?: type = FRAME_SERIES
			s: either series? [h: size? series-frame!  series][h: 0 nodes]
			w: registry-chunk-slots * size? node!		;-- fixed registry chunk width
			
			either s/count <= fit-cache [				;== linear search
				p: s/list
				either series? [
					loop s/count [
						sfrm: series-frame-from-slot p
						tail: (as byte-ptr! sfrm) + sfrm/size
						if all [(as int-ptr! (as byte-ptr! sfrm) + h) <= ptr ptr < as int-ptr! tail][return yes]
						p: p + 1
					]
				][
					loop s/count [
						frm: p/value + h
						if all [
							frm <= ptr
							ptr < as int-ptr! ((as byte-ptr! frm) + w)
							zero? (((as-integer ptr) - (as-integer frm)) and ((size? node!) - 1))
						][return yes]
						p: p + 1
					]
				]
			][											;== binary search for arrays bigger than 16 nodes
				b: s/list								;-- low pointer
				e: s/list + (s/count - 1)				;-- high pointer
				either series? [
					until [
						p: b + ((((as-integer e - b) / size? int-ptr!) + 1) / 2) ;-- points to the middle of [b,e] segment
						sfrm: series-frame-from-slot p
						tail: (as byte-ptr! sfrm) + sfrm/size
						if all [(as int-ptr! (as byte-ptr! sfrm) + h) <= ptr ptr < as int-ptr! tail][return yes]
						end?: b = e						;-- gives a chance to probe the b = e segment
						either p/value < ptr [b: p][e: p - 1] ;-- chooses lower or upper segment
						end?
					]
				][
					until [
						p: b + ((((as-integer e - b) / size? int-ptr!) + 1) / 2) ;-- points to the middle of [b,e] segment
						frm: p/value + h
						if all [
							frm <= ptr
							ptr < as int-ptr! ((as byte-ptr! frm) + w)
							zero? (((as-integer ptr) - (as-integer frm)) and ((size? node!) - 1))
						][return yes]
						end?: b = e						;-- gives a chance to probe the b = e segment
						either p/value < ptr [b: p][e: p - 1] ;-- chooses lower or upper segment
						end?
					]
				]
			]
			no
		]
	]
	
	nodes-list: context [								;-- handles freeing batch handling
		list:	  as int-ptr! 0
		min-size: 20000
		buf-size: min-size								;-- initial number of supported handles
		count:	  0										;-- current number of stored handles
		
		init: does [list: as int-ptr! allocate buf-size * size? integer!]
		
		store: func [
			handle [node-handle!]
			/local slot [int-ptr!]
		][
			if zero? handle [exit]					;-- expanded series clears the old back-reference
			if count = buf-size [flush]					;-- buffer full, flush it first
			slot: list + count
			slot/value: handle
			count: count + 1
		]
		
		flush: func [									;-- hand every queued entry back to the registry
			/local p [int-ptr!]
		][
			if zero? count [exit]
			p: list
			loop count [
				free-node-handle p/value
				p: p + 1
			]
			count: 0									;-- resets the list to its head (clears the list content)
		]
	]
	
	keep-raw: func [
		ptr		[ptr-ptr!]
		return: [logic!]								;-- TRUE if newly marked, FALSE if already done
		/local
			node [node!]
			s	 [series!]
			new? [logic!]
			flags [integer!]
	][
		node: as node! ptr/value
		if any [null? node null? node/value][return no]	;-- an unbound slot names nothing
		s: as series! node/value
		flags: s/flags
		new?: flags and flag-gc-mark = 0
		if new? [s/flags: flags or flag-gc-mark]
		new?
	]

	;-- Mark the series a node handle names. The slot form below is the same test
	;-- through the word holding the handle; a root that is a plain value, like the
	;-- table header _hashtable/mark is handed, needs no slot to be marked.
	keep-handle: func [
		handle	[node-handle!]
		return: [logic!]								;-- TRUE if newly marked, FALSE if already done
		/local
			node  [node!]
			s     [series!]
			new?  [logic!]
			flags [integer!]
	][
		if zero? handle [return no]
		node: resolve-node handle
		if any [null? node null? node/value][return no]
		s: as series! node/value
		flags: s/flags
		new?: flags and flag-gc-mark = 0
		if new? [s/flags: flags or flag-gc-mark]
		new?
	]

	keep: func [
		ptr		[int-ptr!]
		return: [logic!]								;-- TRUE if newly marked, FALSE if already done
	][
		keep-handle ptr/value
	]


	;-- Deep-mark a unit-1 series only when every field of hashtable! is
	;-- consistent with a live table. Must be strict: a false positive marks
	;-- live-looking buffers that nothing owns. Since hashtable! names its arrays
	;-- by handle, consistency is now a registry question -- a field that is
	;-- neither zero nor a live buffer rejects the candidate -- where it used to
	;-- ask the frame lists whether a raw pointer still looked like a node,
	;-- which a freed-but-untouched buffer would answer yes to.
	mark-hashtable-node: func [
		node [node!]
		/local
			s sk sf sb [series!]
			h    [hashtable!]
			kn fn bn [node!]
			type n-buckets n-occupied upper [integer!]
			p e  [int-ptr!]
	][
		if any [null? node null? node/value][exit]
		s: as series! node/value
		if GET_UNIT(s) <> 1 [exit]
		if s/flags and series-in-use = 0 [exit]
		if (as-integer s/tail - s/offset) < size? hashtable! [exit]
		;-- table series must own a stable handle that points back here
		if any [s/node < 1 s/node >= node-registry/next][exit]
		kn: resolve-node s/node
		if any [null? kn kn <> node][exit]

		h: as hashtable! s/offset
		type: h/type
		n-buckets: h/n-buckets
		n-occupied: h/n-occupied
		upper: h/upper-bound
		if any [
			type < HASH_TABLE_HASH
			type > HASH_TABLE_OWNERSHIP
			n-buckets < 4
			n-buckets > 01000000h
			(n-buckets and (n-buckets - 1)) <> 0
			n-occupied < 0
			n-occupied > n-buckets
			upper <= 0
			upper > n-buckets
			h/keys = 0						;-- every type has both of these
			h/flags = 0
		][exit]

		;-- indexes, chains, flags, keys, blk: the five handle fields, consecutive
		;-- in the header. A type that does not use one leaves it zero, so a zero
		;-- here is legal and anything else must name a live buffer. That covers
		;-- the table _hashtable/init is still building: it writes the header words
		;-- one allocation at a time, and a collection fired by a later one can find
		;-- and probe it, so a half-built table must be rejected, not marked.
		p: :h/indexes
		e: p + 5
		while [p < e][
			if p/value <> 0 [
				kn: resolve-node p/value
				if any [null? kn null? kn/value][exit]
			]
			p: p + 1
		]

		kn: resolve-node h/keys
		sk: as series! kn/value
		;-- keys is built by _alloc-bytes, so it is a unit-1 buffer of
		;-- n-buckets * size? int-ptr! bytes that the table indexes as
		;-- 32-bit words. Requiring unit 4 here rejected every table.
		if any [
			GET_UNIT(sk) <> 1
			sk/size < (n-buckets * size? int-ptr!)
		][exit]

		fn: resolve-node h/flags
		sf: as series! fn/value
		if any [
			GET_UNIT(sf) <> 1							;-- flag bytes
			sf/size < (n-buckets >> 2)
		][exit]

		if h/blk <> 0 [
			bn: resolve-node h/blk
			sb: as series! bn/value
			if all [
				type > 0									;-- maps/hashes store cells
				type < HASH_TABLE_NODE_KEY
				GET_UNIT(sb) <> 16
			][exit]
		]

		_hashtable/mark s/node
	]

	;-- Mark a node-handle! found in one native stack slot: unit-16 cell series
	;-- deep-mark via mark-block-node, unit-1 is shallow-kept, and validated
	;-- hashtables are deep-marked so nested keys/flags/blk stay live across GC.
	;-- The slot arrives either because the frame's handle bitmap names it, or
	;-- because the range probe below guessed it might. stats/probe-roots counts the
	;-- guesses, stats/probe-new the ones that were a node's only root that cycle:
	;-- the day probe-new stops moving is the day this probe can stop.
	;-- The probe is a range test -- the registry takes any handle in (0, next) --
	;-- and a node-handle! is a bare index, so an unrelated small integer cannot be
	;-- told apart from a reference: a symbol id in a dead slot roots the series that
	;-- happens to own that index. Two rules narrow that. The 64-bit walk confines the
	;-- probe to declared slots, where root?'s rule for pointers already applies: a
	;-- call in progress has its arguments rooted by the callee's own arg pass, so a
	;-- gap word only holds what a completed call left behind. The other, below, is
	;-- that a candidate has to fill its word -- over the Red unit suite that rule cut
	;-- the load-bearing rootings from 79 to 12 and kept 8810 words out of the walk.
	;-- IA-32 publishes no usable frame shape and still probes the whole body; there a
	;-- word is the index entire, so the second rule is already in force and only the
	;-- first is missing.
	mark-stack-handle: func [
		sp [ptr-ptr!]
		named? [logic!]									;-- yes when the handle bitmap asked
		/local
			handle [integer!]
			p     [int-ptr!]
			entry [ptr-ptr!]
			s     [series!]
			flags [integer!]
			unseen? [logic!]
	][
		handle: as integer! sp/value
		if all [handle > 0 handle < node-registry/next][
			;-- The range test reads the low half only, so on a 64-bit target an address
			;-- ending inside the registry's span answers to whoever owns that index and a
			;-- stranger nothing refers to stays alive for the cycle. A node-handle! fills
			;-- its word, so demanding the whole word leaves only values that can name a
			;-- node at all -- except in a slot the bitmap named, whose upper half is just
			;-- what the last 32-bit store there left behind.
			p: sp/value
			either any [named? p = as int-ptr! handle][
				unless named? [stats/probe-roots: stats/probe-roots + 1]
				entry: registry-slot handle
				if entry/value <> null [
					s: as series! entry/value
					flags: s/flags
					unseen?: either GET_UNIT(s) = 16 [
						any [flags and flag-gc-mark = 0 flags and flag-gc-scan = 0]
					][flags and flag-gc-mark = 0]
					if unseen? [
						;-- This walk runs last, so a node still unmarked here had no
						;-- other root this cycle: the probe is what kept it alive.
						stats/probe-new: stats/probe-new + 1
					]
					either GET_UNIT(s) = 16 [
						mark-block-node as int-ptr! sp
					][
						keep as int-ptr! sp
						if GET_UNIT(s) = 1 [mark-hashtable-node entry]
					]
				]
			][
				stats/probe-alias: stats/probe-alias + 1	;-- an address, not a handle
			]
		]
	]

	unmark: func [
		handle	[node-handle!]
		/local s [series!]
	][
		s: resolve-series handle
		s/flags: s/flags and not (flag-gc-mark or flag-gc-scan)
	]

	;-- Queue a range of cells for the marking walk, growing the buffer on
	;-- demand. A nested block costs two words here instead of a native frame,
	;-- so mark depth is a heap property, not a stack one.
	queue-range: func [
		value [red-value!]
		tail  [red-value!]
		/local pos [ptr-ptr!]
	][
		if value >= tail [exit]
		if null? mark-queue/list [
			mark-queue/size: 256
			mark-queue/list: as ptr-ptr! allocate mark-queue/size * 2 * size? int-ptr!
		]
		if mark-queue/count >= mark-queue/size [
			mark-queue/size: mark-queue/size * 2
			mark-queue/list: as ptr-ptr! realloc as byte-ptr! mark-queue/list mark-queue/size * 2 * size? int-ptr!
		]
		pos: mark-queue/list + (mark-queue/count * 2)
		pos/value: as int-ptr! value
		pos: pos + 1
		pos/value: as int-ptr! tail
		mark-queue/count: mark-queue/count + 1
		if mark-queue/count > stats/queue-peak [stats/queue-peak: mark-queue/count]
	]

	;-- Walk the queue to empty. Every mark-* function bottoms out here, so a
	;-- re-entrant caller only queues work while a walk is already running and
	;-- the outermost call is the one that drains. LIFO order keeps the walk
	;-- depth-first, as the recursion was.
	drain-mark-queue: func [
		/local
			value [red-value!]
			tail  [red-value!]
			pos   [ptr-ptr!]
	][
		if walking? [exit]
		walking?: yes
		while [mark-queue/count > 0][
			mark-queue/count: mark-queue/count - 1
			pos: mark-queue/list + (mark-queue/count * 2)
			value: as red-value! pos/value
			pos: pos + 1
			tail: as red-value! pos/value
			walk-values value tail
		]
		walking?: no
	]
	
	mark-context: func [
		ptr		[int-ptr!]
		/local
			ctx  [red-context!]
			slot [red-value!]
			s	 [series!]
			phys [node!]
	][
		;-- flag-gc-mark = buffer reachable; flag-gc-scan = nested deep-marked
		;-- (or deep-mark in progress). Bare keep only sets mark; a later
		;-- mark-context still deep-scans when scan is clear.
		if zero? ptr/value [exit]
		phys: resolve-node ptr/value
		if any [null? phys null? phys/value][exit]
		keep ptr
		s: as series! phys/value
		if s/flags and flag-gc-scan <> 0 [exit]
		s/flags: s/flags or flag-gc-scan				;-- set before nested (cycle break)
		ctx: TO_CTX(ptr/value)							;-- [context! function!|object!]
		slot: as red-value! ctx
		_hashtable/mark ctx/symbols
		unless ON_STACK?(ctx) [mark-block-node :ctx/values]
		mark-values slot + 1 slot + 2				;-- mark the back-reference value (2nd value)
	]

	mark-values: func [
		value [red-value!]
		tail  [red-value!]
	][
		queue-range value tail
		drain-mark-queue
	]

	walk-values: func [
		value [red-value!]
		tail  [red-value!]
		/local
			series	[red-series!]
			obj		[red-object!]
			hash	[red-hash!]
			word	[red-word!]
			path	[red-path!]
			fun		[red-function!]
			routine [red-routine!]
			native	[red-native!]
			ctx		[red-context!]
			img		[red-image!]
			h		[red-handle!]
			len		[integer!]
			type	[integer!]
			evt		[red-event!]
	][
		#if debug? = yes [if verbose > 1 [len: -1 indent: indent + 1]]
		
		while [value < tail][
			#if debug? = yes [if verbose > 1 [
				print "^/"
				loop indent * 4 [print "  "]
				print [TYPE_OF(value) ": "]
			]]
			
			switch TYPE_OF(value) [
				TYPE_WORD 
				TYPE_GET_WORD
				TYPE_SET_WORD 
				TYPE_LIT_WORD
				TYPE_REFINEMENT [
					word: as red-word! value
					if HANDLE?(word/ctx) [
						#if debug? = yes [if verbose > 1 [print-symbol word]]
						either word/symbol = words/self [
							mark-block-node :word/ctx
						][
							mark-context :word/ctx
						]
					]
				]
				TYPE_BLOCK
				TYPE_PAREN
				TYPE_ANY_PATH [
					series: as red-series! value
					if HANDLE?(series/node) [			;-- can happen in routine
						#if debug? = yes [if verbose > 1 [print ["len: " block/rs-length? as red-block! series]]]
						mark-block as red-block! value
					]
				]
				TYPE_SYMBOL [
					series: as red-series! value
					keep :series/extra
					if HANDLE?(series/node) [keep :series/node]
				]
				TYPE_ANY_STRING [
					#if debug? = yes [if verbose > 1 [print as-c-string string/rs-head as red-string! value]]
					series: as red-series! value
					keep :series/node
					if series/extra <> 0 [keep :series/extra]
				]
				TYPE_BINARY
				TYPE_VECTOR
				TYPE_BITSET [
					series: as red-series! value
					keep :series/node
				]
				TYPE_ERROR
				TYPE_PORT
				TYPE_OBJECT [
					#if debug? = yes [if verbose > 1 [print "object"]]
					obj: as red-object! value
					mark-context :obj/ctx
					if HANDLE?(obj/on-set) [mark-block-node :obj/on-set]
				]
				TYPE_CONTEXT [
					#if debug? = yes [if verbose > 1 [print "context"]]
					ctx: as red-context! value
					;keep :ctx/self
					_hashtable/mark ctx/symbols
					unless ON_STACK?(ctx) [mark-block-node :ctx/values]
				]
				TYPE_HASH
				TYPE_MAP [
					#if debug? = yes [if verbose > 1 [print "hash/map"]]
					hash: as red-hash! value
					mark-block-node :hash/node
					_hashtable/mark hash/table		;@@ check if previously marked
				]
				TYPE_FUNCTION
				TYPE_ROUTINE [
					#if debug? = yes [if verbose > 1 [print "function"]]
					fun: as red-function! value
					mark-context :fun/ctx
					mark-block-node :fun/spec
					mark-block-node :fun/more
				]
				TYPE_ACTION
				TYPE_NATIVE
				TYPE_OP [
					native: as red-native! value
					mark-block-node :native/spec
					mark-block-node :native/more
					if TYPE_OF(native) = TYPE_OP [
						type: GET_OP_SUBTYPE(native)
						if any [type = TYPE_FUNCTION type = TYPE_ROUTINE][
							mark-context :native/code
						]
					]
				]
				#if any [OS = 'macOS OS = 'Linux OS = 'Windows][
				TYPE_IMAGE [
					#if debug? = yes [if verbose > 1 [print "image"]]
					img: as red-image! value
					if HANDLE?(img/node) [
						keep :img/node
						image/mark resolve-node img/node
					]
				]]
				TYPE_HANDLE [
					#if debug? = yes [if verbose > 1 [print "handler"]]
					h: as red-handle! value
					if h/extID >= 0 [externals/mark h/extID]
				]
				TYPE_EVENT [									;-- synthetic `make event!` value: msg encodes a stable node handle
					evt: as red-event! value				;-- 00010000h = gui/EVT_FLAG_SYNTHETIC (View's platform.red; raw value here as the collector also compiles in core-only builds)
					if all [(evt/flags and 00010000h) <> 0  evt/msg <> 0][
						mark-block-node :evt/msg
					]
				]
				default [0]
			]
			value: value + 1
		]
		#if debug? = yes [if verbose > 1 [indent: indent - 1]]
	]
	
	mark-block-node: func [
		ptr	[int-ptr!]
		/local
			s	 [series!]
			phys [node!]
	][
		if zero? ptr/value [exit]
		phys: resolve-node ptr/value
		if any [null? phys null? phys/value][exit]
		keep ptr
		s: as series! phys/value
		if s/flags and flag-gc-scan <> 0 [exit]
		s/flags: s/flags or flag-gc-scan				;-- set before nested (cycle break)
		mark-values s/offset s/tail
	]

	mark-block: func [
		blk [red-block!]
	][
		mark-block-node :blk/node
	]

	;-- Resolve an arbitrary pointer inside a managed series allocation to its
	;-- allocator-owned header. Only trusted headers are dereferenced while
	;-- walking from the frame base.
	find-series-owner: func [
		ptr [int-ptr!]
		return: [series!]
		/local
			base [int-ptr!]
			frame [series-frame!]
			big [big-frame!]
			s [series!]
			finish next [byte-ptr!]
	][
		base: frames-list/find-series-frame ptr
		if null? base [return null]
		either frames-list/big-frame? base [
			big: as big-frame! base
			s: as series! ((as byte-ptr! big) + size? big-frame!)
			finish: (as byte-ptr! s) + big/size
		][
			frame: as series-frame! base
			s: as series! ((as byte-ptr! frame) + size? series-frame!)
			finish: as byte-ptr! frame/heap
		]
		while [(as byte-ptr! s) < finish][
			next: (as byte-ptr! s) + (size? series-buffer!) + s/size + SERIES_BUFFER_PADDING
			if all [
				(as int-ptr! s) <= ptr
				ptr < as int-ptr! next
			][return s]
			if any [next <= as byte-ptr! s next > finish][return null]
			s: as series! next
		]
		null
	]

	;-- Retain the series a root points at. `own?` says the root names the series
	;-- header itself; a root that lands inside the buffer only makes that buffer
	;-- reachable, it is not evidence about its cells. Deep-marking from an
	;-- interior hit resurrects every object the stale buffer happens to still
	;-- reference, and by the runtime's own rule a raw buffer pointer is dead at
	;-- the next allocation, so no live object can depend on one.
	mark-series-root: func [
		s     [series!]
		own?  [logic!]									;-- root names the header, not its payload
		return: [logic!]
		/local node [node!] unit [integer!]
	][
		if any [
			null? s
			s/flags and series-in-use = 0
			s/node < 1
			s/node >= node-registry/next
		][return no]
		node: resolve-node s/node
		if any [null? node node/value <> as int-ptr! s][return no]
		keep :s/node
		unit: GET_UNIT(s)
		if all [own? unit = 1][mark-hashtable-node node]
		if all [own? unit = 16 s/flags and flag-gc-scan = 0][
			s/flags: s/flags or flag-gc-scan
			mark-values s/offset s/tail
		]
		yes
	]

	store-stack-ref: func [
		value [int-ptr!]
		sp    [ptr-ptr!]
		refs  [ptr-ptr!]
		return: [ptr-ptr!]
		/local tail new [ptr-ptr!]
	][
		tail: memory/stk-refs + (memory/stk-sz * 2)
		if refs = tail [
			refs: memory/stk-refs
			memory/stk-sz: memory/stk-sz + 1000
			refs: as ptr-ptr! realloc as byte-ptr! refs memory/stk-sz * 2 * size? int-ptr!
			memory/stk-refs: refs
			tail: refs + (memory/stk-sz * 2)
			refs: tail - 2000
		]
		refs/value: value
		new: refs + 1
		new/value: as int-ptr! sp
		refs + 2
	]

	;-- Pointer bitmap slots and the active expression-spill gap are safe to
	;-- rewrite. Resolve conservative spill candidates through an allocator
	;-- header before retaining them, so one live interior pointer does not keep
	;-- every unrelated series in its 2 MiB frame alive.
	;-- `root?` tells the two kinds of slot apart: a declared slot is written by
	;-- the frame that owns it, so what it holds still counts as a reference,
	;-- while the gap below it only carries arguments and spills of calls that
	;-- have already returned. Nobody reads those addresses again, so a gap word
	;-- is recorded for rewriting but cannot root the series it lands in -- doing
	;-- so resurrected everything a completed call had touched. A node pointer is
	;-- a reference in itself, so it roots from either kind of slot.
	mark-stack-candidate: func [
		sp      [ptr-ptr!]
		store?  [logic!]
		root?   [logic!]									;-- slot content is a reference
		refs    [ptr-ptr!]
		return: [ptr-ptr!]
		/local p [int-ptr!] node [node!] s [series!] managed? [logic!] own? [logic!]
	][
		p: sp/value
		if #either any [target = 'X86-64 target = 'ARM64] [
			p <= as int-ptr! FFFFh
		][any [
			p <= as int-ptr! FFFFh
			p >= as int-ptr! FFFFF000h
		]][return refs]
		stats/stack-slots: stats/stack-slots + 1
		if frames-list/find p FRAME_NODES [
			node: as node! p
			if all [
				node/value <> null
				(frames-list/find-series-frame node/value) <> null
			][
				s: find-series-owner node/value
				if all [s <> null node/value = as int-ptr! s][
					keep-raw sp
					mark-series-root s yes
					stats/stack-roots: stats/stack-roots + 1
					return refs
				]
			]
		]
		if all [
			not all [(as byte-ptr! stack/bottom) <= p p <= (as byte-ptr! stack/top)]
			(frames-list/find-series-frame p) <> null
		][
			s: find-series-owner p
			own?: (as int-ptr! s) = p
			managed?: all [s <> null any [not root? mark-series-root s own?]]
			either managed? [
				if store? [refs: store-stack-ref p sp refs]
				stats/stack-roots: stats/stack-roots + 1
			][
				frames-list/pin p
			]
		]
		refs
	]

	mark-pinned-frames: func [
		/local
			p tail [ptr-ptr!]
			base [int-ptr!]
			frame [series-frame!]
			big [big-frame!]
			s [series!]
			finish next [byte-ptr!]
	][
		p: frames-list/pinned/list
		tail: p + frames-list/pinned/count
		while [p < tail][
			base: p/value
			either frames-list/big-frame? base [
				big: as big-frame! base
				s: as series! ((as byte-ptr! big) + size? big-frame!)
				finish: (as byte-ptr! s) + big/size
			][
				frame: as series-frame! base
				s: as series! ((as byte-ptr! frame) + size? series-frame!)
				finish: as byte-ptr! frame/heap
			]
			while [(as byte-ptr! s) < finish][
				next: (as byte-ptr! s) + (size? series-buffer!) + s/size + SERIES_BUFFER_PADDING
				if next > finish [fire [TO_ERROR(internal no-memory)]]
				if s/flags and series-in-use <> 0 [mark-series-root s yes]
				s: as series! next
			]
			p: p + 1
		]
	]

	clear-pinned-series-frame: func [
		frame [series-frame!]
		/local s [series!] finish next [byte-ptr!]
	][
		s: as series! ((as byte-ptr! frame) + size? series-frame!)
		finish: as byte-ptr! frame/heap
		while [(as byte-ptr! s) < finish][
			next: (as byte-ptr! s) + (size? series-buffer!) + s/size + SERIES_BUFFER_PADDING
			if s/flags and series-in-use <> 0 [
				s/flags: s/flags and not (flag-gc-mark or flag-gc-scan)
			]
			s: as series! next
		]
	]

	pinned-frame?: func [frame [int-ptr!] return: [logic!]][
		frames-list/pinned? frame
	]
	
	prepare-series-move: func [						;-- Rewrite headers for a pending series move
		src dst	[byte-ptr!]							;-- source and destination regions
		size	[integer!]
		/local
			s destination [series!]
			tail [byte-ptr!]
			offset [integer!]
	][
		s: as series! src
		destination: as series! dst
		tail: src + size
		until [
			set-node-value s/node as int-ptr! destination	;-- update the node pointer before moving the bytes
			stats/moved-series: stats/moved-series + 1
			stats/moved-bytes:  stats/moved-bytes  + s/size
			offset: as-integer (as byte-ptr! s/offset) - (as byte-ptr! s)
			s/offset: as cell! (as byte-ptr! destination) + offset
			offset: as-integer (as byte-ptr! s/tail) - (as byte-ptr! s)
			s/tail: as cell! (as byte-ptr! destination) + offset
			destination: as series! (as byte-ptr! destination + 1) + s/size + SERIES_BUFFER_PADDING
			s: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
			tail <= as byte-ptr! s
		]
	]

	compact-series-frame: func [						;-- Compact a series frame by moving down in-use series buffer regions
		frame	[series-frame!]							;-- series frame to compact
		refs	[ptr-ptr!]
		return: [ptr-ptr!]								;-- returns the next stack pointer to process
		/local
			tail  [ptr-ptr!]
			ptr	  [ptr-ptr!]
			s	  [series!]
			heap  [series!]
			src	  [byte-ptr!]
			dst	  [byte-ptr!]
			size  [integer!]
			tail? [logic!]
	][
		tail: memory/stk-tail
		s: as series! frame + 1							;-- point to first series buffer
		heap: frame/heap
		src: null										;-- src will point to start of buffer region to move down
		dst: null										;-- dst will point to start of free region

		;assert heap > s
		if heap = s [return refs]

		until [
			tail?: no
			if s/flags and flag-gc-mark = 0 [			;-- check if it starts with a gap
				if dst = null [dst: as byte-ptr! s]
				;probe ["search live from: " s]
				collector/nodes-list/store s/node
				while [									;-- search for a live series
					s: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
					tail?: s >= heap
					not tail?
				][
					either s/flags and flag-gc-mark <> 0 [break][collector/nodes-list/store s/node]
				]
				;probe ["live found at: " s]
			]
			unless tail? [
				src: as byte-ptr! s
				;probe ["search gap from: " s]
				until [									;-- search for a gap
					s/flags: s/flags and not (flag-gc-mark or flag-gc-scan)	;-- clear mark+scan
					s: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
					tail?: s >= heap
					;@@ test tail? first, otherwise s/flags may crash if s = heap
					any [tail? s/flags and flag-gc-mark = 0]
				]
				;probe ["gap found at: " s]
				if dst <> null [
					assert dst < src					;-- regions are moved down in memory
					assert src < as byte-ptr! s 		;-- src should point at least at series - series/size

					size: as-integer (as byte-ptr! s) - src
					;probe ["move src=" src ", dst=" dst ", size=" size]
					prepare-series-move src dst size
					move-memory dst src size

					if refs < tail [					;-- update pointers on native stack
						while [all [refs < tail (as byte-ptr! refs/value) < src]][refs: refs + 2]
						while [all [refs < tail (as byte-ptr! refs/value) < (src + size)]][
							ptr: refs + 1
							ptr: as ptr-ptr! ptr/value
							ptr/value: as int-ptr! (dst + (as-integer (as byte-ptr! ptr/value) - src))
							refs: refs + 2
						]
					]
					dst: dst + size
				]
			]
			tail?
		]
		if dst <> null [								;-- no compaction occurred, all series were in use
			frame/heap: as series! dst					;-- set new heap after last moved region
			#if debug? = yes [markfill as int-ptr! frame/heap as int-ptr! frame/tail]
			if stress? [markfill as int-ptr! frame/heap as int-ptr! frame/tail]
		]
		refs
	]

	cross-compact-frame: func [
		frame	[series-frame!]
		refs	[ptr-ptr!]
		return: [ptr-ptr!]
		/local
			prev	[series-frame!]
			free-sz [integer!]
			tail	[ptr-ptr!]
			ptr		[ptr-ptr!]
			s		[series!]
			ss		[series!]
			heap	[series!]
			src		[byte-ptr!]
			dst		[byte-ptr!]
			prev-dst [byte-ptr!]
			dst2	[byte-ptr!]
			set-cross [subroutine!]
			size	[integer!]
			size2	[integer!]
			tail?	[logic!]
			cross?	[logic!]
			update? [logic!]
	][
		set-cross: [
			either free-sz > 52428 [cross?: yes][		;- 1MB * 5%
				free-sz: 0
				cross?: no
			]
		]
		prev: frame/prev
		if any [
			null? prev									;-- first frame
			frames-list/pinned? as int-ptr! prev		;-- never move into a conservatively pinned frame
		][
			return compact-series-frame frame refs
		]

		prev-dst: as byte-ptr! prev/heap
		free-sz: as-integer prev/tail - prev/heap
		set-cross

		tail: memory/stk-tail
		s: as series! frame + 1							;-- point to first series buffer
		heap: frame/heap
		if heap = s [return refs]

		src: null										;-- src will point to start of buffer region to move down
		dst: null										;-- dst will point to start of free region
		tail?: no

		until [
			if s/flags and flag-gc-mark = 0 [			;-- check if it starts with a gap
				if dst = null [dst: as byte-ptr! s]
				collector/nodes-list/store s/node
				while [									;-- search for a live series
					s: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
					tail?: s >= heap
					not tail?
				][
					either s/flags and flag-gc-mark <> 0 [break][collector/nodes-list/store s/node]
				]
			]
			unless tail? [
				size: 0
				src: as byte-ptr! s
				until [									;-- search for a gap
					s/flags: s/flags and not (flag-gc-mark or flag-gc-scan)	;-- clear mark+scan
					size2: size
					size: SERIES_BUFFER_PADDING + size + s/size + size? series-buffer!
					ss: s								;-- save previous series pointer
					s: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
					tail?: s >= heap
					any [	;@@ test tail? first, otherwise s/flags may crash if s = heap
						tail?	
						all [cross? size >= free-sz]
						s/flags and flag-gc-mark = 0
					]
				]

				update?: yes
				case [
					any [
						size <= free-sz
						all [size2 > 0 size2 <= free-sz]
					][
						if dst = null [dst: src]
						if size > free-sz [
							size: size2
							s: ss
							s/flags: s/flags or flag-gc-mark
							tail?: no
						]
						free-sz: free-sz - size
						set-cross
						dst2: prev-dst
						prev-dst: prev-dst + size
					]
					dst <> null [
						assert dst < src				;-- regions are moved down in memory
						assert src < as byte-ptr! s 	;-- src should point at least at series - series/size

						size: as-integer (as byte-ptr! s) - src
						dst2: dst
						dst: dst + size
					]
					true [
						update?: no
						cross?: no
					]
				]

				if update? [
					;probe ["(x-compact) move src=" src ", dst=" dst2 ", size=" size]
					prepare-series-move src dst2 size
					move-memory dst2 src size
					if refs < tail [			;-- update pointers on native stack
						while [all [refs < tail (as byte-ptr! refs/value) < src]][refs: refs + 2]
						while [all [refs < tail (as byte-ptr! refs/value) < (src + size)]][
							ptr: refs + 1
							ptr: as ptr-ptr! ptr/value
							ptr/value: as int-ptr! (dst2 + (as-integer (as byte-ptr! ptr/value) - src))
							;probe ["(x-compact) update pointer " as int-ptr! refs/1 " on stack at: " ptr]
							refs: refs + 2
						]
					]
				]
			]
			tail?
		]

		prev/heap: as series! prev-dst
		if dst <> null [								;-- no compaction occurred, all series were in use
			frame/heap: as series! dst					;-- set new heap after last moved region
			#if debug? = yes [markfill as int-ptr! frame/heap as int-ptr! frame/tail]
			if stress? [markfill as int-ptr! frame/heap as int-ptr! frame/tail]
		]
		if all [dst = as byte-ptr! (frame + 1) frame/next <> null][		;-- cache last one
			free-series-frame frame
		]
		refs
	]

	encode-dyn-ptr: func [
		stk	    [ptr-ptr!]								;-- native-width stack frame pointer
		typed?  [logic!]								;-- typed or generic variadic function
		return: [integer!]								;-- return a bitmap of pointer slots
		/local
			count i bits [integer!]
			ptr? [logic!]
	][
		#either any [target = 'X86-64 target = 'ARM64] [
			stk: stk - 5
			count: as-integer stk/value				;-- args count
			stk: stk - 1
			stk: as ptr-ptr! stk/value					;-- args pointer
			i: either typed? [2][3]
		][
			stk: stk + 2
			count: as-integer stk/value				;-- args count
			stk: stk + 1
			stk: as ptr-ptr! stk/value					;-- args pointer
			i: 3										;-- skip variadic slots header
		]
		bits: 0
		#if any [target = 'X86-64 target = 'ARM64] [bits: 2] ;-- list is the second formal argument
		either typed? [									;-- typed call (RTTI available)
			assert count <= 9							;-- 32 - 3, divided by 3 slots per argument
			loop count [
				switch as-integer stk/value [			;-- argument type ID
					type-c-string!
					type-byte-ptr!
					type-int-ptr!
					type-struct! [ptr?: yes]
					default		 [ptr?: (as-integer stk/value) >= 1000]
				]
				i: i + 1
				if ptr? [bits: bits or (1 << i)]		;-- mark pointer
				i: i + 2								;-- skip 64-bit slot
			]
			bits
		][												;-- variadic call (no RTTI)
			assert count <= 14							;-- 32 - 3 divided by 2 slots per argument
			#either any [target = 'X86-64 target = 'ARM64] [
				bits or (((1 << count) - 1) << i)
			][
				bits: (1 << (count * 2)) - 1			;-- set bits for all required positions
				bits and 55555555h << i					;-- mask to keep only even positions, offset by i bits
			]
		]
	]

	scan-stack-refs: func [
		store? [logic!]									;-- store series pointers in a list for later eventual update
		/local
			frm slot sp prev [ptr-ptr!]
			sp-address [byte-ptr!]
			map p b base base' head hword [int-ptr!]
			refs tail new entry [ptr-ptr!]
			node [node!]
			c-low c-high lib-low lib-high caller [byte-ptr!]
			s [series!]
			bits slot-bits idx disp nb arg-slots local-slots slots handle h n [integer!]
			hw hbits [integer!]
			depth pinned-before below word [integer!]
			stop [ptr-ptr!]
			gap-word [int-ptr!]
			ext? dyn? in-lib? named? [logic!]
	][
		c-low: system/image/base + system/image/code
		c-high: c-low + system/image/code-size
		#either libRedRT? = yes [
			lib-low: system/lib-image/base + system/lib-image/code
			lib-high: lib-low + system/lib-image/code-size
		][
			in-lib?: no									;-- one image only: every frame reads the program's table
		]
		frm: as ptr-ptr! system/stack/frame
		refs: memory/stk-refs
		nb: 0
		tail: refs + (memory/stk-sz * 2)
		base: bitarrays-base
		base': lib-bitarrays-base						;-- points to libRedRT's bitmap array
		prev: frm
		frm: as ptr-ptr! frm/value						;-- skip extract-stack-refs own frame
		;-- The collector's own frames hold scratch, not references: its locals are
		;-- either permanent roots that phases 1..10 already marked (symbol/table,
		;-- global-ctx) or, in a debug build, declared slots no branch ever wrote.
		;-- The latter still carry whatever a previous call left on that address,
		;-- and conservative scanning turned one into a live object root that kept a
		;-- dead 160 KB block alive for the rest of the process. The frame that
		;-- called the collector owns the last word of that chain, so start above it.
		while [all [frm > prev frm <= gc-frame]][
			prev: frm
			frm: as ptr-ptr! frm/value
		]

		until [
			caller: either any [null? prev  prev = as ptr-ptr! -1  prev >= as ptr-ptr! stk-bottom][null][
				slot: prev + 1
				as byte-ptr! slot/value
			]
		#either libRedRT? = yes [
			;-- A frame running the runtime's own code carries a bitmap index
			;-- into the runtime's table, so remember which image it belongs to.
			in-lib?: all [lib-low < caller caller < lib-high]
			if any [									;-- only process Red frames (skip externals)
				in-lib?
				all [c-low < caller caller < c-high]
			]
		][
			if all [c-low < caller caller < c-high]		;-- only process Red frames (skip externals)
		]
			[
				;-- Both 64-bit backends publish the bitmap offset at the same
				;-- slot: x64's prolog pushes it (push rbp/push catch-id/push
				;-- resume/push bitmap/push 0), ARM64 stores it into its 5-slot
				;-- prefix. IA-32 (upstream-only) shares the x64 position.
				slot: frm - 3							;-- position on bitmap slot
				slot-bits: as-integer slot/value
				if slot-bits = STACK_BITMAP_BARRIER [break]
				assert slot-bits >= 0
				b: either any [
					in-lib?								;-- code from the runtime's own image
					slot-bits and 40000000h <> 0		;-- bitmap explicitly flagged as the runtime's
				][base'][base]							;-- select exe or dll's bitmap array
				map: b + (slot-bits and 0FFFFFFFh)		;-- first corresponding bitmap slot (removing bit flags)
				#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [
					arg-slots: map/value
					map: map + 1
					local-slots: map/value
					map: map + 1
				][
					arg-slots: 0
					local-slots: 0
				]
				head: map								;-- saved head reference for later args bitmap detection
				;-- The record's shape belongs to system/codegen/stack-bitmap.reds:
				;-- two count words, one empty argument word, then the pointer
				;-- stream, then a handle stream over the same slots and just as
				;-- long. So the handle word paired with the pointer word under read
				;-- is exactly `hw` words below it, and the walk needs no other
				;-- knowledge of where the second stream starts.
				#either any [target = 'X86-64 target = 'ARM64] [
					hw: either local-slots = 0 [1][1 + ((local-slots - 1) / 31)]
				][
					hw: 0
				]
				#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [idx: -1][idx: 2] ;-- arguments index
				disp: 1									;-- scanning direction
				loop 2 [									;-- 1st loop: args, 2nd loop: locals
					#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [
						slots: either disp = 1 [arg-slots][local-slots]
					][slots: 0]
					until [
						bits: map/value					;-- read 31 slots bitmap
						ext?: bits and 80000000h <> 0	;-- read extension bit
						bits: bits and 7FFFFFFFh		;-- clear extension bit
						dyn?: no
						if all [
							map = head					;-- only for args bitmaps
							any [bits = 40000000h bits = 20000000h] ;-- variadic/typed function call
						][
							dyn?: yes
							bits: encode-dyn-ptr frm bits = 20000000h ;-- replace bitmap by a dynamic one (32 stack slots only)
							#if any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [slots: 31]
						]
						;-- Root fix: always consume up to 31 bit positions per word
						;-- (or until declared slots are exhausted). Stopping when the
						;-- remaining bit word becomes 0 misaligns idx for multi-word
						;-- bitmaps, so later pointer/handle slots are scanned at the
						;-- wrong stack addresses. That drops live series* from
						;-- stk-refs and fails to mark live handles under GC pressure.
						;-- The handle word covering these same slots: arguments travel
						;-- through the caller's outgoing area, which no record
						;-- describes, so only the locals stream has one to read.
						hbits: 0
						#if any [target = 'X86-64 target = 'ARM64] [
							if disp = -1 [
								hword: map + hw
								hbits: hword/value
							]
						]
						n: 0
						#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [
							while [all [n < 31 (idx + 1) < slots]][
								idx: idx + 1
								n: n + 1
								#either any [target = 'X86-64 target = 'ARM64] [
									sp-address: either disp = -1 [
										(as byte-ptr! frm) - ((5 + arg-slots + idx) * size? pointer!)
									][either all [dyn? idx >= arg-slots] [
										(as byte-ptr! frm) + ((2 + idx - arg-slots) * size? pointer!)
									][
										(as byte-ptr! frm) - ((5 + idx) * size? pointer!)
									]]
									sp: as ptr-ptr! sp-address
									;-- Both tests read the same slot: the bitmap for the handle it declared,
									;-- the probe for whatever else might be one. Neither is allowed to answer
									;-- for the other yet, so the counters below are the only place their
									;-- disagreement is recorded.
									named?: hbits and 1 <> 0
									if named? [stats/handle-bits: stats/handle-bits + 1]
									mark-stack-handle sp named?
									hbits: hbits >>> 1
								][
									#if target = 'IA-32 [
										;-- args: [ebp+8]=frm+2; locals: [ebp-20]=frm-5
										sp: either disp = 1 [frm + 2 + idx][frm - 5 - idx]
										mark-stack-handle sp no
									]
								]
								if bits and 1 <> 0 [	;-- check if the slot is a pointer
									entry: refs
									refs: mark-stack-candidate sp store? yes refs
									if refs <> entry [nb: nb + 1]
								]
								bits: bits >>> 1		;-- next slot flag
							]
						][
							;-- Legacy targets without slot counts: still consume full
							;-- 31-bit words when the extension bit is set so idx stays
							;-- aligned across multi-word bitmaps.
							either ext? [
								loop 31 [
									idx: idx + disp
									if bits and 1 <> 0 [
										sp: frm + idx - 1
										p: sp/value
										if all [
											p > as int-ptr! FFFFh
											p < as int-ptr! FFFFF000h
										][
											node: as node! p
											case [
												all [
													frames-list/find p FRAME_NODES
													node/value <> null
													not frames-list/find node/value FRAME_NODES
													frames-list/find node/value FRAME_SERIES
													keep-raw as ptr-ptr! sp
												][
													p: sp/value
													node: as node! p
													s: as series! node/value
													if GET_UNIT(s) = 16 [mark-values s/offset s/tail]
												]
												all [
													not all [(as byte-ptr! stack/bottom) <= p p <= (as byte-ptr! stack/top)]
													frames-list/find p FRAME_SERIES
												][
													if store? [
														if refs = tail [
															refs: memory/stk-refs
															memory/stk-sz: memory/stk-sz + 1000
															refs: as ptr-ptr! realloc as byte-ptr! refs memory/stk-sz * 2 * size? int-ptr!
															memory/stk-refs: refs
															tail: refs + (memory/stk-sz * 2)
															refs: tail - 2000
														]
														refs/value: p
														new: refs + 1
														new/value: as int-ptr! sp
														refs: refs + 2
														nb: nb + 1
													]
												]
												true [0]
											]
										]
									]
									bits: bits >>> 1
								]
							][
								while [bits <> 0][
									idx: idx + disp
									if bits and 1 <> 0 [
										sp: frm + idx - 1
										p: sp/value
										if all [
											p > as int-ptr! FFFFh
											p < as int-ptr! FFFFF000h
										][
											node: as node! p
											case [
												all [
													frames-list/find p FRAME_NODES
													node/value <> null
													not frames-list/find node/value FRAME_NODES
													frames-list/find node/value FRAME_SERIES
													keep-raw as ptr-ptr! sp
												][
													p: sp/value
													node: as node! p
													s: as series! node/value
													if GET_UNIT(s) = 16 [mark-values s/offset s/tail]
												]
												all [
													not all [(as byte-ptr! stack/bottom) <= p p <= (as byte-ptr! stack/top)]
													frames-list/find p FRAME_SERIES
												][
													if store? [
														if refs = tail [
															refs: memory/stk-refs
															memory/stk-sz: memory/stk-sz + 1000
															refs: as ptr-ptr! realloc as byte-ptr! refs memory/stk-sz * 2 * size? int-ptr!
															memory/stk-refs: refs
															tail: refs + (memory/stk-sz * 2)
															refs: tail - 2000
														]
														refs/value: p
														new: refs + 1
														new/value: as int-ptr! sp
														refs: refs + 2
														nb: nb + 1
													]
												]
												true [0]
											]
										]
									]
									bits: bits >>> 1
								]
							]
						]
						map: map + 1					;-- next 31 slots bitmap
						;-- Stop when no extension, or all declared slots consumed.
						#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [
							any [
								not ext?
								(idx + 1) >= slots
							]
						][
							not ext?
						]
					]
					#either any [target = 'X86-64 target = 'ARM64 target = 'IA-32] [idx: -1][idx: -3] ;-- locals index
					disp: -1							;-- scanning direction
				]
				;-- The gap below the reserved local frame holds this frame's outgoing
				;-- arguments and the spills of calls that have returned. Formal
				;-- local-slots cover only declared locals, so walk the rest -- but
				;-- record it, do not root from it (see mark-stack-candidate), handles
				;-- included.
				;-- Layout (addresses decrease downward): args, frm, fixed, locals, temps, child.
				#if any [target = 'X86-64 target = 'ARM64] [
					sp-address: (as byte-ptr! frm) - ((4 + arg-slots + local-slots) * size? pointer!)
					sp: as ptr-ptr! sp-address
					slot: either all [
						prev <> null
						prev > as ptr-ptr! system/stack/top
						prev < frm
					][prev][as ptr-ptr! system/stack/top]
					;-- The record's trailing word says how far this frame reaches below
					;-- its declared slots, so the walk stops at the frame's own bottom
					;-- instead of at whatever the callee left. A published depth is
					;-- tagged (stack-bitmap/GAP-TAG): a table written before gap words
					;-- offers the argument count of the record after it at that place,
					;-- and that count is always zero, so it reads as nothing published.
					;-- A depth reaching below where the callee's frame starts is refused
					;-- too, so a published bound can only shorten this walk, never
					;-- misplace it.
					gap-word: head + 1 + (hw * 2)
					word: gap-word/value
					below: either (word and 40000000h) <> 0 [word and 3FFFFFFFh][-1]
					stop: either below >= 0 [frm - (4 + arg-slots + local-slots + below)][null]
					either all [stop <> null stop >= slot][
						slot: stop
						stats/gap-bound: stats/gap-bound + 1
					][
						either null? stop [stats/gap-unpub: stats/gap-unpub + 1][
							stats/gap-refused: stats/gap-refused + 1
						]
					]
					depth: 0
					while [sp > slot][
						sp: sp - 1
						depth: depth + 1
						stats/gap-words: stats/gap-words + 1
						entry: refs
						pinned-before: frames-list/pinned/count
						refs: mark-stack-candidate sp store? no refs
						if any [refs <> entry  frames-list/pinned/count > pinned-before][
							if frames-list/pinned/count > pinned-before [stats/gap-pins: stats/gap-pins + 1]
							if refs <> entry [stats/gap-stores: stats/gap-stores + 1]
							nb: nb + 1
							if depth > stats/gap-depth [stats/gap-depth: depth]
						]
					]
					if depth > 0 [
						stats/gap-frames: stats/gap-frames + 1
						if depth > stats/gap-scan [stats/gap-scan: depth]
					]
				]
				#if target = 'IA-32 [
					;-- Full frame body scan for node-handle! only (safe: registry
					;-- validates handles). Do not conservatively treat random stack
					;-- words as node*/series* — false positives corrupt live data.
					sp: frm - 4
					slot: either all [
						prev <> null
						prev > as ptr-ptr! system/stack/top
						prev < frm
					][prev][as ptr-ptr! system/stack/top]
					while [sp > slot][
						sp: sp - 1
						mark-stack-handle sp no
					]
					sp: frm + 1
					idx: 0
					while [all [idx < 64 sp < as ptr-ptr! stk-bottom]][
						sp: sp + 1
						idx: idx + 1
						mark-stack-handle sp no
					]
				]
			]
			prev: frm
			frm: as ptr-ptr! frm/value					;-- jump to next stack frame
			if frm < prev [								;-- if broken frames chain
				slot: prev - 4
				frm: as ptr-ptr! slot/value				;-- use last known parent frame pointer
				if frm < prev [break]
			]
			any [null? frm  frm = as ptr-ptr! -1  frm >= as ptr-ptr! stk-bottom]
		]
		memory/stk-tail: refs

		if all [store? nb > 0][
			qsort as byte-ptr! memory/stk-refs nb (2 * size? int-ptr!) :compare-cb

			;tail: refs
			;refs: memory/stk-refs
			;until [
			;	probe [refs ": [" as int-ptr! refs/1 #":" as int-ptr! refs/2 #"]"]
			;	refs: refs + 2
			;	refs = tail
			;]
		]
	]

	collect-series-frames: func [
		type	  [integer!]
		/local
			frame [series-frame!]
			refs  [ptr-ptr!]
			next  [series-frame!]
	][
		next: null
		refs: null
		frame: memory/s-head
		refs: memory/stk-refs

		until [
			;@@ current frame may be released
			;@@ rare case: the starting address of next frame may be identical to 
			;@@ the tail of the last frame, add 1 to avoid moving
			next: frame/next + 1

			either frames-list/pinned? as int-ptr! frame [
				clear-pinned-series-frame frame
			][either type = COLLECTOR_RELEASE [
				refs: cross-compact-frame frame refs
			][
				refs: compact-series-frame frame refs
			]]
			frame: next - 1
			frame = null
		]
		;#if debug? = yes [					;; enable it once we get a visual exception reporting for panic exits!
		;	frame: memory/s-head
		;	until [
		;		check-series frame
		;		frame: frame/next
		;		frame = null
		;	]
		;]
	]
	
	;-- Forced by RED_GC_STRESS: after a collection, every live series buffer
	;-- in the compacted frames must be pointed back at by its own node, and
	;-- the offset/tail marks must still land inside the buffer. A violation
	;-- means the collector's bookkeeping failed; when a stressed run
	;-- misbehaves while this check passes, the stale pointer is in generated
	;-- or runtime code instead.
	verify-compaction: func [
		/local
			frame [series-frame!]
			big	  [big-frame!]
			s	  [series!]
			heap nxt [series!]
			node  [node!]
			buf	  [byte-ptr!]
	][
		frame: memory/s-head
		until [
			unless frames-list/pinned? as int-ptr! frame [	;-- dead series still laid out there
				s: as series! frame + 1
				heap: frame/heap
				while [s < heap][
					buf: as byte-ptr! s
					nxt: as series! (as byte-ptr! s + 1) + s/size + SERIES_BUFFER_PADDING
					node: resolve-node s/node
					if any [
						null? node
						node/value <> as int-ptr! buf
						(as byte-ptr! s/tail) > as byte-ptr! nxt
						(as byte-ptr! s/offset) < buf
						(as byte-ptr! s/offset) > (as byte-ptr! s/tail)
					][
						print [
							"*** GC verify: broken series header at " buf
							", node " s/node ", size " s/size lf
						]
						quit -1
					]
					s: nxt
				]
			]
			frame: frame/next
			frame = null
		]
		big: memory/b-head
		while [big <> null][
			s: as series! (as byte-ptr! big) + size? big-frame!
			node: resolve-node s/node
			if any [null? node node/value <> as int-ptr! s][
				print ["*** GC verify: broken big series header at " as byte-ptr! s lf]
				quit -1
			]
			big: big/next
		]
	]

	dump-stats: func [									;-- cumulative totals since init (RED_GC_STATS)
		/local buf [c-string!]
	][
		buf: as c-string! allocate 128
		print-line ["^/== GC stats == (RED_GC_STATS)"]
		print-line ["  cycles        : " stats/cycles]
		sprintf [buf "  mark time     : %.1f ms" stats/mark-time * 1000.0]  print-line buf
		sprintf [buf "  scan time     : %.1f ms" stats/scan-time * 1000.0]  print-line buf
		sprintf [buf "  sweep time    : %.1f ms" stats/sweep-time * 1000.0] print-line buf
		sprintf [buf "  total time    : %.1f ms" (stats/mark-time + stats/scan-time + stats/sweep-time) * 1000.0] print-line buf
		print-line ["  moved series  : " stats/moved-series]
		print-line ["  moved bytes   : " stats/moved-bytes]
		print-line ["  stack slots   : " stats/stack-slots]
		print-line ["  stack roots   : " stats/stack-roots]
		print-line ["  handle slots  : " stats/handle-bits " bitmap-named, " stats/probe-roots " probed (" stats/probe-new " nothing else rooted)"]
		print-line ["  probe aliases : " stats/probe-alias " words too wide to be an index"]
		print-line ["  gap slots     : " stats/gap-words " examined over " stats/gap-frames " frames (deepest " stats/gap-scan "), " stats/gap-stores " recorded / " stats/gap-pins " pinned (deepest hit " stats/gap-depth ")"]
		print-line ["  gap bound     : " stats/gap-bound " frames stopped at their own bottom, " stats/gap-refused " refused, " stats/gap-unpub " with no published depth"]
		print-line ["  mark queue    : " stats/queue-peak " ranges peak / " mark-queue/size " allocated"]
		print-line ["  pinned (last) : " stats/pinned-frames " frames / " stats/pinned-bytes " bytes"]
		free as byte-ptr! buf
	]

	do-mark-sweep: func [
			/local
				global-node [node-handle!]
				marker	[ptr-ptr!]
				timed?	[logic!]
				t0 t1 t2 [float!]						;-- phase start stamps (RED_GC_STATS)
				d-mark d-scan d-sweep [float!]			;-- this cycle's phase durations
		#if debug? = yes [
			file	[c-string!]
			saved	[integer!]
			buf		[c-string!]
		]
			cb		[function! []]
	][
		if GC_RUNNING = system/atomic/load :state [exit]
		system/atomic/store :state GC_RUNNING			;-- camera widget relies on threads and reads this value.
		gc-frame: as ptr-ptr! system/stack/frame
		gc-frame: gc-frame/value						;-- skip the collector's own frames when scanning

		timed?: any [stats? verbose > 0]				;-- RED_GC_STATS, or a verbose debug build
		d-mark: 0.0
		d-scan: 0.0
		d-sweep: 0.0
		if timed? [t0: platform/perf-time]

		#if debug? = yes [if verbose > 1 [
			#if OS = 'Windows [platform/dos-console?: no]
			file: "                      "
			sprintf [file "live-values-%d.log" stats/cycles]
			saved: stdout
			stdout: simple-io/open-file file simple-io/RIO_APPEND no
		]]

		#if debug? = yes [
			if verbose > 3 [stack-trace]
			buf: "                                                               "
			if verbose > 0 [print [
				"root: " block/rs-length? root "/" ***-root-size
				", runs: " stats/cycles
				", mem: " 	memory-info null 1
			]]
			if verbose > 1 [probe "^/marking..."]
		]

		;-- A registry slot never moves, so a raw node! that a Red/System local still
		;-- holds names the same buffer across any number of cycles: there is nothing
		;-- left to rewrite, only to reach through. hashtable! names every array it
		;-- owns by a handle, so marking a table reads its header and never writes it
		;-- -- including the two roots below, which hold handles rather than nodes.
		;-- A walk that ended early would leave ranges queued and the next cycle
		;-- marking from a stale stack; marking itself cannot unwind, so this is
		;-- a tripwire rather than a recovery.
		#if debug? = yes [assert mark-queue/count = 0]
		walking?: no
		mark-queue/count: 0

		mark-block root
		#if debug? = yes [if verbose > 1 [probe "marking symbol table"]]
		_hashtable/mark symbol/table			;-- will mark symbols
		#if debug? = yes [if verbose > 1 [probe "marking ownership table"]]
		_hashtable/mark ownership/table

		#if debug? = yes [if verbose > 1 [probe "marking stack"]]
		keep :arg-stk/node
		keep :call-stk/node
		mark-values stack/bottom stack/top
		
		#if debug? = yes [if verbose > 1 [probe "marking globals"]]
			global-node: global-ctx
			mark-context :global-node
		if HANDLE?(interpreter/near/node) [mark-block interpreter/near]
		lexer/mark-buffers
		mark-block-node :references/list/node
		
		#if debug? = yes [if verbose > 1 [probe "marking globals from optional modules"]]
		marker: ext-markers
		while [marker < ext-top][
			if marker/value <> null [					;-- check if not unregistered
				cb: as function! [] marker/value
				cb
			]
			marker: marker + 1
		]
		
		#if debug? = yes [if verbose > 1 [probe "scanning native stack"]]
		frames-list/rebuild								;-- refresh registry chunks and series frames list
		if timed? [t1: platform/perf-time  d-mark: t1 - t0]
		scan-stack-refs yes
		mark-pinned-frames
		if timed? [t2: platform/perf-time  d-scan: t2 - t1]

		#if debug? = yes [if verbose > 1 [probe "sweeping..."]]
		externals/sweep
		_hashtable/sweep resolve-node ownership/table
		collect-series-frames COLLECTOR_RELEASE
		collect-big-frames
		nodes-list/flush
		if timed? [d-sweep: (platform/perf-time) - t2]
	
		;-- unmark fixed series
		unmark root/node
		unmark arg-stk/node
		unmark call-stk/node
		
		stats/cycles: stats/cycles + 1

		if timed? [
			stats/mark-time:  stats/mark-time  + d-mark
			stats/scan-time:  stats/scan-time  + d-scan
			stats/sweep-time: stats/sweep-time + d-sweep
			;-- Print here rather than at exit: a plain executable never reaches
			;-- red/cleanup (only libRed and View do), so an exit hook would
			;-- print nothing. Throttled so per-cycle I/O cannot distort the
			;-- very timings it reports.
			stats-countdown: stats-countdown - 1
			if stats-countdown <= 0 [
				stats-countdown: GC_STATS_PERIOD
				dump-stats
			]
		]

		#if debug? = yes [
			sprintf [buf ", mark: %.1fms, scan: %.1fms, sweep: %.1fms" d-mark * 1000.0 d-scan * 1000.0 d-sweep * 1000.0]
			if verbose > 0 [probe [" => " memory-info null 1 buf]]
			if verbose > 0 [
				print [
					" pinned: " stats/pinned-frames
					" frames / " stats/pinned-bytes " bytes"
				]
			]
			if verbose > 1 [
				simple-io/close-file stdout
				stdout: saved
				#if OS = 'Windows [platform/dos-console?: yes]
			]
			if verbose > 0 [validate]
		]
		if stress? [verify-compaction]
		system/atomic/store :state GC_DONE
	]

	running?: func [return: [logic!]][
		GC_RUNNING = system/atomic/load :state
	]

	do-cycle: does [
		if any [not active? running?][exit]
		do-mark-sweep
	]

	register: func [
		cb [int-ptr!]
		/local p [ptr-ptr!]
	][
		p: ext-markers
		while [p < ext-top][
			if p/value = null [
				p/value: cb
				exit
			]
			p: p + 1
		]
		if ext-top >= (ext-markers + ext-size) [
			fire [TO_ERROR(internal no-memory)]
		]
		ext-top/value: cb
		ext-top: ext-top + 1
	]
	
	unregister: func [cb [int-ptr!] /local p [ptr-ptr!]][
		p: ext-markers
		while [p < ext-top][
			if p/value = cb [p/value: null exit]
			p: p + 1
		]
	]
;comment {	
	#if debug? = yes [
		;== Memory integrity checkings ==
		
		#enum errors! [
			REG_RANGE: 1
			REG_UNBOUND
			REG_FREE_CTRL
		]
		
		messages: protect [
			"free list holds a handle outside the registry range"
			"a handle in the free list is still bound to a buffer"
			"free list length does not match the number of unbound entries"
		]
		
		--assert: func [id [integer!] b [logic!]][
			unless b [
				print-line [
					"^/** Error: "
				messages/id
					"! (" id ")^/stopping..."
				]
				quit -1
			]
		]
		
		check-registry: func [
			verbose [integer!]
			/local
				slot	[ptr-ptr!]
				link	[int-ptr!]
				h handle [integer!]
				free used [integer!]
		][
			if verbose > 0 [print lf]
			
			;-- a handle below `next` has been handed out at least once, so it is
			;-- either bound to a buffer or waiting in the free list
			used: 0
			free: 0
			h: 1
			while [h < node-registry/next][
				slot: registry-slot h
				either null? slot/value [free: free + 1][used: used + 1]
				h: h + 1
			]
			if verbose > 0 [probe ["Registry: " used " bound, " free " unbound"]]
			
			h: node-registry/free
			handle: 0
			while [all [h <> 0 handle <= free]][			;-- bounded: a cycle cannot spin here
				--assert REG_RANGE all [h >= 1 h < node-registry/next]
				slot: registry-slot h
				--assert REG_UNBOUND null? slot/value
				link: registry-link h
				h: link/value
				handle: handle + 1
			]
			--assert REG_FREE_CTRL free = handle
		]
		
		validate: func [
			/local verbosity [integer!]
		][
			verbosity: 0
			print-line "^/== Memory Checks=="
			print "=> node registry checking..."
			check-registry verbosity
			print-line "OK"
		]
		
		; series frames checkings (normal + big)
		;	- frame header sanity checks
		;   - series header checks
		;	- values series header checks
		
		; node registry checkings
		;	- bound entries and free list account for every handed out handle
		;	- free list links name unbound entries only
	
		; check live values validity
		; check all stack slot pointers validity
	
	]
;}
]
