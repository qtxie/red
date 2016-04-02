Red/System [
	Title:   "Bignum! datatype runtime functions"
	Author:  "bitbegin"
	File: 	 %bignum.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2015 Nenad Rakocevic & Qingtian Xie & bitbegin. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

bignum: context [
	verbose: 1

	ciL:				4				;-- bignum! unit is 4 bytes; chars in limb
	biL:				ciL << 3		;-- bits in limb
	biLH:				ciL << 2		;-- half bits in limb
	BN_MAX_LIMB:		1024			;-- support 1024 * 32 bits

	#define MULADDC_INIT [
		s0: 0
		s1: 0
		b0: 0
		b1: 0
		r0: 0
		r1: 0
		rx: 0
		ry: 0
		b0: (b << biLH) >>> biLH
		b1: b >>> biLH
	]
	#define MULADDC_CORE [
		s0: (s/1 << biLH) >>> biLH
		s1: s/1 >>> biLH		s: s + 1
		rx: s0 * b1 			r0: s0 * b0
		ry: s1 * b0 			r1: s1 * b1
		r1: r1 + (rx >>> biLH)
		r1: r1 + (ry >>> biLH)
		rx: rx << biLH 			ry: ry << biLH
		r0: r0 + rx 			r1: r1 + as integer! (uint-less r0 rx)
		r0: r0 + ry 			r1: r1 + as integer! (uint-less r0 ry)
		r0: r0 + c 				r1: r1 + as integer! (uint-less r0 c)
		r0: r0 + d/1			r1: r1 + as integer! (uint-less r0 d/1)
		c: r1					d/1: r0		d: d + 1
	]
	#define MULADDC_STOP []
	
	push: func [
		big [red-bignum!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/push"]]

		copy-cell as red-value! big stack/push*
	]

	serialize: func [
		big			[red-bignum!]
		buffer		[red-string!]
		only?		[logic!]
		all?		[logic!]
		flat?		[logic!]
		arg			[red-value!]
		part		[integer!]
		mold?		[logic!]
		return: 	[integer!]
		/local
			s		[series!]
			bytes	[integer!]
			p		[byte-ptr!]
			size	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/serialize"]]

		s: GET_BUFFER(big)
		p: as byte-ptr! s/offset
		either big/used = 0 [
			size: 1
		][
			size: big/used * 4
		]
		p: p + size

		bytes: 0
		if size > 30 [
			string/append-char GET_BUFFER(buffer) as-integer lf
			part: part - 1
		]

		if big/sign = -1 [
			string/append-char GET_BUFFER(buffer) as-integer #"-"
			bytes: bytes + 1
		]

		part: part - 2
		loop size [
			p: p - 1
			string/concatenate-literal buffer string/byte-to-hex as-integer p/value
			bytes: bytes + 1
			if bytes % 32 = 0 [
				string/append-char GET_BUFFER(buffer) as-integer lf
				part: part - 1
			]
			part: part - 2
			if all [OPTION?(arg) part <= 0][return part]
		]
		if all [size > 30 bytes % 32 <> 0] [
			string/append-char GET_BUFFER(buffer) as-integer lf
			part: part - 1
		]
		part - 1
	]

	do-math: func [
		type		[math-op!]
		return:		[red-value!]
		/local
			left	[red-bignum!]
			right	[red-bignum!]
			big		[red-bignum!]
			int		[red-integer!]
	][
		left: as red-bignum! stack/arguments
		right: left + 1

		assert any [
			TYPE_OF(left) = TYPE_BIGNUM
		]
		assert any [
			TYPE_OF(right) = TYPE_INTEGER
			TYPE_OF(right) = TYPE_BIGNUM
		]

		switch TYPE_OF(right) [
			TYPE_INTEGER [
				switch type [
					OP_ADD [
						int: as red-integer! right
						big: add-int left int/value
					]
					OP_SUB [
						int: as red-integer! right
						big: sub-int left int/value
					]
				]
			]
			TYPE_BIGNUM [
				switch type [
					OP_ADD [
						big: add left right
					]
					OP_SUB [
						big: sub left right
					]
					OP_MUL [
						big: mul left right
					]
				]
			]
		]
		SET_RETURN(big)
	]

	make-at: func [
		slot		[red-value!]
		len 		[integer!]
		return:		[red-bignum!]
		/local
			big		[red-bignum!]
			s		[series!]
			p4		[int-ptr!]
	][
		if len = 0 [len: 1]

		;-- make bignum!
		big: as red-bignum! slot
		big/header: TYPE_BIGNUM
		big/node:	alloc-series len 4 0
		big/sign:	1
		big/used:	1

		;-- init to zero
		s: GET_BUFFER(big)
		p4: as int-ptr! s/offset
		loop len [
			p4/1: 0
			p4: p4 + 1
		]
		big
	]

	copy: func [
		src	 		[red-bignum!]
		return:	 	[red-bignum!]
		/local
			big		[red-bignum!]
			s1	 	[series!]
			s2	 	[series!]
			p1		[byte-ptr!]
			p2		[byte-ptr!]
			size	[integer!]
	][
		s1: GET_BUFFER(src)
		p1: as byte-ptr! s1/offset
		size: src/used * 4

		big: make-at stack/push* size
		s2: GET_BUFFER(big)
		p2: as byte-ptr! s2/offset

		big/sign: src/sign
		big/used: src/used
		if size > 0 [
			copy-memory p2 p1 size
		]
		big
	]

	grow: func [
		big			[red-bignum!]
		len			[integer!]
		/local
			s	 	[series!]
			p		[int-ptr!]
			ex_len	[integer!]
	][
		if len > BN_MAX_LIMB [--NOT_IMPLEMENTED--]
		if len = 0 [exit]

		s: GET_BUFFER(big)
		ex_len: (len * 4) - s/size
		if ex_len > 0 [
			s: expand-series s ex_len

			;-- set to zero
			p: as int-ptr! s/offset + big/used
			loop ex_len [
				p/1: 0
				p: p + 1
			]
			big/used: len
		]
	]

	clamp: func [
		big			[red-bignum!]
		/local
			s	 	[series!]
			p		[int-ptr!]
			len		[integer!]
	][
		s: GET_BUFFER(big)
		len: big/used
		p: as int-ptr! s/offset
		p: p + len
		loop len [
			p: p - 1
			if p/1 = 0 [
				len: len - 1
			]
		]
		big/used: len
		big
	]
	
	uint-less: func [
		u1			[integer!]
		u2			[integer!]
		return:		[logic!]
		/local
			p1		[byte-ptr!]
			p2		[byte-ptr!]
	][
		p1: as byte-ptr! :u1
		p2: as byte-ptr! :u2

		if p1/4 < p2/4 [return true]
		if p1/4 > p2/4 [return false]
		if p1/3 < p2/3 [return true]
		if p1/3 > p2/3 [return false]
		if p1/2 < p2/2 [return true]
		if p1/2 > p2/2 [return false]
		if p1/1 < p2/1 [return true]
		if p1/1 > p2/1 [return false]
		return false
	]

	absolute-add: func [
		big1	 	[red-bignum!]
		big2		[red-bignum!]
		return:	 	[red-bignum!]
		/local
			s	 	[series!]
			s1	 	[series!]
			s2	 	[series!]
			p		[int-ptr!]
			p2		[int-ptr!]
			len		[integer!]
			big	 	[red-bignum!]
			c		[integer!]
			tmp		[integer!]
	][
		s1: GET_BUFFER(big1)
		s2: GET_BUFFER(big2)
		p2: as int-ptr! s2/offset

		len: either big1/used > big2/used [
			big1/used
		][
			big2/used
		]
		
		big: copy big1
		big/sign: 1
		grow big s2/size
		s: GET_BUFFER(big)
		p: as int-ptr! s/offset

		c: 0
		loop len [
			tmp: p2/1
			p/1: p/1 + c
			c: as integer! (uint-less p/1  c)
			p/1: p/1 + tmp
			c: c + as integer! (uint-less p/1 tmp)
			p: p + 1
			p2: p2 + 1
		]

		while [c > 0][
			if len >= s/size [
				grow big len + 1
				s: GET_BUFFER(big)
				p: as int-ptr! s/offset
				p: p + len
			]
			p/1: p/1 + c
			c: as integer! (uint-less p/1 c)
			len: len + 1
			p: p + 1
		]
		big/used: len
		big
	]

	;-- big1 must large than big2
	absolute-sub: func [
		big1	 	[red-bignum!]
		big2		[red-bignum!]
		return:	 	[red-bignum!]
		/local
			s	 	[series!]
			s1	 	[series!]
			s2	 	[series!]
			p		[int-ptr!]
			p2		[int-ptr!]
			len		[integer!]
			big	 	[red-bignum!]
			c		[integer!]
			z		[integer!]
	][
		s1: GET_BUFFER(big1)
		s2: GET_BUFFER(big2)
		p2: as int-ptr! s2/offset
		len: big2/used

		if big1/used < big2/used [--NOT_IMPLEMENTED--]

		big: copy big1
		big/sign: 1
		s: GET_BUFFER(big)
		p: as int-ptr! s/offset

		c: 0
		z: 0
		loop len [
			z: as integer! (uint-less p/1 c)
			p/1: p/1 - c
			c: as integer! (uint-less p/1 p2/1)
			c: c + z
			p/1: p/1 - p2/1
			p: p + 1
			p2: p2 + 1
		]

		while [c > 0][
			z: as integer! (uint-less p/1 c)
			p/1: p/1 - c
			c: z
			p: p + 1
			p2: p2 + 1
		]
		
		clamp big
		big
	]

	absolute-compare: func [
		big1	 	[red-bignum!]
		big2	 	[red-bignum!]
		return:	 	[integer!]
		/local
			s1	 	[series!]
			s2	 	[series!]
			p1		[int-ptr!]
			p2		[int-ptr!]
	][
		s1: GET_BUFFER(big1)
		s2: GET_BUFFER(big2)

		if all [
			big1/used = 0
			big2/used = 0
		][
			return 0
		]

		if big1/used > big2/used [return 1]
		if big2/used > big1/used [return -1]

		p1: as int-ptr! s1/offset
		p1: p1 + big1/used
		p2: as int-ptr! s2/offset
		p2: p2 + big2/used
		loop big1/used [
			p1: p1 - 1
			p2: p2 - 1
			if p1/1 > p2/1 [return 1]
			if p1/1 < p2/1 [return -1]
		]
		return 0
	]

	add: func [
		big1	 	[red-bignum!]
		big2		[red-bignum!]
		return:	 	[red-bignum!]
		/local
			big	 	[red-bignum!]
	][
		either big1/sign <> big2/sign [
			either (absolute-compare big1 big2) >= 0 [
				big: absolute-sub big1 big2
				big/sign: big1/sign
			][
				big: absolute-sub big2 big1
				big/sign: big2/sign
			]
		][
			big: absolute-add big1 big2
			big/sign: big1/sign
		]
		big
	]

	sub: func [
		big1	 	[red-bignum!]
		big2		[red-bignum!]
		return:	 	[red-bignum!]
		/local
			big	 	[red-bignum!]
	][
		either big1/sign = big2/sign [
			either (absolute-compare big1 big2) >= 0 [
				big: absolute-sub big1 big2
				big/sign: big1/sign
			][
				big: absolute-sub big2 big1
				big/sign: 0 - big1/sign
			]
		][
			big: absolute-add big1 big2
			big/sign: big1/sign
		]
		big
	]

	add-int: func [
		big1	 	[red-bignum!]
		int			[integer!]
		return:	 	[red-bignum!]
		/local
			big	 	[red-bignum!]
			s	 	[series!]
			p		[int-ptr!]
	][
		big: make-at stack/push* 1
		big/used: 1
		s: GET_BUFFER(big)
		p: as int-ptr! s/offset
		p/1: either int > 0 [
			big/sign: 1
			int
		][
			big/sign: -1
			0 - int
		]
		add big1 big
	]
	
	sub-int: func [
		big1	 	[red-bignum!]
		int			[integer!]
		return:	 	[red-bignum!]
		/local
			big	 	[red-bignum!]
			s	 	[series!]
			p		[int-ptr!]
	][
		big: make-at stack/push* 1
		big/used: 1
		s: GET_BUFFER(big)
		p: as int-ptr! s/offset
		p/1: either int > 0 [
			big/sign: -1
			int
		][
			big/sign: 1
			0 - int
		]
		add big1 big
	]
	
	mul-hlp: func [
		i			[integer!]
		s	 		[int-ptr!]
		d	 		[int-ptr!]
		b			[integer!]
		/local
			c		[integer!]
			t		[integer!]
			s0		[integer!]
			s1		[integer!]
			b0		[integer!]
			b1		[integer!]
			r0		[integer!]
			r1		[integer!]
			rx		[integer!]
			ry		[integer!]			
	][
		c: 0
		t: 0
		
		while [i >= 16][
			MULADDC_INIT
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE

	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_CORE   MULADDC_CORE
	        MULADDC_STOP			
			i: i - 16
		]
		
		while [i >= 8][
			MULADDC_INIT
			MULADDC_CORE   MULADDC_CORE
			MULADDC_CORE   MULADDC_CORE

			MULADDC_CORE   MULADDC_CORE
			MULADDC_CORE   MULADDC_CORE
			MULADDC_STOP
			i: i - 8
		]
		
		while [i > 0][
			MULADDC_INIT
			MULADDC_CORE
			MULADDC_STOP
			i: i - 1
		]
		
		t: t + 1
		
		until [
			d/1: d/1 + c
			c: as integer! (uint-less d/1  c)
			d: d + 1
			c = 0
		]
	]
	
	lset: func [
		big			[red-bignum!]
		int			[integer!]
		/local
			s	 	[series!]
			p		[byte-ptr!]
			p4		[int-ptr!]
	][
		grow big (big/used + 1)
		s: GET_BUFFER(big)
		p: as byte-ptr! s/offset
		p4: as int-ptr! s/offset
		set-memory p #"^@" s/size
		
		either int > 0 [
			p4/1: int
			big/sign: 1
		][
			p4/1: 0 - int
			big/sign: -1			
		]
		big/used: 1
	]
	
	mul: func [
		big1		[red-bignum!]
		big2		[red-bignum!]
		return:		[red-bignum!]
		/local
			big		[red-bignum!]
			s	 	[series!]
			s1	 	[series!]
			s2	 	[series!]
			p		[int-ptr!]
			p1		[int-ptr!]
			p2		[int-ptr!]
			len1	[integer!]
			len2	[integer!]
			pt		[int-ptr!]
			len		[integer!]
	][
		s1: GET_BUFFER(big1)
		s2: GET_BUFFER(big2)
		p1: as int-ptr! s1/offset
		p2: as int-ptr! s2/offset
		len1: big1/used
		len2: big2/used
		
		len: len1 + len2 + 1
		big: make-at stack/push* len
		big/used: len
		s: GET_BUFFER(big)
		p: as int-ptr! s/offset
		
		len1: len1 + 1
		while [len2 > 0]
		[
			pt: p2 + len2 - 1
			mul-hlp (len1 - 1) p1 (p + len2 - 1) pt/1
			len2: len2 - 1
		]
		
		big/sign: big1/sign * big2/sign
		clamp big
		big
	]
	
	compare: func [
		big1	 	[red-bignum!]
		big2	 	[red-bignum!]
		return:	 	[integer!]
	][
		if all [
			big1/sign = 1
			big2/sign = -1
		][
			return 1
		]

		if all [
			big2/sign = 1
			big1/sign = -1
		][
			return -1
		]

		either big1/sign = 1 [
			return absolute-compare big1 big2
		][
			return absolute-compare big2 big1
		]
	]

	;--- Actions ---

	make: func [
		proto	 	[red-value!]
		spec	 	[red-value!]
		return:	 	[red-bignum!]
		/local
			int	 	[red-integer!]
			bin	 	[red-binary!]
			big	 	[red-bignum!]
			s	 	[series!]
			sbin	[series!]
			p		[int-ptr!]
			pbig	[byte-ptr!]
			head	[byte-ptr!]
			tail	[byte-ptr!]
			len		[integer!]
			size	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/make"]]

		switch TYPE_OF(spec) [
			TYPE_INTEGER [
				int: as red-integer! spec
				big: make-at stack/push* 1
				big/used: 1
				s: GET_BUFFER(big)
				p: as int-ptr! s/offset
				p/1: either int/value > 0 [
					big/sign: 1
					int/value
				][
					big/sign: -1
					0 - int/value
				]
			]
			TYPE_BINARY [
				bin: as red-binary! spec
				sbin: GET_BUFFER(bin)
				head: (as byte-ptr! sbin/offset) + bin/head
				tail: as byte-ptr! sbin/tail
				size: as-integer tail - head
				either size = 0 [
					big: make-at stack/push* 1
					big/used: 1
					s: GET_BUFFER(big)
					p: as int-ptr! s/offset
					p/1: 0
				][
					len: size / 4
					if size % 4 <> 0 [
						len: len + 1
					]
					print-line size
					big: make-at stack/push* len
					s: GET_BUFFER(big)
					pbig: as byte-ptr! s/offset
					big/used: len
					loop size [
						tail: tail - 1
						pbig/1: tail/1
						pbig: pbig + 1
					]
					
					clamp big
				]
			]
			default [--NOT_IMPLEMENTED--]
		]

		big
	]
	
	form: func [
		big		[red-bignum!]
		buffer	[red-string!]
		arg		[red-value!]
		part 	[integer!]
		return: [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/form"]]
		
		serialize big buffer no no no arg part no
	]
	
	mold: func [
		big		[red-bignum!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part	[integer!]
		indent	[integer!]
		return:	[integer!]
		/local
			formed [c-string!]
			s	   [series!]
			unit   [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/mold"]]

		serialize big buffer only? all? flat? arg part yes
	]

	compare*: func [
		value1    [red-bignum!]						;-- first operand
		value2    [red-bignum!]						;-- second operand
		op	      [integer!]						;-- type of comparison
		return:   [integer!]
		/local
			res	  [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/compare"]]

		if all [
			op = COMP_STRICT_EQUAL
			TYPE_OF(value1) <> TYPE_OF(value2)
		][return 1]

		switch op [
			COMP_EQUAL		[res: compare value1 value2]
			COMP_NOT_EQUAL 	[res: not compare value1 value2]
			default [
				res: SIGN_COMPARE_RESULT(value1 value2)
			]
		]
		res
	]

	absolute: func [
		return:		[red-bignum!]
		/local
			big		[red-bignum!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/absolute"]]

		big: as red-bignum! stack/arguments
		big/sign: 1
		big 											;-- re-use argument slot for return value
	]

	add*: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "bignum/add"]]

		do-math OP_ADD
	]
	
	multiply: func [return:	[red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "bignum/multiply"]]
		as red-value! do-math OP_MUL
	]
	
	subtract: func [return: [red-value!]][
		#if debug? = yes [if verbose > 0 [print-line "bignum/add"]]

		do-math OP_SUB
	]

	negate: func [
		big		[red-bignum!]
		return:	[red-value!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/complement"]]

		either big/sign = 1 [
			big/sign: -1
		][
			big/sign: 1
		]
		as red-value! big
	]

	swap: func [
		big1	 	[red-bignum!]
		big2	 	[red-bignum!]
		return:	 	[red-bignum!]
		/local
			node 	[node!]
			sign 	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "bignum/swap"]]

		node: big1/node
		sign: big1/sign
		big1/node: big2/node
		big1/sign: big2/sign
		big2/node: node
		big2/sign: sign
		big1
	]

	init: does [
		datatype/register [
			TYPE_BIGNUM
			TYPE_VALUE
			"bignum!"
			;-- General actions --
			:make
			null			;random
			null			;reflect
			null			;to
			:form
			:mold
			null			;eval-path
			null			;set-path
			:compare*
			;-- Scalar actions --
			:absolute
			:add*
			null			;divide
			:multiply
			:negate
			null			;power
			null			;remainder
			null			;round
			:subtract
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
			null			;insert
			null			;length?
			null			;next
			null			;pick
			null			;poke
			null			;put
			null			;remove
			null			;reverse
			null			;select
			null			;sort
			null			;skip
			:swap
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
