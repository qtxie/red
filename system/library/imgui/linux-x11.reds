Red/System [
	Title:   "Red/System imgui X11 renderer"
	Author:  "OpenAI"
	File: 	 %linux-x11.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %pixel-renderer.reds

#switch OS [
	#default [#define IMGUI-X11-file "libX11.so.6"]
]

#define ExposureMask         32768
#define KeyPressMask         1
#define ButtonPressMask      4
#define ButtonReleaseMask    8
#define PointerMotionMask    64
#define StructureNotifyMask  131072

#define KeyPress-type        2
#define ButtonPress-type     4
#define ButtonRelease-type   5
#define MotionNotify-type    6
#define Expose-type          12
#define DestroyNotify-type   17

#define Button1Mask          256

#define XK-Left              65361
#define XK-Right             65363
#define XK-Escape            65307
#define ZPixmap              2

#define x-display!           [pointer! [integer!]]
#define x-gc!                [pointer! [integer!]]
#define x-visual!            [pointer! [integer!]]
#define x-image!             [pointer! [integer!]]

#import [
	IMGUI-X11-file cdecl [
		XOpenDisplay: "XOpenDisplay" [
			name    [c-string!]
			return: [x-display!]
		]
		XDefaultScreen: "XDefaultScreen" [
			display [x-display!]
			return:  [integer!]
		]
		XRootWindow: "XRootWindow" [
			display [x-display!]
			screen  [integer!]
			return:  [integer!]
		]
		XDefaultVisual: "XDefaultVisual" [
			display [x-display!]
			screen  [integer!]
			return: [x-visual!]
		]
		XDefaultDepth: "XDefaultDepth" [
			display [x-display!]
			screen  [integer!]
			return: [integer!]
		]
		XBlackPixel: "XBlackPixel" [
			display [x-display!]
			screen  [integer!]
			return:  [integer!]
		]
		XWhitePixel: "XWhitePixel" [
			display [x-display!]
			screen  [integer!]
			return:  [integer!]
		]
		XCreateSimpleWindow: "XCreateSimpleWindow" [
			display       [x-display!]
			parent        [integer!]
			x             [integer!]
			y             [integer!]
			width         [integer!]
			height        [integer!]
			border-width  [integer!]
			border        [integer!]
			background    [integer!]
			return:       [integer!]
		]
		XStoreName: "XStoreName" [
			display [x-display!]
			window  [integer!]
			name    [c-string!]
			return: [integer!]
		]
		XSelectInput: "XSelectInput" [
			display [x-display!]
			window  [integer!]
			mask    [integer!]
			return: [integer!]
		]
		XMapWindow: "XMapWindow" [
			display [x-display!]
			window  [integer!]
			return: [integer!]
		]
		XCreateGC: "XCreateGC" [
			display   [x-display!]
			drawable  [integer!]
			valuemask [integer!]
			values    [byte-ptr!]
			return:   [x-gc!]
		]
		XFreeGC: "XFreeGC" [
			display [x-display!]
			gc      [x-gc!]
			return: [integer!]
		]
		XSetForeground: "XSetForeground" [
			display [x-display!]
			gc      [x-gc!]
			color   [integer!]
			return: [integer!]
		]
		XSetBackground: "XSetBackground" [
			display [x-display!]
			gc      [x-gc!]
			color   [integer!]
			return: [integer!]
		]
		XClearWindow: "XClearWindow" [
			display [x-display!]
			window  [integer!]
			return: [integer!]
		]
		XFillRectangle: "XFillRectangle" [
			display [x-display!]
			drawable [integer!]
			gc      [x-gc!]
			x       [integer!]
			y       [integer!]
			width   [integer!]
			height  [integer!]
			return: [integer!]
		]
		XDrawRectangle: "XDrawRectangle" [
			display [x-display!]
			drawable [integer!]
			gc      [x-gc!]
			x       [integer!]
			y       [integer!]
			width   [integer!]
			height  [integer!]
			return: [integer!]
		]
		XDrawString: "XDrawString" [
			display [x-display!]
			drawable [integer!]
			gc      [x-gc!]
			x       [integer!]
			y       [integer!]
			string  [c-string!]
			length  [integer!]
			return: [integer!]
		]
		XDrawLine: "XDrawLine" [
			display [x-display!]
			drawable [integer!]
			gc      [x-gc!]
			x1      [integer!]
			y1      [integer!]
			x2      [integer!]
			y2      [integer!]
			return: [integer!]
		]
		XPending: "XPending" [
			display [x-display!]
			return: [integer!]
		]
		XQueryPointer: "XQueryPointer" [
			display     [x-display!]
			window      [integer!]
			root-return [int-ptr!]
			child-return [int-ptr!]
			root-x      [int-ptr!]
			root-y      [int-ptr!]
			win-x       [int-ptr!]
			win-y       [int-ptr!]
			mask-return [int-ptr!]
			return:     [integer!]
		]
		XNextEvent: "XNextEvent" [
			display [x-display!]
			event   [byte-ptr!]
			return: [integer!]
		]
		XLookupString: "XLookupString" [
			event-buffer [byte-ptr!]
			buffer       [byte-ptr!]
			bytes        [integer!]
			keysym       [int-ptr!]
			status       [byte-ptr!]
			return:      [integer!]
		]
		XCreateImage: "XCreateImage" [
			display        [x-display!]
			visual         [x-visual!]
			depth          [integer!]
			format         [integer!]
			offset         [integer!]
			data           [byte-ptr!]
			width          [integer!]
			height         [integer!]
			bitmap-pad     [integer!]
			bytes-per-line [integer!]
			return:        [x-image!]
		]
		XPutImage: "XPutImage" [
			display    [x-display!]
			drawable   [integer!]
			gc         [x-gc!]
			image      [x-image!]
			src-x      [integer!]
			src-y      [integer!]
			dest-x     [integer!]
			dest-y     [integer!]
			width      [integer!]
			height     [integer!]
			return:    [integer!]
		]
		XFlush: "XFlush" [
			display [x-display!]
			return: [integer!]
		]
		XDestroyWindow: "XDestroyWindow" [
			display [x-display!]
			window  [integer!]
			return: [integer!]
		]
		XCloseDisplay: "XCloseDisplay" [
			display [x-display!]
			return: [integer!]
		]
	]
]

imgui-x11: context [
	display: as x-display! 0
	screen: 0
	window: 0
	gc: as x-gc! 0
	visual: as x-visual! 0
	depth: 0
	black: 0
	white: 0
	frame-width: 0
	frame-height: 0
	event-buf: as byte-ptr! 0
	key-buf: as byte-ptr! 0
	ximage: as x-image! 0
	mouse-x: 0
	mouse-y: 0
	mouse-down?: no

	render-draw-list: does [
		imgui-pixel-renderer/render-draw-list frame-width frame-height
		XPutImage display window gc ximage 0 0 0 0 frame-width frame-height
		XFlush display
	]

	query-pointer: func [
		return: [logic!]
		/local
			root-ret [integer!]
			child-ret [integer!]
			root-x [integer!]
			root-y [integer!]
			win-x [integer!]
			win-y [integer!]
			mask-ret [integer!]
			ok [integer!]
	][
		root-ret: 0
		child-ret: 0
		root-x: 0
		root-y: 0
		win-x: 0
		win-y: 0
		mask-ret: 0
		ok: XQueryPointer
			display
			window
			:root-ret
			:child-ret
			:root-x
			:root-y
			:win-x
			:win-y
			:mask-ret
		if zero? ok [return no]

		mouse-x: win-x
		mouse-y: win-y
		mouse-down?: mask-ret and Button1Mask <> 0
		yes
	]

	run: func [
		title [c-string!]
		width [integer!]
		height [integer!]
		return: [logic!]
		/local
			mask [integer!]
			root [integer!]
			type-ptr [int-ptr!]
			running? [logic!]
			evtype [integer!]
	][
		display: XOpenDisplay null
		if null? display [return no]

		screen: XDefaultScreen display
		root: XRootWindow display screen
		black: XBlackPixel display screen
		white: XWhitePixel display screen

		window: XCreateSimpleWindow display root 40 40 width height 1 black white
		if zero? window [
			XCloseDisplay display
			return no
		]

		XStoreName display window title
		mask: ExposureMask or KeyPressMask or ButtonPressMask or StructureNotifyMask
		XSelectInput display window mask
		gc: XCreateGC display window 0 null
		XSetBackground display gc white
		XSetForeground display gc black
		XMapWindow display window

		if null? event-buf [event-buf: allocate 256]
		type-ptr: as int-ptr! event-buf
		running?: yes

		while [running?][
			XNextEvent display event-buf
			evtype: type-ptr/value
			case [
				evtype = Expose-type [
					render-draw-list
				]
				evtype = KeyPress-type [
					running?: no
				]
				evtype = ButtonPress-type [
					running?: no
				]
				evtype = DestroyNotify-type [
					running?: no
				]
				true [0]
			]
		]

		XFreeGC display gc
		XDestroyWindow display window
		XCloseDisplay display
		yes
	]

	open-window: func [
		title  [c-string!]
		width  [integer!]
		height [integer!]
		return: [logic!]
		/local
			mask [integer!]
			root [integer!]
	][
		display: XOpenDisplay null
		if null? display [return no]

		screen: XDefaultScreen display
		visual: XDefaultVisual display screen
		depth: XDefaultDepth display screen
		root: XRootWindow display screen
		black: XBlackPixel display screen
		white: XWhitePixel display screen
		frame-width: width
		frame-height: height

		window: XCreateSimpleWindow display root 40 40 width height 1 black white
		if zero? window [
			XCloseDisplay display
			return no
		]

		XStoreName display window title
		mask: ExposureMask or KeyPressMask or ButtonPressMask or ButtonReleaseMask or PointerMotionMask or StructureNotifyMask
		XSelectInput display window mask
		gc: XCreateGC display window 0 null
		XSetBackground display gc white
		XSetForeground display gc black
		XMapWindow display window

		if null? event-buf [event-buf: allocate 256]
		imgui-pixel-renderer/clear width height
		ximage: XCreateImage display visual depth ZPixmap 0 imgui-pixel-renderer/pixels width height 32 0
		if null? ximage [
			XFreeGC display gc
			XDestroyWindow display window
			XCloseDisplay display
			return no
		]
		mouse-x: 0
		mouse-y: 0
		mouse-down?: no
		yes
	]

	wait-event: func [
		return: [integer!]
		/local type-ptr [int-ptr!]
	][
		type-ptr: as int-ptr! event-buf
		XNextEvent display event-buf
		type-ptr/value
	]

	sync-imgui-mouse: func [
		pressed? [logic!]
	][
		query-pointer
		imgui/set-mouse-state as float! mouse-x as float! mouse-y mouse-down? pressed?
	]

	handle-keypress: func [
		return: [logic!]
		/local
			keysym [integer!]
			n [integer!]
			ch [byte!]
			close? [logic!]
			tab? [logic!]
			activate? [logic!]
			left? [logic!]
			right? [logic!]
	][
		if null? key-buf [key-buf: allocate 8]
		keysym: 0
		n: XLookupString event-buf key-buf 7 :keysym null
		ch: either n > 0 [key-buf/1][null-byte]
		close?: any [keysym = XK-Escape ch = as byte! 27]
		tab?: ch = as byte! 9
		activate?: any [ch = as byte! 13 ch = as byte! 32]
		left?: keysym = XK-Left
		right?: keysym = XK-Right
		imgui/set-key-state tab? activate? left? right?
		close?
	]

	close-window: does [
		XFreeGC display gc
		XDestroyWindow display window
		XCloseDisplay display
	]
]
