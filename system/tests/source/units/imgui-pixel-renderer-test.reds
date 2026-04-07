Red/System [
	Title:   "Red/System imgui pixel renderer tests"
	Author:  "OpenAI"
	File: 	 %imgui-pixel-renderer-test.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %../../../../quick-test/quick-test.reds
#include %../../../library/imgui/pixel-renderer.reds

~~~start-file~~~ "imgui-pixel-renderer"

===start-group=== "pixels"

	--test-- "pixel-window-and-button"
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/begin "Window" 8.0 8.0 120.0 80.0
		imgui/button "Run" 80.0 24.0
		imgui/end
		imgui-pixel-renderer/render-draw-list 160 100
		--assert (imgui-pixel-renderer/pixel-at 8 8) > (as byte! 0)
		--assert (imgui-pixel-renderer/pixel-at 20 42) > (as byte! 0)
		--assert (imgui-pixel-renderer/count-lit-pixels) > 200

	--test-- "pixel-slider-fill"
		value: 0.0
		imgui/begin-frame
		imgui/set-mouse-state 82.0 48.0 yes yes
		imgui/begin "Window" 8.0 8.0 160.0 100.0
		imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		imgui-pixel-renderer/render-draw-list 200 120
		--assert (imgui-pixel-renderer/pixel-at 22 42) > (as byte! 0)
		--assert (imgui-pixel-renderer/pixel-at 70 42) > (as byte! 0)
		--assert (imgui-pixel-renderer/count-lit-pixels) > 500

===end-group===

~~~end-file~~~
