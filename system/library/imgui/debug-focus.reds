Red/System [
	Title:   "Red/System imgui focus debug"
	Author:  "OpenAI"
	File: 	 %debug-focus.reds
]

#include %imgui.reds

flag: 0

print "frame1^/"
imgui/init
imgui/begin-frame
imgui/set-mouse-state 0.0 0.0 no no
imgui/set-key-state yes no no no
imgui/begin "Window" 10.0 10.0 220.0 140.0
imgui/button "Run" 80.0 24.0
imgui/checkbox "Flag" :flag
imgui/end
imgui/end-frame
print "focus="
print-line imgui/ctx/focused-item

print "frame2^/"
imgui/begin-frame
imgui/set-mouse-state 0.0 0.0 no no
imgui/set-key-state yes no no no
imgui/begin "Window" 10.0 10.0 220.0 140.0
imgui/button "Run" 80.0 24.0
imgui/checkbox "Flag" :flag
imgui/end
imgui/end-frame
print "focus="
print-line imgui/ctx/focused-item

print "frame3^/"
imgui/begin-frame
imgui/set-mouse-state 0.0 0.0 no no
imgui/set-key-state no yes no no
imgui/begin "Window" 10.0 10.0 220.0 140.0
imgui/button "Run" 80.0 24.0
imgui/checkbox "Flag" :flag
imgui/end
imgui/end-frame
print "focus="
print-line imgui/ctx/focused-item
print "flag="
print-line flag
