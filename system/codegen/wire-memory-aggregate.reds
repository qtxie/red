Red/System [
	Title: "Hybrid compiler RSIR memory and aggregate operation verifier"
	File:  %wire-memory-aggregate.reds
]

#include %wire-scalar-operation.reds

wire-memory-aggregate-result!: alias struct! [
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

wire-memory-aggregate-reader: context [
	set-error: func [
		result [wire-memory-aggregate-result!]
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

	field-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/fields
			(((id - 1) * WIRE_RSIR_FIELD_SIZE) + field-offset)
	]

	local-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/locals
			(((id - 1) * WIRE_RSIR_LOCAL_SIZE) + field-offset)
	]

	symbol-value: func [
		symbols [wire-symbol-linkage!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 symbols/symbols
			(((id - 1) * WIRE_RSIR_SYMBOL_SIZE) + field-offset)
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

	aggregate-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: type-kind types id
		any [kind = WIRE_TYPE_KIND_STRUCT kind = WIRE_TYPE_KIND_UNION]
	]

	pointer-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		(type-kind types id) = WIRE_TYPE_KIND_POINTER
	]

	ordinary-pointer-to?: func [
		types [wire-type-layout!]
		pointer-type pointee-type [integer!]
		return: [logic!]
	][
		unless pointer-type? types pointer-type [return false]
		if (type-flags types pointer-type) <> 0 [return false]
		(type-detail types pointer-type) = pointee-type
	]

	storage-compatible?: func [
		types [wire-type-layout!]
		source target [integer!]
		return: [logic!]
	][
		if source = target [return true]
		if (type-kind types source) <> WIRE_TYPE_KIND_INTEGER [return false]
		if (type-kind types target) <> WIRE_TYPE_KIND_INTEGER [return false]
		if (type-size types source) <> (type-size types target) [return false]
		if (type-flags types source) <> (type-flags types target) [return false]
		any [
			(type-gc-kind types source) = WIRE_GC_KIND_HANDLE
			(type-gc-kind types target) = WIRE_GC_KIND_HANDLE
		]
	]

	tagged-union?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			(type-kind types id) = WIRE_TYPE_KIND_UNION
			(type-flags types id) = WIRE_TYPE_FLAG_TAGGED
		]
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
		any [
			all [opcode >= WIRE_OPCODE_LOAD_LOCAL opcode <= WIRE_OPCODE_AGGREGATE_COPY]
			opcode = WIRE_OPCODE_LOAD_UNION_TAG
			opcode = WIRE_OPCODE_SET_UNION_VARIANT
		]
	]

	no-result-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_STORE_LOCAL
			opcode = WIRE_OPCODE_STORE_GLOBAL
			opcode = WIRE_OPCODE_STORE_INDIRECT
			opcode = WIRE_OPCODE_SET_UNION_VARIANT
		]
	]

	two-operand-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_STORE_LOCAL
			opcode = WIRE_OPCODE_STORE_GLOBAL
			opcode = WIRE_OPCODE_STORE_INDIRECT
			opcode = WIRE_OPCODE_AGGREGATE_COPY
		]
	]

	local-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_LOAD_LOCAL
			opcode = WIRE_OPCODE_STORE_LOCAL
			opcode = WIRE_OPCODE_ADDRESS_LOCAL
		]
	]

	global-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_LOAD_GLOBAL
			opcode = WIRE_OPCODE_STORE_GLOBAL
			opcode = WIRE_OPCODE_ADDRESS_GLOBAL
		]
	]

	auxiliary-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_ADDRESS_FIELD
			opcode = WIRE_OPCODE_AGGREGATE_BUILD
			opcode = WIRE_OPCODE_SET_UNION_VARIANT
		]
	]

	verify-effects: func [
		result [wire-memory-aggregate-result!]
		view [wire-scalar-operation!]
		instruction-id expected [integer!]
		allow-volatile? [logic!]
		return: [integer!]
		/local actual base [integer!]
	][
		actual: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if allow-volatile? [
			if actual = (expected + WIRE_EFFECT_FLAG_VOLATILE) [
				return WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
			]
		]
		if actual = expected [return WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS]
		base: instruction-base view instruction-id
		set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_EFFECTS
			(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
			view/instructions-ordinal
	]

	verify-alias: func [
		result [wire-memory-aggregate-result!]
		view [wire-scalar-operation!]
		instruction-id expected-kind expected-id error-code [integer!]
		return: [integer!]
		/local actual-kind actual-id base relative [integer!]
	][
		actual-kind: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		actual-id: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if all [actual-kind = expected-kind actual-id = expected-id][
			return WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
		]
		base: instruction-base view instruction-id
		relative: either actual-kind <> expected-kind [
			WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
		set-error result error-code (base + relative) view/instructions-ordinal
	]

	verify-memory-instruction: func [
		result [wire-memory-aggregate-result!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		symbols [wire-symbol-linkage!]
		view [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local base opcode first-result result-count first-operand operand-count
			expected-operands expected-results operand-id expected-kind kind auxiliary
			local-id local-type value-id value-type result-type symbol-id symbol-type
			address-value address-type pointee-type field-id field-owner field-type
			aggregate-type first-field field-count index expected-effects
			expected-alias-kind expected-alias-id alias-error status source-value
			source-type destination-value destination-type [integer!]
			allow-volatile? [logic!]
	][
		base: instruction-base view instruction-id
		opcode: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless owned-opcode? opcode [return WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS]

		if (instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
			<> 0
		[
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
				(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				view/instructions-ordinal
		]
		if (instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
			<> 0
		[
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_INSTRUCTION_FLAGS
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

		expected-results: either no-result-opcode? opcode [0][1]
		if result-count <> expected-results [
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]

		expected-operands: case [
			opcode = WIRE_OPCODE_AGGREGATE_BUILD [-1]
			two-operand-opcode? opcode [2]
			true [1]
		]
		if all [expected-operands >= 0 operand-count <> expected-operands][
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			expected-kind: WIRE_OPERAND_KIND_VALUE
			if all [operand-id = first-operand local-opcode? opcode][
				expected-kind: WIRE_OPERAND_KIND_LOCAL
			]
			if all [operand-id = first-operand global-opcode? opcode][
				expected-kind: WIRE_OPERAND_KIND_SYMBOL
			]
			kind: operand-value view operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
			if kind <> expected-kind [
				return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_KIND
					((operand-base view operand-id) + WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			unless auxiliary-opcode? opcode [
				auxiliary: operand-value view operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				if auxiliary <> 0 [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_NONZERO_OPERAND_AUXILIARY
						((operand-base view operand-id)
							+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
			]
			operand-id: operand-id + 1
		]

		expected-effects: 0
		allow-volatile?: false
		expected-alias-kind: WIRE_ALIAS_KIND_NONE
		expected-alias-id: 0
		alias-error: WIRE_MEMORY_AGGREGATE_ERROR_BAD_ALIAS

		case [
			any [opcode = WIRE_OPCODE_LOAD_LOCAL opcode = WIRE_OPCODE_STORE_LOCAL][
				local-id: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				local-type: local-value functions local-id WIRE_RSIR_LOCAL_TYPE_OFFSET
				either opcode = WIRE_OPCODE_LOAD_LOCAL [
					result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
					if result-type <> local-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value view (first-operand + 1)
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? types value-type local-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: WIRE_ALIAS_KIND_LOCAL
				expected-alias-id: local-id
				alias-error: WIRE_MEMORY_AGGREGATE_ERROR_BAD_LOCAL_ALIAS
			]
			opcode = WIRE_OPCODE_ADDRESS_LOCAL [
				local-id: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				local-type: local-value functions local-id WIRE_RSIR_LOCAL_TYPE_OFFSET
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? types result-type local-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_ADDRESS_RESULT_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			any [opcode = WIRE_OPCODE_LOAD_GLOBAL opcode = WIRE_OPCODE_STORE_GLOBAL][
				symbol-id: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				if (symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET)
					<> WIRE_SYMBOL_KIND_GLOBAL
				[
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_SYMBOL
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				symbol-type: symbol-value symbols symbol-id
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				either opcode = WIRE_OPCODE_LOAD_GLOBAL [
					result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
					if result-type <> symbol-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value view (first-operand + 1)
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? types value-type symbol-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: WIRE_ALIAS_KIND_GLOBAL
				expected-alias-id: symbol-id
				alias-error: WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_ALIAS
			]
			opcode = WIRE_OPCODE_ADDRESS_GLOBAL [
				symbol-id: operand-value view first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				if (symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET)
					<> WIRE_SYMBOL_KIND_GLOBAL
				[
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_SYMBOL
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				symbol-type: symbol-value symbols symbol-id
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? types result-type symbol-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_ADDRESS_RESULT_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			any [
				opcode = WIRE_OPCODE_LOAD_INDIRECT
				opcode = WIRE_OPCODE_STORE_INDIRECT
			][
				address-value: operand-value view first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value view address-value WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? types address-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_INDIRECT_ADDRESS_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				pointee-type: type-detail types address-type
				either opcode = WIRE_OPCODE_LOAD_INDIRECT [
					result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
					if result-type <> pointee-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value view (first-operand + 1)
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? types value-type pointee-type [
						return set-error result WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = WIRE_OPCODE_ADDRESS_FIELD [
				address-value: operand-value view first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value view address-value WIRE_RSIR_VALUE_TYPE_OFFSET
				field-id: operand-value view first-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				if any [field-id <= 0 field-id > types/field-count][
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_REFERENCE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				unless pointer-type? types address-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_OWNER
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				field-owner: field-value types field-id WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
				if (type-detail types address-type) <> field-owner [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_OWNER
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				field-type: field-value types field-id WIRE_RSIR_FIELD_TYPE_OFFSET
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? types result-type field-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_RESULT_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			opcode = WIRE_OPCODE_AGGREGATE_BUILD [
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				unless aggregate-type? types result-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				aggregate-type: result-type
				first-field: type-value types aggregate-type WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				field-count: type-value types aggregate-type WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				expected-operands: either (type-kind types aggregate-type)
					= WIRE_TYPE_KIND_STRUCT [field-count][1]
				if operand-count <> expected-operands [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						view/instructions-ordinal
				]
				index: 0
				while [index < operand-count][
					operand-id: first-operand + index
					field-id: operand-value view operand-id
						WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					either (type-kind types aggregate-type) = WIRE_TYPE_KIND_STRUCT [
						if field-id <> (first-field + index) [
							return set-error result
								WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_ORDER
								((operand-base view operand-id)
									+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
								view/operands-ordinal
						]
					][
						unless all [
							field-id >= first-field
							field-id < (first-field + field-count)
						][
							return set-error result
								WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_ORDER
								((operand-base view operand-id)
									+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
								view/operands-ordinal
						]
					]
					field-type: field-value types field-id WIRE_RSIR_FIELD_TYPE_OFFSET
					value-id: operand-value view operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value view value-id WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? types value-type field-type [
						return set-error result
							WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_TYPE
							((operand-base view operand-id)
								+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					index: index + 1
				]
			]
			opcode = WIRE_OPCODE_AGGREGATE_COPY [
				destination-value: operand-value view first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				source-value: operand-value view (first-operand + 1)
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				destination-type: value-value view destination-value
					WIRE_RSIR_VALUE_TYPE_OFFSET
				source-type: value-value view source-value WIRE_RSIR_VALUE_TYPE_OFFSET
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? types destination-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				unless aggregate-type? types (type-detail types destination-type) [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				if source-type <> destination-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((operand-base view (first-operand + 1))
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				if result-type <> destination-type [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				expected-effects: WIRE_EFFECT_FLAG_READ + WIRE_EFFECT_FLAG_WRITE
				expected-alias-kind: WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = WIRE_OPCODE_LOAD_UNION_TAG [
				address-value: operand-value view first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value view address-value WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? types address-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				aggregate-type: type-detail types address-type
				unless tagged-union? types aggregate-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				result-type: value-value view first-result WIRE_RSIR_VALUE_TYPE_OFFSET
				if result-type <> (type-detail types aggregate-type) [
					return set-error result
						WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TAG_TYPE
						((value-base view first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				expected-effects: WIRE_EFFECT_FLAG_READ
				allow-volatile?: true
				expected-alias-kind: WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = WIRE_OPCODE_SET_UNION_VARIANT [
				address-value: operand-value view first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value view address-value WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? types address-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				aggregate-type: type-detail types address-type
				unless tagged-union? types aggregate-type [
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				field-id: operand-value view first-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				first-field: type-value types aggregate-type WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				field-count: type-value types aggregate-type WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				unless all [
					field-id >= first-field
					field-id < (first-field + field-count)
					(field-value types field-id WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
						= aggregate-type
				][
					return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_VARIANT
						((operand-base view first-operand)
							+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				expected-effects: WIRE_EFFECT_FLAG_WRITE
				allow-volatile?: true
				expected-alias-kind: WIRE_ALIAS_KIND_UNIVERSAL
			]
			true [
				return set-error result WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
					(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]

		status: verify-effects result view instruction-id expected-effects allow-volatile?
		if status <> WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS [return status]
		verify-alias result view instruction-id expected-alias-kind expected-alias-id
			alias-error
	]

	; Validate the memory/aggregate layer over views produced by the shared
	; verifier chain. The standalone verify entry remains independently usable.
	verify-view: func [
		result [wire-memory-aggregate-result!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		symbols [wire-symbol-linkage!]
		view [wire-scalar-operation!]
		return: [integer!]
		/local status instruction-id [integer!]
	][
		if null? result [return WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
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
		if any [null? types null? functions null? symbols null? view][
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS 0 0
		]
		instruction-id: 1
		while [instruction-id <= view/instruction-count][
			status: verify-memory-instruction result types functions symbols view
				instruction-id
			if status <> WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS [return status]
			instruction-id: instruction-id + 1
		]
		WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-memory-aggregate-result!]
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
		if null? result [return WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
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
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS 0 0
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
			return set-error result WIRE_MEMORY_AGGREGATE_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		instruction-id: 1
		while [instruction-id <= verified-view/instruction-count][
			status: verify-memory-instruction result verified-types verified-functions
				verified-symbols verified-view instruction-id
			if status <> WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS [return status]
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
		WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
	]
]
