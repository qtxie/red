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
	call-arg-index: call-arg-types: call-extra-slots: call-pad-slots:
	call-shadow-slots: call-stack-slots: call-float-reg-count:
	call-struct-temp-slots: none
	call-variadic?: none

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
	saved-last-wide?: false
	by-value-args: none
	last-math-op: none
	last-red-frame: none
	verbose: 0

	; Backends override these hooks. Keeping typed defaults makes method arity
	; visible to compiled Red even before a concrete target is selected.
	emit-access-path: func [path [path! set-path!] spec [block! none!] /short][any [spec []]]
	emit-access-register: func [reg [word!] set? [logic!] value][]
	emit-alloc-stack: func [zeroed? [logic!]][]
	emit-argument: func [argument function-spec [block!]][]
	emit-atomic-cas: func [check value return? [logic!] order [word!]][]
	emit-atomic-fence: does []
	emit-atomic-load: func [order [word!]][]
	emit-atomic-math: func [operation [word!] right old? [logic!] return? [logic!] order [word!]][]
	emit-atomic-store: func [value order [word!]][]
	emit-boolean-switch: func [operation [word! none!]][reduce [0 0]]
	emit-branch: func [
		code [binary!]
		condition [word! block! logic! none!]
		offset [integer! none!]
		parity? [logic! none!]
		/back?
	][0]
	emit-call-import: func [args [block!] fspec [block!] spec [block!] attributes [block! none!]][]
	emit-call-native: func [
		args [block!] fspec [block!] spec [block!] attributes [block! none!]
		/routine name [word!]
	][]
	emit-call-sub: func [name [word!] spec [block!]][]
	emit-call-syscall: func [args [block!] fspec [block!] attributes [block! none!]][]
	emit-casting: func [value [object!] alternate? [logic!]][]
	emit-clear-slot: func [name [word!]][]
	emit-close-catch: func [offset [integer!] level [integer!] global? [logic!] callback? [logic!]][]
	emit-end-loop: func [spec [block! none!] name [word! none!]][]
	emit-epilog: func [
		name [word! path!]
		locals [block!]
		args-size [integer!]
		locals-size [integer!]
		/with slots [integer! none!]
		/closing
	][]
	emit-float-operation: func [name [word!] args [block!]][]
	emit-float-trash-last: does []
	emit-fpu-get: func [
		/type
		/options option [word!]
		/masks mask [word!]
		/cword
		/status
	][0]
	emit-fpu-set: func [
		value
		/options option [word!]
		/masks mask [word!]
		/cword
	][]
	emit-fpu-init: does []
	emit-fpu-update: does []
	emit-free-stack: does []
	emit-get-overflow: does []
	emit-get-pc: does [0]
	emit-get-stack: func [/frame][]
	emit-init-path: func [name [word! get-word!]][]
	emit-init-sub: does []
	emit-integer-operation: func [name [word!] args [block!]][]
	emit-io-read: func [type][]
	emit-io-write: func [type][]
	emit-jump-point: func [type [block!]][]
	emit-load: func [value /alt /with cast [object!]][]
	emit-load-literal: func [type [block! none!] value][]
	emit-load-literal-ptr: func [spec [block!]][]
	emit-load-path: func [path [path!] type [word!] parent [block! none!]][]
	emit-load-union-tag: func [spec [block!]][]
	emit-log-b: func [type][]
	emit-move-path-alt: func [/pair /with type [block!]][]
	emit-not: func [value][]
	emit-open-catch: func [body-size [integer!] global? [logic!]][]
	emit-overflow-epilog-no-ovf: does []
	emit-overflow-epilog-ovf: does []
	emit-pop: does []
	emit-pop-all: does []
	emit-prolog: func [name [word!] locals [block!] bitmap [integer!]][reduce [0 0]]
	emit-push: func [value /with cast [object!] /cdecl][]
	emit-push-all: does []
	emit-push-struct: func [
		slots [integer!]
		/sysv sysv-type [block!]
		/aggregate aggregate-type [block!]
		/returned
	][]
	emit-push-struct-ref: func [slots [integer!]][]
	emit-read-io: func [type][]
	emit-release-stack: func [slots [integer!] /bytes][]
	emit-reserve-stack: func [slots [integer!]][]
	emit-restore-last: does []
	emit-return-sub: does []
	emit-save-last: does []
	emit-set-stack: func [value /frame][]
	emit-stack-align: does []
	emit-stack-align-epilog: func [args [block!]][]
	emit-stack-align-prolog: func [args [block!] fspec [block!]][]
	emit-start-loop: func [spec [block! none!] name [word! none!]][]
	emit-store: func [
		name [word!]
		value
		spec [block! none!]
		/by-value slots [integer!]
	][]
	emit-store-path: func [path [set-path!] type [word!] value parent [block! none!]][]
	emit-throw: func [value /thru][]
	emit-variable: func [
		name [word! object!]
		global-code [binary! block! none!]
		pointer-code [binary! block! none!]
		local-code [binary! block! none!]
		/alt
	][]
	emit-variant-check: func [spec [block!] id [integer!]][]
	homogeneous-floats?: func [fspec [block!]][reduce [false 0]]
	on-finalize: does []
	on-global-epilog: func [runtime? [logic!] type [word!]][]
	on-global-prolog: func [runtime? [logic!] type [word!]][]
	on-init: does []
	on-root-level-entry: does []
	patch-call: func [buffer [binary!] relative [integer!] destination [integer!]][]
	patch-jump-back: func [buffer [binary!] offset [integer!]][]
	patch-jump-point: func [buffer [binary!] pointer [integer!] exit-point [integer!]][]
	patch-sub-call: func [buffer [binary!] pointer [integer!] offset [integer!]][]

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

	emit-reloc-addr: func [spec [block!] /only][
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
		right-type: compiler-api/get-type argument
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
			argument: compiler-api/make-action [
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
				type: compiler-api/get-type argument
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
				compiler-api/cast arguments/:index
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
		fspec: select compiler-api/functions name
		spec: any [select emitter/symbols name next fspec]
		type: either fspec/2 = 'routine [fspec/2][first spec]
		attributes: compiler-api/get-attributes fspec/4
		switch type [
			syscall [emit-call-syscall arguments fspec attributes]
			import [emit-call-import arguments fspec spec attributes]
			native [
				switch/default name [
					log-b [
						emit-pop
						emit-log-b first compiler-api/last-type
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
						compiler-api/check-throw
						compiler-api/set-last-type [integer!]
						either compiler-api/catch-attribut? [
							emit-throw arguments/1
						][emit-throw/thru arguments/1]
					]
				] name
				if name = 'not [result: compiler-api/get-type arguments/1]
			]
			op [
				operand-type: compiler-api/resolve-expr-type arguments/1
				either compiler-api/any-float? operand-type [
					emit-float-operation name arguments
				][emit-integer-operation name arguments]
				either find comparison-op name [
					result: [logic!]
				][
					result: any [
						all [block? arguments/1 compiler-api/last-type]
						compiler-api/get-type arguments/1
					]
				]
			]
		]
		result
	]
]
