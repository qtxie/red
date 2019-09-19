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

	update-real-size: func [
		gob		[gob!]
		/local
			ss	[gob-style!]
			x	[float32!]
			y	[float32!]
			box [RECT32!]
	][
		ss: gob/styles
		;-- calc real size
		if ss <> null [
			box: gob/box
			x: as float32! (ss/border/width * 2 + ss/padding/left + ss/padding/right)
			y: as float32! (ss/border/width * 2 + ss/padding/top + ss/padding/bottom)
			box/right: box/right + x
			box/bottom: box/bottom + y
		]
	]

	get-content-size: func [
		gob		[gob!]
		sz		[point!]
		/local
			ss	[gob-style!]
			x	[float32!]
			y	[float32!]
			box [RECT32!]
	][
		ss: gob/styles
		either ss <> null [
			x: as float32! (ss/border/width * 2 + ss/padding/left + ss/padding/right)
			y: as float32! (ss/border/width * 2 + ss/padding/top + ss/padding/bottom)
		][
			x: as float32! 0.0
			y: as float32! 0.0
		]
		sz/x: gob/box/right - gob/box/left - x
		sz/y: gob/box/bottom - gob/box/top - y
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
			s	[series!]
	][
		n: length? gob
		p: tail gob
		loop n [
			p: p - 1
			g: as gob! p/value
			if all [
				g/flags and GOB_FLAG_HIDDEN = 0		;-- visible
				all [
					g/box/left <= x x <= g/box/right
					g/box/top <= y y <= g/box/bottom
				]
			][
				return g
			]
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

	tail: func [
		gob		[gob!]
		return: [int-ptr!]
		/local
			s	[series!]
	][
		either gob/children <> null [
			s: as series! gob/children/value
			as int-ptr! s/tail
		][null]
	]
]