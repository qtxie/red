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

#enum gob-part! [
	GOB_PART_NONE:		0
	GOB_PART_TOP:		1
	GOB_PART_LEFT:		2
	GOB_PART_BOTTOM:	4
	GOB_PART_RIGHT:		8
	GOB_PART_FULL:		15
	GOB_PART_INTERNAL:	16
]

#enum gob-type! [
	GOB_BASE
	GOB_WINDOW
	GOB_BUTTON
	GOB_LABEL
	GOB_FIELD
	GOB_TEXTAREA
]

#define GOB_FLAG_HOSTED	00010000h

#define GOB_TYPE(flag)	[flag and FFh]

#define coord!	integer!

point!: alias struct! [
	x	[coord!]
	y	[coord!]
]

area!: alias struct! [
	x1	[coord!]
	y1	[coord!]
	x2	[coord!]
	y2	[coord!]
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
	radius		[integer!]			;-- blur and spread radius
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
	radius		[float32!]
	opacity		[integer!]
	border		[gob-style-border! value]
	padding		[gob-style-padding! value]
	text		[gob-style-text! value]
	shadow		[gob-style-shadow!]
]

gob!: alias struct! [				;-- 64 bytes
	flags		[integer!]			;-- attributes and states
	box			[area! value]		;-- top-left(x1, y1), bottom-right(x2, y2)
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, red-vector!
	event-fn	[gob-event-fn!]		;-- event function
	render-fn	[gob-render-fn!]	;-- render function
	text		[node!]				;-- red-string node
	image		[node!]				;-- red-image node
	draw		[node!]				;-- draw block node
	bg-color	[integer!]			;-- background color
	opacity		[integer!]			;-- overall opacity. Efffects all children
	style		[gob-style!]
	extra		[int-ptr!]
]

rs-gob: context [
	create: func [
		spec	[red-block!]
		return: [gob!]
		/local
			g	[gob!]
	][
		g: as gob! alloc0 size? gob!
		g/flags: GOB_WINDOW
		g
	]

	set-flag?: func [
		gob		[gob!]
		flag	[integer!]
		return: [logic!]
	][
		gob/flags and flag <> 0
	]

	get-type: func [
		gob		[gob!]
		return: [integer!]
	][
		switch GOB_TYPE(gob/flags) [
			0	[gui/base]
			1	[gui/window]
		]
	]

	get-parent: func [
		gob		[gob!]
		return:	[gob!]
	][
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
		if null? gob/children [
			vector/make-at as cell! :v 4 TYPE_INTEGER size? int-ptr!
			gob/children: v/node
		]
		v/node: gob/children
		vector/rs-append-int :v as-integer child
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
		return: [gob!]
		/local
			v	[red-vector! value]
	][
		v/head: 0
		v/node: gob/children
		as gob! vector/rs-head :v
	]
]