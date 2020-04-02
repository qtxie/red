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
	#include %widgets/field.reds

	draw-gob: func [
		gob		[gob!]
		mat		[D2D_MATRIX_3X2_F]
		/local
			s	[series!]
			p	[ptr-ptr!]
			e	[ptr-ptr!]
			t	[integer!]
			rc	[RECT_F! value]
			x	[float32!]
			y	[float32!]
			box	[RECT_F!]
			m	[D2D_MATRIX_3X2_F value]
	][
		box: gob/cbox
		x: box/left
		y: box/top
		t: GOB_TYPE(gob)
		switch t [
			GOB_BASE	[draw-base gob]
			GOB_FIELD	[draw-field gob]
			GOB_BUTTON	[0]
			GOB_WINDOW	[x: F32_0 y: F32_0]
			default		[0]
		]

		if gob/children <> null [
			matrix2d/translate mat x y :m false
			gfx/set-matrix :m

			rc/left: F32_0
			rc/top: F32_0
			rc/right: box/right - box/left
			rc/bottom: box/bottom - box/top

			gfx/push-clip-rect :rc
			s: as series! gob/children/value
			p: as ptr-ptr! s/offset
			e: as ptr-ptr! s/tail
			while [p < e][
				draw-gob as gob! p/value m
				p: p + 1
			]
			gfx/pop-clip-rect
			gfx/set-matrix mat
		]
	]
]
