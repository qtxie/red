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

#enum event-type! [
	EVT_LEFT_DOWN:		1
	EVT_LEFT_UP
	EVT_MIDDLE_DOWN
	EVT_MIDDLE_UP
	EVT_RIGHT_DOWN
	EVT_RIGHT_UP
	EVT_AUX_DOWN
	EVT_AUX_UP
	EVT_CLICK
	EVT_DBL_CLICK
	EVT_WHEEL
	EVT_OVER								;-- last mouse event

	EVT_KEY
	EVT_KEY_DOWN
	EVT_KEY_UP
	EVT_IME
	EVT_FOCUS
	EVT_UNFOCUS
	EVT_ENTER
	EVT_LEAVE
	
	EVT_ZOOM
	EVT_PAN
	EVT_ROTATE
	EVT_TWO_TAP
	EVT_PRESS_TAP
	
	EVT_SELECT
	EVT_CHANGE
	EVT_MENU
	
	EVT_CLOSE								;-- window events
	EVT_MOVE
	EVT_SIZE
	EVT_MOVING
	EVT_SIZING
	EVT_TIME
	EVT_DRAWING
	EVT_SCROLL
]

#enum gob-part! [
	GOB_PART_NONE:		0
	GOB_PART_TOP:		1
	GOB_PART_LEFT:		2
	GOB_PART_BOTTOM:	4
	GOB_PART_RIGHT:		8
	GOB_PART_FULL:		15
	GOB_PART_INTERNAL:	16
]

;#enum gob-border-style! [
#define	GOB_BORDER_NONE		#"^(00)"
#define	GOB_BORDER_SOLID	#"^(01)"
#define	GOB_BORDER_DOTTED	#"^(02)"
#define	GOB_BORDER_DASHED	#"^(03)"
;]

#enum gob-type! [
	GOB_BASE
	GOB_WINDOW
	GOB_BUTTON
	GOB_LABEL
	GOB_FIELD
	GOB_TEXTAREA
]

#define GOB_FLAG_HOSTED		00010000h
#define GOB_FLAG_HIDDEN		00020000h
#define GOB_FLAG_DISABLE	00040000h
#define GOB_FLAG_DRAG		00080000h
#define GOB_FLAG_ALL_OVER	00100000h
#define GOB_FLAG_UPDATE		00200000h
#define GOB_FLAG_TOP		00400000h

#define GOB_TYPE(gob)	[gob/flags and FFh]

#define coord! float32!

point!: alias struct! [
	x	[coord!]
	y	[coord!]
]

RECT_F!: alias struct! [
	left		[float32!]
	top			[float32!]
	right		[float32!]
	bottom		[float32!]
]

gob-event-fn!: alias function! [
	obj			[int-ptr!]
	evt			[event-type!]
	data		[int-ptr!]
	post?		[logic!]			;-- post the event to the user? 
	return:		[integer!]
]

gob-render-fn!: alias function! [	;-- used to draw the gob on the screen
	obj			[int-ptr!]
	mode		[integer!]
	return:		[logic!]
]

gob-style-border!: alias struct! [
	color		[integer!]
	width		[integer!]
	part		[byte!]				;-- which parts to draw
	opacity		[byte!]
	style		[byte!]				;-- dotted, solid, etc.
]

gob-style-shadow!: alias struct! [
	offset		[point! value]
	color		[integer!]
	radius		[integer!]			;-- blur radius
	part		[byte!]				;-- which parts to draw
	inset?		[byte!]
	next		[gob-style-shadow!]	;-- shadow effect chain
]

gob-style-padding!: alias struct! [
	top			[coord!]
	bottom		[coord!]
	left		[coord!]
	right		[coord!]
]

gob-style-text!: alias struct! [
	color		[integer!]
	select-clr	[integer!]
	font		[int-ptr!]			;-- backend specific font handle
	linespace	[float32!]
	letterspace	[float32!]
	opacity		[byte!]
	align		[byte!]				;-- text align
	shadow		[gob-style-shadow!]
]

gob-style!: alias struct! [
	states		[integer!]
	radius		[float32!]			;-- corner radius
	opacity		[integer!]			;-- overall opacity. Effects all children
	border		[gob-style-border! value]
	padding		[gob-style-padding! value]
	text		[gob-style-text! value]
	shadow		[gob-style-shadow!]
]

gob!: alias struct! [				;-- try to keep size? gob! <= 64 bytes
	flags		[integer!]			;-- type and states
	box			[RECT_F! value]		;-- real size: content size + padding + border width
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, red-vector!
	text-head	[integer!]			;-- head of the text
	text		[node!]				;-- red-string node
	draw-head	[integer!]			;-- head of the draw block
	draw		[node!]				;-- draw block node
	backdrop	[integer!]			;-- background color
	image		[node!]				;-- red-image node
	actors		[red-object!]
	styles		[gob-style!]
	extra		[int-ptr!]			;-- extra data for each type
]

gob-event!: alias struct! [
	gob		[gob!]
	pt		[point! value]
	data	[integer!]
	fdata	[float32!]
]

red-gob!: alias struct! [
	header	[integer!]
	pad		[integer!]
	value	[gob!]					;-- low-level gob! pointer
	_pad	[integer!]
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
			box [RECT_F!]
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
			box [RECT_F!]
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