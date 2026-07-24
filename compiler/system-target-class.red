Red [
	Title: "Red/System code emitter target contract"
	File:  %compiler/system-target-class.red
]

compiler-system-target-class: context [
	target: none
	little-endian?: none
	struct-align-size: none
	ptr-size: none
	void-ptr: none
	default-align: none
	stack-width: none
	args-offset: none
	stack-slot-max: none
	branch-offset-size: none
	locals-offset: none
	def-locals-offset: none
	native-ref-one-based?: false
	pc-as-pointer?: false
	stack-bitmap-counts?: false
	stateful-calls?: false

	on-global-prolog: none
	on-global-epilog: none
	on-finalize: none
	on-root-level-entry: none
	emit-stack-align-prolog: none
	emit-stack-align-epilog: none
	emit-float-trash-last: none
	PIC?: none
	PIE?: none

	compiler: none
	emitter: none
	width: none
	signed?: none
	last-saved?: false
	last-red-frame: none
	verbose: 0

	emit-casting: emit-call-syscall: emit-call-import:
	emit-call-native: emit-not: emit-push: emit-pop:
	emit-integer-operation: emit-float-operation:
	emit-throw: on-init: emit-alt-last: emit-log-b:
	emit-variable: emit-read-io: emit-io-write:
	emit-push-all: emit-pop-all: emit-atomic-load:
	emit-atomic-store: emit-atomic-math: emit-atomic-fence:
	emit-init-sub: emit-return-sub: emit-call-sub:
	emit-overflow-epilog-no-ovf: emit-overflow-epilog-ovf: none

	; Backends override these hooks. Keeping typed defaults makes method arity
	; visible to compiled Red even before a concrete target is selected.
	emit-boolean-switch: func [operation [word! none!]][0]
	emit-branch: func [
		code [binary!]
		condition [word! block! logic! none!]
		offset [integer! none!]
		parity? [logic! none!]
		/back?
	][0]

	divide-sym: first [/]
	left-shift-sym: first [<<]
	right-shift-sym: first [>>]
	unsigned-right-shift-sym: first [-**]

	comparison-op: [= <> < > <= >=]
	math-op: compose [+ - * / // (to word! first [%])]
	mod-rem-op: compose [// (to word! first [%])]
	mod-rem-func: compose [// mod (to word! first [%]) rem]
	bitwise-op: [and or xor]
	bitshift-op: [>> << -**]

	opp-conditions: [
		overflow? not-overflow?
		not-overflow? overflow?
		= <>
		<> =
		even? odd?
		odd? even?
		< >=
		>= <
		<= >
		> <=
	]

	connect: func [compiler-service [object!] emitter-service [object!]][
		compiler: compiler-service
		emitter: emitter-service
		self
	]

	opposite?: func [condition [word!]][
		select/skip opp-conditions condition 2
	]

	power-of-2?: func [number [integer! char!] /local value][
		value: to integer! number
		if all [
			positive? value
			zero? ((value - 1) and value)
		][
			to integer! log-2 value
		]
	]

	stack-encode: func [offset [integer!]][
		either any [offset < -128 offset > 127][
			int-to-bin/to-bin32 offset
		][
			int-to-bin/to-bin8 offset
		]
	]

	emit: func [bytes [binary! char! block!]][
		if verbose >= 4 [print [">>>emitting code:" mold bytes]]
		append emitter/code-buf bytes
	]

	emit-reloc-addr: func [spec [block!]][
		append spec/3 emitter/tail-ptr
		emit void-ptr
		unless empty? emitter/chunks/queue [
			append/only second last emitter/chunks/queue back tail spec/3
		]
	]

	get-width: func [operand explicit-type /local value][
		reduce [
			emitter/size-of? value: case [
				explicit-type [operand]
				true [
					value: first compiler/get-type operand
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
		set-width compiler/unbox value
		do body
		set [width signed?] old
		if all [alt object? value][
			emit-casting value true
			set [width signed?] old
		]
	]

	implicit-cast: func [
		argument
		alternate? [logic!]
		/local right-width right-type target-type
	][
		right-width: first get-width argument none
		right-type: compiler/get-type argument
		target-type: reduce [case [
			width = 1 [either signed? ['int8!]['uint8!]]
			width = 2 [either signed? ['int16!]['uint16!]]
			width = 4 [either signed? ['integer!]['uint32!]]
			width = 8 [compiler/last-type/1]
		]]
		if any [
			compiler/lossless-integer-cast? right-type target-type
			find [float! float32! float64!] first right-type
		][
			argument: make compiler/action-class [
				action: 'type-cast
				type: target-type
				data: argument
			]
			emit-casting argument alternate?
		]
	]

	argument-size?: func [argument cdecl? [logic!] /local type][
		max any [
			all [
				object? argument
				argument/action = 'null
				emitter/size-of? 'integer!
			]
			all [
				type: compiler/get-type argument
				any [
					all [cdecl? type/1 = 'float32! 8]
					emitter/size-of? type
				]
			]
		] stack-width
	]

	call-arguments-size?: func [arguments [block!] /cdecl /local total argument][
		total: 0
		foreach argument arguments [
			if argument <> #_ [
				total: total + argument-size? argument to logic! cdecl
			]
		]
		total
	]

	get-arguments-class: func [arguments [block!] /local index a b argument][
		index: 1
		foreach slot [a b][
			argument: either object? arguments/:index [
				compiler/cast arguments/:index
			][
				arguments/:index
			]
			set slot either argument = <last> [
				'reg
			][
				switch type?/word argument [
					logic! [arguments/:index: either argument [1][0] 'imm]
					char! ['imm]
					integer! ['imm]
					float! ['imm]
					issue! ['imm]
					word! ['ref]
					get-word! ['ref]
					block! ['reg]
					path! ['reg]
				]
			]
			index: index + 1
		]
		if verbose >= 3 [print ["argument classes:" a b]]
		reduce [a b]
	]

	emit-call: func [
		name [word!]
		arguments [block!]
		/local spec fspec result type attributes operand-type
	][
		if verbose >= 3 [print [">>>calling:" mold name mold arguments]]
		fspec: select compiler/functions name
		spec: any [select emitter/symbols name next fspec]
		type: either fspec/2 = 'routine [fspec/2][first spec]
		attributes: compiler/get-attributes fspec/4
		switch type [
			syscall [emit-call-syscall arguments fspec attributes]
			import [emit-call-import arguments fspec spec attributes]
			native [
				switch/default name [
					log-b [
						emit-pop
						emit-log-b compiler/last-type/1
					]
				][emit-call-native arguments fspec spec attributes]
			]
			routine [emit-call-native/routine arguments fspec spec attributes name]
			inline [
				if block? arguments/1 [arguments/1: <last>]
				do select [
					not [emit-not arguments/1]
					push [emit-push arguments/1]
					pop [emit-pop]
					throw [
						compiler/check-throw
						compiler/last-type: [integer!]
						either (compiler/catch-attribut?) [
							emit-throw arguments/1
						][emit-throw/thru arguments/1]
					]
				] name
				if name = 'not [result: compiler/get-type arguments/1]
			]
			op [
				operand-type: compiler/resolve-expr-type arguments/1
				either (compiler/any-float? operand-type) [
					emit-float-operation name arguments
				][emit-integer-operation name arguments]
				unless find comparison-op name [
					result: any [
						all [block? arguments/1 compiler/last-type]
						compiler/get-type arguments/1
					]
				]
			]
		]
		result
	]
]
