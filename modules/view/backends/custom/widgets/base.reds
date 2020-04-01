Red/System [
	Title:	"Drawing base widget"
	Author: "Xie Qingtian"
	File: 	%base.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

draw-base: func [
	gob			[gob!]
	/local
		ss		[gob-style!]
		box		[RECT_F!]
		cbox	[RECT_F!]
		rc		[ROUNDED_RECT_F! value]
		bd-w	[float32!]
		n		[float32!]
		w		[float32!]
		h		[float32!]
		x		[float32!]
		y		[float32!]
		bmp		[this!]
		old		[this!]
		mat		[D2D_MATRIX_3X2_F value]
		blk		[red-block! value]
		str		[red-string!]
		img		[red-image!]
		round?	[logic!]
		shadow?	[logic!]
		border? [logic!]
		bcolor	[integer!]
][
	round?: no
	shadow?: no
	border?: no

	ss: gob/styles
	either ss <> null [
		round?: ss/radius <> F32_0
		shadow?: ss/shadow <> null
		border?: ss/border/width <> 0
		if ss/states and GOB_STYLE_BACKDROP <> 0 [
			bcolor: ss/backdrop
		]
	][bcolor: gob/backdrop]

	box: gob/box
	either shadow? [		;-- 1. prepares for drawing shadow
		n: dpi-value / as float32! 96.0
		w: box/right - box/left
		h: box/bottom - box/top
		bmp: gfx/create-bitmap
				as-integer w + (as float32! 1.0) * n
				as-integer h + (as float32! 1.0) * n

		old: gfx/get-target		;-- save old target
		gfx/set-target bmp
		gfx/get-matrix :mat
		gfx/reset-matrix

		rc/left: as float32! 0.0
		rc/top:  as float32! 0.0
		rc/right:  w
		rc/bottom: h
		box: as RECT_F! :rc
	][
		if round? [
			copy-memory as byte-ptr! :rc as byte-ptr! box size? RECT_F!
			box: as RECT_F! :rc
		]
	]

	if border? [
		bd-w: as float32! ss/border/width
		n: bd-w / as float32! 2.0
		rc/left: box/left + n
		rc/top: box/top + n
		rc/right: box/right - n
		rc/bottom: box/bottom - n
	]

	;-- 2. draw background color
	either round? [
		rc/radiusX: ss/radius
		rc/radiusY: ss/radius
		gfx/fill-rounded-box :rc bcolor
	][gfx/fill-box box bcolor]

	;-- 3. draw background image
	if gob/image <> null [
		img: as red-image! :blk
		img/node: gob/image
		gfx/draw-image box img
	]

	;-- 4. draw border
	if border? [
		either round? [
			gfx/draw-rounded-box :rc bd-w ss/border/color
		][
			gfx/draw-box as RECT_F! :rc bd-w ss/border/color
		]
	]

	;-- 5. draw text
	if gob/text <> null [
		str: as red-string! :blk
		str/header: TYPE_STRING
		str/head: 0
		str/node: gob/text
		str/cache: null
		gfx/draw-text box str ss
	]

	;-- 6. draw draw block
	if gob/draw <> null [
		unless shadow? [gfx/get-matrix :mat]
		cbox: gob/cbox
		x: cbox/left + mat/_31
		y: cbox/top + mat/_32
		gfx/set-tranlation x y
		rc/left: as float32! 0.0
		rc/top: as float32! 0.0
		rc/right: cbox/right - cbox/left
		rc/bottom: cbox/bottom - cbox/top
		gfx/push-clip-rect as RECT_F! :rc
		blk/header: TYPE_BLOCK
		blk/head: gob/draw-head
		blk/node: gob/draw
		do-draw as int-ptr! gob null blk no yes yes yes
		gfx/pop-clip-rect
		unless shadow? [gfx/set-matrix :mat]
	]

	if shadow? [
		gfx/flush
		gfx/set-target old
		gfx/set-matrix :mat
		gfx/draw-shadow bmp gob/box ss/shadow
	]
]