Red/System [
	Title:   "Red/System imgui draw debug"
	Author:  "OpenAI"
	File: 	 %debug-draw.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %imgui.reds

idx: 0
value: 0.0
label: ""

print "scenario-1^/"
imgui/init
imgui/begin-frame
imgui/set-mouse-state 0.0 0.0 no no
imgui/begin "Window" 10.0 10.0 220.0 140.0
imgui/text "Hello"
imgui/button "Run" 80.0 24.0
imgui/end

print "draw-count: "
print-line imgui/draw-count?

idx: 1
while [idx <= imgui/draw-count?][
	label: imgui/draw-label-at idx
	print idx
	print " kind="
	print imgui/draw-kind-at idx
	print " color="
	print imgui/draw-color-at idx
	print " label="
	print-line either null? label ["<null>"][label]
	idx: idx + 1
]

print "^/scenario-2^/"
value: 0.0
imgui/begin-frame
imgui/set-mouse-state 82.0 48.0 yes yes
imgui/begin "Window" 10.0 10.0 220.0 140.0
imgui/slider-float "Value" :value 0.0 1.0 120.0
imgui/end

print "draw-count: "
print-line imgui/draw-count?
print "value-x100: "
print-line as integer! (value * 100.0)

idx: 1
while [idx <= imgui/draw-count?][
	label: imgui/draw-label-at idx
	print idx
	print " kind="
	print imgui/draw-kind-at idx
	print " color="
	print imgui/draw-color-at idx
	print " val="
	print imgui/draw-value-at idx
	print " label="
	print-line either null? label ["<null>"][label]
	idx: idx + 1
]
