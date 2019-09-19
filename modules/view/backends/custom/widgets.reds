Red/System [
	Title:	"Drawing widgets"
	Author: "Xie Qingtian"
	File: 	%widgets.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

widgets: context [
	draw-base: func [
		gob		[gob!]
		/local
			bd	[gob-style-border!]
			ss	[gob-style!]
			rc	[RECT32! value]
			m	[float32!]
			n	[float32!]
	][
		ss: gob/styles
		bd: ss/border

		;-- 1. draw shadow
		
		;-- 2. draw background color
		renderer/fill-box gob/box gob/backdrop

		;-- 3. draw background image

		;-- 4. draw border
		if all [ss <> null bd/width <> 0][
			m: as float32! bd/width
			n: m / as float32! 2.0
			rc/left: gob/box/left + n
			rc/top: gob/box/top + n
			rc/right: gob/box/right - n
			rc/bottom: gob/box/bottom - n
			renderer/draw-box rc m bd/color
		]

		;-- 5. draw text
		
	]

	signal-button: func [
		gob		[gob!]
		evt		[event-type!]
	][
		switch evt [
			EVT_ENTER [0]
			EVT_LEAVE [0]
			EVT_LEFT_DOWN [0]
			EVT_LEFT_UP [0]
			default [0]
		]
	]

	draw-update: func [
		update-list	[node!]
	][
		
	]

	draw-gob: func [
		gob		[gob!]
		/local
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
			t	[integer!]
			rc	[RECT32! value]
	][
		t: GOB_TYPE(gob)
		switch t [
			GOB_BASE	[draw-base gob]
			GOB_WINDOW	[0]
			GOB_BUTTON	[0]
			default		[0]
		]
		if gob/children <> null [
			if t <> GOB_WINDOW [
				renderer/set-tranlation gob/box/left gob/box/top
			]
			s: as series! gob/children/value
			p: as ptr-ptr! s/offset
			e: as ptr-ptr! s/tail
			;rc/left: as float32! 0.0
			;rc/top: as float32! 0.0
			;rs-gob/get-content-size gob (as point! :rc) + 1
			;renderer/push-clip-rect rc
			while [p < e][
				draw-gob as gob! p/value
				p: p + 1
			]
			;renderer/pop-clip-rect
		]
	]

	draw-windows: func [
		return:		[float32!]
		/local
			wm		[wm!]
			s		[series!]
			p		[ptr-ptr!]
			e		[ptr-ptr!]
			tm		[time-meter! value]
			t		[float32!]
	][
		t: as float32! 0.0
		s: as series! ui-manager/win-list/value
		p: as ptr-ptr! s/offset
		e: as ptr-ptr! s/tail
		while [p < e][
			wm: as wm! p/value
			if wm/flags and WIN_FLAG_INVISIBLE = 0 [
				renderer/set-render d2d-ctx
				either wm/flags and WIN_RENDER_FULL = 0 [
					draw-update wm/update-list	
				][
					print "Full Draw in "
					time-meter/start :tm
					host/draw-begin wm
					draw-gob wm/gob
					host/draw-end wm
					t: time-meter/elapse :tm
					probe [t "ms"]
					wm/flags: wm/flags and (not WIN_RENDER_FULL)
				]
			]
			p: p + 1
		]
		t
	]
]
