Red/System [
	Title:	"Styles handling"
	Author: "Xie Qingtian"
	File: 	%styles.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

styles-ctx: context [
	background:				symbol/make "background"
	background-clip:		symbol/make "background-clip"
	background-size:		symbol/make "background-size"
	background-color:		symbol/make "background-color"
	background-image:		symbol/make "background-image"
	background-repeat:		symbol/make "background-repeat"
	background-origin:		symbol/make "background-origin"
	background-position:	symbol/make "background-position"
	background-attachment:	symbol/make "background-attachment"
	background-blend-mode:	symbol/make "background-blend-mode"
	
	border:					symbol/make "border"
	border-style:			symbol/make "border-style"
	border-width:			symbol/make "border-width"
	border-color:			symbol/make "border-color"
	border-image:			symbol/make "border-image"
	border-radius:			symbol/make "border-radius"
	border-bottom:			symbol/make "border-bottom"
	border-bottom-color:	symbol/make "border-bottom-color"
	border-bottom-style:	symbol/make "border-bottom-style"
	border-bottom-width:	symbol/make "border-bottom-width"
	border-bottom-radius:	symbol/make "border-bottom-radius"
	border-top:				symbol/make "border-top"
	border-top-color:		symbol/make "border-top-color"
	border-top-style:		symbol/make "border-top-style"
	border-top-width:		symbol/make "border-top-width"
	border-top-radius:		symbol/make "border-top-radius"
	border-left:			symbol/make "border-left"
	border-left-color:		symbol/make "border-left-color"
	border-left-style:		symbol/make "border-left-style"
	border-left-width:		symbol/make "border-left-width"
	border-right:			symbol/make "border-right"
	border-right-color:		symbol/make "border-right-color"
	border-right-style:		symbol/make "border-right-style"
	border-right-width:		symbol/make "border-right-width"

	padding:				symbol/make "padding"
	padding-left:			symbol/make "padding-left"
	padding-top:			symbol/make "padding-top"
	padding-right:			symbol/make "padding-right"
	padding-bottom:			symbol/make "padding-bottom"

	font: 					symbol/make "font"
	font-family:			symbol/make "font-family"
	font-size:				symbol/make "font-size"
	font-style:				symbol/make "font-style"
	font-weight:			symbol/make "font-weight"

	tab-size:				symbol/make "tab-size"
	text-align:				symbol/make "text-align"
	text-indent:			symbol/make "text-indent"
	text-overflow:			symbol/make "text-overflow"
	text-shadow:			symbol/make "text-shadow"
	text-transform:			symbol/make "text-transform"
	text-decoration:		symbol/make "text-decoration"
	text-decoration-color:	symbol/make "text-decoration-color"
	text-decoration-line:	symbol/make "text-decoration-line"
	text-decoration-style:	symbol/make "text-decoration-style"
	letter-spacing:			symbol/make "letter-spacing"
	line-height:			symbol/make "line-height"

	transform:				symbol/make "transform"
	transform-origin:		symbol/make "transform-origin"
	transform-style:		symbol/make "transform-style"

	transition:				symbol/make "transition"
	transition-delay:		symbol/make "transition-delay"
	transition-duration:	symbol/make "transition-duration"
	transition-property:	symbol/make "transition-property"
	transition-timing-function:	symbol/make "transition-timing-function"

	opacity:				symbol/make "opacity"
	shadow:					symbol/make "shadow"
	caret-color:			symbol/make "caret-color"
	text-color:				symbol/make "text-color"
	cursor:					symbol/make "cursor"
	direction:				symbol/make "direction"
	white-space:			symbol/make "white-space"
	word-break:				symbol/make "word-break"
	word-spacing:			symbol/make "word-spacing"
	word-wrap:				symbol/make "word-wrap"
	writing-mode:			symbol/make "writing-mode"

	blend-mode:				symbol/make "blend-mode"	;-- how a gob's content should blend with its direct parent background
	outline:				symbol/make "outline"

	;-- filter, usually for image
	drop-shadow:			symbol/make "drop-shadow"
	blur:					symbol/make "blur"
	grayscale:				symbol/make "grayscale"
	hue-rotate:				symbol/make "hue-rotate"
	brightness:				symbol/make "brightness"
	contrast:				symbol/make "contrast"
	saturate:				symbol/make "saturate"
	sepia:					symbol/make "sepia"

	solid:					symbol/make "solid"

	set-background: func [
		s		[gob-style!]
		val		[red-value!]
	][
		
	]

	set-border: func [
		s		[gob-style!]
		val		[red-value!]
		/local
			w	[red-word!]
			id	[integer!]
			int	[red-integer!]
			tp	[red-tuple!]
			blk [red-block!]
			ser [series!]
			end [red-value!]
	][
		switch TYPE_OF(val) [
			TYPE_INTEGER [
				int: as red-integer! val
				s/border/width: int/value
			]
			TYPE_WORD [		;-- border style
				w: as red-word! val
				id: symbol/resolve w/symbol
				case [
					id = solid [s/border/style: GOB_BORDER_SOLID]
					true [0]
				]
			]
			TYPE_TUPLE [
				tp: as red-tuple! val
				s/border/color: tp/array1
			]
			TYPE_BLOCK [
				blk: as red-block! val
				ser: GET_BUFFER(blk)
				val: ser/offset + blk/head
				end: ser/tail
				while [val < end][
					set-border s val
					val: val + 1
				]
			]
			TYPE_NONE [s/border/style: GOB_BORDER_NONE]
		]
	]

	set-shadow: func [
		s		[gob-style!]
		val		[red-value!]
		n		[int-ptr!]
		/local
			pt	[red-pair!]
			int	[red-integer!]
			tp	[red-tuple!]
			blk	[red-block!]
			ss	[gob-style-shadow!]
			new	[gob-style-shadow!]
			ser [series!]
			end [red-value!]
	][
		ss: s/shadow
		switch TYPE_OF(val) [
			TYPE_PAIR [
				n/value: 0
				new: as gob-style-shadow! alloc0 size? gob-style-shadow!
				new/next: ss
				s/shadow: new
				ss: new
				pt: as red-pair! val
				ss/offset/x: as float32! pt/x
				ss/offset/y: as float32! pt/y
			]
			TYPE_INTEGER [
				int: as red-integer! val
				either zero? n/value [ss/radius: int/value][ss/spread: int/value]
				n/value: n/value + 1
			]
			TYPE_TUPLE [
				tp: as red-tuple! val
				ss/color: tp/array1
			]
			TYPE_BLOCK [
				blk: as red-block! val
				ser: GET_BUFFER(blk)
				val: ser/offset + blk/head
				end: ser/tail
				if TYPE_OF(val) <> TYPE_PAIR [
					s/shadow: as gob-style-shadow! alloc0 size? gob-style-shadow!
				]
				while [val < end][
					set-shadow s val n
					val: val + 1
				]
			]
			TYPE_NONE [
				while [ss <> null][
					new: ss/next
					free as byte-ptr! ss
					ss: new
				]
				s/shadow: null
			]
		]
	]
]