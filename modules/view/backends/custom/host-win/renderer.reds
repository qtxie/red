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
	_pen:	as this! 0		;-- stroke/text color
	_brush: as this! 0		;-- fill color
	_target: as this! 0
	_ctx: as ID2D1DeviceContext 0
	_this: as this! 0
	_renderer: as renderer! 0

	init: func [
		ctx			[this!]
		/local
			clr		[D3DCOLORVALUE]
			brush	[com-ptr! value]
	][
		_this: ctx
		_ctx: as ID2D1DeviceContext _this/vtbl

		clr: to-dx-color 0 null
		_ctx/CreateSolidColorBrush ctx clr null :brush
		_brush: brush/value
		_ctx/CreateSolidColorBrush ctx clr null :brush
		_pen: brush/value
	]

	push-clip-rect: func [
		rc		[RECT_F!]
	][
		_ctx/PushAxisAlignedClip _this rc 0
	]

	pop-clip-rect: func [][
		_ctx/PopAxisAlignedClip _this
	]

	set-tranlation: func [
		x		[float32!]
		y		[float32!]
		/local
			m	[D2D_MATRIX_3X2_F value]
	][
		m/_11: as float32! 1.0
		m/_12: as float32! 0.0
		m/_21: as float32! 0.0
		m/_22: as float32! 1.0
		m/_31:  x
		m/_32:  y
		_ctx/SetTransform _this :m
	]

	reset-matrix: func [/local m [D2D_MATRIX_3X2_F value]][
		m/_11: as float32! 1.0
		m/_12: as float32! 0.0
		m/_21: as float32! 0.0
		m/_22: as float32! 1.0
		m/_31:  as float32! 0.0
		m/_32:  as float32! 0.0
		_ctx/SetTransform _this :m
	]

	set-matrix: func [
		m		[D2D_MATRIX_3X2_F]
	][
		_ctx/SetTransform _this m
	]

	get-matrix: func [m [D2D_MATRIX_3X2_F]][
		_ctx/GetTransform _this m
	]

	draw-box: func [
		rc		[RECT_F!]
		width	[float32!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush _brush/vtbl
		bh/SetColor _brush to-dx-color color null
		_ctx/DrawRectangle _this rc _brush width null
	]

	draw-rounded-box: func [
		rc		[ROUNDED_RECT_F!]
		width	[float32!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush _brush/vtbl
		bh/SetColor _brush to-dx-color color null
		_ctx/DrawRoundedRectangle _this rc _brush width null
	]	

	fill-box: func [
		rc		[RECT_F!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush _brush/vtbl
		bh/SetColor _brush to-dx-color color null
		_ctx/FillRectangle _this rc _brush 
	]

	fill-rounded-box: func [
		rc		[ROUNDED_RECT_F!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush _brush/vtbl
		bh/SetColor _brush to-dx-color color null
		_ctx/FillRoundedRectangle _this rc _brush
	]	

	flush: func [/local err1 err2 [integer!]][
		err1: 0 err2: 0
		_ctx/Flush _this :err1 :err2
	]

	create-text-format: func [
		ss			[gob-style!]
		return: 	[this!]
		/local
			weight	[integer!]
			style	[integer!]
			size	[float32!]
			len		[integer!]
			sym		[integer!]
			name	[c-string!]
			format	[com-ptr! value]
			factory [IDWriteFactory]
	][
		weight:	400
		style:  0
		len:    10

		either ss <> null [
			len: ss/text/font-size
			name: ss/text/font-family
		][
			name: host/default-font-name
		]
		if len <= 0 [len: 10]
		size: ConvertPointSizeToDIP(len)

		;TBD extract font style

		factory: as IDWriteFactory dwrite-factory/vtbl
		factory/CreateTextFormat dwrite-factory name 0 weight style 5 size dw-locale-name :format
		format/value
	]

	get-text-size: func [
		layout		[this!]
		width		[float32-ptr!]
		height		[float32-ptr!]
		/local
			dl		[IDWriteTextLayout]
			metrics	[DWRITE_TEXT_METRICS value]
			hr		[integer!]
	][
		dl: as IDWriteTextLayout layout/vtbl
		hr: dl/GetMetrics layout metrics
		width/value: metrics/width
		height/value: metrics/height
	]

	draw-text: func [
		rc			[RECT_F!]
		txt			[red-string!]
		styles		[gob-style!]
		/local
			fmt		[this!]
			layout	[this!]
			x		[float32!]
			y		[float32!]
			w		[float32!]
			h		[float32!]
	][
		fmt: as this! create-text-format styles

		w: rc/right - rc/left
		h: rc/bottom - rc/top
		layout: create-text-layout txt fmt as-integer w as-integer h

		x: F32_0 y: F32_0
		get-text-size layout :x :y

		;-- draw text in the center of the rect
		w: w - x / as float32! 2.0
		h: h - y / as float32! 2.0
		x: rc/left + w
		y: rc/top + h

		_ctx/DrawTextLayout _this x y layout _pen 0
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
			target	[renderer!]
			output	[com-ptr! value]
			sigma	[float32!]
			spread	[integer!]
			unk		[IUnknown]
			err1	[integer!]
			err2	[integer!]
	][
		until [
			sbmp: bmp
			_ctx/CreateEffect _this CLSID_D2D1Shadow :eff-v
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
			_ctx/DrawImage _this sbmp pt null 1 0
			COM_SAFE_RELEASE(unk sbmp)
			COM_SAFE_RELEASE(unk eff)
			s: s/next
			null? s
		]
		pt/x: rc/left
		pt/y: rc/top
		_ctx/DrawImage _this bmp pt null 1 0
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
		_ctx/CreateBitmap2 _this sz null 0 props :bitmap
		as this! bitmap/value
	]

	set-target: func [
		ptr [this!]
	][
		_target: ptr
		_ctx/SetTarget _this ptr
	]

	get-target: func [return: [this!]][_target]

	set-graphic-ctx: func [ptr [this!]][
		_this: ptr
		_ctx: as ID2D1DeviceContext _this/vtbl
	]

	set-renderer: func [
		ptr [renderer!]
	][
		_renderer: ptr
	]
]