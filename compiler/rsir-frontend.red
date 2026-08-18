Red [
	Title: "Compact Red/System IR frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]
unless value? 'ieee-754 [do %ieee-754.red]

compiler-rsir-frontend: context [
	DEFAULT-MAX-BYTES: 16777216

	ERROR-ARGUMENTS: 1
	ERROR-KIND: 2
	ERROR-LIMIT: 3
	ERROR-NAME: 4
	ERROR-FUNCTION-COUNT: 5
	ERROR-UNSUPPORTED: 6
	ERROR-DUPLICATE: 7
	ERROR-REFERENCE: 8
	ERROR-CONTEXT: 9

	last-error: none
	module-kind: 0
	functions: make block! 96
	function-ids: make hash! 48
	infix-targets: make hash! 16
	contexts: make hash! 32
	types: make block! 256
	type-ids: make hash! 128
	pointer-types: make hash! 64
	array-types: make hash! 32
	aggregate-types: make hash! 64
	function-types: make hash! 64
	subroutine-types: make hash! 16
	typed-call-types: make hash! 64
	alias-type-ids: make hash! 64
	constants: make hash! 256
	protected: make hash! 64
	protected-values: make hash! 64
	imports: make block! 256
	import-ids: make hash! 256
	libraries: make hash! 32
	globals: make hash! 1024
	global-data: make block! 1024
	module-code: make binary! 256
	module-locals: make block! 12
	function-code: make binary! 2048
	initializers: make binary! 256
	switches: make binary! 96
	strings: make binary! 256
	string-ids: make hash! 128
	function-count: 0
	type-count: 0
	import-count: 0
	global-count: 0
	alias-count: 0

	type-kinds: make hash! [
		int8! i8 byte! byte uint8! u8 int16! i16 uint16! u16
		integer! i32 int32! i32 uint32! u32 int64! i64 uint64! u64
		float32! f32 float! f64 float64! f64 logic! logic
		pointer! pointer c-string! c-string struct! pointer union! pointer
		function! pointer subroutine! pointer array! pointer
		byte-ptr! pointer int-ptr! pointer ptr-ptr! pointer
		float32-ptr! pointer
	]

	type-codes: make hash! [
		i8 1 u8 2 i16 3 u16 4 i32 5 u32 6 i64 7 u64 8
		f32 9 f64 10 logic 11 pointer 12 c-string 13 null 14 byte 15
		alias -1 struct -2 union -3 function -4 subroutine -5
		pointer-node -6 array -7 typed-call -8
	]
	builtin-pointees: make hash! [
		byte-ptr! [byte!]
		int-ptr! [integer!]
		ptr-ptr! [pointer!]
		float32-ptr! [float32!]
	]

	return-value-flag: 4
	variadic-flag: 8
	typed-flag: 16
	custom-flag: 32
	callback-flag: 64
	objc-flag: 128
	catch-flag: 256
	call-shape-flags: return-value-flag + variadic-flag + typed-flag
		+ custom-flag + objc-flag
	inline-flag: 1
	protected-flag: 2
	tagged-type-flag: 1
	scalar-initializer: 1
	address-initializer: 2
	bytes-initializer: 3

	; Semantic postfix operations. Operands are typed by the surrounding
	; declaration tables; no source-specific value IDs cross the boundary.
	literal-op: 1
	constant-op: 2
	address-op: 3
	load-op: 4
	set-op: 5
	member-op: 6
	call-op: 7
	cast-op: 8
	size-op: 9
	native-op: 10
	return-op: 11
	drop-op: 12
	duplicate-op: 13
	unary-op: 14
	binary-op: 15
	jump-op: 16
	branch-op: 17
	switch-op: 18
	fail-op: 19
	reference-op: 20
	index-op: 21
	tag-op: 22
	overflow-op: 23
	catch-op: 24
	end-catch-op: 25
	throw-op: 26

	; Operation IDs follow the language families, not source spellings or x64
	; encodings. The postfix stream preserves the specified left-to-right order.
	not-operation: 1
	binary-operations: make hash! [
		+   1  -   2  *   3  /   4  %   5  //  6
		<<  7  >>  8  >>> 9  or 10  xor 11  and 12
		=  13  <> 14  >  15  <  16  >= 17  <= 18
	]

	local-address: 1
	global-address: 2
	import-address: 3
	function-address: 4

	stack-top-native: 1
	stack-push-native: 2
	stack-pop-native: 3
	stack-frame-native: 4
	stack-top-set-native: 5
	stack-frame-set-native: 6
	stack-align-native: 7
	stack-allocate-native: 8
	stack-allocate-zero-native: 9
	stack-free-native: 10
	stack-push-all-native: 11
	stack-pop-all-native: 12
	program-counter-native: 13
	cpu-register-native: 14
	cpu-register-set-native: 15
	cpu-overflow-native: 16
	atomic-fence-native: 17
	atomic-load-native: 18
	atomic-store-native: 19
	atomic-cas-native: 20
	atomic-math-native: 21
	atomic-old-flag: 8
	atomic-operations: make hash! [
		add 1 sub 2 or 3 xor 4 and 5
	]
	cpu-register-ids: make hash! [
		rax 0 rcx 1 rdx 2 rbx 3 rsp 4 rbp 5 rsi 6 rdi 7
		r8 8 r9 9 r10 10 r11 11 r12 12 r13 13 r14 14 r15 15
	]
	statement-value: 0
	expression-value: 1
	tail-value: 2

	last-type: 0
	last-flags: 0
	last-float-literal?: false
	last-stopped?: false
	function-base: 0
	function-return: 0
	function-flags: 0
	function-active?: false
	loops: make block! 8
	overflows: make block! 8
	catches: make block! 8
	thrown-global: 0
	; Function-local lexical constructs are lowered while the postfix stream is
	; built. USE slots stay in the frame table, while their names are tombstoned
	; when the lexical body ends; subroutine bodies are expanded at call sites.
	use-local-slots: make hash! 32
	subroutine-bodies: make block! 32
	subroutine-stack: make block! 8
	static?: false
	static-ref: 0
	static-low: 0
	static-high: 0
	static-flags: 0
	static-initializer: none
	static-next: none

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
	]

	emit-before: func [output [binary!] values [block!] /local position][
		position: tail values
		while [not head? position][
			position: back position
			insert output int-to-bin/to-bin32 position/1
		]
	]

	instruction-here: func [output [binary!] return: [integer!]][
		1 + to integer! (((length? output) / 16) - function-base)
	]

	emit-control: func [
		output [binary!]
		op sense [integer!]
		return: [integer!]
		/local patch
	][
		patch: (length? output) + 5
		emit output reduce [op 0 sense 0]
		patch
	]

	patch-control: func [output [binary!] patch target [integer!]][
		change/part at output patch int-to-bin/to-bin32 target 4
	]

	patch-control-drop: func [output [binary!] patch count [integer!]][
		change/part at output (patch + 4) int-to-bin/to-bin32 count 4
	]

	patch-control-catches: func [output [binary!] patch count [integer!]][
		change/part at output (patch + 8) int-to-bin/to-bin32 count 4
	]

	emit-switch-case: func [low high [integer!] return: [integer!] /local patch][
		patch: (length? switches) + 9
		emit switches reduce [low high 0]
		patch
	]

	patch-switch-case: func [patch target [integer!]][
		change/part at switches patch int-to-bin/to-bin32 target 4
	]

	add-hidden-local: func [
		params locals [block!]
		ref flags [integer!]
		return: [block!]
		/local slot record
	][
		slot: 1 + ((length? params) / 3) + storage-local-count locals
		record: tail locals
		append locals none
		append locals ref
		append locals flags
		; Hidden temporaries have no source name, so they remain usable only
		; through the instruction slot returned here.
		reduce [slot record]
	]

	add-hidden-global: func [ref flags [integer!] return: [integer!] /local id][
		id: global-count + 1
		append/only global-data make binary! 0
		append global-data ref
		append global-data flags
		append global-data 0
		append global-data 0
		global-count: id
		id
	]

	ensure-thrown-global: func [return: [integer!]][
		if thrown-global = 0 [thrown-global: add-hidden-global -5 0]
		thrown-global
	]

	set-global-initializer: func [
		record [block!]
		values [block!]
		/local count data
	][
		unless ((length? values) // 4) = 0 [
			fail ERROR-UNSUPPORTED "invalid static initializer"
		]
		count: (length? values) / 4
		unless all [count > 0 record/5 = 0][
			fail ERROR-UNSUPPORTED "global value is already initialized"
		]
		data: make binary! (count * 16)
		emit data values
		record/4: data
		record/5: count
	]

	write-initializers: func [/local position data][
		clear initializers
		position: global-data
		while [not tail? position][
			data: position/4
			either binary? data [
				position/4: (length? initializers) / 16
				append initializers data
			][position/4: 0]
			position: skip position 5
		]
	]

	emit-local-address: func [output [binary!] slot [integer!]][
		emit output reduce [address-op local-address slot 0]
	]

	storage-local?: func [record [block!] return: [logic!]][
		(ref-kind record/2) <> 'subroutine
	]

	storage-local-count: func [locals [block!] return: [integer!] /local count record][
		count: 0
		record: locals
		while [not tail? record][
			if storage-local? record [count: count + 1]
			record: skip record 3
		]
		count
	]

	logical-value?: func [ref flags [integer!] return: [logic!]][
		all [stack-type-compatible? -11 ref flags = 0]
	]

	fail: func [code [integer!] message [string! block!] /local error][
		error: make object! [code: 0 message: none]
		error/code: code
		error/message: form either block? message [reduce message][message]
		last-error: error
		throw/name error 'rsir-error
	]

	valid-name?: func [name [string!]][
		all [not empty? name not find to binary! name 0]
	]

	qualified: func [scope [block!] value [word! path!] /local output item][
		output: make string! 48
		foreach item scope [
			unless empty? output [append output ">"]
			append output form item
		]
		foreach item either path? value [to block! value][reduce [value]][
			unless empty? output [append output ">"]
			append output form item
		]
		to word! output
	]

	extend-scope: func [scope [block!] value [word! path!] /local output item][
		output: copy scope
		foreach item either path? value [to block! value][reduce [value]][
			append output item
		]
		output
	]

	resolve-name: func [
		value [word! path!]
		scope uses [block!]
		names [hash!]
		/local depth key id imported
	][
		if path? value [
			if id: select names qualified copy [] value [return id]
			depth: length? scope
			while [depth > 0][
				key: qualified copy/part scope depth value
				if id: select names key [return id]
				depth: depth - 1
			]
			foreach imported uses [
				key: qualified imported value
				if id: select names key [return id]
			]
			return none
		]
		depth: length? scope
		while [depth >= 0][
			key: qualified copy/part scope depth value
			if id: select names key [return id]
			depth: depth - 1
		]
		foreach imported uses [
			key: qualified imported value
			if id: select names key [return id]
		]
		none
	]

	import-variable-id: func [
		value [word! path!]
		scope uses [block!]
		/local id record
	][
		unless id: resolve-name value scope uses import-ids [return none]
		record: skip imports ((id - 1) * 10)
		either record/5 = 'variable [id][none]
	]

	resolve-context: func [
		value [word! path!]
		scope uses [block!]
		/local depth key imported
	][
		if path? value [
			key: qualified copy [] value
			if select contexts key [return extend-scope copy [] value]
			depth: length? scope
			while [depth > 0][
				key: qualified copy/part scope depth value
				if select contexts key [
					return extend-scope copy/part scope depth value
				]
				depth: depth - 1
			]
			foreach imported uses [
				key: qualified imported value
				if select contexts key [return extend-scope imported value]
			]
			return none
		]
		depth: length? scope
		while [depth >= 0][
			key: qualified copy/part scope depth value
			if select contexts key [
				return extend-scope copy/part scope depth value
			]
			depth: depth - 1
		]
		foreach imported uses [
			key: qualified imported value
			if select contexts key [return extend-scope imported value]
		]
		none
	]

	intern-pointer: func [pointee [integer!] /local id kind][
		kind: ref-kind pointee
		unless find [i8 byte u8 i16 u16 i32 u32 i64 u64 f32 f64 pointer] kind [
			fail ERROR-UNSUPPORTED "pointer pointee type is unsupported"
		]
		if id: select pointer-types pointee [return id]
		id: type-count + 1
		repend pointer-types [pointee id]
		append types none
		append types 'pointer
		append types pointee
		append/only types copy []
		append/only types copy []
		type-count: id
		id
	]

	intern-array: func [
		element count width [integer!]
		return: [integer!]
		/local key id kind
	][
		kind: ref-kind element
		unless all [
			count > 0
			find [1 2 4 8] width
			find [
				i8 byte u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string function
			] kind
		][
			fail ERROR-UNSUPPORTED "literal array element type is unsupported"
		]
		key: mold/flat reduce [element count width]
		if id: select array-types key [return id]
		id: type-count + 1
		repend array-types [key id]
		append types none
		append types 'array
		append types element
		append types count
		append types width
		type-count: id
		id
	]

	tagged-union?: func [kind [word!] spec [block!] return: [logic!]][
		all [
			kind = 'union
			not empty? spec
			block? spec/1
			spec/1 = [variant]
		]
	]

	aggregate-members: func [kind [word!] spec [block!] return: [block!]][
		either tagged-union? kind spec [next spec][spec]
	]

	validate-aggregate: func [
		kind [word!]
		spec [block!]
		/local position names field
	][
		position: aggregate-members kind spec
		unless all [not empty? position ((length? position) // 2) = 0][
			fail ERROR-UNSUPPORTED "aggregate type requires field/type pairs"
		]
		names: make hash! 16
		while [not tail? position][
			field: position/1
			unless all [word? field block? position/2][
				fail ERROR-UNSUPPORTED ["invalid aggregate member " mold field]
			]
			if select names field [
				fail ERROR-DUPLICATE ["duplicate aggregate member " mold field]
			]
			repend names [field true]
			position: skip position 2
		]
		true
	]

	intern-aggregate: func [
		kind [word!]
		spec scope uses [block!]
		return: [integer!]
		/local key id
	][
		unless find [struct union] kind [
			fail ERROR-UNSUPPORTED "invalid aggregate type"
		]
		validate-aggregate kind spec
		key: mold/flat reduce [kind spec scope uses]
		if id: select aggregate-types key [return id]
		id: type-count + 1
		repend aggregate-types [key id]
		append types none
		append types kind
		append/only types copy/deep spec
		append/only types copy scope
		append/only types copy/deep uses
		type-count: id
		id
	]

	type-kind: func [
		type [block!]
		scope uses [block!]
		/local name kind id record steps target
	][
		unless all [not empty? type any [word? type/1 path? type/1]][return none]
		name: type/1
		kind: all [word? name select type-kinds name]
		unless kind [
			unless id: resolve-name name scope uses type-ids [return none]
			steps: 0
			forever [
				steps: steps + 1
				if steps > type-count [fail ERROR-REFERENCE "cyclic type alias"]
				record: skip types ((id - 1) * 5)
				kind: record/2
				if kind <> 'alias [break]
				target: record/3
				if block? target [
					kind: type-kind target record/4 record/5
					break
				]
				name: target
				if all [word? name kind: select type-kinds name][break]
				unless id: resolve-name name record/4 record/5 type-ids [return none]
			]
		]
		case [
			find [struct union] kind [
				case [
					(length? type) = 1 ['pointer]
					all [(length? type) = 2 type/2 = 'value][kind]
					true [none]
				]
			]
			find [function subroutine] kind [
				either (length? type) = 1 ['pointer][none]
			]
			kind = 'pointer [
				case [
					(length? type) = 1 [kind]
					all [(length? type) = 2 block? type/2][kind]
					true [none]
				]
			]
			(length? type) = 1 [kind]
			true [none]
		]
	]

	type-ref: func [
		type [block!]
		scope uses [block!]
		/local name kind code id pointee
	][
		unless all [not empty? type any [word? type/1 path? type/1]][
			fail ERROR-UNSUPPORTED "invalid type reference"
		]
		name: type/1
		if all [
			word? name
			find [struct! union!] name
			any [
				all [(length? type) = 2 block? type/2]
				all [(length? type) = 3 block? type/2 type/3 = 'value]
			]
		][
			return intern-aggregate either name = 'struct! ['struct]['union]
				type/2 scope uses
		]
		if all [
			word? name
			name = 'function!
			(length? type) = 2
			block? type/2
		][return intern-function-type type/2 scope uses]
		if all [
			word? name
			name = 'subroutine!
			(length? type) = 1
		][return intern-subroutine-type scope uses]
		kind: type-kind type scope uses
		unless kind [fail ERROR-UNSUPPORTED ["unsupported type " mold type]]
		if all [word? name pointee: select builtin-pointees name][
			return intern-pointer type-ref pointee scope uses
		]
		if all [word? name name = 'pointer! (length? type) = 2][
			return intern-pointer type-ref type/2 scope uses
		]
		if all [
			word? name
			select type-kinds name
			code: select type-codes kind
		][return negate code]
		unless id: resolve-name name scope uses type-ids [
			fail ERROR-REFERENCE ["unknown type " mold name]
		]
		id
	]

	type-flags: func [type [block!] scope uses [block!] /local kind direct?][
		direct?: all [
			(length? type) = 3
			word? type/1
			find [struct! union!] type/1
			block? type/2
			type/3 = 'value
		]
		either any [all [(length? type) = 2 type/2 = 'value] direct?][
			kind: either direct? [
				either type/1 = 'struct! ['struct]['union]
			][type-kind type scope uses]
			unless find [struct union] kind [
				fail ERROR-UNSUPPORTED "only aggregate types can be passed by value"
			]
			inline-flag
		][0]
	]

	member-type-info: func [
		kind [word!]
		spec field-type scope uses [block!]
		return: [block!]
		/local member-kind
	][
		member-kind: type-kind field-type scope uses
		if all [tagged-union? kind spec none? member-kind][
			validate-aggregate 'struct field-type
			return reduce [
				intern-aggregate 'struct field-type scope uses
				inline-flag
			]
		]
		reduce [
			type-ref field-type scope uses
			type-flags field-type scope uses
		]
	]

	ref-kind: func [ref [integer!] /local record kind name steps target][
		if ref < 0 [
			if ref < -15 [return none]
			return pick [
				i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string null byte
			]
				negate ref
		]
		if any [ref = 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			if ref > type-count [return none]
			record: skip types ((ref - 1) * 5)
			kind: record/2
			unless kind = 'alias [return kind]
			target: record/3
			if block? target [return type-kind target record/4 record/5]
			name: target
			if all [word? name kind: select type-kinds name][
				return kind
			]
			unless ref: resolve-name name record/4 record/5 type-ids [return none]
			steps: steps + 1
		]
		none
	]

	canonical-ref: func [ref [integer!] /local record target steps][
		if ref <= 0 [return ref]
		steps: 0
		while [steps < type-count][
			if ref > type-count [return 0]
			record: skip types ((ref - 1) * 5)
			unless record/2 = 'alias [return ref]
			target: record/3
			target: either block? target [target][reduce [target]]
			ref: type-ref target record/4 record/5
			if ref <= 0 [return ref]
			steps: steps + 1
		]
		fail ERROR-REFERENCE "cyclic type alias"
	]

	tagged-union-ref?: func [ref [integer!] return: [logic!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return false]
		record: skip types ((ref - 1) * 5)
		all [record/2 = 'union tagged-union? record/2 record/3]
	]

	array-info: func [ref [integer!] return: [block! none!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return none]
		record: skip types ((ref - 1) * 5)
		either record/2 = 'array [reduce [record/3 record/4 record/5]][none]
	]

	member-info: func [
		ref [integer!]
		name [word!]
		/local record kind target definition spec index steps info
	][
		if any [ref <= 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			record: skip types ((ref - 1) * 5)
			kind: record/2
			if kind = 'alias [
				target: record/3
				if block? target [
					ref: type-ref target record/4 record/5
					if ref <= 0 [return none]
				]
				if not block? target [
					if all [word? target select type-kinds target][return none]
					unless ref: resolve-name target record/4 record/5 type-ids [return none]
				]
				steps: steps + 1
				continue
			]
			unless find [struct union] kind [return none]
			definition: record/3
			spec: aggregate-members kind definition
			index: 0
			while [not tail? spec][
				if spec/1 = name [
					info: member-type-info kind definition spec/2 record/4 record/5
					return reduce [
						index
						info/1
						info/2
					]
				]
				index: index + 1
				spec: skip spec 2
			]
			return none
		]
		none
	]

	pointee-ref: func [ref [integer!] return: [integer! none!] /local base kind record][
		base: canonical-ref ref
		kind: ref-kind base
		case [
			kind = 'c-string [-15]
			kind = 'array [
				record: skip types ((base - 1) * 5)
				record/3
			]
			all [kind = 'pointer base > 0][
				record: skip types ((base - 1) * 5)
				either record/2 = 'pointer [record/3][none]
			]
			find [struct union] kind [base]
			true [none]
		]
	]

	typed-pointer-id: func [
		ref [integer!]
		return: [integer!]
		/local base record target kind
	][
		base: canonical-ref ref
		target: none
		if all [base > 0 base <= type-count][
			record: skip types ((base - 1) * 5)
			if record/2 = 'pointer [target: record/3]
		]
		unless integer? target [return 10]
		kind: ref-kind target
		case [
			kind = 'i32 [8]
			kind = 'pointer [10]
			true [7]
		]
	]

	typed-type-id: func [
		ref [integer!]
		return: [integer!]
		/local record target alias-id kind
	][
		if ref = 0 [return 8]
		if all [ref > 0 ref <= type-count][
			record: skip types ((ref - 1) * 5)
			alias-id: select alias-type-ids record/1
			if all [integer? alias-id alias-id > 1000][
				return alias-id
			]
			if record/2 = 'alias [
				target: either block? record/3 [
					type-ref record/3 record/4 record/5
				][
					type-ref reduce [record/3] record/4 record/5
				]
				return typed-type-id target
			]
		]
		kind: ref-kind ref
		case [
			kind = 'logic [1]
			kind = 'i32 [2]
			kind = 'byte [3]
			kind = 'u8 [14]
			kind = 'f32 [4]
			kind = 'f64 [5]
			kind = 'c-string [6]
			kind = 'pointer [typed-pointer-id ref]
			kind = 'function [9]
			kind = 'i64 [11]
			kind = 'u64 [12]
			kind = 'i8 [13]
			kind = 'i16 [15]
			kind = 'u16 [16]
			kind = 'u32 [17]
			kind = 'struct [1000]
			kind = 'union [1001]
			kind = 'null [8]
			true [0]
		]
	]

	address-reference-ref: func [
		ref flags [integer!]
		return: [integer! none!]
		/local base kind
	][
		if flags <> 0 [return none]
		base: canonical-ref ref
		kind: ref-kind base
		case [
			integer-kind? kind [intern-pointer base]
			float-kind? kind [intern-pointer base]
			kind = 'pointer [intern-pointer -12]
			true [none]
		]
	]

	one-based-index-bits: func [value [integer!] return: [block!] /local low][
		if value = -2147483648 [return reduce [2147483647 -1]]
		low: value - 1
		reduce [low either low < 0 [-1][0]]
	]

	add-system-type: func [scope uses [block!] /local key id][
		if id: resolve-name 'system! scope uses type-ids [return id]
		key: to word! "system!"
		id: type-count + 1
		repend type-ids [key id]
		append types key
		append types 'struct
		append/only types [
			args-count [integer!]
			args-list [byte-ptr!]
			env-vars [byte-ptr!]
			stack [byte-ptr!]
			pc [byte-ptr!]
			cpu [byte-ptr!]
			fpu [byte-ptr!]
			alias [integer!]
			words [integer!]
			thrown [integer!]
			boot-data [byte-ptr!]
		]
		append/only types copy []
		append/only types copy []
		type-count: id
		id
	]

	add-system-import: func [
		library [binary!]
		scope uses [block!]
		/local key external ref id
	][
		key: to word! "system"
		if any [
			select import-ids key
			select function-ids key
			select globals key
		][fail ERROR-DUPLICATE "system is already declared"]
		external: to binary! "system"
		ref: add-system-type scope uses
		id: import-count + 1
		repend import-ids [key id]
		append imports key
		append/only imports library
		append/only imports external
		append/only imports [system!]
		append imports 'variable
		append/only imports scope
		append/only imports uses
		append imports ref
		append imports none
		append imports 0
		import-count: id
		id
	]

	infix-spec?: func [spec [block!] return: [logic!] /local position][
		position: spec
		if all [not tail? position string? position/1][position: next position]
		to logic! all [
			not tail? position
			block? position/1
			find position/1 'infix
		]
	]

	check-infix-arity: func [name signature [block!] /local count][
		count: (length? signature/2) / 3
		unless count = 2 [
			fail ERROR-ARGUMENTS [
				"infix function requires 2 arguments, found " count "for" form name
			]
		]
	]

	signature-flags: func [attributes [block!] /local flags convention item bit][
		if (length? attributes) > 2 [
			fail ERROR-UNSUPPORTED "too many function attributes"
		]
		if all [find attributes 'catch (length? attributes) <> 1][
			fail ERROR-UNSUPPORTED "catch cannot be combined with another function attribute"
		]
		if all [
			(length? attributes) = 2
			attributes/1 = attributes/2
		][fail ERROR-UNSUPPORTED "duplicate function attribute"]
		flags: 0
		convention: 0
		foreach item attributes [
			unless word? item [fail ERROR-UNSUPPORTED "invalid function attribute"]
			bit: 0
			case [
				item = 'cdecl [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 1
				]
				item = 'stdcall [
					if convention <> 0 [
						fail ERROR-UNSUPPORTED "conflicting calling conventions"
					]
					convention: 2
				]
				item = 'variadic [bit: variadic-flag]
				item = 'typed [bit: typed-flag]
				item = 'custom [bit: custom-flag]
				item = 'callback [bit: callback-flag]
				item = 'objc [bit: objc-flag]
				item = 'catch [bit: catch-flag]
				item = 'infix []
				item = 'red-internal []
				true [fail ERROR-UNSUPPORTED ["unknown function attribute " mold item]]
			]
			if all [
				bit >= variadic-flag
				bit <= custom-flag
				(flags and (variadic-flag + typed-flag + custom-flag)) <> 0
			][fail ERROR-UNSUPPORTED "conflicting variable-arity attributes"]
			flags: flags + bit
		]
		flags + convention
	]

	read-signature: func [
		spec scope uses [block!]
		/local position names-start names-end item name type params locals names flags
			ref type-flags-value
			return-ref value? locals?
	][
		position: spec
		if all [not tail? position string? position/1][position: next position]
		flags: 0
		if all [not tail? position block? position/1][
			flags: signature-flags position/1
			position: next position
		]
		if all [not tail? position string? position/1][position: next position]
		if all [not tail? position position/1 = 'red-internal][position: next position]

		params: make block! 12
		locals: make block! 12
		names: make hash! 16
		return-ref: 0
		value?: false
		locals?: false
		while [not tail? position][
			item: position/1
			case [
				refinement? item [
					unless all [item = /local not locals?][
						fail ERROR-UNSUPPORTED "function refinement is unsupported"
					]
					locals?: true
					position: next position
				]
				all [set-word? item not locals?][
					unless all [
						item = to set-word! 'return
						not value?
						(length? position) >= 2
						block? position/2
					][fail ERROR-UNSUPPORTED "invalid function return type"]
					type: position/2
					return-ref: type-ref type scope uses
					if (ref-kind return-ref) = 'subroutine [
						fail ERROR-UNSUPPORTED "subroutine! cannot be returned"
					]
					if (type-flags type scope uses) = 1 [
						flags: flags + return-value-flag
					]
					value?: true
					position: skip position 2
					if all [not tail? position string? position/1][position: next position]
				]
				word? item [
					if all [value? not locals?][
						fail ERROR-UNSUPPORTED "function parameter follows its return type"
					]
					names-start: position
					while [all [not tail? position word? position/1]][
						name: position/1
						if select names name [
							fail ERROR-UNSUPPORTED "duplicate function variable"
						]
						repend names [name true]
						position: next position
					]
					names-end: position
					either locals? [
						ref: 0
						type-flags-value: 0
						if all [not tail? position block? position/1][
							ref: type-ref position/1 scope uses
							type-flags-value: type-flags position/1 scope uses
							position: next position
						]
						while [names-start <> names-end][
							repend locals [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
					][
						unless all [not tail? position block? position/1][
							fail ERROR-UNSUPPORTED "function parameter is missing its type"
						]
						type: position/1
						ref: type-ref type scope uses
						type-flags-value: type-flags type scope uses
						if (ref-kind ref) = 'subroutine [
							fail ERROR-UNSUPPORTED "subroutine! is only allowed for locals"
						]
						while [names-start <> position][
							repend params [names-start/1 ref type-flags-value]
							names-start: next names-start
						]
						position: next position
					]
					if all [not tail? position string? position/1][position: next position]
				]
				true [fail ERROR-UNSUPPORTED "function signature is unsupported"]
			]
		]
		reduce [return-ref params locals flags]
	]

	resolved-signature?: func [value return: [logic!]][
		all [
			block? value
			(length? value) = 4
			integer? value/1
			block? value/2
			block? value/3
			integer? value/4
		]
	]

	signature-key: func [signature [block!] /local key parameter][
		key: make block! ((length? signature/2) + 2)
		append key canonical-ref signature/1
		append key signature/4
		parameter: signature/2
		while [not tail? parameter][
			append key canonical-ref parameter/2
			append key parameter/3
			parameter: skip parameter 3
		]
		mold/flat key
	]

	intern-function-signature: func [
		signature scope uses [block!]
		return: [integer!]
		/local key id
	][
		unless empty? signature/3 [
			fail ERROR-UNSUPPORTED "function type cannot declare locals"
		]
		key: signature-key signature
		if id: select function-types key [return id]
		id: type-count + 1
		repend function-types [key id]
		append types none
		append types 'function
		append/only types copy/deep signature
		append/only types copy scope
		append/only types copy/deep uses
		type-count: id
		id
	]

	intern-function-type: func [
		spec scope uses [block!]
		return: [integer!]
	][
		intern-function-signature (read-signature spec scope uses) scope uses
	]

	intern-subroutine-type: func [
		scope uses [block!]
		return: [integer!]
		/local key id
	][
		key: mold/flat reduce [scope uses]
		if id: select subroutine-types key [return id]
		id: type-count + 1
		repend subroutine-types [key id]
		append types none
		append types 'subroutine
		append/only types copy []
		append/only types copy scope
		append/only types copy/deep uses
		type-count: id
		id
	]

	prepare-types: func [/local position signature key id][
		position: types
		id: 1
		while [not tail? position][
			if position/2 = 'function [
				signature: either resolved-signature? position/3 [
					position/3
				][read-signature position/3 position/4 position/5]
				unless empty? signature/3 [
					fail ERROR-UNSUPPORTED "function type cannot declare locals"
				]
				position/3: signature
				key: signature-key signature
				unless select function-types key [
					repend function-types [key id]
				]
			]
			position: skip position 5
			id: id + 1
		]
	]

	function-signature: func [ref [integer!] return: [block! none!] /local record][
		ref: canonical-ref ref
		if any [ref <= 0 ref > type-count][return none]
		record: skip types ((ref - 1) * 5)
		unless record/2 = 'function [return none]
		either resolved-signature? record/3 [record/3][none]
	]

	call-signature-ref: func [target [integer!] return: [integer!] /local record][
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			intern-function-signature reduce [
				record/6 record/7 copy [] record/9
			] copy [] copy []
		][
			record: skip imports (((0 - target) - 1) * 10)
			intern-function-signature reduce [
				record/8 record/9 copy [] record/10
			] copy [] copy []
		]
	]

	intern-typed-call: func [
		signature [integer!]
		arguments [block!]
		return: [integer!]
		/local key id
	][
		key: mold/flat reduce [signature arguments]
		if id: select typed-call-types key [return id]
		id: type-count + 1
		repend typed-call-types [key id]
		append types key
		append types 'typed-call
		append/only types copy arguments
		append/only types copy []
		append/only types copy []
		type-count: id
		id
	]

	prepare-functions: func [/local record signature id][
		record: functions
		id: 1
		while [not tail? record][
			signature: read-signature record/2 record/4 record/5
			if find infix-targets id [check-infix-arity record/1 signature]
			record/6: signature/1
			record/7: signature/2
			record/8: signature/3
			record/9: signature/4
			id: id + 1
			record: skip record 10
		]
	]

	prepare-imports: func [/local record signature cc id][
		record: imports
		id: -1
		while [not tail? record][
			cc: record/8
			either record/5 = 'function [
				signature: read-signature record/4 record/6 record/7
				if find infix-targets id [check-infix-arity record/1 signature]
				unless empty? signature/3 [
					fail ERROR-UNSUPPORTED "import signature cannot declare locals"
				]
				if (signature/4 and 3) <> 0 [
					fail ERROR-UNSUPPORTED
						"import calling convention is specified twice"
				]
				record/8: signature/1
				record/9: signature/2
				record/10: signature/4 + either cc = 'cdecl [1][2]
			][
				record/8: type-ref record/4 record/6 record/7
				record/9: none
				record/10: 0
			]
			id: id - 1
			record: skip record 10
		]
	]

	add-module-function: func [/local key][
		key: to word! "***-main"
		if any [
			select function-ids key
			select import-ids key
			select globals key
		][fail ERROR-DUPLICATE "***-main is reserved for the module body"]
		append/only functions to binary! "***-main"
		append/only functions copy []
		append/only functions module-code
		append/only functions copy []
		append/only functions copy []
		append functions 0
		append/only functions copy []
		append/only functions copy module-locals
		append functions 0
		append functions 0
		function-count: function-count + 1
	]

	lower-functions: func [/local record body count][
		clear function-code
		record: functions
		while [not tail? record][
			body: record/3
			count: either binary? body [
				unless ((length? body) // 16) = 0 [
					fail ERROR-UNSUPPORTED "invalid module instruction stream"
				]
				append function-code body
				(length? body) / 16
			][
				stack-body record/6 body record/4 record/5 function-code
					record/7 record/8 record/9
			]
			record/10: count
			record: skip record 10
		]
	]

	scan-enum: func [
		name [word!]
		values scope [block!]
		/local key position item value constant-key id
	][
		key: qualified scope name
		if select type-ids key [fail ERROR-DUPLICATE ["duplicate type " mold key]]
		id: type-count + 1
		repend type-ids [key id]
		append types key
		append types 'i32
		append/only types values
		append/only types copy scope
		append/only types copy []
		type-count: id
		value: 0
		position: values
		while [not tail? position][
			item: position/1
			case [
				word? item [position: next position]
				all [set-word? item (length? position) >= 2][
					item: to word! item
					case [
						integer? position/2 [value: position/2]
						word? position/2 [
							constant-key: qualified scope position/2
							unless integer? value: select constants constant-key [
								fail ERROR-REFERENCE [
									"unknown enum value " mold position/2
								]
							]
						]
						true [fail ERROR-UNSUPPORTED "invalid enum value"]
					]
					position: skip position 2
				]
				true [fail ERROR-UNSUPPORTED "invalid enum declaration"]
			]
			constant-key: qualified scope item
			if select constants constant-key [
				fail ERROR-DUPLICATE ["duplicate enum name " mold constant-key]
			]
			repend constants [constant-key value]
			value: value + 1
		]
	]

	scan-imports: func [
		definitions scope uses [block!]
		/local position library canonical cc entries entry name key external spec kind id
	][
		if empty? definitions [fail ERROR-UNSUPPORTED "import block is empty"]
		position: definitions
		while [not tail? position][
			unless all [
				(length? position) >= 3
				string? position/1
				find [cdecl stdcall] position/2
				block? position/3
			][fail ERROR-UNSUPPORTED "invalid import group"]
			unless valid-name? position/1 [
				fail ERROR-NAME "invalid import library name"
			]
			library: to binary! position/1
			either canonical: select libraries library [
				library: canonical
			][repend libraries [library library]]
			cc: position/2
			entries: position/3
			if empty? entries [
				fail ERROR-UNSUPPORTED "empty import group is unsupported"
			]
			entry: entries
			while [not tail? entry][
				unless all [
					(length? entry) >= 3
					set-word? entry/1
					string? entry/2
					block? entry/3
				][fail ERROR-UNSUPPORTED "invalid import declaration"]
				name: to word! entry/1
				key: qualified scope name
				if any [
					select import-ids key
					select function-ids key
					select globals key
					select protected key
				][
					fail ERROR-DUPLICATE ["duplicate import " mold key]
				]
				unless valid-name? entry/2 [
					fail ERROR-NAME "invalid external import name"
				]
				external: to binary! entry/2
				spec: entry/3
				kind: either any [
					all [(length? spec) = 1 not block? spec/1]
					all [
						(length? spec) = 2
						find [pointer! struct!] spec/1
						block? spec/2
					]
				]['variable]['function]
				id: import-count + 1
				repend import-ids [key id]
				if all [kind = 'function infix-spec? spec][
					append infix-targets (0 - id)
				]
				append imports key
				append/only imports library
				append/only imports external
				append/only imports spec
				append imports kind
				append/only imports scope
				append/only imports uses
				append imports cc
				append imports none
				append imports none
				import-count: id
				entry: skip entry 3
			]
			position: skip position 3
		]
	]

	scan-block: func [
		values scope uses [block!]
		/local position name spec body child key kind target next-uses
			spelling id type-spec protected-id alias-target-ref alias-id
	][
		position: values
		while [not tail? position][
			case [
				all [
					position/1 = 'comment
					(length? position) >= 2
				][position: skip position 2]
				all [
					issue? position/1
					position/1 = #script
					(length? position) >= 2
					file? position/2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					position: next position
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
					word? position/2
					block? position/3
				][
					scan-enum position/2 position/3 scope
					position: skip position 3
				]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
					block? position/2
				][
					scan-imports position/2 scope uses
					position: skip position 2
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][
					key: qualified scope to word! position/1
					if select type-ids key [
						fail ERROR-DUPLICATE ["duplicate alias " mold key]
					]
					case [
						position/3 = 'pointer! [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "pointer alias is missing its pointee"]
							kind: 'alias
							type-spec: reduce [position/3 position/4]
							position: skip position 4
						]
						find [struct! union! function! subroutine!] position/3 [
							unless all [
								(length? position) >= 4
								block? position/4
							][fail ERROR-UNSUPPORTED "alias type is missing its spec"]
							kind: case [
								position/3 = 'struct! ['struct]
								position/3 = 'union! ['union]
								position/3 = 'function! ['function]
								true ['subroutine]
							]
							type-spec: position/4
							if find [struct union] kind [validate-aggregate kind type-spec]
							position: skip position 4
						]
						any [word? position/3 path? position/3][
							kind: 'alias
							type-spec: position/3
							position: skip position 3
						]
						true [fail ERROR-UNSUPPORTED "invalid alias declaration"]
					]
					id: type-count + 1
					repend type-ids [key id]
					append types key
					append types kind
					append/only types type-spec
					append/only types copy scope
					append/only types copy/deep uses
					type-count: id
					alias-count: alias-count + 1
					alias-id: 0
					alias-target-ref: either kind = 'alias [
						type-ref either block? type-spec [
							type-spec
						][reduce [type-spec]] scope uses
					][id]
					unless integer-kind? ref-kind alias-target-ref [
						alias-id: 1000 + alias-count
					]
					repend alias-type-ids [key alias-id]
				]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][
					name: position/1
					spec: position/3
					body: position/4
					key: qualified scope to word! name
					spelling: form key
					unless valid-name? spelling [
						fail ERROR-NAME "invalid RSIR function name"
					]
					if any [
						select function-ids key
						select import-ids key
						select globals key
						select protected key
					][
						fail ERROR-DUPLICATE ["duplicate function " mold key]
					]
					id: function-count + 1
					repend function-ids [key id]
					if infix-spec? spec [append infix-targets id]
					append/only functions to binary! spelling
					append/only functions spec
					append/only functions body
					append/only functions copy scope
					append/only functions copy/deep uses
					append functions none
					append functions none
					append functions none
					append functions none
					append functions none
					function-count: id
					position: skip position 4
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					name: to word! position/1
					key: qualified scope name
					if select contexts key [
						fail ERROR-DUPLICATE ["duplicate context " mold key]
					]
					repend contexts [key true]
					child: append copy scope name
					scan-block position/3 child uses
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2]
					block? position/3
				][
					target: position/2
					unless child: resolve-context target scope uses [
						fail ERROR-CONTEXT ["unknown context " mold target]
					]
					next-uses: copy/deep uses
					append/only next-uses child
					scan-block position/3 scope next-uses
					position: skip position 3
				]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'protect
				][
					name: to word! position/1
					key: qualified scope name
					if any [
						select function-ids key
						select import-ids key
						select globals key
						select protected key
					][fail ERROR-DUPLICATE ["duplicate protected value " mold key]]
					protected-id: 0
					unless protected-scalar? position/3 [
						global-count: global-count + 1
						protected-id: global-count
						repend globals [key global-count]
						spelling: form key
						unless valid-name? spelling [
							fail ERROR-NAME "invalid RSIR global name"
						]
						append/only global-data to binary! spelling
						append global-data none
						append global-data 0
						append global-data 0
						append global-data 0
					]
					repend protected [key protected-id]
					position: next position
				]
				set-word? position/1 [
					name: to word! position/1
					key: qualified scope name
					unless any [
						select protected key
						import-variable-id name scope uses
						resolve-name name scope uses globals
					][
						if any [select function-ids key select import-ids key][
							fail ERROR-DUPLICATE ["duplicate global " mold key]
						]
						global-count: global-count + 1
						repend globals [key global-count]
						spelling: form key
						unless valid-name? spelling [
							fail ERROR-NAME "invalid RSIR global name"
						]
						append/only global-data to binary! spelling
						append global-data none
						append global-data 0
						append global-data 0
						append global-data 0
					]
					position: next position
				]
				true [position: next position]
			]
		]
	]

	compile-source: func [source [block!] /local header][
		unless all [not tail? source source/1 = 'Red/System] [
			fail ERROR-ARGUMENTS "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2] [
			fail ERROR-ARGUMENTS "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]] [
			fail ERROR-ARGUMENTS "invalid Red/System program header"
		]

		scan-block skip source 2 copy [] copy []
		prepare-types
		prepare-functions
		prepare-imports
		compile-module skip source 2 copy [] copy []
		if module-kind = 3 [
			emit module-code reduce [return-op 0 0 0]
			add-module-function
		]
		if all [module-kind <> 3 not empty? module-code][
			fail ERROR-UNSUPPORTED "runtime module body requires a glue module"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
		lower-functions
	]

	write-types: func [type-output members [binary!] /local position kind definition
		spec scope uses field field-type info ref flags count code first signature
		params parameter target typed-arguments typed-argument
	][
		first: 0
		position: types
		while [not tail? position][
			kind: position/2
			case [
				kind = 'alias [
					code: select type-codes 'alias
					target: either block? position/3 [position/3][reduce [position/3]]
					emit type-output reduce [
						code
						type-ref target position/4 position/5
						0
						first
						0
					]
				]
				kind = 'typed-call [
					typed-arguments: position/3
					count: ((length? typed-arguments) - 1) / 2
					emit type-output reduce [
						select type-codes 'typed-call
						typed-arguments/1
						0
						first
						count
					]
					typed-argument: skip typed-arguments 1
					while [not tail? typed-argument][
						emit members reduce [typed-argument/1 typed-argument/2]
						typed-argument: skip typed-argument 2
					]
					first: first + count
				]
				kind = 'pointer [
					emit type-output reduce [
						select type-codes 'pointer-node position/3 0 first 0
					]
				]
				kind = 'array [
					emit type-output reduce [
						select type-codes 'array position/3 position/5 first position/4
					]
				]
				find [struct union] kind [
					code: select type-codes kind
					definition: position/3
					spec: aggregate-members kind definition
					scope: position/4
					uses: position/5
					count: (length? spec) / 2
					emit type-output reduce [
						code 0 either tagged-union? kind definition [tagged-type-flag][0]
						first count
					]
					while [not tail? spec][
						field: spec/1
						field-type: spec/2
						info: member-type-info kind definition field-type scope uses
						ref: info/1
						flags: info/2
						emit members reduce [ref flags]
						spec: skip spec 2
					]
					first: first + count
				]
				find [function subroutine] kind [
					signature: either kind = 'function [
						position/3
					][read-signature position/3 position/4 position/5]
					unless block? signature [
						fail ERROR-REFERENCE "function type signature is unresolved"
					]
					unless empty? signature/3 [
						fail ERROR-UNSUPPORTED "function type cannot declare locals"
					]
					params: signature/2
					count: (length? params) / 3
					emit type-output reduce [
						select type-codes kind
						signature/1
						signature/4
						first
						count
					]
					parameter: params
					while [not tail? parameter][
						emit members reduce [parameter/2 parameter/3]
						parameter: skip parameter 3
					]
					first: first + count
				]
				true [
					emit type-output reduce [(select type-codes kind) 0 0 first 0]
				]
			]
			position: skip position 5
		]
	]

	write-rsir: func [limit [integer!] /local output position name
		params locals flags record-offset param-count local-count first-param first-local
		instruction-count size entry id parameter import-records global-records
		function-records
		library external last-library library-offset external-offset names
		type-output members type-bytes member-bytes switch-count
	][
		type-output: make binary! (type-count * 20)
		members: make binary! 64
		write-types type-output members
		write-initializers
		type-bytes: length? type-output
		member-bytes: length? members
		names: copy strings
		switch-count: (length? switches) / 12
		output: make binary! (32 + type-bytes + member-bytes + (length? initializers)
			+ (length? switches)
			+ (length? strings)
			+ (length? function-code) + (import-count * 64)
			+ (global-count * 40) + (function-count * 112))
		append/dup output 0 32
		append output type-output
		append output members
		import-records: 33 + type-bytes + member-bytes
		global-records: import-records + (import-count * 32)
		function-records: global-records + (global-count * 24)
		append/dup output 0 (import-count * 32)
		append/dup output 0 (global-count * 24)
		append/dup output 0 (function-count * 36)

		position: imports
		last-library: none
		library-offset: 0
		first-param: 0
		id: 1
		while [not tail? position][
			library: position/2
			external: position/3
			unless same? library last-library [
				library-offset: length? names
				append names library
				last-library: library
			]
			external-offset: length? names
			append names external
			params: position/9
			param-count: either block? params [(length? params) / 3][0]
			record-offset: import-records + ((id - 1) * 32)
			change/part at output record-offset
				int-to-bin/to-bin32 library-offset 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? library) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 external-offset 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 (length? external) 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/8 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 position/10 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 param-count 4
			if block? params [
				parameter: params
				while [not tail? parameter][
					emit output reduce [parameter/2 parameter/3]
					parameter: skip parameter 3
				]
			]
			first-param: first-param + param-count
			id: id + 1
			position: skip position 10
		]

		position: global-data
		id: 1
		while [not tail? position][
			name: position/1
			unless integer? position/2 [
				fail ERROR-UNSUPPORTED ["global type is unresolved: " to string! name]
			]
			record-offset: global-records + ((id - 1) * 24)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/2 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 position/3 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 position/4 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 position/5 4
			append names name
			id: id + 1
			position: skip position 5
		]

		position: functions
		instruction-count: 0
		id: 1
		while [not tail? position][
			name: position/1
			params: position/7
			locals: position/8
			flags: position/9
			param-count: (length? params) / 3
			local-count: storage-local-count locals
			first-local: first-param + param-count
			record-offset: function-records + ((id - 1) * 36)
			change/part at output record-offset
				int-to-bin/to-bin32 (length? names) 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 position/6 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 flags 4
			change/part at output (record-offset + 16)
				int-to-bin/to-bin32 first-param 4
			change/part at output (record-offset + 20)
				int-to-bin/to-bin32 param-count 4
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 first-local 4
			change/part at output (record-offset + 28)
				int-to-bin/to-bin32 local-count 4
			change/part at output (record-offset + 32)
				int-to-bin/to-bin32 position/10 4
			parameter: params
			while [not tail? parameter][
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			parameter: locals
			while [not tail? parameter][
				if all [storage-local? parameter parameter/2 = 0][
					fail ERROR-UNSUPPORTED [
						"local type is unresolved: " mold parameter/1
					]
				]
				if storage-local? parameter [
					emit output reduce [parameter/2 parameter/3]
				]
				parameter: skip parameter 3
			]
			append names name
			first-param: first-local + local-count
			instruction-count: instruction-count + position/10
			id: id + 1
			position: skip position 10
		]
		append output initializers
		append output switches
		append output function-code
		append output names
		size: length? output
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [function-count][0]
		change/part output int-to-bin/to-bin32 module-kind 4
		change/part at output 5 int-to-bin/to-bin32 entry 4
		change/part at output 9 int-to-bin/to-bin32 type-count 4
		change/part at output 13 int-to-bin/to-bin32 import-count 4
		change/part at output 17 int-to-bin/to-bin32 function-count 4
		change/part at output 21 int-to-bin/to-bin32 instruction-count 4
		change/part at output 25 int-to-bin/to-bin32 global-count 4
		change/part at output 29 int-to-bin/to-bin32 switch-count 4
		output
	]

	; Bodies lower directly to typed postfix values and places.
	resolve-stack-call: func [
		value [word! path!]
		scope uses [block!]
		return: [integer! none!]
		/local id record
	][
		id: resolve-name value scope uses function-ids
		if integer? id [return id]
		id: resolve-name value scope uses import-ids
		unless integer? id [return none]
		record: skip imports ((id - 1) * 10)
		either record/5 = 'function [0 - id][none]
	]

	array-pointer-compatible?: func [
		expected actual [integer!]
		return: [logic!]
		/local info target
	][
		unless info: array-info actual [return false]
		unless target: pointee-ref expected [return false]
		(canonical-ref target) = canonical-ref info/1
	]

	address-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [pointer c-string struct union array] kind
	]

	reference-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [pointer c-string struct union array function null] kind
	]

	function-signatures-compatible?: func [
		expected actual depth [integer!]
		return: [logic!]
		/local left right left-parameter right-parameter
	][
		if depth > type-count [return false]
		left: function-signature expected
		right: function-signature actual
		unless all [block? left block? right][return false]
		if (left/4 and call-shape-flags) <> (right/4 and call-shape-flags)[
			return false
		]
		either left/1 = 0 [
			if right/1 <> 0 [return false]
		][
			if any [
				right/1 = 0
				not stack-type-compatible-at? left/1 right/1 (depth + 1)
			][return false]
		]
		if (length? left/2) <> length? right/2 [return false]
		left-parameter: left/2
		right-parameter: right/2
		while [not tail? left-parameter][
			if any [
				left-parameter/3 <> right-parameter/3
				not stack-type-compatible-at? left-parameter/2 right-parameter/2
					(depth + 1)
			][return false]
			left-parameter: skip left-parameter 3
			right-parameter: skip right-parameter 3
		]
		true
	]

	stack-type-compatible-at?: func [
		expected actual [integer!]
		depth [integer!]
		return: [logic!]
		/local expected-kind actual-kind
	][
		expected: canonical-ref expected
		actual: canonical-ref actual
		if expected = actual [return true]
		if any [expected = 0 actual = 0] [return false]
		expected-kind: ref-kind expected
		actual-kind: ref-kind actual
		if any [expected-kind = 'null actual-kind = 'null][
			return all [reference-kind? expected-kind reference-kind? actual-kind]
		]
		if array-pointer-compatible? expected actual [return true]
		if all [expected-kind = 'function actual-kind = 'function][
			return function-signatures-compatible? expected actual depth
		]
		if any [reference-kind? expected-kind reference-kind? actual-kind][return false]
		either all [expected > 0 actual > 0][
			false
		][
			expected-kind = actual-kind
		]
	]

	stack-type-compatible?: func [
		expected actual [integer!]
		return: [logic!]
	][
		stack-type-compatible-at? expected actual 0
	]

	integer-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [i8 byte u8 i16 u16 i32 u32 i64 u64] kind
	]

	integer-code: func [ref [integer!] return: [integer!] /local kind][
		if all [ref < 0 ref >= -8][return negate ref]
		kind: ref-kind ref
		case [
			kind = 'i8 [1]
			kind = 'byte [2]
			kind = 'u8 [2]
			kind = 'i16 [3]
			kind = 'u16 [4]
			kind = 'i32 [5]
			kind = 'u32 [6]
			kind = 'i64 [7]
			kind = 'u64 [8]
			true [0]
		]
	]

	integer-code-widens?: func [
		source target [integer!]
		return: [logic!]
		/local source-rank target-rank source-signed? target-signed?
	][
		if any [source = 0 target = 0][return false]
		source-rank: to integer! ((source + 1) / 2)
		target-rank: to integer! ((target + 1) / 2)
		if target-rank <= source-rank [return false]
		source-signed?: (source and 1) = 1
		target-signed?: (target and 1) = 1
		any [
			source-signed? = target-signed?
			all [not source-signed? target-signed?]
		]
	]

	lossless-integer-cast?: func [
		source target [integer!]
		return: [logic!]
		/local source-code target-code
	][
		if stack-type-compatible? target source [return true]
		source-code: integer-code source
		target-code: integer-code target
		integer-code-widens? source-code target-code
	]

	integer-common-ref: func [
		left right [integer!]
		return: [integer!]
		/local left-code right-code
	][
		if stack-type-compatible? left right [return left]
		left-code: integer-code left
		right-code: integer-code right
		if integer-code-widens? right-code left-code [return left]
		if integer-code-widens? left-code right-code [return right]
		0
	]

	coerce-stack: func [
		expected expected-flags [integer!]
		instructions [binary!]
		allow-float-literal? [logic!]
		/before position [binary!]
		return: [logic!]
		/local source-kind target-kind
	][
		if all [
			expected-flags = last-flags
			stack-type-compatible? expected last-type
		][
			if all [
				(canonical-ref expected) <> canonical-ref last-type
				any [
					last-type = -14
					(ref-kind expected) = 'function
					(ref-kind last-type) = 'function
				]
			][either before [
				emit-before position reduce [cast-op expected expected-flags 0]
			][
				emit instructions reduce [cast-op expected expected-flags 0]
			]]
			last-type: expected
			last-flags: expected-flags
			return true
		]
		source-kind: ref-kind last-type
		target-kind: ref-kind expected
		if all [
			last-flags = 0
			expected-flags <> 0
			find [struct union] target-kind
			find [struct union] source-kind
			stack-type-compatible? expected last-type
		][
			last-type: expected
			return true
		]
		if all [
			allow-float-literal?
			last-float-literal?
			expected-flags = 0
			last-flags = 0
			source-kind = 'f64
			target-kind = 'f32
		][
			either before [
				emit-before position reduce [cast-op expected 0 0]
			][
				emit instructions reduce [cast-op expected 0 0]
			]
			last-type: expected
			last-flags: 0
			last-float-literal?: false
			return true
		]
		unless all [
			expected-flags = 0
			last-flags = 0
			lossless-integer-cast? last-type expected
		][return false]
		either before [
			emit-before position reduce [cast-op expected 0 0]
		][
			emit instructions reduce [cast-op expected 0 0]
		]
		last-type: expected
		last-flags: 0
		last-float-literal?: false
		true
	]

	hex-digit: func [value [char!] return: [integer!] /local code][
		code: to integer! value
		case [
			all [code >= 48 code <= 57][code - 48]
			all [code >= 65 code <= 70][code - 55]
			true [-1]
		]
	]

	hex-word: func [digits [string!] return: [integer! none!] /local value digit][
		value: 0
		foreach character digits [
			digit: hex-digit character
			if digit < 0 [return none]
			value: (value << 4) or digit
		]
		value
	]

	greater-digits?: func [left right [string!] return: [logic!]][
		any [
			(length? left) > (length? right)
			all [(length? left) = (length? right) left > right]
		]
	]

	decimal-bits: func [
		digits [string!]
		negative? [logic!]
		return: [block! none!]
		/local limbs carry value digit index low high
	][
		if empty? digits [return none]
		limbs: copy [0 0 0 0]
		foreach character digits [
			digit: (to integer! character) - (to integer! #"0")
			if any [digit < 0 digit > 9][return none]
			carry: digit
			repeat index 4 [
				value: (limbs/:index * 10) + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
			if carry <> 0 [return none]
		]
		if negative? [
			repeat index 4 [limbs/:index: 65535 - limbs/:index]
			carry: 1
			repeat index 4 [
				value: limbs/:index + carry
				limbs/:index: value and 65535
				carry: to integer! (value / 65536)
			]
		]
		low: (limbs/2 << 16) or limbs/1
		high: (limbs/4 << 16) or limbs/3
		reduce [low high]
	]

	wide-literal: func [
		value
		return: [block! none!]
		/local spelling payload digits negative? bits low high ref
	][
		unless issue? value [return none]
		spelling: form value
		case [
			find/match spelling "u64h-" [
				payload: uppercase copy skip spelling 5
				if any [empty? payload (length? payload) > 16][return none]
				insert/dup payload #"0" (16 - length? payload)
				high: hex-word copy/part payload 8
				low: hex-word skip payload 8
				unless all [integer? low integer? high][return none]
				ref: either high < 0 [-8][-7]
				reduce [ref low high]
			]
			find/match spelling "i64-" [
				payload: skip spelling 4
				negative?: all [not empty? payload payload/1 = #"n"]
				if negative? [payload: next payload]
				digits: copy payload
				if greater-digits? digits either negative? [
					"9223372036854775808"
				]["9223372036854775807"][return none]
				bits: decimal-bits digits negative?
				if none? bits [return none]
				reduce [-7 bits/1 bits/2]
			]
			find/match spelling "u64-" [
				digits: copy skip spelling 4
				if greater-digits? digits "18446744073709551615" [return none]
				bits: decimal-bits digits false
				if none? bits [return none]
				ref: either bits/2 < 0 [-8][-7]
				reduce [ref bits/1 bits/2]
			]
			true [none]
		]
	]

	little-word: func [data [binary!] return: [integer!]][
		(to integer! data/1)
			or ((to integer! data/2) << 8)
			or ((to integer! data/3) << 16)
			or ((to integer! data/4) << 24)
	]

	integer-literal-since: func [
		output [binary!]
		offset [integer!]
		return: [integer! none!]
		/local instruction ref value high
	][
		unless (length? output) = (offset + 16) [return none]
		instruction: at output (offset + 1)
		unless (little-word instruction) = literal-op [return none]
		ref: little-word skip instruction 4
		unless (ref-kind ref) = 'i32 [return none]
		value: little-word skip instruction 8
		high: little-word skip instruction 12
		unless high = (either value < 0 [-1][0]) [return none]
		value
	]

	float-literal?: func [value return: [logic!]][
		any [
			float? value
			all [issue? value not none? select ieee-754/special64 value]
		]
	]

	protected-scalar?: func [value return: [logic!] /local wide][
		case [
			any [integer? value float? value char? value][true]
			issue? value [
				wide: wide-literal value
				any [block? wide float-literal? value]
			]
			true [false]
		]
	]

	float-bits: func [
		value
		kind [word!]
		return: [block! none!]
		/local bytes width low high
	][
		width: either kind = 'f32 [4][either kind = 'f64 [8][0]]
		if width = 0 [return none]
		bytes: either width = 4 [
			ieee-754/to-binary32/rev value
		][ieee-754/to-binary64/rev value]
		unless all [binary? bytes (length? bytes) = width][return none]
		low: little-word bytes
		high: either width = 8 [little-word skip bytes 4][0]
		reduce [low high]
	]

	add-static-bytes: func [
		value [binary!]
		nul? protected? [logic!]
		return: [integer!]
		/local data offset ref id record
	][
		data: copy value
		if nul? [append data 0]
		offset: length? strings
		append strings data
		ref: intern-array -15 length? data 1
		id: add-hidden-global ref (
			inline-flag + either protected? [protected-flag][0]
		)
		record: skip global-data ((id - 1) * 5)
		set-global-initializer record reduce [
			bytes-initializer offset length? data 0
		]
		id
	]

	static-literal-info: func [
		value
		scope uses [block!]
		protected? [logic!]
		return: [block! none!]
		/local wide bits id key target record ref protected-info
	][
		case [
			issue? value [
				wide: wide-literal value
				if block? wide [
					return reduce [
						wide/1 scalar-initializer wide/2 wide/3 0
					]
				]
				bits: either float-literal? value [float-bits value 'f64][none]
				if block? bits [
					return reduce [-10 scalar-initializer bits/1 bits/2 0]
				]
			]
			float? value [
				bits: float-bits value 'f64
				if block? bits [
					return reduce [-10 scalar-initializer bits/1 bits/2 0]
				]
			]
			integer? value [
				return reduce [
					-5 scalar-initializer value either value < 0 [-1][0] 0
				]
			]
			char? value [
				id: to integer! value
				if id <= 255 [return reduce [-15 scalar-initializer id 0 0]]
			]
			logic? value [
				return reduce [
					-11 scalar-initializer either value [1][0] 0 0
				]
			]
			all [word? value find [true false yes no] value][
				return reduce [
					-11 scalar-initializer either find [true yes] value [1][0] 0 0
				]
			]
			string? value [
				id: add-static-bytes to binary! value true protected?
				return reduce [-13 address-initializer global-address id 0]
			]
			any [get-word? value get-path? value][
				target: either get-word? value [to word! value][to path! value]
				id: resolve-name target scope uses function-ids
				if integer? id [
					ref: call-signature-ref id
					return reduce [ref address-initializer function-address id 0]
				]
				id: resolve-name target scope uses import-ids
				if integer? id [
					record: skip imports ((id - 1) * 10)
					if record/5 = 'function [
						ref: call-signature-ref (0 - id)
						return reduce [ref address-initializer import-address id 0]
					]
				]
				id: resolve-name target scope uses globals
				if integer? id [
					record: skip global-data ((id - 1) * 5)
					if integer? record/2 [
						ref: address-reference-ref record/2 record/3
						if integer? ref [
							return reduce [
								ref address-initializer global-address id 0
							]
						]
					]
				]
			]
			any [word? value path? value][
				protected-info: resolve-name value scope uses protected-values
				if block? protected-info [return copy protected-info]
				key: qualified scope value
				id: select constants key
				if integer? id [
					return reduce [
						-5 scalar-initializer id either id < 0 [-1][0] 0
					]
				]
			]
		]
		none
	]

	static-literal-width: func [ref [integer!] return: [integer!] /local kind][
		kind: ref-kind ref
		case [
			find [i8 byte u8] kind [1]
			find [i16 u16] kind [2]
			find [i32 u32 f32 logic] kind [4]
			find [i64 u64 f64 pointer c-string function null] kind [8]
			true [0]
		]
	]

	array-literal-info: func [
		value [block! binary!]
		scope uses [block!]
		protected? [logic!]
		return: [block!]
		/local values item info element count offset width item-width uniform?
	][
		if empty? value [fail ERROR-UNSUPPORTED "literal array is empty"]
		if binary? value [
			offset: length? strings
			append strings value
			return reduce [
				intern-array -15 length? value 1
				reduce [bytes-initializer offset length? value 0]
			]
		]

		values: make block! ((length? value) * 4)
		element: 0
		count: 0
		width: 0
		uniform?: true
		foreach item value [
			info: static-literal-info item scope uses protected?
			unless block? info [
				fail ERROR-UNSUPPORTED ["invalid literal array item " mold item]
			]
			item-width: static-literal-width info/1
			if item-width = 0 [
				fail ERROR-UNSUPPORTED ["invalid literal array item " mold item]
			]
			if item-width > width [width: item-width]
			either element = 0 [
				element: info/1
			][
				if (canonical-ref element) <> canonical-ref info/1 [uniform?: false]
			]
			repend values [info/2 info/3 info/4 info/5]
			count: count + 1
		]
		unless uniform? [
			if width < 4 [width: 4]
			element: either width = 8 [-8][-5]
		]
		reduce [intern-array element count width values]
	]

	stack-array-literal: func [
		position scope uses [block!]
		instructions [binary!]
		return: [block!]
		/local info id record
	][
		info: array-literal-info position/1 scope uses false
		id: add-hidden-global info/1 inline-flag
		record: skip global-data ((id - 1) * 5)
		set-global-initializer record info/2
		emit instructions reduce [address-op global-address id 0]
		emit instructions reduce [load-op 0 0 0]
		last-type: info/1
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		next position
	]

	float-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [f32 f64] kind
	]

	float-cast-compatible?: func [
		source target [integer!]
		keep? [logic!]
		return: [logic!]
		/local source-kind target-kind
	][
		source-kind: ref-kind source
		target-kind: ref-kind target
		unless any [float-kind? source-kind float-kind? target-kind][return true]
		if keep? [
			return any [
				source-kind = target-kind
				all [source-kind = 'i32 target-kind = 'f32]
				all [source-kind = 'f32 target-kind = 'i32]
			]
		]
		any [
			source-kind = target-kind
			all [float-kind? source-kind float-kind? target-kind]
			all [source-kind = 'i32 float-kind? target-kind]
			all [float-kind? source-kind target-kind = 'i32]
		]
	]

	same-stack-type?: func [
		left left-flags right right-flags [integer!]
		return: [logic!]
	][
		all [
			(canonical-ref left) = canonical-ref right
			left-flags = right-flags
		]
	]

	stack-unary: func [
		operation [integer!]
		instructions [binary!]
		/local kind
	][
		kind: ref-kind last-type
		unless all [
			operation = not-operation
			last-flags = 0
			any [integer-kind? kind kind = 'logic]
		][fail ERROR-REFERENCE "invalid operand type for not"]
		emit instructions reduce [unary-op operation 0 0]
	]

	stack-binary: func [
		operation left left-flags [integer!]
		right-start [integer!]
		instructions [binary!]
		/local right right-flags left-kind right-kind common valid? comparison?
			scope-state anchor overflow-data right-literal shift-limit tracked?
	][
		right: last-type
		right-flags: last-flags
		left-kind: ref-kind left
		right-kind: ref-kind right
		valid?: false
		comparison?: operation >= 13

		case [
			operation <= 6 [
				valid?: any [
					all [
						integer-kind? left-kind
						integer-kind? right-kind
						left-flags = 0
						right-flags = 0
					]
					all [
						float-kind? left-kind
						left-kind = right-kind
						left-flags = 0
						right-flags = 0
						any [operation <= 4 left-kind = 'f32]
					]
					all [
						operation <= 2
						address-kind? left-kind
						left-flags = 0
						any [
							all [integer-kind? right-kind right-flags = 0]
							all [address-kind? right-kind right-flags = 0]
						]
					]
				]
			]
			operation <= 9 [
				valid?: all [
					integer-kind? left-kind
					right-kind = 'i32
					left-flags = 0
					right-flags = 0
				]
			]
			operation <= 12 [
				valid?: all [
					any [integer-kind? left-kind left-kind = 'logic]
					same-stack-type? left left-flags right right-flags
				]
			]
			comparison? [
				common: either all [
					left-flags = 0
					right-flags = 0
					integer-kind? left-kind
					integer-kind? right-kind
				][integer-common-ref left right][0]
				valid?: any [
					common <> 0
					all [
						operation <= 14
						left-flags = 0
						right-flags = 0
						any [left-kind = 'null right-kind = 'null]
						reference-kind? left-kind
						reference-kind? right-kind
					]
					all [
						same-stack-type? left left-flags right right-flags
						any [
							float-kind? left-kind
							address-kind? left-kind
							all [
								find [function null] left-kind
								operation <= 14
							]
							all [left-kind = 'logic operation <= 14]
						]
					]
				]
			]
			true [valid?: false]
		]
		unless valid? [fail ERROR-REFERENCE "incompatible binary operands"]

		anchor: 0
		overflow-data: 0
		tracked?: false
		unless empty? overflows [
			scope-state: last overflows
			if block? scope-state [
				case [
					all [operation <= 3 integer-kind? left-kind][
						tracked?: true
					]
					all [
						operation >= 4
						operation <= 6
						left-kind = 'i32
					][tracked?: true]
					operation = 7 [
						right-literal: integer-literal-since instructions right-start
						if integer? right-literal [
							shift-limit: either find [i64 u64] left-kind [63][31]
							if all [right-literal > 0 right-literal <= shift-limit][
								tracked?: true
								overflow-data: right-literal
							]
						]
					]
					true [0]
				]
				if tracked? [
					anchor: scope-state/1
					scope-state/3: scope-state/3 + 1
				]
			]
		]
		emit instructions reduce [binary-op operation anchor overflow-data]
		last-float-literal?: false
		either comparison? [
			last-type: -11
			last-flags: 0
		][
			last-type: left
			last-flags: left-flags
		]
	]

	stack-storage-info: func [
		name [word!]
		params [block!]
		locals [block!]
		return: [block! none!]
		/local position index
	][
		position: params
		index: 1
		while [not tail? position][
			if position/1 = name [return reduce [index position]]
			position: skip position 3
			index: index + 1
		]
		position: locals
		while [not tail? position][
			if position/1 = name [return reduce [index position]]
			if storage-local? position [index: index + 1]
			position: skip position 3
		]
		none
	]

	subroutine-body: func [
		name [word!]
		return: [block! none!]
		/local position
	][
		position: find/skip subroutine-bodies name 2
		either position [position/2][none]
	]

	set-subroutine-body: func [
		name [word!]
		body [block!]
		/local position
	][
		position: find/skip subroutine-bodies name 2
		either position [
			change/only next position copy/deep body
		][
			append subroutine-bodies name
			append/only subroutine-bodies copy/deep body
		]
	]

	stack-use: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local spec body cursor names-start name ref flags record-index record
			active-records stopped?
	][
		unless function-active? [
			fail ERROR-CONTEXT "USE is only allowed inside a function"
		]
		unless all [
			(length? position) >= 3
			block? position/2
			block? position/3
		][fail ERROR-UNSUPPORTED "USE requires a local specification and body"]
		spec: position/2
		body: position/3
		active-records: make block! 8
		cursor: spec
		while [not tail? cursor][
			unless word? cursor/1 [
				fail ERROR-UNSUPPORTED ["invalid USE local " mold cursor/1]
			]
			names-start: cursor
			while [all [not tail? cursor word? cursor/1]][
				if refinement? cursor/1 [
					fail ERROR-UNSUPPORTED "USE does not accept refinements"
				]
				cursor: next cursor
			]
			unless all [not tail? cursor block? cursor/1][
				fail ERROR-UNSUPPORTED "USE local is missing its type"
			]
			ref: type-ref cursor/1 scope uses
			flags: type-flags cursor/1 scope uses
			if (ref-kind ref) = 'subroutine [
				fail ERROR-UNSUPPORTED "subroutines cannot be defined by USE"
			]
			while [names-start <> cursor][
				name: names-start/1
				if stack-storage-info name params locals [
					fail ERROR-DUPLICATE ["duplicate USE local " mold name]
				]
				record-index: select use-local-slots name
				either integer? record-index [
					record: skip locals ((record-index - 1) * 3)
					unless all [
						stack-type-compatible? record/2 ref
						record/3 = flags
					][
						fail ERROR-REFERENCE [
							"conflicting USE local type " mold name
						]
					]
					record/1: name
				][
					record-index: 1 + ((length? locals) / 3)
					repend use-local-slots [name record-index]
					append locals name
					append locals ref
					append locals flags
				]
				append active-records record-index
				names-start: next names-start
			]
			cursor: next cursor
		]
		stack-block body scope uses instructions params locals statement-value
		stopped?: last-stopped?
		; The slots remain available for a later same-name USE, but their source
		; names leave the active lexical environment with this body.
		foreach record-index active-records [
			record: skip locals ((record-index - 1) * 3)
			record/1: none
		]
		last-type: 0
		last-flags: 0
		last-stopped?: stopped?
		skip position 3
	]

	stack-subroutine: func [
		position [block!]
		name [word!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local body body-context
	][
		body: subroutine-body name
		unless block? body [
			fail ERROR-REFERENCE ["subroutine is used before its definition " mold name]
		]
		if find subroutine-stack name [
			fail ERROR-CONTEXT ["recursive subroutine " mold name]
		]
		append subroutine-stack name
		; A subroutine is called code even though its body is expanded here.
		append/only overflows none
		body-context: either value-context = statement-value [
			statement-value
		][tail-value]
		stack-block body scope uses instructions params locals body-context
		remove back tail overflows
		remove find subroutine-stack name
		next position
	]

	stack-read-type: func [
		position [block!]
		scope uses [block!]
		return: [block!]
		/local type token
	][
		unless all [not tail? position any [word? position/1 path? position/1]][
			fail ERROR-UNSUPPORTED "missing logical type"
		]
		token: position/1
		type: reduce [token]
		position: next position
		if all [
			word? token
			find [pointer! struct! union! function! subroutine!] token
			not tail? position
			block? position/1
		][
			append/only type position/1
			position: next position
		]
		last-type: type-ref type scope uses
		last-flags: type-flags type scope uses
		reduce [position last-type last-flags]
	]

	stack-cast: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local type-info target-ref target-flags target-kind source keep? value
			literal-end bits next-position source-ref source-flags source-kind
			source-literal? valid? address-source?
	][
		type-info: stack-read-type next position scope uses
		target-ref: type-info/2
		target-flags: type-info/3
		target-kind: ref-kind target-ref
		source: type-info/1
		keep?: false
		if all [not tail? source source/1 = 'keep][
			keep?: true
			source: next source
		]
		if tail? source [fail ERROR-UNSUPPORTED "cast is missing its value"]
		value: source/1
		literal-end: next source
		if all [
			target-flags = 0
			float-kind? target-kind
			any [
				all [not keep? any [float-literal? value integer? value]]
				all [keep? target-kind = 'f32 integer? value]
			]
			any [tail? literal-end none? select binary-operations literal-end/1]
		][
			bits: either keep? [
				reduce [value 0]
			][
				float-bits either integer? value [to float! value][value] target-kind
			]
			unless block? bits [fail ERROR-UNSUPPORTED "invalid floating-point literal"]
			emit instructions reduce [literal-op target-ref bits/1 bits/2]
			last-type: target-ref
			last-flags: 0
			last-float-literal?: all [target-kind = 'f64 float-literal? value]
			return literal-end
		]

		address-source?: false
		if all [
			target-kind = 'function
			any [word? source/1 path? source/1]
			not any [get-word? source/1 get-path? source/1]
		][
			address-source?: stack-address source/1 scope uses instructions params locals
			if address-source? [
				emit instructions reduce [load-op 0 0 0]
				next-position: next source
			]
		]
		unless address-source? [
			next-position: stack-value source scope uses instructions params locals
				expression-value
		]
		source-ref: last-type
		source-flags: last-flags
		source-kind: ref-kind source-ref
		source-literal?: last-float-literal?
		if source-ref = -14 [
			fail ERROR-REFERENCE "null cannot be explicitly cast"
		]
		if any [source-kind = 'function target-kind = 'function][
			valid?: either source-kind = 'function [
				not none? find [i32 pointer function] target-kind
			][
				any [
					source-kind = 'i32
					not none? find [c-string pointer struct union array function]
						source-kind
				]
			]
			unless valid? [fail ERROR-REFERENCE "invalid function pointer cast"]
		]
		if all [
			any [float-kind? ref-kind source-ref float-kind? target-kind]
			any [
				target-flags <> 0
				source-flags <> 0
				not float-cast-compatible? source-ref target-ref keep?
			]
		][fail ERROR-REFERENCE "incompatible floating-point cast"]
		unless all [
			target-flags = source-flags
			stack-type-compatible? target-ref source-ref
			any [
				(canonical-ref target-ref) = canonical-ref source-ref
				all [
					(ref-kind target-ref) <> 'function
					(ref-kind source-ref) <> 'function
				]
			]
		][
			emit instructions reduce [cast-op target-ref target-flags either keep? [1][0]]
		]
		last-type: target-ref
		last-flags: target-flags
		last-float-literal?: all [source-literal? target-kind = 'f64]
		next-position
	]

	stack-address: func [
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		/write
		return: [logic!]
		/local id position part parts index base current flags info storage kind
			element bits place?
	][
		if word? target [
			storage: stack-storage-info target params locals
			if block? storage [
				if (ref-kind storage/2/2) = 'subroutine [
					fail ERROR-REFERENCE ["subroutine has no address " mold target]
				]
				emit instructions reduce [address-op local-address storage/1 0]
				position: storage/2
				last-type: position/2
				last-flags: position/3
				return true
			]
		]
		id: resolve-name target scope uses globals
		if integer? id [
			emit instructions reduce [address-op global-address id 0]
			position: skip global-data ((id - 1) * 5)
			last-type: any [position/2 0]
			last-flags: position/3 and inline-flag
			return true
		]
		id: import-variable-id target scope uses
		if integer? id [
			emit instructions reduce [address-op import-address id 0]
			position: skip imports ((id - 1) * 10)
			last-type: position/8
			last-flags: 0
			return true
		]
		if word? target [return false]
		parts: to block! target
		if (length? parts) < 2 [return false]
		base: parts/1
		stack-value reduce [base] scope uses instructions params locals expression-value
		current: last-type
		flags: last-flags
		place?: false
		index: 2
		while [index <= length? parts][
			part: parts/:index
			kind: ref-kind current
			case [
				find [struct union] kind [
					unless word? part [
						fail ERROR-REFERENCE ["aggregate member must be a word: " mold part]
					]
					if all [place? flags = 0][
						emit instructions reduce [load-op 0 0 0]
						place?: false
					]
					info: member-info current part
					unless block? info [
						fail ERROR-REFERENCE ["unknown member " mold part]
					]
					emit instructions reduce [
						member-op info/1 either all [
							write tagged-union-ref? current
						][info/1 + 1][0] 0
					]
					current: info/2
					flags: info/3
					place?: true
				]
				find [pointer c-string array] kind [
					if place? [
						emit instructions reduce [load-op 0 0 0]
						flags: 0
						place?: false
					]
					element: pointee-ref current
					unless integer? element [
						fail ERROR-REFERENCE ["pointer has no indexable pointee: " mold part]
					]
					case [
						all [kind = 'pointer word? part part = 'value][
							emit instructions reduce [index-op 0 0 0]
						]
						integer? part [
							bits: one-based-index-bits part
							emit instructions reduce [index-op bits/1 0 bits/2]
						]
						word? part [
							stack-value reduce [part] scope uses instructions params locals
								expression-value
							unless all [
								last-flags = 0
								stack-type-compatible? -5 last-type
							][fail ERROR-REFERENCE "pointer index must be an integer!"]
							emit instructions reduce [index-op 0 1 0]
						]
						true [
							fail ERROR-REFERENCE ["invalid pointer index " mold part]
						]
					]
					current: element
					flags: 0
					place?: true
				]
				true [fail ERROR-REFERENCE ["value cannot be selected by path: " mold target]]
			]
			index: index + 1
		]
		last-type: current
		last-flags: flags
		true
	]

	stack-custom-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref signature-ref [integer!]
		return: [block!]
		/local position-after
	][
		position-after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			stack-type-compatible? -5 last-type
		][fail ERROR-REFERENCE ["custom call count must be an integer!: " mold value]]
		emit instructions reduce [
			call-op target 1 either target = 0 [signature-ref][return-ref]
		]
		last-type: return-ref
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		position-after
	]

	stack-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local record return-ref parameters flags mode
			parameter count expected expected-flags position-after
	][
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			return-ref: record/6
			parameters: record/7
			flags: record/9
		][
			record: skip imports (((0 - target) - 1) * 10)
			return-ref: record/8
			parameters: record/9
			flags: record/10
		]
		mode: flags and (variadic-flag + typed-flag + custom-flag)
		if mode <> 0 [
			case [
				mode = variadic-flag [
					return stack-variadic-call target value position scope uses instructions
						params locals return-ref parameters flags 0
				]
				mode = typed-flag [
					return stack-typed-call target value position scope uses instructions
						params locals return-ref parameters flags
						(call-signature-ref target)
				]
				mode = custom-flag [
					return stack-custom-call target value position scope uses instructions
						params locals return-ref 0
				]
				true [fail ERROR-UNSUPPORTED "unsupported call attributes"]
			]
		]
		count: 0
		parameter: parameters
		position-after: next position
		while [not tail? parameter][
			position-after: stack-value position-after scope uses instructions params locals
				expression-value
			expected: parameter/2
			expected-flags: parameter/3
			unless coerce-stack expected expected-flags instructions true [
				fail ERROR-REFERENCE [
					"argument type does not match function " mold value
				]
			]
			count: count + 1
			parameter: skip parameter 3
		]
		emit instructions reduce [call-op target count return-ref]
		last-type: return-ref
		last-flags: 0
		position-after
	]

	stack-infix-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local record return-ref parameters expected expected-flags position-after
	][
		if path? value [
			fail ERROR-UNSUPPORTED "infix functions cannot be called using a path"
		]
		either target > 0 [
			record: skip functions ((target - 1) * 10)
			return-ref: record/6
			parameters: record/7
		][
			record: skip imports (((0 - target) - 1) * 10)
			return-ref: record/8
			parameters: record/9
		]
		unless last-type <> 0 [
			fail ERROR-REFERENCE ["infix function is missing its left argument " mold value]
		]
		expected: parameters/2
		expected-flags: parameters/3
		unless coerce-stack expected expected-flags instructions true [
			fail ERROR-REFERENCE ["left argument does not match infix function " mold value]
		]
		position-after: stack-primary next position scope uses instructions params locals
			expression-value
		unless all [not last-stopped? last-type <> 0][
			fail ERROR-REFERENCE ["infix function is missing its right argument " mold value]
		]
		expected: parameters/5
		expected-flags: parameters/6
		unless coerce-stack expected expected-flags instructions true [
			fail ERROR-REFERENCE ["right argument does not match infix function " mold value]
		]
		emit instructions reduce [call-op target 2 return-ref]
		last-type: return-ref
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		position-after
	]

	packed-variadic-signature?: func [
		parameters [block!]
		return: [logic!]
		/local count tail-parameter
	][
		count: (length? parameters) / 3
		unless any [count = 2 count = 3][return false]
		unless all [
			parameters/3 = 0
			(ref-kind parameters/2) = 'i32
			parameters/6 = 0
			find [pointer struct union] ref-kind parameters/5
		][return false]
		if count = 3 [
			tail-parameter: skip parameters 6
			unless all [
				tail-parameter/3 = 0
				(ref-kind tail-parameter/2) = 'i32
			][return false]
		]
		true
	]

	typed-list-signature?: func [
		parameters [block!]
		return: [logic!]
		/local target base record spec field-spec field-count field-ref
	][
		unless (length? parameters) = 6 [return false]
		unless all [
			parameters/3 = 0
			(ref-kind parameters/2) = 'i32
			parameters/6 = 0
		][return false]
		unless target: pointee-ref parameters/5 [return false]
		base: canonical-ref target
		unless all [base > 0 base <= type-count][return false]
		record: skip types ((base - 1) * 5)
		unless record/2 = 'struct [return false]
		spec: aggregate-members record/2 record/3
		field-count: (length? spec) / 2
		unless any [field-count = 3 field-count = 4 field-count = 5][
			return false
		]
		field-ref: type-ref spec/2 record/4 record/5
		unless (ref-kind field-ref) = 'i32 [return false]
		if field-count >= 4 [
			field-spec: skip spec 2
			field-ref: type-ref field-spec/2 record/4 record/5
			unless (ref-kind field-ref) = 'i32 [return false]
		]
		true
	]

	stack-typed-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref [integer!]
		parameters [block!]
		flags signature-ref [integer!]
		return: [block!]
		/local cursor next-value arguments count type-id
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED [
				"typed call requires an argument block: " mold value
			]
		]
		unless typed-list-signature? parameters [
			fail ERROR-UNSUPPORTED [
				"typed function must declare count and typed-value list: " mold value
			]
		]
		arguments: reduce [signature-ref]
		cursor: position/2
		count: 0
		while [not tail? cursor][
			next-value: stack-value cursor scope uses instructions params locals
				expression-value
			unless all [last-type <> 0 last-flags = 0][
				fail ERROR-UNSUPPORTED [
					"typed argument must be a scalar or reference value: " mold value
				]
			]
			type-id: typed-type-id last-type
			unless type-id > 0 [
				fail ERROR-UNSUPPORTED [
					"typed argument has no runtime type ID: " mold value
				]
			]
			append arguments last-type
			append arguments type-id
			count: count + 1
			cursor: next-value
		]
		emit instructions reduce [
			call-op target count intern-typed-call signature-ref arguments
		]
		last-type: return-ref
		last-flags: 0
		skip position 2
	]

	stack-variadic-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return-ref [integer!]
		parameters [block!]
		flags signature-ref [integer!]
		return: [block!]
		/local cursor next-value parameter count expected expected-flags cdecl?
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED ["variadic call requires an argument block: " mold value]
		]
		cdecl?: (flags and 3) = 1
		unless any [
			cdecl?
			all [target < 0 empty? parameters]
			all [target >= 0 packed-variadic-signature? parameters]
		][
			fail ERROR-UNSUPPORTED [
				"variadic function must declare count, list, and optional size: "
				mold value
			]
		]
		cursor: position/2
		parameter: parameters
		count: 0
		while [not tail? cursor][
			next-value: stack-value cursor scope uses instructions params locals
				expression-value
			if last-type = 0 [
				fail ERROR-REFERENCE ["variadic argument has no value: " mold value]
			]
			count: count + 1
			either all [cdecl? not tail? parameter][
				expected: parameter/2
				expected-flags: parameter/3
				unless coerce-stack expected expected-flags instructions true [
					fail ERROR-REFERENCE [
						"argument type does not match function " mold value
					]
				]
				parameter: skip parameter 3
			][
				if all [
					cdecl?
					(flags and objc-flag) = 0
					(ref-kind last-type) = 'f32
				][
					emit instructions reduce [cast-op -10 0 0]
					last-type: -10
					last-flags: 0
					last-float-literal?: false
				]
			]
			cursor: next-value
		]
		if all [cdecl? not tail? parameter][
			fail ERROR-REFERENCE ["not enough arguments for function " mold value]
		]
		emit instructions reduce [
			call-op target count either target = 0 [signature-ref][return-ref]
		]
		last-type: return-ref
		last-flags: 0
		skip position 2
	]

	stack-indirect-call: func [
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local signature signature-ref return-ref parameters mode parameter
			count expected expected-flags position-after
	][
		signature-ref: canonical-ref last-type
		signature: function-signature signature-ref
		unless block? signature [
			fail ERROR-REFERENCE ["value is not callable " mold value]
		]
		emit instructions reduce [load-op 0 0 0]
		return-ref: signature/1
		parameters: signature/2
		mode: signature/4 and (variadic-flag + typed-flag + custom-flag)
		if mode <> 0 [
			case [
				mode = variadic-flag [
					return stack-variadic-call 0 value position scope uses instructions
						params locals return-ref parameters signature/4 signature-ref
				]
				mode = typed-flag [
					return stack-typed-call 0 value position scope uses instructions params
						locals return-ref parameters signature/4 signature-ref
				]
				mode = custom-flag [
					return stack-custom-call 0 value position scope uses instructions params
						locals return-ref signature-ref
				]
				true [fail ERROR-UNSUPPORTED "unsupported call attributes"]
			]
		]
		count: 0
		parameter: parameters
		position-after: next position
		while [not tail? parameter][
			position-after: stack-value position-after scope uses instructions params locals
				expression-value
			expected: parameter/2
			expected-flags: parameter/3
			unless coerce-stack expected expected-flags instructions true [
				fail ERROR-REFERENCE [
					"argument type does not match function value " mold value
				]
			]
			count: count + 1
			parameter: skip parameter 3
		]
		emit instructions reduce [call-op 0 count signature-ref]
		last-type: return-ref
		last-flags: 0
		position-after
	]

	stack-block: func [
		body scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		/local position next-position keep? stopped?
	][
		position: body
		last-type: 0
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		while [not tail? position][
			last-stopped?: false
			either any [set-word? position/1 set-path? position/1][
				next-position: stack-assignment position scope uses instructions
					params locals false
			][
				next-position: stack-value position scope uses instructions params locals
					value-context
			]
			stopped?: last-stopped?
			keep?: all [value-context = tail-value tail? next-position]
			unless keep? [
				if last-type <> 0 [emit instructions reduce [drop-op 0 0 0]]
				last-type: 0
				last-flags: 0
			]
			position: next-position
			last-stopped?: all [tail? position stopped?]
		]
	]

	stack-overflow: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local scope-state stopped? jump-patch target
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "OVERFLOW? requires a body block"
		]
		scope-state: reduce [
			instruction-here instructions
			(length? instructions) + 5
			0
		]
		append/only overflows scope-state
		emit instructions reduce [overflow-op 0 0 0]
		stack-block position/2 scope uses instructions params locals statement-value
		stopped?: last-stopped?
		remove back tail overflows

		either scope-state/3 = 0 [
			unless stopped? [
				emit instructions reduce [literal-op -11 0 0]
			]
		][
			either stopped? [
				target: instruction-here instructions
				patch-control instructions scope-state/2 target
				emit instructions reduce [literal-op -11 1 0]
			][
				emit instructions reduce [literal-op -11 0 0]
				jump-patch: emit-control instructions jump-op 0
				target: instruction-here instructions
				patch-control instructions scope-state/2 target
				emit instructions reduce [literal-op -11 1 0]
				patch-control instructions jump-patch instruction-here instructions
			]
		]

		either all [scope-state/3 = 0 stopped?][
			last-type: 0
			last-flags: 0
			last-stopped?: true
		][
			last-type: -11
			last-flags: 0
			last-stopped?: false
		]
		last-float-literal?: false
		skip position 2
	]

	stack-catch: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body anchor patch level target
	][
		body: stack-value next position scope uses instructions params locals
			expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			(ref-kind last-type) = 'i32
		][fail ERROR-REFERENCE "CATCH expects an integer! filter"]
		unless all [not tail? body block? body/1][
			fail ERROR-UNSUPPORTED "CATCH requires a body block"
		]

		anchor: instruction-here instructions
		level: 1 + length? catches
		patch: (length? instructions) + 5
		emit instructions reduce [catch-op 0 level 0]
		append/only catches reduce [anchor level]
		stack-block body/1 scope uses instructions params locals statement-value
		remove back tail catches

		target: instruction-here instructions
		patch-control instructions patch target
		emit instructions reduce [end-catch-op anchor level 0]
		last-type: 0
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		next body
	]

	stack-throw: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after id
	][
		after: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return after]
		unless all [last-flags = 0 (ref-kind last-type) = 'i32][
			fail ERROR-REFERENCE "THROW expects an integer! ID"
		]
		id: ensure-thrown-global
		emit instructions reduce [address-op global-address id 0]
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [throw-op 0 0 0]
		last-type: 0
		last-flags: 0
		last-float-literal?: false
		last-stopped?: true
		after
	]

	stack-if: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body patch
	][
		body: stack-value next position scope uses instructions params locals
			expression-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "IF requires a logic value"
		]
		unless all [not tail? body block? body/1][
			fail ERROR-UNSUPPORTED "IF is missing its body block"
		]
		patch: emit-control instructions branch-op 0
		stack-block body/1 scope uses instructions params locals statement-value
		patch-control instructions patch instruction-here instructions
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next body
	]

	finish-selection: func [
		name [word!]
		arms [block!]
		instructions [binary!]
		after [block!]
		value-context [integer!]
		return: [block!]
		/local arm result-type result-flags flow? common? drop? target
	][
		result-type: 0
		result-flags: 0
		flow?: false
		common?: true
		arm: arms
		while [not tail? arm][
			unless arm/4 [
				either flow? [
					unless all [
						result-type <> 0
						arm/2 <> 0
						same-stack-type? result-type result-flags arm/2 arm/3
					][common?: false]
				][
					flow?: true
					result-type: arm/2
					result-flags: arm/3
				]
			]
			arm: skip arm 4
		]
		unless common? [
			result-type: 0
			result-flags: 0
		]

		arm: arms
		while [not tail? arm][
			drop?: all [not arm/4 arm/2 <> 0 result-type = 0]
			if integer? arm/1 [
				patch-control-drop instructions arm/1 either drop? [1][0]
			]
			if all [none? arm/1 drop?][
				emit instructions reduce [drop-op 0 0 0]
			]
			arm: skip arm 4
		]
		target: instruction-here instructions
		arm: arms
		while [not tail? arm][
			if integer? arm/1 [patch-control instructions arm/1 target]
			arm: skip arm 4
		]

		last-type: result-type
		last-flags: result-flags
		last-stopped?: not flow?
		if all [
			any [
				value-context = expression-value
				all [value-context = tail-value tail? after]
			]
			result-type = 0
			not last-stopped?
		][
			fail ERROR-REFERENCE [uppercase form name " bodies do not have a common value"]
		]
		after
	]

	stack-either: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local arms after branch-patch jump-patch drop-count
			true-type true-flags false-type false-flags
			result-type result-flags
			true-value? false-value? true-stopped? false-stopped?
	][
		arms: stack-value next position scope uses instructions params locals
			expression-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "EITHER requires a logic value"
		]
		unless all [
			(length? arms) >= 2 block? arms/1 block? arms/2
		][fail ERROR-UNSUPPORTED "EITHER requires two body blocks"]
		after: skip arms 2

		branch-patch: emit-control instructions branch-op 0
		stack-block arms/1 scope uses instructions params locals tail-value
		true-type: last-type
		true-flags: last-flags
		true-stopped?: last-stopped?
		true-value?: all [not true-stopped? true-type <> 0]
		jump-patch: none
		unless true-stopped? [
			jump-patch: emit-control instructions jump-op 0
		]

		patch-control instructions branch-patch instruction-here instructions
		stack-block arms/2 scope uses instructions params locals tail-value
		false-type: last-type
		false-flags: last-flags
		false-stopped?: last-stopped?
		false-value?: all [not false-stopped? false-type <> 0]

		result-type: 0
		result-flags: 0
		case [
			all [true-value? false-stopped?][
				result-type: true-type
				result-flags: true-flags
			]
			all [false-value? true-stopped?][
				result-type: false-type
				result-flags: false-flags
			]
			all [
				true-value? false-value?
				same-stack-type? true-type true-flags false-type false-flags
			][
				result-type: true-type
				result-flags: true-flags
			]
			true [0]
		]

		if integer? jump-patch [
			drop-count: either all [true-value? result-type = 0][1][0]
			patch-control-drop instructions jump-patch drop-count
		]
		if all [false-value? result-type = 0][
			emit instructions reduce [drop-op 0 0 0]
		]
		if integer? jump-patch [
			patch-control instructions jump-patch instruction-here instructions
		]

		last-type: result-type
		last-flags: result-flags
		last-stopped?: all [true-stopped? false-stopped?]
		if all [
			any [
				value-context = expression-value
				all [value-context = tail-value tail? after]
			]
			result-type = 0
			not last-stopped?
		][fail ERROR-REFERENCE "EITHER blocks do not have a common value"]
		after
	]

	stack-case: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local body after cursor action branch-patch jump-patch arms
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "CASE requires a condition/body block"
		]
		body: position/2
		after: skip position 2
		if empty? body [fail ERROR-UNSUPPORTED "CASE body is empty"]
		arms: make block! 16
		cursor: body
		while [not tail? cursor][
			action: stack-value cursor scope uses instructions params locals
				expression-value
			unless logical-value? last-type last-flags [
				fail ERROR-REFERENCE "CASE requires logic conditions"
			]
			unless all [not tail? action block? action/1][
				fail ERROR-UNSUPPORTED "CASE condition is missing its body block"
			]
			branch-patch: emit-control instructions branch-op 0
			stack-block action/1 scope uses instructions params locals tail-value
			jump-patch: none
			unless last-stopped? [
				jump-patch: emit-control instructions jump-op 0
			]
			repend arms [jump-patch last-type last-flags last-stopped?]
			patch-control instructions branch-patch instruction-here instructions
			cursor: next action
		]
		emit instructions reduce [fail-op 100 0 0]
		finish-selection 'case arms instructions after value-context
	]

	switch-bits: func [
		value scope [block!]
		return: [block! none!]
		/local key number wide
	][
		case [
			integer? value [
				reduce [value either value < 0 [-1][0]]
			]
			char? value [reduce [to integer! value 0]]
			issue? value [
				wide: wide-literal value
				either block? wide [reduce [wide/2 wide/3]][none]
			]
			any [word? value path? value][
				key: qualified scope value
				number: select constants key
				either integer? number [
					reduce [number either number < 0 [-1][0]]
				][none]
			]
			true [none]
		]
	]

	stack-variant: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after ref name info
	][
		after: stack-value next position scope uses instructions params locals
			expression-value
		ref: last-type
		unless all [last-flags = 0 tagged-union-ref? ref][
			fail ERROR-REFERENCE "VARIANT? requires a tagged union value"
		]
		unless all [not tail? after lit-word? after/1][
			fail ERROR-UNSUPPORTED "VARIANT? requires a literal variant name"
		]
		name: to word! after/1
		info: member-info ref name
		unless block? info [
			fail ERROR-REFERENCE ["unknown union variant " mold name]
		]
		emit instructions reduce [tag-op 0 0 0]
		emit instructions reduce [literal-op -5 (info/1 + 1) 0]
		emit instructions reduce [binary-op 13 0 0]
		last-type: -11
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		next after
	]

	stack-switch: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		value-context [integer!]
		return: [block!]
		/local spec-position spec after selector-ref selector-kind cursor arms default-body
			patches bits first-case case-count case-patch switch-patch default-target
			arm-position arm target jump-patch missing-jump results last-arm? info
			tagged-selector?
	][
		spec-position: stack-value next position scope uses instructions params locals
			expression-value
		selector-ref: last-type
		selector-kind: ref-kind last-type
		tagged-selector?: all [last-flags = 0 tagged-union-ref? selector-ref]
		either tagged-selector? [
			emit instructions reduce [tag-op 0 0 0]
			last-type: -5
			last-flags: 0
		][unless all [integer-kind? selector-kind last-flags = 0][
			fail ERROR-REFERENCE "SWITCH requires an integer or tagged union value"
		]]
		unless all [not tail? spec-position block? spec-position/1][
			fail ERROR-UNSUPPORTED "SWITCH is missing its body block"
		]
		spec: spec-position/1
		after: next spec-position
		if empty? spec [fail ERROR-UNSUPPORTED "SWITCH body is empty"]
		first-case: (length? switches) / 12
		case-count: 0
		arms: make block! 8
		default-body: none
		cursor: spec
		while [not tail? cursor][
			if all [word? cursor/1 cursor/1 = 'default][
				unless all [(length? cursor) = 2 block? cursor/2][
					fail ERROR-UNSUPPORTED "DEFAULT must be the final SWITCH body"
				]
				default-body: cursor/2
				cursor: tail cursor
				break
			]
			patches: make block! 4
			while [all [not tail? cursor not block? cursor/1]][
				if all [word? cursor/1 cursor/1 = 'default][break]
				bits: either tagged-selector? [
					info: all [word? cursor/1 member-info selector-ref cursor/1]
					either block? info [reduce [info/1 + 1 0]][none]
				][switch-bits cursor/1 scope]
				unless block? bits [
					fail ERROR-UNSUPPORTED [
						"invalid SWITCH value: " mold cursor/1
					]
				]
				case-patch: emit-switch-case bits/1 bits/2
				append patches case-patch
				case-count: case-count + 1
				cursor: next cursor
			]
			unless all [not empty? patches not tail? cursor block? cursor/1][
				fail ERROR-UNSUPPORTED "invalid SWITCH value/body group"
			]
			append/only arms reduce [patches cursor/1]
			cursor: next cursor
		]
		if empty? arms [fail ERROR-UNSUPPORTED "SWITCH requires at least one value"]

		switch-patch: (length? instructions) + 13
		emit instructions reduce [switch-op first-case case-count 0]
		missing-jump: none
		if none? default-body [
			default-target: instruction-here instructions
			patch-control instructions switch-patch default-target
			missing-jump: emit-control instructions jump-op 0
		]

		results: make block! ((length? arms) * 4) + 4
		if integer? missing-jump [
			repend results [missing-jump 0 0 false]
		]
		arm-position: arms
		while [not tail? arm-position][
			arm: arm-position/1
			target: instruction-here instructions
			foreach case-patch arm/1 [patch-switch-case case-patch target]
			stack-block arm/2 scope uses instructions params locals tail-value
			last-arm?: all [tail? next arm-position none? default-body]
			jump-patch: none
			if all [not last-stopped? not last-arm?][
				jump-patch: emit-control instructions jump-op 0
			]
			repend results [jump-patch last-type last-flags last-stopped?]
			arm-position: next arm-position
		]
		if block? default-body [
			default-target: instruction-here instructions
			patch-control instructions switch-patch default-target
			stack-block default-body scope uses instructions params locals tail-value
			repend results [none last-type last-flags last-stopped?]
		]
		finish-selection 'switch results instructions after value-context
	]

	stack-conditions: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		any? [logic!]
		return: [block!]
		/local body after cursor patches patch decided jump-patch
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "ANY/ALL requires a condition block"
		]
		body: position/2
		after: skip position 2
		if empty? body [
			emit instructions reduce [literal-op -11 either any? [0][1] 0]
			last-type: -11
			last-flags: 0
			last-stopped?: false
			return after
		]
		patches: make block! 4
		cursor: body
		cursor: stack-value cursor scope uses instructions params locals
			expression-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "ANY/ALL requires logic values"
		]
		if tail? cursor [
			last-stopped?: false
			return after
		]
		patch: emit-control instructions branch-op either any? [1][0]
		append patches patch
		while [not tail? cursor][
			cursor: stack-value cursor scope uses instructions params locals
				expression-value
			unless logical-value? last-type last-flags [
				fail ERROR-REFERENCE "ANY/ALL requires logic values"
			]
			unless tail? cursor [
				patch: emit-control instructions branch-op either any? [1][0]
				append patches patch
			]
		]

		decided: either any? [1][0]
		jump-patch: emit-control instructions jump-op 0
		foreach patch patches [
			patch-control instructions patch instruction-here instructions
		]
		emit instructions reduce [literal-op -11 decided 0]
		patch-control instructions jump-patch instruction-here instructions
		last-type: -11
		last-flags: 0
		last-stopped?: false
		after
	]

	stack-return: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after return-flags
	][
		unless function-active? [
			fail ERROR-CONTEXT "RETURN used outside a function"
		]
		if function-return = 0 [
			fail ERROR-UNSUPPORTED "RETURN requires a value-returning function"
		]
		after: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return after]
		return-flags: either (function-flags and return-value-flag) <> 0 [
			inline-flag
		][0]
		unless all [
			last-type <> 0
			coerce-stack function-return return-flags instructions false
		][fail ERROR-REFERENCE "RETURN value does not match the function type"]
		emit instructions reduce [return-op function-return last-flags 0]
		last-type: 0
		last-flags: 0
		last-stopped?: true
		after
	]

	stack-exit: func [position [block!] instructions [binary!] return: [block!]][
		unless function-active? [
			fail ERROR-CONTEXT "EXIT used outside a function"
		]
		if function-return <> 0 [
			fail ERROR-REFERENCE "EXIT is incompatible with a function result"
		]
		emit instructions reduce [return-op 0 0 0]
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	open-loop: func [
		continue-target [integer!]
		condition? [logic!]
		return: [block!]
		/local record
	][
		record: reduce [
			continue-target make block! 2 make block! 2 condition? length? catches
		]
		append/only loops record
		record
	]

	close-loop: func [][
		remove back tail loops
	]

	patch-controls: func [
		instructions [binary!]
		patches [block!]
		target [integer!]
		/local patch
	][
		foreach patch patches [patch-control instructions patch target]
	]

	stack-break: func [
		position [block!]
		instructions [binary!]
		return: [block!]
		/local loop-state patch
	][
		if empty? loops [fail ERROR-CONTEXT "BREAK used outside a loop"]
		loop-state: last loops
		if loop-state/4 [fail ERROR-CONTEXT "BREAK used in a WHILE condition block"]
		patch: emit-control instructions jump-op 0
		patch-control-catches instructions patch ((length? catches) - loop-state/5)
		append loop-state/3 patch
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	stack-continue: func [
		position [block!]
		instructions [binary!]
		return: [block!]
		/local loop-state patch
	][
		if empty? loops [fail ERROR-CONTEXT "CONTINUE used outside a loop"]
		loop-state: last loops
		if loop-state/4 [fail ERROR-CONTEXT "CONTINUE used in a WHILE condition block"]
		patch: emit-control instructions jump-op 0
		patch-control-catches instructions patch ((length? catches) - loop-state/5)
		either loop-state/1 > 0 [
			patch-control instructions patch loop-state/1
		][append loop-state/2 patch]
		last-type: 0
		last-flags: 0
		last-stopped?: true
		next position
	]

	stack-loop: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local after local-info slot test-target exit-patch loop-state jump-patch
	][
		local-info: add-hidden-local params locals -5 0
		slot: local-info/1
		after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [(ref-kind last-type) = 'i32 last-flags = 0][
			fail ERROR-REFERENCE "LOOP requires an integer value"
		]
		emit-local-address instructions slot
		unless all [not tail? after block? after/1][
			fail ERROR-UNSUPPORTED "LOOP is missing its body block"
		]
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [drop-op 0 0 0]

		test-target: instruction-here instructions
		emit-local-address instructions slot
		emit instructions reduce [load-op 0 0 0]
		emit instructions reduce [literal-op -5 0 0]
		emit instructions reduce [binary-op 15 0 0]
		exit-patch: emit-control instructions branch-op 0

		loop-state: open-loop 0 false
		stack-block after/1 scope uses instructions params locals statement-value
		loop-state/1: instruction-here instructions
		patch-controls instructions loop-state/2 loop-state/1

		emit-local-address instructions slot
		emit instructions reduce [load-op 0 0 0]
		emit instructions reduce [literal-op -5 1 0]
		emit instructions reduce [binary-op 2 0 0]
		emit-local-address instructions slot
		emit instructions reduce [set-op 0 0 0]
		emit instructions reduce [drop-op 0 0 0]
		jump-patch: emit-control instructions jump-op 0
		patch-control instructions jump-patch test-target

		patch-control instructions exit-patch instruction-here instructions
		patch-controls instructions loop-state/3 instruction-here instructions
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next after
	]

	stack-while: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local condition body test-target exit-patch loop-state jump-patch target
	][
		unless all [
			(length? position) >= 3 block? position/2 block? position/3
		][fail ERROR-UNSUPPORTED "WHILE requires condition and body blocks"]
		condition: position/2
		body: position/3
		test-target: instruction-here instructions
		open-loop 0 true
		stack-block condition scope uses instructions params locals tail-value
		close-loop
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "WHILE condition block must end in a logic value"
		]
		exit-patch: emit-control instructions branch-op 0

		loop-state: open-loop test-target false
		stack-block body scope uses instructions params locals statement-value
		patch-controls instructions loop-state/2 test-target
		jump-patch: emit-control instructions jump-op 0
		patch-control instructions jump-patch test-target
		target: instruction-here instructions
		patch-control instructions exit-patch target
		patch-controls instructions loop-state/3 target
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		skip position 3
	]

	stack-until: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local body start loop-state patch target
	][
		unless all [(length? position) >= 2 block? position/2][
			fail ERROR-UNSUPPORTED "UNTIL requires a body block"
		]
		body: position/2
		if empty? body [fail ERROR-UNSUPPORTED "UNTIL body is empty"]
		start: instruction-here instructions
		loop-state: open-loop start false
		stack-block body scope uses instructions params locals tail-value
		unless logical-value? last-type last-flags [
			fail ERROR-REFERENCE "UNTIL body must end in a logic value"
		]
		patch-controls instructions loop-state/2 start
		patch: emit-control instructions branch-op 0
		patch-control instructions patch start
		target: instruction-here instructions
		patch-controls instructions loop-state/3 target
		close-loop
		last-type: 0
		last-flags: 0
		last-stopped?: false
		skip position 2
	]

	stack-size: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local value storage id record ref info type-info
	][
		if tail? position [fail ERROR-UNSUPPORTED "SIZE? requires a type or array"]
		value: position/1
		ref: none
		if word? value [
			storage: stack-storage-info value params locals
			if block? storage [
				record: storage/2
				if integer? record/2 [ref: record/2]
			]
		]
		if all [none? ref any [word? value path? value]][
			id: resolve-name value scope uses globals
			if integer? id [
				record: skip global-data ((id - 1) * 5)
				if integer? record/2 [ref: record/2]
			]
		]
		info: either integer? ref [array-info ref][none]
		if block? info [
			emit instructions reduce [size-op ref 0 0]
			last-type: -5
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next position
		]
		type-info: stack-read-type position scope uses
		emit instructions reduce [size-op type-info/2 0 0]
		last-type: -5
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		type-info/1
	]

	integer-pointer-value?: func [
		ref flags [integer!]
		return: [logic!]
		/local pointee
	][
		if any [flags <> 0 (ref-kind ref) <> 'pointer][return false]
		pointee: pointee-ref ref
		all [integer? pointee (canonical-ref pointee) = -5]
	]

	stack-atomic: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local path count operation next-position old?
	][
		path: position/1
		count: length? path
		if all [count = 3 path/3 = 'fence][
			emit instructions reduce [native-op atomic-fence-native 0 0]
			last-type: 0
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next position
		]
		if all [count = 3 path/3 = 'load][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/load expects pointer! [integer!]"
			]
			emit instructions reduce [native-op atomic-load-native 0 -5]
			last-type: -5
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next-position
		]
		if all [count = 3 path/3 = 'store][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/store expects pointer! [integer!]"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/store expects an integer! value"
			]
			emit instructions reduce [native-op atomic-store-native 0 0]
			last-type: 0
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next-position
		]
		if all [count = 3 path/3 = 'cas][
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				integer-pointer-value? last-type last-flags
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects pointer! [integer!]"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects an integer! check value"
			]
			next-position: stack-value next-position scope uses instructions
				params locals expression-value
			unless all [
				not last-stopped?
				last-flags = 0
				(canonical-ref last-type) = -5
			][
				fail ERROR-REFERENCE
					"system/atomic/cas expects an integer! new value"
			]
			emit instructions reduce [native-op atomic-cas-native 0 -11]
			last-type: -11
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next-position
		]
		operation: either count >= 3 [select atomic-operations path/3][none]
		old?: all [count = 4 path/4 = 'old]
		unless all [
			integer? operation
			any [count = 3 old?]
		][fail ERROR-REFERENCE "invalid system/atomic access"]
		next-position: stack-value next position scope uses instructions
			params locals expression-value
		unless all [
			not last-stopped?
			integer-pointer-value? last-type last-flags
		][
			fail ERROR-REFERENCE [
				"system/atomic/" path/3 " expects pointer! [integer!]"
			]
		]
		next-position: stack-value next-position scope uses instructions
			params locals expression-value
		unless all [
			not last-stopped?
			last-flags = 0
			(canonical-ref last-type) = -5
		][
			fail ERROR-REFERENCE [
				"system/atomic/" path/3 " expects an integer! value"
			]
		]
		emit instructions reduce [
			native-op atomic-math-native
			operation + (either old? [atomic-old-flag][0])
			-5
		]
		last-type: -5
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		next-position
	]

	stack-system-path: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block! none!]
		/local path count next-position pointer-ref register id
	][
		unless path? position/1 [return none]
		path: position/1
		unless all [
			(length? path) >= 2
			path/1 = 'system
		][return none]
		count: length? path
		if path/2 = 'thrown [
			unless count = 2 [fail ERROR-REFERENCE "invalid system/thrown access"]
			id: ensure-thrown-global
			emit instructions reduce [address-op global-address id 0]
			emit instructions reduce [load-op 0 0 0]
			last-type: -5
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next position
		]
		if path/2 = 'pc [
			unless count = 2 [fail ERROR-REFERENCE "invalid system/pc access"]
			pointer-ref: intern-pointer -15
			emit instructions reduce [
				native-op program-counter-native 0 pointer-ref
			]
			last-type: pointer-ref
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next position
		]
		if path/2 = 'cpu [
			unless count = 3 [fail ERROR-REFERENCE "invalid system/cpu access"]
			either path/3 = 'overflow? [
				emit instructions reduce [native-op cpu-overflow-native 0 -11]
				last-type: -11
			][
				register: select cpu-register-ids path/3
				unless integer? register [
					fail ERROR-REFERENCE ["unknown x64 CPU register " mold path/3]
				]
				pointer-ref: intern-pointer -5
				emit instructions reduce [
					native-op cpu-register-native register pointer-ref
				]
				last-type: pointer-ref
			]
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next position
		]
		if path/2 = 'atomic [
			return stack-atomic position scope uses instructions params locals
		]
		unless path/2 = 'stack [return none]
		case [
			all [count = 3 path/3 = 'top][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-top-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'frame][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-frame-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'align][
				pointer-ref: intern-pointer -5
				emit instructions reduce [native-op stack-align-native 0 pointer-ref]
				last-type: pointer-ref
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			all [
				any [
					all [count = 3 path/3 = 'allocate]
					all [
						count = 4
						path/3 = 'allocate
						path/4 = 'zero
					]
				]
			][
				next-position: stack-value next position scope uses instructions
					params locals expression-value
				unless all [
					not last-stopped?
					last-flags = 0
					(ref-kind last-type) = 'i32
				][
					fail ERROR-REFERENCE
						"system/stack/allocate expects an integer! argument"
				]
				pointer-ref: intern-pointer -5
				emit instructions reduce [
					native-op either count = 4 [
						stack-allocate-zero-native
					][stack-allocate-native]
					0 pointer-ref
				]
				last-type: pointer-ref
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next-position
			]
			all [count = 3 path/3 = 'free][
				next-position: stack-value next position scope uses instructions
					params locals expression-value
				unless all [
					not last-stopped?
					last-flags = 0
					(ref-kind last-type) = 'i32
				][
					fail ERROR-REFERENCE
						"system/stack/free expects an integer! argument"
				]
				emit instructions reduce [native-op stack-free-native 0 0]
				last-type: 0
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next-position
			]
			all [count = 3 path/3 = 'push-all][
				emit instructions reduce [native-op stack-push-all-native 0 0]
				last-type: 0
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			all [count = 3 path/3 = 'pop-all][
				emit instructions reduce [native-op stack-pop-all-native 0 0]
				last-type: 0
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			true [fail ERROR-REFERENCE "invalid system/stack access"]
		]
	]

	stack-system-assignment: func [
		position [block!]
		target [word! path!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block! none!]
		/local pointer-ref next-position register id
	][
		unless all [
			path? target
			(length? target) >= 2
			target/1 = 'system
		][return none]
		if target/2 = 'thrown [
			unless (length? target) = 2 [
				fail ERROR-REFERENCE "invalid system/thrown assignment"
			]
			next-position: stack-value next position scope uses instructions params locals
				expression-value
			if last-stopped? [return next-position]
			unless all [last-flags = 0 (ref-kind last-type) = 'i32][
				fail ERROR-REFERENCE "system/thrown expects an integer! value"
			]
			id: ensure-thrown-global
			emit instructions reduce [address-op global-address id 0]
			emit instructions reduce [set-op 0 0 0]
			last-type: -5
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next-position
		]
		if target/2 = 'pc [
			fail ERROR-REFERENCE "cannot modify system/pc"
		]
		if target/2 = 'cpu [
			unless (length? target) = 3 [
				fail ERROR-REFERENCE "invalid system/cpu assignment"
			]
			if target/3 = 'overflow? [
				fail ERROR-REFERENCE "cannot modify system/cpu/overflow?"
			]
			register: select cpu-register-ids target/3
			unless integer? register [
				fail ERROR-REFERENCE ["unknown x64 CPU register " mold target/3]
			]
			pointer-ref: intern-pointer -5
			next-position: stack-value next position scope uses instructions
				params locals expression-value
			if last-stopped? [return next-position]
			unless coerce-stack pointer-ref 0 instructions false [
				fail ERROR-REFERENCE "system/cpu assignment expects pointer! [integer!]"
			]
			emit instructions reduce [
				native-op cpu-register-set-native register pointer-ref
			]
			last-type: pointer-ref
			last-flags: 0
			last-float-literal?: false
			last-stopped?: false
			return next-position
		]
		unless target/2 = 'stack [return none]
		unless all [
			(length? target) = 3
			any [target/3 = 'top target/3 = 'frame]
		][fail ERROR-REFERENCE "invalid system/stack assignment"]
		pointer-ref: intern-pointer -5
		next-position: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return next-position]
		unless coerce-stack pointer-ref 0 instructions false [
			fail ERROR-REFERENCE "system/stack assignment expects pointer! [integer!]"
		]
		emit instructions reduce [
			native-op either target/3 = 'top [
				stack-top-set-native
			][stack-frame-set-native]
			0 pointer-ref
		]
		last-type: pointer-ref
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		next-position
	]

	stack-push: func [
		position scope uses [block!]
		instructions [binary!]
		params locals [block!]
		return: [block!]
		/local position-after
	][
		position-after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [not last-stopped? last-type <> 0][
			fail ERROR-REFERENCE "PUSH requires a value"
		]
		emit instructions reduce [native-op stack-push-native 0 0]
		last-type: 0
		last-flags: 0
		last-float-literal?: false
		last-stopped?: false
		position-after
	]

	stack-primary: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local value type-info next-position target id constant-key bytes offset
			inner wide bits call-target protected-info
			storage
	][
		unless not tail? position [
			fail ERROR-UNSUPPORTED "missing expression"
		]
		value: position/1
		last-float-literal?: false
		last-stopped?: false
		if all [
			word? value
			storage: stack-storage-info value params locals
			(ref-kind storage/2/2) = 'subroutine
		][
			return stack-subroutine position value scope uses instructions params locals
				value-context
		]
		case [
			value = 'catch [
				stack-catch position scope uses instructions params locals
			]
			value = 'throw [
				stack-throw position scope uses instructions params locals
			]
			value = 'overflow? [
				stack-overflow position scope uses instructions params locals
			]
			value = 'if [
				next-position: stack-if position scope uses instructions params locals
				last-float-literal?: false
				next-position
			]
			value = 'either [
				next-position: stack-either position scope uses instructions params locals
					value-context
				last-float-literal?: false
				next-position
			]
			value = 'case [
				next-position: stack-case position scope uses instructions params locals
					value-context
				last-float-literal?: false
				next-position
			]
			value = 'switch [
				next-position: stack-switch position scope uses instructions params locals
					value-context
				last-float-literal?: false
				next-position
			]
			value = 'variant? [
				next-position: stack-variant position scope uses instructions params locals
				last-float-literal?: false
				next-position
			]
			value = 'any [
				next-position: stack-conditions position scope uses instructions params locals true
				last-float-literal?: false
				next-position
			]
			value = 'all [
				next-position: stack-conditions position scope uses instructions params locals false
				last-float-literal?: false
				next-position
			]
			value = 'return [
				stack-return position scope uses instructions params locals
			]
			value = 'exit [stack-exit position instructions]
			value = 'loop [
				stack-loop position scope uses instructions params locals
			]
			value = 'while [
				stack-while position scope uses instructions params locals
			]
			value = 'until [
				stack-until position scope uses instructions params locals
			]
			value = 'break [stack-break position instructions]
			value = 'continue [stack-continue position instructions]
			value = 'use [
				stack-use position scope uses instructions params locals
			]
			paren? value [
				inner: to block! value
				if empty? inner [fail ERROR-UNSUPPORTED "empty expression"]
				next-position: stack-value inner scope uses instructions params locals
					expression-value
				unless tail? next-position [
					fail ERROR-UNSUPPORTED "parenthesized expression is incomplete"
				]
				next position
			]
			value = 'not [
				next-position: stack-value next position scope uses instructions params locals
					expression-value
				stack-unary not-operation instructions
				last-float-literal?: false
				next-position
			]
			value = 'as [
				stack-cast position scope uses instructions params locals
			]
			value = 'size? [
				stack-size next position scope uses instructions params locals
			]
			value = 'push [
				stack-push position scope uses instructions params locals
			]
			value = 'pop [
				emit instructions reduce [native-op stack-pop-native 0 0]
				last-type: -5
				last-flags: 0
				last-float-literal?: false
				last-stopped?: false
				next position
			]
			value = 'declare [
				fail ERROR-CONTEXT "DECLARE requires an assignment target"
			]
			any [get-word? value get-path? value][
				target: either get-word? value [to word! value][to path! value]
				call-target: resolve-stack-call target scope uses
				if integer? call-target [
					id: call-signature-ref call-target
					emit instructions reduce [
						address-op either call-target > 0 [
							function-address
						][import-address]
						either call-target > 0 [call-target][0 - call-target]
						id
					]
					emit instructions reduce [reference-op id 0 0]
					last-type: id
					last-flags: 0
					return next position
				]
				unless stack-address target scope uses instructions params locals [
					fail ERROR-REFERENCE ["unknown address target " mold value]
				]
				if all [get-word? value (ref-kind last-type) = 'function][
					emit instructions reduce [load-op 0 0 0]
					last-flags: 0
					return next position
				]
				id: either get-path? value [
					intern-pointer -5
				][address-reference-ref last-type last-flags]
				unless integer? id [
					fail ERROR-REFERENCE ["value cannot be addressed " mold value]
				]
				emit instructions reduce [reference-op id 0 0]
				last-type: id
				last-flags: 0
				next position
			]
			issue? value [
				wide: wide-literal value
				either block? wide [
					emit instructions reduce [literal-op wide/1 wide/2 wide/3]
					last-type: wide/1
				][
					bits: either float-literal? value [float-bits value 'f64][none]
					unless block? bits [
						fail ERROR-UNSUPPORTED ["unsupported issue literal " mold value]
					]
					emit instructions reduce [literal-op -10 bits/1 bits/2]
					last-type: -10
					last-float-literal?: true
				]
				last-flags: 0
				next position
			]
			float? value [
				bits: float-bits value 'f64
				unless block? bits [fail ERROR-UNSUPPORTED "invalid floating-point literal"]
				emit instructions reduce [literal-op -10 bits/1 bits/2]
				last-type: -10
				last-flags: 0
				last-float-literal?: true
				next position
			]
			integer? value [
				emit instructions reduce [
					literal-op -5 value either value < 0 [-1][0]
				]
				last-type: -5
				last-flags: 0
				next position
			]
			char? value [
				id: to integer! value
				if id > 255 [fail ERROR-UNSUPPORTED "byte literal is out of range"]
				emit instructions reduce [literal-op -15 id 0]
				last-type: -15
				last-flags: 0
				next position
			]
			logic? value [
				emit instructions reduce [literal-op -11 either value [1][0] 0]
				last-type: -11
				last-flags: 0
				next position
			]
			all [word? value find [true false yes no] value][
				emit instructions reduce [
					literal-op -11 either find [true yes] value [1][0] 0
				]
				last-type: -11
				last-flags: 0
				next position
			]
			value = 'null [
				emit instructions reduce [literal-op -14 0 0]
				last-type: -14
				last-flags: 0
				next position
			]
			string? value [
				bytes: to binary! value
				offset: select string-ids bytes
				unless integer? offset [
					offset: length? strings
					repend string-ids [bytes offset]
					append strings bytes
					append strings 0
				]
				emit instructions reduce [
					constant-op -13 offset ((length? bytes) + 1)
				]
				last-type: -13
				last-flags: 0
				next position
			]
			all [
				path? value
				next-position: stack-system-path position scope uses instructions
					params locals
			][next-position]
			any [word? value path? value] [
				protected-info: resolve-name value scope uses protected-values
				if block? protected-info [
					emit instructions reduce [
						literal-op protected-info/1 protected-info/3 protected-info/4
					]
					last-type: protected-info/1
					last-flags: 0
					last-float-literal?: float-kind? ref-kind last-type
					return next position
				]
				constant-key: qualified scope value
				id: select constants constant-key
				next-position: either integer? id [
					emit instructions reduce [literal-op -5 id either id < 0 [-1][0]]
					last-type: -5
					last-flags: 0
					next position
				][
					target: resolve-stack-call value scope uses
					either integer? target [
						stack-call target value position scope uses instructions params locals
					][
						unless stack-address value scope uses instructions params locals [
							fail ERROR-REFERENCE [
								"unknown value or function " mold value
							]
						]
						if last-type = 0 [
							fail ERROR-REFERENCE ["value is used before initialization " mold value]
						]
						either (ref-kind last-type) = 'function [
							stack-indirect-call value position scope uses instructions params locals
						][
							emit instructions reduce [load-op 0 0 0]
							last-flags: 0
							next position
						]
					]
				]
				last-float-literal?: false
				next-position
			]
			true [
				fail ERROR-UNSUPPORTED ["unsupported expression " mold value]
			]
		]
	]

	stack-value: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local operation left left-flags infix-target right-start
	][
		position: stack-primary position scope uses instructions params locals value-context
		while [not tail? position][
			operation: select binary-operations position/1
			either integer? operation [
				left: last-type
				left-flags: last-flags
				right-start: length? instructions
				position: stack-primary next position scope uses instructions params locals
					expression-value
				stack-binary operation left left-flags right-start instructions
			][
				infix-target: none
				if any [word? position/1 path? position/1][
					infix-target: resolve-stack-call position/1 scope uses
				]
				unless all [integer? infix-target find infix-targets infix-target][break]
				position: stack-infix-call infix-target position/1 position
					scope uses instructions params locals
			]
		]
		position
	]

	stack-static: func [
		position [block!]
		scope uses [block!]
		protected? [logic!]
		return: [logic!]
		/local value type-info next-position wide bits kind source-kind keep? info id
	][
		static?: false
		static-ref: 0
		static-low: 0
		static-high: 0
		static-flags: 0
		static-initializer: none
		static-next: position
		value: position/2
		case [
			any [block? value binary? value][
				info: array-literal-info value scope uses protected?
				static?: true
				static-ref: info/1
				static-flags: inline-flag
				static-initializer: info/2
				static-next: skip position 2
			]
			string? value [
				info: static-literal-info value scope uses protected?
				static?: true
				static-ref: info/1
				static-initializer: reduce [info/2 info/3 info/4 info/5]
				static-next: skip position 2
			]
			any [get-word? value get-path? value][
				info: static-literal-info value scope uses protected?
				if block? info [
					static?: true
					static-ref: info/1
					static-initializer: reduce [info/2 info/3 info/4 info/5]
					static-next: skip position 2
				]
			]
			issue? value [
				wide: wide-literal value
				either block? wide [
					static?: true
					static-ref: wide/1
					static-low: wide/2
					static-high: wide/3
					static-next: skip position 2
				][
					bits: either float-literal? value [float-bits value 'f64][none]
					if block? bits [
						static?: true
						static-ref: -10
						static-low: bits/1
						static-high: bits/2
						static-next: skip position 2
					]
				]
			]
			float? value [
				bits: float-bits value 'f64
				if block? bits [
					static?: true
					static-ref: -10
					static-low: bits/1
					static-high: bits/2
					static-next: skip position 2
				]
			]
			integer? value [
				static?: true
				static-ref: -5
				static-low: value
				static-high: either value < 0 [-1][0]
				static-next: skip position 2
			]
			char? value [
				static-low: to integer! value
				if static-low > 255 [
					fail ERROR-UNSUPPORTED "byte literal is out of range"
				]
				static?: true
				static-ref: -15
				static-high: 0
				static-next: skip position 2
			]
			logic? value [
				static?: true
				static-ref: -11
				static-low: either value [1][0]
				static-next: skip position 2
			]
			all [word? value find [true false yes no] value][
				static?: true
				static-ref: -11
				static-low: either find [true yes] value [1][0]
				static-next: skip position 2
			]
			value = 'as [
				type-info: stack-read-type skip position 2 scope uses
				next-position: type-info/1
				keep?: false
				if all [not tail? next-position next-position/1 = 'keep][
					keep?: true
					next-position: next next-position
				]
				if not tail? next-position [
					value: next-position/1
					kind: ref-kind type-info/2
					bits: none
					if all [
						float-kind? kind
						any [
							all [not keep? any [float-literal? value integer? value]]
							all [keep? kind = 'f32 integer? value]
						]
					][
						bits: either keep? [
							reduce [value 0]
						][float-bits either integer? value [to float! value][value] kind]
					]
					either block? bits [
						static?: true
						static-ref: type-info/2
						static-low: bits/1
						static-high: bits/2
						static-next: next next-position
					][if integer? value [
						static?: true
						static-ref: type-info/2
						static-low: value
						static-high: either value < 0 [-1][0]
						static-next: next next-position
					]]
					if all [not static?
						any [logic? value all [word? value find [true false yes no] value]]
						kind = 'logic
					][
						static?: true
						static-ref: type-info/2
						static-low: either any [
							value = true
							all [word? value find [true yes] value]
						][1][0]
						static-next: next next-position
					]
					if all [
						not static?
						string? value
						find [pointer c-string] kind
					][
						id: add-static-bytes to binary! value true protected?
						static?: true
						static-ref: type-info/2
						static-initializer: reduce [
							address-initializer global-address id 0
						]
						static-next: next next-position
					]
					if all [
						not static?
						any [get-word? value get-path? value]
						info: static-literal-info value scope uses protected?
					][
						source-kind: ref-kind info/1
						if all [
							source-kind = 'function
							none? find [i32 pointer function] kind
						][fail ERROR-REFERENCE "invalid function pointer cast"]
						static?: true
						static-ref: type-info/2
						static-initializer: reduce [info/2 info/3 info/4 info/5]
						static-next: next next-position
					]
				]
			]
		]
		if all [static? none? static-initializer][
			static-initializer: reduce [
				scalar-initializer static-low static-high 0
			]
		]
		static?
	]

	stack-declaration: func [
		position [block!]
		target [word! path!]
		storage [block! none!]
		id [integer! none!]
		scope uses [block!]
		instructions [binary!]
		params locals [block!]
		fold? [logic!]
		return: [block!]
		/local type-info next-position ref kind aggregate? record hidden target-ref
			target-flags source-ref source-flags address-position
	][
		type-info: stack-read-type skip position 2 scope uses
		next-position: type-info/1
		ref: type-info/2
		if type-info/3 <> 0 [
			fail ERROR-UNSUPPORTED "DECLARE requires a reference type"
		]
		kind: ref-kind ref
		aggregate?: not none? find [struct union] kind

		unless aggregate? [
			unless word? target [
				fail ERROR-CONTEXT "scalar DECLARE requires a variable target"
			]
			either block? storage [
				record: storage/2
				either record/2 = 0 [
					record/2: ref
					record/3: 0
				][unless all [
					record/3 = 0
					stack-type-compatible? record/2 ref
				][fail ERROR-REFERENCE ["declaration changes type " mold target]]]
			][
				unless integer? id [
					fail ERROR-REFERENCE ["unknown declaration target " mold target]
				]
				record: skip global-data ((id - 1) * 5)
				either integer? record/2 [
					unless stack-type-compatible? record/2 ref [
						fail ERROR-REFERENCE ["declaration changes type " mold target]
					]
				][
					record/2: ref
					record/3: 0
					record/4: 0
					record/5: 0
				]
			]
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return next-position
		]

		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 5)
			unless integer? record/2 [
				hidden: add-hidden-global ref inline-flag
				record/2: ref
				record/3: 0
				set-global-initializer record reduce [
					address-initializer global-address hidden 0
				]
				last-type: 0
				last-flags: 0
				last-stopped?: false
				return next-position
			]
		]

		either function-active? [
			hidden: add-hidden-local params locals ref inline-flag
			emit-local-address instructions hidden/1
		][
			hidden: add-hidden-global ref inline-flag
			emit instructions reduce [address-op global-address hidden 0]
		]
		emit instructions reduce [reference-op ref 0 0]
		last-type: ref
		last-flags: 0
		source-ref: last-type
		source-flags: last-flags
		address-position: tail instructions
		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		target-flags: last-flags
		last-type: source-ref
		last-flags: source-flags

		either block? storage [
			record: storage/2
			either record/2 = 0 [
				record/2: ref
				record/3: 0
			][unless coerce-stack/before record/2 record/3 instructions false
				address-position [
				fail ERROR-REFERENCE ["declaration changes type " mold target]
			]]
		][either integer? id [
			record: skip global-data ((id - 1) * 5)
			either integer? record/2 [
				unless coerce-stack/before record/2 0 instructions false
					address-position [
					fail ERROR-REFERENCE ["declaration changes type " mold target]
				]
			][
				record/2: ref
				record/3: 0
			]
		][
			unless coerce-stack/before target-ref target-flags instructions false
				address-position [
				fail ERROR-REFERENCE ["declaration changes type " mold target]
			]
		]]
		emit instructions reduce [set-op 0 0 0]
		next-position
	]

	protected-target?: func [
		target [word! path!]
		scope uses params locals [block!]
		return: [logic!]
		/local parts count candidate
	][
		parts: either word? target [reduce [target]][to block! target]
		if block? stack-storage-info parts/1 params locals [return false]
		count: length? parts
		while [count > 0][
			candidate: either count = 1 [
				parts/1
			][to path! copy/part parts count]
			if integer? resolve-name candidate scope uses protected [return true]
			count: count - 1
		]
		false
	]

	stack-protect: func [
		position [block!]
		target [word! path!]
		scope uses [block!]
		fold? [logic!]
		return: [block!]
		/local key info id record next-position
	][
		unless all [fold? word? target (length? position) >= 3][
			fail ERROR-CONTEXT "PROTECT is only allowed on a new global value"
		]
		key: qualified scope target
		id: resolve-name target scope uses protected
		unless integer? id [
			fail ERROR-CONTEXT "PROTECT must immediately follow a new global name"
		]
		either id = 0 [
			info: static-literal-info position/3 scope uses true
			unless all [block? info info/2 = scalar-initializer][
				fail ERROR-UNSUPPORTED "PROTECT expects a literal value"
			]
			append protected-values key
			append/only protected-values copy info
			next-position: skip position 3
		][
			unless stack-static next position scope uses true [
				fail ERROR-UNSUPPORTED "PROTECT expects a literal value"
			]
			record: skip global-data ((id - 1) * 5)
			record/2: static-ref
			record/3: static-flags or protected-flag
			set-global-initializer record static-initializer
			next-position: static-next
		]
		last-type: 0
		last-flags: 0
		last-stopped?: false
		next-position
	]

	stack-assignment: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		fold? [logic!]
		return: [block!]
		/local target id record target-ref target-flags next-position storage
			source-ref source-flags source-float-literal? address-position
	][
		if (length? position) < 2 [fail ERROR-UNSUPPORTED "assignment value is missing"]
		target: either set-word? position/1 [
			to word! position/1
		][to path! position/1]
		next-position: stack-system-assignment position target scope uses instructions
			params locals
		if block? next-position [return next-position]
		storage: either word? target [stack-storage-info target params locals][none]
		id: either block? storage [none][resolve-name target scope uses globals]
		if all [
			block? storage
			(ref-kind storage/2/2) = 'subroutine
		][
			unless block? position/2 [
				fail ERROR-REFERENCE ["subroutine requires a body block " mold target]
			]
			set-subroutine-body target position/2
			last-type: 0
			last-flags: 0
			last-stopped?: false
			return skip position 2
		]
		if position/2 = 'protect [
			return stack-protect position target scope uses fold?
		]
		if protected-target? target scope uses params locals [
			fail ERROR-REFERENCE ["cannot modify protected data " mold target]
		]
		if position/2 = 'declare [
			return stack-declaration position target storage id scope uses instructions
				params locals fold?
		]
		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 5)
			if all [
				not integer? record/2
				stack-static position scope uses false
				static?
				any [
					tail? static-next
					none? select binary-operations static-next/1
				]
			][
				record/2: static-ref
				record/3: static-flags
				set-global-initializer record static-initializer
				last-type: 0
				last-flags: 0
				return static-next
			]
		]
		next-position: either any [block? position/2 binary? position/2][
			stack-array-literal next position scope uses instructions
		][
			stack-value next position scope uses instructions params locals
				expression-value
		]
		if last-stopped? [return next-position]
		source-ref: last-type
		source-flags: last-flags
		source-float-literal?: last-float-literal?
		address-position: tail instructions
		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		target-flags: last-flags
		if (ref-kind target-ref) = 'array [
			fail ERROR-REFERENCE "a literal array pointer cannot be reassigned"
		]
		last-type: source-ref
		last-flags: source-flags
		last-float-literal?: source-float-literal?
		either block? storage [
			record: storage/2
			either record/2 = 0 [
				if last-type = -14 [
					fail ERROR-REFERENCE "null needs an explicit target type"
				]
				record/2: last-type
				record/3: last-flags
			][
				unless coerce-stack/before record/2 record/3 instructions false
					address-position [
					fail ERROR-REFERENCE ["local assignment changes type " mold target]
				]
			]
		][either integer? id [
			record: skip global-data ((id - 1) * 5)
			either integer? record/2 [
				unless coerce-stack/before record/2 0 instructions false
					address-position [
					fail ERROR-REFERENCE ["global assignment changes type " mold target]
				]
			][
				if last-type = -14 [
					fail ERROR-REFERENCE "null needs an explicit target type"
				]
				record/2: last-type
			]
		][
			unless coerce-stack/before target-ref target-flags instructions false
				address-position [
				fail ERROR-REFERENCE ["assignment changes type " mold target]
			]
		]]
		emit instructions reduce [set-op 0 0 0]
		next-position
	]

	stack-module: func [
		values scope uses [block!]
		/local position child target next-uses
	][
		position: values
		while [not tail? position][
			case [
				all [position/1 = 'comment (length? position) >= 2][
					position: skip position 2
				]
				all [
					issue? position/1
					find [#script #include] position/1
					(length? position) >= 2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					position: next position
				]
				all [
					issue? position/1
					position/1 = #enum
					(length? position) >= 3
				][position: skip position 3]
				all [
					issue? position/1
					position/1 = #import
					(length? position) >= 2
				][position: skip position 2]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'alias
				][position: skip position either find [
					pointer! struct! union! function! subroutine!
				] position/3 [4][3]]
				all [
					set-word? position/1
					(length? position) >= 4
					find [func function] position/2
					block? position/3
					block? position/4
				][position: skip position 4]
				all [
					set-word? position/1
					(length? position) >= 3
					position/2 = 'context
					block? position/3
				][
					child: append copy scope to word! position/1
					stack-module position/3 child uses
					position: skip position 3
				]
				all [
					position/1 = 'with
					(length? position) >= 3
					any [word? position/2 path? position/2]
					block? position/3
				][
					target: position/2
					unless child: resolve-context target scope uses [
						fail ERROR-CONTEXT ["unknown context " mold target]
					]
					next-uses: copy/deep uses
					append/only next-uses child
					stack-module position/3 scope next-uses
					position: skip position 3
				]
				any [set-word? position/1 set-path? position/1][
					position: stack-assignment position scope uses module-code
						[] module-locals true
					if last-type <> 0 [emit module-code reduce [drop-op 0 0 0]]
				]
				true [
					position: stack-value position scope uses module-code [] module-locals
						statement-value
					if last-type <> 0 [
						emit module-code reduce [drop-op 0 0 0]
					]
				]
			]
		]
	]

	stack-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
		return: [integer!]
		/local before count return-flags
	][
		before: length? instructions
		function-base: to integer! (before / 16)
		function-return: return-ref
		function-flags: flags
		function-active?: true
		clear loops
		clear overflows
		clear catches
		clear use-local-slots
		clear subroutine-bodies
		clear subroutine-stack
		last-type: 0
		last-flags: 0
		last-stopped?: false
		either return-ref = 0 [
			stack-block body scope uses instructions params locals statement-value
			unless last-stopped? [emit instructions reduce [return-op 0 0 0]]
		][
			stack-block body scope uses instructions params locals tail-value
			unless last-stopped? [
				if last-type = 0 [
					fail ERROR-UNSUPPORTED "function result is missing"
				]
				return-flags: either (flags and return-value-flag) <> 0 [
					inline-flag
				][0]
				unless coerce-stack return-ref return-flags instructions false [
					fail ERROR-REFERENCE "function result type does not match signature"
				]
				emit instructions reduce [return-op return-ref last-flags 0]
			]
		]
		count: to integer! (((length? instructions) - before) / 16)
		function-active?: false
		clear overflows
		clear catches
		clear use-local-slots
		clear subroutine-bodies
		clear subroutine-stack
		count
	]

	set-global: func [
		position scope uses [block!]
	][
		stack-assignment position scope uses module-code [] [] true
	]

	compile-import-set: func [
		position scope uses [block!]
		instructions [binary!]
		module? [logic!]
	][
		stack-assignment position scope uses instructions [] [] module?
	]

	compile-module: func [
		values scope uses [block!]
	][
		function-base: 0
		function-return: 0
		function-flags: 0
		function-active?: false
		clear loops
		clear overflows
		clear catches
		stack-module values scope uses
	]

	compile-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		flags [integer!]
	][
		stack-body return-ref body scope uses instructions params locals flags
	]

	compile: func [
		source [block!]
		kind [word!]
		/limit max-bytes [integer!]
		/local result
	][
		last-error: none
		result: catch/name [
			function-active?: false
			module-kind: case [
				kind = 'user [1]
				kind = 'support [2]
				kind = 'glue [3]
				true [0]
			]
			if module-kind = 0 [
				fail ERROR-KIND "unsupported RSIR module kind"
			]

			clear functions
			clear function-ids
			clear infix-targets
			clear contexts
			clear types
			clear type-ids
			clear pointer-types
			clear array-types
			clear aggregate-types
			clear function-types
			clear subroutine-types
			clear typed-call-types
			clear alias-type-ids
			clear constants
			clear protected
			clear protected-values
			clear imports
			clear import-ids
			clear libraries
			clear globals
			clear global-data
			clear module-code
			clear module-locals
			last-float-literal?: false
			clear function-code
			clear overflows
			clear catches
			clear initializers
			clear switches
			clear strings
			clear string-ids
			clear use-local-slots
			clear subroutine-bodies
			clear subroutine-stack
			function-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			thrown-global: 0
			alias-count: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
