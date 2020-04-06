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

ui-manager: context [	;-- manage all the windows

	active-win:		as wm! 0
	hover-gob:		as gob! 0		;-- the gob under the mouse
	captured-gob:	as gob! 0
	captured:		as node! 0
	win-list:		as node! 0

	init: func [][
		win-list: array/make 4 size? int-ptr!
		captured: array/make 16 size? int-ptr!
	]

	on-gc-mark: func [
		/local
			w	[wm!]
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
	][
		collector/keep win-list
		collector/keep captured
		collector/keep animation/anim-list
		s: as series! win-list/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		while [p < e][
			w: as wm! p/value
			collector/keep w/update-list
			p: p + 1
		]
	]

	add-window: func [
		hwnd	[handle!]
		root	[gob!]
		render	[renderer!]
		return: [wm!]
		/local
			p	[wm!]
	][
		p: as wm! allocate size? wm!
		p/flags: WIN_RENDER_ALL
		p/hWnd: hWnd
		p/gob: root
		p/render: render
		p/focused: null
		p/update-list: array/make 16 size? int-ptr!
		array/append-ptr win-list as int-ptr! p
		p
	]

	remove-window: func [
		wm		[wm!]
		/local
			g	[gob!]
	][
		g: wm/gob
		g/flags: g/flags and (not GOB_FLAG_HOSTED)
		array/remove-ptr win-list as int-ptr! wm
		host/free-renderer wm/render
		free as byte-ptr! wm
		active-win: null
		hover-gob:	null
		captured-gob: null
		array/clear captured
	]

	add-update: func [
		gob		[gob!]
	][
		unless rs-gob/set-flag? gob GOB_FLAG_UPDATE [
			gob/flags: gob/flags or GOB_FLAG_UPDATE
			array/append-ptr active-win/update-list as int-ptr! gob
		]
	]

	draw-update: func [
		update-list	[node!]
	][
		
	]

	redraw: func [][
		if active-win <> null [
			active-win/flags: active-win/flags or WIN_RENDER_ALL
		]
	]

	draw-window: func [
		wm			[wm!]
		return:		[float32!]
		/local
			tm		[time-meter! value]
			t		[float32!]
	][
		if wm/flags and WIN_FLAG_INVISIBLE = 0 [
			either wm/flags and WIN_RENDER_ALL = 0 [
				draw-update wm/update-list	
			][
				time-meter/start :tm
				host/draw-begin wm
				widgets/draw-gob wm/gob wm/matrix
				host/draw-end wm
				t: time-meter/elapse :tm
				VIEW_MSG(["Full Draw in " t "ms"])
				wm/flags: wm/flags and (not WIN_RENDER_ALL)
			]
		]
		array/clear wm/update-list
		t
	]

	draw-windows: func [
		return:		[float32!]
		/local
			wm		[wm!]
			s		[series!]
			p		[ptr-ptr!]
			e		[ptr-ptr!]
			t		[float32!]
	][
		t: as float32! 0.0
		s: as series! win-list/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		animation/run-all 18
		while [p < e][
			wm: as wm! p/value
			t: t + draw-window wm
			p: p + 1
		]
		t
	]
]