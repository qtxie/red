Red [
	Title: "Hybrid compiler RSIR scalar value and operation verifier"
	File:  %wire-scalar-operation.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-constant-initializer [do %wire-constant-initializer.red]

compiler-wire-scalar-operation: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	constant-verifier: compiler-wire-constant-initializer

	value-fields: reduce [
		'definition-kind schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
		'definition-id schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		'result-ordinal schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
		'type schema/WIRE_RSIR_VALUE_TYPE_OFFSET
		'function schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET
		'flags schema/WIRE_RSIR_VALUE_FLAGS_OFFSET
	]

	instruction-fields: reduce [
		'block schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
		'opcode schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		'subopcode schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		'flags schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		'first-result schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
		'result-count schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		'first-operand schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		'operand-count schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		'effect-flags schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		'alias-kind schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		'alias-id schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		'source-location schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET
	]

	operand-fields: reduce [
		'kind schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		'reference schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		'auxiliary schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
		'flags schema/WIRE_RSIR_OPERAND_FLAGS_OFFSET
	]

	make-view: does [
		make object! [
			values-offset: 0
			value-count: 0
			value-record-size: schema/WIRE_RSIR_VALUE_SIZE
			values-ordinal: 0
			instructions-offset: 0
			instruction-count: 0
			instruction-record-size: schema/WIRE_RSIR_INSTRUCTION_SIZE
			instructions-ordinal: 0
			operands-offset: 0
			operand-count: 0
			operand-record-size: schema/WIRE_RSIR_OPERAND_SIZE
			operands-ordinal: 0
			target-fragment-count: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
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
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	value-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/values-offset schema/WIRE_RSIR_VALUE_SIZE id field
	]

	instruction-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/instructions-offset
			schema/WIRE_RSIR_INSTRUCTION_SIZE id field
	]

	operand-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/operands-offset schema/WIRE_RSIR_OPERAND_SIZE id field
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		record-value data types/types-offset schema/WIRE_RSIR_TYPE_SIZE id field
	]

	function-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/functions-offset schema/WIRE_RSIR_FUNCTION_SIZE id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/signatures-offset schema/WIRE_RSIR_SIGNATURE_SIZE id field
	]

	local-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/locals-offset schema/WIRE_RSIR_LOCAL_SIZE id field
	]

	block-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/blocks-offset schema/WIRE_RSIR_BLOCK_SIZE id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		record-value data constants/constants-offset schema/WIRE_RSIR_CONSTANT_SIZE id field
	]

	valid-type?: func [types [object!] id [integer!]][
		all [id > 0 id <= types/type-count]
	]

	type-kind: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
	]

	type-size: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET
	]

	type-flags: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
	]

	type-gc-kind: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET
	]

	integer-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_INTEGER
	]

	float-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_FLOAT
	]

	logic-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_LOGIC
	]

	address-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [schema/WIRE_TYPE_KIND_POINTER schema/WIRE_TYPE_KIND_FUNCTION]
			type-kind data types id
	]

	pointer-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_POINTER
	]

	scalar-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [
			schema/WIRE_TYPE_KIND_LOGIC
			schema/WIRE_TYPE_KIND_INTEGER
			schema/WIRE_TYPE_KIND_FLOAT
			schema/WIRE_TYPE_KIND_POINTER
			schema/WIRE_TYPE_KIND_FUNCTION
		] type-kind data types id
	]

	ordinary-integer?: func [data [binary!] types [object!] id [integer!]][
		all [
			integer-type? data types id
			(type-gc-kind data types id) = schema/WIRE_GC_KIND_NONE
		]
	]

	handle-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			integer-type? data types id
			(type-gc-kind data types id) = schema/WIRE_GC_KIND_HANDLE
		]
	]

	plain-signed-i32?: func [data [binary!] types [object!] id [integer!]][
		all [
			ordinary-integer? data types id
			(type-size data types id) = 4
			(type-flags data types id) = schema/WIRE_TYPE_FLAG_SIGNED
		]
	]

	f32-type?: func [data [binary!] types [object!] id [integer!]][
		all [float-type? data types id (type-size data types id) = 4]
	]

	same-integer-representation?: func [
		data [binary!] types [object!] left right [integer!]
	][
		all [
			integer-type? data types left
			integer-type? data types right
			(type-size data types left) = (type-size data types right)
			(type-flags data types left) = (type-flags data types right)
		]
	]

	compatible-integers?: func [
		data [binary!] types [object!] left right [integer!]
	][
		all [
			same-integer-representation? data types left right
			any [
				left = right
				handle-type? data types left
				handle-type? data types right
			]
		]
	]

	plain-integer-result?: func [
		data [binary!] types [object!] source result [integer!]
	][
		all [
			same-integer-representation? data types source result
			ordinary-integer? data types result
			any [source = result handle-type? data types source]
		]
	]

	valid-convert?: func [
		data [binary!] types [object!] source target [integer!]
		/local source-kind target-kind source-size target-size
	][
		if any [source = target handle-type? data types source handle-type? data types target][
			return false
		]
		source-kind: type-kind data types source
		target-kind: type-kind data types target
		source-size: type-size data types source
		target-size: type-size data types target
		case [
			all [ordinary-integer? data types source ordinary-integer? data types target][
				source-size <> target-size
			]
			all [logic-type? data types source ordinary-integer? data types target][true]
			all [
				any [ordinary-integer? data types source address-type? data types source]
				logic-type? data types target
			][true]
			all [plain-signed-i32? data types source float-type? data types target][true]
			all [float-type? data types source plain-signed-i32? data types target][true]
			all [float-type? data types source float-type? data types target][
				source-size <> target-size
			]
			all [
				ordinary-integer? data types source
				address-type? data types target
			][source-size <> target-size]
			all [
				address-type? data types source
				ordinary-integer? data types target
			][source-size <> target-size]
			true [false]
		]
	]

	valid-bitcast?: func [
		data [binary!] types [object!] source target [integer!]
		/local source-size target-size
	][
		if any [source = target handle-type? data types source handle-type? data types target][
			return false
		]
		source-size: type-size data types source
		target-size: type-size data types target
		if source-size <> target-size [return false]
		case [
			all [ordinary-integer? data types source ordinary-integer? data types target][
				(type-flags data types source) <> (type-flags data types target)
			]
			all [address-type? data types source address-type? data types target][true]
			all [
				ordinary-integer? data types source
				address-type? data types target
			][true]
			all [
				address-type? data types source
				ordinary-integer? data types target
			][true]
			all [plain-signed-i32? data types source f32-type? data types target][true]
			all [f32-type? data types source plain-signed-i32? data types target][true]
			true [false]
		]
	]

	inherit-constant-errors: func [result constant-result [object!]][
		result/header: constant-result/header
		result/container-error: constant-result/container-error
		result/string-error: constant-result/string-error
		result/file-source-error: constant-result/file-source-error
		result/data-layout-error: constant-result/data-layout-error
		result/type-layout-error: constant-result/type-layout-error
		result/function-signature-error: constant-result/function-signature-error
		result/module-lifecycle-error: constant-result/module-lifecycle-error
		result/symbol-linkage-error: constant-result/symbol-linkage-error
		result/constant-initializer-error: constant-result/error
	]

	map-constant-error: func [code [integer!]][
		case [
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_STRINGS [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_STRINGS
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FILE_SOURCE [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_FILE_SOURCE
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_DATA_LAYOUT [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_DATA_LAYOUT
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_TYPE_LAYOUT [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_TYPE_LAYOUT
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FUNCTION_SIGNATURE [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_FUNCTION_SIGNATURE
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_MODULE_LIFECYCLE [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_MODULE_LIFECYCLE
			]
			code = schema/WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_SYMBOL_LINKAGE [
				schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_SYMBOL_LINKAGE
			]
			true [schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_CONSTANT_INITIALIZER]
		]
	]

	verify-scalar-instruction: func [
		data [binary!] result [object!] constants-result [object!] view [object!]
		instruction-id [integer!]
		/local base opcode subopcode flags checked? expected-operands expected-results
			first-result result-count first-operand operand-count alias-kind alias-id
			operand-id operand-base operand-kind operand-reference auxiliary
			left-type right-type result-type second-result-type kind expected-effects
			valid? compare-kind source-kind target-kind
	][
		base: record-offset view/instructions-offset (instruction-id - 1)
			schema/WIRE_RSIR_INSTRUCTION_SIZE
		opcode: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode > schema/WIRE_OPCODE_COMPARE [return none]

		subopcode: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		either opcode = schema/WIRE_OPCODE_COMPARE [
			unless all [
				subopcode >= schema/WIRE_COMPARE_KIND_EQUAL
				subopcode <= schema/WIRE_COMPARE_KIND_GREATER_EQUAL
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_KIND
					(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		][
			if subopcode <> 0 [
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_SUBOPCODE
					(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]

		flags: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		unless find reduce [0 schema/WIRE_INSTRUCTION_FLAG_CHECKED] flags [
			return reject result
				schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_INSTRUCTION_FLAGS
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		checked?: flags = schema/WIRE_INSTRUCTION_FLAG_CHECKED

		alias-kind: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if any [alias-kind <> schema/WIRE_ALIAS_KIND_NONE alias-id <> 0][
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_ALIAS
				(base + either alias-kind <> schema/WIRE_ALIAS_KIND_NONE [
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET])
				view/instructions-ordinal
		]

		expected-operands: either find reduce [
			schema/WIRE_OPCODE_CONSTANT schema/WIRE_OPCODE_COPY
			schema/WIRE_OPCODE_CONVERT schema/WIRE_OPCODE_BITCAST
			schema/WIRE_OPCODE_NEGATE schema/WIRE_OPCODE_BIT_NOT
			schema/WIRE_OPCODE_LOGIC_NOT
		] opcode [1][2]
		operand-count: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if operand-count <> expected-operands [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]
		first-operand: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET

		expected-results: either checked? [2][1]
		result-count: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		if result-count <> expected-results [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_RESULT_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]
		first-result: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			operand-base: record-offset view/operands-offset (operand-id - 1)
				schema/WIRE_RSIR_OPERAND_SIZE
			operand-kind: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			if operand-kind <> either opcode = schema/WIRE_OPCODE_CONSTANT [
				schema/WIRE_OPERAND_KIND_CONSTANT
			][schema/WIRE_OPERAND_KIND_VALUE][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_KIND
					(operand-base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			auxiliary: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return reject result
					schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_SCALAR_OPERAND_AUXILIARY
					(operand-base + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		operand-reference: operand-value data view first-operand
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		left-type: either opcode = schema/WIRE_OPCODE_CONSTANT [
			constant-value data constants-result/view operand-reference
				schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
		][
			value-value data view operand-reference schema/WIRE_RSIR_VALUE_TYPE_OFFSET
		]
		right-type: 0
		if operand-count = 2 [
			operand-reference: operand-value data view (first-operand + 1)
				schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			right-type: value-value data view operand-reference
				schema/WIRE_RSIR_VALUE_TYPE_OFFSET
		]
		result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET

		unless scalar-type? data constants-result/types result-type [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_TYPE
				((record-offset view/values-offset (first-result - 1)
					schema/WIRE_RSIR_VALUE_SIZE) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
				view/values-ordinal
		]

		valid?: false
		case [
			opcode = schema/WIRE_OPCODE_CONSTANT [
				valid?: all [
					scalar-type? data constants-result/types left-type
					left-type = result-type
				]
			]
			opcode = schema/WIRE_OPCODE_COPY [
				valid?: all [scalar-type? data constants-result/types left-type left-type = result-type]
			]
			opcode = schema/WIRE_OPCODE_CONVERT [
				valid?: valid-convert? data constants-result/types left-type result-type
				if not valid? [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION
						((record-offset view/values-offset (first-result - 1)
							schema/WIRE_RSIR_VALUE_SIZE) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_BITCAST [
				valid?: valid-bitcast? data constants-result/types left-type result-type
				if not valid? [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST
						((record-offset view/values-offset (first-result - 1)
							schema/WIRE_RSIR_VALUE_SIZE) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			find reduce [schema/WIRE_OPCODE_ADD schema/WIRE_OPCODE_SUBTRACT] opcode [
				kind: type-kind data constants-result/types left-type
				case [
					kind = schema/WIRE_TYPE_KIND_POINTER [
						valid?: all [
							left-type = result-type
							any [
								ordinary-integer? data constants-result/types right-type
								pointer-type? data constants-result/types right-type
							]
						]
					]
					kind = schema/WIRE_TYPE_KIND_INTEGER [
						valid?: all [
							compatible-integers? data constants-result/types left-type right-type
							plain-integer-result? data constants-result/types left-type result-type
						]
					]
					kind = schema/WIRE_TYPE_KIND_FLOAT [
						valid?: all [left-type = right-type left-type = result-type]
					]
					true [valid?: false]
				]
			]
			find reduce [schema/WIRE_OPCODE_MULTIPLY schema/WIRE_OPCODE_DIVIDE] opcode [
				kind: type-kind data constants-result/types left-type
				valid?: case [
					kind = schema/WIRE_TYPE_KIND_INTEGER [
						all [
							compatible-integers? data constants-result/types left-type right-type
							plain-integer-result? data constants-result/types left-type result-type
						]
					]
					kind = schema/WIRE_TYPE_KIND_FLOAT [
						all [left-type = right-type left-type = result-type]
					]
					true [false]
				]
			]
			find reduce [schema/WIRE_OPCODE_REMAINDER schema/WIRE_OPCODE_MODULO] opcode [
				valid?: all [
					compatible-integers? data constants-result/types left-type right-type
					plain-integer-result? data constants-result/types left-type result-type
				]
			]
			opcode = schema/WIRE_OPCODE_NEGATE [
				kind: type-kind data constants-result/types left-type
				valid?: case [
					kind = schema/WIRE_TYPE_KIND_INTEGER [
						plain-integer-result? data constants-result/types left-type result-type
					]
					kind = schema/WIRE_TYPE_KIND_FLOAT [left-type = result-type]
					true [false]
				]
			]
			opcode = schema/WIRE_OPCODE_BIT_NOT [
				valid?: plain-integer-result? data constants-result/types left-type result-type
			]
			opcode = schema/WIRE_OPCODE_LOGIC_NOT [
				valid?: all [logic-type? data constants-result/types left-type left-type = result-type]
			]
			find reduce [
				schema/WIRE_OPCODE_SHIFT_LEFT schema/WIRE_OPCODE_SHIFT_RIGHT
				schema/WIRE_OPCODE_SHIFT_RIGHT_LOGICAL
			] opcode [
				unless plain-signed-i32? data constants-result/types right-type [
					operand-base: record-offset view/operands-offset first-operand
						schema/WIRE_RSIR_OPERAND_SIZE
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SHIFT_COUNT_TYPE
						(operand-base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				valid?: plain-integer-result? data constants-result/types left-type result-type
			]
			find reduce [
				schema/WIRE_OPCODE_BIT_AND schema/WIRE_OPCODE_BIT_OR schema/WIRE_OPCODE_BIT_XOR
			] opcode [
				kind: type-kind data constants-result/types left-type
				valid?: case [
					kind = schema/WIRE_TYPE_KIND_INTEGER [
						all [
							compatible-integers? data constants-result/types left-type right-type
							plain-integer-result? data constants-result/types left-type result-type
						]
					]
					kind = schema/WIRE_TYPE_KIND_LOGIC [
						all [left-type = right-type left-type = result-type]
					]
					true [false]
				]
			]
			opcode = schema/WIRE_OPCODE_COMPARE [
				kind: type-kind data constants-result/types left-type
				compare-kind: type-kind data constants-result/types right-type
				valid?: case [
					kind = schema/WIRE_TYPE_KIND_INTEGER [
						compatible-integers? data constants-result/types left-type right-type
					]
					kind = schema/WIRE_TYPE_KIND_FLOAT [left-type = right-type]
					kind = schema/WIRE_TYPE_KIND_LOGIC [left-type = right-type]
					kind = schema/WIRE_TYPE_KIND_POINTER [
						compare-kind = schema/WIRE_TYPE_KIND_POINTER
					]
					kind = schema/WIRE_TYPE_KIND_FUNCTION [
						compare-kind = schema/WIRE_TYPE_KIND_FUNCTION
					]
					true [false]
				]
				unless valid? [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_TYPE
						((record-offset view/operands-offset first-operand
							schema/WIRE_RSIR_OPERAND_SIZE)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				valid?: logic-type? data constants-result/types result-type
			]
			true [assert false "unreachable scalar opcode"]
		]

		unless valid? [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH
				((record-offset view/values-offset (first-result - 1)
					schema/WIRE_RSIR_VALUE_SIZE) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
				view/values-ordinal
		]

		if checked? [
			unless all [
				integer-type? data constants-result/types left-type
				find reduce [
					schema/WIRE_OPCODE_ADD schema/WIRE_OPCODE_SUBTRACT
					schema/WIRE_OPCODE_MULTIPLY schema/WIRE_OPCODE_DIVIDE
					schema/WIRE_OPCODE_REMAINDER schema/WIRE_OPCODE_MODULO
					schema/WIRE_OPCODE_SHIFT_LEFT
				] opcode
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_OPERATION
					(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
					view/instructions-ordinal
			]
			second-result-type: value-value data view (first-result + 1)
				schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			unless logic-type? data constants-result/types second-result-type [
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_RESULT
					((record-offset view/values-offset first-result
						schema/WIRE_RSIR_VALUE_SIZE) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
					view/values-ordinal
			]
		]

		expected-effects: 0
		kind: type-kind data constants-result/types left-type
		if all [
			kind = schema/WIRE_TYPE_KIND_INTEGER
			find reduce [
				schema/WIRE_OPCODE_DIVIDE schema/WIRE_OPCODE_REMAINDER
				schema/WIRE_OPCODE_MODULO
			] opcode
		][expected-effects: schema/WIRE_EFFECT_FLAG_MAY_TRAP]
		if all [
			kind = schema/WIRE_TYPE_KIND_FLOAT
			find reduce [
				schema/WIRE_OPCODE_ADD schema/WIRE_OPCODE_SUBTRACT
				schema/WIRE_OPCODE_MULTIPLY schema/WIRE_OPCODE_DIVIDE
				schema/WIRE_OPCODE_COMPARE
			] opcode
		][expected-effects: schema/WIRE_EFFECT_FLAG_MAY_TRAP]
		if all [
			opcode = schema/WIRE_OPCODE_CONVERT
			any [
				float-type? data constants-result/types left-type
				float-type? data constants-result/types result-type
			]
		][expected-effects: schema/WIRE_EFFECT_FLAG_MAY_TRAP]
		if (instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) <> expected-effects
		[
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS
				(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		none
	]

	verify: func [
		data
		/local result constants-result container-result values instructions operands
			target-fragments view count base size ordinal fields record-index
			record-base field-name field-offset value value-id definition-kind
			definition-id result-ordinal value-type function-id flags instruction-id
			block-id opcode first-result result-count first-operand operand-count finish
			source-location cursor block-count instruction-block operand-id kind reference
			reference-count owner-function argument-index signature-id parameter-count
			first-local local-id expected-type block-first function-block-count
			block-end result-id expected-offset failure
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS 0 0
		]

		constants-result: constant-verifier/verify data
		inherit-constant-errors result constants-result
		unless constants-result/valid? [
			return reject result (map-constant-error constants-result/error)
				constants-result/error-offset constants-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		values: container/find-section container-result schema/WIRE_RSIR_SECTION_VALUES
		instructions:
			container/find-section container-result schema/WIRE_RSIR_SECTION_INSTRUCTIONS
		operands: container/find-section container-result schema/WIRE_RSIR_SECTION_OPERANDS
		target-fragments:
			container/find-section container-result schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS
		if any [none? values none? instructions none? operands none? target-fragments][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		foreach [section code] reduce [
			values schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_SECTION_FLAGS
			instructions schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SECTION_FLAGS
			operands schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_SECTION_FLAGS
		][
			if (select section 'flags) <> 0 [
				return reject result code (section-flags-offset section)
					(select section 'ordinal)
			]
		]

		view: make-view
		view/values-offset: select values 'payload-offset
		view/value-count: select values 'record-count
		view/value-record-size: select values 'record-size
		view/values-ordinal: select values 'ordinal
		view/instructions-offset: select instructions 'payload-offset
		view/instruction-count: select instructions 'record-count
		view/instruction-record-size: select instructions 'record-size
		view/instructions-ordinal: select instructions 'ordinal
		view/operands-offset: select operands 'payload-offset
		view/operand-count: select operands 'record-count
		view/operand-record-size: select operands 'record-size
		view/operands-ordinal: select operands 'ordinal
		view/target-fragment-count: select target-fragments 'record-count

		; Decode every signed scalar before following a semantic reference.
		foreach [count base size ordinal fields] reduce [
			view/value-count view/values-offset schema/WIRE_RSIR_VALUE_SIZE
				view/values-ordinal value-fields
			view/instruction-count view/instructions-offset schema/WIRE_RSIR_INSTRUCTION_SIZE
				view/instructions-ordinal instruction-fields
			view/operand-count view/operands-offset schema/WIRE_RSIR_OPERAND_SIZE
				view/operands-ordinal operand-fields
		][
			record-index: 0
			while [record-index < count][
				record-base: record-offset base record-index size
				foreach [field-name field-offset] fields [
					value: container/read-i31 data (record-base + field-offset)
					if none? value [
						return reject result schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_RANGE
							(record-base + field-offset) ordinal
					]
				]
				record-index: record-index + 1
			]
		]

		value-id: 1
		while [value-id <= view/value-count][
			record-base: record-offset view/values-offset (value-id - 1)
				schema/WIRE_RSIR_VALUE_SIZE
			definition-kind: value-value data view value-id
				schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
			unless find reduce [
				schema/WIRE_VALUE_DEFINITION_PARAMETER
				schema/WIRE_VALUE_DEFINITION_INSTRUCTION
			] definition-kind [
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_KIND
					(record-base + schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
					view/values-ordinal
			]
			definition-id: value-value data view value-id
				schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
			if any [
				definition-id <= 0
				definition-id > either definition-kind = schema/WIRE_VALUE_DEFINITION_PARAMETER [
					constants-result/functions/local-count
				][view/instruction-count]
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_ID
					(record-base + schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET)
					view/values-ordinal
			]
			result-ordinal: value-value data view value-id
				schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
			if all [
				definition-kind = schema/WIRE_VALUE_DEFINITION_PARAMETER
				result-ordinal <> 0
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_RESULT_ORDINAL
					(record-base + schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET)
					view/values-ordinal
			]
			value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			if any [
				not valid-type? constants-result/types value-type
				all [
					valid-type? constants-result/types value-type
					(type-kind data constants-result/types value-type)
						= schema/WIRE_TYPE_KIND_VOID
				]
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_TYPE
					(record-base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET) view/values-ordinal
			]
			function-id: value-value data view value-id schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET
			if any [function-id <= 0 function-id > constants-result/functions/function-count][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_FUNCTION
					(record-base + schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET)
					view/values-ordinal
			]
			flags: value-value data view value-id schema/WIRE_RSIR_VALUE_FLAGS_OFFSET
			if flags <> schema/WIRE_VALUE_FLAG_NONE [
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_VALUE_FLAGS
					(record-base + schema/WIRE_RSIR_VALUE_FLAGS_OFFSET) view/values-ordinal
			]
			value-id: value-id + 1
		]

		instruction-id: 1
		while [instruction-id <= view/instruction-count][
			record-base: record-offset view/instructions-offset (instruction-id - 1)
				schema/WIRE_RSIR_INSTRUCTION_SIZE
			block-id: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			if any [block-id <= 0 block-id > constants-result/functions/block-count][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_BLOCK
					(record-base + schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
					view/instructions-ordinal
			]
			opcode: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			unless all [
				opcode >= schema/WIRE_OPCODE_CONSTANT
				opcode <= schema/WIRE_OPCODE_SET_UNION_VARIANT
			][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPCODE
					(record-base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					view/instructions-ordinal
			]
			first-result: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
			result-count: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
			either result-count = 0 [
				if first-result <> 0 [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
						(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
						view/instructions-ordinal
				]
			][
				finish: container/checked-add first-result (result-count - 1)
				if any [first-result <= 0 none? finish finish > view/value-count][
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
						(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
						view/instructions-ordinal
				]
			]
			first-operand: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			either operand-count = 0 [
				if first-operand <> 0 [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						view/instructions-ordinal
				]
			][
				finish: container/checked-add first-operand (operand-count - 1)
				if any [first-operand <= 0 none? finish finish > view/operand-count][
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						view/instructions-ordinal
				]
			]
			source-location: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET
			if source-location > constants-result/functions/source-location-count [
				return reject result
					schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET)
					view/instructions-ordinal
			]
			instruction-id: instruction-id + 1
		]

		; Instruction-defined value ordinals are meaningful after result ranges decode.
		value-id: 1
		while [value-id <= view/value-count][
			if (value-value data view value-id schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
				= schema/WIRE_VALUE_DEFINITION_INSTRUCTION
			[
				definition-id: value-value data view value-id
					schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
				result-ordinal: value-value data view value-id
					schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
				if result-ordinal >= (instruction-value data view definition-id
					schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				[
					record-base: record-offset view/values-offset (value-id - 1)
						schema/WIRE_RSIR_VALUE_SIZE
					return reject result
						schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_RESULT_ORDINAL
						(record-base + schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET)
						view/values-ordinal
				]
			]
			value-id: value-id + 1
		]

		; Blocks partition instructions and every instruction points back to its owner.
		cursor: 1
		block-id: 1
		while [block-id <= constants-result/functions/block-count][
			record-base: record-offset constants-result/functions/blocks-offset (block-id - 1)
				schema/WIRE_RSIR_BLOCK_SIZE
			first-operand: block-value data constants-result/functions block-id
				schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value data constants-result/functions block-id
				schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			either count = 0 [
				if first-operand <> 0 [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BLOCK_INSTRUCTION_RANGE
						(record-base + schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET)
						constants-result/functions/blocks-ordinal
				]
			][
				finish: container/checked-add first-operand (count - 1)
				if any [first-operand <> cursor none? finish finish > view/instruction-count][
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BLOCK_INSTRUCTION_RANGE
						(record-base + schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET)
						constants-result/functions/blocks-ordinal
				]
				instruction-id: first-operand
				while [instruction-id <= finish][
					if (instruction-value data view instruction-id
						schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET) <> block-id
					[
						record-base: record-offset view/instructions-offset (instruction-id - 1)
							schema/WIRE_RSIR_INSTRUCTION_SIZE
						return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_BLOCK
							(record-base + schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
							view/instructions-ordinal
					]
					instruction-id: instruction-id + 1
				]
				cursor: finish + 1
			]
			block-id: block-id + 1
		]
		if cursor <> (view/instruction-count + 1) [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_COVERAGE
				(view/instructions-offset + ((cursor - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE))
				view/instructions-ordinal
		]

		operand-id: 1
		while [operand-id <= view/operand-count][
			record-base: record-offset view/operands-offset (operand-id - 1)
				schema/WIRE_RSIR_OPERAND_SIZE
			kind: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			unless all [kind >= schema/WIRE_OPERAND_KIND_VALUE kind <= schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_KIND
					(record-base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			reference: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			reference-count: case [
				kind = schema/WIRE_OPERAND_KIND_VALUE [view/value-count]
				kind = schema/WIRE_OPERAND_KIND_CONSTANT [constants-result/view/constant-count]
				kind = schema/WIRE_OPERAND_KIND_SYMBOL [constants-result/symbols/symbol-count]
				kind = schema/WIRE_OPERAND_KIND_BLOCK [constants-result/functions/block-count]
				kind = schema/WIRE_OPERAND_KIND_LOCAL [constants-result/functions/local-count]
				kind = schema/WIRE_OPERAND_KIND_TYPE [constants-result/types/type-count]
				kind = schema/WIRE_OPERAND_KIND_FUNCTION [constants-result/functions/function-count]
				true [view/target-fragment-count]
			]
			if any [reference <= 0 reference > reference-count][
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_REFERENCE
					(record-base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					view/operands-ordinal
			]
			flags: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_FLAGS_OFFSET
			if flags <> schema/WIRE_OPERAND_FLAG_NONE [
				return reject result schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_OPERAND_FLAGS
					(record-base + schema/WIRE_RSIR_OPERAND_FLAGS_OFFSET)
					view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		; Instruction ranges partition operands and provide function ownership.
		cursor: 1
		instruction-id: 1
		while [instruction-id <= view/instruction-count][
			record-base: record-offset view/instructions-offset (instruction-id - 1)
				schema/WIRE_RSIR_INSTRUCTION_SIZE
			first-operand: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value data view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			if operand-count > 0 [
				if first-operand <> cursor [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						view/instructions-ordinal
				]
				block-id: instruction-value data view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
				owner-function: block-value data constants-result/functions block-id
					schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				operand-id: first-operand
				while [operand-id < (first-operand + operand-count)][
					kind: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
					reference: operand-value data view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					function-id: case [
						kind = schema/WIRE_OPERAND_KIND_VALUE [
							value-value data view reference schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET
						]
						kind = schema/WIRE_OPERAND_KIND_BLOCK [
							block-value data constants-result/functions reference
								schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
						]
						kind = schema/WIRE_OPERAND_KIND_LOCAL [
							local-value data constants-result/functions reference
								schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET
						]
						true [owner-function]
					]
					if function-id <> owner-function [
						record-base: record-offset view/operands-offset (operand-id - 1)
							schema/WIRE_RSIR_OPERAND_SIZE
						return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_FUNCTION
							(record-base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					operand-id: operand-id + 1
				]
				cursor: first-operand + operand-count
			]
			instruction-id: instruction-id + 1
		]
		if cursor <> (view/operand-count + 1) [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_COVERAGE
				(view/operands-offset + ((cursor - 1) * schema/WIRE_RSIR_OPERAND_SIZE))
				view/operands-ordinal
		]

		; Functions own parameter values first, then instruction results.
		cursor: 1
		function-id: 1
		while [function-id <= constants-result/functions/function-count][
			signature-id: function-value data constants-result/functions function-id
				schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			parameter-count: signature-value data constants-result/functions signature-id
				schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			first-local: function-value data constants-result/functions function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			argument-index: 0
			while [argument-index < parameter-count][
				if cursor > view/value-count [
					return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(view/values-offset + (view/value-count * schema/WIRE_RSIR_VALUE_SIZE))
						view/values-ordinal
				]
				value-id: cursor
				local-id: first-local + argument-index
				record-base: record-offset view/values-offset (value-id - 1)
					schema/WIRE_RSIR_VALUE_SIZE
				foreach [field expected] reduce [
					schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
						schema/WIRE_VALUE_DEFINITION_PARAMETER
					schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET local-id
					schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET 0
					schema/WIRE_RSIR_VALUE_TYPE_OFFSET
						local-value data constants-result/functions local-id
							schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
					schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET function-id
				][
					if (value-value data view value-id field) <> expected [
						return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
							(record-base + field) view/values-ordinal
					]
				]
				cursor: cursor + 1
				argument-index: argument-index + 1
			]

			block-first: function-value data constants-result/functions function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			function-block-count: function-value data constants-result/functions function-id
				schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-end: block-first + function-block-count
			block-id: block-first
			while [block-id < block-end][
				instruction-id: block-value data constants-result/functions block-id
					schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
				count: block-value data constants-result/functions block-id
					schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
				if count = 0 [instruction-id: 1]
				while [count > 0][
					first-result: instruction-value data view instruction-id
						schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
					result-count: instruction-value data view instruction-id
						schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
					if all [result-count > 0 first-result <> cursor][
						record-base: record-offset view/instructions-offset (instruction-id - 1)
							schema/WIRE_RSIR_INSTRUCTION_SIZE
						return reject result
							schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
							(record-base + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
							view/instructions-ordinal
					]
					result-id: 0
					while [result-id < result-count][
						value-id: cursor + result-id
						record-base: record-offset view/values-offset (value-id - 1)
							schema/WIRE_RSIR_VALUE_SIZE
						foreach [field expected] reduce [
							schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
								schema/WIRE_VALUE_DEFINITION_INSTRUCTION
							schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET instruction-id
							schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET result-id
							schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET function-id
						][
							if (value-value data view value-id field) <> expected [
								return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
									(record-base + field) view/values-ordinal
							]
						]
						result-id: result-id + 1
					]
					cursor: cursor + result-count
					instruction-id: instruction-id + 1
					count: count - 1
				]
				block-id: block-id + 1
			]
			function-id: function-id + 1
		]
		if cursor <> (view/value-count + 1) [
			return reject result schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_COVERAGE
				(view/values-offset + ((cursor - 1) * schema/WIRE_RSIR_VALUE_SIZE))
				view/values-ordinal
		]

		instruction-id: 1
		while [instruction-id <= view/instruction-count][
			failure: verify-scalar-instruction data result constants-result view instruction-id
			if failure [return failure]
			instruction-id: instruction-id + 1
		]

		result/strings: constants-result/strings
		result/files: constants-result/files
		result/layout: constants-result/layout
		result/types: constants-result/types
		result/functions: constants-result/functions
		result/modules: constants-result/modules
		result/symbols: constants-result/symbols
		result/constants: constants-result/view
		result/view: view
		result/valid?: true
		result
	]
]
