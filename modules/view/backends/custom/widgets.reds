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

	brush: as this! 0
	render: as ID2D1DeviceContext 0
	this: as this! 0

	draw-base: func [
		gob		[gob!]
		/local
			bh	[ID2D1SolidColorBrush]
			rc	[D2D_RECT_F value]
	][
		bh: as ID2D1SolidColorBrush brush/vtbl
		bh/SetColor brush host/to-dx-color gob/bg-color null

		rc/right: as float32! gob/box/x2
		rc/bottom: as float32! gob/box/y2
		rc/left: as float32! gob/box/x1
		rc/top: as float32! gob/box/y1
		render/FillRectangle this :rc as-integer brush 
	]

	set-render: func [rdr [this!]][
		this: rdr
		render: as ID2D1DeviceContext this/vtbl
	]
]
