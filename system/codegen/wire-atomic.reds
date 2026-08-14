Red/System [
	Title: "Hybrid compiler RSIR atomic operation verifier"
	File:  %wire-atomic.reds
]

#include %wire-scalar-operation.reds

wire-atomic-result!: alias struct! [
	error                      [integer!]
	scalar-operation-error     [integer!]
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

wire-atomic-reader: context [
	allowed-atomic-flags:
		WIRE_ATOMIC_FLAG_ORDER_MASK + WIRE_ATOMIC_FLAG_RETURN_OLD

	set-error: func [
		result [wire-atomic-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
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

	type-kind: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
	]

	type-flags: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET
	]

	type-size: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_SIZE_OFFSET
	]

	type-detail: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
	]

	type-gc-kind: func [types [wire-type-layout!] id [integer!] return: [integer!]][
		type-value types id WIRE_RSIR_TYPE_GC_KIND_OFFSET
	]

	plain-signed-i32?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			(type-kind types id) = WIRE_TYPE_KIND_INTEGER
			(type-flags types id) = WIRE_TYPE_FLAG_SIGNED
			(type-size types id) = 4
			(type-gc-kind types id) = WIRE_GC_KIND_NONE
		]
	]

	logic-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		(type-kind types id) = WIRE_TYPE_KIND_LOGIC
	]

	instruction-base: func [
		view [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		view/instructions-offset + ((id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [
		view [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		view/operands-offset + ((id - 1) * WIRE_RSIR_OPERAND_SIZE)
	]

	value-base: func [
		view [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		view/values-offset + ((id - 1) * WIRE_RSIR_VALUE_SIZE)
	]

	owned-opcode?: func [opcode [integer!] return: [logic!]][
		all [opcode >= WIRE_OPCODE_ATOMIC_LOAD opcode <= WIRE_OPCODE_ATOMIC_FENCE]
	]

	valid-rmw-operation?: func [operation [integer!] return: [logic!]][
		all [
			operation >= WIRE_ATOMIC_RMW_OPERATION_ADD
			operation <= WIRE_ATOMIC_RMW_OPERATION_BIT_XOR
		]
	]

	legal-order?: func [opcode order [integer!] return: [logic!]][
		case [
			opcode = WIRE_OPCODE_ATOMIC_LOAD [
				any [
					order = WIRE_ATOMIC_ORDER_RELAXED
					order = WIRE_ATOMIC_ORDER_ACQUIRE
					order = WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			opcode = WIRE_OPCODE_ATOMIC_STORE [
				any [
					order = WIRE_ATOMIC_ORDER_RELAXED
					order = WIRE_ATOMIC_ORDER_RELEASE
					order = WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			any [
				opcode = WIRE_OPCODE_ATOMIC_RMW
				opcode = WIRE_OPCODE_ATOMIC_CAS
			][
				all [
					order >= WIRE_ATOMIC_ORDER_RELAXED
					order <= WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			opcode = WIRE_OPCODE_ATOMIC_FENCE [
				all [
					order >= WIRE_ATOMIC_ORDER_ACQUIRE
					order <= WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			true [false]
		]
	]

	verify-effects: func [
		result [wire-atomic-result!]
		view [wire-scalar-operation!]
		instruction-id expected [integer!]
		return: [integer!]
		/local actual base [integer!]
	][
		actual: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual = expected [return WIRE_ATOMIC_ERROR_SUCCESS]
		base: instruction-base view instruction-id
		set-error result WIRE_ATOMIC_ERROR_BAD_EFFECTS
			(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
			view/instructions-ordinal
	]

	verify-alias: func [
		result [wire-atomic-result!]
		view [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local actual-kind actual-id base relative [integer!]
	][
		actual-kind: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		actual-id: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if all [actual-kind = WIRE_ALIAS_KIND_UNIVERSAL actual-id = 0][
			return WIRE_ATOMIC_ERROR_SUCCESS
		]
		base: instruction-base view instruction-id
		relative: either actual-kind <> WIRE_ALIAS_KIND_UNIVERSAL [
			WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
		set-error result WIRE_ATOMIC_ERROR_BAD_ALIAS
			(base + relative) view/instructions-ordinal
	]

	verify-atomic-instruction: func [
		result [wire-atomic-result!]
		types [wire-type-layout!]
		view [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local base opcode subopcode flags order first-result result-count
			first-operand operand-count expected-operands operand-id kind auxiliary
			address-value address-type pointee-type value-id value-type result-type
			expected-effects status [integer!]
			return-old? valid-results? [logic!]
	][
		base: instruction-base view instruction-id
		opcode: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless owned-opcode? opcode [return WIRE_ATOMIC_ERROR_SUCCESS]

		subopcode: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		if opcode = WIRE_OPCODE_ATOMIC_RMW [
			unless valid-rmw-operation? subopcode [
				return set-error result WIRE_ATOMIC_ERROR_BAD_RMW_OPERATION
					(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]
		if all [opcode <> WIRE_OPCODE_ATOMIC_RMW subopcode <> 0][
			return set-error result WIRE_ATOMIC_ERROR_BAD_SUBOPCODE
				(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				view/instructions-ordinal
		]

		flags: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		unless (flags and allowed-atomic-flags) = flags [
			return set-error result WIRE_ATOMIC_ERROR_BAD_INSTRUCTION_FLAGS
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		order: flags and WIRE_ATOMIC_FLAG_ORDER_MASK
		unless legal-order? opcode order [
			return set-error result WIRE_ATOMIC_ERROR_BAD_ORDER
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		return-old?: (flags and WIRE_ATOMIC_FLAG_RETURN_OLD) <> 0
		if all [return-old? opcode <> WIRE_OPCODE_ATOMIC_RMW][
			return set-error result WIRE_ATOMIC_ERROR_BAD_RETURN_MODE
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]

		first-result: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
		result-count: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		first-operand: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET

		valid-results?: case [
			opcode = WIRE_OPCODE_ATOMIC_LOAD [result-count = 1]
			any [
				opcode = WIRE_OPCODE_ATOMIC_STORE
				opcode = WIRE_OPCODE_ATOMIC_FENCE
			][result-count = 0]
			true [any [result-count = 0 result-count = 1]]
		]
		unless valid-results? [
			return set-error result WIRE_ATOMIC_ERROR_BAD_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]

		expected-operands: case [
			opcode = WIRE_OPCODE_ATOMIC_LOAD [1]
			any [
				opcode = WIRE_OPCODE_ATOMIC_STORE
				opcode = WIRE_OPCODE_ATOMIC_RMW
			][2]
			opcode = WIRE_OPCODE_ATOMIC_CAS [3]
			true [0]
		]
		if operand-count <> expected-operands [
			return set-error result WIRE_ATOMIC_ERROR_BAD_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]

		if all [return-old? result-count = 0][
			return set-error result WIRE_ATOMIC_ERROR_BAD_RETURN_MODE
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			kind: operand-value view operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
			if kind <> WIRE_OPERAND_KIND_VALUE [
				return set-error result WIRE_ATOMIC_ERROR_BAD_OPERAND_KIND
					((operand-base view operand-id) + WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			auxiliary: operand-value view operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return set-error result WIRE_ATOMIC_ERROR_NONZERO_OPERAND_AUXILIARY
					((operand-base view operand-id) + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		if opcode <> WIRE_OPCODE_ATOMIC_FENCE [
			address-value: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			address-type: value-value view address-value WIRE_RSIR_VALUE_TYPE_OFFSET
			if (type-kind types address-type) <> WIRE_TYPE_KIND_POINTER [
				return set-error result WIRE_ATOMIC_ERROR_BAD_ADDRESS_TYPE
					((operand-base view first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					view/operands-ordinal
			]
			if (type-flags types address-type) <> 0 [
				return set-error result WIRE_ATOMIC_ERROR_BAD_ADDRESS_TYPE
					((operand-base view first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					view/operands-ordinal
			]
			pointee-type: type-detail types address-type
			unless plain-signed-i32? types pointee-type [
				return set-error result WIRE_ATOMIC_ERROR_BAD_ADDRESS_TYPE
					((operand-base view first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					view/operands-ordinal
			]

			operand-id: first-operand + 1
			while [operand-id < (first-operand + operand-count)][
				value-id: operand-value view operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				value-type: value-value view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
				if value-type <> pointee-type [
					return set-error result WIRE_ATOMIC_ERROR_BAD_VALUE_TYPE
						((operand-base view operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				operand-id: operand-id + 1
			]
		]

		if result-count = 1 [
			result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
			if opcode = WIRE_OPCODE_ATOMIC_CAS [
				unless logic-type? types result-type [
					return set-error result WIRE_ATOMIC_ERROR_BAD_RESULT_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			if all [opcode <> WIRE_OPCODE_ATOMIC_CAS result-type <> pointee-type][
				return set-error result WIRE_ATOMIC_ERROR_BAD_RESULT_TYPE
					((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
					view/values-ordinal
			]
		]

		expected-effects: case [
			opcode = WIRE_OPCODE_ATOMIC_LOAD [
				WIRE_EFFECT_FLAG_READ + WIRE_EFFECT_FLAG_ATOMIC
			]
			opcode = WIRE_OPCODE_ATOMIC_STORE [
				WIRE_EFFECT_FLAG_WRITE + WIRE_EFFECT_FLAG_ATOMIC
			]
			any [
				opcode = WIRE_OPCODE_ATOMIC_RMW
				opcode = WIRE_OPCODE_ATOMIC_CAS
			][
				WIRE_EFFECT_FLAG_READ + WIRE_EFFECT_FLAG_WRITE
					+ WIRE_EFFECT_FLAG_ATOMIC
			]
			true [WIRE_EFFECT_FLAG_ATOMIC]
		]
		status: verify-effects result view instruction-id expected-effects
		if status <> WIRE_ATOMIC_ERROR_SUCCESS [return status]
		verify-alias result view instruction-id
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-atomic-result!]
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
		/local scalar-result [wire-scalar-operation-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			verified-modules [wire-module-lifecycle!]
			verified-symbols [wire-symbol-linkage!]
			verified-constants [wire-constant-initializer!]
			verified-view [wire-scalar-operation!]
			status instruction-id [integer!]
	][
		if null? result [return WIRE_ATOMIC_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_ATOMIC_ERROR_SUCCESS
		result/scalar-operation-error: WIRE_SCALAR_OPERATION_ERROR_SUCCESS
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
			return set-error result WIRE_ATOMIC_ERROR_INVALID_ARGUMENTS 0 0
		]

		scalar-result: declare wire-scalar-operation-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		verified-modules: declare wire-module-lifecycle!
		verified-symbols: declare wire-symbol-linkage!
		verified-constants: declare wire-constant-initializer!
		verified-view: declare wire-scalar-operation!
		status: wire-scalar-operation-reader/verify data size scalar-result
			verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-view
		result/scalar-operation-error: status
		result/container-error: scalar-result/container-error
		result/string-error: scalar-result/string-error
		result/file-source-error: scalar-result/file-source-error
		result/data-layout-error: scalar-result/data-layout-error
		result/type-layout-error: scalar-result/type-layout-error
		result/function-signature-error: scalar-result/function-signature-error
		result/module-lifecycle-error: scalar-result/module-lifecycle-error
		result/symbol-linkage-error: scalar-result/symbol-linkage-error
		result/constant-initializer-error: scalar-result/constant-initializer-error
		if status <> WIRE_SCALAR_OPERATION_ERROR_SUCCESS [
			return set-error result WIRE_ATOMIC_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		instruction-id: 1
		while [instruction-id <= verified-view/instruction-count][
			status: verify-atomic-instruction result verified-types verified-view instruction-id
			if status <> WIRE_ATOMIC_ERROR_SUCCESS [return status]
			instruction-id: instruction-id + 1
		]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		wire-scalar-operation-reader/copy-symbols symbols verified-symbols
		wire-scalar-operation-reader/copy-constants constants verified-constants
		wire-scalar-operation-reader/copy-view view verified-view
		WIRE_ATOMIC_ERROR_SUCCESS
	]
]
