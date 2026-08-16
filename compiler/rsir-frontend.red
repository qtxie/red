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
	contexts: make hash! 32
	types: make block! 256
	type-ids: make hash! 128
	pointer-types: make hash! 64
	aggregate-types: make hash! 64
	constants: make hash! 256
	imports: make block! 256
	import-ids: make hash! 256
	libraries: make hash! 32
	globals: make hash! 1024
	global-data: make block! 1024
	module-code: make binary! 256
	module-locals: make block! 12
	function-code: make binary! 2048
	switches: make binary! 96
	strings: make binary! 256
	string-ids: make hash! 128
	function-count: 0
	type-count: 0
	import-count: 0
	global-count: 0

	type-kinds: make hash! [
		int8! i8 byte! u8 uint8! u8 int16! i16 uint16! u16
		integer! i32 int32! i32 uint32! u32 int64! i64 uint64! u64
		float32! f32 float! f64 float64! f64 logic! logic
		pointer! pointer c-string! c-string struct! pointer union! pointer
		function! pointer subroutine! pointer array! pointer
		byte-ptr! pointer int-ptr! pointer ptr-ptr! pointer
		float32-ptr! pointer
	]

	type-codes: make hash! [
		i8 1 u8 2 i16 3 u16 4 i32 5 u32 6 i64 7 u64 8
		f32 9 f64 10 logic 11 pointer 12 c-string 13
		alias -1 struct -2 union -3 function -4 subroutine -5
		pointer-node -6
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
	inline-flag: 1
	global-reference-flag: 2
	tagged-type-flag: 1

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
	static?: false
	static-ref: 0
	static-low: 0
	static-high: 0
	static-next: none

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
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
		slot: 1 + to integer! (((length? params) + (length? locals)) / 3)
		record: tail locals
		append locals none
		append locals ref
		append locals flags
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

	emit-local-address: func [output [binary!] slot [integer!]][
		emit output reduce [address-op local-address slot 0]
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
		unless find [i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 pointer] kind [
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
			if ref < -13 [return none]
			return pick [i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer c-string]
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
			kind = 'c-string [-2]
			all [kind = 'pointer base > 0][
				record: skip types ((base - 1) * 5)
				either record/2 = 'pointer [record/3][none]
			]
			true [none]
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

	signature-flags: func [attributes [block!] /local flags convention item bit][
		if (length? attributes) > 2 [
			fail ERROR-UNSUPPORTED "too many function attributes"
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

	prepare-functions: func [/local record signature][
		record: functions
		while [not tail? record][
			signature: read-signature record/2 record/4 record/5
			record/6: signature/1
			record/7: signature/2
			record/8: signature/3
			record/9: signature/4
			record: skip record 10
		]
	]

	prepare-imports: func [/local record signature cc][
		record: imports
		while [not tail? record][
			cc: record/8
			either record/5 = 'function [
				signature: read-signature record/4 record/6 record/7
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
			spelling id type-spec
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
					][
						fail ERROR-DUPLICATE ["duplicate function " mold key]
					]
					id: function-count + 1
					repend function-ids [key id]
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
				set-word? position/1 [
					name: to word! position/1
					key: qualified scope name
					unless any [
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
		params parameter target
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
				kind = 'pointer [
					emit type-output reduce [
						select type-codes 'pointer-node position/3 0 first 0
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
					signature: read-signature position/3 position/4 position/5
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
		type-bytes: length? type-output
		member-bytes: length? members
		names: copy strings
		switch-count: (length? switches) / 12
		output: make binary! (32 + type-bytes + member-bytes + (length? switches)
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
			local-count: (length? locals) / 3
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
				if parameter/2 = 0 [
					fail ERROR-UNSUPPORTED [
						"local type is unresolved: " mold parameter/1
					]
				]
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			append names name
			first-param: first-local + local-count
			instruction-count: instruction-count + position/10
			id: id + 1
			position: skip position 10
		]
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

	stack-type-compatible?: func [
		expected actual [integer!]
		return: [logic!]
		/local expected-kind actual-kind
	][
		expected: canonical-ref expected
		actual: canonical-ref actual
		if expected = actual [return true]
		if any [expected = 0 actual = 0] [return false]
		expected-kind: ref-kind expected
		actual-kind: ref-kind actual
		if any [reference-kind? expected-kind reference-kind? actual-kind][return false]
		either all [expected > 0 actual > 0][
			false
		][
			expected-kind = actual-kind
		]
	]

	integer-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [i8 u8 i16 u16 i32 u32 i64 u64] kind
	]

	integer-code: func [ref [integer!] return: [integer!] /local kind][
		if all [ref < 0 ref >= -8][return negate ref]
		kind: ref-kind ref
		case [
			kind = 'i8 [1]
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
		return: [logic!]
		/local source-kind target-kind
	][
		if all [
			expected-flags = last-flags
			stack-type-compatible? expected last-type
		][
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
			emit instructions reduce [cast-op expected 0 0]
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
		emit instructions reduce [cast-op expected 0 0]
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

	float-literal?: func [value return: [logic!]][
		any [
			float? value
			all [issue? value not none? select ieee-754/special64 value]
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

	reference-kind?: func [kind [word! none!] return: [logic!]][
		not none? find [pointer c-string struct union] kind
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
		instructions [binary!]
		/local right right-flags left-kind right-kind common valid? comparison?
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
						reference-kind? left-kind
						left-flags = 0
						any [
							all [integer-kind? right-kind right-flags = 0]
							all [reference-kind? right-kind right-flags = 0]
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
						same-stack-type? left left-flags right right-flags
						any [
							float-kind? left-kind
							reference-kind? left-kind
							all [left-kind = 'logic operation <= 14]
						]
					]
				]
			]
			true [valid?: false]
		]
		unless valid? [fail ERROR-REFERENCE "incompatible binary operands"]
		emit instructions reduce [binary-op operation 0 0]
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
			position: skip position 3
			index: index + 1
		]
		none
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
			literal-end bits next-position source-ref source-flags source-literal?
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

		next-position: stack-value source scope uses instructions params locals
			expression-value
		source-ref: last-type
		source-flags: last-flags
		source-literal?: last-float-literal?
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
				find [pointer c-string] kind [
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

	stack-call: func [
		target [integer!]
		value [word! path!]
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		return: [block!]
		/local record return-ref parameters flags
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
		last-flags: either return-ref = 0 [0][flags and return-value-flag]
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
		/local after
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
		unless all [
			last-type <> 0
			coerce-stack function-return
				(function-flags and return-value-flag) instructions false
		][fail ERROR-REFERENCE "RETURN value does not match the function type"]
		emit instructions reduce [
			return-op function-return (function-flags and return-value-flag) 0
		]
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
		record: reduce [continue-target make block! 2 make block! 2 condition?]
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
		emit-local-address instructions slot
		after: stack-value next position scope uses instructions params locals
			expression-value
		unless all [(ref-kind last-type) = 'i32 last-flags = 0][
			fail ERROR-REFERENCE "LOOP requires an integer value"
		]
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
		emit-local-address instructions slot
		emit instructions reduce [load-op 0 0 0]
		emit instructions reduce [literal-op -5 1 0]
		emit instructions reduce [binary-op 2 0 0]
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

	stack-primary: func [
		position [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		locals [block!]
		value-context [integer!]
		return: [block!]
		/local value type-info next-position target id constant-key bytes offset
			inner wide bits
	][
		unless not tail? position [
			fail ERROR-UNSUPPORTED "missing expression"
		]
		value: position/1
		last-float-literal?: false
		last-stopped?: false
		case [
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
				type-info: stack-read-type next position scope uses
				emit instructions reduce [size-op type-info/2 0 0]
				last-type: -5
				last-flags: 0
				type-info/1
			]
			value = 'declare [
				fail ERROR-CONTEXT "DECLARE requires an assignment target"
			]
			any [get-word? value get-path? value][
				target: either get-word? value [to word! value][to path! value]
				unless stack-address target scope uses instructions params locals [
					fail ERROR-REFERENCE ["unknown address target " mold value]
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
				emit instructions reduce [literal-op -2 id 0]
				last-type: -2
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
				(length? value) = 3
				value/1 = 'system
				value/2 = 'stack
				value/3 = 'top
			][
				emit instructions reduce [native-op stack-top-native 0 -12]
				last-type: -12
				last-flags: 0
				next position
			]
			any [word? value path? value] [
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
						emit instructions reduce [load-op 0 0 0]
						last-flags: 0
						next position
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
		/local operation left left-flags
	][
		position: stack-primary position scope uses instructions params locals value-context
		while [not tail? position][
			operation: select binary-operations position/1
			unless integer? operation [break]
			left: last-type
			left-flags: last-flags
			position: stack-primary next position scope uses instructions params locals
				expression-value
			stack-binary operation left left-flags instructions
		]
		position
	]

	stack-static: func [
		position [block!]
		scope uses [block!]
		return: [logic!]
		/local value type-info next-position wide bits kind keep?
	][
		static?: false
		static-ref: 0
		static-low: 0
		static-high: 0
		static-next: position
		value: position/2
		case [
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
				static-ref: -2
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
				]
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
			target-flags
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
				record/3: global-reference-flag
				record/4: hidden
				record/5: 0
				last-type: 0
				last-flags: 0
				last-stopped?: false
				return next-position
			]
		]

		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		target-flags: last-flags
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

		either block? storage [
			record: storage/2
			either record/2 = 0 [
				record/2: ref
				record/3: 0
			][unless coerce-stack record/2 record/3 instructions false [
				fail ERROR-REFERENCE ["declaration changes type " mold target]
			]]
		][either integer? id [
			record: skip global-data ((id - 1) * 5)
			either integer? record/2 [
				unless coerce-stack record/2 0 instructions false [
					fail ERROR-REFERENCE ["declaration changes type " mold target]
				]
			][
				record/2: ref
				record/3: 0
			]
		][
			unless coerce-stack target-ref target-flags instructions false [
				fail ERROR-REFERENCE ["declaration changes type " mold target]
			]
		]]
		emit instructions reduce [set-op 0 0 0]
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
	][
		if (length? position) < 2 [fail ERROR-UNSUPPORTED "assignment value is missing"]
		target: either set-word? position/1 [
			to word! position/1
		][to path! position/1]
		storage: either word? target [stack-storage-info target params locals][none]
		id: either block? storage [none][resolve-name target scope uses globals]
		if position/2 = 'declare [
			return stack-declaration position target storage id scope uses instructions
				params locals fold?
		]
		if all [fold? integer? id][
			record: skip global-data ((id - 1) * 5)
			if all [
				not integer? record/2
				stack-static position scope uses
				static?
				any [
					tail? static-next
					none? select binary-operations static-next/1
				]
			][
				record/2: static-ref
				record/3: 0
				record/4: static-low
				record/5: static-high
				last-type: 0
				last-flags: 0
				return static-next
			]
		]
		unless stack-address/write target scope uses instructions params locals [
			fail ERROR-REFERENCE ["unknown assignment target " mold target]
		]
		target-ref: last-type
		target-flags: last-flags
		next-position: stack-value next position scope uses instructions params locals
			expression-value
		if last-stopped? [return next-position]
		either block? storage [
			record: storage/2
			either record/2 = 0 [
				record/2: last-type
				record/3: last-flags
			][
				unless coerce-stack record/2 record/3 instructions false [
					fail ERROR-REFERENCE ["local assignment changes type " mold target]
				]
			]
		][either integer? id [
			record: skip global-data ((id - 1) * 5)
			either integer? record/2 [
				unless coerce-stack record/2 0 instructions false [
					fail ERROR-REFERENCE ["global assignment changes type " mold target]
				]
			][record/2: last-type]
		][
			unless coerce-stack target-ref target-flags instructions false [
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
				return-flags: flags and return-value-flag
				unless coerce-stack return-ref return-flags instructions false [
					fail ERROR-REFERENCE "function result type does not match signature"
				]
				emit instructions reduce [return-op return-ref return-flags 0]
			]
		]
		count: to integer! (((length? instructions) - before) / 16)
		function-active?: false
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
			clear contexts
			clear types
			clear type-ids
			clear pointer-types
			clear aggregate-types
			clear constants
			clear imports
			clear import-ids
			clear libraries
			clear globals
			clear global-data
			clear module-code
			clear module-locals
			last-float-literal?: false
			clear function-code
			clear switches
			clear strings
			clear string-ids
			function-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
