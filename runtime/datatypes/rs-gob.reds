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
		x		[float32!]
		y		[float32!]
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
		if null? gob/children [gob/children: array/make 4 size? int-ptr!]
		v/node: gob/children
		either append? [vector/rs-append-int :v as-integer child][
			array/insert-ptr v/node as int-ptr! child 0
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
		either gob/children <> null [
			v/head: 0
			v/node: gob/children
			as int-ptr! vector/rs-head :v
		][null]
	]
]