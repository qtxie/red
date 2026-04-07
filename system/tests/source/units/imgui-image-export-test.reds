Red/System [
	Title:   "Red/System imgui image export tests"
	Author:  "OpenAI"
	File: 	 %imgui-image-export-test.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %../../../../quick-test/quick-test.reds
#include %../../../library/imgui/image-export.reds

#import [
	IMGUI-LIBC-file cdecl [
		imgui-test-fopen: "fopen" [
			filename [c-string!]
			mode     [c-string!]
			return:  [byte-ptr!]
		]
		imgui-test-fread: "fread" [
			ptr      [byte-ptr!]
			size     [integer!]
			count    [integer!]
			stream   [byte-ptr!]
			return:  [integer!]
		]
		imgui-test-fclose: "fclose" [
			stream   [byte-ptr!]
			return:  [integer!]
		]
	]
]

~~~start-file~~~ "imgui-image-export"

===start-group=== "ppm"

	--test-- "save-ppm"
		out: "imgui-test.ppm"
		header: as byte-ptr! allocate 32
		imgui/init
		imgui/begin-frame
		imgui/set-mouse-state 0.0 0.0 no no
		imgui/begin "Window" 8.0 8.0 120.0 80.0
		imgui/button "Run" 80.0 24.0
		imgui/end
		imgui-pixel-renderer/render-draw-list 64 48
		--assert imgui-image-export/save-ppm out
		fd: imgui-test-fopen out "rb"
		--assert not null? fd
		imgui-test-fread header 1 15 fd
		imgui-test-fclose fd
		--assert header/1 = #"P"
		--assert header/2 = #"6"
		--assert header/3 = #"^/"

===end-group===

~~~end-file~~~
