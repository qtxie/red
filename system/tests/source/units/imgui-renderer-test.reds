Red/System [
	Title:   "Red/System imgui renderer tests"
	Author:  "OpenAI"
	File: 	 %imgui-renderer-test.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %../../../../quick-test/quick-test.reds
#include %../../../library/imgui/renderer.reds

~~~start-file~~~ "imgui-renderer"

===start-group=== "ascii"

	--test-- "renderer-window-and-button"
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/begin "Window" 8.0 8.0 120.0 80.0
		imgui/button "Run" 80.0 24.0
		imgui/end
		imgui-renderer/render-draw-list 24 14
		--assert imgui-renderer/contains-char? #"#"
		--assert imgui-renderer/contains-char? #"W"
		--assert imgui-renderer/contains-char? #"+"
		--assert imgui-renderer/contains-char? #"R"

	--test-- "renderer-slider-fill"
		value: 0.0
		imgui/begin-frame
		imgui/set-mouse-state 82.0 48.0 yes yes
		imgui/begin "Window" 8.0 8.0 160.0 100.0
		imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		imgui-renderer/render-draw-list 28 14
		--assert imgui-renderer/contains-char? #"~"

===end-group===

~~~end-file~~~
