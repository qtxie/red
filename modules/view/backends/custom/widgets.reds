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
			rc	[RECT_F value]
	][
		rc/right: as float32! gob/box/x2
		rc/bottom: as float32! gob/box/y2
		rc/left: as float32! gob/box/x1
		rc/top: as float32! gob/box/y1
		renderer/fill-box :rc gob/bg-color
	]
]
