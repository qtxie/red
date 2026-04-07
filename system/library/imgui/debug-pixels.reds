Red/System [
	Title:   "Red/System imgui pixel debug"
	Author:  "OpenAI"
	File: 	 %debug-pixels.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %pixel-renderer.reds

value: 0.0

print "scene-1^/"
imgui/init
imgui/begin-frame
imgui/set-mouse-state 0.0 0.0 no no
imgui/begin "Window" 8.0 8.0 120.0 80.0
imgui/button "Run" 80.0 24.0
imgui/end
imgui-pixel-renderer/render-draw-list 160 100
print "p(8,8)="
print-line imgui-pixel-renderer/pixel-at 8 8
print "p(20,12)="
print-line imgui-pixel-renderer/pixel-at 20 12
print "p(20,42)="
print-line imgui-pixel-renderer/pixel-at 20 42
print "p(12,38)="
print-line imgui-pixel-renderer/pixel-at 12 38
print "lit="
print-line imgui-pixel-renderer/count-lit-pixels

print "^/scene-2^/"
value: 0.0
imgui/begin-frame
imgui/set-mouse-state 82.0 48.0 yes yes
imgui/begin "Window" 8.0 8.0 160.0 100.0
imgui/slider-float "Value" :value 0.0 1.0 120.0
imgui/end
imgui-pixel-renderer/render-draw-list 200 120
print "p(22,42)="
print-line imgui-pixel-renderer/pixel-at 22 42
print "p(70,42)="
print-line imgui-pixel-renderer/pixel-at 70 42
print "p(130,42)="
print-line imgui-pixel-renderer/pixel-at 130 42
print "p(40,42)="
print-line imgui-pixel-renderer/pixel-at 40 42
