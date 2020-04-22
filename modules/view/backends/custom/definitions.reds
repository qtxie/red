Red/System [
	Title:	"Windows platform GUI imports"
	Author: "Nenad Rakocevic"
	File: 	%win32.red
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

;=== gob definitions ===

#enum gob-event-type! [
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

#enum gob-type! [	;-- basic widgets
	GOB_BASE
	GOB_WINDOW
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
#define GOB_FLAG_AWAY		01000000h
#define GOB_FLAG_FOCUS		02000000h
#define GOB_FLAG_POPUP		04000000h
#define GOB_FLAG_MODAL		08000000h
#define GOB_FLAG_LAYER		10000000h
#define GOB_FLAG_RESIZE		20000000h

#define GOB_TYPE(gob)				[gob/flags and FFh]
#define GOB_SET_FLAG(gob flag)		[gob/flags: gob/flags or flag]
#define GOB_UNSET_FLAG(gob flag)	[gob/flags: gob/flags and (not flag)]

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
	evt			[gob-event-type!]
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

#enum font-style! [
	FONT_STYLE_NORMAL:		0
	FONT_STYLE_ITALIC:		1
	FONT_STYLE_BOLD:		2
	FONT_STYLE_UNDERLINE:	4
	FONT_STYLE_STRIKE:		8
]

#define TEXT_ALIGN_LEFT 		0
#define TEXT_ALIGN_RIGHT 		1
#define TEXT_ALIGN_CENTER 		2
#define TEXT_ALIGN_TOP 			0
#define TEXT_ALIGN_VCENTER		4
#define TEXT_ALIGN_BOTTOM 		8
#define TEXT_WRAP_FLAG	 		20h

gob-style-text!: alias struct! [
	color		 [integer!]
	select-clr	 [integer!]
	font-family	 [node!]
	font-size	 [integer!]
	font-weight	 [integer!]
	font-style	 [font-style!]		;-- italic, bold, underline
	line-space	 [float32!]
	letter-space [float32!]
	opacity		 [float32!]
	align		 [integer!]			;-- text align, wrap?
	shadow		 [gob-style-shadow!]
]

#define GOB_STYLE_BACKDROP 		1
#define GOB_STYLE_BORDER		2
#define GOB_STYLE_TEXT			4
#define GOB_STYLE_SHADOW		8

gob-style!: alias struct! [
	states		[integer!]			;-- each bit indicate whether a property has been set or not
	backdrop	[integer!]			;-- background color
	radius		[float32!]			;-- corner radius
	opacity		[integer!]			;-- overall opacity. Effects all children
	border		[gob-style-border! value]
	padding		[gob-style-padding! value]
	text		[gob-style-text! value]
	shadow		[gob-style-shadow!]
]

gob-cache!: alias struct! [
	txt-fmt		[int-ptr!]
	txt-layout	[int-ptr!]
	bitmap		[int-ptr!]
]

gob!: alias struct! [				;-- size: 84 bytes, 100 bytes with face slot
	flags		[integer!]			;-- type and states
	box			[RECT_F! value]		;-- box = content box + padding + border width
	cbox		[RECT_F! value]		;-- content box 
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, array of gobs
	text		[node!]				;-- red-string node
	draw-head	[integer!]			;-- head of the draw block
	draw		[node!]				;-- draw block node
	backdrop	[integer!]			;-- background color
	image		[node!]				;-- red-image node
	actors		[red-block!]
	styles		[gob-style!]
	anim		[int-ptr!]
	data		[int-ptr!]			;-- extra data for each type
	cache		[gob-cache!]
	#if GUI-engine = 'custom [
	face		[integer!]
	obj-ctx		[node!]
	obj-class	[integer!]
	obj-cb		[node!]
	]
]

#enum animation-flags! [
	ANIM_STOP:		0
	ANIM_PLAYBACK:	1
	ANIM_REPEAT:	2
	ANIM_RUNNING:	4
]

#enum animation-type! [
	ANIM_TYPE_INT32
	ANIM_TYPE_FLOAT32
	ANIM_TYPE_SIZE
	ANIM_TYPE_OFFSET
	ANIM_TYPE_TUPLE
]

anim-property!: alias struct! [
	next		[anim-property!]
	size		[integer!]
	ptr			[int-ptr!]			;-- point to a property of the gob
	sym			[integer!]
	type		[animation-type!]
	duration	[integer!]
	start		[int-ptr!]			;-- start value
	end			[int-ptr!]			;-- end value
]

animation!: alias struct! [
	gob			[gob!]				;-- animation in this gob
	flags		[animation-flags!]			
	exec		[int-ptr!]			;-- anim-function!
	ticks		[integer!]			;-- current animation ticks in ms
	properties	[anim-property!]
]

anim-function!: alias function! [
	anim		[animation!]
]

#define NEW_ANIM_PROPERTY(data-size) [as anim-property! alloc0 data-size + size? anim-property!]

#define ANIM_RESOLUTION 1024
#define ANIM_RES_SHIFT 10

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

#switch OS [
	Windows  [#include %host-win/definitions.reds]
	macOS    [#include %host-mac/definitions.reds]
	#default [#include %host-linux/definitions.reds]		;-- Linux
]

#enum window-flags! [
	;-- show flags
	WIN_FLAG_SHOW:		0
	WIN_FLAG_HIDE:		1
	WIN_FLAG_MIN:		2
	WIN_FLAG_INVISIBLE: 3		;-- HIDE or MIN
	WIN_FLAG_MAX:		4
	WIN_FLAG_INACTIVE:	8
	;-- window type
	WIN_TYPE_POPUP:		10h
	WIN_TYPE_FRAMELESS:	20h
	WIN_TYPE_TOOL:		40h
	WIN_TYPE_TASKBAR:	80h
	;-- render flags
	WIN_RENDER_ALL:		0100h
]

renderer!: alias struct! [
	dc				[this!]
	brushes			[int-ptr!]
	brushes-cnt		[uint!]
	styles			[red-vector!]
	bitmap			[this!]
	swapchain		[this!]
	dcomp-device	[this!]
	dcomp-target	[this!]
	dcomp-visual	[this!]
]

wm!: alias struct! [
	flags		[integer!]
	hwnd		[handle!]
	gob			[gob!]			;-- root gob
	render		[renderer!]
	focused		[gob!]			;-- focused gob in the window
	update-list	[node!]
	matrix		[D2D_MATRIX_3X2_F value]
]

#define IF_GOB_FACE(code) [
	#if GUI-engine = 'custom code
]