Red/System [
	Title:   "Red/System native imgui demo"
	Author:  "OpenAI"
	File: 	 %demo.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %imgui.reds

checked: 0
ratio: 0.0

print-result: func [
	label [c-string!]
	flag  [logic!]
][
	print label
	print ": "
	print-line either flag ["true"]["false"]
]

imgui/init

imgui/begin-frame
imgui/set-mouse-state 40.0 48.0 yes yes
imgui/begin "Demo" 10.0 10.0 320.0 180.0
clicked?: imgui/button "Click me" 100.0 24.0
imgui/end

imgui/begin-frame
imgui/set-mouse-state 150.0 48.0 yes yes
imgui/begin "Demo" 10.0 10.0 320.0 180.0
imgui/button "Click me" 100.0 24.0
imgui/same-line 0.0 -1.0
check?: imgui/checkbox "Enabled" :checked
imgui/end

imgui/begin-frame
imgui/set-mouse-state 90.0 77.0 yes yes
imgui/begin "Demo" 10.0 10.0 320.0 180.0
imgui/text "Slider frame"
slide?: imgui/slider-float "Ratio" :ratio 0.0 1.0 120.0
imgui/end

print-result "button-clicked" clicked?
print-result "checkbox-toggled" check?
print "checkbox-value: "
print-line either checked = 0 ["0"]["1"]
print-result "slider-changed" slide?
print "slider-value-x100: "
print-line as integer! (ratio * 100.0)
print "item-count: "
print-line imgui/item-count?
print "draw-count: "
print-line imgui/draw-count?
