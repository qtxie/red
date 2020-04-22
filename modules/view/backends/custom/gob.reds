Red/System [
	Title:	 "Graphic object datatype"
	Author:	 "Xie Qingtian"
	File: 	 %gob.reds
	Tabs:	 4
	Rights:	 "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

gob: context [
	verbose: 0

	box: func [
		val		[int-ptr!]
		return:	[red-gob!]
		/local
			h [red-gob!]
	][
		h: as red-gob! stack/arguments
		h/header: TYPE_GOB
		h/value: as gob! val
		h
	]

	make-in: func [
		parent 	[red-block!]
		val 	[gob!]
		return: [red-gob!]
		/local
			h	[red-gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/make-in"]]
		
		h: as red-gob! ALLOC_TAIL(parent)
		h/header: TYPE_GOB
		h/value: val
		h
	]

	make-at: func [
		slot	[red-value!]
		val		[gob!]
		return:	[red-gob!]
		/local
			h	[red-gob!]
	][
		h: as red-gob! slot
		h/header: TYPE_GOB
		h/value: val
		h
	]

	push: func [
		val		[gob!]
		return: [red-gob!]
		/local
			hndl [red-gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/push"]]
		
		hndl: as red-gob! stack/push*
		hndl/header: TYPE_GOB
		hndl/value: val
		hndl
	]

	get-type: func [
		gob		[gob!]
		return: [integer!]
	][
		switch GOB_TYPE(gob) [
			GOB_BASE	[base]
			GOB_WINDOW	[window]
			GOB_FIELD	[field]
			GOB_TEXTAREA [area]
		]
	]

	get-value: func [
		gob			[red-gob!]						;-- implicit type casting
		element		[red-value!]
		path		[red-value!]
		return:		[red-value!]
		/local
			g		[gob!]
			child	[int-ptr!]
			w		[red-word!]
			int		[red-integer!]
			str		[red-string!]
			len		[integer!]
			idx		[integer!]
			sym		[integer!]
			blk		[red-block!]
			ret		[red-value!]
	][
		g: gob/value
		ret: stack/push*
		ret/header: TYPE_NONE
		switch TYPE_OF(element) [
			TYPE_INTEGER [
				int: as red-integer! element
				idx: int/value
			]
			TYPE_WORD [
				w: as red-word! element
				sym: symbol/resolve w/symbol
				case [
					sym = facets/type [
						word/make-at get-type g ret
					]
					sym = facets/state	 [
						if rs-gob/set-flag? g GOB_FLAG_HOSTED [
							0
						]
					]
					sym = facets/parent [
						handle/make-at ret 0
					]
					sym = facets/text [
						if g/text <> null [
							str: as red-string! ret
							str/header: TYPE_STRING
							str/head: 0
							str/node: g/text
							str/cache: null
						]
					]
					sym = facets/offset [
						pair/make-at ret as-integer g/box/left as-integer g/box/top
					]
					sym = facets/color [0]
					sym = facets/pane [
						len: rs-gob/length? g
						blk: block/make-at as red-block! ret len
						child: rs-gob/head g
						loop len [
							make-in blk as gob! child/value
							child: child + 1
						]
					]
					all [
						sym = facets/actors
						g/actors <> null
					][
						ret: as red-value! g/actors
					]
					sym = facets/data [ret: as red-value! g/data]
					sym = words/face [ret: as red-value! :g/face]
					true [0]
				]
			]
			default [fire [TO_ERROR(script invalid-path) path element]]
		]
		stack/pop 1			;-- avoids moving stack up
		ret
	]

	set-styles: func [
		g			[gob!]
		styles-obj	[red-object!]
		/local
			s		[gob-style!]
			ctx		[red-context!]
			syms	[series!]
			values	[series!]
			sym		[red-value!]
			s-tail	[red-value!]
			value	[red-value!]
			tp		[red-tuple!]
			int		[red-integer!]
			str		[red-string!]
			w		[red-word!]
			id		[integer!]
			n		[integer!]
	][
		if null? g/styles [g/styles: as gob-style! alloc0 size? gob-style!]
		s: g/styles

		ctx: 	GET_CTX(styles-obj)
		syms:   as series! ctx/symbols/value
		values: as series! ctx/values/value

		sym:	syms/offset
		s-tail: syms/tail
		value: 	values/offset
		while [sym < s-tail][
			w: as red-word! sym
			id: symbol/resolve w/symbol
			with styles-ctx [
				case [
					id = background [set-background s value]
					id = border [set-border s value]
					id = border-radius [s/radius: get-float32 as red-integer! value]
					id = shadow [
						set-shadow s none-value null		;-- delete previous one
						n: 0 set-shadow s value :n
					]
					id = text-color [
						if TYPE_OF(value) = TYPE_TUPLE [
							tp: as red-tuple! value
							s/text/color: tp/array1
						]
					]
					id = font-style [
						set-font-style s value
					]
					id = font-family [
						if TYPE_OF(value) = TYPE_STRING [
							str: as red-string! value
							s/text/font-family: str/node
						]
					]
					id = font-size [
						if TYPE_OF(value) = TYPE_INTEGER [
							int: as red-integer! value
							s/text/font-size: int/value
						]
					]
					true [0]
				]
			]
			sym: sym + 1
			value: value + 1
		]
	]

	get-flags: func [
		field	[red-block!]
		return: [integer!]									;-- return a bit-array of all flags
		/local
			word  [red-word!]
			len	  [integer!]
			sym	  [integer!]
			flags [integer!]
	][
		switch TYPE_OF(field) [
			TYPE_BLOCK [
				word: as red-word! block/rs-head field
				len: block/rs-length? field
				if zero? len [return 0]
			]
			TYPE_WORD [
				word: as red-word! field
				len: 1
			]
			default [return 0]
		]
		flags: 0
		
		loop len [
			sym: symbol/resolve word/symbol
			case [
				sym = all-over	 [flags: flags or GOB_FLAG_ALL_OVER]
				sym = scrollable [0]
				sym = password	 [0]
				true			 [0]
			]
			word: word + 1
		]
		flags
	]

	set-facets: func [
		g			[gob!]
		word		[red-word!]
		value		[red-value!]
		return:		[logic!]			;-- error?
		/local
			sym		[integer!]
			pair	[red-pair!]
			int		[red-integer!]
			tp		[red-tuple!]
			blk		[red-block!]
			str		[red-string!]
			bool	[red-logic!]
			layer?	[logic!]
			prop	[anim-property!]
			w		[float32!]
			h		[float32!]
			redraw? [logic!]
	][
		redraw?: yes
		sym: symbol/resolve word/symbol
		prop: animation/check g value sym
		case [
			sym = facets/type	[
				word: as red-word! value
				sym: symbol/resolve word/symbol
				case [
					sym = window [sym: GOB_WINDOW]
					sym = field	 [sym: GOB_FIELD]
					sym = area	 [sym: GOB_TEXTAREA]
					true		 [sym: GOB_BASE]	
				]
				g/flags: g/flags or sym
				redraw?: no
			]
			sym = facets/offset [
				pair: as red-pair! value
				w: g/box/right - g/box/left
				h: g/box/bottom - g/box/top
				g/box/left: as float32! pair/x
				g/box/top: as float32! pair/y
				g/box/right: g/box/left + w
				g/box/bottom: g/box/top + h
				redraw?: no
			]
			sym = facets/size [
				pair: as red-pair! value
				g/box/right: g/box/left + as-float32 pair/x
				g/box/bottom: g/box/top + as-float32 pair/y
				if rs-gob/set-flag? g GOB_FLAG_LAYER [GOB_SET_FLAG(g GOB_FLAG_RESIZE)]
			]
			sym = facets/color [
				tp: as red-tuple! value
				g/backdrop: tp/array1
			]
			sym = facets/actors [
				if TYPE_OF(value) = TYPE_BLOCK [
					if null? g/actors [
						g/actors: as red-block! allocate size? red-block!
					]
					copy-cell value as cell! g/actors
				]
				redraw?: no
			]
			sym = facets/text [
				either TYPE_OF(value) = TYPE_STRING [
					str: as red-string! value
					g/text: str/node
				][
					g/text: null
				]
			]
			sym = facets/styles [
				if TYPE_OF(value) = TYPE_OBJECT [
					set-styles g as red-object! value
				]
			]
			sym = facets/draw [
				if TYPE_OF(value) = TYPE_BLOCK [
					blk: as red-block! value
					g/draw-head: blk/head
					g/draw: blk/node
				]
			]
			sym = styles-ctx/transition [
				if TYPE_OF(value) = TYPE_BLOCK [
					parse-transition g as red-block! value
				]
			]
			sym = facets/flags [g/flags: g/flags or get-flags as red-block! value]
			sym = facets/data [
				if null? g/data [g/data: as int-ptr! allocate size? red-value!]
				copy-cell value as cell! g/data
			]
			sym = facets/image [
				either TYPE_OF(value) = TYPE_IMAGE [
					blk: as red-block! value
					g/image: blk/node
				][g/image: null]
			]
			sym = styles-ctx/layer? [
				either TYPE_OF(value) = TYPE_LOGIC [
					bool: as red-logic! value
					layer?: bool/value
				][layer?: no]
				either layer? [GOB_SET_FLAG(g GOB_FLAG_LAYER)][
					GOB_UNSET_FLAG(g GOB_FLAG_LAYER)
				]
			]
			;sym = facets/opacity [
			;	int: as red-integer! value
			;	g/opacity: int/value
			;]
			true [return true]
		]
		if all [redraw? rs-gob/set-flag? g GOB_FLAG_LAYER][
			GOB_SET_FLAG(g GOB_FLAG_UPDATE)
		]
		if prop <> null [animation/set-property g prop sym yes]
		false
	]

	set-value: func [
		gob			[red-gob!]						;-- implicit type casting
		element		[red-value!]
		value		[red-value!]
		path		[red-value!]
		return:		[red-value!]
		/local
			g		[gob!]
			word	[red-word!]
			int		[red-integer!]
			idx		[integer!]
			sym		[integer!]
			error?	[logic!]
	][
		error?: no
		g: gob/value

		switch TYPE_OF(element) [
			TYPE_INTEGER [
				int: as red-integer! element
				idx: int/value
			]
			TYPE_WORD [
				error?: set-facets g as red-word! element value
			]
			default [error?: yes]
		]
		rs-gob/update-content-box g
		ui-manager/redraw
		if all [path <> null error?][fire [TO_ERROR(script invalid-path) path element]]
		value
	]

	serialize: func [
		gob		[red-gob!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		indent?	[logic!]
		tabs	[integer!]
		mold?	[logic!]
		return: [integer!]
		/local
			s-tail	[red-value!]
			value	[red-value!]
			w		[red-word!]
			idx		[integer!]
			blank	[byte!]
			g		[gob!]
			t-list	[int-ptr!]
			pt		[red-pair! value]
			str		[c-string!]
			len		[integer!]
	][
		;-- This will crash, a bug in R/S
		;t-list: ["base" 4 "window" 6 "button" 6 "label" 5 "field" 5 "area" 4]

		either flat? [
			indent?: no
			blank: space
		][
			if mold? [
				string/append-char GET_BUFFER(buffer) as-integer lf
				part: part - 1
			]
			blank: lf
		]

		;-- type
		if indent? [part: object/do-indent buffer tabs part]
		string/concatenate-literal buffer "type: "
		part: part - 6

		g: gob/value
		switch GOB_TYPE(g) [
			GOB_BASE	[str: "base" len: 4]
			GOB_WINDOW	[str: "window" len: 6]
			GOB_FIELD	[str: "field" len: 5]
			GOB_TEXTAREA [str: "area" len: 4]
			default	[str: "ALIEN" len: 5]
		]
		string/concatenate-literal buffer str
		part: part - len
		;idx: GOB_TYPE(g) * 2 + 1
		;string/concatenate-literal buffer as c-string! t-list/idx
		;idx: idx + 1
		;part: part - t-list/idx
		if indent? [
			string/append-char GET_BUFFER(buffer) as-integer blank
			part: object/do-indent buffer tabs part - 1
		]

		;-- offset
		string/concatenate-literal buffer "offset: "
		part: part - 8
		pt/x: as-integer g/box/left
		pt/y: as-integer g/box/top
		part: pair/form :pt buffer null part
		if indent? [
			string/append-char GET_BUFFER(buffer) as-integer blank
			part: object/do-indent buffer tabs part - 1
		]

		;-- size
		string/concatenate-literal buffer "size: "
		part: part - 6
		pt/x: as-integer g/box/right - g/box/left
		pt/y: as-integer g/box/bottom - g/box/top
		part: pair/form :pt buffer null part
		if indent? [
			string/append-char GET_BUFFER(buffer) as-integer blank
			part: part - 1
		]
		part
	]

	rs-make: func [
		spec		[red-block!]
		return:		[gob!]
		/local
			g		[gob!]
			val		[red-value!]
			end		[red-value!]
			w		[red-value!]
			n		[integer!]
			saved	[integer!]
	][
		g: as gob! alloc0 size? gob!

		val: block/rs-head spec
		end: block/rs-tail spec

		w: val
		saved: spec/head
		spec/head: saved + 1
		while [w < end][
			n: interpreter/eval-single as red-value! spec
			set-facets g as red-word! w stack/arguments
			w: val + n
			spec/head: n + 1
		]
		spec/head: saved
		rs-gob/update-content-box g
		g
	]

	;-- Actions --

	make: func [
		proto	[red-gob!]
		spec	[red-value!]
		type	[integer!]
		return:	[red-gob!]  
	][
		proto/value: rs-make as red-block! spec
		proto/header: type
		proto
	]

	form: func [
		gob		[red-gob!]
		buffer	[red-string!]
		arg		[red-value!]
		part	[integer!]
		return:	[integer!]
		/local
			formed [c-string!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/form"]]
		
		serialize gob buffer no no no arg part no 0 no
	]
	
	mold: func [
		gob		[red-gob!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part 	[integer!]
		indent	[integer!]
		return: [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/mold"]]

		string/concatenate-literal buffer "make gob! ["
		part: serialize gob buffer no all? flat? arg part - 11 yes indent + 1 yes
		if indent > 0 [part: object/do-indent buffer indent part]
		string/append-char GET_BUFFER(buffer) as-integer #"]"
		part - 1
	]

	eval-path: func [
		gob			[red-gob!]						;-- implicit type casting
		element		[red-value!]
		value		[red-value!]
		path		[red-value!]
		case?		[logic!]
		return:		[red-value!]
	][
		either value <> null [
			set-value gob element value path
		][
			get-value gob element path
		]
	]

	compare: func [
		value1	[red-gob!]							;-- first operand
		value2	[red-gob!]							;-- second operand
		op		[integer!]							;-- type of comparison
		return:	[integer!]
		/local
			left  [integer!]
			right [integer!] 
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/compare"]]

		if TYPE_OF(value2) <> TYPE_GOB [return 1]
		SIGN_COMPARE_RESULT(value1/value value2/value)
	]

	clear: func [
		gob		[red-gob!]
		return:	[red-value!]
		/local
			s	 [series!]
			size [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/clear"]]

		;ownership/check as red-value! ser words/_clear null ser/head size
		rs-gob/clear gob/value
		;ownership/check as red-value! ser words/_cleared null ser/head 0
		as red-value! gob
	]

	copy: func [
		obj      [red-gob!]
		new	  	 [red-gob!]
		part-arg [red-value!]
		deep?	 [logic!]
		types	 [red-value!]
		return:	 [red-gob!]
		/local
			ctx	  [red-context!]
			nctx  [red-context!]
			value [red-value!]
			tail  [red-value!]
			src	  [series!]
			dst	  [series!]
			node  [node!]
			size  [integer!]
			slots [integer!]
			type  [integer!]
			sym	  [red-word!]
			w-ctx [node!]
			g	  [gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/copy"]]
		
		if OPTION?(types) [--NOT_IMPLEMENTED--]

		if OPTION?(part-arg) [
			ERR_INVALID_REFINEMENT_ARG(refinements/_part part-arg)
		]

		new/header: TYPE_UNSET
		g: rs-gob/copy obj/value
		new/value: g
		new/header: TYPE_GOB

		if g/anim <> null [animation/add as animation! g/anim]
		new
	]

	insert: func [
		gob		  [red-gob!]
		val		  [red-gob!]
		part-arg  [red-value!]
		only?	  [logic!]
		dup-arg	  [red-value!]
		append?	  [logic!]
		return:	  [red-value!]
	][
		rs-gob/insert gob/value val/value append?
		as red-value! gob
	]

	length?: func [
		gob		[red-gob!]
		return: [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/length?"]]
		rs-gob/length? gob/value
	]

	put: func [
		gob		[red-gob!]
		field	[red-value!]
		value	[red-value!]
		case?	[logic!]
		return:	[red-value!]
		/local
			slot  [red-value!]
			s	  [series!]
			hash? [logic!]
			hash  [red-hash!]
			put?  [logic!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/put"]]

		set-value gob field value null
		value
	]

	init: does [
		datatype/register [
			TYPE_GOB
			TYPE_INTEGER
			"GOB!"
			;-- General actions --
			:make
			null			;random
			null			;reflect
			null			;to
			:form
			:mold
			:eval-path
			null			;set-path
			:compare
			;-- Scalar actions --
			null			;absolute
			null			;add
			null			;divide
			null			;multiply
			null			;negate
			null			;power
			null			;remainder
			null			;round
			null			;subtract
			null			;even?
			null			;odd?
			;-- Bitwise actions --
			null			;and~
			null			;complement
			null			;or~
			null			;xor~
			;-- Series actions --
			null			;append
			null			;at
			null			;back
			null			;change
			:clear
			:copy
			null			;find
			null			;head
			null			;head?
			null			;index?
			:insert
			:length?
			null			;move
			null			;next
			null			;pick
			null			;poke
			:put
			null			;remove
			null			;reverse
			null			;select
			null			;sort
			null			;skip
			null			;swap
			null			;tail
			null			;tail?
			null			;take
			null			;trim
			;-- I/O actions --
			null			;create
			null			;close
			null			;delete
			null			;modify
			null			;open
			null			;open?
			null			;query
			null			;read
			null			;rename
			null			;update
			null			;write
		]
	]
]