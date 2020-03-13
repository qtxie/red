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

;create-text-format: func [
;	font	[red-object!]
;	face	[red-object!]
;	return: [integer!]
;	/local
;		values	[red-value!]
;		h-font	[red-handle!]
;		int		[red-integer!]
;		value	[red-value!]
;		w		[red-word!]
;		str		[red-string!]
;		blk		[red-block!]
;		weight	[integer!]
;		style	[integer!]
;		size	[float32!]
;		len		[integer!]
;		sym		[integer!]
;		name	[c-string!]
;		format	[integer!]
;		factory [IDWriteFactory]
;		save?	[logic!]
;][
;	weight:	400
;	style:  0
;	either TYPE_OF(font) = TYPE_OBJECT [
;		save?: yes
;		values: object/get-values font
;		blk: as red-block! values + FONT_OBJ_STATE
;		if TYPE_OF(blk) <> TYPE_BLOCK [
;			block/make-at blk 2
;			none/make-in blk
;			none/make-in blk
;		]

;		value: block/rs-head blk
;		h-font: (as red-handle! value) + 1
;		if TYPE_OF(h-font) = TYPE_HANDLE [
;			return h-font/value
;		]

;		if TYPE_OF(value) = TYPE_NONE [make-font face font]	;-- make a GDI font

;		int: as red-integer! values + FONT_OBJ_SIZE
;		len: either TYPE_OF(int) <> TYPE_INTEGER [10][int/value]
;		size: ConvertPointSizeToDIP(len)

;		str: as red-string! values + FONT_OBJ_NAME
;		name: either TYPE_OF(str) = TYPE_STRING [
;			len: string/rs-length? str
;			if len > 31 [len: 31]
;			unicode/to-utf16-len str :len yes
;		][null]
		
;		w: as red-word! values + FONT_OBJ_STYLE
;		len: switch TYPE_OF(w) [
;			TYPE_BLOCK [
;				blk: as red-block! w
;				w: as red-word! block/rs-head blk
;				len: block/rs-length? blk
;			]
;			TYPE_WORD  [1]
;			default	   [0]
;		]

;		unless zero? len [
;			loop len [
;				sym: symbol/resolve w/symbol
;				case [
;					sym = _bold	 	 [weight:  700]
;					sym = _italic	 [style:	 2]
;					true			 [0]
;				]
;				w: w + 1
;			]
;		]
;	][
;		save?: no
;		int: as red-integer! #get system/view/fonts/size
;		str: as red-string!  #get system/view/fonts/system
;		size: ConvertPointSizeToDIP(int/value)
;		name: unicode/to-utf16 str
;	]

;	format: 0
;	factory: as IDWriteFactory dwrite-factory/vtbl
;	factory/CreateTextFormat dwrite-factory name 0 weight style 5 size dw-locale-name :format
;	if save? [handle/make-at as red-value! h-font format]
;	format
;]

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
		0
		;get-para-flags base para
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
	props/dpiX: host/dpi-x
	props/dpiY: host/dpi-y
	props/options: options
	props/colorContext: null

	sz/width: width
	sz/height: height
	dc: as ID2D1DeviceContext this/vtbl
	dc/CreateBitmap2 this sz null 0 props :bitmap
	as this! bitmap/value
]