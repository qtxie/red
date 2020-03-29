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

#include %direct2d.reds
#include %gfx.reds
#include %draw.reds
#include %text-box.reds

host: context [
	win8+?:			no
	win10?:			no

	process-id:		0
	hInstance:		as handle! 0
	default-font:	as handle! 0
	version-info: 	declare OSVERSIONINFO
	hIMCtx:			as handle! 0
	ime-open?:		no
	;ime-font:		as tagLOGFONT allocate 92

	screen-size-x:	0
	screen-size-y:	0
	default-font-name: as c-string! 0

	rc-cache:		declare RECT_STRUCT
	;kb-state: 		allocate 256							;-- holds keyboard state for keys conversion

	#include %events.reds

	get-para-flags: func [
		type	[integer!]
		para	[red-object!]
		return: [integer!]
	][
		0
	]

	logical-to-pixel: func [
		num		[float32!]
		return: [integer!]
	][
		as-integer (num * dpi-value / as-float32 96.0)
	]

	pixel-to-logical: func [
		num		[integer!]
		return: [float32!]
	][
		(as-float32 num * 96) / dpi-value
	]

	create-render-target: func [
		hWnd		[handle!]
		return:		[renderer!]
		/local
			rt		[renderer!]
			rc		[RECT_STRUCT value]
			desc	[DXGI_SWAP_CHAIN_DESC1 value]
			dxgi	[IDXGIFactory2]
			int		[integer!]
			sc		[IDXGISwapChain1]
			this	[this!]
			hr		[integer!]
			buf		[integer!]
			props	[D2D1_BITMAP_PROPERTIES1 value]
			bmp		[integer!]
			unk		[IUnknown]
	][
		GetClientRect hWnd :rc
		zero-memory as byte-ptr! :desc size? DXGI_SWAP_CHAIN_DESC1

		desc/Width: rc/right - rc/left
		desc/Height: rc/bottom - rc/top
		desc/Format: 87			;-- DXGI_FORMAT_B8G8R8A8_UNORM
		desc/SampleCount: 1
		desc/BufferUsage: 20h	;-- DXGI_USAGE_RENDER_TARGET_OUTPUT
		desc/BufferCount: 2
		desc/AlphaMode: 1		;-- DXGI_ALPHA_MODE_PREMULTIPLIED
		desc/SwapEffect: 3		;-- DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL

		int: 0
		buf: 0
		dxgi: as IDXGIFactory2 dxgi-factory/vtbl
		either win8+? [			;-- use direct composition
			hr: dxgi/CreateSwapChainForComposition dxgi-factory d3d-device desc null :int
		][
			desc/AlphaMode: 0
			hr: dxgi/CreateSwapChainForHwnd dxgi-factory d3d-device hWnd desc null null :int
		]
		assert zero? hr

		rt: as renderer! allocate size? renderer!
		DX-create-buffer rt as this! int

		if win8+? [create-dcomp rt hWnd]

		gfx/init d2d-ctx
		rt
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

	get-screen-size: func [
		id		[integer!]									;@@ Not used yet
		return: [red-pair!]
		/local
			dc	[handle!]
	][
		dc: GetDC null
		screen-size-x: GetDeviceCaps dc HORZRES
		screen-size-y: GetDeviceCaps dc VERTRES
		pair/push
			as-integer pixel-to-logical screen-size-x
			as-integer pixel-to-logical screen-size-y
	]

	init: func [
		/local
			ver   [red-tuple!]
			int   [red-integer!]
	][
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

		DX-init
		set-defaults
		register-classes hInstance

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
		parent		[gob!]
		return:		[handle!]
		/local
			rc		[RECT_STRUCT value]
			wsflags [integer!]
			flags	[integer!]
			bits	[integer!]
			w		[integer!]
			h		[integer!]
			wm		[wm!]
			handle	[handle!]
	][
		flags: WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX or WS_THICKFRAME
		wsflags: 0
		if win10? [wsflags: wsflags or WS_EX_NOREDIRECTIONBITMAP]

		w: logical-to-pixel obj/box/right - obj/box/left
		h: logical-to-pixel obj/box/bottom - obj/box/top
		if w <= 0 [w: 200]
		if h <= 0 [h: 200]
		rc/left: 0
		rc/top: 0
		rc/right:  w
		rc/bottom: h
		AdjustWindowRectEx rc flags no 0
		w: rc/right - rc/left
		h: rc/bottom - rc/top

		either parent <> null [
			wm: as wm! parent/data
			handle: wm/hwnd
		][handle: null]

		CreateWindowEx
			wsflags
			#u16 "RedHostWindow"
			#u16 "RedCustomWindow"
			flags
			logical-to-pixel obj/box/left
			logical-to-pixel obj/box/top
			w
			h
			handle
			null
			hInstance
			as int-ptr! obj
	]

	show-window: func [
		hWnd	[handle!]
	][
		ShowWindow hwnd SW_SHOWDEFAULT
	]

	draw-begin: func [
		wm			[wm!]
		/local
			this	[this!]
			dc		[ID2D1DeviceContext]
			clr		[D3DCOLORVALUE]
			brush	[com-ptr! value]
	][
		this: d2d-ctx
		gfx/set-renderer wm/render
		gfx/set-target wm/render/bitmap
		current-rt: wm/render

		dc: as ID2D1DeviceContext this/vtbl
		dc/BeginDraw this
		matrix2d/identity wm/matrix
		gfx/set-matrix wm/matrix
		clr: to-dx-color wm/gob/backdrop null
		dc/Clear this clr
	]

	draw-end: func [
		wm		[wm!]
		/local
			this	[this!]
			dc		[ID2D1DeviceContext]
			sc		[IDXGISwapChain1]
			render	[renderer!]
			m		[D2D_MATRIX_3X2_F value]
			hr		[integer!]
	][
		this: d2d-ctx
		dc: as ID2D1DeviceContext this/vtbl
		dc/EndDraw this null null
		dc/SetTarget this null

		render: wm/render
		this: render/swapchain
		sc: as IDXGISwapChain1 this/vtbl
		hr: sc/Present this 0 0
		switch hr [
			COM_S_OK [0]
			DXGI_ERROR_DEVICE_REMOVED
			DXGI_ERROR_DEVICE_RESET [
				DX-release-target render
				DX-create-dev
				wm/render: create-render-target wm/hWnd
			]
			default [
				VIEW_ERROR(["IDXGISwapChain1/Present failed: " as int-ptr! hr])
			]
		]
	]
]

do-events: func [
	no-wait?	[logic!]
	return:		[logic!]
	/local
		msg		[tagMSG value]
		msg?	[logic!]
		run?	[logic!]
		tm		[integer!]
		mt		[time-meter! value]
		t		[float32!]
][
	msg?: no
	run?: yes

	while [run?][
		;time-meter/start :mt
		
		loop 10 [
			if 0 < PeekMessage :msg null 0 0 1 [
				if msg/msg = 12h [run?: no]		;-- WM_QUIT
				unless msg? [msg?: yes]
				TranslateMessage :msg
				DispatchMessage :msg
				if no-wait? [return msg?]
			]
		]
		tm: as-integer (as float32! 16.66) - ui-manager/draw-windows
		if tm > 0 [io/do-events tm]

		;t: time-meter/elapse :mt
		;VIEW_MSG(["sleep " t "ms"])
	]
	msg?
]