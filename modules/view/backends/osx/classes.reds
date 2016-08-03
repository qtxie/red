Red/System [
	Title:	"Windows classes handling"
	Author: "Qingtian Xie"
	File: 	%classes.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

add-method!: alias function! [class [integer!]]

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
	/local
		res [integer!]
][
	res: make-event self 0 EVT_CLOSE
]

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
][
	text: as red-string! values + FACE_OBJ_TEXT
	if TYPE_OF(text) <> TYPE_STRING [exit]

	font: as red-object! values + FACE_OBJ_FONT
	hFont: either TYPE_OF(font) = TYPE_OBJECT [
		values: object/get-values font
		color: as red-tuple! values + FONT_OBJ_COLOR
		if all [
			TYPE_OF(color) = TYPE_TUPLE
			color/array1 <> 0
		][
			0		;@@ TBD set text color attribute
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
	font-h: as float32! objc_msgSend [hFont sel_getUid "lineSize"]
	
	s: to-NSString text
	;@@ TBD draw string
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
	r: as float32! (as-float color and FFh) / 255.0
	g: as float32! (as-float color >> 8 and FFh) / 255.0
	b: as float32! (as-float color >> 16 and FFh) / 255.0
	a: as float32! (as-float 255 - (color >>> 24)) / 255.0
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

	render-text vals width height

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
	do-draw as handle! ctx null draw no yes yes yes
]

add-base-handler: func [class [integer!]][
	flipp-coord class
	class_addMethod class sel_getUid "drawRect:" as-integer :draw-rect "v@:{_NSRect=ffff}"
]

add-window-handler: func [class [integer!]][
	class_addMethod class sel_getUid "mouseDown:" as-integer :mouse-down "v@:@"
	class_addMethod class sel_getUid "mouseUp:" as-integer :mouse-up "v@:@"
	class_addMethod class sel_getUid "keyDown:" as-integer :on-key-down "v@:@"
	class_addMethod class sel_getUid "keyUp:" as-integer :on-key-up "v@:@"
	class_addMethod class sel_getUid "windowWillClose:" as-integer :win-will-close "v12@0:4@8"
]

add-button-handler: func [class [integer!]][
	class_addMethod class sel_getUid "button-click:" as-integer :button-click "v@:@"
]

add-slider-handler: func [class [integer!]][
	class_addMethod class sel_getUid "slider-change:" as-integer :slider-change "v@:@"
]

add-text-field-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :text-did-change "v@:@"
	class_addMethod class sel_getUid "textDidEndEditing:" as-integer :text-did-end-editing "v@:@"
	class_addMethod class sel_getUid "becomeFirstResponder" as-integer :get-focus "B@:"
]

add-area-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :area-text-change "v@:@"
]

add-combo-box-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :text-did-change "v@:@"
	class_addMethod class sel_getUid "comboBoxSelectionDidChange:" as-integer :selection-change "v@:@"
]

add-app-delegate: func [class [integer!]][
	class_addMethod class sel_getUid "applicationWillFinishLaunching:" as-integer :will-finish "v12@0:4@8"
	class_addMethod class sel_getUid "applicationShouldTerminateAfterLastWindowClosed:" as-integer :destroy-app "B12@0:4@8"
]

flipp-coord: func [class [integer!]][
	class_addMethod class sel_getUid "isFlipped" as-integer :is-flipped "B@:"
]

make-super-class: func [
	new		[c-string!]
	base	[c-string!]
	method	[integer!]				;-- override functions or add functions
	store?	[logic!]
	return:	[integer!]
	/local
		new-class	[integer!]
		add-method	[add-method!]
][
	new-class: objc_allocateClassPair objc_getClass base new 0
	if store? [						;-- add an instance value to store red-object!
		class_addIvar new-class IVAR_RED_FACE 16 2 "{red-face=iiii}"
	]
	unless zero? method [
		add-method: as add-method! method
		add-method new-class
	]
	objc_registerClassPair new-class
]

register-classes: does [
	make-super-class "RedAppDelegate"	"NSObject"		as-integer :add-app-delegate	no
	make-super-class "RedView"			"NSView"		as-integer :flipp-coord			no
	make-super-class "RedBase"			"NSView"		as-integer :add-base-handler	yes
	make-super-class "RedWindow"		"NSWindow"		as-integer :add-window-handler	yes
	make-super-class "RedButton"		"NSButton"		as-integer :add-button-handler	yes
	make-super-class "RedSlider"		"NSSlider"		as-integer :add-slider-handler	yes
	make-super-class "RedTextField"		"NSTextField"	as-integer :add-text-field-handler yes
	make-super-class "RedTextView"		"NSTextView"	as-integer :add-area-handler yes
	make-super-class "RedComboBox"		"NSComboBox"	as-integer :add-combo-box-handler yes
	make-super-class "RedScrollView"	"NSScrollView"	0	yes
	make-super-class "RedBox"			"NSBox"			0	yes
]
