Red/System [
	Title:	"Cocoa fonts management"
	Author: "Qingtian Xie"
	File: 	%font.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

make-font: func [
	face	[red-object!]
	font	[red-object!]
	return: [handle!]
	/local
		values	[red-value!]
		int		[red-integer!]
		value	[red-value!]
		bool	[red-logic!]
		style	[red-word!]
		str		[red-string!]
		blk		[red-block!]
		size	[float32!]
		angle	[integer!]
		quality [integer!]
		len		[integer!]
		sym		[integer!]
		name	[c-string!]
		traits	[integer!]
		manager [integer!]
		method	[c-string!]
		hFont	[handle!]
		temp	[CGPoint!]
][
	temp: declare CGPoint!
	values: object/get-values font

	int: as red-integer! values + FONT_OBJ_SIZE
	size: either TYPE_OF(int) <> TYPE_INTEGER [as float32! 0.0][as float32! int/value]

	int: as red-integer! values + FONT_OBJ_ANGLE
	angle: either TYPE_OF(int) = TYPE_INTEGER [int/value * 10][0]	;-- in tenth of degrees

	style: as red-word! values + FONT_OBJ_STYLE
	len: switch TYPE_OF(style) [
		TYPE_BLOCK [
			blk: as red-block! style
			style: as red-word! block/rs-head blk
			len: block/rs-length? blk
		]
		TYPE_WORD  [1]
		default	   [0]
	]

	traits: 0
	unless zero? len [
		loop len [
			sym: symbol/resolve style/symbol
			case [
				sym = _bold	 	 [traits: traits or NSBoldFontMask]
				sym = _italic	 [traits: traits or NSItalicFontMask]
				sym = _underline [0]
				sym = _strike	 [0]
				true			 [0]
			]
			style: style + 1
		]
	]

	temp/x: size
	str: as red-string! values + FONT_OBJ_NAME
	either TYPE_OF(str) = TYPE_STRING [
		len: -1
		name: unicode/to-utf8 str :len
		sym: CFString(name)
		manager: objc_msgSend [objc_getClass "NSFontManager" sel_getUid "sharedFontManager"]
		hFont: as handle! objc_msgSend [
			manager
			sel_getUid "fontWithFamily:traits:weight:size:"
			sym
			traits
			0								;-- ignored if use traits
			temp/x
		]
		CFRelease sym
	][												;-- use system font
		method: either traits and NSBoldFontMask <> 0 [
			"boldSystemFontOfSize:"
		][
			"systemFontOfSize:"
		]
		hFont: as handle! objc_msgSend [objc_getClass "NSFont" sel_getUid method temp/x]
	]

	either null? face [									;-- null => replace underlying font object 
		int: as red-integer! block/rs-head as red-block! values + FONT_OBJ_STATE
		int/header: TYPE_INTEGER
		int/value: as-integer hFont
	][
		blk: block/make-at as red-block! values + FONT_OBJ_STATE 2
		integer/make-in blk as-integer hFont

		blk: block/make-at as red-block! values + FONT_OBJ_PARENT 4
		block/rs-append blk as red-value! face
	]
	hFont
]

get-font-handle: func [
	font	[red-object!]
	return: [handle!]
	/local
		state  [red-block!]
		int	   [red-integer!]
][
	state: as red-block! (object/get-values font) + FONT_OBJ_STATE
	if TYPE_OF(state) = TYPE_BLOCK [
		int: as red-integer! block/rs-head state
		if TYPE_OF(int) = TYPE_INTEGER [
			return as handle! int/value
		]
	]
	null
]

get-font: func [
	face	[red-object!]
	font	[red-object!]
	return: [handle!]
	/local
		hFont [handle!]
][
	if TYPE_OF(font) <> TYPE_OBJECT [return null]
	hFont: get-font-handle font
	if null? hFont [hFont: make-font face font]
	hFont
]

free-font: func [
	font [red-object!]
	/local
		state [red-block!]
		hFont [handle!]
][
	hFont: get-font-handle font
	if hFont <> null [
		OBJC_RELEASE(hFont)
		state: as red-block! (object/get-values font) + FONT_OBJ_STATE
		state/header: TYPE_NONE
	]
]

update-font: func [
	font [red-object!]
	flag [integer!]
][
	switch flag [
		FONT_OBJ_NAME
		FONT_OBJ_SIZE
		FONT_OBJ_STYLE
		FONT_OBJ_ANGLE
		FONT_OBJ_ANTI-ALIAS? [
			free-font font
			make-font null font
		]
		default [0]
	]
]