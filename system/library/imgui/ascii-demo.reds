Red/System [
	Title:   "Red/System imgui ASCII demo"
	Author:  "OpenAI"
	File: 	 %ascii-demo.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %renderer.reds

checked: 0
ratio: 0.0

imgui/init
imgui/begin-frame
imgui/set-mouse-state 150.0 48.0 yes yes
imgui/begin "Ascii Demo" 8.0 8.0 200.0 120.0
imgui/button "Run" 80.0 24.0
imgui/same-line 0.0 -1.0
imgui/checkbox "Enabled" :checked
imgui/text "Value"
imgui/slider-float "Ratio" :ratio 0.0 1.0 120.0
imgui/end

imgui-renderer/render-draw-list 32 18
imgui-renderer/print-canvas
