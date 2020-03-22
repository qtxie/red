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
	#include %widgets/base.reds
	#include %widgets/button.reds

	draw-gob: func [
		gob		[gob!]
		mat		[D2D_MATRIX_3X2_F]
		/local
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
			t	[integer!]
			rc	[RECT_F! value]
			ss	[gob-style!]
			x	[float32!]
			y	[float32!]
			xx	[float32!]
			yy	[float32!]
			box	[RECT_F!]
			m	[D2D_MATRIX_3X2_F value]
			bd-w [integer!]
	][
		t: GOB_TYPE(gob)
		switch t [
			GOB_BASE	[draw-base gob]
			GOB_BUTTON	[draw-button gob]
			GOB_WINDOW	[0]
			default		[0]
		]
		if gob/children <> null [
			ss: gob/styles
			box: gob/box
			either t <> GOB_WINDOW [
				x: box/left
				y: box/top		
			][
				x: F32_0
				y: F32_0
			]

			either ss <> null [
				bd-w: ss/border/width
				x: x + ss/padding/left + bd-w
				y: y + ss/padding/top + bd-w
				xx: ss/padding/right - bd-w
				yy: ss/padding/bottom - bd-w
			][
				xx: F32_0
				yy: F32_0
			]

			matrix2d/translate mat x y m false
			renderer/set-matrix m

			rc/left: F32_0
			rc/top: F32_0
			rc/right: box/right - x - xx
			rc/bottom: box/bottom - y - yy
			renderer/push-clip-rect :rc
			s: as series! gob/children/value
			p: as ptr-ptr! s/offset
			e: as ptr-ptr! s/tail
			while [p < e][
				draw-gob as gob! p/value m
				p: p + 1
			]
			renderer/pop-clip-rect
		]
	]
]
