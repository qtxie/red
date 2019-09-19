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

renderer: context [
	brush: as this! 0
	render: as ID2D1DeviceContext 0
	this: as this! 0

	push-clip-rect: func [
		rc		[RECT32!]
	][
		render/PushAxisAlignedClip this rc 0
	]

	pop-clip-rect: func [][
		render/PopAxisAlignedClip this
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
		render/SetTransform this :m
	]

	set-matrix: func [
		m		[D2D_MATRIX_3X2_F]
	][
		render/SetTransform this m
	]

	draw-box: func [
		rc		[RECT32!]
		width	[float32!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush to-dx-color color null
		render/DrawRectangle this rc as-integer brush width 0
	]

	fill-box: func [
		rc		[RECT32!]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush to-dx-color color null
		render/FillRectangle this rc as-integer brush 
	]

	set-render: func [rdr [this!]][
		this: rdr
		render: as ID2D1DeviceContext this/vtbl
	]
]