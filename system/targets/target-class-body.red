Red [
	Title: "Shared Red/System target emitter body"
	File:  %target-class-body.red
]

	target: little-endian?: struct-align: ptr-size: void-ptr: none ; TBD: document once stabilized
	default-align: stack-width: stack-slot-max:				  	   ; TBD: document once stabilized
	branch-offset-size: locals-offset: def-locals-offset: none	   ; TBD: document once stabilized
	native-ref-one-based?: no
	pc-as-pointer?: no
	stack-bitmap-counts?: no
	stateful-calls?: no
	call-arg-index: call-arg-types: call-extra-slots: call-pad-slots:
	call-shadow-slots: call-stack-slots: call-float-reg-count:
	call-struct-temp-slots: none
	call-variadic?: none

	on-global-prolog: 		 none					;-- called at start of global code section
	on-global-epilog: 		 none					;-- called at end of global code section
	on-finalize:	  		 none					;-- called after all sources are compiled
	on-root-level-entry:	 none					;-- called after a root level expression or directive is compiled
	emit-stack-align-prolog: none					;-- align stack on imported function calls
	emit-stack-align-epilog: none					;-- unwind aligned stack
	emit-float-trash-last:	 none					;-- FPU clean-up code after use in expression
	PIC?:					 none					;-- PIC flag set from compilation job options
	PIE?:					 none					;-- PIE flag set from compilation job options

	compiler: 	none								;-- just a short-cut
	width: 		none								;-- current operand width in bytes
	signed?: 	none								;-- TRUE => signed op, FALSE => unsigned op
	last-saved?: no									;-- TRUE => operand saved in another register
	saved-last-wide?: no
	by-value-args: none
	last-math-op: none
	last-red-frame: none							;-- memory slot holding the last Red frame pointer before an external call
	verbose:  	0									;-- logs verbosity level

	emit-casting: emit-call-syscall: emit-call-import: ;-- just pre-bind word to avoid contexts issue
	emit-call-native: emit-not: emit-push: emit-pop:
	emit-integer-operation: emit-float-operation:
	emit-throw:	on-init: emit-alt-last: emit-log-b:
	emit-variable: emit-read-io: emit-io-write:
	emit-push-all: emit-pop-all: emit-atomic-load:
	emit-atomic-store: emit-atomic-math: emit-atomic-fence:
	emit-init-sub: emit-return-sub: emit-call-sub:
	emit-overflow-epilog-no-ovf: emit-overflow-epilog-ovf: none

	divide-sym:               first [/]
	left-shift-sym:           first [<<]
	right-shift-sym:          first [>>]
	unsigned-right-shift-sym: first [-**]

	comparison-op: [= <> < > <= >=]
	math-op:	   compose [+ - * / // (to word! first [%])]
	mod-rem-op:    compose [// (to word! first [%])]
	mod-rem-func:  compose [// mod (to word! first [%]) rem]
	bitwise-op:	   [and or xor]
	bitshift-op:   [>> << -**]

	opp-conditions: [
	;-- condition ------ opposite condition --
		overflow?		 not-overflow?
		not-overflow?	 overflow?
		=				 <>
		<>				 =
		even?			 odd?
		odd?			 even?
		<				 >=
		>=				 <
		<=				 >
		>				 <=
	]

	opposite?: func [cond [word!]][
		select/skip opp-conditions cond 2
	]

	power-of-2?: func [n [integer! char!]][
		if all [
			n: to integer! n
			positive? n
			zero? n - 1 and n
		][
			to integer! log-2 n
		]
	]

	stack-encode: func [offset [integer!]][
		either any [								;-- local variables only
			offset < -128
			offset > 127
		][
			int-to-bin/to-bin32 offset
		][
			int-to-bin/to-bin8 offset
		]
	]

	emit: func [bin [binary! char! block!]][
		if verbose >= 4 [print [">>>emitting code:" mold bin]]
		append emitter/code-buf bin
	]

	emit-reloc-addr: func [spec [block!]][
		append spec/3 emitter/tail-ptr				;-- save reloc position
		emit emitter/target/void-ptr				;-- emit void addr, reloc later
		unless empty? emitter/chunks/queue [
			append/only 							;-- record reloc reference
				second last emitter/chunks/queue
				back tail spec/3
		]
	]

	get-width: func [operand type /local value][
		reduce [
			emitter/size-of? value: case [
				type 	[operand]
				'else 	[
					value: first compiler-api/get-type operand
					either value = 'any-pointer! ['pointer!][value]
				]
			]
			value
		]
	]

	set-width: func [operand /type /local value][
		value: get-width operand type
		width: value/1
		signed?: emitter/signed? value/2
	]

	with-width-of: func [value body [block!] /alt /local old][
		old: reduce [width signed?]
		set-width compiler-api/unbox value
		do body
		set [width signed?] old
		if all [alt object? value][					;-- casting for right operand
			emit-casting value yes
			set [width signed?] old
		]
	]

	implicit-cast: func [arg alt? [logic!] /local right-width right-type target-type][
		right-width: first get-width arg none
		right-type: compiler-api/get-type arg
		target-type: reduce [case [
			width = 1 [either signed? ['int8!]['uint8!]]
			width = 2 [either signed? ['int16!]['uint16!]]
			width = 4 [either signed? ['integer!]['uint32!]]
			width = 8 [first compiler-api/last-type]
		]]

		if any [
			compiler-api/lossless-integer-cast? right-type target-type
			find [float! float32! float64!] first right-type
		][
			arg: compiler-api/make-action [
				action: 'type-cast
				type: target-type
				data: arg
			]
			emit-casting arg alt?					;-- type cast right argument
		]
	]

	argument-size?: func [arg cdecl [logic!] /local type][
		max
			any [
				all [object? arg arg/action = 'null emitter/size-of? 'integer!]
				all [
					type: compiler-api/get-type arg
					any [
						all [cdecl type/1 = 'float32! 8]	;-- promote to C double
						emitter/size-of? type
					]
				]
			]
			stack-width
	]

	call-arguments-size?: func [args [block!] /cdecl /local total type][
		total: 0
		foreach arg args [
			if arg <> #_ [							;-- bypass place-holder marker
				total: total + argument-size? arg to logic! cdecl
			]
		]
		total
	]

	get-arguments-class: func [args [block!] /local c a b arg][
		c: 1
		foreach op [a b][
			arg: either object? args/:c [compiler-api/cast args/:c][args/:c]
			set op either arg = <last> [
				 'reg								;-- value in accumulator
			][
				switch type?/word arg [
					logic!	  [args/:c: make integer! arg 'imm]
					char! 	  ['imm]
					integer!  ['imm]
					float!	  ['imm]
					issue!    ['imm]
					word! 	  ['ref] 				;-- value needs to be fetched
					get-word! ['ref]
					block!    ['reg] 				;-- value in accumulator (or in alt-acc)
					path!     ['reg] 				;-- value in accumulator (or in alt-acc)
				]
			]
			c: c + 1
		]
		if verbose >= 3 [?? a ?? b]					;-- a and b hold addressing modes for operands
		reduce [a b]
	]

	emit-call: func [name [word!] args [block!] /local spec fspec res type attribs][
		if verbose >= 3 [print [">>>calling:" mold name mold args]]

		fspec: select compiler-api/functions name
		spec: any [select emitter/symbols name next fspec]
		type: either fspec/2 = 'routine [fspec/2][first spec]
		attribs: compiler-api/get-attributes fspec/4

		switch type [
			syscall [
				emit-call-syscall args fspec attribs
			]
			import [
				emit-call-import args fspec spec attribs
			]
			native [
				switch/default name [
					log-b [							;@@ needs a new function type...
						emit-pop
						emit-log-b first compiler-api/last-type
					]
				][
					emit-call-native args fspec spec attribs
				]
			]
			routine [
				emit-call-native/routine-call args fspec spec attribs name
			]
			inline [
				if block? args/1 [args/1: <last>]	;-- works only for unary functions
				do select [
					not	  [emit-not args/1]
					push  [emit-push args/1]
					pop	  [emit-pop]
					throw [
						compiler-api/check-throw
						compiler-api/set-last-type [integer!]
						either compiler-api/catch-attribut? [
							emit-throw args/1
						][
							emit-throw/thru args/1
						]
					]
				] name
				if name = 'not [res: compiler-api/get-type args/1]
			]
			op [
				either compiler-api/any-float? compiler-api/resolve-expr-type args/1 [
					emit-float-operation name args
				][
					emit-integer-operation name args
				]
				unless find comparison-op name [	;-- comparison always return a logic!
					res: any [
						all [block? args/1 compiler-api/last-type]
						compiler-api/get-type args/1	;-- other ops return type of the first argument
					]
				]
			]
		]
		res
	]
