Red [
	Title: "Compact Red/System IR frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]

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
	constants: make hash! 256
	imports: make block! 256
	import-ids: make hash! 256
	globals: make hash! 1024
	global-blocks: make block! 64
	function-count: 0
	type-count: 0
	import-count: 0
	global-count: 0

	type-kinds: make hash! [
		int8! i8 byte! u8 uint8! u8 int16! i16 uint16! u16
		integer! i32 int32! i32 uint32! u32 int64! i64 uint64! u64
		float32! f32 float! f64 float64! f64 logic! logic
		pointer! pointer c-string! pointer struct! pointer union! pointer
		function! pointer subroutine! pointer array! pointer
		byte-ptr! pointer int-ptr! pointer ptr-ptr! pointer
		float32-ptr! pointer
	]

	type-codes: make hash! [
		i8 1 u8 2 i16 3 u16 4 i32 5 u32 6 i64 7 u64 8
		f32 9 f64 10 logic 11 pointer 12
		alias -1 struct -2 union -3 function -4 subroutine -5
	]

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
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

	type-kind: func [
		type [block!]
		scope uses [block!]
		/local name kind id record steps
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
				name: record/3
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
		/local name kind code id
	][
		unless all [not empty? type any [word? type/1 path? type/1]][
			fail ERROR-UNSUPPORTED "invalid type reference"
		]
		name: type/1
		kind: type-kind type scope uses
		unless kind [fail ERROR-UNSUPPORTED ["unsupported type " mold type]]
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

	compile-body: func [
		kind [word!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		/local expression value callee position callee-params argument type ref
			param-count argument-id result-id before
	][
		before: length? instructions
		either kind = 'void [
			unless empty? body [
				fail ERROR-UNSUPPORTED "void function body must be empty"
			]
			emit instructions [2 0 0 0]                ; return void
		][
			expression: either all [not empty? body body/1 = 'return][next body][body]
			param-count: (length? params) / 2
			result-id: 0
			case [
				all [not empty? expression expression/1 = 'size?][
					unless any [
						all [
							(length? expression) = 2
							any [word? expression/2 path? expression/2]
						]
						all [
							(length? expression) = 3
							expression/2 = 'pointer!
							block? expression/3
						]
					][fail ERROR-UNSUPPORTED "size? requires a logical type"]
					type: copy next expression
					ref: type-ref type scope uses
					result-id: param-count + 1
					emit instructions reduce [
						5 result-id ref 0                     ; target size
					]
				]
				(length? expression) = 1 [
					value: expression/1
					if all [
						word? value
						not empty? params
						value = params/1
					][
						result-id: 1
					]
					if integer? value [
						result-id: param-count + 1
						emit instructions reduce [
							1 result-id 0 value                ; i32 literal
						]
					]
					if all [
						result-id = 0
						any [word? value path? value]
					][
						callee: resolve-name value scope uses function-ids
						unless integer? callee [
							fail ERROR-REFERENCE ["unknown value or function " mold value]
						]
						position: skip functions ((callee - 1) * 7)
						callee-params: position/7
						unless all [
							position/6 = 'i32
							empty? callee-params
						][
							fail ERROR-REFERENCE [
								"function " mold value " does not take zero arguments and return i32"
							]
						]
						result-id: param-count + 1
						emit instructions reduce [
							4 result-id callee 0               ; i32 call
						]
					]
					if result-id = 0 [
						fail ERROR-UNSUPPORTED "unsupported i32 return expression"
					]
				]
				(length? expression) = 2 [
					value: expression/1
					unless any [word? value path? value][
						fail ERROR-UNSUPPORTED "call target must be a function name"
					]
					callee: resolve-name value scope uses function-ids
					unless integer? callee [
						fail ERROR-REFERENCE ["unknown function " mold value]
					]
					position: skip functions ((callee - 1) * 7)
					callee-params: position/7
					unless all [
						position/6 = 'i32
						(length? callee-params) = 2
					][
						fail ERROR-REFERENCE [
							"function " mold value " does not take one argument and return i32"
						]
					]
					argument: expression/2
					argument-id: all [
						word? argument
						not empty? params
						argument = params/1
						1
					]
					unless integer? argument-id [
						unless integer? argument [
							fail ERROR-UNSUPPORTED "call argument must be an i32 literal or parameter"
						]
						argument-id: param-count + 1
						emit instructions reduce [
							1 argument-id 0 argument            ; i32 literal
						]
					]
					result-id: max (param-count + 1) (argument-id + 1)
					emit instructions reduce [
						4 result-id callee argument-id        ; i32 call
					]
				]
				true [
					fail ERROR-UNSUPPORTED
						"i32 body must return a value or direct call"
				]
			]
			emit instructions reduce [3 0 result-id 0]   ; return i32
		]
		((length? instructions) - before) / 16
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
		definitions scope [block!]
		/local position library cc entries entry name key external spec kind id
	][
		position: definitions
		while [not tail? position][
			unless all [
				(length? position) >= 3
				string? position/1
				find [cdecl stdcall] position/2
				block? position/3
			][fail ERROR-UNSUPPORTED "invalid import group"]
			library: position/1
			cc: position/2
			entries: position/3
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
				if any [select import-ids key select function-ids key][
					fail ERROR-DUPLICATE ["duplicate import " mold key]
				]
				external: entry/2
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
				append imports cc
				append/only imports spec
				append imports kind
				import-count: id
				entry: skip entry 3
			]
			position: skip position 3
		]
	]

	scan-block: func [
		values scope uses [block!]
		/local position name spec body child key kind target next-uses code?
			spelling id type-spec
	][
		code?: false
		position: values
		while [not tail? position][
			case [
				all [
					issue? position/1
					position/1 = #script
					(length? position) >= 2
					file? position/2
				][position: skip position 2]
				all [issue? position/1 position/1 = #user-code][
					code?: true
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
					scan-imports position/2 scope
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
					if any [select function-ids key select import-ids key][
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
					key: qualified scope to word! position/1
					unless select globals key [
						global-count: global-count + 1
						repend globals [key global-count]
					]
					code?: true
					position: next position
				]
				true [code?: true position: next position]
			]
		]
		if code? [
			append/only global-blocks values
			append/only global-blocks copy scope
			append/only global-blocks copy/deep uses
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
		unless empty? global-blocks [
			fail ERROR-UNSUPPORTED "global code lowering is unsupported"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
	]

	write-types: func [type-output fields [binary!] /local position kind spec scope uses
		field field-type ref flags count code
	][
		position: types
		while [not tail? position][
			kind: position/2
			case [
				kind = 'alias [
					code: select type-codes 'alias
					emit type-output reduce [
						code
						type-ref reduce [position/3] position/4 position/5
						0
					]
				]
				find [struct union] kind [
					code: select type-codes kind
					spec: position/3
					scope: position/4
					uses: position/5
					unless ((length? spec) // 2) = 0 [
						fail ERROR-UNSUPPORTED ["invalid aggregate type " mold position/1]
					]
					count: (length? spec) / 2
					emit type-output reduce [code 0 count]
					while [not tail? spec][
						field: spec/1
						field-type: spec/2
						unless all [
							word? field
							block? field-type
						][
							fail ERROR-UNSUPPORTED [
								"invalid aggregate member " mold position/1
							]
						]
						ref: type-ref field-type scope uses
						flags: either all [
							(length? field-type) = 2
							field-type/2 = 'value
						][1][0]
						if flags = 1 [
							unless find [struct union]
								(type-kind field-type scope uses) [
								fail ERROR-UNSUPPORTED [
									"only aggregate types can be passed by value"
								]
							]
						]
						emit fields reduce [ref flags]
						spec: skip spec 2
					]
				]
				find [function subroutine] kind [
					emit type-output reduce [(select type-codes kind) 0 0]
				]
				true [
					emit type-output reduce [(select type-codes kind) 0 0]
				]
			]
			position: skip position 5
		]
	]

	write-rsir: func [limit [integer!] /local output position name kind body
		scope uses params name-offset record-offset param-count signature count
		instruction-count size entry id record spec spec-position item type param-name
		type-output fields type-bytes field-bytes
	][
		record: functions
		while [not tail? record][
			spec: record/2
			scope: record/4
			uses: record/5
			kind: 'void
			params: make block! 2
			spec-position: spec
			while [not tail? spec-position][
				item: spec-position/1
				case [
					all [
						set-word? item
						item = to set-word! 'return
						(length? spec-position) >= 2
						block? spec-position/2
					][
						unless kind: type-kind spec-position/2 scope uses [
							fail ERROR-UNSUPPORTED "unsupported function return type"
						]
						spec-position: skip spec-position 2
					]
					all [
						word? item
						(length? spec-position) >= 2
						block? spec-position/2
					][
						param-name: item
						unless type: type-kind spec-position/2 scope uses [
							fail ERROR-UNSUPPORTED "unsupported parameter type"
						]
						if find/skip params param-name 2 [
							fail ERROR-UNSUPPORTED "duplicate function parameter"
						]
						repend params [param-name type]
						spec-position: skip spec-position 2
					]
					true [fail ERROR-UNSUPPORTED "function signature is unsupported"]
				]
			]
			unless any [
				all [kind = 'void empty? params]
				all [
					kind = 'i32
					((length? params) / 2) <= 1
					any [empty? params params/2 = 'i32]
				]
			][fail ERROR-UNSUPPORTED "function signature is unsupported"]
			record/6: kind
			record/7: params
			record: skip record 7
		]

		type-output: make binary! (type-count * 12)
		fields: make binary! 64
		write-types type-output fields
		type-bytes: length? type-output
		field-bytes: length? fields
		output: make binary! (20 + type-bytes + field-bytes + (function-count * 80))
		append/dup output 0 20
		append output type-output
		append output fields
		append/dup output 0 (function-count * 16)
		position: functions
		instruction-count: 0
		name-offset: 0
		id: 1
		while [not tail? position][
			name: position/1
			kind: position/6
			body: position/3
			scope: position/4
			uses: position/5
			params: position/7
			param-count: (length? params) / 2
			signature: case [
				kind = 'void [0]                       ; () -> void
				param-count = 0 [1]                    ; () -> i32
				true [2]                               ; (i32) -> i32
			]
			count: compile-body kind body scope uses output params
			record-offset: 21 + type-bytes + field-bytes + ((id - 1) * 16)
			change/part at output record-offset
				int-to-bin/to-bin32 name-offset 4
			change/part at output (record-offset + 4)
				int-to-bin/to-bin32 (length? name) 4
			change/part at output (record-offset + 8)
				int-to-bin/to-bin32 signature 4
			change/part at output (record-offset + 12)
				int-to-bin/to-bin32 count 4
			name-offset: name-offset + (length? name)
			instruction-count: instruction-count + count
			id: id + 1
			position: skip position 7
		]

		position: functions
		while [not tail? position][
			append output position/1
			position: skip position 7
		]
		size: length? output
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [function-count][0]
		change/part output int-to-bin/to-bin32 module-kind 4
		change/part at output 5 int-to-bin/to-bin32 entry 4
		change/part at output 9 int-to-bin/to-bin32 type-count 4
		change/part at output 13 int-to-bin/to-bin32 function-count 4
		change/part at output 17 int-to-bin/to-bin32 instruction-count 4
		output
	]

	compile: func [
		source [block!]
		kind [word!]
		/limit max-bytes [integer!]
		/local result
	][
		last-error: none
		result: catch/name [
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
			clear constants
			clear imports
			clear import-ids
			clear globals
			clear global-blocks
			function-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			compile-source source
			if import-count > 0 [
				fail ERROR-UNSUPPORTED "import lowering is unsupported"
			]
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
