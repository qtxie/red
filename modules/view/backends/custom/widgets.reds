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
		gob			[gob!]
		/local
			ss		[gob-style!]
			box		[RECT_F!]
			rc		[RECT_F! value]
			bd-w	[float32!]
			n		[float32!]
			w		[float32!]
			h		[float32!]
			x		[float32!]
			y		[float32!]
			bmp		[this!]
			old		[this!]
			shadow?	[logic!]
			mat		[D2D_MATRIX_3X2_F value]
			blk		[red-block! value]
	][
		ss: gob/styles
		shadow?: all [ss <> null ss/shadow <> null]

		;-- 1. draw shadow
		box: gob/box
		if shadow? [
			n: host/dpi-value / as float32! 96.0
			w: box/right - box/left
			h: box/bottom - box/top
			bmp: renderer/create-bitmap
					as-integer w + (as float32! 1.0) * n
					as-integer h + (as float32! 1.0) * n

			old: renderer/get-target		;-- save old target
			renderer/set-target bmp
			renderer/get-matrix :mat
			renderer/reset-matrix

			rc/left: as float32! 0.5
			rc/top:  as float32! 0.5
			rc/right:  w + (as float32! 0.5)
			rc/bottom: h + (as float32! 0.5)
			box: :rc
		]

		;-- 2. draw background color
		renderer/fill-box box gob/backdrop

		;-- 3. draw background image

		;-- 4. draw border
		if all [ss <> null ss/border/width <> 0][
			bd-w: as float32! ss/border/width
			n: bd-w / as float32! 2.0
			rc/left: box/left + n
			rc/top: box/top + n
			rc/right: box/right - n
			rc/bottom: box/bottom - n
			renderer/draw-box rc bd-w ss/border/color
		]

		;-- 5. draw text

		;-- 6. draw draw block
		if gob/draw <> null [
			unless shadow? [renderer/get-matrix :mat]
			x: box/left + mat/_31
			y: box/top + mat/_32
			either ss <> null [
				x: x + bd-w + ss/padding/left
				y: y + bd-w + ss/padding/top
				w: bd-w * 2 + ss/padding/left + ss/padding/right
				h: bd-w * 2 + ss/padding/top + ss/padding/bottom
			][
				w: as float32! 0.0
				h: as float32! 0.0
			]
			renderer/set-tranlation x y
			rc/left: as float32! 0.0
			rc/top: as float32! 0.0
			rc/right: box/right - box/left - w
			rc/bottom: box/bottom - box/top - h
			renderer/push-clip-rect rc
			blk/header: TYPE_BLOCK
			blk/head: gob/draw-head
			blk/node: gob/draw
			do-draw as int-ptr! gob null blk no yes yes yes
			renderer/pop-clip-rect
			unless shadow? [renderer/set-matrix :mat]
		]

		if shadow? [
			renderer/flush
			renderer/set-target old
			renderer/set-matrix :mat
			renderer/draw-shadow bmp gob/box ss/shadow
		]
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

	draw-gob: func [
		gob		[gob!]
		/local
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
			t	[integer!]
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
			while [p < e][
				draw-gob as gob! p/value
				p: p + 1
			]
		]
	]
]
