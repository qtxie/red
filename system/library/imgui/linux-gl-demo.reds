Red/System [
	Title:   "Red/System imgui Linux GLX demo"
	Author:  "OpenAI"
	File: 	 %linux-gl-demo.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %linux-glx.reds

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
	imgui/begin "Linux GL Demo" 16.0 16.0 260.0 150.0
	imgui/text "Immediate UI on OpenGL"
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

either imgui-glx/open-window "Red/System ImGui OpenGL Demo" win-w win-h [
	build-frame no
	imgui-glx/render-draw-list
	running?: yes
	while [running?][
		evtype: imgui-glx/wait-event
		case [
			evtype = Expose-type [
				imgui-glx/sync-imgui-mouse no
				build-frame no
				imgui-glx/render-draw-list
			]
			evtype = MotionNotify-type [
				imgui-glx/sync-imgui-mouse no
				build-frame no
				imgui-glx/render-draw-list
			]
			evtype = ButtonPress-type [
				imgui-glx/mouse-down?: yes
				imgui-glx/sync-imgui-mouse yes
				build-frame yes
				imgui-glx/render-draw-list
			]
			evtype = ButtonRelease-type [
				imgui-glx/mouse-down?: no
				imgui-glx/sync-imgui-mouse no
				build-frame no
				imgui-glx/render-draw-list
			]
			evtype = KeyPress-type [
				if imgui-glx/handle-keypress [running?: no]
				unless not running? [
					build-frame no
					imgui-glx/render-draw-list
				]
			]
			evtype = DestroyNotify-type [
				running?: no
			]
			true [0]
		]
	]
	imgui-glx/close-window
	print-line "window closed"
][
	print-line "failed to open GLX display/context"
]
