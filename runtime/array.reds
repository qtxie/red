Red/System [
	Title:   "Integer and Pointer array"
	Author:  "Xie Qingtian"
	File: 	 %array.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

array: context [

	make: func [
		sz		[integer!]
		unit	[integer!]
		return:	[node!]
		/local
			node [node!]
			s	 [series!]
	][
		node: alloc-bytes sz * unit
		s: as series! node/value
		s/flags: s/flags and flag-unit-mask or unit
		node
	]

	length?: func [
		node	[node!]
		return: [integer!]
		/local
			s	[series!]
	][
		s: as series! node/value
		as-integer s/tail - s/offset
	]

	clear: func [
		node	[node!]
		/local
			s	[series!]
	][
		s: as series! node/value
		s/offset: s/tail
	]

	copy: func [
		node	[node!]
		return: [node!]
	][
		copy-series as series! node/value
	]

	append-int: func [
		node	[node!]
		val		[integer!]
		/local
			s	[series!]
			p	[int-ptr!]
	][
		s: as series! node/value
		p: as int-ptr! alloc-tail-unit s size? integer!
		p/value: val
	]

	find-int: func [
		node	[node!]
		val		[integer!]
		return: [integer!]		;-- return offset if found, -1 if not found
		/local
			s	[series!]
			p	[int-ptr!]
			pp	[int-ptr!]
			e	[int-ptr!]
	][
		s: as series! node/value
		p: as int-ptr! s/offset
		e: as int-ptr! s/tail
		pp: p
		while [p < e][
			if p/value = val [
				return as-integer p - pp
			]
			p: p + 1
		]
		-1
	]

	pick-int: func [
		node		[node!]
		idx			[integer!]		;-- 0-based index
		return:		[integer!]
		/local
			s		[series!]
			p		[int-ptr!]
	][
		s: as series! node/value
		p: as int-ptr! s/offset
		assert p + idx < as int-ptr! s/tail
		idx: idx + 1
		p/idx
	]

	append-ptr: func [
		node	[node!]
		val		[int-ptr!]
		/local
			s	[series!]
			p	[ptr-ptr!]
	][
		s: as series! node/value
		p: as ptr-ptr! alloc-tail-unit s size? int-ptr!	
		p/value: val
	]

	insert-ptr: func [
		node		[node!]
		ptr			[int-ptr!]
		offset		[integer!]
		/local
			s		[series!]
			p		[byte-ptr!]
			pp		[ptr-ptr!]
			unit	[integer!]
	][
		s: as series! node/value
		unit: size? int-ptr!

		if ((as byte-ptr! s/tail) + unit) > ((as byte-ptr! s + 1) + s/size) [
			s: expand-series s 0
		]
		p: (as byte-ptr! s/offset) + (offset << (log-b unit))

		move-memory		;-- make space
			p + unit
			p
			as-integer (as byte-ptr! s/tail) - p

		pp: as ptr-ptr! p
		pp/value: ptr
		s/tail: as cell! (as byte-ptr! s/tail) + unit
	]

	pick-ptr: func [
		node		[node!]
		idx			[integer!]		;-- 0-based index
		return:		[int-ptr!]
		/local
			s		[series!]
			p		[ptr-ptr!]
	][
		s: as series! node/value
		p: as ptr-ptr! s/offset
		p: p + idx
		assert p < as ptr-ptr! s/tail
		p/value
	]

	poke-ptr: func [
		node		[node!]
		idx			[integer!]		;-- 0-based index
		val			[int-ptr!]
		/local
			s		[series!]
			p		[ptr-ptr!]
	][
		s: as series! node/value
		p: as ptr-ptr! s/offset
		p: p + idx
		assert p < as ptr-ptr! s/tail
		p/value: val
	]

	find-ptr: func [
		node	[node!]
		val		[int-ptr!]
		return: [integer!]		;-- return offset if found, -1 if not found
		/local
			s	[series!]
			p	[ptr-ptr!]
			pp	[ptr-ptr!]
			e	[ptr-ptr!]
	][
		s: as series! node/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		pp: p
		while [p < e][
			if p/value = val [
				return as-integer p - pp
			]
			p: p + 1
		]
		-1
	]

	remove-ptr: func [
		node	[node!]
		val		[int-ptr!]
		/local
			n	[integer!]
	][
		n: find-ptr node val
		if n <> -1 [remove-at node n size? int-ptr!]
	]

	remove-at: func [
		node	[node!]
		offset	[integer!]			;-- bytes
		len		[integer!]			;-- bytes
		/local
			s	[series!]
			p	[byte-ptr!]
	][
		s: as series! node/value

		p: (as byte-ptr! s/offset) + offset

		assert p + len <= (as byte-ptr! s/tail)

		move-memory
			p
			p + len
			as-integer (as byte-ptr! s/tail) - (p + len)

		s/tail: as cell! (as byte-ptr! s/tail) - len
	]
]