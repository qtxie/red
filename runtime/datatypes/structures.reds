Red/System [
	Title:   "Alias definitions for datatype structures"
	Author:  "Nenad Rakocevic"
	File: 	 %structures.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/red-system/runtime/BSL-License.txt
	}
	Note: {
		Putting all aliases in this file for early inclusion in %red.reds solves
		cross-referencing issues in datatypes definitions.
	}
]

#define red-value!	cell!

red-datatype!: alias struct! [
	header 	[integer!]								;-- cell header
	value	[integer!]								;-- datatype ID
	_pad2	[integer!]
	_pad3	[integer!]
]

red-unset!: alias struct! [
	header 	[integer!]								;-- cell header only, no payload
	_pad1	[integer!]
	_pad2	[integer!]
	_pad3	[integer!]
]

red-none!: alias struct! [
	header 	[integer!]								;-- cell header only, no payload
	_pad1	[integer!]
	_pad2	[integer!]
	_pad3	[integer!]
]

red-logic!: alias struct! [
	header 	[integer!]								;-- cell header
	value	[logic!]								;-- 1: TRUE, 0: FALSE
	_pad1	[integer!]
	_pad2	[integer!]
]

red-series!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- series's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- datatype-specific extra value
]

red-block!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- block's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- (reserved for block-derivative types)
]

red-paren!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- paren's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- (unused, for compatibility with block!)
]

red-path!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- path's head index (zero-based)
	node	[node!]									;-- series node pointer
	args	[node!]									;-- cache for function+refinements args block
]

red-lit-path!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- path's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- (unused, for compatibility with block!)
]

red-set-path!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- path's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- (unused, for compatibility with block!)
]

red-get-path!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- path's head index (zero-based)
	node	[node!]									;-- series node pointer
	extra	[integer!]								;-- (unused, for compatibility with block!)
]

red-string!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-file!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-url!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-tag!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-email!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-binary!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- string's head index (zero-based)
	node	[node!]									;-- series node pointer
	_pad	[integer!]
]

red-bitset!: alias struct! [
	header 	[integer!]								;-- cell header
	_pad1	[integer!]
	node	[node!]									;-- series node pointer
	_pad2	[integer!]
]

red-symbol!: alias struct! [
	header 	[integer!]								;-- cell header
	alias	[integer!]								;-- Alias symbol index
	node	[node!]									;-- string series node pointer
	cache	[node!]									;-- UTF-8 cached version of the string (experimental)
]

red-integer!: alias struct! [
	header 	[integer!]								;-- cell header
	padding	[integer!]								;-- align value on 64-bit boundary
	value	[integer!]								;-- 32-bit signed integer value
	_pad	[integer!]	
]

red-float!: alias struct! [
	header 	[integer!]								;-- cell header
	padding [integer!]
	value	[float!]								;-- 64-bit float value
]

red-float32!: alias struct! [
	header 	[integer!]								;-- cell header
	padding [integer!]
	value	[float32!]								;-- 32-bit float value
	_pad	[integer!]
]

red-context!: alias struct! [
	header 	[integer!]								;-- cell header
	symbols	[node!]									;-- array of symbols ID
	values	[node!]									;-- block of values (do not move this field!)
	self	[node!]									;-- indirect auto-reference (optimization)
]

red-object!: alias struct! [
	header 	[integer!]								;-- cell header
	ctx		[node!]									;-- context reference
	class	[integer!]								;-- class ID
	on-set	[node!]									;-- on-set callback info
]

red-word!: alias struct! [
	header 	[integer!]								;-- cell header
	ctx		[node!]									;-- context reference
	symbol	[integer!]								;-- index in symbol table
	index	[integer!]								;-- index in context
]

red-refinement!: alias struct! [
	header 	[integer!]								;-- cell header
	ctx		[node!]									;-- context reference
	symbol	[integer!]								;-- index in symbol table
	index	[integer!]								;-- index in context
]

red-char!: alias struct! [
	header 	[integer!]								;-- cell header
	_pad1	[integer!]
	value	[integer!]								;-- UCS-4 codepoint
	_pad2	[integer!]	
]

red-point!: alias struct! [
	header 	[integer!]								;-- cell header
	x		[integer!]								;-- stores an integer! or float32! value
	y		[integer!]								;-- stores an integer! or float32! value
	z		[integer!]								;-- stores an integer! or float32! value
]

red-pair!: alias struct! [
	header 	[integer!]								;-- cell header
	padding	[integer!]								;-- align value on 64-bit boundary
	x		[integer!]								;-- 32-bit signed integer or float32!
	y		[integer!]								;-- 32-bit signed integer or float32!
]

red-action!: alias struct! [
	header 	[integer!]								;-- cell header
	args	[node!]									;-- list of typed arguments (including optional ones)
	spec	[node!]									;-- action spec block reference
	code	[integer!]								;-- native code function pointer
]

red-native!: alias struct! [
	header 	[integer!]								;-- cell header
	args	[node!]									;-- list of typed arguments (including optional ones)
	spec	[node!]									;-- native spec block reference
	code	[integer!]								;-- native code function pointer
]

red-op!: alias struct! [
	header 	[integer!]								;-- cell header
	args	[node!]									;-- list of typed arguments
	spec	[node!]									;-- op spec block reference
	code	[integer!]								;-- native code function pointer
]

red-function!: alias struct! [
	header 	[integer!]								;-- cell header
	ctx		[node!]									;-- function's context
	spec	[node!]									;-- native spec block buffer reference
	more	[node!]									;-- additional members storage block:
	;	body	 [red-block!]						;-- 	function's body block
	;	args	 [red-block!]						;-- 	list of typed arguments (including optional ones)
	;	native   [red-native!]						;-- 	JIT-compiled body (binary!)
	;   fun		 [red-function!]					;--		(optional) copy of parent function! value (used by op!)
	;	obj		 [red-context!]						;--		context! pointer for methods
]

red-routine!: alias struct! [
	header   [integer!]								;-- cell header
	ret-type [integer!]								;-- return type (-1 if no return: in spec block)
	spec	 [node!]								;-- routine spec block buffer reference	
	more	 [node!]								;-- additional members storage block:
	;	body	 [red-block!]						;-- 	routine's body block
	;	args	 [red-block!]						;-- 	list of typed arguments (including optional ones)
	;	native   [node!]							;-- 	compiled body (binary!)
	;	fun		 [red-routine!]						;--		(optional) copy of parent routine! value (used by op!)
]

red-typeset!: alias struct! [
	header  [integer!]								;-- cell header
	array1  [integer!]
	array2  [integer!]
	array3  [integer!]
]

red-tuple!: alias struct! [
	header  [integer!]								;-- cell header
	array1  [integer!]
	array2  [integer!]
	array3  [integer!]
]

red-vector!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- vector's head index (zero-based)
	node	[node!]									;-- vector's buffer
	type	[integer!]								;-- vector elements datatype
]

red-hash!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- block's head index (zero-based)
	node	[node!]									;-- series node pointer
	table	[node!]									;-- additional members of hash table
	;	size		[integer!]						;-- 	size of keys
	;	indexes		[node!]							;-- 	optimized: use to refresh hashtable when insert and remove
	;	flags		[node!]
	;	keys		[node!]
	;	blk			[node!]
	;	n-occupied	[integer!]
	;	n-buckets	[integer!]
	;	upper-bound	[integer!]
]

red-event!: alias struct! [
	header	[integer!]								;-- cell header
	type	[integer!]								;-- event category (high 16bit) and event type (low 16bit)
	msg		[byte-ptr!]								;-- low-level OS-specific structure
	flags	[integer!]								;-- bit array
]

red-image!: alias struct! [
	header 	[integer!]								;-- cell header
	head	[integer!]								;-- series's head index (zero-based)
	node	[node!]									;-- internal buffer or platform-specific handle
	size	[integer!]								;-- pair of size
]

red-date!: alias struct! [
	header 	[integer!]								;-- cell header
	date	[integer!]								;-- year:15 (signed), time?:1, month:4, day:5, TZ:7 (5 + 2, signed)
	time	[float!]								;-- 64-bit float, UTC time
]

red-time!: alias struct! [
	header 	[integer!]								;-- cell header
	padding	[integer!]								;-- for compatibility with date!
	time	[float!]								;-- 64-bit float
]

red-handle!: alias struct! [
	header 	[integer!]								;-- cell header
	padding	[integer!]								;-- align value on 64-bit boundary
	value	[integer!]								;-- 32-bit signed integer value
	_pad	[integer!]	
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
#define GOB_FLAG_UPDATE	00100000h

#define GOB_TYPE(gob)	[gob/flags and FFh]

#define coord! float32!

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
	radius		[float32!]			;-- corner radius
	opacity		[integer!]			;-- overall opacity. Effects all children
	border		[gob-style-border! value]
	padding		[gob-style-padding! value]
	text		[gob-style-text! value]
	shadow		[gob-style-shadow!]
]

gob!: alias struct! [				;-- keep the size <= 64 bytes
	flags		[integer!]			;-- type and states
	box			[area! value]		;-- top-left(x1, y1), bottom-right(x2, y2)
	parent		[gob!]				;-- parent gob
	children	[node!]				;-- child gobs, red-vector!
	text-head	[integer!]			;-- head of the text
	text		[node!]				;-- red-string node
	draw-head	[integer!]			;-- head of the draw block
	draw		[node!]				;-- draw block node
	backdrop	[integer!]			;-- background color
	image		[node!]				;-- red-image node
	actors		[red-object!]
	style		[gob-style!]
	extra		[int-ptr!]			;-- extra data for each type
]

red-gob!: alias struct! [
	header	[integer!]
	host	[int-ptr!]				;-- host window handle
	value	[gob!]					;-- low-level gob! pointer
	_pad	[integer!]
]

]