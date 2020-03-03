Red/System [
	Title:   "Symbol! datatype runtime functions"
	Author:  "Nenad Rakocevic"
	File: 	 %symbol.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

symbol: context [
	verbose: 0
	table: as node! 0
	
	is-any-type?: func [
		word	[red-word!]
		return: [logic!]
	][
		assert TYPE_OF(word) = TYPE_WORD
		(resolve word/symbol) = resolve words/any-type!
	]
	
	search: func [
		str			 [red-slice!]
		return:		 [integer!]
		/local
			s		 [series!]
			id		 [integer!]
			aliased? [logic!]
			key		 [red-value!]
	][
		aliased?: no

		key: _hashtable/get table as red-value! str 0 1 COMP_STRICT_EQUAL no no
		if key = null [
			key: _hashtable/get table as red-value! str 0 1 COMP_EQUAL no no	
			aliased?: yes
		]

		id: either key = null [0][
			s: GET_BUFFER(symbols)
			(as-integer key - s/offset) >> 4 + 1
		]
		if aliased? [id: 0 - id]
		id
	]
	
	internalize: func [
		src		 [c-string!]
		return:  [node!]
		/local
			node [node!]
			dst  [c-string!]
			s	 [series!]
			len	 [integer!]
	][
		len: 1 + length? src
		node: alloc-bytes len 							;@@ TBD: mark this buffer as protected!
		s: as series! node/value
		dst: as c-string! s/offset
		
		copy-memory as byte-ptr! dst as byte-ptr! src len
		node
	]

	make-alt: func [
		str 	[red-string!]
		len		[integer!]		;-- -1: use the whole string
		return:	[integer!]
		/local
			sym	[red-symbol!]
			id	[integer!]
			val [red-slice! value]
	][
		#if debug? = yes [if verbose > 0 [print-line "symbol/make-alt"]]

		;-- make a slice, then search in the hashtable
		val/header: TYPE_SLICE
		val/head:	str/head
		val/node:	str/node
		val/length: len
		id: search val

		if positive? id [return id]

		sym: as red-symbol! ALLOC_TAIL(symbols)
		sym/header: TYPE_UNSET
		either len < 0 [
			sym/node: str/node
		][
			sym/node: copy-part str/node str/head len
		]
		sym/cache:  unicode/str-to-utf8 str :len no
		sym/alias:  either zero? id [-1][0 - id]		;-- -1: no alias, abs(id)>0: alias id
		sym/header: TYPE_SYMBOL							;-- implicit reset of all header flags
		_hashtable/put table as red-value! sym
		block/rs-length? symbols
	]
	
	make: func [
		s 		[c-string!]								;-- input c-string!
		return:	[integer!]
		/local
			str  [red-slice! value]
			sym  [red-symbol!]
			id   [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "symbol/make"]]

		str/node:	unicode/load-utf8 s system/words/length? s
		str/header: TYPE_SLICE
		str/head:	0
		str/length: -1
		id: search str

		if positive? id [return id]
		
		sym: as red-symbol! ALLOC_TAIL(symbols)	
		sym/header: TYPE_UNSET
		sym/node:   str/node
		sym/cache:  internalize s
		sym/alias:  either zero? id [-1][0 - id]		;-- -1: no alias, abs(id)>0: alias id
		sym/header: TYPE_SYMBOL							;-- implicit reset of all header flags
		_hashtable/put table as red-value! sym
		block/rs-length? symbols
	]
	
	get: func [
		id		[integer!]
		return:	[red-symbol!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(symbols)
		as red-symbol! s/offset + id - 1
	]
	
	resolve: func [
		id		[integer!]
		return:	[integer!]
		/local
			sym	[red-symbol!]
			s	[series!]
	][
		s: GET_BUFFER(symbols)
		sym: as red-symbol! s/offset + id - 1
		assert sym < s/tail
		either positive? sym/alias [sym/alias][id]
	]

	get-alias-id: func [
		id		[integer!]
		return:	[integer!]
		/local
			sym	[red-symbol!]
			s	[series!]
	][
		s: GET_BUFFER(symbols)
		sym: as red-symbol! s/offset + id - 1
		sym/alias
	]

	push: func [

	][

	]
	
	;-- Actions -- 

	compare: func [
		sym1	[red-symbol!]
		sym2	[red-symbol!]
		op		[integer!]
		return:	[integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "symbol/compare"]]

		string/equal? as red-string! sym1 as red-string! sym2 op no							;-- match?: no
	]
	
	init: does [
		datatype/register [
			TYPE_SYMBOL
			TYPE_VALUE
			"symbol!"
			;-- General actions --
			null			;make
			null			;random
			null			;reflect
			null			;to
			null			;form
			null			;mold
			null			;eval-path
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
			null			;insert
			null			;length?
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
	]
]