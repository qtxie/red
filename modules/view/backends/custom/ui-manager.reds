Red/System [
	Title:	"UI manager"
	Author: "Xie Qingtian"
	File: 	%ui-manager.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#enum window-flags! [
	;-- show flags
	WIN_FLAG_SHOW:		0
	WIN_FLAG_HIDE:		1
	WIN_FLAG_MIN:		2
	WIN_FLAG_MAX:		4
	WIN_FLAG_INACTIVE:	8
	;-- window type
	WIN_TYPE_POPUP:		10h
	WIN_TYPE_FRAMELESS:	20h
	WIN_TYPE_TOOL:		40h
	WIN_TYPE_TASKBAR:	80h
	;-- render flags
	WIN_RENDER_FULL:	0100h
]

wm!: alias struct! [
	flags		[integer!]
	hWnd		[handle!]
	gob			[gob!]			;-- root gob
	focused		[gob!]			;-- focused gob in the window
	update-list	[node!]
]

ui-manager: context [	;-- manager all the windows

	win-list:		as node! 0
	active-win:		as wm! 0

	init: func [
		/local
			v1	[node!]
			s	[series!]
	][
		win-list: rs-gob/make-vector 2 * size? wm!
		active-win: as wm! alloc0 size? wm!
	]

	on-gc-mark: func [
		/local
			w	[wm!]
			s	[series!]
			e	[wm!]
	][
		collector/keep win-list
		s: as series! win-list/node
		w: as wm! s/offset
		e: as wm! s/tail
		while [w < e][
			collector/keep w/update-list
			w: w + 1
		]
	]

	add-window: func [
		hWnd	[handle!]
		root	[gob!]
		/local
			p	[wm!]
	][
		p: as wm! alloc-tail-unit as series! win-list/value size? wm!
		p/flags: 0
		p/hWnd: hWnd
		p/gob: root
		p/focused: null
		p/update-list: rs-gob/make-vector 16
	]

	add-update: func [
		gob		[gob!]
		/local
			v	[red-vector! value]
	][
		unless rs-gob/set-flag? GOB_FLAG_UPDATE [
			gob/flags: gob/flags or GOB_FLAG_UPDATE
			v/node: active-win/update-list
			vector/rs-append-int :v as-integer gob
		]
	]
]
