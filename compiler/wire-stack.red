Red [
	Title: "Hybrid compiler RSIR explicit-stack verifier"
	File:  %wire-stack.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-exception [do %wire-exception.red]

compiler-wire-stack: context [
	schema: compiler-wire-schema
	exception-verifier: compiler-wire-exception

	state-exact: 1
	state-dynamic: 2
	max-depth: 2147483647
	stack-effects: schema/WIRE_EFFECT_FLAG_STACK
	opaque-stack-effects:
		schema/WIRE_EFFECT_FLAG_STACK + schema/WIRE_EFFECT_FLAG_OPAQUE

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_STACK_ERROR_SUCCESS
			exception-error: schema/WIRE_EXCEPTION_ERROR_SUCCESS
			subroutine-error: schema/WIRE_SUBROUTINE_ERROR_SUCCESS
			call-abi-error: schema/WIRE_CALL_ABI_ERROR_SUCCESS
			control-flow-error: schema/WIRE_CONTROL_FLOW_ERROR_SUCCESS
			scalar-operation-error: schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			type-layout-error: schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
			function-signature-error: schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
			module-lifecycle-error: schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
			symbol-linkage-error: schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
			constant-initializer-error:
				schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			types: none
			functions: none
			modules: none
			symbols: none
			constants: none
			scalar-view: none
			control-view: none
			call-view: none
			subroutine-view: none
			exception-view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-exception-result: func [result exception-result [object!]][
		result/header: exception-result/header
		result/exception-error: exception-result/error
		result/subroutine-error: exception-result/subroutine-error
		result/call-abi-error: exception-result/call-abi-error
		result/control-flow-error: exception-result/control-flow-error
		result/scalar-operation-error: exception-result/scalar-operation-error
		result/container-error: exception-result/container-error
		result/string-error: exception-result/string-error
		result/file-source-error: exception-result/file-source-error
		result/data-layout-error: exception-result/data-layout-error
		result/type-layout-error: exception-result/type-layout-error
		result/function-signature-error: exception-result/function-signature-error
		result/module-lifecycle-error: exception-result/module-lifecycle-error
		result/symbol-linkage-error: exception-result/symbol-linkage-error
		result/constant-initializer-error:
			exception-result/constant-initializer-error
	]

	record-value: func [data [binary!] base size id field [integer!]][
		exception-verifier/record-value data base size id field
	]

	instruction-value: func [data [binary!] scalar [object!] id field [integer!]][
		exception-verifier/instruction-value data scalar id field
	]

	operand-value: func [data [binary!] scalar [object!] id field [integer!]][
		exception-verifier/operand-value data scalar id field
	]

	value-value: func [data [binary!] scalar [object!] id field [integer!]][
		exception-verifier/value-value data scalar id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		exception-verifier/constant-value data constants id field
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		exception-verifier/type-value data types id field
	]

	function-value: func [data [binary!] functions [object!] id field [integer!]][
		exception-verifier/function-value data functions id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		exception-verifier/signature-value data functions id field
	]

	block-value: func [data [binary!] functions [object!] id field [integer!]][
		exception-verifier/block-value data functions id field
	]

	edge-value: func [data [binary!] control [object!] id field [integer!]][
		exception-verifier/edge-value data control id field
	]

	call-value: func [data [binary!] calls [object!] id field [integer!]][
		exception-verifier/call-value data calls id field
	]

	instruction-base: func [scalar [object!] id [integer!]][
		exception-verifier/instruction-base scalar id
	]

	operand-base: func [scalar [object!] id [integer!]][
		exception-verifier/operand-base scalar id
	]

	block-base: func [functions [object!] id [integer!]][
		exception-verifier/block-base functions id
	]

	value-base: func [scalar [object!] id [integer!]][
		scalar/values-offset + ((id - 1) * schema/WIRE_RSIR_VALUE_SIZE)
	]

	block-first-instruction: func [data [binary!] functions [object!] id [integer!]][
		block-value data functions id schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
	]

	block-instruction-count: func [data [binary!] functions [object!] id [integer!]][
		block-value data functions id schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
	]

	plain-signed-i32?: func [data [binary!] types [object!] id [integer!]][
		all [
			id > 0 id <= types/type-count
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_INTEGER
			(type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET)
				= schema/WIRE_TYPE_FLAG_SIGNED
		]
	]

	stack-pointer-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			id > 0 id <= types/type-count
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_POINTER
			plain-signed-i32? data types
				(type-value data types id schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
		]
	]

	pushable-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			id > 0 id <= types/type-count
			find reduce [
				schema/WIRE_TYPE_KIND_LOGIC
				schema/WIRE_TYPE_KIND_INTEGER
				schema/WIRE_TYPE_KIND_FLOAT
				schema/WIRE_TYPE_KIND_POINTER
				schema/WIRE_TYPE_KIND_FUNCTION
			] type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
		]
	]

	operand-type: func [
		data [binary!] scalar constants [object!] operand-id [integer!]
		/local kind reference
	][
		kind: operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value data scalar operand-id
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = schema/WIRE_OPERAND_KIND_VALUE [
				value-value data scalar reference schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			]
			kind = schema/WIRE_OPERAND_KIND_CONSTANT [
				constant-value data constants reference schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
			]
			true [none]
		]
	]

	known-i32-constant: func [
		data [binary!] constants [object!] constant-id [integer!]
		/local kind data-size data-offset byte-offset raw high
	][
		kind: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
		if kind = schema/WIRE_CONSTANT_KIND_ZERO [return 0]
		unless kind = schema/WIRE_CONSTANT_KIND_SCALAR [return none]
		data-size: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		unless data-size = 4 [return none]
		data-offset: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		byte-offset: constants/constant-data-offset + data-offset
		high: to integer! pick data (byte-offset + 4)
		if high >= 128 [high: high - 256]
		raw: (to integer! pick data (byte-offset + 1))
			+ ((to integer! pick data (byte-offset + 2)) * 256)
			+ ((to integer! pick data (byte-offset + 3)) * 65536)
			+ (high * 16777216)
		raw
	]

	known-count: func [
		data [binary!] scalar constants [object!] operand-id [integer!]
		/local kind reference definition-kind definition-id opcode first operand-kind
	][
		kind: operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value data scalar operand-id
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		if kind = schema/WIRE_OPERAND_KIND_CONSTANT [
			return known-i32-constant data constants reference
		]
		unless kind = schema/WIRE_OPERAND_KIND_VALUE [return none]
		definition-kind: value-value data scalar reference
			schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
		unless definition-kind = schema/WIRE_VALUE_DEFINITION_INSTRUCTION [return none]
		definition-id: value-value data scalar reference
			schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		opcode: instruction-value data scalar definition-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless opcode = schema/WIRE_OPCODE_CONSTANT [return none]
		unless (instruction-value data scalar definition-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) = 1 [return none]
		first: instruction-value data scalar definition-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-kind: operand-value data scalar first schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		unless operand-kind = schema/WIRE_OPERAND_KIND_CONSTANT [return none]
		known-i32-constant data constants
			(operand-value data scalar first schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
	]

	make-state: does [
		make object! [
			seen?: false
			mismatch?: false
			kind: state-exact
			depth: 0
			push-id: 0
			saved-kind: state-exact
			saved-depth: 0
		]
	]

	copy-state: func [source [object!] /local destination][
		destination: make-state
		destination/seen?: source/seen?
		destination/mismatch?: source/mismatch?
		destination/kind: source/kind
		destination/depth: source/depth
		destination/push-id: source/push-id
		destination/saved-kind: source/saved-kind
		destination/saved-depth: source/saved-depth
		destination
	]

	set-state: func [destination source [object!]][
		destination/seen?: source/seen?
		destination/mismatch?: source/mismatch?
		destination/kind: source/kind
		destination/depth: source/depth
		destination/push-id: source/push-id
		destination/saved-kind: source/saved-kind
		destination/saved-depth: source/saved-depth
	]

	join-state: func [target incoming [object!] /local changed?][
		unless target/seen? [
			set-state target incoming
			return true
		]
		if target/mismatch? [return false]
		if any [incoming/mismatch? target/push-id <> incoming/push-id][
			target/mismatch?: true
			return true
		]
		changed?: false
		if all [
			target/kind = state-exact
			any [incoming/kind = state-dynamic target/depth <> incoming/depth]
		][
			target/kind: state-dynamic
			target/depth: 0
			changed?: true
		]
		if all [
			target/push-id <> 0
			target/saved-kind = state-exact
			any [
				incoming/saved-kind = state-dynamic
				target/saved-depth <> incoming/saved-depth
			]
		][
			target/saved-kind: state-dynamic
			target/saved-depth: 0
			changed?: true
		]
		changed?
	]

	adjust-depth: func [
		result state [object!] delta instruction-id [integer!] scalar [object!]
		analysis? [logic!]
		/local amount base
	][
		if state/kind = state-dynamic [return none]
		base: instruction-base scalar instruction-id
		either delta >= 0 [
			if state/depth > (max-depth - delta) [
				either analysis? [
					state/kind: state-dynamic
					state/depth: 0
					return none
				][
					return reject result schema/WIRE_STACK_ERROR_SCALAR_RANGE
						(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
			]
			state/depth: state/depth + delta
		][
			amount: negate delta
			if state/depth < amount [
				either analysis? [
					state/kind: state-dynamic
					state/depth: 0
					return none
				][
					return reject result schema/WIRE_STACK_ERROR_STACK_UNDERFLOW
						(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
			]
			state/depth: state/depth - amount
		]
		none
	]

	custom-call-count-operand: func [
		data [binary!] exception-result [object!] instruction-id [integer!]
		/local call-id signature-id flags
	][
		call-id: exception-verifier/call-id-for-instruction data
			exception-result/call-view instruction-id
		if call-id = 0 [return 0]
		signature-id: call-value data exception-result/call-view call-id
			schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET
		flags: signature-value data exception-result/functions signature-id
			schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		if (flags and schema/WIRE_FUNCTION_FLAG_CUSTOM) = 0 [return 0]
		call-value data exception-result/call-view call-id
			schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
	]

	transfer-instruction: func [
		data [binary!] result exception-result state [object!]
		instruction-id [integer!] analysis? [logic!]
		/local scalar constants opcode operand-id count failure
	][
		scalar: exception-result/scalar-view
		constants: exception-result/constants
		opcode: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		case [
			opcode = schema/WIRE_OPCODE_STACK_ALLOC [
				operand-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				count: known-count data scalar constants operand-id
				either none? count [
					state/kind: state-dynamic
					state/depth: 0
				][
					failure: adjust-depth result state count instruction-id scalar analysis?
					if failure [return failure]
				]
			]
			opcode = schema/WIRE_OPCODE_STACK_FREE [
				operand-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				count: known-count data scalar constants operand-id
				either none? count [
					state/kind: state-dynamic
					state/depth: 0
				][
					failure: adjust-depth result state (negate count)
						instruction-id scalar analysis?
					if failure [return failure]
				]
			]
			opcode = schema/WIRE_OPCODE_STACK_PUSH [
				failure: adjust-depth result state 1 instruction-id scalar analysis?
				if failure [return failure]
			]
			opcode = schema/WIRE_OPCODE_STACK_POP [
				failure: adjust-depth result state -1 instruction-id scalar analysis?
				if failure [return failure]
			]
			opcode = schema/WIRE_OPCODE_PUSH_ALL [
				if state/push-id <> 0 [
					unless analysis? [
						return reject result schema/WIRE_STACK_ERROR_NESTED_PUSH_ALL
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					return none
				]
				state/push-id: instruction-id
				state/saved-kind: state/kind
				state/saved-depth: state/depth
				state/kind: state-exact
				state/depth: 0
			]
			opcode = schema/WIRE_OPCODE_POP_ALL [
				if state/push-id = 0 [
					unless analysis? [
						return reject result schema/WIRE_STACK_ERROR_UNMATCHED_POP_ALL
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					return none
				]
				if any [state/kind <> state-exact state/depth <> 0][
					unless analysis? [
						return reject result schema/WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
				state/kind: state/saved-kind
				state/depth: state/saved-depth
				state/push-id: 0
				state/saved-kind: state-exact
				state/saved-depth: 0
			]
			opcode = schema/WIRE_OPCODE_CALL [
				operand-id: custom-call-count-operand data exception-result instruction-id
				if operand-id <> 0 [
					count: known-count data scalar constants operand-id
					either none? count [
						state/kind: state-dynamic
						state/depth: 0
					][
						failure: adjust-depth result state (negate count)
							instruction-id scalar analysis?
						if failure [return failure]
					]
				]
			]
			opcode = schema/WIRE_OPCODE_SUBROUTINE_RETURN [
				unless analysis? [
					if state/push-id <> 0 [
						return reject result schema/WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					if any [state/kind <> state-exact state/depth <> 0][
						return reject result
							schema/WIRE_STACK_ERROR_BAD_SUBROUTINE_STACK_DEPTH
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
			]
			true []
		]
		none
	]

	validate-instruction-shapes: func [
		data [binary!] result exception-result [object!]
		/local scalar constants types instruction-id opcode base subopcode flags effects
			expected-effects alias-kind alias-id operand-count result-count
			expected-operands expected-results first-operand operand-kind auxiliary
			type-id first-result count
	][
		scalar: exception-result/scalar-view
		constants: exception-result/constants
		types: exception-result/types
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if all [
				opcode >= schema/WIRE_OPCODE_STACK_ALLOC
				opcode <= schema/WIRE_OPCODE_POP_ALL
			][
				base: instruction-base scalar instruction-id
				subopcode: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
				either opcode = schema/WIRE_OPCODE_STACK_ALLOC [
					unless any [
						subopcode = schema/WIRE_STACK_ALLOCATION_MODE_UNINITIALIZED
						subopcode = schema/WIRE_STACK_ALLOCATION_MODE_ZEROED
					][
						return reject result schema/WIRE_STACK_ERROR_BAD_SUBOPCODE
							(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if subopcode <> 0 [
						return reject result schema/WIRE_STACK_ERROR_BAD_SUBOPCODE
							(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
				flags: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
				if flags <> 0 [
					return reject result schema/WIRE_STACK_ERROR_BAD_INSTRUCTION_FLAGS
						(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				effects: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				expected-effects: either any [
					opcode = schema/WIRE_OPCODE_PUSH_ALL
					opcode = schema/WIRE_OPCODE_POP_ALL
				][opaque-stack-effects][stack-effects]
				if effects <> expected-effects [
					return reject result schema/WIRE_STACK_ERROR_BAD_EFFECTS
						(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				alias-kind: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				alias-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
				if any [alias-kind <> schema/WIRE_ALIAS_KIND_NONE alias-id <> 0][
					return reject result schema/WIRE_STACK_ERROR_BAD_ALIAS
						(base + either alias-kind <> schema/WIRE_ALIAS_KIND_NONE [
							schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
						][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET])
						scalar/instructions-ordinal
				]

				expected-operands: case [
					any [
						opcode = schema/WIRE_OPCODE_STACK_ALLOC
						opcode = schema/WIRE_OPCODE_STACK_FREE
						opcode = schema/WIRE_OPCODE_STACK_PUSH
					][1]
					true [0]
				]
				expected-results: either any [
					opcode = schema/WIRE_OPCODE_STACK_ALLOC
					opcode = schema/WIRE_OPCODE_STACK_POP
				][1][0]
				operand-count: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
				if operand-count <> expected-operands [
					return reject result schema/WIRE_STACK_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				result-count: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
				if result-count <> expected-results [
					return reject result schema/WIRE_STACK_ERROR_BAD_RESULT_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
						scalar/instructions-ordinal
				]

				if expected-operands = 1 [
					first-operand: instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
					operand-kind: operand-value data scalar first-operand
						schema/WIRE_RSIR_OPERAND_KIND_OFFSET
					unless any [
						operand-kind = schema/WIRE_OPERAND_KIND_VALUE
						operand-kind = schema/WIRE_OPERAND_KIND_CONSTANT
					][
						return reject result schema/WIRE_STACK_ERROR_BAD_OPERAND_KIND
							((operand-base scalar first-operand)
								+ schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
							scalar/operands-ordinal
					]
					auxiliary: operand-value data scalar first-operand
						schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					if auxiliary <> 0 [
						return reject result
							schema/WIRE_STACK_ERROR_NONZERO_OPERAND_AUXILIARY
							((operand-base scalar first-operand)
								+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
							scalar/operands-ordinal
					]
					type-id: operand-type data scalar constants first-operand
					if any [
						opcode = schema/WIRE_OPCODE_STACK_ALLOC
						opcode = schema/WIRE_OPCODE_STACK_FREE
					][
						unless plain-signed-i32? data types type-id [
							return reject result schema/WIRE_STACK_ERROR_BAD_COUNT_TYPE
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						count: known-count data scalar constants first-operand
						if all [integer? count count < 0][
							return reject result schema/WIRE_STACK_ERROR_NEGATIVE_COUNT
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
					if opcode = schema/WIRE_OPCODE_STACK_PUSH [
						unless pushable-type? data types type-id [
							return reject result schema/WIRE_STACK_ERROR_BAD_PUSH_TYPE
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
				]

				if expected-results = 1 [
					first-result: instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
					type-id: value-value data scalar first-result
						schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					if all [
						opcode = schema/WIRE_OPCODE_STACK_ALLOC
						not stack-pointer-type? data types type-id
					][
						return reject result schema/WIRE_STACK_ERROR_BAD_ALLOC_TYPE
							((value-base scalar first-result)
								+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
							scalar/values-ordinal
					]
					if all [
						opcode = schema/WIRE_OPCODE_STACK_POP
						not plain-signed-i32? data types type-id
					][
						return reject result schema/WIRE_STACK_ERROR_BAD_POP_TYPE
							((value-base scalar first-result)
								+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
							scalar/values-ordinal
					]
				]
			]
			instruction-id: instruction-id + 1
		]
		none
	]

	simulate-block: func [
		data [binary!] result exception-result input [object!] block-id [integer!]
		analysis? [logic!]
		/local state first count instruction-id failure control functions scalar
			terminator ordinary-count
	][
		state: copy-state input
		functions: exception-result/functions
		scalar: exception-result/scalar-view
		control: exception-result/control-view
		first: block-first-instruction data functions block-id
		count: block-instruction-count data functions block-id
		instruction-id: first
		while [instruction-id < (first + count)][
			failure: transfer-instruction data result exception-result state
				instruction-id analysis?
			if failure [return failure]
			instruction-id: instruction-id + 1
		]
		unless analysis? [
			ordinary-count: exception-verifier/ordinary-edge-count data functions
				control block-id
			if all [state/push-id <> 0 ordinary-count = 0][
				terminator: first + count - 1
				return reject result schema/WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
					((instruction-base scalar terminator)
						+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]
		]
		state
	]

	seed-entry: func [states [block!] block-id [integer!] /local state seed][
		state: pick states block-id
		seed: make-state
		seed/seen?: true
		join-state state seed
	]

	verify-states: func [
		data [binary!] result exception-result [object!]
		/local functions control scalar subroutines states block-id state output
			changed? edge-id first-edge edge-count kind target function-id entry
			subroutine-id failure
	][
		functions: exception-result/functions
		control: exception-result/control-view
		scalar: exception-result/scalar-view
		subroutines: exception-result/subroutine-view
		states: make block! functions/block-count
		loop functions/block-count [append/only states make-state]

		; Function/subroutine entries and exception handlers are the roots admitted
		; by the lower verifier chain. Seeding every no-ordinary-incoming block also
		; keeps this pass total if that root policy is widened later.
		block-id: 1
		while [block-id <= functions/block-count][
			unless exception-verifier/block-has-ordinary-incoming? data control block-id [
				seed-entry states block-id
			]
			block-id: block-id + 1
		]
		function-id: 1
		while [function-id <= functions/function-count][
			entry: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
			seed-entry states entry
			function-id: function-id + 1
		]
		subroutine-id: 1
		while [subroutine-id <= subroutines/subroutine-count][
			entry: exception-verifier/subroutine-verifier/subroutine-value data
				subroutines subroutine-id schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
			seed-entry states entry
			subroutine-id: subroutine-id + 1
		]

		changed?: true
		while [changed?][
			changed?: false
			block-id: 1
			while [block-id <= functions/block-count][
				state: pick states block-id
				if all [state/seen? not state/mismatch?][
					output: simulate-block data result exception-result state block-id true
					first-edge: block-value data functions block-id
						schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
					edge-count: block-value data functions block-id
						schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
					edge-id: first-edge
					while [edge-count > 0][
						kind: edge-value data control edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
						if exception-verifier/ordinary-edge? kind [
							target: edge-value data control edge-id
								schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
							if join-state (pick states target) output [changed?: true]
						]
						edge-id: edge-id + 1
						edge-count: edge-count - 1
					]
				]
				block-id: block-id + 1
			]
		]

		block-id: 1
		while [block-id <= functions/block-count][
			state: pick states block-id
			if state/mismatch? [
				return reject result schema/WIRE_STACK_ERROR_STACK_STATE_MISMATCH
					(block-base functions block-id) functions/blocks-ordinal
			]
			block-id: block-id + 1
		]
		block-id: 1
		while [block-id <= functions/block-count][
			state: pick states block-id
			if state/seen? [
				failure: simulate-block data result exception-result state block-id false
				if all [object? failure in failure 'error] [return failure]
			]
			block-id: block-id + 1
		]
		none
	]

	verify: func [data /local result exception-result failure][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_STACK_ERROR_INVALID_ARGUMENTS 0 0
		]
		exception-result: exception-verifier/verify data
		inherit-exception-result result exception-result
		unless exception-result/valid? [
			return reject result schema/WIRE_STACK_ERROR_INVALID_EXCEPTION
				exception-result/error-offset exception-result/error-section
		]

		failure: validate-instruction-shapes data result exception-result
		if failure [return failure]
		failure: verify-states data result exception-result
		if failure [return failure]

		result/strings: exception-result/strings
		result/files: exception-result/files
		result/layout: exception-result/layout
		result/types: exception-result/types
		result/functions: exception-result/functions
		result/modules: exception-result/modules
		result/symbols: exception-result/symbols
		result/constants: exception-result/constants
		result/scalar-view: exception-result/scalar-view
		result/control-view: exception-result/control-view
		result/call-view: exception-result/call-view
		result/subroutine-view: exception-result/subroutine-view
		result/exception-view: exception-result/view
		result/valid?: true
		result
	]
]
