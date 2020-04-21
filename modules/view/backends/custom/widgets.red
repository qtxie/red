Red [
	Title:	"GOB-based widgets"
	Author: "Xie Qingtian"
	File: 	%widgets.red
	Tabs: 	4
	Rights: "Copyright (C) 2020 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

gob-widgets: make map! 64

register-widget: func [
	name	[word!]
	proto	[gob!]
][
	put gob-widgets name proto
]

custom-widgets: object [
	btn-radius: 4
	btn-shadow-normal: [
		0x3 1 -2 0.0.0.204
		0x2 2 0.0.0.220
		0x1 5 0.0.0.224
	]
	btn-shadow-down: [
		0x3 7 -2 0.0.0.180
		0x2 8 0.0.0.200
		0x1 11 0.0.0.204
	]

	btn-normal: object [
		background: 255.255.255
		text-color: blue
		border-radius: btn-radius
		shadow: btn-shadow-normal
	]

	btn-hover: object [
		background: 240.240.240
		border-radius: btn-radius
		shadow: btn-shadow-normal
	]

	btn-down: object [
		background: 210.210.210
		border-radius: btn-radius
		shadow: btn-shadow-down
	]

	register: func [][
		register-widget 'window make gob! [
			type: 'window color: white
		]

		register-widget 'button make gob! [
			actors: reduce [
				'create func [gob _][]
				'over func [gob event][
					gob/styles: either find event/flags 'away [btn-normal][btn-hover]
				]
				'down func [gob evt][
					gob/styles: btn-down
				]
				'up func [gob evt][
					gob/styles: btn-normal
				]
			]
			styles: btn-normal
		]

		register-widget 'base make gob! []

		register-widget 'panel make gob! []

		register-widget 'text make gob! []
	]
]
