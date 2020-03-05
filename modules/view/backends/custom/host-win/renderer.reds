Red/System [
	Title:	"GOB Renderer"
	Author: "Xie Qingtian"
	File: 	%renderer.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define GAUSSIAN_SCALE_FACTOR 1.87997120597325

renderer: context [
	brush: as this! 0
	target: as this! 0
	ctx: as ID2D1DeviceContext 0
	this: as this! 0

	push-clip-rect: func [
		rc		[RECT_F!]
	][
		ctx/PushAxisAlignedClip this rc 0
	]

	pop-clip-rect: func [][
		ctx/PopAxisAlignedClip this
	]

	set-tranlation: func [
		x		[float32!]
		y		[float32!]
		/local
			m	[D2D_MATRIX_3X2_F value]
	][
		m/m11: as float32! 1.0
		m/m12: as float32! 0.0
		m/m21: as float32! 0.0
		m/m22: as float32! 1.0
		m/dx:  x
		m/dy:  y
		ctx/SetTransform this :m
	]

	reset-matrix: func [/local m [D2D_MATRIX_3X2_F value]][
		m/m11: as float32! 1.0
		m/m12: as float32! 0.0
		m/m21: as float32! 0.0
		m/m22: as float32! 1.0
		m/dx:  as float32! 0.0
		m/dy:  as float32! 0.0
		ctx/SetTransform this :m
	]

	set-matrix: func [
		m		[D2D_MATRIX_3X2_F]
	][
		ctx/SetTransform this m
	]

	get-matrix: func [m [D2D_MATRIX_3X2_F]][
		ctx/GetTransform this m
	]

	draw-box: func [
		rc		[RECT_F!]
		width	[float32!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush to-dx-color color null
		ctx/DrawRectangle this rc brush width null
	]

	fill-box: func [
		rc		[RECT_F!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush to-dx-color color null
		ctx/FillRectangle this rc brush 
	]

	flush: func [/local err1 err2 [integer!]][
		err1: 0 err2: 0
		ctx/Flush this :err1 :err2
	]

	draw-shadow: func [			;-- draw bitmap with shadow
		bmp			[this!]
		rc			[RECT_F!]
		s			[gob-style-shadow!]
		/local
			sbmp	[this!]
			eff-v	[com-ptr! value]
			eff-s	[com-ptr! value]
			eff		[this!]
			eff2	[this!]
			effect	[ID2D1Effect]
			pt		[POINT_2F value]
			target	[render-target!]
			output	[com-ptr! value]
			sigma	[float32!]
			spread	[integer!]
			unk		[IUnknown]
			err1	[integer!]
			err2	[integer!]
	][
		until [
			sbmp: bmp
			ctx/CreateEffect this CLSID_D2D1Shadow :eff-v
			eff: eff-v/value
			effect: as ID2D1Effect eff/vtbl
			effect/SetInput eff 0 sbmp true

			sigma: as float32! (as float! s/radius) / GAUSSIAN_SCALE_FACTOR
			effect/base/setValue eff 0 0 as byte-ptr! :sigma size? float32!
			effect/base/setValue eff 1 0 as byte-ptr! to-dx-color s/color null size? D3DCOLORVALUE

			effect/GetOutput eff :output
			sbmp: output/value

			pt/x: rc/left + s/offset/x
			pt/y: rc/top  + s/offset/y
			ctx/DrawImage this sbmp pt null 1 0
			COM_SAFE_RELEASE(unk sbmp)
			COM_SAFE_RELEASE(unk eff)
			s: s/next
			null? s
		]
		pt/x: rc/left
		pt/y: rc/top
		ctx/DrawImage this bmp pt null 1 0
		COM_SAFE_RELEASE(unk bmp)
	]

	create-bitmap: func [
		width		[uint32!]
		height		[uint32!]
		return: 	[this!]
		/local
			props	[D2D1_BITMAP_PROPERTIES1 value]
			sz		[SIZE_U! value]
			bitmap	[ptr-value!]
	][
		props/format: 87
		props/alphaMode: 1
		props/dpiX: host/dpi-x
		props/dpiY: host/dpi-y
		props/options: 1
		props/colorContext: null
		sz/width: width
		sz/height: height
		ctx/CreateBitmap2 this sz null 0 props :bitmap
		as this! bitmap/value
	]

	set-target: func [
		ptr [this!]
	][
		target: ptr
		ctx/SetTarget this ptr
	]

	get-target: func [return: [this!]][target]

	set-graphic-ctx: func [ptr [this!]][
		this: ptr
		ctx: as ID2D1DeviceContext this/vtbl
	]
]