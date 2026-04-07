Red/System [
	Title:   "Red/System imgui core tests"
	Author:  "OpenAI"
	File: 	 %imgui-test.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %../../../../quick-test/quick-test.reds
#include %../../../library/imgui/imgui.reds

keyboard-focus-step2: func [return: [integer!] /local flag [integer!]][
	flag: 0
	imgui/init
	imgui/begin-frame
	imgui/set-mouse-state 0.0 0.0 no no
	imgui/set-key-state yes no no no
	imgui/begin "Window" 10.0 10.0 220.0 140.0
	imgui/button "Run" 80.0 24.0
	imgui/checkbox "Flag" :flag
	imgui/end
	imgui/end-frame

	imgui/begin-frame
	imgui/set-mouse-state 0.0 0.0 no no
	imgui/set-key-state yes no no no
	imgui/begin "Window" 10.0 10.0 220.0 140.0
	imgui/button "Run" 80.0 24.0
	imgui/checkbox "Flag" :flag
	imgui/end
	imgui/end-frame
	imgui/ctx/focused-item
]

keyboard-activate-checkbox: func [return: [integer!] /local flag [integer!]][
	flag: 0
	imgui/init
	imgui/begin-frame
	imgui/set-mouse-state 0.0 0.0 no no
	imgui/set-key-state yes no no no
	imgui/begin "Window" 10.0 10.0 220.0 140.0
	imgui/button "Run" 80.0 24.0
	imgui/checkbox "Flag" :flag
	imgui/end
	imgui/end-frame

	imgui/begin-frame
	imgui/set-mouse-state 0.0 0.0 no no
	imgui/set-key-state yes no no no
	imgui/begin "Window" 10.0 10.0 220.0 140.0
	imgui/button "Run" 80.0 24.0
	imgui/checkbox "Flag" :flag
	imgui/end
	imgui/end-frame

	imgui/begin-frame
	imgui/set-mouse-state 0.0 0.0 no no
	imgui/set-key-state no yes no no
	imgui/begin "Window" 10.0 10.0 220.0 140.0
	imgui/button "Run" 80.0 24.0
	imgui/checkbox "Flag" :flag
	imgui/end
	imgui/end-frame
	flag
]

~~~start-file~~~ "imgui"

===start-group=== "widgets"

	--test-- "imgui-button-click"
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 40.0 48.0 yes yes
		imgui/begin "Window" 10.0 10.0 200.0 120.0
		clicked?: imgui/button "OK" 100.0 24.0
		imgui/end
		--assert clicked?

	--test-- "imgui-checkbox-toggle"
		flag: 0
		imgui/begin-frame
		imgui/set-mouse-state 40.0 48.0 yes yes
		imgui/begin "Window" 10.0 10.0 200.0 120.0
		changed?: imgui/checkbox "Flag" :flag
		imgui/end
		--assert changed?
		--assert flag = 1

	--test-- "imgui-slider-drag"
		value: 0.0
		imgui/begin-frame
		imgui/set-mouse-state 82.0 48.0 yes yes
		imgui/begin "Window" 10.0 10.0 220.0 120.0
		changed?: imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		--assert changed?
		--assert value > 0.45
		--assert value < 0.55

	--test-- "imgui-item-list"
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/text "Hello"
		imgui/button "Run" 80.0 24.0
		imgui/end
		label: imgui/item-label-at 2
		--assert (imgui/item-count?) = 2
		--assert (imgui/item-kind-at 1) = IMGUIT-Text
		--assert (imgui/item-kind-at 2) = IMGUIT-Button
		--assert label/1 = #"R"

	--test-- "imgui-draw-list"
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/text "Hello"
		imgui/button "Run" 80.0 24.0
		imgui/end
		draw-label: imgui/draw-label-at 4
		--assert (imgui/draw-count?) = 6
		--assert (imgui/draw-kind-at 1) = IMGUID-Rect
		--assert (imgui/draw-kind-at 3) = IMGUID-Text
		--assert (imgui/draw-kind-at 4) = IMGUID-Text
		--assert draw-label/1 = #"H"
		--assert (imgui/draw-color-at 5) = 301
		--assert (imgui/draw-color-at 6) = 203

	--test-- "imgui-slider-draw-fill"
		value: 0.0
		imgui/begin-frame
		imgui/set-mouse-state 82.0 48.0 yes yes
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		--assert (imgui/draw-count?) = 7
		--assert (imgui/draw-kind-at 5) = IMGUID-Rect
		--assert (imgui/draw-color-at 5) = 601
		--assert (imgui/draw-color-at 6) = 502
		--assert (imgui/draw-value-at 6) > 0.45
		--assert (imgui/draw-value-at 6) < 0.55

	--test-- "imgui-keyboard-focus-first"
		flag: 0
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/set-key-state yes no no no
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/button "Run" 80.0 24.0
		imgui/checkbox "Flag" :flag
		imgui/end
		imgui/end-frame
		--assert imgui/ctx/focused-item = 1

	--test-- "imgui-keyboard-focus-next"
		--assert keyboard-focus-step2 = 2

	--test-- "imgui-keyboard-activate-checkbox"
		--assert keyboard-activate-checkbox = 1

	--test-- "imgui-keyboard-slider-adjust"
		value: 0.5
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/set-key-state yes no no no
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		imgui/end-frame
		focused: imgui/ctx/focused-item
		--assert focused = 1

		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/set-key-state no no no yes
		imgui/begin "Window" 10.0 10.0 220.0 140.0
		imgui/slider-float "Value" :value 0.0 1.0 120.0
		imgui/end
		imgui/end-frame
		--assert value > 0.5

===end-group===

~~~end-file~~~
