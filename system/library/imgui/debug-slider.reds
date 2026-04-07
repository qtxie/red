Red/System [
	Title:   "Red/System imgui slider renderer debug"
	Author:  "OpenAI"
	File: 	 %debug-slider.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %renderer.reds

value: 0.0

imgui/init
imgui/begin-frame
imgui/set-mouse-state 82.0 48.0 yes yes
imgui/begin "Window" 8.0 8.0 160.0 100.0
imgui/slider-float "Value" :value 0.0 1.0 120.0
imgui/end

imgui-renderer/render-draw-list 28 14
imgui-renderer/print-canvas
