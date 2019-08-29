Red/System [
	Title:	"Host environment"
	Author: "Xie Qingtian"
	File: 	%host.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %definitions.reds
#include %utils.reds

host: context [
	win8+?:			no
	win10?:			no

	exit-loop:		0
	process-id:		0
	border-width:	0
	hScreen:		as handle! 0
	hInstance:		as handle! 0
	default-font:	as handle! 0
	version-info: 	declare OSVERSIONINFO
	win-state:		0
	hIMCtx:			as handle! 0
	ime-open?:		no
	;ime-font:		as tagLOGFONT allocate 92

	dpi-factor:		100
	dpi-x:			as float32! 0.0
	dpi-y:			as float32! 0.0
	screen-size-x:	0
	screen-size-y:	0
	default-font-name: as c-string! 0

	rc-cache:		declare RECT_STRUCT
	;kb-state: 		allocate 256							;-- holds keyboard state for keys conversion

	#include %direct2d.reds

	get-para-flags: func [
		type	[integer!]
		para	[red-object!]
		return: [integer!]
	][
		0
	]

	dpi-scale: func [
		num		[integer!]
		return: [integer!]
	][
		num * dpi-factor / 100
	]

	dpi-unscale: func [
		num		[integer!]
		return: [integer!]
	][
		num * 100 / dpi-factor
	]

	set-defaults: func [
		/local
			hTheme	[handle!]
			font	[tagLOGFONT]
			ft		[tagLOGFONT value]
			name	[c-string!]
			res		[integer!]
			len		[integer!]
			metrics [tagNONCLIENTMETRICS value]
			theme?	[logic!]
	][
		theme?: IsThemeActive
		res: -1
		either theme? [
			hTheme: OpenThemeData null #u16 "Window"
			if hTheme <> null [
				res: GetThemeSysFont hTheme 805 :ft		;-- TMT_MSGBOXFONT
				font: :ft
			]
		][
			metrics/cbSize: size? tagNONCLIENTMETRICS
			res: as-integer SystemParametersInfo 29h size? tagNONCLIENTMETRICS as int-ptr! :metrics 0
			font: as tagLOGFONT :metrics/lfMessageFont
		]
		if res >= 0 [
			name: as-c-string :font/lfFaceName
			len: utf16-length? name
			res: len + 1 * 2
			default-font-name: as c-string! allocate res
			copy-memory as byte-ptr! default-font-name as byte-ptr! name res
			string/load-at
				name
				len
				#get system/view/fonts/system
				UTF-16LE
			
			integer/make-at 
				#get system/view/fonts/size
				0 - (font/lfHeight * 72 / as-integer dpi-x)
				
			default-font: CreateFontIndirect font

			if theme? [CloseThemeData hTheme]
		]

		if null? default-font [default-font: GetStockObject DEFAULT_GUI_FONT]
	]

	RedWndProc: func [
		hWnd	[handle!]
		msg		[integer!]
		wParam	[integer!]
		lParam	[integer!]
		return: [integer!]
		/local
			cs	[tagCREATESTRUCT]
			rc	[RECT_STRUCT]
			obj [gob!]
	][
		obj: as gob! GetWindowLongPtr hWnd 0

		switch msg [
			WM_NCCREATE [
				cs: as tagCREATESTRUCT lParam
				SetWindowLongPtr hWnd 0 cs/lpCreateParams
				1		;-- continue to create the window
			]
			WM_MOUSEHOVER [0]
			WM_MOUSELEAVE [0]
			WM_MOVING [0]
			WM_KEYDOWN [0]
			WM_SYSKEYDOWN [0]
			WM_SYSCHAR [0]
			WM_CHAR [0]
			WM_UNICHAR [0]
			WM_SETFOCUS [0]
			WM_KILLFOCUS [0]
			WM_SIZE [0]
			WM_GETMINMAXINFO [0]	;-- for maximization and minimization
			WM_NCACTIVATE [0]
			WM_MOUSEACTIVATE [0]
			WM_SETCURSOR [0]
			WM_GETOBJECT [0]		;-- for accessibility support
			WM_CLOSE [0]
			WM_DESTROY [
				PostQuitMessage 0
				return 0
			]
			WM_DPICHANGED [
				dpi-x: as float32! WIN32_LOWORD(wParam)			;-- new DPI X
				dpi-y: as float32! WIN32_HIWORD(wParam)			;-- new DPI Y
				dpi-factor: WIN32_LOWORD(wParam) * 100 / 96
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
			default [0]
		]
		DefWindowProc hWnd msg wParam lParam
	]

	register-classes: func [
		hInstance [handle!]
		/local
			wcex  [WNDCLASSEX value]
			cur	  [handle!]
	][
		cur: LoadCursor null IDC_ARROW

		wcex/cbSize: 		size? WNDCLASSEX
		wcex/style:			0
		wcex/lpfnWndProc:	:RedWndProc
		wcex/cbClsExtra:	0
		wcex/cbWndExtra:	size? int-ptr!		;-- gob
		wcex/hInstance:		hInstance
		wcex/hIcon:			LoadIcon hInstance as c-string! 1
		wcex/hCursor:		cur
		wcex/hbrBackground:	0
		wcex/lpszMenuName:	null
		wcex/lpszClassName: #u16 "RedHostWindow"
		wcex/hIconSm:		0
		RegisterClassEx		wcex
	]

	unregister-classes: func [
		hInstance [handle!]
	][
		UnregisterClass #u16 "RedHostWindow"	hInstance
	]

	init: func [
		/local
			ver   [red-tuple!]
			int   [red-integer!]
	][
		probe "init ......."
		process-id:		GetCurrentProcessId
		hInstance:		GetModuleHandle 0

		version-info/dwOSVersionInfoSize: size? OSVERSIONINFO
		GetVersionEx version-info

		win10?: version-info/dwMajorVersion >= 10
		win8+?: any [
			win10?
			all [											;-- Win 8, Win 8.1
				version-info/dwMajorVersion >= 6
				version-info/dwMinorVersion >= 2
			]
		]
	
		ver: as red-tuple! #get system/view/platform/version

		ver/header: TYPE_TUPLE or (3 << 19)
		ver/array1: version-info/dwMajorVersion
			or (version-info/dwMinorVersion << 8)
			and 0000FFFFh
probe 2
		DX-init
probe 3
		set-defaults
probe 4
		register-classes hInstance
probe 5

		int: as red-integer! #get system/view/platform/build
		int/header: TYPE_INTEGER
		int/value:  version-info/dwBuildNumber

		int: as red-integer! #get system/view/platform/product
		int/header: TYPE_INTEGER
		int/value:  as-integer version-info/wProductType
	]

	cleanup: does [
		unregister-classes hInstance
		DX-cleanup
	]

	make-window: func [
		obj			[gob!]
		parent		[handle!]
		return:		[handle!]
		/local
			rc		[RECT_STRUCT value]
			wsflags [integer!]
			flags	[integer!]
			bits	[integer!]
			w		[integer!]
			h		[integer!]
			handle	[handle!]
	][
probe "make window"
		flags: WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX or WS_THICKFRAME
		wsflags: 0
		if win10? [wsflags: wsflags or WS_EX_NOREDIRECTIONBITMAP]

		w: obj/box/x2 - obj/box/x1
		h: obj/box/y2 - obj/box/y1
		if w <= 0 [w: 200]
		if h <= 0 [h: 200]
		rc/left: 0
		rc/top: 0
		rc/right:  dpi-scale w
		rc/bottom: dpi-scale h
		AdjustWindowRectEx rc flags no 0
		w: rc/right - rc/left
		h: rc/bottom - rc/top

		handle: CreateWindowEx
			wsflags
			#u16 "RedHostWindow"
			#u16 "RedCustomWindow"
			flags
			dpi-scale obj/box/x1
			dpi-scale obj/box/y1
			w
			h
			parent
			null
			hInstance
			as int-ptr! obj

		obj/flags: obj/flags and FFFFFF00h or GOB_WINDOW or GOB_FLAG_HOSTED
?? handle
		handle
	]

	show-window: func [
		hWnd	[handle!]
	][
		?? hWnd
		ShowWindow hWnd SW_SHOWDEFAULT
	]

	do-events: func [
		no-wait? [logic!]
		return:  [logic!]
		/local
			msg	  [tagMSG value]
			state [integer!]
			msg?  [logic!]
			saved [tagMSG]
			run? [logic!]
	][
		msg?: no
		run?: yes

		unless no-wait? [exit-loop: 0]

		while [run?][
			loop 10 [
				if 0 < PeekMessage :msg null 0 0 1 [
					if msg/msg = 12h [run?: no]		;-- WM_QUIT
					unless msg? [msg?: yes]
					TranslateMessage :msg
					DispatchMessage :msg
					if no-wait? [return msg?]
				]
			]
			io/do-events 16
		]
		unless no-wait? [
			exit-loop: exit-loop - 1
			if exit-loop > 0 [PostQuitMessage 0]
		]
		msg?
	]
]