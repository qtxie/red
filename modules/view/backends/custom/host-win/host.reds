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
#include %renderer.reds

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

	dpi-value:		as float32! 96.0
	dpi-x:			as float32! 0.0
	dpi-y:			as float32! 0.0
	screen-size-x:	0
	screen-size-y:	0
	default-font-name: as c-string! 0

	rc-cache:		declare RECT_STRUCT
	;kb-state: 		allocate 256							;-- holds keyboard state for keys conversion

	#include %events.reds

	DX-init: func [
		/local
			str					[red-string!]
			hr					[integer!]
			factory 			[integer!]
			dll					[handle!]
			options				[integer!]
			D2D1CreateFactory	[D2D1CreateFactory!]
			DWriteCreateFactory [DWriteCreateFactory!]
			GetUserDefaultLocaleName [GetUserDefaultLocaleName!]
			d2d					[ID2D1Factory]
			d3d					[ID3D11Device]
			d2d-dev				[ID2D1Device]
			dxgi				[IDXGIDevice1]
			adapter				[IDXGIAdapter]
			ctx					[integer!]
			unk					[IUnknown]
			d2d-device			[this!]
	][
		dll: LoadLibraryA "d2d1.dll"
		if null? dll [exit]
		D2D1CreateFactory: as D2D1CreateFactory! GetProcAddress dll "D2D1CreateFactory"
		dll: LoadLibraryA "DWrite.dll"
		if null? dll [exit]
		DWriteCreateFactory: as DWriteCreateFactory! GetProcAddress dll "DWriteCreateFactory"
		dll: LoadLibraryA "kernel32.dll"
		GetUserDefaultLocaleName: as GetUserDefaultLocaleName! GetProcAddress dll "GetUserDefaultLocaleName"
		dw-locale-name: as c-string! allocate 85
		GetUserDefaultLocaleName dw-locale-name 85
		if win8+? [
			dll: LoadLibraryA "dcomp.dll"
			pfnDCompositionCreateDevice2: GetProcAddress dll "DCompositionCreateDevice2"
		]

		ctx:	 0
		factory: 0
		options: 0													;-- debugLevel

		hr: D3D11CreateDevice
			null
			1		;-- D3D_DRIVER_TYPE_HARDWARE
			null
			33		;-- D3D11_CREATE_DEVICE_BGRA_SUPPORT or D3D11_CREATE_DEVICE_SINGLETHREADED
			null
			0
			7		;-- D3D11_SDK_VERSION
			:factory
			null
			:ctx
		assert zero? hr

		d3d-device: as this! factory
		d3d-ctx: as this! ctx

		d3d: as ID3D11Device d3d-device/vtbl
		;-- create DXGI device
		hr: d3d/QueryInterface d3d-device IID_IDXGIDevice1 as interface! :factory	
		assert zero? hr
		dxgi-device: as this! factory

		hr: D2D1CreateFactory 0 IID_ID2D1Factory1 :options :factory	;-- D2D1_FACTORY_TYPE_SINGLE_THREADED: 0
		assert zero? hr
		d2d-factory: as this! factory

		;-- get system DPI
		d2d: as ID2D1Factory d2d-factory/vtbl
		d2d/GetDesktopDpi d2d-factory :dpi-x :dpi-y
	?? dpi-y
		dpi-value: dpi-y

		;-- create D2D Device
		hr: d2d/CreateDevice d2d-factory as int-ptr! dxgi-device :factory
		d2d-device: as this! factory
		assert zero? hr

		;-- create D2D context
		d2d-dev: as ID2D1Device d2d-device/vtbl
		hr: d2d-dev/CreateDeviceContext d2d-device 0 :factory
		assert zero? hr
		d2d-ctx: as this! factory

		;-- get dxgi adapter
		dxgi: as IDXGIDevice1 dxgi-device/vtbl
		hr: dxgi/GetAdapter dxgi-device :factory
		assert zero? hr

		;-- get Dxgi factory
		dxgi-adapter: as this! factory
		adapter: as IDXGIAdapter dxgi-adapter/vtbl
		hr: adapter/GetParent dxgi-adapter IID_IDXGIFactory2 :factory
		assert zero? hr
		dxgi-factory: as this! factory

		hr: DWriteCreateFactory 0 IID_IDWriteFactory :factory		;-- DWRITE_FACTORY_TYPE_SHARED: 0
		assert zero? hr
		dwrite-factory: as this! factory
		str: string/rs-make-at ALLOC_TAIL(root) 1024
		dwrite-str-cache: str/node

		COM_SAFE_RELEASE(unk dxgi-device)
		COM_SAFE_RELEASE(unk d2d-device)
		COM_SAFE_RELEASE(unk dxgi-adapter)
	]

	DX-cleanup: func [/local unk [IUnknown]][
		COM_SAFE_RELEASE(unk dwrite-factory)
		COM_SAFE_RELEASE(unk d2d-factory)
		free as byte-ptr! dw-locale-name
	]

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

	create-dcomp: func [
		target			[render-target!]
		hWnd			[handle!]
		d2d-dc			[ID2D1DeviceContext]
		/local
			dev			[integer!]
			d2d-device	[this!]
			hr			[integer!]
			unk			[IUnknown]
			dcomp-dev	[IDCompositionDevice]
			dcomp		[IDCompositionTarget]
			this		[this!]
			tg			[this!]
			visual		[IDCompositionVisual]
			DCompositionCreateDevice2 [DCompositionCreateDevice2!]
	][
		dev: 0
		d2d-dc/GetDevice d2d-ctx :dev
		d2d-device: as this! dev
		DCompositionCreateDevice2: as DCompositionCreateDevice2! pfnDCompositionCreateDevice2
		hr: DCompositionCreateDevice2 d2d-device IID_IDCompositionDevice :dev
		COM_SAFE_RELEASE(unk d2d-device)
		assert hr = 0

		this: as this! dev
		target/dcomp-device: this

		dcomp-dev: as IDCompositionDevice this/vtbl
		hr: dcomp-dev/CreateTargetForHwnd this hWnd yes :dev
		assert zero? hr
		tg: as this! dev
		target/dcomp-target: tg

		hr: dcomp-dev/CreateVisual this :dev
		assert zero? hr
		this: as this! dev
		target/dcomp-visual: this

		visual: as IDCompositionVisual this/vtbl
		visual/SetContent this target/swapchain

		dcomp: as IDCompositionTarget tg/vtbl
		hr: dcomp/SetRoot tg this
		assert zero? hr
		hr: dcomp-dev/Commit target/dcomp-device
		assert zero? hr
	]

	create-render-target: func [
		hWnd		[handle!]
		return:		[render-target!]
		/local
			rt		[render-target!]
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
			d2d		[ID2D1DeviceContext]
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

		;-- get back buffer from the swap chain
		this: as this! int
		sc: as IDXGISwapChain1 this/vtbl
		hr: sc/GetBuffer this 0 IID_IDXGISurface :buf
		assert zero? hr

		;-- create a bitmap from the buffer
		props/format: 87		;-- DXGI_FORMAT_B8G8R8A8_UNORM
		props/alphaMode: 1		;-- D2D1_ALPHA_MODE_PREMULTIPLIED
		props/dpiX: dpi-x
		props/dpiY: dpi-y
		props/options: 3		;-- D2D1_BITMAP_OPTIONS_TARGET or D2D1_BITMAP_OPTIONS_CANNOT_DRAW
		props/colorContext: null
		bmp: 0
		d2d: as ID2D1DeviceContext d2d-ctx/vtbl
		d2d/setDpi d2d-ctx dpi-x dpi-y
		hr: d2d/CreateBitmapFromDxgiSurface d2d-ctx as int-ptr! buf props :bmp
		assert hr = 0
		
		rt: as render-target! allocate size? render-target!
		rt/swapchain: as this! int
		rt/bitmap: as this! bmp

		COM_SAFE_RELEASE_OBJ(unk buf)
		if win8+? [create-dcomp rt hWnd d2d]
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
		parent		[handle!]
		return:		[handle!]
		/local
			rc		[RECT_STRUCT value]
			wsflags [integer!]
			flags	[integer!]
			bits	[integer!]
			w		[integer!]
			h		[integer!]
	][
probe "make window"
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

		CreateWindowEx
			wsflags
			#u16 "RedHostWindow"
			#u16 "RedCustomWindow"
			flags
			logical-to-pixel obj/box/left
			logical-to-pixel obj/box/top
			w
			h
			parent
			null
			hInstance
			as int-ptr! obj
	]

	show-window: func [
		hWnd	[handle!]
	][
		ui-manager/active-win: as wm! GetWindowLongPtr hWnd GWLP_USERDATA
		ShowWindow hWnd SW_SHOWDEFAULT
	]

	draw-begin: func [
		wm			[wm!]
		/local
			this	[this!]
			dc		[ID2D1DeviceContext]
			clr		[D3DCOLORVALUE]
			brush	[integer!]
			m		[D2D_MATRIX_3X2_F value]
	][
		this: d2d-ctx
		dc: as ID2D1DeviceContext this/vtbl
		dc/SetTarget this wm/render/bitmap
		dc/BeginDraw this
		m/m11: as float32! 1.0
		m/m12: as float32! 0.0
		m/m21: as float32! 0.0
		m/m22: as float32! 1.0
		m/dx:  as float32! 0.0
		m/dy:  as float32! 0.0
		renderer/set-matrix :m
		clr: to-dx-color 00FFCC66h null
		dc/Clear this clr
		brush: 0
		dc/CreateSolidColorBrush this clr null :brush
		renderer/brush: as this! brush
	]

	draw-end: func [
		wm		[wm!]
		/local
			this	[this!]
			dc		[ID2D1DeviceContext]
			sc		[IDXGISwapChain1]
			render	[render-target!]
			m		[D2D_MATRIX_3X2_F value]
	][
		this: d2d-ctx
		dc: as ID2D1DeviceContext this/vtbl
		dc/EndDraw this null null
		dc/SetTarget this null
		render: wm/render
		this: render/swapchain
		sc: as IDXGISwapChain1 this/vtbl
		sc/Present this 0 0
	]
]

;-- 

do-events: func [
	no-wait?	[logic!]
	return:		[logic!]
	/local
		msg		[tagMSG value]
		msg?	[logic!]
		run?	[logic!]
		tm		[integer!]
][
	msg?: no
	run?: yes

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
		tm: as-integer (as float32! 16.66) - widgets/draw-windows
		if tm > 0 [io/do-events tm]
	]
	msg?
]