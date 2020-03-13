Red/System [
	Title:	"Windows platform GUI imports"
	Author: "Nenad Rakocevic"
	File: 	%win32.red
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#switch OS [
	Windows  [#include %host-win/definitions.reds]
	macOS    [#include %host-mac/definitions.reds]
	#default [#include %host-linux/definitions.reds]		;-- Linux
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
	WIN_RENDER_ALL:		0100h
]

wm!: alias struct! [
	flags		[integer!]
	hwnd		[handle!]
	gob			[gob!]			;-- root gob
	render		[renderer!]
	focused		[gob!]			;-- focused gob in the window
	update-list	[node!]
]
