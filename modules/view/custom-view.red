Red [
	Title:   "Custom drawing widgets"
	Author:  "Xie Qingtian"
	File: 	 %custom-view.red
	Tabs:	 4
	Rights:  "Copyright (C)2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/dockimbel/Red/blob/master/BSL-License.txt
	}
]

custom-view: context [
	down-face:  none
	hover-face: none

	manager: #include %custom-view-manager.red

	init: func [][
		put system/view/VID/styles 'window manager
	]
]

custom-view/init

;-- let's create a button widget
RoundButton: object [

	name: 'RoundButton

	style: [
		default-actor: on-click
		template: [type: name size: 60x60]
	]

	init: func [][
		make block! [normal 255.130.136]
	]

	drawing: func [face [object!] draw-blk [block!] /local color r center][
		color: face/state/1/2
		center: face/size / 2
		r: either center/x > center/y [center/y][center/x]
		reduce/into ['pen color 'fill-pen color 'circle center r] draw-blk
	]

	enter: func [face [object!]][
		face/state/1/2: 255.99.109
	]

	leave: func [face [object!]][
		face/state/1/2: 255.130.136
	]

	down: func [face [object!]][
		face/state/1/2: 255.48.58
	]

	up: func [face [object!]][
		face/state/1/2: 255.99.109
	]
]

system/view/register 'myButton RoundButton

view [size 500x500 myButton [b/offset: b/offset + 3x3] b: myButton 20x20]