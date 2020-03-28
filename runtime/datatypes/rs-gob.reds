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
	EVT_DBL_CLICK
	EVT_RIGHT_DOWN
	EVT_RIGHT_UP
	EVT_RIGHT_DBL_CLICK
	EVT_MIDDLE_DOWN
	EVT_MIDDLE_UP
	EVT_MIDDLE_DBL_CLICK
	EVT_WHEEL
	EVT_AUX_DOWN
	EVT_AUX_UP
	EVT_AUX_DBL_CLICK
	EVT_CLICK
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
#define GOB_FLAG_COW_STYLES	00800000h		;-- copy-on-write styles

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
	spread		[integer!]
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

;gob-style-font!: alias struct! [
;	family		[c-string!]
;	size		[integer!]
;	weight		[integer!]
;	style		[integer!]			;-- italic, bold, underline
;]

gob-style-text!: alias struct! [
	color		 [integer!]
	select-clr	 [integer!]
	;font		 [gob-style-font! value]
	font-family	 [c-string!]
	font-size	 [integer!]
	font-weight	 [integer!]
	font-style	 [integer!]			;-- italic, bold, underline
	line-space	 [float32!]
	letter-space [float32!]
	opacity		 [byte!]
	align		 [byte!]			;-- text align
	shadow		 [gob-style-shadow!]
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

gob!: alias struct! [				;-- size: 80 bytes, 96 bytes with face slot
	flags		[integer!]			;-- type and states
	box			[RECT_F! value]		;-- box = content box + padding + border width
	cbox		[RECT_F! value]		;-- content box 
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, array of gobs
	font		[int-ptr!]			;-- backend specific font handle
	text		[node!]				;-- red-string node
	draw-head	[integer!]			;-- head of the draw block
	draw		[node!]				;-- draw block node
	backdrop	[integer!]			;-- background color
	image		[node!]				;-- red-image node
	actors		[red-block!]
	styles		[gob-style!]
	data		[int-ptr!]			;-- extra data for each type
	#if GUI-engine = 'custom [
	face		[integer!]
	obj-ctx		[node!]
	obj-class	[integer!]
	obj-cb		[node!]
	]
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
	][
		g: as gob! allocate size? gob!
		copy-memory as byte-ptr! g as byte-ptr! gob size? gob!
		g/flags: g/flags or GOB_FLAG_COW_STYLES
		if g/children <> null [g/children: array/copy g/children]
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