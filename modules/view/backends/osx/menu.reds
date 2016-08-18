Red/System [
	Title:	"macOS Menu widget"
	Author: "Qingtian Xie"
	File: 	%menu.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

menu-selected:	-1										;-- last selected menu item ID
menu-handle: 	as handle! 0							;-- last selected menu handle
menu-origin:	as handle! 0							;-- window where context menu was opened from
menu-ctx:		as handle! 0							;-- context menu handle

create-main-menu: func [
	/local
		app-name	[integer!]
		empty-str	[integer!]
		main-menu	[integer!]
		apple-menu	[integer!]
		app-item	[integer!]
][
	empty-str: NSString("")
	main-menu: objc_msgSend [objc_getClass "NSMenu" sel_getUid "alloc"]
	main-menu: objc_msgSend [main-menu sel_getUid "initWithTitle:" NSString("NSAppleMenu")]
	
	apple-menu: objc_msgSend [objc_getClass "NSMenu" sel_getUid "alloc"]
	apple-menu: objc_msgSend [apple-menu sel_getUid "initWithTitle:" NSString("Apple")]
	objc_msgSend [NSApp sel_getUid "setAppleMenu:" apple-menu]

	app-item: objc_msgSend [
		main-menu sel_getUid "addItemWithTitle:action:keyEquivalent:"
		empty-str 0 empty-str
	]
	objc_msgSend [main-menu sel_getUid "setSubmenu:forItem:" apple-menu app-item]
	objc_msgSend [apple-menu sel_getUid "release"]
	objc_msgSend [NSApp sel_getUid "setMainMenu:" main-menu]
	objc_msgSend [main-menu sel_getUid "release"]
]

build-menu: func [
	menu	[red-block!]
	hMenu	[integer!]
	return: [integer!]
	/local
		item	 [integer!]
		sub-menu [integer!]
		value	 [red-value!]
		tail	 [red-value!]
		next	 [red-value!]
		str		 [red-string!]
		w		 [red-word!]
		title	 [integer!]
		key		 [integer!]
][
	if TYPE_OF(menu) <> TYPE_BLOCK [return null] 

	value: block/rs-head menu
	tail:  block/rs-tail menu

	key: NSString("")
	while [value < tail][
		switch TYPE_OF(value) [
			TYPE_STRING [
				str: as red-string! value
				next: value + 1

				title: to-NSString str
				item: objc_msgSend [objc_getClass "NSMenuItem" sel_getUid "alloc"]
				item: objc_msgSend [
					item sel_getUid "initWithTitle:action:keyEquivalent:"
					title 0 key
				]
				if next < tail [
					switch TYPE_OF(next) [
						TYPE_BLOCK [
							sub-menu: objc_msgSend [objc_getClass "NSMenu" sel_getUid "alloc"]
							sub-menu: objc_msgSend [sub-menu sel_getUid "initWithTitle:" title]
							build-menu as red-block! next sub-menu
							objc_msgSend [item sel_getUid "setSubmenu:" sub-menu]
							value: value + 1
						]
						TYPE_WORD [
							w: as red-word! next
							value: value + 1
						]
						default [0]
					]
				]
			]
			TYPE_WORD [
				w: as red-word! value
				if w/symbol = --- [
					item: objc_msgSend [objc_getClass "NSMenuItem" sel_getUid "separatorItem"]
				]
			]
			default [0]
		]
		objc_msgSend [hMenu sel_getUid "addItem:" item]
		value: value + 1
	]
	hMenu
]

menu-bar?: func [
	spec	[red-block!]
	type	[integer!]
	return: [logic!]
	/local
		w	[red-word!]
][
	if all [
		TYPE_OF(spec) = TYPE_BLOCK
		not block/rs-tail? spec
		type = window
	][
		w: as red-word! block/rs-head spec
		return not all [
			TYPE_OF(w) = TYPE_WORD
			popup = symbol/resolve w/symbol
		]
	]
	no
]

;show-context-menu: func [
;	msg		[tagMSG]
;	x		[integer!]
;	y		[integer!]
;	return: [logic!]									;-- TRUE: menu displayed
;	/local
;		values [red-value!]
;		spec   [red-block!]
;		w	   [red-word!]
;		hWnd   [handle!]
;		hMenu  [handle!]
;][
	;values: get-facets msg
	;spec: as red-block! values + FACE_OBJ_MENU
	;menu-selected: -1
	;menu-handle: null

	;if TYPE_OF(spec) = TYPE_BLOCK [
	;	w: as red-word! values + FACE_OBJ_TYPE
	;	if menu-bar? spec symbol/resolve w/symbol [
	;		return no
	;	]
	;	hWnd: GetParent msg/hWnd
	;	if null? hWnd [hWnd: msg/hWnd]
	;	menu-origin: msg/hWnd

	;	hMenu: build-menu spec CreatePopupMenu
	;	menu-ctx: hMenu
	;	TrackPopupMenuEx hMenu 0 x y GetParent msg/hWnd null
	;	return yes
	;]
;	no
;]

;get-menu-id: func [
;	hMenu	[handle!]
;	pos		[integer!]
;	return: [integer!]
;	/local
;		item [MENUITEMINFO]
;][
;	item: declare MENUITEMINFO 
;	item/cbSize:  size? MENUITEMINFO
;	item/fMask:	  MIIM_DATA
;	GetMenuItemInfo hMenu pos true item
;	return item/dwItemData
;]

;do-menu: func [
;	hWnd [handle!]
;	/local
;		res	[integer!]
;][
;	res: get-menu-id menu-handle menu-selected
;	if null? menu-origin [menu-origin: hWnd]
;	current-msg/hWnd: menu-origin
;	make-event current-msg res EVT_MENU
;	unless null? menu-ctx [DestroyMenu menu-ctx]		;-- recursive destruction
;	menu-origin: null
;]