Red/System [
	Title:	"MacOSX GUI backend"
	Author: "Qingtian Xie"
	File: 	%gui.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %cocoa.reds
#include %events.reds

#include %font.reds
#include %para.reds
#include %draw.reds

#include %classes.reds

NSApp:			0

log-pixels-x:	0
log-pixels-y:	0
screen-size-x:	0
screen-size-y:	0

get-face-values: func [
	handle	[integer!]
	return: [red-value!]
	/local
		ctx	 [red-context!]
		s	 [series!]
		ivar [integer!]
		face [red-object!]
][
	ivar: class_getInstanceVariable object_getClass handle IVAR_RED_FACE
	assert ivar <> 0
	face: as red-object! handle + ivar_getOffset ivar
	ctx: TO_CTX(face/ctx)
	s: as series! ctx/values/value
	s/offset
]

get-node-facet: func [
	node	[node!]
	facet	[integer!]
	return: [red-value!]
	/local
		ctx	 [red-context!]
		s	 [series!]
][
	ctx: TO_CTX(node)
	s: as series! ctx/values/value
	s/offset + facet
]

get-face-flags: func [
	face	[handle!]
	return: [integer!]
][
	0
]

get-face-handle: func [
	face	[red-object!]
	return: [handle!]
	/local
		state [red-block!]
		int	  [red-integer!]
][
	state: as red-block! get-node-facet face/ctx FACE_OBJ_STATE
	assert TYPE_OF(state) = TYPE_BLOCK
	int: as red-integer! block/rs-head state
	assert TYPE_OF(int) = TYPE_INTEGER
	as handle! int/value
]

get-child-from-xy: func [
	parent	[handle!]
	x		[integer!]
	y		[integer!]
	return: [integer!]
	/local
		hWnd [handle!]
][
0
]

get-text-size: func [
	str		[red-string!]
	hFont	[handle!]
	len		[integer!]
	pair	[red-pair!]
	return: [tagSIZE]
	/local
		saved [handle!]
		size  [tagSIZE]
][
	size: declare tagSIZE
	if pair <> null [
		pair/x: size/width
		pair/y: size/height
	]
	size
]

to-bgr: func [
	node	[node!]
	pos		[integer!]
	return: [integer!]									;-- 00bbggrr format or -1 if not found
	/local
		color [red-tuple!]
][
	color: as red-tuple! get-node-facet node pos
	either TYPE_OF(color) = TYPE_TUPLE [
		color/array1 and 00FFFFFFh
	][
		-1
	]
]

free-handles: func [
	hWnd [integer!]
	/local
		values [red-value!]
		type   [red-word!]
		face   [red-object!]
		tail   [red-object!]
		pane   [red-block!]
		state  [red-value!]
		sym	   [integer!]
		dc	   [integer!]
][
	values: get-face-values hWnd
	type: as red-word! values + FACE_OBJ_TYPE
	sym: symbol/resolve type/symbol

	pane: as red-block! values + FACE_OBJ_PANE
	if TYPE_OF(pane) = TYPE_BLOCK [
		face: as red-object! block/rs-head pane
		tail: as red-object! block/rs-tail pane
		while [face < tail][
			;@@ TBD
			face: face + 1
		]
	]

	state: values + FACE_OBJ_STATE
	state/header: TYPE_NONE
]

init: func [
	/local
		screen		[integer!]
		rect		[NSRect!]
		pool		[integer!]
		delegate	[integer!]
][
	NSApp: objc_msgSend [objc_getClass "NSApplication" sel_getUid "sharedApplication"]

	pool: objc_msgSend [objc_getClass "NSAutoreleasePool" sel_getUid "alloc"]
	objc_msgSend [pool sel_getUid "init"]

	register-classes

	delegate: objc_msgSend [objc_getClass "RedAppDelegate" sel_getUid "alloc"]
	delegate: objc_msgSend [delegate sel_getUid "init"]
	objc_msgSend [NSApp sel_getUid "setDelegate:" delegate]

	screen: objc_msgSend [objc_getClass "NSScreen" sel_getUid "mainScreen"]
	rect: as NSRect! (as int-ptr! screen) + 1
	screen-size-x: float/to-integer as float! rect/w
	screen-size-y: float/to-integer as float! rect/h
]

set-selected-focus: func [
	hWnd [integer!]
	/local
		face   [red-object!]
		values [red-value!]
		handle [handle!]
][
	values: get-face-values hWnd
	if values <> null [
		face: as red-object! values + FACE_OBJ_SELECTED
		if TYPE_OF(face) = TYPE_OBJECT [
			0;@@ TBD
		]
	]
]

set-logic-state: func [
	hWnd   [integer!]
	state  [red-logic!]
	check? [logic!]
	/local
		value [integer!]
][
	value: either TYPE_OF(state) <> TYPE_LOGIC [
		state/header: TYPE_LOGIC
		state/value: check?
		either check? [-1][0]
	][
		as-integer state/value							;-- returns 0/1, matches the messages
	]
	objc_msgSend [hWnd sel_getUid "setState:"  value]
]

get-flags: func [
	field	[red-block!]
	return: [integer!]									;-- return a bit-array of all flags
	/local
		word  [red-word!]
		len	  [integer!]
		sym	  [integer!]
		flags [integer!]
][
	switch TYPE_OF(field) [
		TYPE_BLOCK [
			word: as red-word! block/rs-head field
			len: block/rs-length? field
			if zero? len [return 0]
		]
		TYPE_WORD [
			word: as red-word! field
			len: 1
		]
		default [return 0]
	]
	flags: 0
	
	until [
		sym: symbol/resolve word/symbol
		case [
			sym = all-over	 [flags: flags or FACET_FLAGS_ALL_OVER]
			sym = resize	 [flags: flags or FACET_FLAGS_RESIZE]
			sym = no-title	 [flags: flags or FACET_FLAGS_NO_TITLE]
			sym = no-border  [flags: flags or FACET_FLAGS_NO_BORDER]
			sym = no-min	 [flags: flags or FACET_FLAGS_NO_MIN]
			sym = no-max	 [flags: flags or FACET_FLAGS_NO_MAX]
			sym = no-buttons [flags: flags or FACET_FLAGS_NO_BTNS]
			sym = modal		 [flags: flags or FACET_FLAGS_MODAL]
			sym = popup		 [flags: flags or FACET_FLAGS_POPUP]
			true			 [fire [TO_ERROR(script invalid-arg) word]]
		]
		word: word + 1
		len: len - 1
		zero? len
	]
	flags
]

get-position-value: func [
	pos		[red-float!]
	maximun [integer!]
	return: [integer!]
	/local
		f	[float!]
][
	f: 0.0
	if any [
		TYPE_OF(pos) = TYPE_FLOAT
		TYPE_OF(pos) = TYPE_PERCENT
	][
		f: pos/value * (integer/to-float maximun)
	]
	float/to-integer f
]

get-screen-size: func [
	id		[integer!]									;@@ Not used yet
	return: [red-pair!]
][
	pair/push screen-size-x screen-size-y
]

store-face-to-obj: func [
	obj		[integer!]
	class	[integer!]
	face	[red-object!]
	/local
		new  [red-object!]
		ivar [integer!]
][
	ivar: class_getInstanceVariable class IVAR_RED_FACE
	assert ivar <> 0
	new: as red-object! obj + ivar_getOffset ivar
	copy-cell as cell! face as cell! new
]

make-rect: func [
	x		[integer!]
	y		[integer!]
	w		[integer!]
	h		[integer!]
	return: [NSRect!]
	/local
		r	[NSRect!]
][
	r: declare NSRect!
	r/x: as float32! integer/to-float x
    r/y: as float32! integer/to-float y
    r/w: as float32! integer/to-float w
    r/h: as float32! integer/to-float h
    r
]

init-window: func [
	window	[integer!]
	title	[c-string!]
	rect	[NSRect!]
	/local
		view [integer!]
][
	window: objc_msgSend [
		window
		sel_getUid "initWithContentRect:styleMask:backing:defer:"
		rect/x rect/y rect/w rect/h
		NSTitledWindowMask or NSClosableWindowMask or NSResizableWindowMask or NSMiniaturizableWindowMask
		2 0
	]

	view: objc_msgSend [objc_getClass "RedView" sel_getUid "alloc"]
	rect: make-rect 0 0 0 0
	view: objc_msgSend [view sel_getUid "initWithFrame:" rect/x rect/y rect/w rect/h]
	objc_msgSend [window sel_getUid "setContentView:" view]

	objc_msgSend [window sel_getUid "setTitle:" CFString(title)]
	objc_msgSend [window sel_getUid "becomeFirstResponder"]
	objc_msgSend [window sel_getUid "makeKeyAndOrderFront:" 0]
	objc_msgSend [window sel_getUid "makeMainWindow"]

	objc_msgSend [NSApp sel_getUid "setActivationPolicy:" 0]
	objc_msgSend [NSApp sel_getUid "activateIgnoringOtherApps:" 1]
]

OS-show-window: func [
	hWnd [integer!]
	/local
		face	[red-object!]
][
	0
]

OS-make-view: func [
	face	[red-object!]
	parent	[integer!]
	return: [integer!]
	/local
		values	  [red-value!]
		type	  [red-word!]
		str		  [red-string!]
		tail	  [red-string!]
		offset	  [red-pair!]
		size	  [red-pair!]
		data	  [red-block!]
		int		  [red-integer!]
		img		  [red-image!]
		menu	  [red-block!]
		show?	  [red-logic!]
		open?	  [red-logic!]
		selected  [red-integer!]
		para	  [red-object!]
		flags	  [integer!]
		bits	  [integer!]
		sym		  [integer!]
		id		  [integer!]
		class	  [c-string!]
		caption   [c-string!]
		len		  [integer!]
		obj		  [integer!]
		rc		  [NSRect!]
		view	  [integer!]
][
	stack/mark-func words/_body

	values: object/get-values face

	type:	  as red-word!		values + FACE_OBJ_TYPE
	str:	  as red-string!	values + FACE_OBJ_TEXT
	offset:   as red-pair!		values + FACE_OBJ_OFFSET
	size:	  as red-pair!		values + FACE_OBJ_SIZE
	show?:	  as red-logic!		values + FACE_OBJ_VISIBLE?
	open?:	  as red-logic!		values + FACE_OBJ_ENABLE?
	data:	  as red-block!		values + FACE_OBJ_DATA
	img:	  as red-image!		values + FACE_OBJ_IMAGE
	menu:	  as red-block!		values + FACE_OBJ_MENU
	selected: as red-integer!	values + FACE_OBJ_SELECTED
	para:	  as red-object!	values + FACE_OBJ_PARA

	sym: 	  symbol/resolve type/symbol

	case [
		sym = button [class: "RedButton"]
		sym = check [
			class: "RedButton"
			flags: NSSwitchButton
		]
		sym = radio [
			class: "RedButton"
			flags: NSRadioButton
		]
		sym = window [class: "RedWindow"]
		sym = base	 [class: "RedBase"]
		true [											;-- search in user-defined classes
			fire [TO_ERROR(script face-type) type]
		]
	]

	id: objc_getClass class
	obj: objc_msgSend [id sel_getUid "alloc"]
	if zero? obj [print-line "*** Error: Create Window failed!"]

	;-- store the face value in the extra space of the window struct
	assert TYPE_OF(face) = TYPE_OBJECT					;-- detect corruptions caused by CreateWindow unwanted events
	store-face-to-obj obj id face

	;-- extra initialization
	caption: either TYPE_OF(str) = TYPE_STRING [
		len: -1
		unicode/to-utf8 str :len
	][
		null
	]
	rc: make-rect offset/x offset/y size/x size/y
	if sym <> window [
		obj: objc_msgSend [obj sel_getUid "initWithFrame:" rc/x rc/y rc/w rc/h]
	]

	case [
		any [sym = button sym = check sym = radio][
			objc_msgSend [obj sel_getUid "setBezelStyle:" NSRoundedBezelStyle]
			objc_msgSend [obj sel_getUid "setTitle:" CFString(caption)]
			objc_msgSend [obj sel_getUid "setTarget:" obj]
			objc_msgSend [obj sel_getUid "setAction:" sel_getUid "button-click:"]
			if sym <> button [
				objc_msgSend [obj sel_getUid "setButtonType:" flags]
				set-logic-state obj as red-logic! data no
			]
		]
		sym = window [
			rc: make-rect offset/x screen-size-y - offset/y - size/y size/x size/y
			init-window obj caption rc
		]
		true [0]
	]

	if all [
		sym <> window
		parent <> 0
	][
		view: objc_msgSend [parent sel_getUid "contentView"]
		objc_msgSend [view sel_getUid "addSubview:" obj]	;-- `addSubView:` will retain the obj
		objc_msgSend [obj sel_getUid "release"]
	]

	stack/unwind
	obj
]

OS-update-view: func [
	face [red-object!]
	/local
		ctx		[red-context!]
		values	[red-value!]
		state	[red-block!]
		menu	[red-block!]
		draw	[red-block!]
		word	[red-word!]
		int		[red-integer!]
		int2	[red-integer!]
		bool	[red-logic!]
		s		[series!]
		hWnd	[integer!]
		flags	[integer!]
		type	[integer!]
][
	ctx: GET_CTX(face)
	s: as series! ctx/values/value
	values: s/offset

	state: as red-block! values + FACE_OBJ_STATE
	word: as red-word! values + FACE_OBJ_TYPE
	type: symbol/resolve word/symbol
	s: GET_BUFFER(state)
	int: as red-integer! s/offset
	hWnd: int/value
	int: int + 1
	flags: int/value

	;if flags and FACET_FLAG_OFFSET <> 0 [
	;	change-offset hWnd as red-pair! values + FACE_OBJ_OFFSET type
	;]
	;if flags and FACET_FLAG_SIZE <> 0 [
	;	change-size hWnd as red-pair! values + FACE_OBJ_SIZE type
	;]
	;if flags and FACET_FLAG_TEXT <> 0 [
	;	change-text hWnd values type
	;]
	;if flags and FACET_FLAG_DATA <> 0 [
	;	change-data	as handle! hWnd values
	;]
	;if flags and FACET_FLAG_ENABLE? <> 0 [
	;	change-enabled as handle! hWnd values
	;]
	;if flags and FACET_FLAG_VISIBLE? <> 0 [
	;	bool: as red-logic! values + FACE_OBJ_VISIBLE?
	;	change-visible hWnd bool/value type
	;]
	;if flags and FACET_FLAG_SELECTED <> 0 [
	;	int2: as red-integer! values + FACE_OBJ_SELECTED
	;	change-selection hWnd int2 values
	;]
	;if flags and FACET_FLAG_FLAGS <> 0 [
	;	SetWindowLong
	;		as handle! hWnd
	;		wc-offset + 16
	;		get-flags as red-block! values + FACE_OBJ_FLAGS
	;]
	if flags and FACET_FLAG_DRAW  <> 0 [
		objc_msgSend [hWnd sel_getUid "display"]
	]
	;if flags and FACET_FLAG_COLOR <> 0 [
	;	either type = base [
	;		update-base as handle! hWnd null null values
	;	][
	;		InvalidateRect as handle! hWnd null 1
	;	]
	;]
	;if flags and FACET_FLAG_PANE <> 0 [
	;	if tab-panel <> type [				;-- tab-panel/pane has custom z-order handling
	;		update-z-order 
	;			as red-block! values + gui/FACE_OBJ_PANE
	;			null
	;	]
	;]
	;if flags and FACET_FLAG_FONT <> 0 [
	;	set-font as handle! hWnd face values
	;	InvalidateRect as handle! hWnd null 1
	;]
	;if flags and FACET_FLAG_PARA <> 0 [
	;	update-para face 0
	;	InvalidateRect as handle! hWnd null 1
	;]
	;if flags and FACET_FLAG_MENU <> 0 [
	;	menu: as red-block! values + FACE_OBJ_MENU
	;	if menu-bar? menu window [
	;		DestroyMenu GetMenu as handle! hWnd
	;		SetMenu as handle! hWnd build-menu menu CreateMenu
	;	]
	;]
	;if flags and FACET_FLAG_IMAGE <> 0 [
	;	change-image hWnd values type
	;]

	int/value: 0										;-- reset flags
]

OS-destroy-view: func [
	face   [red-object!]
	empty? [logic!]
	/local
		handle [integer!]
		values [red-value!]
		obj	   [red-object!]
		flags  [integer!]
][
	handle: as-integer get-face-handle face
	values: object/get-values face
	flags: get-flags as red-block! values + FACE_OBJ_FLAGS
	if flags and FACET_FLAGS_MODAL <> 0 [
		0
		;;TBD
		;SetActiveWindow GetWindow handle GW_OWNER
	]

	free-handles handle

	obj: as red-object! values + FACE_OBJ_FONT
	;if TYPE_OF(obj) = TYPE_OBJECT [unlink-sub-obj face obj FONT_OBJ_PARENT]
	
	obj: as red-object! values + FACE_OBJ_PARA
	;if TYPE_OF(obj) = TYPE_OBJECT [unlink-sub-obj face obj PARA_OBJ_PARENT]
	
]

OS-update-facet: func [
	face   [red-object!]
	facet  [red-word!]
	value  [red-value!]
	action [red-word!]
	new	   [red-value!]
	index  [integer!]
	part   [integer!]
	/local
		word [red-word!]
		sym	 [integer!]
		type [integer!]
		hWnd [handle!]
][
	sym: symbol/resolve facet/symbol
	
	case [
		sym = facets/pane [0]
		sym = facets/data [0]
		true [OS-update-view face]
	]
]

OS-to-image: func [
	face	[red-object!]
	return: [red-image!]
	/local
		hWnd 	[handle!]
		dc		[handle!]
		mdc		[handle!]
		rect	[RECT_STRUCT]
		width	[integer!]
		height	[integer!]
		bmp		[handle!]
		bitmap	[integer!]
		img		[red-image!]
		word	[red-word!]
		type	[integer!]
		size	[red-pair!]
		screen? [logic!]
][
	as red-image! none-value
]

OS-do-draw: func [
	img		[red-image!]
	cmds	[red-block!]
][
	do-draw null img cmds no no no no
]