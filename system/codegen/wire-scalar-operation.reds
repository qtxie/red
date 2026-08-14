Red/System [
	Title: "Hybrid compiler RSIR scalar value and operation verifier"
	File:  %wire-scalar-operation.reds
]

#include %wire-constant-initializer.reds

wire-scalar-operation-result!: alias struct! [
	error                      [integer!]
	container-error            [integer!]
	string-error               [integer!]
	file-source-error          [integer!]
	data-layout-error          [integer!]
	type-layout-error          [integer!]
	function-signature-error   [integer!]
	module-lifecycle-error     [integer!]
	symbol-linkage-error       [integer!]
	constant-initializer-error [integer!]
	error-offset               [integer!]
	error-section              [integer!]
]

wire-scalar-operation!: alias struct! [
	values                  [byte-ptr!]
	value-count             [integer!]
	value-record-size       [integer!]
	values-offset           [integer!]
	values-ordinal          [integer!]
	instructions            [byte-ptr!]
	instruction-count       [integer!]
	instruction-record-size [integer!]
	instructions-offset     [integer!]
	instructions-ordinal    [integer!]
	operands                [byte-ptr!]
	operand-count           [integer!]
	operand-record-size     [integer!]
	operands-offset         [integer!]
	operands-ordinal        [integer!]
	target-fragment-count   [integer!]
	subroutine-count        [integer!]
]

wire-scalar-operation-reader: context [
	set-error: func [
		result [wire-scalar-operation-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	map-constant-error: func [code [integer!] return: [integer!]][
		case [
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_STRINGS [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_STRINGS
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FILE_SOURCE [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_FILE_SOURCE
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_DATA_LAYOUT [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_DATA_LAYOUT
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_TYPE_LAYOUT [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_TYPE_LAYOUT
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FUNCTION_SIGNATURE [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_FUNCTION_SIGNATURE
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_MODULE_LIFECYCLE [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_MODULE_LIFECYCLE
			]
			code = WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_SYMBOL_LINKAGE [
				WIRE_SCALAR_OPERATION_ERROR_INVALID_SYMBOL_LINKAGE
			]
			true [WIRE_SCALAR_OPERATION_ERROR_INVALID_CONSTANT_INITIALIZER]
		]
	]

	section-flags-offset: func [
		section [wire-section-slice!]
		return: [integer!]
	][
		WIRE_HEADER_SIZE
			+ (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
				+ WIRE_DIRECTORY_FLAGS_OFFSET)
	]

	first-bad-scalar: func [
		record [byte-ptr!]
		word-count [integer!]
		return: [integer!]
		/local index relative [integer!]
	][
		index: 0
		while [index < word-count][
			relative: index * 4
			if (wire-container-reader/read-i31 record relative) < 0 [return relative]
			index: index + 1
		]
		-1
	]

	record-offset: func [
		section [wire-section-slice!]
		id record-size [integer!]
		return: [integer!]
	][
		section/offset + ((id - 1) * record-size)
	]

	record-value: func [
		section [wire-section-slice!]
		id record-size field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 section/data
			(((id - 1) * record-size) + field-offset)
	]

	value-value: func [
		view [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/values
			(((id - 1) * WIRE_RSIR_VALUE_SIZE) + field-offset)
	]

	instruction-value: func [
		view [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/instructions
			(((id - 1) * WIRE_RSIR_INSTRUCTION_SIZE) + field-offset)
	]

	operand-value: func [
		view [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/operands
			(((id - 1) * WIRE_RSIR_OPERAND_SIZE) + field-offset)
	]

	type-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/types
			(((id - 1) * WIRE_RSIR_TYPE_SIZE) + field-offset)
	]

	function-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/functions
			(((id - 1) * WIRE_RSIR_FUNCTION_SIZE) + field-offset)
	]

	signature-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/signatures
			(((id - 1) * WIRE_RSIR_SIGNATURE_SIZE) + field-offset)
	]

	local-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/locals
			(((id - 1) * WIRE_RSIR_LOCAL_SIZE) + field-offset)
	]

	block-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/blocks
			(((id - 1) * WIRE_RSIR_BLOCK_SIZE) + field-offset)
	]

	constant-value: func [
		constants [wire-constant-initializer!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 constants/constants
			(((id - 1) * WIRE_RSIR_CONSTANT_SIZE) + field-offset)
	]

	valid-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [id > 0 id <= types/type-count]
	]

	type-kind: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
	]

	type-size: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_SIZE_OFFSET
	]

	type-flags: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET
	]

	type-gc-kind: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_GC_KIND_OFFSET
	]

	integer-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		(type-kind types id) = WIRE_TYPE_KIND_INTEGER
	]

	float-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		(type-kind types id) = WIRE_TYPE_KIND_FLOAT
	]

	logic-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		(type-kind types id) = WIRE_TYPE_KIND_LOGIC
	]

	address-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		any [
			(type-kind types id) = WIRE_TYPE_KIND_POINTER
			(type-kind types id) = WIRE_TYPE_KIND_FUNCTION
		]
	]

	pointer-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		(type-kind types id) = WIRE_TYPE_KIND_POINTER
	]

	scalar-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		any [
			(type-kind types id) = WIRE_TYPE_KIND_LOGIC
			(type-kind types id) = WIRE_TYPE_KIND_INTEGER
			(type-kind types id) = WIRE_TYPE_KIND_FLOAT
			(type-kind types id) = WIRE_TYPE_KIND_POINTER
			(type-kind types id) = WIRE_TYPE_KIND_FUNCTION
		]
	]

	ordinary-integer?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [
			integer-type? types id
			(type-gc-kind types id) = WIRE_GC_KIND_NONE
		]
	]

	handle-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [
			integer-type? types id
			(type-gc-kind types id) = WIRE_GC_KIND_HANDLE
		]
	]

	plain-signed-i32?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [
			ordinary-integer? types id
			(type-size types id) = 4
			(type-flags types id) = WIRE_TYPE_FLAG_SIGNED
		]
	]

	f32-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [float-type? types id (type-size types id) = 4]
	]

	same-integer-representation?: func [
		types [wire-type-layout!]
		left right [integer!]
		return: [logic!]
	][
		all [
			integer-type? types left
			integer-type? types right
			(type-size types left) = (type-size types right)
			(type-flags types left) = (type-flags types right)
		]
	]

	compatible-integers?: func [
		types [wire-type-layout!]
		left right [integer!]
		return: [logic!]
	][
		all [
			same-integer-representation? types left right
			any [left = right handle-type? types left handle-type? types right]
		]
	]

	plain-integer-result?: func [
		types [wire-type-layout!]
		source target [integer!]
		return: [logic!]
	][
		all [
			same-integer-representation? types source target
			ordinary-integer? types target
			any [source = target handle-type? types source]
		]
	]

	valid-convert?: func [
		types [wire-type-layout!]
		source target [integer!]
		return: [logic!]
		/local source-size target-size [integer!]
	][
		if any [
			source = target
			handle-type? types source
			handle-type? types target
		][return false]
		source-size: type-size types source
		target-size: type-size types target
		case [
			all [ordinary-integer? types source ordinary-integer? types target][
				return source-size <> target-size
			]
			all [logic-type? types source ordinary-integer? types target][return true]
			all [
				any [ordinary-integer? types source address-type? types source]
				logic-type? types target
			][return true]
			all [plain-signed-i32? types source float-type? types target][return true]
			all [float-type? types source plain-signed-i32? types target][return true]
			all [float-type? types source float-type? types target][
				return source-size <> target-size
			]
			all [ordinary-integer? types source address-type? types target][
				return source-size <> target-size
			]
			all [address-type? types source ordinary-integer? types target][
				return source-size <> target-size
			]
			true [false]
		]
	]

	valid-bitcast?: func [
		types [wire-type-layout!]
		source target [integer!]
		return: [logic!]
		/local source-size target-size [integer!]
	][
		if any [
			source = target
			handle-type? types source
			handle-type? types target
		][return false]
		source-size: type-size types source
		target-size: type-size types target
		if source-size <> target-size [return false]
		case [
			all [ordinary-integer? types source ordinary-integer? types target][
				return (type-flags types source) <> (type-flags types target)
			]
			all [address-type? types source address-type? types target][return true]
			all [ordinary-integer? types source address-type? types target][return true]
			all [address-type? types source ordinary-integer? types target][return true]
			all [plain-signed-i32? types source f32-type? types target][return true]
			all [f32-type? types source plain-signed-i32? types target][return true]
			true [false]
		]
	]

	checked-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_ADD
			opcode = WIRE_OPCODE_SUBTRACT
			opcode = WIRE_OPCODE_MULTIPLY
			opcode = WIRE_OPCODE_DIVIDE
			opcode = WIRE_OPCODE_REMAINDER
			opcode = WIRE_OPCODE_MODULO
			opcode = WIRE_OPCODE_SHIFT_LEFT
		]
	]

	unary-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_CONSTANT
			opcode = WIRE_OPCODE_COPY
			opcode = WIRE_OPCODE_CONVERT
			opcode = WIRE_OPCODE_BITCAST
			opcode = WIRE_OPCODE_NEGATE
			opcode = WIRE_OPCODE_BIT_NOT
			opcode = WIRE_OPCODE_LOGIC_NOT
		]
	]

	verify-scalar-instruction: func [
		result [wire-scalar-operation-result!]
		types [wire-type-layout!]
		constants [wire-constant-initializer!]
		view [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local base opcode subopcode flags expected-operands expected-results
			first-result result-count first-operand operand-count alias-kind alias-id
			alias-offset expected-operand-kind
			operand-id operand-base operand-kind operand-reference auxiliary
			left-type right-type result-type second-result-type kind right-kind
			expected-effects [integer!]
			checked? valid? [logic!]
	][
		base: view/instructions-offset
			+ ((instruction-id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
		opcode: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode > WIRE_OPCODE_COMPARE [return WIRE_SCALAR_OPERATION_ERROR_SUCCESS]

		subopcode: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		either opcode = WIRE_OPCODE_COMPARE [
			unless all [
				subopcode >= WIRE_COMPARE_KIND_EQUAL
				subopcode <= WIRE_COMPARE_KIND_GREATER_EQUAL
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_KIND
					(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		][
			if subopcode <> 0 [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_SUBOPCODE
					(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]

		flags: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		unless any [flags = 0 flags = WIRE_INSTRUCTION_FLAG_CHECKED][
			return set-error result
				WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_INSTRUCTION_FLAGS
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		checked?: flags = WIRE_INSTRUCTION_FLAG_CHECKED

		alias-kind: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if any [alias-kind <> WIRE_ALIAS_KIND_NONE alias-id <> 0][
			alias-offset: either alias-kind <> WIRE_ALIAS_KIND_NONE [
				WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
			][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_ALIAS
				(base + alias-offset)
				view/instructions-ordinal
		]

		expected-operands: either unary-opcode? opcode [1][2]
		operand-count: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if operand-count <> expected-operands [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]
		first-operand: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET

		expected-results: either checked? [2][1]
		result-count: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		if result-count <> expected-results [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]
		first-result: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
		expected-operand-kind: either opcode = WIRE_OPCODE_CONSTANT [
			WIRE_OPERAND_KIND_CONSTANT
		][WIRE_OPERAND_KIND_VALUE]

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			operand-base: view/operands-offset
				+ ((operand-id - 1) * WIRE_RSIR_OPERAND_SIZE)
			operand-kind: operand-value view operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
			if operand-kind <> expected-operand-kind [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_KIND
					(operand-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			auxiliary: operand-value view operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return set-error result
					WIRE_SCALAR_OPERATION_ERROR_NONZERO_SCALAR_OPERAND_AUXILIARY
					(operand-base + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		operand-reference: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		left-type: either opcode = WIRE_OPCODE_CONSTANT [
			constant-value constants operand-reference WIRE_RSIR_CONSTANT_TYPE_OFFSET
		][value-value view operand-reference WIRE_RSIR_VALUE_TYPE_OFFSET]
		right-type: 0
		if operand-count = 2 [
			operand-reference: operand-value view (first-operand + 1)
				WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			right-type: value-value view operand-reference WIRE_RSIR_VALUE_TYPE_OFFSET
		]
		result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET

		unless scalar-type? types result-type [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_TYPE
				((view/values-offset + ((first-result - 1) * WIRE_RSIR_VALUE_SIZE))
					+ WIRE_RSIR_VALUE_TYPE_OFFSET)
				view/values-ordinal
		]

		valid?: false
		case [
			opcode = WIRE_OPCODE_CONSTANT [
				valid?: all [scalar-type? types left-type left-type = result-type]
			]
			opcode = WIRE_OPCODE_COPY [
				valid?: all [scalar-type? types left-type left-type = result-type]
			]
			opcode = WIRE_OPCODE_CONVERT [
				valid?: valid-convert? types left-type result-type
				unless valid? [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION
						((view/values-offset + ((first-result - 1) * WIRE_RSIR_VALUE_SIZE))
							+ WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			opcode = WIRE_OPCODE_BITCAST [
				valid?: valid-bitcast? types left-type result-type
				unless valid? [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST
						((view/values-offset + ((first-result - 1) * WIRE_RSIR_VALUE_SIZE))
							+ WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			any [opcode = WIRE_OPCODE_ADD opcode = WIRE_OPCODE_SUBTRACT][
				kind: type-kind types left-type
				case [
					kind = WIRE_TYPE_KIND_POINTER [
						valid?: all [
							left-type = result-type
							any [
								ordinary-integer? types right-type
								pointer-type? types right-type
							]
						]
					]
					kind = WIRE_TYPE_KIND_INTEGER [
						valid?: all [
							compatible-integers? types left-type right-type
							plain-integer-result? types left-type result-type
						]
					]
					kind = WIRE_TYPE_KIND_FLOAT [
						valid?: all [left-type = right-type left-type = result-type]
					]
					true [valid?: false]
				]
			]
			any [opcode = WIRE_OPCODE_MULTIPLY opcode = WIRE_OPCODE_DIVIDE][
				kind: type-kind types left-type
				case [
					kind = WIRE_TYPE_KIND_INTEGER [
						valid?: all [
							compatible-integers? types left-type right-type
							plain-integer-result? types left-type result-type
						]
					]
					kind = WIRE_TYPE_KIND_FLOAT [
						valid?: all [left-type = right-type left-type = result-type]
					]
					true [valid?: false]
				]
			]
			any [opcode = WIRE_OPCODE_REMAINDER opcode = WIRE_OPCODE_MODULO][
				valid?: all [
					compatible-integers? types left-type right-type
					plain-integer-result? types left-type result-type
				]
			]
			opcode = WIRE_OPCODE_NEGATE [
				kind: type-kind types left-type
				case [
					kind = WIRE_TYPE_KIND_INTEGER [
						valid?: plain-integer-result? types left-type result-type
					]
					kind = WIRE_TYPE_KIND_FLOAT [valid?: left-type = result-type]
					true [valid?: false]
				]
			]
			opcode = WIRE_OPCODE_BIT_NOT [
				valid?: plain-integer-result? types left-type result-type
			]
			opcode = WIRE_OPCODE_LOGIC_NOT [
				valid?: all [logic-type? types left-type left-type = result-type]
			]
			any [
				opcode = WIRE_OPCODE_SHIFT_LEFT
				opcode = WIRE_OPCODE_SHIFT_RIGHT
				opcode = WIRE_OPCODE_SHIFT_RIGHT_LOGICAL
			][
				unless plain-signed-i32? types right-type [
					operand-base: view/operands-offset
						+ (first-operand * WIRE_RSIR_OPERAND_SIZE)
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SHIFT_COUNT_TYPE
						(operand-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				valid?: plain-integer-result? types left-type result-type
			]
			any [
				opcode = WIRE_OPCODE_BIT_AND
				opcode = WIRE_OPCODE_BIT_OR
				opcode = WIRE_OPCODE_BIT_XOR
			][
				kind: type-kind types left-type
				case [
					kind = WIRE_TYPE_KIND_INTEGER [
						valid?: all [
							compatible-integers? types left-type right-type
							plain-integer-result? types left-type result-type
						]
					]
					kind = WIRE_TYPE_KIND_LOGIC [
						valid?: all [left-type = right-type left-type = result-type]
					]
					true [valid?: false]
				]
			]
			opcode = WIRE_OPCODE_COMPARE [
				kind: type-kind types left-type
				right-kind: type-kind types right-type
				case [
					kind = WIRE_TYPE_KIND_INTEGER [
						valid?: compatible-integers? types left-type right-type
					]
					kind = WIRE_TYPE_KIND_FLOAT [valid?: left-type = right-type]
					kind = WIRE_TYPE_KIND_LOGIC [valid?: left-type = right-type]
					kind = WIRE_TYPE_KIND_POINTER [
						valid?: right-kind = WIRE_TYPE_KIND_POINTER
					]
					kind = WIRE_TYPE_KIND_FUNCTION [
						valid?: right-kind = WIRE_TYPE_KIND_FUNCTION
					]
					true [valid?: false]
				]
				unless valid? [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_TYPE
						((view/operands-offset + (first-operand * WIRE_RSIR_OPERAND_SIZE))
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				valid?: logic-type? types result-type
			]
			true [valid?: false]
		]

		unless valid? [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH
				((view/values-offset + ((first-result - 1) * WIRE_RSIR_VALUE_SIZE))
					+ WIRE_RSIR_VALUE_TYPE_OFFSET)
				view/values-ordinal
		]

		if checked? [
			unless all [integer-type? types left-type checked-opcode? opcode][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_OPERATION
					(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
					view/instructions-ordinal
			]
			second-result-type: value-value view (first-result + 1)
				WIRE_RSIR_VALUE_TYPE_OFFSET
			unless logic-type? types second-result-type [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_RESULT
					((view/values-offset + (first-result * WIRE_RSIR_VALUE_SIZE))
						+ WIRE_RSIR_VALUE_TYPE_OFFSET)
					view/values-ordinal
			]
		]

		expected-effects: 0
		kind: type-kind types left-type
		if all [
			kind = WIRE_TYPE_KIND_INTEGER
			any [
				opcode = WIRE_OPCODE_DIVIDE
				opcode = WIRE_OPCODE_REMAINDER
				opcode = WIRE_OPCODE_MODULO
			]
		][expected-effects: WIRE_EFFECT_FLAG_MAY_TRAP]
		if all [
			kind = WIRE_TYPE_KIND_FLOAT
			any [
				opcode = WIRE_OPCODE_ADD
				opcode = WIRE_OPCODE_SUBTRACT
				opcode = WIRE_OPCODE_MULTIPLY
				opcode = WIRE_OPCODE_DIVIDE
				opcode = WIRE_OPCODE_COMPARE
			]
		][expected-effects: WIRE_EFFECT_FLAG_MAY_TRAP]
		if all [
			opcode = WIRE_OPCODE_CONVERT
			any [float-type? types left-type float-type? types result-type]
		][expected-effects: WIRE_EFFECT_FLAG_MAY_TRAP]
		if (instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
			<> expected-effects
		[
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS
				(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		WIRE_SCALAR_OPERATION_ERROR_SUCCESS
	]

	copy-symbols: func [destination source [wire-symbol-linkage!]][
		destination/symbols: source/symbols
		destination/symbol-count: source/symbol-count
		destination/symbol-record-size: source/symbol-record-size
		destination/symbols-offset: source/symbols-offset
		destination/symbols-ordinal: source/symbols-ordinal
		destination/globals: source/globals
		destination/global-count: source/global-count
		destination/global-record-size: source/global-record-size
		destination/globals-offset: source/globals-offset
		destination/globals-ordinal: source/globals-ordinal
		destination/imports: source/imports
		destination/import-count: source/import-count
		destination/import-record-size: source/import-record-size
		destination/imports-offset: source/imports-offset
		destination/imports-ordinal: source/imports-ordinal
		destination/exports: source/exports
		destination/export-count: source/export-count
		destination/export-record-size: source/export-record-size
		destination/exports-offset: source/exports-offset
		destination/exports-ordinal: source/exports-ordinal
		destination/function-count: source/function-count
		destination/module-kind: source/module-kind
		destination/image-kind: source/image-kind
	]

	copy-constants: func [
		destination source [wire-constant-initializer!]
	][
		destination/constants: source/constants
		destination/constant-count: source/constant-count
		destination/constant-record-size: source/constant-record-size
		destination/constants-offset: source/constants-offset
		destination/constants-ordinal: source/constants-ordinal
		destination/constant-data: source/constant-data
		destination/constant-data-size: source/constant-data-size
		destination/constant-data-owned-size: source/constant-data-owned-size
		destination/constant-data-offset: source/constant-data-offset
		destination/constant-data-ordinal: source/constant-data-ordinal
		destination/parts: source/parts
		destination/part-count: source/part-count
		destination/part-record-size: source/part-record-size
		destination/parts-offset: source/parts-offset
		destination/parts-ordinal: source/parts-ordinal
		destination/bindings: source/bindings
		destination/binding-count: source/binding-count
		destination/binding-record-size: source/binding-record-size
		destination/bindings-offset: source/bindings-offset
		destination/bindings-ordinal: source/bindings-ordinal
		destination/global-count: source/global-count
	]

	copy-view: func [destination source [wire-scalar-operation!]][
		destination/values: source/values
		destination/value-count: source/value-count
		destination/value-record-size: source/value-record-size
		destination/values-offset: source/values-offset
		destination/values-ordinal: source/values-ordinal
		destination/instructions: source/instructions
		destination/instruction-count: source/instruction-count
		destination/instruction-record-size: source/instruction-record-size
		destination/instructions-offset: source/instructions-offset
		destination/instructions-ordinal: source/instructions-ordinal
		destination/operands: source/operands
		destination/operand-count: source/operand-count
		destination/operand-record-size: source/operand-record-size
		destination/operands-offset: source/operands-offset
		destination/operands-ordinal: source/operands-ordinal
		destination/target-fragment-count: source/target-fragment-count
		destination/subroutine-count: source/subroutine-count
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-scalar-operation-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		view [wire-scalar-operation!]
		return: [integer!]
		/local constant-result [wire-constant-initializer-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			verified-modules [wire-module-lifecycle!]
			verified-symbols [wire-symbol-linkage!]
			verified-constants [wire-constant-initializer!]
			verified-view [wire-scalar-operation!]
			values instructions operands target-fragments subroutines [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative record-index record-base value-id definition-kind
			definition-id result-ordinal value-type function-id flags instruction-id
			block-id opcode first-result result-count first-operand operand-count finish
			source-location cursor count operand-id kind reference reference-count
			owner-function signature-id parameter-count first-local argument-index
			local-id block-first function-block-count block-end result-id field
			expected [integer!]
	][
		if null? result [return WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_SCALAR_OPERATION_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/type-layout-error: WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		result/function-signature-error: WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/symbol-linkage-error: WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		result/constant-initializer-error: WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [
			size < 0
			null? data
			null? strings
			null? files
			null? layout
			null? types
			null? functions
			null? modules
			null? symbols
			null? constants
			null? view
		][
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS 0 0
		]

		constant-result: declare wire-constant-initializer-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		verified-modules: declare wire-module-lifecycle!
		verified-symbols: declare wire-symbol-linkage!
		verified-constants: declare wire-constant-initializer!
		status: wire-constant-initializer-reader/verify data size constant-result
			verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
		result/container-error: constant-result/container-error
		result/string-error: constant-result/string-error
		result/file-source-error: constant-result/file-source-error
		result/data-layout-error: constant-result/data-layout-error
		result/type-layout-error: constant-result/type-layout-error
		result/function-signature-error: constant-result/function-signature-error
		result/module-lifecycle-error: constant-result/module-lifecycle-error
		result/symbol-linkage-error: constant-result/symbol-linkage-error
		result/constant-initializer-error: status
		if status <> WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS [
			return set-error result (map-constant-error status)
				constant-result/error-offset constant-result/error-section
		]

		values: declare wire-section-slice!
		instructions: declare wire-section-slice!
		operands: declare wire-section-slice!
		target-fragments: declare wire-section-slice!
		subroutines: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_VALUES values
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_INSTRUCTIONS instructions
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_OPERANDS operands
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_TARGET_FRAGMENTS target-fragments
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_SUBROUTINES subroutines
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SCALAR_OPERATION_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if values/flags <> 0 [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_SECTION_FLAGS
				section-flags-offset values values/ordinal
		]
		if instructions/flags <> 0 [
			return set-error result
				WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SECTION_FLAGS
				section-flags-offset instructions instructions/ordinal
		]
		if operands/flags <> 0 [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_SECTION_FLAGS
				section-flags-offset operands operands/ordinal
		]

		verified-view: declare wire-scalar-operation!
		verified-view/values: values/data
		verified-view/value-count: values/record-count
		verified-view/value-record-size: values/record-size
		verified-view/values-offset: values/offset
		verified-view/values-ordinal: values/ordinal
		verified-view/instructions: instructions/data
		verified-view/instruction-count: instructions/record-count
		verified-view/instruction-record-size: instructions/record-size
		verified-view/instructions-offset: instructions/offset
		verified-view/instructions-ordinal: instructions/ordinal
		verified-view/operands: operands/data
		verified-view/operand-count: operands/record-count
		verified-view/operand-record-size: operands/record-size
		verified-view/operands-offset: operands/offset
		verified-view/operands-ordinal: operands/ordinal
		verified-view/target-fragment-count: target-fragments/record-count
		verified-view/subroutine-count: subroutines/record-count

		; Decode every signed scalar before following any reference.
		record-index: 0
		while [record-index < values/record-count][
			record: values/data + (record-index * WIRE_RSIR_VALUE_SIZE)
			bad-relative: first-bad-scalar record 6
			if bad-relative >= 0 [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_SCALAR_RANGE
					((values/offset + (record-index * WIRE_RSIR_VALUE_SIZE)) + bad-relative)
					values/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < instructions/record-count][
			record: instructions/data + (record-index * WIRE_RSIR_INSTRUCTION_SIZE)
			bad-relative: first-bad-scalar record 12
			if bad-relative >= 0 [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_SCALAR_RANGE
					((instructions/offset
						+ (record-index * WIRE_RSIR_INSTRUCTION_SIZE)) + bad-relative)
					instructions/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < operands/record-count][
			record: operands/data + (record-index * WIRE_RSIR_OPERAND_SIZE)
			bad-relative: first-bad-scalar record 4
			if bad-relative >= 0 [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_SCALAR_RANGE
					((operands/offset + (record-index * WIRE_RSIR_OPERAND_SIZE))
						+ bad-relative)
					operands/ordinal
			]
			record-index: record-index + 1
		]

		value-id: 1
		while [value-id <= verified-view/value-count][
			record-base: verified-view/values-offset
				+ ((value-id - 1) * WIRE_RSIR_VALUE_SIZE)
			definition-kind: value-value verified-view value-id
				WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
			unless any [
				definition-kind = WIRE_VALUE_DEFINITION_PARAMETER
				definition-kind = WIRE_VALUE_DEFINITION_INSTRUCTION
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_KIND
					(record-base + WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
					verified-view/values-ordinal
			]
			definition-id: value-value verified-view value-id
				WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
			reference-count: either definition-kind = WIRE_VALUE_DEFINITION_PARAMETER [
				verified-functions/local-count
			][verified-view/instruction-count]
			if any [definition-id <= 0 definition-id > reference-count][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_ID
					(record-base + WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET)
					verified-view/values-ordinal
			]
			result-ordinal: value-value verified-view value-id
				WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
			if all [
				definition-kind = WIRE_VALUE_DEFINITION_PARAMETER
				result-ordinal <> 0
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_RESULT_ORDINAL
					(record-base + WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET)
					verified-view/values-ordinal
			]
			value-type: value-value verified-view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
			if any [
				not valid-type? verified-types value-type
				all [
					valid-type? verified-types value-type
					(type-kind verified-types value-type) = WIRE_TYPE_KIND_VOID
				]
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_TYPE
					(record-base + WIRE_RSIR_VALUE_TYPE_OFFSET)
					verified-view/values-ordinal
			]
			function-id: value-value verified-view value-id WIRE_RSIR_VALUE_FUNCTION_OFFSET
			if any [
				function-id <= 0
				function-id > verified-functions/function-count
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_FUNCTION
					(record-base + WIRE_RSIR_VALUE_FUNCTION_OFFSET)
					verified-view/values-ordinal
			]
			flags: value-value verified-view value-id WIRE_RSIR_VALUE_FLAGS_OFFSET
			if flags <> WIRE_VALUE_FLAG_NONE [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_NONZERO_VALUE_FLAGS
					(record-base + WIRE_RSIR_VALUE_FLAGS_OFFSET)
					verified-view/values-ordinal
			]
			value-id: value-id + 1
		]

		instruction-id: 1
		while [instruction-id <= verified-view/instruction-count][
			record-base: verified-view/instructions-offset
				+ ((instruction-id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
			block-id: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			if any [block-id <= 0 block-id > verified-functions/block-count][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_BLOCK
					(record-base + WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
					verified-view/instructions-ordinal
			]
			opcode: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			unless all [
				opcode >= WIRE_OPCODE_CONSTANT
				opcode <= WIRE_OPCODE_CPU_REGISTER_WRITE
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_OPCODE
					(record-base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					verified-view/instructions-ordinal
			]
			first-result: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
			result-count: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
			either result-count = 0 [
				if first-result <> 0 [
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
						(record-base + WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
						verified-view/instructions-ordinal
				]
			][
				finish: wire-container-reader/checked-add first-result (result-count - 1)
				if any [
					first-result <= 0
					finish < 0
					finish > verified-view/value-count
				][
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
						(record-base + WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
						verified-view/instructions-ordinal
				]
			]
			first-operand: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			either operand-count = 0 [
				if first-operand <> 0 [
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						verified-view/instructions-ordinal
				]
			][
				finish: wire-container-reader/checked-add first-operand (operand-count - 1)
				if any [
					first-operand <= 0
					finish < 0
					finish > verified-view/operand-count
				][
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						verified-view/instructions-ordinal
				]
			]
			source-location: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET
			if source-location > verified-functions/source-location-count [
				return set-error result
					WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SOURCE_LOCATION
					(record-base + WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET)
					verified-view/instructions-ordinal
			]
			instruction-id: instruction-id + 1
		]

		value-id: 1
		while [value-id <= verified-view/value-count][
			if (value-value verified-view value-id WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
				= WIRE_VALUE_DEFINITION_INSTRUCTION
			[
				definition-id: value-value verified-view value-id
					WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
				result-ordinal: value-value verified-view value-id
					WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
				if result-ordinal >= (instruction-value verified-view definition-id
					WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				[
					record-base: verified-view/values-offset
						+ ((value-id - 1) * WIRE_RSIR_VALUE_SIZE)
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_RESULT_ORDINAL
						(record-base + WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET)
						verified-view/values-ordinal
				]
			]
			value-id: value-id + 1
		]

		; Blocks partition the instruction table and point back to their owner.
		cursor: 1
		block-id: 1
		while [block-id <= verified-functions/block-count][
			record-base: verified-functions/blocks-offset
				+ ((block-id - 1) * WIRE_RSIR_BLOCK_SIZE)
			first-operand: block-value verified-functions block-id
				WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value verified-functions block-id
				WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			either count = 0 [
				if first-operand <> 0 [
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_BLOCK_INSTRUCTION_RANGE
						(record-base + WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET)
						verified-functions/blocks-ordinal
				]
			][
				finish: wire-container-reader/checked-add first-operand (count - 1)
				if any [
					first-operand <> cursor
					finish < 0
					finish > verified-view/instruction-count
				][
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_BLOCK_INSTRUCTION_RANGE
						(record-base + WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET)
						verified-functions/blocks-ordinal
				]
				instruction-id: first-operand
				while [instruction-id <= finish][
					if (instruction-value verified-view instruction-id
						WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET) <> block-id
					[
						record-base: verified-view/instructions-offset
							+ ((instruction-id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
						return set-error result
							WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_BLOCK
							(record-base + WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
							verified-view/instructions-ordinal
					]
					instruction-id: instruction-id + 1
				]
				cursor: finish + 1
			]
			block-id: block-id + 1
		]
		if cursor <> (verified-view/instruction-count + 1) [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_COVERAGE
				(verified-view/instructions-offset
					+ ((cursor - 1) * WIRE_RSIR_INSTRUCTION_SIZE))
				verified-view/instructions-ordinal
		]

		operand-id: 1
		while [operand-id <= verified-view/operand-count][
			record-base: verified-view/operands-offset
				+ ((operand-id - 1) * WIRE_RSIR_OPERAND_SIZE)
			kind: operand-value verified-view operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
			unless all [
				kind >= WIRE_OPERAND_KIND_VALUE
				kind <= WIRE_OPERAND_KIND_SUBROUTINE
			][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_KIND
					(record-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
					verified-view/operands-ordinal
			]
			reference: operand-value verified-view operand-id
				WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			reference-count: case [
				kind = WIRE_OPERAND_KIND_VALUE [verified-view/value-count]
				kind = WIRE_OPERAND_KIND_CONSTANT [verified-constants/constant-count]
				kind = WIRE_OPERAND_KIND_SYMBOL [verified-symbols/symbol-count]
				kind = WIRE_OPERAND_KIND_BLOCK [verified-functions/block-count]
				kind = WIRE_OPERAND_KIND_LOCAL [verified-functions/local-count]
				kind = WIRE_OPERAND_KIND_TYPE [verified-types/type-count]
				kind = WIRE_OPERAND_KIND_FUNCTION [verified-functions/function-count]
				kind = WIRE_OPERAND_KIND_TARGET_FRAGMENT [
					verified-view/target-fragment-count
				]
				true [verified-view/subroutine-count]
			]
			if any [reference <= 0 reference > reference-count][
				return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_REFERENCE
					(record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					verified-view/operands-ordinal
			]
			flags: operand-value verified-view operand-id WIRE_RSIR_OPERAND_FLAGS_OFFSET
			if flags <> WIRE_OPERAND_FLAG_NONE [
				return set-error result WIRE_SCALAR_OPERATION_ERROR_NONZERO_OPERAND_FLAGS
					(record-base + WIRE_RSIR_OPERAND_FLAGS_OFFSET)
					verified-view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		; Instruction ranges partition operands and establish function ownership.
		cursor: 1
		instruction-id: 1
		while [instruction-id <= verified-view/instruction-count][
			record-base: verified-view/instructions-offset
				+ ((instruction-id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
			first-operand: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value verified-view instruction-id
				WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			if operand-count > 0 [
				if first-operand <> cursor [
					return set-error result
						WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
						(record-base + WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
						verified-view/instructions-ordinal
				]
				block-id: instruction-value verified-view instruction-id
					WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
				owner-function: block-value verified-functions block-id
					WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				operand-id: first-operand
				while [operand-id < (first-operand + operand-count)][
					kind: operand-value verified-view operand-id
						WIRE_RSIR_OPERAND_KIND_OFFSET
					reference: operand-value verified-view operand-id
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					function-id: case [
						kind = WIRE_OPERAND_KIND_VALUE [
							value-value verified-view reference WIRE_RSIR_VALUE_FUNCTION_OFFSET
						]
						kind = WIRE_OPERAND_KIND_BLOCK [
							block-value verified-functions reference WIRE_RSIR_BLOCK_FUNCTION_OFFSET
						]
						kind = WIRE_OPERAND_KIND_LOCAL [
							local-value verified-functions reference WIRE_RSIR_LOCAL_FUNCTION_OFFSET
						]
						true [owner-function]
					]
					if function-id <> owner-function [
						record-base: verified-view/operands-offset
							+ ((operand-id - 1) * WIRE_RSIR_OPERAND_SIZE)
						return set-error result
							WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_FUNCTION
							(record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							verified-view/operands-ordinal
					]
					operand-id: operand-id + 1
				]
				cursor: first-operand + operand-count
			]
			instruction-id: instruction-id + 1
		]
		if cursor <> (verified-view/operand-count + 1) [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_COVERAGE
				(verified-view/operands-offset + ((cursor - 1) * WIRE_RSIR_OPERAND_SIZE))
				verified-view/operands-ordinal
		]

		; Functions own parameter values first, then instruction results.
		cursor: 1
		function-id: 1
		while [function-id <= verified-functions/function-count][
			signature-id: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			parameter-count: signature-value verified-functions signature-id
				WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			first-local: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			argument-index: 0
			while [argument-index < parameter-count][
				if cursor > verified-view/value-count [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(verified-view/values-offset
							+ (verified-view/value-count * WIRE_RSIR_VALUE_SIZE))
						verified-view/values-ordinal
				]
				value-id: cursor
				local-id: first-local + argument-index
				record-base: verified-view/values-offset
					+ ((value-id - 1) * WIRE_RSIR_VALUE_SIZE)
				field: WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
				expected: WIRE_VALUE_DEFINITION_PARAMETER
				if (value-value verified-view value-id field) <> expected [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(record-base + field) verified-view/values-ordinal
				]
				field: WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
				expected: local-id
				if (value-value verified-view value-id field) <> expected [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(record-base + field) verified-view/values-ordinal
				]
				field: WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
				expected: 0
				if (value-value verified-view value-id field) <> expected [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(record-base + field) verified-view/values-ordinal
				]
				field: WIRE_RSIR_VALUE_TYPE_OFFSET
				expected: local-value verified-functions local-id WIRE_RSIR_LOCAL_TYPE_OFFSET
				if (value-value verified-view value-id field) <> expected [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(record-base + field) verified-view/values-ordinal
				]
				field: WIRE_RSIR_VALUE_FUNCTION_OFFSET
				expected: function-id
				if (value-value verified-view value-id field) <> expected [
					return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
						(record-base + field) verified-view/values-ordinal
				]
				cursor: cursor + 1
				argument-index: argument-index + 1
			]

			block-first: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			function-block-count: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-end: block-first + function-block-count
			block-id: block-first
			while [block-id < block-end][
				instruction-id: block-value verified-functions block-id
					WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
				count: block-value verified-functions block-id
					WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
				if count = 0 [instruction-id: 1]
				while [count > 0][
					first-result: instruction-value verified-view instruction-id
						WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
					result-count: instruction-value verified-view instruction-id
						WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
					if all [result-count > 0 first-result <> cursor][
						record-base: verified-view/instructions-offset
							+ ((instruction-id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
						return set-error result
							WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
							(record-base + WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET)
							verified-view/instructions-ordinal
					]
					result-id: 0
					while [result-id < result-count][
						value-id: cursor + result-id
						record-base: verified-view/values-offset
							+ ((value-id - 1) * WIRE_RSIR_VALUE_SIZE)
						field: WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
						expected: WIRE_VALUE_DEFINITION_INSTRUCTION
						if (value-value verified-view value-id field) <> expected [
							return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
								(record-base + field) verified-view/values-ordinal
						]
						field: WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
						expected: instruction-id
						if (value-value verified-view value-id field) <> expected [
							return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
								(record-base + field) verified-view/values-ordinal
						]
						field: WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
						expected: result-id
						if (value-value verified-view value-id field) <> expected [
							return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
								(record-base + field) verified-view/values-ordinal
						]
						field: WIRE_RSIR_VALUE_FUNCTION_OFFSET
						expected: function-id
						if (value-value verified-view value-id field) <> expected [
							return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
								(record-base + field) verified-view/values-ordinal
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
		if cursor <> (verified-view/value-count + 1) [
			return set-error result WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_COVERAGE
				(verified-view/values-offset + ((cursor - 1) * WIRE_RSIR_VALUE_SIZE))
				verified-view/values-ordinal
		]

		instruction-id: 1
		while [instruction-id <= verified-view/instruction-count][
			status: verify-scalar-instruction result verified-types verified-constants
				verified-view instruction-id
			if status <> WIRE_SCALAR_OPERATION_ERROR_SUCCESS [return status]
			instruction-id: instruction-id + 1
		]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		copy-symbols symbols verified-symbols
		copy-constants constants verified-constants
		copy-view view verified-view
		WIRE_SCALAR_OPERATION_ERROR_SUCCESS
	]
]
