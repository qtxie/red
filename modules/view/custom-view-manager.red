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

[
default-actor: on-down
template: [
	type: 'window size: 100x100 flags: [all-over]
	actors: object [
		on-created: func [face [object!] event][
			system/view/current-win: face
		]
		on-over: func [
			face [object!]
			event [event!]
			/local f pt widget hover find? widgets upper lower
		][
			pt: event/offset
			hover: custom-view/hover-face
			widgets: system/view/widgets
			foreach f face/pane [
				upper: f/offset
				lower: upper + f/size
				if all [
					pt/x >= upper/x
					pt/x <= lower/x
					pt/y >= upper/y
					pt/y <= lower/y
				][
					find?: yes
					either hover [
						either not same? f hover [
							custom-view/hover-face: f
							widget: select widgets hover/type
							widget/leave f
						][break]
					][
						custom-view/hover-face: f
					]
					widget: select widgets f/type
					widget/enter f
					system/view/platform/redraw face
					break
				]
			]
			if all [hover not find?][
				widget: select widgets hover/type
				widget/leave hover
				custom-view/hover-face: none
				system/view/platform/redraw face
			]
		]

		on-down: func [
			face [object!] event [event!]
			/local hover widget
		][
			hover: custom-view/hover-face
			custom-view/down-face: hover
			if hover [
				widget: select system/view/widgets hover/type
				widget/down hover
				system/view/platform/redraw face
				system/view/awake/with event hover
			]
		]

		on-up: func [
			face [object!] event [event!]
			/local hover widget
		][
			hover: custom-view/hover-face
			if hover [
				if same? hover custom-view/down-face [
					event/type: 'click
					system/view/awake/with event hover
				]
				widget: select system/view/widgets hover/type
				widget/up hover
				system/view/platform/redraw face
			]
		]

		on-drawing: func [
			face [object!] event [event!]
			/local cmds f widget push-blk
		][
			cmds: clear []
			push-blk: []
			reduce/into ['pen 255.255.255 'fill-pen 255.255.255 'box 0x0 face/size] cmds
			system/view/platform/draw-face face cmds
			clear cmds
			foreach f face/pane [
				clear push-blk
				reduce/into ['translate f/offset] push-blk
				widget: select system/view/widgets f/type
				widget/drawing f tail push-blk
				repend push-blk ['translate 0 - f/offset]
				system/view/platform/draw-face face push-blk
			]
		]
	]
]]