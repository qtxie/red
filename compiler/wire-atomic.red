Red [
	Title: "Hybrid compiler RSIR atomic operation verifier"
	File:  %wire-atomic.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-scalar-operation [do %wire-scalar-operation.red]

compiler-wire-atomic: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	scalar-verifier: compiler-wire-scalar-operation
	allowed-atomic-flags:
		schema/WIRE_ATOMIC_FLAG_ORDER_MASK + schema/WIRE_ATOMIC_FLAG_RETURN_OLD

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_ATOMIC_ERROR_SUCCESS
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
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
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

	type-kind: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
	]

	type-flags: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
	]

	type-size: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET
	]

	type-detail: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
	]

	type-gc-kind: func [data [binary!] types [object!] id [integer!]][
		type-value data types id schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET
	]

	plain-signed-i32?: func [data [binary!] types [object!] id [integer!]][
		all [
			(type-kind data types id) = schema/WIRE_TYPE_KIND_INTEGER
			(type-flags data types id) = schema/WIRE_TYPE_FLAG_SIGNED
			(type-size data types id) = 4
			(type-gc-kind data types id) = schema/WIRE_GC_KIND_NONE
		]
	]

	logic-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_LOGIC
	]

	instruction-base: func [view [object!] id [integer!]][
		record-offset view/instructions-offset (id - 1)
			schema/WIRE_RSIR_INSTRUCTION_SIZE
	]

	operand-base: func [view [object!] id [integer!]][
		record-offset view/operands-offset (id - 1) schema/WIRE_RSIR_OPERAND_SIZE
	]

	value-base: func [view [object!] id [integer!]][
		record-offset view/values-offset (id - 1) schema/WIRE_RSIR_VALUE_SIZE
	]

	owned-opcode?: func [opcode [integer!]][
		all [
			opcode >= schema/WIRE_OPCODE_ATOMIC_LOAD
			opcode <= schema/WIRE_OPCODE_ATOMIC_FENCE
		]
	]

	valid-rmw-operation?: func [operation [integer!]][
		all [
			operation >= schema/WIRE_ATOMIC_RMW_OPERATION_ADD
			operation <= schema/WIRE_ATOMIC_RMW_OPERATION_BIT_XOR
		]
	]

	legal-order?: func [opcode order [integer!]][
		case [
			opcode = schema/WIRE_OPCODE_ATOMIC_LOAD [
				to logic! find reduce [
					schema/WIRE_ATOMIC_ORDER_RELAXED
					schema/WIRE_ATOMIC_ORDER_ACQUIRE
					schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
				] order
			]
			opcode = schema/WIRE_OPCODE_ATOMIC_STORE [
				to logic! find reduce [
					schema/WIRE_ATOMIC_ORDER_RELAXED
					schema/WIRE_ATOMIC_ORDER_RELEASE
					schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
				] order
			]
			find reduce [
				schema/WIRE_OPCODE_ATOMIC_RMW
				schema/WIRE_OPCODE_ATOMIC_CAS
			] opcode [
				all [
					order >= schema/WIRE_ATOMIC_ORDER_RELAXED
					order <= schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			opcode = schema/WIRE_OPCODE_ATOMIC_FENCE [
				all [
					order >= schema/WIRE_ATOMIC_ORDER_ACQUIRE
					order <= schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
				]
			]
			true [false]
		]
	]

	inherit-scalar-result: func [result scalar-result [object!]][
		result/scalar-operation-error: scalar-result/error
		result/container-error: scalar-result/container-error
		result/string-error: scalar-result/string-error
		result/file-source-error: scalar-result/file-source-error
		result/data-layout-error: scalar-result/data-layout-error
		result/type-layout-error: scalar-result/type-layout-error
		result/function-signature-error: scalar-result/function-signature-error
		result/module-lifecycle-error: scalar-result/module-lifecycle-error
		result/symbol-linkage-error: scalar-result/symbol-linkage-error
		result/constant-initializer-error: scalar-result/constant-initializer-error
		result/header: scalar-result/header
	]

	verify-effects: func [
		data [binary!] result [object!] view [object!] instruction-id expected [integer!]
		/local actual base
	][
		actual: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual <> expected [
			base: instruction-base view instruction-id
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_EFFECTS
				(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		none
	]

	verify-alias: func [
		data [binary!] result [object!] view [object!] instruction-id [integer!]
		/local actual-kind actual-id base relative
	][
		actual-kind: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		actual-id: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [
			actual-kind = schema/WIRE_ALIAS_KIND_UNIVERSAL
			actual-id = 0
		][
			base: instruction-base view instruction-id
			relative: either actual-kind <> schema/WIRE_ALIAS_KIND_UNIVERSAL [
				schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
			][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_ALIAS
				(base + relative) view/instructions-ordinal
		]
		none
	]

	verify-atomic-instruction: func [
		data [binary!] result [object!] scalar-result [object!] instruction-id [integer!]
		/local view types base opcode subopcode flags order return-old? first-result
			result-count first-operand operand-count expected-operands valid-results?
			operand-id kind auxiliary address-value address-type value-id value-type
			pointee-type result-type expected-effects failure
	][
		view: scalar-result/view
		types: scalar-result/types
		base: instruction-base view instruction-id
		opcode: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless owned-opcode? opcode [return none]

		subopcode: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		either opcode = schema/WIRE_OPCODE_ATOMIC_RMW [
			unless valid-rmw-operation? subopcode [
				return reject result schema/WIRE_ATOMIC_ERROR_BAD_RMW_OPERATION
					(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		][
			if subopcode <> 0 [
				return reject result schema/WIRE_ATOMIC_ERROR_BAD_SUBOPCODE
					(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]

		flags: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		unless (flags and allowed-atomic-flags) = flags [
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_INSTRUCTION_FLAGS
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		order: flags and schema/WIRE_ATOMIC_FLAG_ORDER_MASK
		unless legal-order? opcode order [
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_ORDER
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		return-old?: (flags and schema/WIRE_ATOMIC_FLAG_RETURN_OLD) <> 0
		if all [return-old? opcode <> schema/WIRE_OPCODE_ATOMIC_RMW][
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_RETURN_MODE
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]

		first-result: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
		result-count: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		first-operand: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET

		valid-results?: case [
			opcode = schema/WIRE_OPCODE_ATOMIC_LOAD [result-count = 1]
			find reduce [
				schema/WIRE_OPCODE_ATOMIC_STORE
				schema/WIRE_OPCODE_ATOMIC_FENCE
			] opcode [result-count = 0]
			true [any [result-count = 0 result-count = 1]]
		]
		unless valid-results? [
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_RESULT_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]

		expected-operands: case [
			opcode = schema/WIRE_OPCODE_ATOMIC_LOAD [1]
			find reduce [
				schema/WIRE_OPCODE_ATOMIC_STORE
				schema/WIRE_OPCODE_ATOMIC_RMW
			] opcode [2]
			opcode = schema/WIRE_OPCODE_ATOMIC_CAS [3]
			true [0]
		]
		if operand-count <> expected-operands [
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]

		if all [return-old? result-count = 0][
			return reject result schema/WIRE_ATOMIC_ERROR_BAD_RETURN_MODE
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				view/instructions-ordinal
		]

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			kind: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			if kind <> schema/WIRE_OPERAND_KIND_VALUE [
				return reject result schema/WIRE_ATOMIC_ERROR_BAD_OPERAND_KIND
					((operand-base view operand-id) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			auxiliary: operand-value data view operand-id
				schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return reject result schema/WIRE_ATOMIC_ERROR_NONZERO_OPERAND_AUXILIARY
					((operand-base view operand-id)
						+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					view/operands-ordinal
			]
			operand-id: operand-id + 1
		]

		if opcode <> schema/WIRE_OPCODE_ATOMIC_FENCE [
			address-value: operand-value data view first-operand
				schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			address-type: value-value data view address-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			unless all [
				(type-kind data types address-type) = schema/WIRE_TYPE_KIND_POINTER
				(type-flags data types address-type) = 0
				pointee-type: type-detail data types address-type
				plain-signed-i32? data types pointee-type
			][
				return reject result schema/WIRE_ATOMIC_ERROR_BAD_ADDRESS_TYPE
					((operand-base view first-operand)
						+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					view/operands-ordinal
			]

			operand-id: first-operand + 1
			while [operand-id < (first-operand + operand-count)][
				value-id: operand-value data view operand-id
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				if value-type <> pointee-type [
					return reject result schema/WIRE_ATOMIC_ERROR_BAD_VALUE_TYPE
						((operand-base view operand-id)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				operand-id: operand-id + 1
			]
		]

		if result-count = 1 [
			result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			unless either opcode = schema/WIRE_OPCODE_ATOMIC_CAS [
				logic-type? data types result-type
			][result-type = pointee-type][
				return reject result schema/WIRE_ATOMIC_ERROR_BAD_RESULT_TYPE
					((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
					view/values-ordinal
			]
		]

		expected-effects: case [
			opcode = schema/WIRE_OPCODE_ATOMIC_LOAD [
				schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_ATOMIC
			]
			opcode = schema/WIRE_OPCODE_ATOMIC_STORE [
				schema/WIRE_EFFECT_FLAG_WRITE + schema/WIRE_EFFECT_FLAG_ATOMIC
			]
			find reduce [
				schema/WIRE_OPCODE_ATOMIC_RMW
				schema/WIRE_OPCODE_ATOMIC_CAS
			] opcode [
				schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_WRITE
					+ schema/WIRE_EFFECT_FLAG_ATOMIC
			]
			true [schema/WIRE_EFFECT_FLAG_ATOMIC]
		]
		failure: verify-effects data result view instruction-id expected-effects
		if failure [return failure]
		failure: verify-alias data result view instruction-id
		if failure [return failure]
		none
	]

	verify: func [data /local result scalar-result instruction-id failure][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_ATOMIC_ERROR_INVALID_ARGUMENTS 0 0
		]

		scalar-result: scalar-verifier/verify data
		inherit-scalar-result result scalar-result
		unless scalar-result/valid? [
			return reject result schema/WIRE_ATOMIC_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		instruction-id: 1
		while [instruction-id <= scalar-result/view/instruction-count][
			failure: verify-atomic-instruction data result scalar-result instruction-id
			if failure [return failure]
			instruction-id: instruction-id + 1
		]

		result/strings: scalar-result/strings
		result/files: scalar-result/files
		result/layout: scalar-result/layout
		result/types: scalar-result/types
		result/functions: scalar-result/functions
		result/modules: scalar-result/modules
		result/symbols: scalar-result/symbols
		result/constants: scalar-result/constants
		result/view: scalar-result/view
		result/valid?: true
		result
	]
]
