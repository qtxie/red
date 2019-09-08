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

	draw-box: func [
		rc		[RECT_F]
		color	[integer!]
		/local
			bh	[ID2D1SolidColorBrush]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush to-dx-color color null
		render/DrawRectangle this rc as-integer brush as float32! 1.0 0
	]

	fill-box: func [
		rc		[RECT_F]
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