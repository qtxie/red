Red/System [
	Title:	"Windows Image widget"
	Author: "Xie Qingtian"
	File: 	%image.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015 Nenad Rakocevic. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

ImageWndProc: func [
	hWnd	[handle!]
	msg		[integer!]
	wParam	[integer!]
	lParam	[integer!]
	return: [integer!]
][
	switch msg [
		WM_ERASEBKGND [return 1]
		WM_PAINT [
			bitblt-memory-dc hWnd yes
			return 0
		]
		default [0]
	]
	DefWindowProc hWnd msg wParam lParam
]

make-image-dc: func [
	hWnd		[handle!]
	img			[red-image!]
	return:		[integer!]
	/local
		graphic [integer!]
		rect	[RECT_STRUCT]
		width	[integer!]
		height	[integer!]
		hDC		[handle!]
		hBitmap [handle!]
		hBackDC [handle!]
][
	graphic: 0
	rect: declare RECT_STRUCT

	GetClientRect hWnd rect
	width: rect/right - rect/left
	height: rect/bottom - rect/top

	hDC: GetDC hWnd
	hBackDC: CreateCompatibleDC hDC
	hBitmap: CreateCompatibleBitmap hDC width height
	ReleaseDC hWnd hDC
	SelectObject hBackDC hBitmap
	GdipCreateFromHDC hBackDC :graphic
	GdipDrawImageRectI graphic as-integer img/node 0 0 width height

	as-integer hBackDC
]

draw-vbase: func [
	dc			[handle!]
	pane		[red-block!]
	return:		[handle!]
	/local
		graphic [integer!]
		s		[series!]
		face	[red-object!]
		values	[red-value!]
		type	[red-word!]
		offset	  [red-pair!]
		size	  [red-pair!]
		data	  [red-block!]
		int		  [red-integer!]
		img		  [red-image!]
		menu	  [red-block!]
		show?	  [red-logic!]
		open?	  [red-logic!]
		selected  [red-integer!]
		str		  [red-string!]
		para	  [red-object!]
		end		[red-object!]
][
	probe "jkjlkjlljk"
	graphic: 0
	s: GET_BUFFER(pane)
	face: as red-object! s/offset + pane/head
	end: as red-object! s/tail

	GdipCreateFromHDC dc :graphic

	while [face < end][
		if TYPE_OF(face) <> TYPE_OBJECT [print "error............." break]
		values: object/get-values face

		type:	  as red-word!		values + FACE_OBJ_TYPE
		str:	  as red-string!	values + FACE_OBJ_TEXT
		offset:   as red-pair!		values + FACE_OBJ_OFFSET
		size:	  as red-pair!		values + FACE_OBJ_SIZE
		show?:	  as red-logic!		values + FACE_OBJ_VISIBLE?
		open?:	  as red-logic!		values + FACE_OBJ_ENABLE?
		data:	  as red-block!		values + FACE_OBJ_DATA
		img:	  as red-image!		values + FACE_OBJ_IMAGE
		menu:	  as red-block!		values + FACE_OBJ_MENU
		selected: as red-integer!	values + FACE_OBJ_SELECTED
		para:	  as red-object!	values + FACE_OBJ_PARA

		sym: symbol/resolve type/symbol
		if sym = vbase [
			GdipDrawImageRectI graphic as-integer img/node offset/x offset/y size/x size/y
		]
		face: face + 1
	]

	dc
]

init-image: func [
	hWnd	[handle!]
	data	[red-block!]
	img		[red-image!]
	/local
		str  [red-string!]
		tail [red-string!]
][
	if any [
		TYPE_OF(data) = TYPE_BLOCK
		TYPE_OF(data) = TYPE_HASH
		TYPE_OF(data) = TYPE_MAP
	][
		str:  as red-string! block/rs-head data
		tail: as red-string! block/rs-tail data
		while [str < tail][
			switch TYPE_OF(str) [
				TYPE_URL   [
					copy-cell
						as cell! image/load-binary as red-binary!
							simple-io/request-http HTTP_GET as red-url! str null null yes no no
						as cell! img
				]
				TYPE_FILE  [image/make-at as red-value! img str]
				TYPE_IMAGE [copy-cell as cell! str as cell! img]
				default [0]
			]
			str: str + 1
		]
	]
	SetWindowLong hWnd wc-offset - 4 make-image-dc hWnd img
]