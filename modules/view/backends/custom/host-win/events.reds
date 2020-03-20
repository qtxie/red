Red/System [
	Title:	"Windows events handling"
	Author: "Xie Qingtian"
	File: 	%events.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

special-key: 	-1										;-- <> -1 if a non-displayable key is pressed
key-flags:		 0										;-- last key-flags, needed in mouseleave event
hover-win:		as handle! 0
mouse-x:		as float32! 0
mouse-y:		as float32! 0
mouse-flags:	0

decode-down-flags: func [
	wParam  [integer!]
	return: [integer!]
	/local
		flags [integer!]
][
	flags: 0
	if wParam and 0001h <> 0 [flags: flags or EVT_FLAG_DOWN]
	if wParam and 0002h <> 0 [flags: flags or EVT_FLAG_ALT_DOWN]
	if wParam and 0004h <> 0 [flags: flags or EVT_FLAG_SHIFT_DOWN]
	if wParam and 0008h <> 0 [flags: flags or EVT_FLAG_CTRL_DOWN]
	if wParam and 0010h <> 0 [flags: flags or EVT_FLAG_MID_DOWN]
	if wParam and 0020h <> 0 [flags: flags or EVT_FLAG_AUX_DOWN]
	if wParam and 0040h <> 0 [flags: flags or EVT_FLAG_AUX_DOWN]	;-- needs an AUX2 flag
	flags
]

RedWndProc: func [
	[stdcall]
	hWnd		[handle!]
	msg			[integer!]
	wParam		[integer!]
	lParam		[integer!]
	return:		[integer!]
	/local
		cs		[tagCREATESTRUCT]
		rc		[RECT_STRUCT]
		obj		[gob!]
		child	[gob!]
		x		[integer!]
		y		[integer!]
		wm		[wm!]
		flags	[integer!]
		track	[tagTRACKMOUSEEVENT value]
][
	wm: as wm! GetWindowLongPtr hWnd GWLP_USERDATA

	switch msg [
		WM_CREATE [
			cs: as tagCREATESTRUCT lParam
			obj: as gob! cs/lpCreateParams
			obj/flags: obj/flags and FFFFFF00h or GOB_WINDOW or GOB_FLAG_HOSTED
			wm: ui-manager/add-window hWnd obj create-render-target hWnd
			obj/extra: as int-ptr! wm
			SetWindowLongPtr hWnd GWLP_USERDATA as int-ptr! wm
			return 0	;-- continue to create the window
		]
		WM_MOUSEMOVE [
			x: WIN32_LOWORD(lParam)
			y: WIN32_HIWORD(lParam)
			if hover-win <> hWnd [
				track/cbSize: size? tagTRACKMOUSEEVENT
				track/dwFlags: 2					;-- TME_LEAVE
				track/hwndTrack: hWnd
				TrackMouseEvent :track
				hover-win: hWnd
			]
			mouse-flags: decode-down-flags wParam
			mouse-x: pixel-to-logical x
			mouse-y: pixel-to-logical y
			do-mouse-move EVT_OVER wm/gob mouse-x mouse-y mouse-flags
			return 0
		]
		WM_MOUSELEAVE [
			send-mouse-event EVT_OVER wm/gob mouse-x mouse-y mouse-flags or EVT_FLAG_AWAY
			if hover-win = hWnd [
				hover-win: null
				ui-manager/hover-gob: null
			]
			return 0
		]
		WM_LBUTTONDOWN
		WM_LBUTTONUP
		WM_RBUTTONDOWN
		WM_RBUTTONUP
		WM_MBUTTONDOWN
		WM_MBUTTONUP	[do-mouse-press msg - 0200h wm/gob mouse-x mouse-y mouse-flags]
		WM_MOVING [0]
		WM_KEYDOWN [0]
		WM_SYSKEYDOWN [0]
		WM_SYSCHAR [0]
		WM_CHAR [0]
		WM_UNICHAR [0]
		WM_SETFOCUS [return 0]
		WM_KILLFOCUS [0]
		WM_SIZE [0]
		WM_GETMINMAXINFO [0]	;-- for maximization and minimization
		WM_NCACTIVATE [0]
		WM_MOUSEACTIVATE [0]
		WM_SETCURSOR [0]
		WM_GETOBJECT [0]		;-- for accessibility support
		WM_CLOSE [0]
		WM_DESTROY [
			ui-manager/remove-window wm
			PostQuitMessage 0
			return 0
		]
		WM_DPICHANGED [
			dpi-x: as float32! WIN32_LOWORD(wParam)			;-- new DPI X
			dpi-y: as float32! WIN32_HIWORD(wParam)			;-- new DPI Y
			dpi-value: dpi-y
			rc: as RECT_STRUCT lParam
			SetWindowPos 
				hWnd
				as handle! 0
				rc/left rc/top
				rc/right - rc/left rc/bottom - rc/top
				SWP_NOZORDER or SWP_NOACTIVATE
			;d2d-release-target target
			return 0
		]
		WM_PAINT [
			ValidateRect hWnd null
		]
		WM_ERASEBKGND [
			return 1
		]
		default [0]
	]
	DefWindowProc hWnd msg wParam lParam
]