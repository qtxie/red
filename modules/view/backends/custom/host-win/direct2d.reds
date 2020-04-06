Red/System [
	Title:	"Direct2D structures and functions"
	Author: "Xie Qingtian"
	File: 	%direct2d.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

d3d-device:		as this! 0
d3d-ctx:		as this! 0
d2d-ctx:		as this! 0
d2d-factory:	as this! 0
dwrite-factory: as this! 0
dxgi-device:	as this! 0
dxgi-adapter:	as this! 0
dxgi-factory:	as this! 0
dw-locale-name: as c-string! 0
dpi-value:		as float32! 96.0
dpi-x:			as float32! 0.0
dpi-y:			as float32! 0.0

pfnDCompositionCreateDevice2: as int-ptr! 0

dwrite-str-cache: as node! 0

select-brush: func [
	target		[int-ptr!]
	color		[integer!]
	return: 	[integer!]
	/local
		brushes [int-ptr!]
		cnt		[integer!]
][
	brushes: as int-ptr! target/1
	cnt: target/2
	loop cnt [
		either brushes/value = color [
			return brushes/2
		][
			brushes: brushes + 2
		]
	]
	0
]

put-brush: func [
	target		[int-ptr!]
	color		[integer!]
	brush		[integer!]
	/local
		brushes [int-ptr!]
		cnt		[integer!]
][
	cnt: target/2
	brushes: (as int-ptr! target/1) + (cnt * 2)
	brushes/1: color
	brushes/2: brush
	target/2: cnt + 1 % D2D_MAX_BRUSHES
]

to-dx-color: func [
	color	[integer!]
	clr-ptr [D3DCOLORVALUE]
	return: [D3DCOLORVALUE]
	/local
		c	[D3DCOLORVALUE]
][
	either null? clr-ptr [
		c: declare D3DCOLORVALUE
	][
		c: clr-ptr
	]
	c/r: (as float32! color and FFh) / 255.0
	c/g: (as float32! color >> 8 and FFh) / 255.0
	c/b: (as float32! color >> 16 and FFh) / 255.0
	c/a: (as float32! 255 - (color >>> 24)) / 255.0
	c
]

set-tab-size: func [
	fmt		[this!]
	size	[red-integer!]
	/local
		t	[integer!]
		tf	[IDWriteTextFormat]
][
	t: TYPE_OF(size)
	if any [t = TYPE_INTEGER t = TYPE_FLOAT][
		tf: as IDWriteTextFormat fmt/vtbl
		tf/SetIncrementalTabStop fmt get-float32 size
	]
]

set-line-spacing: func [
	fmt		[this!]
	int		[red-integer!]
	/local
		IUnk			[IUnknown]
		dw				[IDWriteFactory]
		lay				[com-ptr! value]
		layout			[this!]
		lineCount		[integer!]
		maxBidiDepth	[integer!]
		baseline		[float32!]
		height			[float32!]
		width			[float32!]
		top				[float32!]
		left			[integer!]
		tf				[IDWriteTextFormat]
		dl				[IDWriteTextLayout]
		lm				[DWRITE_LINE_METRICS]
		type			[integer!]
][
	type: TYPE_OF(int)
	if all [type <> TYPE_INTEGER type <> TYPE_FLOAT][exit]

	left: 73 lineCount: 0
	dw: as IDWriteFactory dwrite-factory/vtbl
	dw/CreateTextLayout dwrite-factory as c-string! :left 1 fmt FLT_MAX FLT_MAX :lay
	layout: lay/value
	dl: as IDWriteTextLayout layout/vtbl
	lm: as DWRITE_LINE_METRICS :left
	dl/GetLineMetrics layout lm 1 :lineCount
	tf: as IDWriteTextFormat fmt/vtbl
	tf/SetLineSpacing fmt 1 get-float32 int lm/baseline
	COM_SAFE_RELEASE(IUnk layout)
]

create-text-layout: func [
	text	[red-string!]
	fmt		[this!]
	width	[integer!]
	height	[integer!]
	return: [this!]
	/local
		str	[c-string!]
		len	[integer!]
		dw	[IDWriteFactory]
		w	[float32!]
		h	[float32!]
		lay	[com-ptr! value]
][
	len: -1
	either TYPE_OF(text) = TYPE_STRING [
		if null? text/cache [text/cache: dwrite-str-cache]
		str: unicode/to-utf16-len text :len no
	][
		str: ""
		len: 0
	]

	w: either zero? width  [FLT_MAX][as float32! width]
	h: either zero? height [FLT_MAX][as float32! height]

	dw: as IDWriteFactory dwrite-factory/vtbl
	dw/CreateTextLayout dwrite-factory str len fmt w h :lay
	lay/value
]

render-target-lost?: func [
	target	[this!]
	return: [logic!]
	/local
		rt	 [ID2D1HwndRenderTarget]
		hr	 [integer!]
][
	rt: as ID2D1HwndRenderTarget target/vtbl
	rt/BeginDraw target
	rt/Clear target to-dx-color 0 null
	0 <> rt/EndDraw target null null
]

create-d2d-bitmap: func [
	this	[this!]
	width	[uint32!]
	height	[uint32!]
	options	[integer!]
	return: [this!]
	/local
		dc		[ID2D1DeviceContext]
		props	[D2D1_BITMAP_PROPERTIES1 value]
		sz		[SIZE_U! value]
		bitmap	[ptr-value!]
][
	props/format: 87
	props/alphaMode: 1
	props/dpiX: dpi-x
	props/dpiY: dpi-y
	props/options: options
	props/colorContext: null

	sz/width: width
	sz/height: height
	dc: as ID2D1DeviceContext this/vtbl
	dc/CreateBitmap2 this sz null 0 props :bitmap
	as this! bitmap/value
]

create-dcomp: func [
	target			[renderer!]
	hWnd			[handle!]
	/local
		dev			[integer!]
		d2d-dc		[ID2D1DeviceContext]
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
	d2d-dc: as ID2D1DeviceContext d2d-ctx/vtbl
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

DX-init: func [
	/local
		str					[red-string!]
		hr					[integer!]
		factory 			[com-ptr! value]
		dll					[handle!]
		options				[integer!]
		DWriteCreateFactory [DWriteCreateFactory!]
		GetUserDefaultLocaleName [GetUserDefaultLocaleName!]
][
	dll: LoadLibraryA "DWrite.dll"
	if null? dll [exit]
	DWriteCreateFactory: as DWriteCreateFactory! GetProcAddress dll "DWriteCreateFactory"
	dll: LoadLibraryA "kernel32.dll"
	GetUserDefaultLocaleName: as GetUserDefaultLocaleName! GetProcAddress dll "GetUserDefaultLocaleName"
	dw-locale-name: as c-string! allocate 85
	GetUserDefaultLocaleName dw-locale-name 85

	;-- create D2D factory
	options: 0													;-- debugLevel
	#if debug? = yes [options: 3]								;-- D2D1_DEBUG_LEVEL_INFORMATION
	hr: D2D1CreateFactory 0 IID_ID2D1Factory1 :options :factory	;-- D2D1_FACTORY_TYPE_SINGLE_THREADED: 0
	assert zero? hr
	d2d-factory: as this! factory/value

	;-- create DWrite factory
	hr: DWriteCreateFactory 0 IID_IDWriteFactory :factory		;-- DWRITE_FACTORY_TYPE_SHARED: 0
	assert zero? hr
	dwrite-factory: as this! factory/value
	str: string/rs-make-at ALLOC_TAIL(root) 1024
	dwrite-str-cache: str/node

	DX-create-dev
]

DX-create-buffer: func [
	rt			[renderer!]
	swapchain	[this!]
	/local
		sc		[IDXGISwapChain1]
		this	[this!]
		hr		[integer!]
		buf		[integer!]
		props	[D2D1_BITMAP_PROPERTIES1 value]
		bmp		[integer!]
		d2d		[ID2D1DeviceContext]
		unk		[IUnknown]
][
	;-- get back buffer from the swap chain
	this: as this! swapchain
	sc: as IDXGISwapChain1 this/vtbl
	buf: 0
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
	
	rt/dc: d2d-ctx
	rt/swapchain: swapchain
	rt/bitmap: as this! bmp

	COM_SAFE_RELEASE_OBJ(unk buf)
]

DX-resize-buffer: func [
	rt				[renderer!]
	width			[uint!]
	height			[uint!]
	/local
		unk			[IUnknown]
		this		[this!]
		sc			[IDXGISwapChain1]
		hr			[integer!]
][
	COM_SAFE_RELEASE(unk rt/bitmap)

	this: rt/swapchain
	sc: as IDXGISwapChain1 this/vtbl
	hr: sc/ResizeBuffers this 0 width height 87 0
	if hr <> 0 [VIEW_ERROR("DX resizing buffer failed") exit]

	DX-create-buffer rt this
]

DX-create-dev: func [
	/local
		factory 			[com-ptr! value]
		d2d					[ID2D1Factory]
		d3d					[ID3D11Device]
		d2d-dev				[ID2D1Device]
		dxgi				[IDXGIDevice1]
		adapter				[IDXGIAdapter]
		ctx					[com-ptr! value]
		unk					[IUnknown]
		d2d-device			[this!]
		hr					[integer!]
		dll					[handle!]
		flags				[integer!]
][
	if host/win8+? [
		dll: LoadLibraryA "dcomp.dll"
		pfnDCompositionCreateDevice2: GetProcAddress dll "DCompositionCreateDevice2"
	]

	flags: 33	;-- D3D11_CREATE_DEVICE_BGRA_SUPPORT or D3D11_CREATE_DEVICE_SINGLETHREADED
	#if debug? = yes [flags: flags or 2]
	hr: D3D11CreateDevice
		null
		1		;-- D3D_DRIVER_TYPE_HARDWARE
		null
		flags
		null
		0
		7		;-- D3D11_SDK_VERSION
		:factory
		null
		:ctx
	assert zero? hr

	d3d-device: factory/value
	d3d-ctx: ctx/value

	d3d: as ID3D11Device d3d-device/vtbl
	;-- create DXGI device
	hr: d3d/QueryInterface d3d-device IID_IDXGIDevice1 as interface! :factory	
	assert zero? hr
	dxgi-device: factory/value

	;-- get system DPI
	d2d: as ID2D1Factory d2d-factory/vtbl
	d2d/GetDesktopDpi d2d-factory :dpi-x :dpi-y
	dpi-value: dpi-y

	;-- create D2D Device
	hr: d2d/CreateDevice d2d-factory dxgi-device :factory
	d2d-device: factory/value
	assert zero? hr

	;-- create D2D context
	d2d-dev: as ID2D1Device d2d-device/vtbl
	hr: d2d-dev/CreateDeviceContext d2d-device 0 :factory
	assert zero? hr
	d2d-ctx: factory/value

	;-- get dxgi adapter
	dxgi: as IDXGIDevice1 dxgi-device/vtbl
	hr: dxgi/GetAdapter dxgi-device :factory
	assert zero? hr

	;-- get Dxgi factory
	dxgi-adapter: factory/value
	adapter: as IDXGIAdapter dxgi-adapter/vtbl
	hr: adapter/GetParent dxgi-adapter IID_IDXGIFactory2 :factory
	assert zero? hr
	dxgi-factory: factory/value

	COM_SAFE_RELEASE(unk dxgi-device)
	COM_SAFE_RELEASE(unk d2d-device)
	COM_SAFE_RELEASE(unk dxgi-adapter)	
]

DX-release-dev: func [
	/local
		unk		[IUnknown]
][
	COM_SAFE_RELEASE(unk d2d-ctx)
	COM_SAFE_RELEASE(unk d3d-ctx)
	COM_SAFE_RELEASE(unk d3d-device)
	COM_SAFE_RELEASE(unk dxgi-factory)
]

DX-cleanup: func [/local unk [IUnknown]][
	DX-release-dev
	COM_SAFE_RELEASE(unk dwrite-factory)
	COM_SAFE_RELEASE(unk d2d-factory)
	free as byte-ptr! dw-locale-name
]

DX-release-target: func [
	target	[renderer!]
	/local
		brushes [int-ptr!]
		cnt		[integer!]
		this	[this!]
		obj		[IUnknown]
][
	brushes: target/brushes
	cnt: target/brushes-cnt
	target/brushes-cnt: 0
	loop cnt [
		COM_SAFE_RELEASE_OBJ(obj brushes/2)
		brushes: brushes + 2
	]
	COM_SAFE_RELEASE(obj target/bitmap)
	COM_SAFE_RELEASE(obj target/swapchain)
	COM_SAFE_RELEASE(obj target/dcomp-visual)
	COM_SAFE_RELEASE(obj target/dcomp-target)
	COM_SAFE_RELEASE(obj target/dcomp-device)
	free as byte-ptr! brushes
	free as byte-ptr! target
]
