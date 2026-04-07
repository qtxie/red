Red/System [
	Title:   "Red/System imgui pixel image export"
	Author:  "OpenAI"
	File: 	 %image-export.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %pixel-renderer.reds

#switch OS [
	Windows [#define IMGUI-LIBC-file "msvcrt.dll"]
	macOS   [#define IMGUI-LIBC-file "libc.dylib"]
	#default [#define IMGUI-LIBC-file "libc.so.6"]
]

#import [
	IMGUI-LIBC-file cdecl [
		imgui-fopen: "fopen" [
			filename [c-string!]
			mode     [c-string!]
			return:  [byte-ptr!]
		]
		imgui-fwrite: "fwrite" [
			ptr      [byte-ptr!]
			size     [integer!]
			count    [integer!]
			stream   [byte-ptr!]
			return:  [integer!]
		]
		imgui-fclose: "fclose" [
			stream   [byte-ptr!]
			return:  [integer!]
		]
		imgui-sprintf: "sprintf" [[variadic] return: [integer!]]
	]
]

imgui-image-export: context [
	header-buffer: as byte-ptr! 0

	ensure-header-buffer: does [
		if null? header-buffer [
			header-buffer: allocate 128
		]
	]

	save-ppm: func [
		path    [c-string!]
		return: [logic!]
		/local
			fd           [byte-ptr!]
			header-size  [integer!]
			body-size    [integer!]
			wrote        [integer!]
			src          [byte-ptr!]
			dst          [byte-ptr!]
			i            [integer!]
			pack         [byte-ptr!]
	][
		ensure-header-buffer
		fd: imgui-fopen path "wb"
		if null? fd [return no]

		header-size: imgui-sprintf [
			header-buffer
			"P6^/%i %i^/255^/"
			imgui-pixel-renderer/width
			imgui-pixel-renderer/height
		]

		wrote: imgui-fwrite header-buffer 1 header-size fd
		if wrote <> header-size [
			imgui-fclose fd
			return no
		]

		body-size: imgui-pixel-renderer/width * imgui-pixel-renderer/height
		pack: allocate body-size * 3
		src: imgui-pixel-renderer/pixels
		dst: pack
		i: 0
		while [i < body-size][
			dst/1: src/3
			dst/2: src/2
			dst/3: src/1
			src: src + 4
			dst: dst + 3
			i: i + 1
		]
		wrote: imgui-fwrite pack 1 (body-size * 3) fd
		imgui-fclose fd
		wrote = (body-size * 3)
	]
]
