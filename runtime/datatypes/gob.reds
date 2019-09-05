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

	sym-state:	-1
	sym-parent:	-1
	sym-pane:	-1
	sym-text:	-1
	sym-color:	-1
	sym-data:	-1
	sym-style:	-1
	sym-font:	-1

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
		val		[int-ptr!]
		return: [red-gob!]
		/local
			hndl [red-gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/push"]]
		
		hndl: as red-gob! stack/push*
		hndl/header: TYPE_GOB
		hndl/value: as gob! val
		hndl
	]

	get-type: func [
		gob		[gob!]
		return: [integer!]
	][
		switch GOB_TYPE(gob) [
			GOB_BASE	[base]
			GOB_WINDOW	[window]
			GOB_BUTTON	[button]
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
			len		[integer!]
			idx		[integer!]
			sym		[integer!]
			blk		[red-block!]
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
				w: as red-word! element
				sym: symbol/resolve w/symbol
				case [
					sym = gui/facets/type [
						word/make-at get-type g element
					]
					sym = sym-state	 [
						either rs-gob/set-flag? g GOB_FLAG_HOSTED [
							handle/make-at element as-integer gob/host
						][element/header: TYPE_NONE]
					]
					sym = sym-parent [
						handle/make-at element as-integer rs-gob/get-parent g
					]
					sym = sym-text [0]
					sym = sym-color [0]
					sym = sym-pane [
						len: rs-gob/length? g
						blk: block/make-at as red-block! element len
						child: rs-gob/head g
						loop len [
							make-in blk as gob! child/value
							child: child + 1
						]
					]
					true [error?: yes]
				]
			]
			default [error?: yes]
		]
		if error? [fire [TO_ERROR(script invalid-path) path element]]
		element
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
				word: as red-word! element
				sym: symbol/resolve word/symbol
				case [
					sym = sym-state	 [0]
					sym = sym-parent [0]
					sym = sym-text [0]
					sym = sym-color [0]
					sym = sym-pane [0]
					true [error?: yes]
				]
			]
			default [error?: yes]
		]
		if error? [fire [TO_ERROR(script invalid-path) path element]]
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
	][
		t-list: ["base" 4 "window" 6 "button" 6 "label" 5 "field" 5 "area" 4]

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
		idx: GOB_TYPE(g) * 2 + 1
		string/concatenate-literal buffer as c-string! t-list/idx
		idx: idx + 1
		part: part - t-list/idx
		if indent? [
			string/append-char GET_BUFFER(buffer) as-integer blank
			part: part - 1
		]

		;-- offset
		string/concatenate-literal buffer "offset: "
		part: part - 8
		pt/x: g/box/x1
		pt/y: g/box/y1
		part: pair/form :pt buffer null part
		if indent? [
			string/append-char GET_BUFFER(buffer) as-integer blank
			part: part - 1
		]

		;-- size
		string/concatenate-literal buffer "size: "
		part: part - 6
		pt/x: g/box/x2 - g/box/x1
		pt/y: g/box/y2 - g/box/y1
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
			w		[red-word!]
			val		[red-value!]
			end		[red-value!]
			pair	[red-pair!]
			int		[red-integer!]
			tp		[red-tuple!]
			type	[integer!]
			sym		[integer!]
	][
		g: as gob! alloc0 size? gob!

		val: block/rs-head spec
		end: block/rs-tail spec

		while [val < end][
			w: as red-word! val
			sym: symbol/resolve w/symbol
			w: w + 1
			type: case [
				sym = facets/type	[
					sym: symbol/resolve w/symbol
					case [
						sym = window [type: GOB_WINDOW]
						sym = button [type: GOB_BUTTON]
						true		 [type: GOB_BASE]	
					]
				]
				sym = facets/offset [
					pair: as red-pair! w
					g/box/x1: pair/x
					g/box/y1: pair/y
					g/box/x2: g/box/x1 + g/box/x2
					g/box/y2: g/box/y1 + g/box/y2
				]
				sym = facets/size [
					pair: as red-pair! w
					g/box/x2: g/box/x1 + pair/x
					g/box/y2: g/box/y1 + pair/y
				]
				sym = facets/color [
					tp: as red-tuple! w
					g/bg-color: tp/array1
				]
				sym = facets/opacity [
					int: as red-integer! w
					g/opacity: int/value
				]
				true					[
					;fire [TO_ERROR(script bad-make-arg) proto spec]
					0
				]
			]
			val: val + 2
		]
		g
	]

	;-- Actions --

	make: func [
		proto	[red-gob!]
		spec	[red-value!]
		type	[integer!]
		return:	[red-gob!]  
	][
		proto/header: type
		proto/host: null
		proto/value: rs-make as red-block! spec
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
			null			;clear
			null			;copy
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
			null			;put
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

		sym-state:	symbol/make "state"
		sym-parent:	symbol/make "parent"
		sym-pane:	symbol/make "pane"
		sym-text:	symbol/make "text"
		sym-color:	symbol/make "color"
		sym-data:	symbol/make "data"
		sym-style:	symbol/make "style"
		sym-font:	symbol/make "font"
	]
]