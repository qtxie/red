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
	dpi-value: as-integer dpi-y

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

d2d-release-target: func [
	target	[int-ptr!]
	/local
		rt		[ID2D1HwndRenderTarget]
		brushes [int-ptr!]
		cnt		[integer!]
		this	[this!]
		obj		[IUnknown]
][
	brushes: as int-ptr! target/2
	cnt: target/3
	loop cnt [
		COM_SAFE_RELEASE_OBJ(obj brushes/2)
		brushes: brushes + 2
	]
	this: as this! target/1
	rt: as ID2D1HwndRenderTarget this/vtbl
	rt/Release this
	free as byte-ptr! target
]

create-hwnd-render-target: func [
	hwnd	[handle!]
	return: [this!]
	/local
		props		[D2D1_RENDER_TARGET_PROPERTIES value]
		options		[integer!]
		height		[integer!]
		width		[integer!]
		wnd			[integer!]
		hprops		[D2D1_HWND_RENDER_TARGET_PROPERTIES]
		bottom		[integer!]
		right		[integer!]
		top			[integer!]
		left		[integer!]
		factory		[ID2D1Factory]
		rt			[ID2D1HwndRenderTarget]
		target		[integer!]
		hr			[integer!]
][
	left: 0 top: 0 right: 0 bottom: 0
	GetClientRect hwnd as RECT_STRUCT :left
	wnd: as-integer hwnd
	width: right - left
	height: bottom - top
	options: 1						;-- D2D1_PRESENT_OPTIONS_RETAIN_CONTENTS: 1
	hprops: as D2D1_HWND_RENDER_TARGET_PROPERTIES :wnd

	zero-memory as byte-ptr! :props size? D2D1_RENDER_TARGET_PROPERTIES
	props/dpiX: dpi-x
	props/dpiY: dpi-y

	target: 0
	factory: as ID2D1Factory d2d-factory/vtbl
	hr: factory/CreateHwndRenderTarget d2d-factory :props hprops :target
	if hr <> 0 [return null]
	as this! target
]

get-hwnd-render-target: func [
	hWnd	[handle!]
	return:	[int-ptr!]
	/local
		target	[int-ptr!]
][
	target: GetWindowLongPtr hWnd GWLP_USERDATA
	if null? target [
		target: as int-ptr! allocate 4 * size? int-ptr!
		target/1: as-integer create-hwnd-render-target hWnd
		target/2: as-integer allocate D2D_MAX_BRUSHES * 2 * size? int-ptr!
		target/3: 0
		target/4: 0			;-- for text-box! background color
		SetWindowLongPtr hWnd GWLP_USERDATA target
	]
	target
]

create-dc-render-target: func [
	dc		[handle!]
	rc		[RECT_STRUCT]
	return: [this!]
	/local
		props		[D2D1_RENDER_TARGET_PROPERTIES value]
		factory		[ID2D1Factory]
		rt			[ID2D1DCRenderTarget]
		IRT			[this!]
		target		[integer!]
		hr			[integer!]
][
	props/type: 0									;-- D2D1_RENDER_TARGET_TYPE_DEFAULT
	props/format: 87								;-- DXGI_FORMAT_B8G8R8A8_UNORM
	props/alphaMode: 1								;-- D2D1_ALPHA_MODE_PREMULTIPLIED
	props/dpiX: dpi-x
	props/dpiY: dpi-y
	props/usage: 2									;-- D2D1_RENDER_TARGET_USAGE_GDI_COMPATIBLE
	props/minLevel: 0								;-- D2D1_FEATURE_LEVEL_DEFAULT

	target: 0
	factory: as ID2D1Factory d2d-factory/vtbl
	hr: factory/CreateDCRenderTarget d2d-factory :props :target
	if hr <> 0 [return null]

	IRT: as this! target
	rt: as ID2D1DCRenderTarget IRT/vtbl
	hr: rt/BindDC IRT dc rc
	if hr <> 0 [rt/Release IRT return null]
	IRT
]

create-text-format: func [
	font	[red-object!]
	face	[red-object!]
	return: [integer!]
	/local
		values	[red-value!]
		h-font	[red-handle!]
		int		[red-integer!]
		value	[red-value!]
		w		[red-word!]
		str		[red-string!]
		blk		[red-block!]
		weight	[integer!]
		style	[integer!]
		size	[float32!]
		len		[integer!]
		sym		[integer!]
		name	[c-string!]
		format	[integer!]
		factory [IDWriteFactory]
		save?	[logic!]
][
	weight:	400
	style:  0
	either TYPE_OF(font) = TYPE_OBJECT [
		save?: yes
		values: object/get-values font
		blk: as red-block! values + FONT_OBJ_STATE
		if TYPE_OF(blk) <> TYPE_BLOCK [
			block/make-at blk 2
			none/make-in blk
			none/make-in blk
		]

		value: block/rs-head blk
		h-font: (as red-handle! value) + 1
		if TYPE_OF(h-font) = TYPE_HANDLE [
			return h-font/value
		]

		if TYPE_OF(value) = TYPE_NONE [make-font face font]	;-- make a GDI font

		int: as red-integer! values + FONT_OBJ_SIZE
		len: either TYPE_OF(int) <> TYPE_INTEGER [10][int/value]
		size: ConvertPointSizeToDIP(len)

		str: as red-string! values + FONT_OBJ_NAME
		name: either TYPE_OF(str) = TYPE_STRING [
			len: string/rs-length? str
			if len > 31 [len: 31]
			unicode/to-utf16-len str :len yes
		][null]
		
		w: as red-word! values + FONT_OBJ_STYLE
		len: switch TYPE_OF(w) [
			TYPE_BLOCK [
				blk: as red-block! w
				w: as red-word! block/rs-head blk
				len: block/rs-length? blk
			]
			TYPE_WORD  [1]
			default	   [0]
		]

		unless zero? len [
			loop len [
				sym: symbol/resolve w/symbol
				case [
					sym = _bold	 	 [weight:  700]
					sym = _italic	 [style:	 2]
					true			 [0]
				]
				w: w + 1
			]
		]
	][
		save?: no
		int: as red-integer! #get system/view/fonts/size
		str: as red-string!  #get system/view/fonts/system
		size: ConvertPointSizeToDIP(int/value)
		name: unicode/to-utf16 str
	]

	format: 0
	factory: as IDWriteFactory dwrite-factory/vtbl
	factory/CreateTextFormat dwrite-factory name 0 weight style 5 size dw-locale-name :format
	if save? [handle/make-at as red-value! h-font format]
	format
]

set-text-format: func [
	fmt		[this!]
	para	[red-object!]
	/local
		flags	[integer!]
		h-align [integer!]
		v-align [integer!]
		wrap	[integer!]
		format	[IDWriteTextFormat]
][
	flags: either TYPE_OF(para) = TYPE_OBJECT [
		get-para-flags base para
	][
		0
	]
	case [
		flags and 1 <> 0 [h-align: 2]
		flags and 2 <> 0 [h-align: 1]
		true			 [h-align: 0]
	]
	case [
		flags and 4 <> 0 [v-align: 2]
		flags and 8 <> 0 [v-align: 1]
		true			 [v-align: 0]
	]
	wrap: either flags and 20h = 0 [0][1]

	format: as IDWriteTextFormat fmt/vtbl
	format/SetTextAlignment fmt h-align
	format/SetParagraphAlignment fmt v-align
	format/SetWordWrapping fmt wrap
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
		lay				[integer!]
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

	left: 73 lineCount: 0 lay: 0 
	dw: as IDWriteFactory dwrite-factory/vtbl
	dw/CreateTextLayout dwrite-factory as c-string! :left 1 fmt FLT_MAX FLT_MAX :lay
	layout: as this! lay
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
		lay	[integer!]
][
	len: -1
	either TYPE_OF(text) = TYPE_STRING [
		if null? text/cache [text/cache: dwrite-str-cache]
		str: unicode/to-utf16-len text :len no
	][
		str: ""
		len: 0
	]
	lay: 0
	w: either zero? width  [FLT_MAX][as float32! width]
	h: either zero? height [FLT_MAX][as float32! height]

	dw: as IDWriteFactory dwrite-factory/vtbl
	dw/CreateTextLayout dwrite-factory str len fmt w h :lay
	as this! lay
]

draw-text-d2d: func [
	dc		[handle!]
	text	[red-string!]
	font	[red-object!]
	para	[red-object!]
	rc		[RECT_STRUCT]
	/local
		this	[this!]
		this2	[this!]
		fmt		[this!]
		layout	[this!]
		obj		[IUnknown]
		rt		[ID2D1DCRenderTarget]
		dwrite	[IDWriteFactory]
		brush	[integer!]
		color	[red-tuple!]
		clr		[integer!]
		_11		[integer!]
		_12		[integer!]
		_21		[integer!]
		_22		[integer!]
		_31		[integer!]
		_32		[integer!]
		m		[D2D_MATRIX_3X2_F]
][
	fmt: as this! create-text-format font null
	set-text-format fmt para

	layout: create-text-layout text fmt rc/right rc/bottom

	this: create-dc-render-target dc rc
	rt: as ID2D1DCRenderTarget this/vtbl
	rt/SetTextAntialiasMode this 1					;-- ClearType

	rt/BeginDraw this
	_11: 0 _12: 0 _21: 0 _22: 0 _31: 0 _32: 0
	m: as D2D_MATRIX_3X2_F :_32
	m/_11: as float32! 1.0
	m/_22: as float32! 1.0
	rt/SetTransform this m							;-- set to identity matrix

	clr: either TYPE_OF(font) = TYPE_OBJECT [
		color: as red-tuple! (object/get-values font) + FONT_OBJ_COLOR
		color/array1
	][
		0											;-- black
	]
	brush: 0
	rt/CreateSolidColorBrush this to-dx-color clr null null :brush
	rt/DrawTextLayout this as float32! 0.0 as float32! 0.0 layout brush 0
	rt/EndDraw this null null

	this2: as this! brush
	COM_SAFE_RELEASE(obj this2)
	COM_SAFE_RELEASE(obj layout)
	COM_SAFE_RELEASE(obj fmt)
	rt/Release this
]

render-text-d2d: func [
	values	[red-value!]				;-- face! values
	hDC		[handle!]
	rc		[RECT_STRUCT]
	return: [logic!]
	/local
		font	[red-object!]
		para	[red-object!]
		text	[red-string!]
][
	text: as red-string! values + FACE_OBJ_TEXT
	either TYPE_OF(text) = TYPE_STRING [
		font: as red-object! values + FACE_OBJ_FONT
		para: as red-object! values + FACE_OBJ_PARA
		draw-text-d2d hDC text font para rc
		true
	][
		false
	]
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