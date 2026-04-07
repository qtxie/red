Red/System [
	Title:   "Red/System imgui Linux X11 demo"
	Author:  "OpenAI"
	File: 	 %linux-demo.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %linux-x11.reds

checked: 0
ratio: 0.0
win-w: 0
win-h: 0
show-alt?: no
status-text: "Idle"
running?: yes
evtype: 0

build-frame: func [pressed? [logic!]][
	imgui/begin-frame
	imgui/begin "Linux Demo" 16.0 16.0 260.0 150.0
	imgui/text "Immediate UI on X11"
	if imgui/button "Render" 90.0 24.0 [
		show-alt?: not show-alt?
		status-text: either show-alt? ["Pressed"]["Idle"]
	]
	imgui/same-line 0.0 -1.0
	imgui/checkbox "Enabled" :checked
	imgui/text "Blend"
	imgui/slider-float "Amount" :ratio 0.0 1.0 160.0
	imgui/text status-text
	imgui/end
]

imgui/init
imgui/set-mouse-state 0.0 0.0 no no
build-frame no

win-w: as integer! imgui/draw-max-x
win-h: as integer! imgui/draw-max-y
win-w: win-w + 24
win-h: win-h + 24

either imgui-x11/open-window "Red/System ImGui X11 Demo" win-w win-h [
	build-frame no
	imgui-x11/render-draw-list
	running?: yes
	while [running?][
		evtype: imgui-x11/wait-event
		case [
			evtype = Expose-type [
				imgui-x11/sync-imgui-mouse no
				build-frame no
				imgui-x11/render-draw-list
			]
			evtype = MotionNotify-type [
				imgui-x11/sync-imgui-mouse no
				build-frame no
				imgui-x11/render-draw-list
			]
			evtype = ButtonPress-type [
				imgui-x11/mouse-down?: yes
				imgui-x11/sync-imgui-mouse yes
				build-frame yes
				imgui-x11/render-draw-list
			]
			evtype = ButtonRelease-type [
				imgui-x11/mouse-down?: no
				imgui-x11/sync-imgui-mouse no
				build-frame no
				imgui-x11/render-draw-list
			]
			evtype = KeyPress-type [
				if imgui-x11/handle-keypress [running?: no]
				unless not running? [
					build-frame no
					imgui-x11/render-draw-list
				]
			]
			evtype = DestroyNotify-type [
				running?: no
			]
			true [0]
		]
	]
	imgui-x11/close-window
	print-line "window closed"
][
	print-line "failed to open X11 display"
]
