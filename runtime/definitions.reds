Red/System [
	Title:   "Red runtime library definitions"
	Author:  "Nenad Rakocevic"
	File: 	 %definitions.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2016-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

;=== Memory allocator definitions ===

#define _512KB				524288
#define _1MB				1048576
#define _2MB				2097152
#define _16MB				16777216
#define nodes-per-frame		10000
#define node-frame-size		[((nodes-per-frame * 2 * size? pointer!) + size? node-frame!)]

#define series-in-use		80000000h		;-- mark a series as used (not collectable by the GC)
#define flag-ins-both		30000000h		;-- optimize for both head & tail insertions
#define flag-ins-tail		20000000h		;-- optimize for tail insertions
#define flag-ins-head		10000000h		;-- optimize for head insertions
#define flag-gc-mark		08000000h		;-- mark as referenced for the GC (mark phase)
#define flag-series-big		01000000h		;-- 1 = big, 0 = series
#define flag-series-small	00800000h		;-- series <= 16 bytes
#define flag-series-stk		00400000h		;-- values block allocated on stack
#define flag-series-nogc	00200000h		;-- protected from GC (system-critical series)
#define flag-series-fixed	00100000h		;-- series cannot be relocated (system-critical series)
#define flag-bitset-not		00080000h		;-- complement flag for bitsets
#define flag-UTF16-cache	00040000h		;-- UTF-16 encoding for string cache buffer
#define flag-series-owned	00020000h		;-- series is owned by an object
#define flag-owned			00010000h		;-- cell is owned by an object. (for now only image! use it)
#define flag-owner			00010000h		;-- object is an owner (carried by object's context value)
#define flag-native-op		00010000h		;-- operator is made from a native! function
#define flag-extern-code	00008000h		;-- routine's body is from FFI

#define flag-new-line		40000000h		;-- if set, indicates that a new-line preceeds the value
#define flag-nl-mask		BFFFFFFFh		;-- mask for new-line flag
#define flag-arity-mask		C1FFFFFFh		;-- mask for reading routines arity field
#define flag-self-mask		01000000h		;-- mask for self? flag
#define body-flag			00800000h		;-- flag for op! body node
#define tuple-size-mask		00780000h		;-- mask for reading tuple size field
#define flag-unit-mask		FFFFFFE0h		;-- mask for reading unit field in series-buffer!
#define get-unit-mask		0000001Fh		;-- mask for setting unit field in series-buffer!
#define series-free-mask	7FFFFFFFh		;-- mark a series as used (not collectable by the GC)
#define flag-not-mask		FFF7FFFFh		;-- mask for complement flag

#define type-mask			FFFFFF00h		;-- mask for clearing type ID in cell header
#define get-type-mask		000000FFh		;-- mask for reading type ID in cell header
#define node!				int-ptr!
#define default-offset		-1				;-- for offset value in alloc-series calls

#define series!				series-buffer! 
#define handle!				[pointer! [integer!]]

;== platform-specific definitions ==

#include %platform/definitions.reds

;=== Unicode support definitions ===

#enum encoding! [
	UTF-16LE:	-1
	UTF-8:		 0
	Latin1:		 1
	UCS-2:		 2
	UCS-4:		 4
]

;== Image definitions ===

#enum extract-type! [
	EXTRACT_ALPHA
	EXTRACT_RGB
	EXTRACT_ARGB
]

;== Draw Context definitions ==

#if OS = 'macOS [
	CGAffineTransform!: alias struct! [
		a		[float32!]
		b		[float32!]
		c		[float32!]
		d		[float32!]
		tx		[float32!]
		ty		[float32!]
	]

	draw-ctx!: alias struct! [
		raw				[int-ptr!]					;-- OS drawing object: CGContext
		matrix          [CGAffineTransform! value]
		pen-join		[integer!]
		pen-cap			[integer!]
		pen-width		[float32!]
		pen-style		[integer!]
		pen-color		[integer!]					;-- 00bbggrr format
		brush-color		[integer!]					;-- 00bbggrr format
		font-attrs		[integer!]
		colorspace		[integer!]
		grad-pen		[integer!]
		grad-type		[integer!]
		grad-spread		[integer!]
		grad-x1			[float32!]
		grad-y1			[float32!]
		grad-x2			[float32!]
		grad-y2			[float32!]
		grad-radius		[float32!]
		grad-pos?		[logic!]
		grad-pen?		[logic!]
		grad-brush?		[logic!]
		pen?			[logic!]
		brush?			[logic!]
		on-image?		[logic!]					;-- drawing on image?
		rect-y			[float32!]
		pattern-blk		[int-ptr!]
		pattern-mode	[integer!]
		pattern-ver		[integer!]
		pattern-draw	[integer!]
		pattern-release [integer!]
		pattern-w		[float32!]
		pattern-h		[float32!]
		last-pt-x		[float32!]					;-- below used by shape
		last-pt-y		[float32!]
		control-x		[float32!]
		control-y		[float32!]
		path			[integer!]
		shape-curve?	[logic!]
	]
]

#if OS = 'Windows [
	gradient!: alias struct! [
		extra           [integer!]                              ;-- used when pen width > 1
		path-data       [PATHDATA]                              ;-- preallocated for performance reasons
		points-data     [tagPOINT]                              ;-- preallocated for performance reasons
		matrix			[integer!]
		colors			[int-ptr!]
		colors-pos		[float32-ptr!]
		spread			[integer!]
		type            [integer!]                              ;-- gradient on fly (just before drawing figure)
		count           [integer!]                              ;-- gradient stops count
		data            [tagPOINT]                              ;-- figure coordinates
		positions?      [logic!]                                ;-- true if positions are defined, false otherwise
		created?        [logic!]                                ;-- true if gradient brush created, false otherwise
		transformed?	[logic!]								;-- true if transformation applied
	]

	curve-info!: alias struct! [
		type    [integer!]
		control [tagPOINT]
	]

	arcPOINTS!: alias struct! [
		start-x     [float!]
		start-y     [float!]
		end-x       [float!]
		end-y       [float!]
	]

	other!: alias struct! [
		gradient-pen			[gradient!]
		gradient-fill			[gradient!]
		gradient-pen?			[logic!]
		gradient-fill?			[logic!]
		matrix-elems			[float32-ptr!]		;-- elements of matrix allocated in draw-begin for performance reason
		paint					[tagPAINTSTRUCT]
		edges					[tagPOINT]					;-- polygone edges buffer
		types					[byte-ptr!]					;-- point type buffer
		last-point?				[logic!]
		path-last-point			[tagPOINT]
		prev-shape				[curve-info!]
		connect-subpath			[integer!]
		matrix-order			[integer!]
		anti-alias?				[logic!]
		GDI+?					[logic!]
		D2D?					[logic!]
		pattern-image-fill		[integer!]
		pattern-image-pen		[integer!]
	]

	draw-ctx!: alias struct! [
		dc				[int-ptr!]								;-- OS drawing object
		hwnd			[int-ptr!]								;-- Window's handle
		pen				[integer!]
		brush			[integer!]
		pen-join		[integer!]
		pen-cap			[integer!]
		pen-width		[float32!]
		pen-style		[integer!]
		pen-color		[integer!]								;-- 00bbggrr format
		brush-color		[integer!]								;-- 00bbggrr format
		font-color		[integer!]
		bitmap			[int-ptr!]
		brushes			[int-ptr!]
		graphics		[integer!]								;-- gdiplus graphics
		gp-state		[integer!]
		gp-pen			[integer!]								;-- gdiplus pen
		gp-pen-type 	[brush-type!]							;-- gdiplus pen type (for texture, another set of transformation functions must be applied)
		gp-pen-saved	[integer!]
		gp-brush		[integer!]								;-- gdiplus brush
		gp-brush-type 	[brush-type!]							;-- gdiplus brush type (for texture, another set of transformation functions must be applied)
		gp-font			[integer!]								;-- gdiplus font
		gp-font-brush	[integer!]
		gp-matrix		[integer!]
		gp-path			[integer!]
		image-attr		[integer!]								;-- gdiplus image attributes
		scale-ratio		[float32!]
		pen?			[logic!]
		brush?			[logic!]
		on-image?		[logic!]								;-- drawing on image?
		alpha-pen?		[logic!]
		alpha-brush?	[logic!]
		font-color?		[logic!]
		other 			[other!]
	]
]

;=== Image definitions ===

#enum image-format! [
	IMAGE_BMP
	IMAGE_PNG
	IMAGE_GIF
	IMAGE_JPEG
	IMAGE_TIFF
]

;=== GOB! definitions ===

#if modules contains 'View [
	
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

#enum gob-type! [
	GOB_BASE
	GOB_WINDOW
	GOB_BUTTON
	GOB_LABEL
	GOB_FIELD
	GOB_TEXTAREA
]

#define GOB_FLAG_HOSTED	00010000h
#define GOB_FLAG_HIDDEN 00020000h
#define GOB_FLAG_TOP	00040000h
#define GOB_FLAG_DRAG	00080000h

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

]