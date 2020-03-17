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

face-handle?: func [
	face	[red-object!]
	return: [handle!]							;-- returns NULL if no handle
][
	null
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
][
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
][
	g: as red-gob! face
	as-integer host/make-window as gob! g/value as handle! parent
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