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

gob-event-fn!: alias function! [
	obj			[gob!]
	evt			[gob-event!]
	data		[int-ptr!]
	post?		[logic!]			;-- post the event to the user? 
	return:		[integer!]
]

gob-render-fn!: alias function! [	;-- used to draw the gob on the screen
	obj			[gob!]
	mode		[integer!]
	return:		[logic!]
]

gob-style-border!: alias struct! [
	color		[integer!]
	width		[integer!]
	part		[byte!]				;-- which parts to draw
	opacity		[byte!]
]

gob-style-shadow!: alias struct! [
	offset		[point!]
	color		[integer!]
	radius		[integer!]			;-- blur and spread radius
	part		[byte!]				;-- which parts to draw
	inset?		[byte!]
]

gob-style-padding!: alias struct! [
	top			[coord!]
	bottom		[coord!]
	left		[coord!]
	right		[coord!]
	inner		[coord!]
]

gob-style!: alias struct! [
	bg-color	[integer!]			;-- background color
	radius		[float32!]
	opacity		[integer!]
	border		[gob-style-border! vaule]
	shadow		[gob-style-shadow! value]
	padding		[gob-style-padding! value]
]

gob!: alias struct! [
	flags		[integer!]			;-- attributes and states
	coords		[area!]				;-- top-left(x1, y1), bottom-right(x2, y2)
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, red-vector!
	event-fn	[gob-event-fn!]		;-- event function
	render-fn	[gob-render-fn!]	;-- render function
	opacity		[integer!]			;-- overall opacity. Efffects all children
	style		[gob-style!]
]

