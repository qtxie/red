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

#include %../keycodes.reds
#include %cocoa.reds
#include %selectors.reds
#include %events.reds

#include %font.reds
#include %para.reds
#include %draw.reds

#include %classes.reds
#include %menu.reds
#include %tab-panel.reds

NSApp:					0
AppMainMenu:			0
NSDefaultRunLoopMode:	0
&_NSConcreteStackBlock: 0
NSFontAttributeName:	0
NSParagraphStyleAttributeName: 0
NSForegroundColorAttributeName: 0

default-font:	0
exit-loop:		0
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

face-handle?: func [
	face	[red-object!]
	return: [handle!]									;-- returns NULL is no handle
	/local
		state [red-block!]
		int	  [red-integer!]
][
	state: as red-block! get-node-facet face/ctx FACE_OBJ_STATE
	if TYPE_OF(state) = TYPE_BLOCK [
		int: as red-integer! block/rs-head state
		if TYPE_OF(int) = TYPE_INTEGER [return as handle! int/value]
	]
	null
]

get-face-handle: func [
	face	[red-object!]
	return: [integer!]
	/local
		state [red-block!]
		int	  [red-integer!]
][
	state: as red-block! get-node-facet face/ctx FACE_OBJ_STATE
	assert TYPE_OF(state) = TYPE_BLOCK
	int: as red-integer! block/rs-head state
	assert TYPE_OF(int) = TYPE_INTEGER
	int/value
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
		rate   [red-value!]
		sym	   [integer!]
		handle [integer!]
][
	values: get-face-values hWnd
	type: as red-word! values + FACE_OBJ_TYPE
	sym: symbol/resolve type/symbol

	rate: values + FACE_OBJ_RATE
	if TYPE_OF(rate) <> TYPE_NONE [change-rate hWnd none-value]

	pane: as red-block! values + FACE_OBJ_PANE
	if TYPE_OF(pane) = TYPE_BLOCK [
		face: as red-object! block/rs-head pane
		tail: as red-object! block/rs-tail pane
		while [face < tail][
			handle: as-integer face-handle? face
			if handle <> 0 [free-handles handle]
			face: face + 1
		]
	]

	state: values + FACE_OBJ_STATE
	state/header: TYPE_NONE
]

get-os-version: func [
	/local
		ver		[red-tuple!]
		info	[integer!]
][
0
]

set-defaults: func [][
	default-font: objc_msgSend [
		objc_getClass "NSFont" sel_getUid "systemFontOfSize:" 0
	]
]

init: func [
	/local
		screen	 [integer!]
		rect	 [NSRect!]
		pool	 [integer!]
		delegate [integer!]
		lib		 [integer!]
		p-int	 [int-ptr!]
][
	lib: red/platform/dlopen "/System/Library/Frameworks/AppKit.framework/Versions/Current/AppKit" RTLD_LAZY
	p-int: red/platform/dlsym lib "NSDefaultRunLoopMode"
	NSDefaultRunLoopMode: p-int/value
	p-int: red/platform/dlsym lib "NSFontAttributeName"
	NSFontAttributeName: p-int/value
	p-int: red/platform/dlsym lib "NSParagraphStyleAttributeName"
	NSParagraphStyleAttributeName: p-int/value
	p-int: red/platform/dlsym lib "NSForegroundColorAttributeName"
	NSForegroundColorAttributeName: p-int/value

	lib: red/platform/dlopen "/System/Library/Frameworks/Foundation.framework/Versions/Current/Foundation" RTLD_LAZY
	&_NSConcreteStackBlock: as-integer red/platform/dlsym lib "_NSConcreteStackBlock"

	init-selectors

	NSApp: objc_msgSend [objc_getClass "NSApplication" sel_getUid "sharedApplication"]

	pool: objc_msgSend [objc_getClass "NSAutoreleasePool" sel_getUid "alloc"]
	objc_msgSend [pool sel_getUid "init"]

	get-os-version
	register-classes

	delegate: objc_msgSend [objc_getClass "RedAppDelegate" sel_getUid "alloc"]
	delegate: objc_msgSend [delegate sel_getUid "init"]
	objc_msgSend [NSApp sel_getUid "setDelegate:" delegate]

	create-main-menu

	screen: objc_msgSend [objc_getClass "NSScreen" sel_getUid "mainScreen"]
	rect: as NSRect! (as int-ptr! screen) + 1
	screen-size-x: as-integer rect/w
	screen-size-y: as-integer rect/h

	set-defaults

	objc_msgSend [NSApp sel_getUid "setActivationPolicy:" 0]
	objc_msgSend [NSApp sel_getUid "finishLaunching"]
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
	maximun [float!]
	return: [float!]
	/local
		f	[float!]
][
	f: 0.0
	if any [
		TYPE_OF(pos) = TYPE_FLOAT
		TYPE_OF(pos) = TYPE_PERCENT
	][
		f: pos/value *  maximun
	]
	f
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
	r/x: as float32! x
    r/y: as float32! y
    r/w: as float32! w
    r/h: as float32! h
    r
]

change-rate: func [
	hWnd [integer!]
	rate [red-value!]
	/local
		int		[red-integer!]
		tm		[red-time!]
		timer	[integer!]
		ts		[float!]
][
	timer: objc_getAssociatedObject hWnd RedTimerKey

	if timer <> 0 [								;-- cancel a preexisting timer
		objc_msgSend [timer sel_getUid "invalidate"]
		objc_setAssociatedObject hWnd RedTimerKey 0 OBJC_ASSOCIATION_ASSIGN
	]

	switch TYPE_OF(rate) [
		TYPE_INTEGER [
			int: as red-integer! rate
			if int/value <= 0 [fire [TO_ERROR(script invalid-facet-type) rate]]
			ts: 1.0 / as-float int/value
		]
		TYPE_TIME [
			tm: as red-time! rate
			if tm/time <= 0.0 [fire [TO_ERROR(script invalid-facet-type) rate]]
			ts: tm/time / 1E3
		]
		TYPE_NONE [exit]
		default	  [fire [TO_ERROR(script invalid-facet-type) rate]]
	]

	timer: objc_msgSend [
		objc_getClass "NSTimer"
		sel_getUid "scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"
		ts hWnd sel-on-timer 0 yes
	]
	objc_setAssociatedObject hWnd RedTimerKey timer OBJC_ASSOCIATION_ASSIGN
]

change-size: func [
	hWnd [integer!]
	size [red-pair!]
	type [integer!]
	/local
		rc [NSRect!]
][
	rc: make-rect size/x size/y 0 0
	if all [type = button size/y > 32][
		objc_msgSend [hWnd sel_getUid "setBezelStyle:" NSRegularSquareBezelStyle]
	]
	either type = window [
		0
	][
		objc_msgSend [hWnd sel_getUid "setFrameSize:" rc/x rc/y]
	]
]

change-offset: func [
	hWnd [integer!]
	pos  [red-pair!]
	type [integer!]
	/local
		rc [NSRect!]
][
	rc: make-rect pos/x pos/y 0 0
	either type = window [
		objc_msgSend [hWnd sel_getUid "setFrameTopLeftPoint:" rc/x rc/y]
	][
		objc_msgSend [hWnd sel_getUid "setFrameOrigin:" rc/x rc/y]
	]
]

change-visible: func [
	hWnd  [integer!]
	show? [logic!]
	type  [integer!]
][
	case [
		any [type = button type = check type = radio][
			objc_msgSend [hWnd sel_getUid "setEnabled:" show?]
			objc_msgSend [hWnd sel_getUid "setTransparent:" not show?]
		]
		type = window [0]
		true [objc_msgSend [hWnd sel_getUid "setHidden:" not show?]]
	]
]

change-text: func [
	hWnd	[integer!]
	values	[red-value!]
	type	[integer!]
	/local
		len  [integer!]
		txt  [integer!]
		cstr [c-string!]
		str  [red-string!]
][
	if type = base [
		objc_msgSend [hWnd sel_getUid "display"]
		exit
	]

	str: as red-string! values + FACE_OBJ_TEXT
	cstr: switch TYPE_OF(str) [
		TYPE_STRING [len: -1 unicode/to-utf8 str :len]
		TYPE_NONE	[""]
		default		[null]									;@@ Auto-convert?
	]
	unless null? cstr [
		txt: CFString(cstr)
		case [
			type = area [
				objc_msgSend [hWnd sel_getUid "setString:" txt]
			]
			any [type = field type = text][
				objc_msgSend [hWnd sel_getUid "setStringValue:" txt]
			]
			true [
				objc_msgSend [hWnd sel_getUid "setTitle:" txt]
			]
		]
		CFRelease txt
	]
]

change-data: func [
	hWnd   [integer!]
	values [red-value!]
	/local
		data 	[red-value!]
		word 	[red-word!]
		size	[red-pair!]
		f		[red-float!]
		str		[red-string!]
		caption [c-string!]
		type	[integer!]
		len		[integer!]
][
	data: as red-value! values + FACE_OBJ_DATA
	word: as red-word! values + FACE_OBJ_TYPE
	type: word/symbol
	
	case [
		all [
			type = progress
			TYPE_OF(data) = TYPE_PERCENT
		][
			f: as red-float! data
			objc_msgSend [hWnd sel_getUid "setDoubleValue:" f/value * 100.0]
		]
		all [
			type = slider
			TYPE_OF(data) = TYPE_PERCENT
		][
			f: as red-float! data
			size: as red-pair! values + FACE_OBJ_SIZE
			len: either size/x > size/y [size/x][size/y]
			objc_msgSend [hWnd sel_getUid "setDoubleValue:" f/value * (as-float len)]
		]
		type = check [
			set-logic-state hWnd as red-logic! data yes
		]
		type = radio [
			set-logic-state hWnd as red-logic! data no
		]
		;type = tab-panel [
		;	set-tabs hWnd get-face-values hWnd
		;]
		all [
			type = text-list
			TYPE_OF(data) = TYPE_BLOCK
		][
			objc_msgSend [objc_msgSend [hWnd sel_getUid "documentView"] sel_getUid "reloadData"]
		]
		any [type = drop-list type = drop-down][
			init-combo-box 
				hWnd
				as red-block! data
				null
				as red-integer! values + FACE_OBJ_SELECTED
				type = drop-list
		]
		true [0]										;-- default, do nothing
	]
]

change-selection: func [
	hWnd   [integer!]
	int	   [red-integer!]								;-- can be also none! | object!
	type   [integer!]
	/local
		idx [integer!]
][
	if TYPE_OF(int) = TYPE_NONE [idx: -1]
	idx: int/value - 1
	if idx < 0 [exit]		;-- @@ should unselect the items ?
	case [
		type = camera [
			either TYPE_OF(int) = TYPE_NONE [
				toggle-preview hWnd false
			][
				select-camera hWnd idx
				toggle-preview hWnd true
			]
		]
		type = text-list [
			idx: objc_msgSend [objc_getClass "NSIndexSet" sel_getUid "indexSetWithIndex:" idx]
			objc_msgSend [
				objc_msgSend [hWnd sel_getUid "documentView"]
				sel_getUid "selectRowIndexes:byExtendingSelection:"
				idx no
			]
			objc_msgSend [idx sel_getUid "release"]
		]
		any [type = drop-list type = drop-down][
			objc_msgSend [hWnd sel_getUid "selectItemAtIndex:" idx]
			idx: objc_msgSend [hWnd sel_getUid "objectValueOfSelectedItem"]
			objc_msgSend [hWnd sel_getUid "setObjectValue:" idx]
		]
		type = tab-panel [
			0
		]
		type = window [0]
		true [0]										;-- default, do nothing
	]
]

same-type?: func [
	obj		[integer!]
	name	[c-string!]
	return: [logic!]
][
	(object_getClass obj) = objc_getClass name
]

set-content-view: func [
	obj		[integer!]
	/local
		rect [NSRect!]
		view [integer!]
][
	view: objc_msgSend [objc_getClass "RedView" sel_getUid "alloc"]
	rect: make-rect 0 0 0 0
	view: objc_msgSend [view sel_getUid "initWithFrame:" rect/x rect/y rect/w rect/h]
	objc_msgSend [obj sel_getUid "setContentView:" view]
]

init-combo-box: func [
	combo		[integer!]
	data		[red-block!]
	caption		[integer!]
	selected	[red-integer!]
	drop-list?	[logic!]
	/local
		str	 [red-string!]
		tail [red-string!]
		len  [integer!]
		val  [integer!]
][
	if any [
		TYPE_OF(data) = TYPE_BLOCK
		TYPE_OF(data) = TYPE_HASH
		TYPE_OF(data) = TYPE_MAP
	][
		str:  as red-string! block/rs-head data
		tail: as red-string! block/rs-tail data
		
		objc_msgSend [combo sel_getUid "removeAllItems"]
		
		while [str < tail][
			if TYPE_OF(str) = TYPE_STRING [
				len: -1
				val: CFString((unicode/to-utf8 str :len))
				objc_msgSend [combo sel_getUid "addItemWithObjectValue:" val]
			]
			str: str + 1
		]
	]
	if TYPE_OF(selected) = TYPE_INTEGER [
		objc_msgSend [combo sel_getUid "selectItemAtIndex:" selected/value - 1]
		val: objc_msgSend [combo sel_getUid "objectValueOfSelectedItem"]
		objc_msgSend [combo sel_getUid "setObjectValue:" val]
	]
	either drop-list? [
		objc_msgSend [combo sel_getUid "setEditable:" false]
	][
		if caption <> 0 [
			objc_msgSend [combo sel_getUid "setStringValue:" caption]
		]
	]
]

init-window: func [
	window	[integer!]
	title	[integer!]
	rect	[NSRect!]
][
	window: objc_msgSend [
		window
		sel_getUid "initWithContentRect:styleMask:backing:defer:"
		rect/x rect/y rect/w rect/h
		NSTitledWindowMask or NSClosableWindowMask or NSResizableWindowMask or NSMiniaturizableWindowMask
		2 0
	]

	set-content-view window

	if title <> 0 [objc_msgSend [window sel_getUid "setTitle:" title]]
	objc_msgSend [window sel_getUid "becomeFirstResponder"]
	objc_msgSend [window sel_getUid "makeKeyAndOrderFront:" 0]
	objc_msgSend [window sel_getUid "makeMainWindow"]

	objc_msgSend [window sel_getUid "setDelegate:" window]
]

make-area: func [
	face		[red-object!]
	container	[integer!]
	rc			[NSRect!]
	text		[integer!]
	/local
		id		[integer!]
		obj		[integer!]
		tbox	[integer!]
][
	rc/x: as float32! 0.0
	rc/y: as float32! 0.0
	;objc_msgSend2 container sel_getUid "contentSize"				;-- return struct

	objc_msgSend [container sel_getUid "setBorderType:" NSGrooveBorder]
	objc_msgSend [container sel_getUid "setHasVerticalScroller:" yes]
	objc_msgSend [container sel_getUid "setHasHorizontalScroller:" no]
	objc_msgSend [container sel_getUid "setAutoresizingMask:" NSViewWidthSizable or NSViewHeightSizable]

	id: objc_getClass "RedTextView"
	obj: objc_msgSend [id sel_getUid "alloc"]

	assert obj <> 0
	obj: objc_msgSend [
		obj sel_getUid "initWithFrame:" rc/x rc/y rc/w rc/h
	]
	store-face-to-obj obj id face

	rc/y: as float32! 1e37			;-- FLT_MAX
	objc_msgSend [obj sel_getUid "setVerticallyResizable:" yes]
	objc_msgSend [obj sel_getUid "setHorizontallyResizable:" no]
	objc_msgSend [obj sel_getUid "setMinSize:" rc/x rc/h]

	objc_msgSend [obj sel_getUid "setMaxSize:" rc/y rc/y]
	objc_msgSend [obj sel_getUid "setAutoresizingMask:" NSViewWidthSizable]

	tbox: objc_msgSend [obj sel_getUid "textContainer"]
	objc_msgSend [tbox sel_getUid "setContainerSize:" rc/w rc/y]
	objc_msgSend [tbox sel_getUid "setWidthTracksTextView:" yes]

	if text <> 0 [objc_msgSend [obj sel_getUid "setString:" text]]

	objc_msgSend [obj sel_getUid "setDelegate:" obj]
	objc_msgSend [container sel_getUid "setDocumentView:" obj]
]

make-text-list: func [
	face		[red-object!]
	container	[integer!]
	rc			[NSRect!]
	/local
		id		[integer!]
		obj		[integer!]
		column	[integer!]
][
	rc/x: as float32! 0.0
	rc/y: as float32! 0.0
	rc/w: rc/w - 16.0

	id: CFString("RedCol1")
	column: objc_msgSend [objc_getClass "NSTableColumn" sel_getUid "alloc"]
	column: objc_msgSend [column sel_getUid "initWithIdentifier:" id]
	;CFRelease id
	objc_msgSend [column sel_getUid "setWidth:" rc/w]

	;objc_msgSend [container sel_getUid "setHasHorizontalScroller:" no]
	objc_msgSend [container sel_getUid "setHasVerticalScroller:" yes]
	objc_msgSend [container sel_getUid "setAutoresizingMask:" NSViewWidthSizable or NSViewHeightSizable]

	id: objc_getClass "RedTableView"
	obj: objc_msgSend [id sel_getUid "alloc"]

	assert obj <> 0
	obj: objc_msgSend [
		obj sel_getUid "initWithFrame:" rc/x rc/y rc/w rc/h
	]
	store-face-to-obj obj id face

	objc_msgSend [obj sel_getUid "setHeaderView:" 0]
	objc_msgSend [obj sel_getUid "addTableColumn:" column]
	objc_msgSend [obj sel_getUid "setDelegate:" obj]
	objc_msgSend [obj sel_getUid "setDataSource:" obj]
	objc_msgSend [obj sel_getUid "reloadData"]

	objc_msgSend [container sel_getUid "setDocumentView:" obj]
	objc_msgSend [obj sel_getUid "release"]
	objc_msgSend [column sel_getUid "release"]
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
		rate	  [red-value!]
		flags	  [integer!]
		sym		  [integer!]
		id		  [integer!]
		class	  [c-string!]
		caption   [integer!]
		len		  [integer!]
		obj		  [integer!]
		rc		  [NSRect!]
		flt		  [float!]
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
	rate:						values + FACE_OBJ_RATE

	sym: 	  symbol/resolve type/symbol

	case [
		any [
			sym = text-list
			sym = area
		][class: "RedScrollView"]
		sym = text [class: "RedTextField"]
		sym = field [class: "RedTextField"]
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
		sym = tab-panel [class: "RedTabView"]
		any [
			sym = panel
			sym = base
		][class: "RedBase"]
		any [
			sym = drop-down
			sym = drop-list
		][class: "RedComboBox"]
		sym = slider [class: "RedSlider"]
		sym = progress [class: "RedProgress"]
		sym = group-box [class: "RedBox"]
		sym = camera [class: "RedCamera"]
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
		CFString((unicode/to-utf8 str :len))
	][
		0
	]
	rc: make-rect offset/x offset/y size/x size/y
	if sym <> window [
		obj: objc_msgSend [obj sel_getUid "initWithFrame:" rc/x rc/y rc/w rc/h]
	]

	case [
		sym = text [
			objc_msgSend [obj sel_getUid "setEditable:" false]
			objc_msgSend [obj sel_getUid "setBordered:" false]
			objc_msgSend [obj sel_getUid "setDrawsBackground:" false]
			if caption <> 0 [objc_msgSend [obj sel_getUid "setStringValue:" caption]]
		]
		sym = field [
			id: objc_msgSend [obj sel_getUid "cell"]
			objc_msgSend [id sel_getUid "setWraps:" no]
			objc_msgSend [id sel_getUid "setScrollable:" yes]
			if caption <> 0 [objc_msgSend [obj sel_getUid "setStringValue:" caption]]
		]
		sym = area [
			make-area face obj rc caption
		]
		sym = text-list [
			make-text-list face obj rc
		]
		any [sym = button sym = check sym = radio][
			len: either any [
				size/y > 32
				TYPE_OF(img) = TYPE_IMAGE
			][
				NSRegularSquareBezelStyle
			][
				NSRoundedBezelStyle
			]
			objc_msgSend [obj sel_getUid "setBezelStyle:" len]
			if sym <> button [
				objc_msgSend [obj sel_getUid "setButtonType:" flags]
				set-logic-state obj as red-logic! data no
			]
			if TYPE_OF(img) = TYPE_IMAGE [
				len: CGBitmapContextCreateImage as-integer img/node
				id: objc_msgSend [objc_getClass "NSImage" sel_getUid "alloc"]
				id: objc_msgSend [id sel_getUid "initWithCGImage:size:" len 0 0] 
				objc_msgSend [obj sel_getUid "setImage:" id]
				objc_msgSend [id sel_getUid "release"]
				CGImageRelease len
			]
			if caption <> 0 [objc_msgSend [obj sel_getUid "setTitle:" caption]]
			objc_msgSend [obj sel_getUid "setTarget:" obj]
			objc_msgSend [obj sel_getUid "setAction:" sel_getUid "button-click:"]
		]
		any [
			sym = panel
			sym = base
		][
			if TYPE_OF(menu) = TYPE_BLOCK [set-context-menu obj menu]
		]
		sym = tab-panel [
			set-tabs obj values
			objc_msgSend [obj sel_getUid "setDelegate:" obj]
		]
		sym = window [
			rc: make-rect offset/x screen-size-y - offset/y - size/y size/x size/y
			init-window obj caption rc
			if all [						;@@ application menu ?
				zero? AppMainMenu
				menu-bar? menu window
			][
				AppMainMenu: objc_msgSend [NSApp sel_getUid "mainMenu"]
				build-menu menu AppMainMenu obj
			]
		]
		sym = slider [
			len: either size/x > size/y [size/x][size/y]
			flt: as-float len
			objc_msgSend [obj sel_getUid "setMaxValue:" flt]
			flt: get-position-value as red-float! data flt
			objc_msgSend [obj sel_getUid "setDoubleValue:" flt]
			objc_msgSend [obj sel_getUid "setTarget:" obj]
			objc_msgSend [obj sel_getUid "setAction:" sel_getUid "slider-change:"]
		]
		sym = progress [
			objc_msgSend [obj sel_getUid "setIndeterminate:" false]
			flt: get-position-value as red-float! data 100.0
			objc_msgSend [obj sel_getUid "setDoubleValue:" flt]
		]
		sym = group-box [
			set-content-view obj
			either zero? caption [
				objc_msgSend [obj sel_getUid "setTitlePosition:" NSNoTitle]
			][
				objc_msgSend [obj sel_getUid "setTitle:" caption]
			]
		]
		any [
			sym = drop-down
			sym = drop-list
		][
			init-combo-box obj data caption selected sym = drop-list
			objc_msgSend [obj sel_getUid "setDelegate:" obj]
		]
		sym = camera [
			init-camera obj rc data
		]
		true [0]
	]

	if TYPE_OF(rate) <> TYPE_NONE [change-rate obj rate]

	if parent <> 0 [
		objc_msgSend [parent sel_getUid "addSubview:" obj]	;-- `addSubView:` will retain the obj
		objc_msgSend [obj sel_getUid "release"]
	]

	if caption <> 0 [CFRelease caption]
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

	if flags and FACET_FLAG_OFFSET <> 0 [
		change-offset hWnd as red-pair! values + FACE_OBJ_OFFSET type
	]
	if flags and FACET_FLAG_SIZE <> 0 [
		change-size hWnd as red-pair! values + FACE_OBJ_SIZE type
	]
	if flags and FACET_FLAG_TEXT <> 0 [
		change-text hWnd values type
	]
	if flags and FACET_FLAG_DATA <> 0 [
		change-data hWnd values
	]
	if flags and FACET_FLAG_ENABLE? <> 0 [
		bool: as red-logic! values + FACE_OBJ_ENABLE?
		objc_msgSend [hWnd sel_getUid "setEnabled:" bool/value]
	]
	if flags and FACET_FLAG_VISIBLE? <> 0 [
		bool: as red-logic! values + FACE_OBJ_VISIBLE?
		change-visible hWnd bool/value type
	]
	if flags and FACET_FLAG_SELECTED <> 0 [
		change-selection hWnd as red-integer! values + FACE_OBJ_SELECTED type
	]
	;if flags and FACET_FLAG_FLAGS <> 0 [
	;	get-flags as red-block! values + FACE_OBJ_FLAGS
	;]
	if any [
		flags and FACET_FLAG_DRAW  <> 0
		flags and FACET_FLAG_COLOR <> 0
		flags and FACET_FLAG_IMAGE <> 0
	][
		either type = camera [
			snap-camera hWnd
			values: values + FACE_OBJ_IMAGE
			until [TYPE_OF(values) = TYPE_IMAGE]			;-- wait
		][
			objc_msgSend [hWnd sel_getUid "display"]
		]
	]
	;if flags and FACET_FLAG_PANE <> 0 [
	;	if tab-panel <> type [				;-- tab-panel/pane has custom z-order handling
	;		update-z-order 
	;			as red-block! values + gui/FACE_OBJ_PANE
	;			null
	;	]
	;]
	if flags and FACET_FLAG_RATE <> 0 [
		change-rate hWnd values + FACE_OBJ_RATE
	]
	if flags and FACET_FLAG_FONT <> 0 [
		set-font hWnd face values
		objc_msgSend [hWnd sel_getUid "display"]
	]
	;if flags and FACET_FLAG_PARA <> 0 [
	;	update-para face 0
	;]
	if flags and FACET_FLAG_MENU <> 0 [
		menu: as red-block! values + FACE_OBJ_MENU
		if menu-bar? menu window [
			AppMainMenu: objc_msgSend [NSApp sel_getUid "mainMenu"]
			objc_msgSend [AppMainMenu sel_getUid "removeAllItems"]
			build-menu menu AppMainMenu hWnd
		]
	]

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
	handle: get-face-handle face
	values: object/get-values face
	flags: get-flags as red-block! values + FACE_OBJ_FLAGS
	if flags and FACET_FLAGS_MODAL <> 0 [
		0
		;;TBD
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
