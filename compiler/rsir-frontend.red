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
	global-data: make block! 1024
	module-code: make binary! 256
	strings: make binary! 256
	string-ids: make hash! 128
	function-count: 0
	type-count: 0
	import-count: 0
	global-count: 0
	module-value: 0

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

	return-value-flag: 4
	variadic-flag: 8
	typed-flag: 16
	custom-flag: 32
	callback-flag: 64
	objc-flag: 128
	catch-flag: 256

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

	type-flags: func [type [block!] scope uses [block!] /local kind][
		either all [(length? type) = 2 type/2 = 'value][
			unless find [struct union] kind: type-kind type scope uses [
				fail ERROR-UNSUPPORTED "only aggregate types can be passed by value"
			]
			1
		][0]
	]

	ref-kind: func [ref [integer!] /local record kind name steps][
		if ref < 0 [
			if ref < -12 [return none]
			return pick [i8 u8 i16 u16 i32 u32 i64 u64 f32 f64 logic pointer]
				negate ref
		]
		if any [ref = 0 ref > type-count][return none]
		steps: 0
		while [steps < type-count][
			record: skip types ((ref - 1) * 5)
			kind: record/2
			unless kind = 'alias [return kind]
			name: record/3
			if all [word? name kind: select type-kinds name][
				return kind
			]
			unless ref: resolve-name name record/4 record/5 type-ids [return none]
			steps: steps + 1
		]
		none
	]

	integer32-ref?: func [ref [integer!] /local kind][
		kind: ref-kind ref
		to logic! find [i32 u32] kind
	]

	pointer-ref?: func [ref [integer!] /local kind][
		kind: ref-kind ref
		to logic! find [pointer struct union function subroutine] kind
	]

	scalar-width: func [ref [integer!] /local kind][
		kind: ref-kind ref
		case [
			find [i32 u32] kind [4]
			find [pointer struct union function subroutine] kind [8]
			true [0]
		]
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
		/local position names-start item name type params names flags ref type-flags-value
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
					either locals? [
						if all [not tail? position block? position/1][
							type-ref position/1 scope uses
							type-flags position/1 scope uses
							position: next position
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
		reduce [return-ref params flags]
	]

	prepare-functions: func [/local record signature][
		record: functions
		while [not tail? record][
			signature: read-signature record/2 record/4 record/5
			record/6: signature/1
			record/7: signature/2
			record/8: signature/3
			record: skip record 8
		]
	]

	prepare-imports: func [/local record signature cc][
		record: imports
		while [not tail? record][
			cc: record/8
			either record/5 = 'function [
				signature: read-signature record/4 record/6 record/7
				if (signature/3 and 3) <> 0 [
					fail ERROR-UNSUPPORTED
						"import calling convention is specified twice"
				]
				record/8: signature/1
				record/9: signature/2
				record/10: signature/3 + either cc = 'cdecl [1][2]
			][
				record/8: type-ref record/4 record/6 record/7
				record/9: none
				record/10: 0
			]
			record: skip record 10
		]
	]

	set-global: func [
		position scope uses [block!]
		/local name id record value type kind ref low high after callee callee-record
			callee-return callee-params callee-flags bytes offset result
	][
		name: to word! position/1
		id: select globals qualified scope name
		unless integer? id [fail ERROR-REFERENCE ["unknown global " mold name]]
		record: skip global-data ((id - 1) * 4)
		if integer? record/2 [
			fail ERROR-UNSUPPORTED ["global reassignment is not lowered yet: " mold name]
		]
		value: position/2
		after: skip position 2
		ref: 0
		low: 0
		high: 0
		case [
			integer? value [ref: -5 low: value high: either value < 0 [-1][0]]
			logic? value [ref: -11 low: either value [1][0]]
			all [word? value find [true false yes no] value][
				ref: -11
				low: either find [true yes] value [1][0]
			]
			value = 'as [
				unless all [
					(length? position) >= 4
					any [word? position/3 path? position/3]
				][fail ERROR-UNSUPPORTED "static cast is missing its type or value"]
				type: reduce [position/3]
				after: skip position 3
				if all [
					word? position/3
					find [pointer! struct! union! function!] position/3
					block? after/1
				][
					append/only type after/1
					after: next after
				]
				if tail? after [
					fail ERROR-UNSUPPORTED "static cast is missing its value"
				]
				value: after/1
				after: next after
				kind: type-kind type scope uses
				case [
					all [
						integer? value
						find [i8 u8 i16 u16 i32 u32 i64 u64 pointer] kind
					][
						low: value
						high: either value < 0 [-1][0]
					]
					all [
						any [logic? value all [word? value find [true false yes no] value]]
						kind = 'logic
					][low: either any [value = true find [true yes] value][1][0]]
					true [
						fail ERROR-UNSUPPORTED [
							"global cast is not a static scalar: " mold type " " mold value
						]
					]
				]
				ref: type-ref type scope uses
			]
			all [
				any [word? value path? value]
				(length? position) >= 3
				string? position/3
			][
				callee: resolve-name value scope uses function-ids
				either integer? callee [
					callee-record: skip functions ((callee - 1) * 8)
					callee-return: callee-record/6
					callee-params: callee-record/7
					callee-flags: callee-record/8
				][
					callee: resolve-name value scope uses import-ids
					unless integer? callee [
						fail ERROR-REFERENCE ["unknown initializer function " mold value]
					]
					callee-record: skip imports ((callee - 1) * 10)
					unless callee-record/5 = 'function [
						fail ERROR-REFERENCE ["initializer target is not a function: " mold value]
					]
					callee-return: callee-record/8
					callee-params: callee-record/9
					callee-flags: callee-record/10
					callee: negate callee
				]
				unless all [
					callee-return <> 0
					(callee-flags and return-value-flag) = 0
					(length? callee-params) = 3
					pointer-ref? callee-params/2
					callee-params/3 = 0
					scalar-width callee-return
				][
					fail ERROR-UNSUPPORTED [
						"initializer function does not take c-string! and return a scalar: "
						mold value
					]
				]
				bytes: to binary! position/3
				offset: select string-ids bytes
				unless integer? offset [
					offset: length? strings
					repend string-ids [bytes offset]
					append strings bytes
					append strings 0
				]
				result: module-value + 1
				emit module-code reduce [
					9 result offset ((length? bytes) + 1)
					4 (result + 1) callee result
					10 0 id (result + 1)
				]
				module-value: result + 1
				ref: callee-return
				after: skip position 3
			]
			true [
				fail ERROR-UNSUPPORTED [
					"global initializer is not a static scalar: " mold value
				]
			]
		]
		record/2: ref
		record/3: low
		record/4: high
		after
	]

	compile-import-set: func [
		position scope uses [block!]
		instructions [binary!]
		/local target id record kind value
	][
		unless all [
			(length? position) >= 2
			any [set-word? position/1 set-path? position/1]
		][fail ERROR-UNSUPPORTED "imported variable assignment is incomplete"]
		target: either set-word? position/1 [
			to word! position/1
		][to path! position/1]
		id: resolve-name target scope uses import-ids
		unless integer? id [
			fail ERROR-REFERENCE ["unknown imported variable " mold target]
		]
		record: skip imports ((id - 1) * 10)
		unless record/5 = 'variable [
			fail ERROR-REFERENCE ["import " mold target " is not a variable"]
		]
		kind: type-kind record/4 record/6 record/7
		value: position/2
		case [
			all [find [i32 u32] kind integer? value] []
			all [
				kind = 'logic
				any [logic? value all [word? value find [true false yes no] value]]
			][value: either any [value = true find [true yes] value][1][0]]
			true [
				fail ERROR-UNSUPPORTED [
					"imported variable store is not a 32-bit scalar: "
					mold copy/part position 2
				]
			]
		]
		emit instructions reduce [8 0 id value]
		skip position 2
	]

	compile-module: func [
		values scope uses [block!]
		/local position name child target next-uses
	][
		position: values
		while [not tail? position][
			case [
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
				][
					position: skip position either find [
						struct! union! function! subroutine!
					] position/3 [4][3]
				]
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
					name: to word! position/1
					child: append copy scope name
					compile-module position/3 child uses
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
					compile-module position/3 scope next-uses
					position: skip position 3
				]
				all [set-word? position/1 (length? position) >= 2][
					position: set-global position scope uses
				]
				all [set-path? position/1 (length? position) >= 2][
					position: compile-import-set position scope uses module-code
				]
				true [
					fail ERROR-UNSUPPORTED [
						"global expression is not lowered yet: " mold position/1
					]
				]
			]
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
		append functions 0
		function-count: function-count + 1
	]

	compile-body: func [
		return-ref [integer!]
		body [block!]
		scope uses [block!]
		instructions [binary!]
		params [block!]
		flags [integer!]
		/local expression value callee global-id position callee-params argument type ref
			kind
			callee-return callee-flags param-count argument-id result-id before
	][
		before: length? instructions
		param-count: (length? params) / 3
		either return-ref = 0 [
			unless empty? params [
				fail ERROR-UNSUPPORTED "void parameters are not lowered yet"
			]
			case [
				empty? body []
				all [
					(length? body) = 2
					any [set-word? body/1 set-path? body/1]
				][
					compile-import-set body scope uses instructions
				]
				true [
					fail ERROR-UNSUPPORTED "void function body is not lowered yet"
				]
			]
			emit instructions [2 0 0 0]                ; return void
		][
			unless all [
				integer32-ref? return-ref
				(flags and return-value-flag) = 0
				param-count <= 1
				any [
					empty? params
					all [integer32-ref? params/2 params/3 = 0]
				]
			][fail ERROR-UNSUPPORTED "function body signature is not lowered yet"]
			expression: either all [not empty? body body/1 = 'return][next body][body]
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
						integer? global-id: resolve-name value scope uses globals
					][
						position: skip global-data ((global-id - 1) * 4)
						unless integer32-ref? position/2 [
							fail ERROR-UNSUPPORTED [
								"global " mold value " is not an i32 value"
							]
						]
						result-id: param-count + 1
						emit instructions reduce [
							6 result-id global-id 0            ; load global i32
						]
					]
					if all [
						result-id = 0
						any [word? value path? value]
					][
						callee: resolve-name value scope uses function-ids
						either integer? callee [
							kind: 'function
							position: skip functions ((callee - 1) * 8)
							callee-return: position/6
							callee-params: position/7
							callee-flags: position/8
						][
							callee: resolve-name value scope uses import-ids
							unless integer? callee [
								fail ERROR-REFERENCE [
									"unknown value or function " mold value
								]
							]
							position: skip imports ((callee - 1) * 10)
							kind: position/5
							if kind = 'function [
								callee-return: position/8
								callee-params: position/9
								callee-flags: position/10
								callee: 0 - callee
							]
						]
						either kind = 'variable [
							unless find [i32 u32] (
								type-kind position/4 position/6 position/7
							)[
								fail ERROR-REFERENCE [
									"import " mold value " is not an i32 variable"
								]
							]
							result-id: param-count + 1
							emit instructions reduce [
								7 result-id callee 0              ; load imported i32
							]
						][
							unless all [
								integer32-ref? callee-return
								(callee-flags and return-value-flag) = 0
								empty? callee-params
							][
								fail ERROR-REFERENCE [
									"function " mold value
									" does not take zero arguments and return i32"
								]
							]
							result-id: param-count + 1
							emit instructions reduce [
								4 result-id callee 0               ; i32 call
							]
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
					either integer? callee [
						position: skip functions ((callee - 1) * 8)
						callee-return: position/6
						callee-params: position/7
						callee-flags: position/8
					][
						callee: resolve-name value scope uses import-ids
						unless integer? callee [
							fail ERROR-REFERENCE ["unknown function " mold value]
						]
						position: skip imports ((callee - 1) * 10)
						unless position/5 = 'function [
							fail ERROR-REFERENCE ["import " mold value " is not a function"]
						]
						callee-return: position/8
						callee-params: position/9
						callee-flags: position/10
						callee: 0 - callee
					]
					unless all [
						integer32-ref? callee-return
						(callee-flags and return-value-flag) = 0
						(length? callee-params) = 3
						integer32-ref? callee-params/2
						callee-params/3 = 0
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
		definitions scope uses [block!]
		/local position library cc entries entry name key external spec kind id
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
					if any [select function-ids key select import-ids key][
						fail ERROR-DUPLICATE ["duplicate global " mold key]
					]
					unless select globals key [
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
			emit module-code [2 0 0 0]
			add-module-function
		]
		if all [module-kind <> 3 not empty? module-code][
			fail ERROR-UNSUPPORTED "runtime module body requires a glue module"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
	]

	write-types: func [type-output members [binary!] /local position kind spec scope uses
		field field-type ref flags count code first signature params parameter
	][
		first: 0
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
						first
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
					emit type-output reduce [code 0 0 first count]
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
						flags: type-flags field-type scope uses
						emit members reduce [ref flags]
						spec: skip spec 2
					]
					first: first + count
				]
				find [function subroutine] kind [
					signature: read-signature position/3 position/4 position/5
					params: signature/2
					count: (length? params) / 3
					emit type-output reduce [
						select type-codes kind
						signature/1
						signature/3
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

	write-rsir: func [limit [integer!] /local output position name body
		scope uses params flags record-offset param-count first-param count
		instruction-count size entry id parameter import-records global-records
		function-records
		library external last-library library-offset external-offset names
		type-output members type-bytes member-bytes
	][
		type-output: make binary! (type-count * 20)
		members: make binary! 64
		write-types type-output members
		type-bytes: length? type-output
		member-bytes: length? members
		names: copy strings
		output: make binary! (28 + type-bytes + member-bytes + (length? strings)
			+ (import-count * 64) + (global-count * 40) + (function-count * 96))
		append/dup output 0 28
		append output type-output
		append output members
		import-records: 29 + type-bytes + member-bytes
		global-records: import-records + (import-count * 32)
		function-records: global-records + (global-count * 20)
		append/dup output 0 (import-count * 32)
		append/dup output 0 (global-count * 20)
		append/dup output 0 (function-count * 28)

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
			record-offset: global-records + ((id - 1) * 20)
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
			append names name
			id: id + 1
			position: skip position 4
		]

		position: functions
		id: 1
		while [not tail? position][
			name: position/1
			params: position/7
			flags: position/8
			param-count: (length? params) / 3
			record-offset: function-records + ((id - 1) * 28)
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
			parameter: params
			while [not tail? parameter][
				emit output reduce [parameter/2 parameter/3]
				parameter: skip parameter 3
			]
			append names name
			first-param: first-param + param-count
			id: id + 1
			position: skip position 8
		]

		position: functions
		instruction-count: 0
		id: 1
		while [not tail? position][
			body: position/3
			scope: position/4
			uses: position/5
			params: position/7
			flags: position/8
			count: either binary? body [
				unless ((length? body) // 16) = 0 [
					fail ERROR-UNSUPPORTED "invalid module instruction stream"
				]
				append output body
				(length? body) / 16
			][compile-body position/6 body scope uses output params flags]
			record-offset: function-records + ((id - 1) * 28)
			change/part at output (record-offset + 24)
				int-to-bin/to-bin32 count 4
			instruction-count: instruction-count + count
			id: id + 1
			position: skip position 8
		]

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
			clear global-data
			clear module-code
			clear strings
			clear string-ids
			function-count: 0
			type-count: 0
			import-count: 0
			global-count: 0
			module-value: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
