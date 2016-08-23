Red/System [
	Title:	"Delegates are used in controls"
	Author: "Qingtian Xie"
	File: 	%delegates.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

is-flipped: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	return: [logic!]
][
	true
]

get-focus: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	return: [logic!]
][
	make-event self 0 EVT_FOCUS
	yes
]

lost-focus: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	return: [logic!]
][
	make-event self 0 EVT_UNFOCUS
	yes
]

mouse-down: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	event	[integer!]
][
	probe "mouse-down"
]

mouse-up: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	event	[integer!]
][
	probe "mouse-up"
]

print-classname: func [
	obj		[integer!]
	/local
		cls		 [integer!]
		name	 [integer!]
		cls-name [c-string!]
][
	cls: objc_msgSend [obj sel_getUid "class"]
	name: NSStringFromClass cls
	cls-name: as c-string! objc_msgSend [name sel_getUid "UTF8String"]
	?? cls-name
]

on-key-down: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	event	[integer!]
	/local
		res		[integer!]
		key		[integer!]
		flags	[integer!]
][
	key: objc_msgSend [event sel_getUid "keyCode"]
	key: either key >= 80h [0][translate-key key]
	flags: either char-key? as-byte key [0][80000000h]	;-- special key or not
	flags: flags or check-extra-keys event

	res: make-event self key or flags EVT_KEY_DOWN
	if res <> EVT_NO_DISPATCH [
		either flags and 80000000h <> 0 [				;-- special key
			make-event self key or flags EVT_KEY
		][
			key: objc_msgSend [event sel_getUid "characters"]
			if all [
				key <> 0
				0 < objc_msgSend [key sel_getUid "length"]
			][
				key: objc_msgSend [key sel_getUid "characterAtIndex:" 0]
				make-event self key or flags EVT_KEY
			]
		]
	]
	msg-send-super self cmd event
]

on-key-up: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	event	[integer!]
	/local
		key		[integer!]
		flags	[integer!]
][
	key: objc_msgSend [event sel_getUid "keyCode"]
	key: either key >= 80h [0][translate-key key]
	flags: either char-key? as-byte key [0][80000000h]	;-- special key or not
	flags: flags or check-extra-keys event
	make-event self key or flags EVT_KEY_DOWN
	msg-send-super self cmd event
]

button-click: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	sender	[integer!]
	/local
		w		[red-word!]
		values	[red-value!]
		bool	[red-logic!]
		type 	[integer!]
		state	[integer!]
		change? [logic!]
][
	make-event self 0 EVT_CLICK
	values: get-face-values self
	w: as red-word! values + FACE_OBJ_TYPE
	type: symbol/resolve w/symbol
	if any [
		type = check
		type = radio
	][
		bool: as red-logic! values + FACE_OBJ_DATA
		state: objc_msgSend [self sel_getUid "state"]
		change?: either state = -1 [
			type: TYPE_OF(bool)
			bool/header: TYPE_NONE							;-- NONE indicates undeterminate
			bool/header <> type
		][
			change?: bool/value								;-- save the old value
			bool/value: as logic! state
			bool/value <> change?
		]
		if change? [make-event self 0 EVT_CHANGE]
	]
]

slider-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	sender	[integer!]
	/local
		pos		[red-float!]
		val		[float!]
		divisor [float!]
][
	pos: (as red-float! get-face-values self) + FACE_OBJ_DATA

	if all [
		TYPE_OF(pos) <> TYPE_FLOAT
		TYPE_OF(pos) <> TYPE_PERCENT
	][
		percent/rs-make-at as red-value! pos 0.0
	]
	val: objc_msgSend_fpret [self sel_getUid "floatValue"]
	divisor: objc_msgSend_fpret [self sel_getUid "maxValue"]
	pos/value: val / divisor
	make-event self 0 EVT_CHANGE
]

set-selected: func [
	obj [integer!]
	idx [integer!]
	/local
		int [red-integer!]
][
	int: as red-integer! (get-face-values obj) + FACE_OBJ_SELECTED
	int/header: TYPE_INTEGER
	int/value: idx
]

set-text: func [
	obj  [integer!]
	text [integer!]
	/local
		size [integer!]
		str	 [red-string!]
		face [red-object!]
		out	 [c-string!]
][
	size: objc_msgSend [text sel_getUid "length"]
	if size >= 0 [
		str: as red-string! (get-face-values obj) + FACE_OBJ_TEXT
		if TYPE_OF(str) <> TYPE_STRING [
			string/make-at as red-value! str size UCS-2
		]
		if size = 0 [
			string/rs-reset str
			exit
		]
		out: unicode/get-cache str size + 1 * 4			;-- account for surrogate pairs and terminal NUL
		objc_msgSend [text sel_getUid "getCString:maxLength:encoding:" out size + 1 * 2 NSUTF16LittleEndianStringEncoding]
		unicode/load-utf16 null size str no

		face: push-face obj
		if TYPE_OF(face) = TYPE_OBJECT [
			ownership/bind as red-value! str face _text
		]
		stack/pop 1
	]
]

text-did-end-editing: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
][
	make-event self 0 EVT_UNFOCUS
]

text-did-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
][
	set-text self objc_msgSend [self sel_getUid "stringValue"]
	make-event self 0 EVT_CHANGE
]

area-text-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
][
	set-text self objc_msgSend [self sel_getUid "string"]
	make-event self 0 EVT_CHANGE
]

selection-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
	/local
		idx [integer!]
		res [integer!]
][
	res: make-event self 0 EVT_SELECT
	idx: objc_msgSend [self sel_getUid "indexOfSelectedItem"]
	set-selected self idx + 1
	set-text self objc_msgSend [self sel_getUid "itemObjectValueAtIndex:" idx]
	if res = EVT_DISPATCH [
		make-event self 0 EVT_CHANGE
	]
]

number-of-rows: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	obj		[integer!]
	return: [integer!]
	/local
		blk [red-block!]
		head [red-value!]
		tail [red-value!]
		cnt  [integer!]
][
	blk: as red-block! (get-face-values obj) + FACE_OBJ_DATA
	either TYPE_OF(blk) = TYPE_BLOCK [
		head: block/rs-head blk
		tail: block/rs-tail blk
		cnt: 0
		while [head < tail][
			if TYPE_OF(head) = TYPE_STRING [cnt: cnt + 1]
			head: head + 1
		]
		cnt
	][0]
]

object-for-table: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	obj		[integer!]
	column	[integer!]
	row		[integer!]
	return: [integer!]
	/local
		data [red-block!]
		head [red-value!]
		tail [red-value!]
		idx  [integer!]
][
	data: (as red-block! get-face-values obj) + FACE_OBJ_DATA
	head: block/rs-head data
	tail: block/rs-tail data
	idx: -1
	while [all [row >= 0 head < tail]][
		if TYPE_OF(head) = TYPE_STRING [row: row - 1]
		head: head + 1
		idx: idx + 1
	]
	to-NSString as red-string! block/rs-abs-at data idx
]

table-cell-edit: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	obj		[integer!]
	column	[integer!]
	row		[integer!]
	return: [logic!]
][
	no
]

table-select-did-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
	/local
		res [integer!]
][
	res: make-event self 0 EVT_SELECT
	set-selected self 1 + objc_msgSend [self sel_getUid "selectedRow"]
	if res = EVT_DISPATCH [
		make-event self 0 EVT_CHANGE
	]
]

will-finish: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
][
	0
]

destroy-app: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	app		[integer!]
	return: [logic!]
][
	objc_msgSend [NSApp sel_getUid "stop:" 0]
	no
]

win-will-close: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
][
	make-event self 0 EVT_CLOSE
]

win-did-resize: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
	/local
		x	[float!]
		y	[float!]
		w	[float!]
		h	[float!]
][
	;objc_msgSend_stret self sel_getUid "frame"		;return a struct
]

tabview-will-select: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	tabview	[integer!]
	item	[integer!]
][
	probe "will select"
]

;font-line-height: func [
;	hFont	[integer!]
;	return: [float32!]
;	/local
;		leading		[float32!]
;		descender	[float32!]
;		ascender	[float32!]
;		height		[float!]
;		res			[integer!]
;][
;	res: objc_msgSend [objc_getClass "NSLayoutManager" sel_getUid "alloc"]
;	res: objc_msgSend [res sel_getUid "init"]
;	height: objc_msgSend_fpret [res sel_getUid "defaultLineHeightForFont:" hFont]
;dump4 :height
;	?? hFont
;	height: objc_msgSend_fpret [hFont sel_getUid "capHeight"]
;dump4 :height
;dump4 system/stack/top
;	leading: as float32! 10
;?? leading
;	descender: as float32! objc_msgSend [hFont sel_getUid "descender"]
;	ascender: as float32! objc_msgSend [hFont sel_getUid "ascender"]
;?? ascender
;	height: fabs as-float descender
;	as float32! ceil height + ascender + leading
;	as float32! 20
;]

render-text: func [
	values	[red-value!]
	width	[float32!]
	height	[float32!]
	/local
		text	[red-string!]
		font	[red-object!]
		para	[red-object!]
		color	[red-tuple!]
		state	[red-block!]
		int		[red-integer!]
		hFont	[integer!]
		old		[integer!]
		flags	[integer!]
		s		[integer!]
		font-h	[float32!]
		nscolor [integer!]
		attrs	[integer!]
		style	[integer!]
		rc		[NSRect!]
		size	[float!]
][
	text: as red-string! values + FACE_OBJ_TEXT
	if TYPE_OF(text) <> TYPE_STRING [exit]

	nscolor: 0
	font: as red-object! values + FACE_OBJ_FONT
	hFont: either TYPE_OF(font) = TYPE_OBJECT [
		values: object/get-values font
		color: as red-tuple! values + FONT_OBJ_COLOR
		if all [
			TYPE_OF(color) = TYPE_TUPLE
			color/array1 <> 0
		][
			nscolor: to-NSColor color/array1
		]
		state: as red-block! values + FONT_OBJ_STATE
		int: as red-integer! block/rs-head state
		int/value
		;@@ TBD set font attribute
	][
		default-font
	]

	para: as red-object! values + FACE_OBJ_PARA
	flags: either TYPE_OF(para) = TYPE_OBJECT [		;@@ TBD set alignment attribute
		;--get-para-flags base para
		0
	][
		0
	]
	;font-h: font-line-height hFont

	rc: make-rect 0 0 0 0
	rc/w: width
	rc/h: height
	if zero? nscolor [
		nscolor: objc_msgSend [objc_getClass "NSColor" sel_getUid "blackColor"]
	]
	s: to-NSString text
	style: objc_msgSend [objc_getClass "NSParagraphStyle" sel_getUid "defaultParagraphStyle"]
	style: objc_msgSend [style sel_getUid "mutableCopy"]
	;objc_msgSend [style sel_getUid "setAlignment:" NSTextAlignmentCenter]
	attrs: objc_msgSend [objc_getClass "NSDictionary" sel_getUid "alloc"]
	attrs: objc_msgSend [
		attrs sel_getUid "initWithObjectsAndKeys:"
		hFont NSFontAttributeName
		nscolor NSForegroundColorAttributeName
		style NSParagraphStyleAttributeName
		0
	]
	objc_msgSend [s sel_getUid "drawInRect:withAttributes:" rc/x rc/y rc/w rc/h attrs]
]

paint-background: func [
	ctx		[handle!]
	color	[integer!]
	x		[float32!]
	y		[float32!]
	width	[float32!]
	height	[float32!]
	/local
		r	[float32!]
		g	[float32!]
		b	[float32!]
		a	[float32!]
][
	r: (as float32! color and FFh) / 255.0
	g: (as float32! color >> 8 and FFh) / 255.0
	b: (as float32! color >> 16 and FFh) / 255.0
	a: (as float32! 255 - (color >>> 24)) / 255.0
	CGContextSetRGBFillColor ctx r g b a
	CGContextFillRect ctx x y width height
]

draw-rect: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	x		[float32!]
	y		[float32!]
	width	[float32!]
	height	[float32!]
	/local
		ctx  [integer!]
		vals [red-value!]
		img  [red-image!]
		draw [red-block!]
		clr  [red-tuple!]
		size [red-pair!]
		v1010? [logic!]
][
	ctx: objc_msgSend [objc_getClass "NSGraphicsContext" sel_getUid "currentContext"]
	v1010?: as logic! objc_msgSend [ctx sel_getUid "respondsToSelector:" sel_getUid "CGContext"]
	ctx: either v1010? [
		objc_msgSend [ctx sel_getUid "CGContext"]
	][
		objc_msgSend [ctx sel_getUid "graphicsPort"]		;-- deprecated in 10.10
	]

	vals: get-face-values self
	img: as red-image! vals + FACE_OBJ_IMAGE
	draw: as red-block! vals + FACE_OBJ_DRAW
	clr:  as red-tuple! vals + FACE_OBJ_COLOR
	size: as red-pair! vals + FACE_OBJ_SIZE
	if TYPE_OF(clr) = TYPE_TUPLE [
		paint-background as handle! ctx clr/array1 x y width height
	]
	if TYPE_OF(img) = TYPE_IMAGE [
		CG-draw-image as handle! ctx as-integer img/node 0 0 size/x size/y
	]

	render-text vals width height

	do-draw as handle! ctx null draw no yes yes yes
]