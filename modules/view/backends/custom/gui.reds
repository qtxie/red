Red/System [
	Title:	"GOB! based GUI backend"
	Author: "Xie Qingtian"
	File: 	%gui.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %definitions.reds
#include %utils.reds
#include %matrix2d.reds

#switch OS [
	Windows  [#include %host-win/host.reds]
	macOS    [#include %host-mac/host.reds]
	#default [#include %host-linux/host.reds]		;-- Linux
]

#include %events.reds
#include %widgets.reds
#include %ui-manager.reds

IF_GOB_FACE([

get-face-values: func [
	g		 [gob!]
	return:  [red-value!]
	/local
		ctx	 [red-context!]
		node [node!]
		s	 [series!]
][
	node: g/obj-ctx
	ctx: TO_CTX(node)
	s: as series! ctx/values/value
	s/offset
]

])

on-gc-mark: does [
	collector/keep flags-blk/node
	ui-manager/on-gc-mark
]

init: func [
	/local
		ver   [red-tuple!]
		int   [red-integer!]
][
	ui-manager/init
	host/init
	animation/init
	collector/register as int-ptr! :on-gc-mark
]

cleanup: does [
	host/cleanup
]

get-screen-size: func [
	id		[integer!]
	return: [red-pair!]
][
	host/get-screen-size id
]

get-text-size: func [
	face 	[red-object!]
	text	[red-string!]
	hFont	[handle!]
	p		[red-pair!]
	return: [red-pair!]
][
	pair/push 80 20
]

get-flags: func [
	field	[red-block!]
	return: [integer!]									;-- return a bit-array of all flags
	/local
		word  [red-word!]
		len	  [integer!]
		sym	  [integer!]
		flags [integer!]
][
	switch TYPE_OF(field) [
		TYPE_BLOCK [
			word: as red-word! block/rs-head field
			len: block/rs-length? field
			if zero? len [return 0]
		]
		TYPE_WORD [
			word: as red-word! field
			len: 1
		]
		default [return 0]
	]
	flags: 0
	
	loop len [
		sym: symbol/resolve word/symbol
		case [
			sym = all-over	 [flags: flags or FACET_FLAGS_ALL_OVER]
			sym = resize	 [flags: flags or FACET_FLAGS_RESIZE]
			sym = no-title	 [flags: flags or FACET_FLAGS_NO_TITLE]
			sym = no-border  [flags: flags or FACET_FLAGS_NO_BORDER]
			sym = no-min	 [flags: flags or FACET_FLAGS_NO_MIN]
			sym = no-max	 [flags: flags or FACET_FLAGS_NO_MAX]
			sym = no-buttons [flags: flags or FACET_FLAGS_NO_BTNS]
			sym = modal		 [flags: flags or FACET_FLAGS_MODAL]
			sym = popup		 [flags: flags or FACET_FLAGS_POPUP]
			sym = scrollable [flags: flags or FACET_FLAGS_SCROLLABLE]
			sym = password	 [flags: flags or FACET_FLAGS_PASSWORD]
			true			 [fire [TO_ERROR(script invalid-arg) word]]
		]
		word: word + 1
	]
	flags
]

face-handle?: func [
	face	[red-object!]
	return: [handle!]							;-- returns NULL if no handle
][
	null
]

make-font: func [
	face	[red-object!]
	font	[red-object!]
	return: [handle!]
	/local
		blk	[red-block!]
][
	blk: as red-block! (object/get-values font) + FONT_OBJ_PARENT
	if face <> null [
		if TYPE_OF(blk) <> TYPE_BLOCK [blk: block/make-at blk 4]
		block/rs-append blk as red-value! face
	]
	OS-make-font font
]

update-para: func [
	para	[red-object!]
	flags	[integer!]
][

]

update-font: func [
	font [red-object!]
	flag [integer!]
][
	switch flag [
		FONT_OBJ_NAME
		FONT_OBJ_SIZE
		FONT_OBJ_STYLE
		FONT_OBJ_ANGLE
		FONT_OBJ_ANTI-ALIAS? [
			free-font font
			make-font null font
		]
		default [0]
	]
]

OS-request-file: func [
	title	[red-string!]
	name	[red-file!]
	filter	[red-block!]
	save?	[logic!]
	multi?	[logic!]
	return: [red-value!]
][
	as red-value! none-value
]

OS-request-dir: func [
	title	[red-string!]
	dir		[red-file!]
	filter	[red-block!]
	keep?	[logic!]
	multi?	[logic!]
	return: [red-value!]
][
	as red-value! none-value
]

update-scroller: func [
	scroller [red-object!]
	flags [integer!]
][

]

OS-redraw: func [hWnd [integer!]][]

OS-refresh-window: func [hWnd [integer!] /local g [gob!]][
	g: as gob! hWnd
	if GOB_TYPE(g) = GOB_WINDOW [ui-manager/draw-windows]
]

OS-show-window: func [
	hWnd	[integer!]
	/local
		g	[gob!]
		wm	[wm!]
][
	g: as gob! hWnd
	wm: as wm! g/data
	ui-manager/active-win: wm
	host/show-window wm/hWnd
]

OS-make-view: func [
	face	[red-object!]
	parent	[integer!]
	return: [integer!]
	/local
		g		[red-gob!]
		gob		[gob!]
		values	[red-value!]
		type	[red-word!]
		str		[red-string!]
		tail	[red-string!]
		offset	[red-pair!]
		size	[red-pair!]
		data	[red-block!]
		int		[red-integer!]
		img		[red-image!]
		menu	[red-block!]
		show?	[red-logic!]
		open?	[red-logic!]
		rate	[red-value!]
		saved	[red-value!]
		font	[red-object!]
		flags	[integer!]
		bits	[integer!]
		sym		[integer!]
		id		[integer!]
		class	[c-string!]
		caption [integer!]
		len		[integer!]
		obj		[integer!]
		hWnd	[integer!]
		flt		[float!]
][
	stack/mark-native words/_body

	values: object/get-values face

	type:	  as red-word!		values + FACE_OBJ_TYPE
	str:	  as red-string!	values + FACE_OBJ_TEXT
	offset:   as red-pair!		values + FACE_OBJ_OFFSET
	size:	  as red-pair!		values + FACE_OBJ_SIZE
	show?:	  as red-logic!		values + FACE_OBJ_VISIBLE?
	open?:	  as red-logic!		values + FACE_OBJ_ENABLED?
	data:	  as red-block!		values + FACE_OBJ_DATA
	img:	  as red-image!		values + FACE_OBJ_IMAGE
	menu:	  as red-block!		values + FACE_OBJ_MENU
	font:	  as red-object!	values + FACE_OBJ_FONT
	rate:						values + FACE_OBJ_RATE
	g:		  as red-gob!		values + FACE_OBJ_GOB

	bits: 	  get-flags as red-block! values + FACE_OBJ_FLAGS
	sym: 	  symbol/resolve type/symbol

	stack/unwind

	gob: as gob! g/value
	copy-cell as cell! face as cell! :gob/face
	gob/parent: as gob! parent
	if sym = window [host/make-window gob as gob! parent]
	as-integer gob
]

unlink-sub-obj: func [
	face  [red-object!]
	obj   [red-object!]
	field [integer!]
][
]

OS-update-view: func [
	face [red-object!]
][										;-- reset flags
]

OS-destroy-view: func [
	face   [red-object!]
	empty? [logic!]
][
	;free-faces face
]

OS-update-facet: func [
	face   [red-object!]
	facet  [red-word!]
	value  [red-value!]
	action [red-word!]
	new	   [red-value!]
	index  [integer!]
	part   [integer!]
][

]

OS-to-image: func [
	face	[red-object!]
	return: [red-image!]
][
	null
]

OS-do-draw: func [
	img		[red-image!]
	cmds	[red-block!]
][
	do-draw null img cmds no no no no
]

OS-draw-face: func [
	ctx		[draw-ctx!]
	cmds	[red-block!]
][
	if TYPE_OF(cmds) = TYPE_BLOCK [
		catch RED_THROWN_ERROR [parse-draw ctx cmds yes]
	]
	if system/thrown = RED_THROWN_ERROR [system/thrown: 0]
]