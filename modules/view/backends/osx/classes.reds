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

text-did-change: func [
	[cdecl]
	self	[integer!]
	cmd		[integer!]
	notif	[integer!]
	/local
		text [integer!]
		size [integer!]
		str	 [red-string!]
		face [red-object!]
		out	 [c-string!]
][
	text: objc_msgSend [self sel_getUid "stringValue"]
	size: objc_msgSend [text sel_getUid "length"]
	if size >= 0 [
		str: as red-string! (get-face-values self) + FACE_OBJ_TEXT
		if TYPE_OF(str) <> TYPE_STRING [
			string/make-at as red-value! str size UCS-2
		]
		if size = 0 [
			string/rs-reset str
			exit
		]
		out: unicode/get-cache str size + 1 * 4			;-- account for surrogate pairs and terminal NUL
		objc_msgSend [text sel_getUid "getCString:maxLength:encoding:" out size + 1 * 2 NSUTF16LittleEndianStringEncoding]
		unicode/load-utf16 null size str

		face: push-face self
		if TYPE_OF(face) = TYPE_OBJECT [
			ownership/bind as red-value! str face _text
		]
		stack/pop 1
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

paint-background: func [
	ctx		[handle!]
	color	[integer!]
	x		[float32!]
	y		[float32!]
	width	[float32!]
	height	[float32!]
][
	OS-draw-fill-pen ctx color yes yes
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
		draw [red-block!]
		clr  [red-tuple!]
][
	ctx: objc_msgSend [objc_getClass "NSGraphicsContext" sel_getUid "currentContext"]
	ctx: objc_msgSend [ctx sel_getUid "graphicsPort"]
	vals: get-face-values self
	draw: as red-block! vals + FACE_OBJ_DRAW
	clr:  as red-tuple! vals + FACE_OBJ_COLOR
	if TYPE_OF(clr) = TYPE_TUPLE [
		paint-background as handle! ctx clr/array1 x y width height
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
	make-super-class "RedTextField"		"NSTextField"	as-integer :add-text-field-handler	yes
	make-super-class "RedBox"			"NSBox"			0	yes
]
