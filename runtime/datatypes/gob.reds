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
		value	[int-ptr!]
		return:	[red-gob!]
		/local
			h [red-gob!]
	][
		h: as red-gob! stack/arguments
		h/header: TYPE_GOB
		h/value: value
		h
	]

	make-in: func [
		parent 	[red-block!]
		value 	[int-ptr!]
		return: [red-gob!]
		/local
			h	[red-gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/make-in"]]
		
		h: as red-gob! ALLOC_TAIL(parent)
		h/header: TYPE_GOB
		h/value: value
		h
	]

	make-at: func [
		slot	[red-value!]
		value	[int-ptr!]
		return:	[red-gob!]
		/local
			h	[red-gob!]
	][
		h: as red-gob! slot
		h/header: TYPE_GOB
		h/value: value
		h
	]

	push: func [
		value	[int-ptr!]
		return: [red-gob!]
		/local
			hndl [red-gob!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/push"]]
		
		hndl: as red-gob! stack/push*
		hndl/header: TYPE_GOB
		hndl/value:  value
		hndl
	]

	;-- Actions --

	make: func [
		proto	[red-gob!]
		spec	[red-value!]
		type	[integer!]
		return:	[red-gob!]  
	][
		proto/header: type
		proto/value: as int-ptr! gui/rs-gob/create as red-block! spec
		proto
	]

	form: func [
		h		[red-gob!]
		buffer	[red-string!]
		arg		[red-value!]
		part	[integer!]
		return:	[integer!]
		/local
			formed [c-string!]
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/form"]]
		
		formed: string/to-hex as-integer h/value false
		string/concatenate-literal buffer formed
		string/append-char GET_BUFFER(buffer) as-integer #"h"
		part - 9
	]
	
	mold: func [
		h		[red-gob!]
		buffer	[red-string!]
		only?	[logic!]
		all?	[logic!]
		flat?	[logic!]
		arg		[red-value!]
		part 	[integer!]
		indent	[integer!]
		return: [integer!]
	][
		#if debug? = yes [
			all?: yes			;-- show gob in debug mode
			if verbose > 0 [print-line "gob/mold"]
		]

		either all? [
			string/concatenate-literal buffer "#[GOB! "
			part: form h buffer arg part
			string/append-char GET_BUFFER(buffer) as-integer #"]"
			part + 11
		][
			string/concatenate-literal buffer "GOB!"
			part + 11
		]
	]

	compare: func [
		value1	[red-gob!]							;-- first operand
		value2	[red-gob!]							;-- second operand
		op		[integer!]								;-- type of comparison
		return:	[integer!]
		/local
			left  [integer!]
			right [integer!] 
	][
		#if debug? = yes [if verbose > 0 [print-line "gob/compare"]]

		if TYPE_OF(value2) <> TYPE_GOB [return 1]
		SIGN_COMPARE_RESULT(value1/value value2/value)
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