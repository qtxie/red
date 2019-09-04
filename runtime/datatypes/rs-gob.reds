Red/System [
	Title:	"R/S Gob implementation"
	Author: "Xie Qingtian"
	File: 	%gob.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

rs-gob: context [
	make-vector: func [
		sz		[integer!]
		return:	[node!]
		/local
			node [node!]
			s	 [series!]
	][
		node: alloc-bytes sz * size? int-ptr!
		s: as series! node/value
		s/flags: s/flags and flag-unit-mask or size? int-ptr!
		node
	]

	vector-insert: func [
		node	[node!]
		ptr		[int-ptr!]
		offset	[integer!]
		return: [series!]
		/local
			s	  [series!]
			p	  [byte-ptr!]
			pp	  [struct! [val [int-ptr!]]]
			unit  [integer!]
	][
		s: as series! node/value
		unit: size? int-ptr!

		if ((as byte-ptr! s/tail) + unit) > ((as byte-ptr! s + 1) + s/size) [
			s: expand-series s 0
		]
		p: (as byte-ptr! s/offset) + (offset << (log-b unit))

		move-memory										;-- make space
			p + unit
			p
			as-integer (as byte-ptr! s/tail) - p

		pp: as struct! [val [int-ptr!]] p
		pp/val: ptr
		s/tail: as cell! (as byte-ptr! s/tail) + unit
		s
	]

	set-flag?: func [
		gob		[gob!]
		flag	[integer!]
		return: [logic!]
	][
		gob/flags and flag <> 0
	]

	get-parent: func [
		gob		[gob!]
		return:	[gob!]
	][
		null
	]

	find-child: func [
		gob		[gob!]
		x		[integer!]
		y		[integer!]
		return: [gob!]
		/local
			g	[gob!]
			p	[int-ptr!]
			n	[integer!]
	][
		n: length? gob
		p: head gob
		loop n [
			g: as gob! p/value
;probe [
;					g/box/x1 " " x " " g/box/x2 lf
;					g/box/y1 " " y " " g/box/y2
;]
			if all [
				g/flags and GOB_FLAG_HIDDEN = 0		;-- visible
				all [
					g/box/x1 <= x x <= g/box/x2
					g/box/y1 <= y y <= g/box/y2
				]
			][
				return g
			]
			p: p + 1
		]
		null
	]

	;-- actions

	insert: func [
		gob		[gob!]
		child	[gob!]
		append?	[logic!]
		/local
			v	[red-vector! value]
	][
		child/parent: gob
		if null? gob/children [gob/children: make-vector 4]
		v/node: gob/children
		if append? [vector/rs-append-int :v as-integer child][
			vector-insert v/node as int-ptr! child 0
		]
	]

	length?: func [
		gob		[gob!]
		return:	[integer!]
		/local
			s	[red-series! value]
	][
		if null? gob/children [return 0]
		s/node: gob/children
		_series/get-length :s yes
	]

	head: func [
		gob		[gob!]
		return: [int-ptr!]
		/local
			v	[red-vector! value]
	][
		assert gob/children <> null
		v/head: 0
		v/node: gob/children
		as int-ptr! vector/rs-head :v
	]
]