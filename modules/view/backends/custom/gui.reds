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

#switch OS [
	Windows  [#include %windows/definitions.reds]
	macOS    [#include %macOS/definitions.reds]
	#default [#include %Linux/definitions.reds]		;-- Linux
]

#enum window-flags! [
	;-- show flags
	WIN_FLAG_SHOW:		0
	WIN_FLAG_HIDE:		1
	WIN_FLAG_MIN:		2
	WIN_FLAG_INVISIBLE: 3		;-- HIDE or MIN
	WIN_FLAG_MAX:		4
	WIN_FLAG_INACTIVE:	8
	;-- window type
	WIN_TYPE_POPUP:		10h
	WIN_TYPE_FRAMELESS:	20h
	WIN_TYPE_TOOL:		40h
	WIN_TYPE_TASKBAR:	80h
	;-- render flags
	WIN_RENDER_FULL:	0100h
]

wm!: alias struct! [
	flags		[integer!]
	hwnd		[handle!]
	gob			[gob!]			;-- root gob
	render		[render-target!]
	focused		[gob!]			;-- focused gob in the window
	update-list	[node!]
]

#switch OS [
	Windows  [#include %windows/host.reds]
	macOS    [#include %macOS/host.reds]
	#default [#include %Linux/host.reds]		;-- Linux
]

#include %ui-manager.reds
#include %text-box.reds
#include %draw.reds
#include %events.reds
#include %widgets.reds

get-face-obj: func [
	hWnd	[handle!]
	return: [red-object!]
	/local
		face [red-object!]
][
	;face: declare red-object!
	;face/header: GetWindowLong hWnd wc-offset
	;face/ctx:	 as node! GetWindowLong hWnd wc-offset + 4
	;face/class:  GetWindowLong hWnd wc-offset + 8
	;face/on-set: as node! GetWindowLong hWnd wc-offset + 12
	;face
	null
]

get-face-values: func [
	hWnd	[handle!]
	return: [red-value!]
	/local
		ctx	 [red-context!]
		node [node!]
		s	 [series!]
][
	;node: as node! GetWindowLong hWnd wc-offset + 4
	;ctx: TO_CTX(node)
	;s: as series! ctx/values/value
	;s/offset
	null
]

get-node-facet: func [
	node	[node!]
	facet	[integer!]
	return: [red-value!]
	/local
		ctx	 [red-context!]
		s	 [series!]
][
	ctx: TO_CTX(node)
	s: as series! ctx/values/value
	s/offset + facet
]

face-handle?: func [
	face	[red-object!]
	return: [handle!]									;-- returns NULL if no handle
	/local
		state  [red-block!]
		handle [red-handle!]
][
	state: as red-block! get-node-facet face/ctx FACE_OBJ_STATE
	if TYPE_OF(state) = TYPE_BLOCK [
		handle: as red-handle! block/rs-head state
		if TYPE_OF(handle) = TYPE_HANDLE [return as handle! handle/value]
	]
	null
]

get-face-handle: func [
	face	[red-object!]
	return: [handle!]
	/local
		state  [red-block!]
		handle [red-handle!]
][
	state: as red-block! get-node-facet face/ctx FACE_OBJ_STATE
	assert TYPE_OF(state) = TYPE_BLOCK
	handle: as red-handle! block/rs-head state
	assert TYPE_OF(handle) = TYPE_HANDLE
	as handle! handle/value
]

free-faces: func [
	face	[red-object!]
	/local
		values	[red-value!]
		type	[red-word!]
		obj		[red-object!]
		tail	[red-object!]
		pane	[red-block!]
		state	[red-value!]
		rate	[red-value!]
		sym		[integer!]
		dc		[integer!]
		flags	[integer!]
		handle	[handle!]
][
	;handle: face-handle? face
	;if null? handle [exit]

	values: object/get-values face
	;type: as red-word! values + FACE_OBJ_TYPE
	;sym: symbol/resolve type/symbol

	;obj: as red-object! values + FACE_OBJ_FONT
	;if TYPE_OF(obj) = TYPE_OBJECT [unlink-sub-obj face obj FONT_OBJ_PARENT]
	
	;obj: as red-object! values + FACE_OBJ_PARA
	;if TYPE_OF(obj) = TYPE_OBJECT [unlink-sub-obj face obj PARA_OBJ_PARENT]

	state: values + FACE_OBJ_STATE
	state/header: TYPE_NONE
]

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
	collector/register as int-ptr! :on-gc-mark
]

cleanup: does [
	host/cleanup
]

get-screen-size: func [
	id		[integer!]
	return: [red-pair!]
][
	pair/push 2000 1000
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


make-font: func [
	face [red-object!]
	font [red-object!]
	return: [handle!]
][
	as handle! 0
]

get-font-handle: func [
	font	[red-object!]
	idx		[integer!]							;-- 0-based index
	return: [handle!]
	/local
		state  [red-block!]
		handle [red-handle!]
][
	state: as red-block! (object/get-values font) + FONT_OBJ_STATE
	if TYPE_OF(state) = TYPE_BLOCK [
		handle: (as red-handle! block/rs-head state) + idx
		if TYPE_OF(handle) = TYPE_HANDLE [
			return as handle! handle/value
		]
	]
	null
]

update-para: func [
	para	[red-object!]
	flags	[integer!]
][

]

update-font: func [
	font	[red-object!]
	flags	[integer!]
][

]

OS-request-font: func [
	font	 [red-object!]
	selected [red-object!]
	mono?	 [logic!]
][

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

OS-refresh-window: func [hWnd [integer!]][]

OS-show-window: func [
	hWnd [integer!]
][
	host/show-window as handle! hWnd
]

OS-make-view: func [
	face	[red-object!]
	parent	[integer!]
	return: [integer!]
	/local
		g	[red-gob!]
		h	[handle!]
][
	g: as red-gob! face
	h: host/make-window as gob! g/value as handle! parent
	g/host: h
	as-integer h
]

unlink-sub-obj: func [
	face  [red-object!]
	obj   [red-object!]
	field [integer!]
	/local
		values [red-value!]
		parent [red-block!]
		res	   [red-value!]
][
	values: object/get-values obj
	parent: as red-block! values + field
]

OS-update-view: func [
	face [red-object!]
	/local
		ctx		[red-context!]
		state	[red-block!]
		int		[red-integer!]
		s		[series!]
][
	ctx: GET_CTX(face)
	s: as series! ctx/values/value
	state: as red-block! s/offset + FACE_OBJ_STATE
	s: GET_BUFFER(state)
	int: as red-integer! s/offset
	int: int + 1
	int/value: 0										;-- reset flags
]

OS-destroy-view: func [
	face   [red-object!]
	empty? [logic!]
][
	free-faces face
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