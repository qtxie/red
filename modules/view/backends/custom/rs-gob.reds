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

	update-content-box: func [
		gob		[gob!]
		/local
			ss	[gob-style!]
			box [RECT_F!]
			cbox [RECT_F!]
			bd-w [float32!]
	][
		ss: gob/styles
		;-- calc real size
		box: gob/box
		cbox: gob/cbox
		either null? ss [
			cbox/left: box/left
			cbox/right: box/right
			cbox/top: box/top
			cbox/bottom: box/bottom
		][
			bd-w: as float32! ss/border/width
			cbox/left: box/left + bd-w + ss/padding/left
			cbox/right: box/right - bd-w - ss/padding/right
			cbox/top: box/top + bd-w + ss/padding/top
			cbox/bottom: box/bottom - bd-w - ss/padding/bottom 
		]
	]

	set-size: func [
		g			[gob!]
		w			[float32!]
		h			[float32!]
	][
		g/box/right: g/box/left + w
		g/box/bottom: g/box/top + h
		g/cbox/right: g/cbox/left + w
		g/cbox/bottom: g/cbox/top + h
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

	copy-anim: func [
		anim	[animation!]
		return: [animation!]
		/local
			new [animation!]
			p	[anim-property!]
			pp	[anim-property!]
			ppp [anim-property!]
			n	[integer!]
	][
		new: as animation! allocate size? animation!
		copy-memory as byte-ptr! new as byte-ptr! anim size? animation!
		p: anim/properties
		n: 0
		while [p <> null][
			pp: as anim-property! allocate p/size
			copy-memory as byte-ptr! pp as byte-ptr! p p/size
			either zero? n [new/properties: pp n: 1][ppp/next: pp]
			p: p/next
			ppp: pp
		]
		new
	]

	;-- actions

	clear: func [
		gob		[gob!]
	][
		if gob/children <> null [array/clear gob/children]
	]

	copy: func [
		gob		[gob!]
		return: [gob!]
		/local
			g	[gob!]
			a	[animation!]
	][
		g: as gob! allocate size? gob!
		copy-memory as byte-ptr! g as byte-ptr! gob size? gob!
		g/flags: g/flags or GOB_FLAG_COW_STYLES
		if g/children <> null [g/children: array/copy g/children]
		if g/anim <> null [
			a: copy-anim as animation! g/anim
			a/gob: g
			g/anim: as int-ptr! a
		]
		
		if all [
			gob/data <> null
			GOB_TYPE(gob) <> GOB_WINDOW
		][
			g/data: as int-ptr! allocate size? red-value!
			actions/copy 
				as red-series! gob/data
				as red-value! g/data
				null
				yes
				null
		]
		g
	]

	insert: func [
		gob		[gob!]
		child	[gob!]
		append?	[logic!]
	][
		child/parent: gob
		if null? gob/children [gob/children: array/make 4 size? int-ptr!]
		either append? [array/append-ptr gob/children as int-ptr! child][
			array/insert-ptr gob/children as int-ptr! child 0
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