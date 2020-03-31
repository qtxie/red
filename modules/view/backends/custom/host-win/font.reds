Red/System [
	Title:	"Windows fonts management"
	Author: "Xie Qingtian"
	File: 	%font.reds
	Tabs: 	4
	Rights: "Copyright (C) 2020 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

OS-make-font: func [
	font		[red-object!]
	return:		[handle!]
][
	make-dw-font font
]

make-dw-font: func [
	font	[red-object!]
	return: [handle!]
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
		format	[com-ptr! value]
		factory [IDWriteFactory]
		save?	[logic!]
][
	weight:	400
	style:  0
	either TYPE_OF(font) = TYPE_OBJECT [
		save?: yes
		values: object/get-values font

		h-font: as red-handle! values + FONT_OBJ_STATE
		if TYPE_OF(h-font) = TYPE_HANDLE [return as handle! h-font/value]	;-- already has one

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

	factory: as IDWriteFactory dwrite-factory/vtbl
	factory/CreateTextFormat dwrite-factory name 0 weight style 5 size dw-locale-name :format
	if save? [handle/make-at as red-value! h-font as-integer format/value]
	as handle! format/value
]

make-gdi-font: func [
	font		[red-object!]
	scaling?	[logic!]
	return:		[handle!]
	/local
		values	[red-value!]
		int		[red-integer!]
		value	[red-value!]
		bool	[red-logic!]
		style	[red-word!]
		str		[red-string!]
		blk		[red-block!]
		weight	[integer!]
		height	[integer!]
		angle	[integer!]
		quality [integer!]
		len		[integer!]
		sym		[integer!]
		name	[c-string!]
		italic? [logic!]
		under?	[logic!]
		strike? [logic!]
][
	values: object/get-values font
	
	int: as red-integer! values + FONT_OBJ_SIZE
	height: either TYPE_OF(int) <> TYPE_INTEGER [0][
		len: as-integer dpi-value
		unless scaling? [len: 96]
		0 - (int/value * len / 72)
	]

	int: as red-integer! values + FONT_OBJ_ANGLE
	angle: either TYPE_OF(int) = TYPE_INTEGER [int/value * 10][0]	;-- in tenth of degrees
	
	value: values + FONT_OBJ_ANTI-ALIAS?
	switch TYPE_OF(value) [
		TYPE_LOGIC [
			bool: as red-logic! value
			quality: either bool/value [4][0]			;-- ANTIALIASED_QUALITY
		]
		TYPE_WORD [
			style: as red-word! value
			either ClearType = symbol/resolve style/symbol [
				quality: 5								;-- CLEARTYPE_QUALITY
			][
				quality: 0
				;fire error ?
			]
		]
		default [quality: 0]							;-- DEFAULT_QUALITY
	]
	
	str: as red-string! values + FONT_OBJ_NAME
	name: either TYPE_OF(str) = TYPE_STRING [
		len: string/rs-length? str
		if len > 31 [len: 31]
		unicode/to-utf16-len str :len yes
	][host/default-font-name]

	style: as red-word! values + FONT_OBJ_STYLE
	len: switch TYPE_OF(style) [
		TYPE_BLOCK [
			blk: as red-block! style
			style: as red-word! block/rs-head blk
			len: block/rs-length? blk
		]
		TYPE_WORD  [1]
		default	   [0]
	]
	
	italic?: no
	under?:  no
	strike?: no
	weight:	 0

	unless zero? len [
		loop len [
			sym: symbol/resolve style/symbol
			case [
				sym = _bold	 	 [weight:  700]
				sym = _italic	 [italic?: yes]
				sym = _underline [under?:  yes]
				sym = _strike	 [strike?: yes]
				true			 [0]
			]
			style: style + 1
		]
	]

	CreateFont
		height
		0												;-- nWidth
		0												;-- nEscapement
		angle											;-- nOrientation
		weight
		as-integer italic?
		as-integer under?
		as-integer strike?
		1												;-- DEFAULT_CHARSET
		0												;-- OUT_DEFAULT_PRECIS
		0												;-- CLIP_DEFAULT_PRECIS
		quality
		0												;-- DEFAULT_PITCH
		name
]

get-font-handle: func [
	font	[red-object!]
	return: [handle!]
	/local
		handle [red-handle!]
][
	handle: as red-handle! (object/get-values font) + FONT_OBJ_STATE
	if TYPE_OF(handle) = TYPE_HANDLE [
		return as handle! handle/value
	]
	null
]

free-font: func [
	font [red-object!]
	/local
		state [red-block!]
		this  [this!]
		obj   [IUnknown]
][
	this: as this! get-font-handle font
	COM_SAFE_RELEASE(obj this)
	state: as red-block! (object/get-values font) + FONT_OBJ_STATE
	state/header: TYPE_NONE
]

OS-request-font: func [
	font	 [red-object!]
	selected [red-object!]
	mono?	 [logic!]
	return:  [red-object!]
	/local
		values	[red-value!]
		str		[red-string!]
		style	[red-block!]
		cf		[tagCHOOSEFONT]
		logfont [tagLOGFONT]
		size	[integer!]
		hfont	[handle!]
		name	[c-string!]
		bold?	[logic!]
		dpi-v	[integer!]
][
	size: size? tagCHOOSEFONT
	cf: as tagCHOOSEFONT allocate size
	logfont: as tagLOGFONT allocate 92
	zero-memory as byte-ptr! cf size
	zero-memory as byte-ptr! logfont 92

	name: as c-string! (as byte-ptr! logfont) + 28

	hfont: make-gdi-font selected yes
	either null? hfont [
		copy-memory as byte-ptr! name as byte-ptr! #u16 "Courier New" 22
		dpi-v: as-integer dpi-value
		logfont/lfHeight: -11 * dpi-v / 72
		logfont/lfCharSet: #"^(01)"						;-- default
	][
		GetObject hfont 92 as byte-ptr! logfont
	]

	cf/lStructSize: size
	cf/hwndOwner: GetForegroundWindow
	cf/lpLogFont: logfont
	cf/Flags: 01000043h									;-- CF_INITTOLOGFONTSTRUCT or CF_BOTH or CF_NOVERTFONTS
	if mono? [cf/Flags: 4000h or cf/Flags]				;-- CF_FIXEDPITCHONLY

	either ChooseFont cf [
		size: lstrlen as byte-ptr! name
		values: object/get-values font
		str: as red-string! values + FONT_OBJ_NAME
		str/header: TYPE_UNSET
		str/head:	0
		str/cache:	null
		str/node:	unicode/load-utf16 name size null no
		str/header:	TYPE_STRING							;-- implicit reset of all header flags
		integer/make-at values + FONT_OBJ_SIZE cf/iPointSize / 10

		style: as red-block! values + FONT_OBJ_STYLE
		bold?: no
		if logfont/lfWeight = 700 [
			word/make-at _bold as red-value! style
			bold?: yes
		]
		if logfont/lfItalic <> #"^@" [
			either bold? [
				block/make-at style 4
				word/push-in _bold style
				word/push-in _italic style
			][
				word/make-at _italic as red-value! style
			]
		]
	][
		font/header: TYPE_NONE
	]

	free as byte-ptr! cf
	free as byte-ptr! logfont
	DeleteObject hfont
	font
]