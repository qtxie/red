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
	][
		renderer/fill-box as RECT_F :gob/box gob/backdrop
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
]
