Red/System [
	Title:   "Red/System imgui image export demo"
	Author:  "OpenAI"
	File: 	 %image-demo.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %image-export.reds

checked: 0
ratio: 0.0
out-file: "imgui-demo.ppm"
canvas-w: 0
canvas-h: 0

imgui/init

imgui/begin-frame
imgui/set-mouse-state 92.0 96.0 yes yes
imgui/begin "Export Demo" 16.0 16.0 220.0 140.0
imgui/text "Immediate UI"
imgui/button "Render" 90.0 24.0
imgui/same-line 0.0 -1.0
imgui/checkbox "Enabled" :checked
imgui/text "Ratio"
imgui/slider-float "Blend" :ratio 0.0 1.0 140.0
imgui/end

canvas-w: as integer! imgui/draw-max-x
canvas-h: as integer! imgui/draw-max-y
canvas-w: canvas-w + 32
canvas-h: canvas-h + 32

imgui-pixel-renderer/render-draw-list canvas-w canvas-h

either imgui-image-export/save-ppm out-file [
	print "wrote: "
	print-line out-file
	print "size: "
	print imgui-pixel-renderer/width
	print "x"
	print-line imgui-pixel-renderer/height
	print "lit-pixels: "
	print-line imgui-pixel-renderer/count-lit-pixels
][
	print-line "failed to write image"
]
