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
	make-event self 0 0 EVT_CLICK
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
		if change? [make-event self 0 0 EVT_CHANGE]
	]
]

will-finish: func [
	[cdecl]
	self	[NSAppDelegate!]
	cmd		[integer!]
	notify	[integer!]
][
	0
]

destroy-app: func [
	[cdecl]
	self	[NSAppDelegate!]
	cmd		[integer!]
	app		[integer!]
	return: [logic!]
][
	objc_msgSend [NSApp sel_getUid "stop:" 0]
	no
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
		draw [red-block!]
][
	draw: (as red-block! get-face-values self) + FACE_OBJ_DRAW
	do-draw as handle! self null draw no yes yes yes
]

add-base-handler: func [class [integer!]][
	flipp-coord class
	class_addMethod class sel_getUid "drawRect:" as-integer :draw-rect "v@:{_NSRect=ffff}"
]

add-window-handler: func [class [integer!]][
	class_addMethod class sel_getUid "mouseDown:" as-integer :mouse-down "v@:@"
	class_addMethod class sel_getUid "mouseUp:" as-integer :mouse-up "v@:@"
]

add-button-handler: func [class [integer!]][
	class_addMethod class sel_getUid "button-click:" as-integer :button-click "v@:@"
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
]
