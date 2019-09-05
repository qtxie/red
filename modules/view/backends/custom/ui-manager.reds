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

ui-manager: context [	;-- manager all the windows

	win-list:		as node! 0
	active-win:		as wm! 0

	init: func [
		/local
			v1	[node!]
			s	[series!]
	][
		win-list: rs-gob/make-vector 4
	]

	on-gc-mark: func [
		/local
			w	[wm!]
			s	[series!]
			p	[int-ptr!]
			e	[int-ptr!]
	][
		collector/keep win-list
		s: as series! win-list/value
		p: as int-ptr! s/offset
		e: as int-ptr! s/tail
		while [p < e][
			w: as wm! p/value
			collector/keep w/update-list
			p: p + 1
		]
	]

	add-window: func [
		hwnd	[handle!]
		root	[gob!]
		render	[render-target!]
		return: [wm!]
		/local
			p	[wm!]
	][
		p: as wm! allocate size? wm!
		p/flags: WIN_RENDER_FULL
		p/hWnd: hWnd
		p/gob: root
		p/render: render
		p/focused: null
		p/update-list: rs-gob/make-vector 16
		rs-gob/vector-append win-list as int-ptr! p
		p
	]

	add-update: func [
		gob		[gob!]
	][
		unless rs-gob/set-flag? gob GOB_FLAG_UPDATE [
			gob/flags: gob/flags or GOB_FLAG_UPDATE
			rs-gob/vector-append active-win/update-list as int-ptr! gob
		]
	]
]
