Red [
	Title: "Hybrid compiler RSIR memory and aggregate operation verifier"
	File:  %wire-memory-aggregate.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-scalar-operation [do %wire-scalar-operation.red]

compiler-wire-memory-aggregate: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	scalar-verifier: compiler-wire-scalar-operation

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
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

	field-value: func [data [binary!] types [object!] id field [integer!]][
		record-value data types/fields-offset schema/WIRE_RSIR_FIELD_SIZE id field
	]

	local-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/locals-offset schema/WIRE_RSIR_LOCAL_SIZE id field
	]

	symbol-value: func [data [binary!] symbols [object!] id field [integer!]][
		record-value data symbols/symbols-offset schema/WIRE_RSIR_SYMBOL_SIZE id field
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

	aggregate-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [schema/WIRE_TYPE_KIND_STRUCT schema/WIRE_TYPE_KIND_UNION]
			type-kind data types id
	]

	pointer-type?: func [data [binary!] types [object!] id [integer!]][
		(type-kind data types id) = schema/WIRE_TYPE_KIND_POINTER
	]

	ordinary-pointer-to?: func [
		data [binary!] types [object!] pointer-type pointee-type [integer!]
	][
		all [
			pointer-type? data types pointer-type
			(type-flags data types pointer-type) = 0
			(type-detail data types pointer-type) = pointee-type
		]
	]

	storage-compatible?: func [
		data [binary!] types [object!] source target [integer!]
	][
		any [
			source = target
			all [
				(type-kind data types source) = schema/WIRE_TYPE_KIND_INTEGER
				(type-kind data types target) = schema/WIRE_TYPE_KIND_INTEGER
				(type-size data types source) = (type-size data types target)
				(type-flags data types source) = (type-flags data types target)
				any [
					(type-gc-kind data types source) = schema/WIRE_GC_KIND_HANDLE
					(type-gc-kind data types target) = schema/WIRE_GC_KIND_HANDLE
				]
			]
		]
	]

	tagged-union?: func [data [binary!] types [object!] id [integer!]][
		all [
			(type-kind data types id) = schema/WIRE_TYPE_KIND_UNION
			(type-flags data types id) = schema/WIRE_TYPE_FLAG_TAGGED
		]
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
		any [
			all [
				opcode >= schema/WIRE_OPCODE_LOAD_LOCAL
				opcode <= schema/WIRE_OPCODE_AGGREGATE_COPY
			]
			opcode = schema/WIRE_OPCODE_LOAD_UNION_TAG
			opcode = schema/WIRE_OPCODE_SET_UNION_VARIANT
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
		allow-volatile? [logic!]
		/local actual base
	][
		actual: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		unless either allow-volatile? [
			any [
				actual = expected
				actual = (expected + schema/WIRE_EFFECT_FLAG_VOLATILE)
			]
		][actual = expected][
			base: instruction-base view instruction-id
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_EFFECTS
				(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				view/instructions-ordinal
		]
		none
	]

	verify-alias: func [
		data [binary!] result [object!] view [object!] instruction-id
		expected-kind expected-id error-code [integer!]
		/local actual-kind actual-id base relative
	][
		actual-kind: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		actual-id: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if any [actual-kind <> expected-kind actual-id <> expected-id][
			base: instruction-base view instruction-id
			relative: either actual-kind <> expected-kind [
				schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
			][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
			return reject result error-code (base + relative) view/instructions-ordinal
		]
		none
	]

	verify-memory-instruction: func [
		data [binary!] result [object!] scalar-result [object!] instruction-id [integer!]
		/local view types functions symbols base opcode first-result result-count
			first-operand operand-count expected-operands expected-results operand-id
			kind auxiliary reference local-id local-type value-id value-type result-type
			symbol-id symbol-type address-value address-type pointee-type field-id
			field-owner field-type aggregate-type first-field field-count index failure
			expected-effects allow-volatile? expected-alias-kind expected-alias-id
			alias-error source-value source-type destination-value destination-type
	][
		view: scalar-result/view
		types: scalar-result/types
		functions: scalar-result/functions
		symbols: scalar-result/symbols
		base: instruction-base view instruction-id
		opcode: instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless owned-opcode? opcode [return none]

		if (instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) <> 0
		[
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
				(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				view/instructions-ordinal
		]
		if (instruction-value data view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) <> 0
		[
			return reject result
				schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_INSTRUCTION_FLAGS
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

		expected-results: either find reduce [
			schema/WIRE_OPCODE_STORE_LOCAL
			schema/WIRE_OPCODE_STORE_GLOBAL
			schema/WIRE_OPCODE_STORE_INDIRECT
			schema/WIRE_OPCODE_SET_UNION_VARIANT
		] opcode [0][1]
		if result-count <> expected-results [
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_RESULT_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				view/instructions-ordinal
		]

		expected-operands: case [
			opcode = schema/WIRE_OPCODE_AGGREGATE_BUILD [-1]
			find reduce [
				schema/WIRE_OPCODE_STORE_LOCAL
				schema/WIRE_OPCODE_STORE_GLOBAL
				schema/WIRE_OPCODE_STORE_INDIRECT
				schema/WIRE_OPCODE_AGGREGATE_COPY
			] opcode [2]
			true [1]
		]
		if all [expected-operands >= 0 operand-count <> expected-operands][
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				view/instructions-ordinal
		]

		operand-id: first-operand
		while [operand-id < (first-operand + operand-count)][
			kind: operand-value data view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			unless kind = case [
				find reduce [
					schema/WIRE_OPCODE_LOAD_LOCAL
					schema/WIRE_OPCODE_STORE_LOCAL
					schema/WIRE_OPCODE_ADDRESS_LOCAL
				] opcode [either operand-id = first-operand [schema/WIRE_OPERAND_KIND_LOCAL][schema/WIRE_OPERAND_KIND_VALUE]]
				find reduce [
					schema/WIRE_OPCODE_LOAD_GLOBAL
					schema/WIRE_OPCODE_STORE_GLOBAL
					schema/WIRE_OPCODE_ADDRESS_GLOBAL
				] opcode [either operand-id = first-operand [schema/WIRE_OPERAND_KIND_SYMBOL][schema/WIRE_OPERAND_KIND_VALUE]]
				true [schema/WIRE_OPERAND_KIND_VALUE]
			][
				return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_KIND
					((operand-base view operand-id) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					view/operands-ordinal
			]
			if not find reduce [
				schema/WIRE_OPCODE_ADDRESS_FIELD
				schema/WIRE_OPCODE_AGGREGATE_BUILD
				schema/WIRE_OPCODE_SET_UNION_VARIANT
			] opcode [
				auxiliary: operand-value data view operand-id
					schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				if auxiliary <> 0 [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_NONZERO_OPERAND_AUXILIARY
						((operand-base view operand-id)
							+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
			]
			operand-id: operand-id + 1
		]

		expected-effects: 0
		allow-volatile?: false
		expected-alias-kind: schema/WIRE_ALIAS_KIND_NONE
		expected-alias-id: 0
		alias-error: schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_ALIAS

		case [
			find reduce [schema/WIRE_OPCODE_LOAD_LOCAL schema/WIRE_OPCODE_STORE_LOCAL]
				opcode
			[
				local-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				local-type: local-value data functions local-id schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
				either opcode = schema/WIRE_OPCODE_LOAD_LOCAL [
					result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless result-type = local-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value data view (first-operand + 1)
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? data types value-type local-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: schema/WIRE_ALIAS_KIND_LOCAL
				expected-alias-id: local-id
				alias-error: schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_LOCAL_ALIAS
			]
			opcode = schema/WIRE_OPCODE_ADDRESS_LOCAL [
				local-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				local-type: local-value data functions local-id schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? data types result-type local-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_ADDRESS_RESULT_TYPE
						((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			find reduce [schema/WIRE_OPCODE_LOAD_GLOBAL schema/WIRE_OPCODE_STORE_GLOBAL]
				opcode
			[
				symbol-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				unless (symbol-value data symbols symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
					= schema/WIRE_SYMBOL_KIND_GLOBAL
				[
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_SYMBOL
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				symbol-type: symbol-value data symbols symbol-id
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				either opcode = schema/WIRE_OPCODE_LOAD_GLOBAL [
					result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless result-type = symbol-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value data view (first-operand + 1)
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? data types value-type symbol-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: schema/WIRE_ALIAS_KIND_GLOBAL
				expected-alias-id: symbol-id
				alias-error: schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_ALIAS
			]
			opcode = schema/WIRE_OPCODE_ADDRESS_GLOBAL [
				symbol-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				unless (symbol-value data symbols symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
					= schema/WIRE_SYMBOL_KIND_GLOBAL
				[
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_SYMBOL
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				symbol-type: symbol-value data symbols symbol-id
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? data types result-type symbol-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_ADDRESS_RESULT_TYPE
						((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			find reduce [schema/WIRE_OPCODE_LOAD_INDIRECT schema/WIRE_OPCODE_STORE_INDIRECT]
				opcode
			[
				address-value: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value data view address-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? data types address-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_INDIRECT_ADDRESS_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				pointee-type: type-detail data types address-type
				either opcode = schema/WIRE_OPCODE_LOAD_INDIRECT [
					result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless result-type = pointee-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
							view/values-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_READ
				][
					value-id: operand-value data view (first-operand + 1)
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? data types value-type pointee-type [
						return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
							((operand-base view (first-operand + 1))
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					expected-effects: schema/WIRE_EFFECT_FLAG_WRITE
				]
				allow-volatile?: true
				expected-alias-kind: schema/WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = schema/WIRE_OPCODE_ADDRESS_FIELD [
				address-value: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value data view address-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				field-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				if any [field-id <= 0 field-id > types/field-count][
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_REFERENCE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				unless pointer-type? data types address-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_OWNER
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				field-owner: field-value data types field-id schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET
				unless (type-detail data types address-type) = field-owner [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_OWNER
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				field-type: field-value data types field-id schema/WIRE_RSIR_FIELD_TYPE_OFFSET
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless ordinary-pointer-to? data types result-type field-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_RESULT_TYPE
						((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_AGGREGATE_BUILD [
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless aggregate-type? data types result-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_TYPE
						((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				aggregate-type: result-type
				first-field: type-value data types aggregate-type
					schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				field-count: type-value data types aggregate-type
					schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				unless operand-count = either (type-kind data types aggregate-type)
					= schema/WIRE_TYPE_KIND_STRUCT [field-count][1]
				[
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						view/instructions-ordinal
				]
				index: 0
				while [index < operand-count][
					operand-id: first-operand + index
					field-id: operand-value data view operand-id
						schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					unless either (type-kind data types aggregate-type)
						= schema/WIRE_TYPE_KIND_STRUCT
					[
						field-id = (first-field + index)
					][
						all [field-id >= first-field field-id < (first-field + field-count)]
					][
						return reject result
							schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_ORDER
							((operand-base view operand-id)
								+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
							view/operands-ordinal
					]
					field-type: field-value data types field-id schema/WIRE_RSIR_FIELD_TYPE_OFFSET
					value-id: operand-value data view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					value-type: value-value data view value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
					unless storage-compatible? data types value-type field-type [
						return reject result
							schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_TYPE
							((operand-base view operand-id)
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							view/operands-ordinal
					]
					index: index + 1
				]
			]
			opcode = schema/WIRE_OPCODE_AGGREGATE_COPY [
				destination-value: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				source-value: operand-value data view (first-operand + 1)
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				destination-type: value-value data view destination-value
					schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				source-type: value-value data view source-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless all [
					pointer-type? data types destination-type
					aggregate-type? data types (type-detail data types destination-type)
				][
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				unless source-type = destination-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((operand-base view (first-operand + 1))
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				unless result-type = destination-type [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
						((value-base view first-result)
							+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				expected-effects:
					schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_WRITE
				expected-alias-kind: schema/WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = schema/WIRE_OPCODE_LOAD_UNION_TAG [
				address-value: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value data view address-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? data types address-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				aggregate-type: type-detail data types address-type
				unless tagged-union? data types aggregate-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				result-type: value-value data view first-result schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless result-type = (type-detail data types aggregate-type) [
					return reject result
						schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TAG_TYPE
						((value-base view first-result) + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						view/values-ordinal
				]
				expected-effects: schema/WIRE_EFFECT_FLAG_READ
				allow-volatile?: true
				expected-alias-kind: schema/WIRE_ALIAS_KIND_UNIVERSAL
			]
			opcode = schema/WIRE_OPCODE_SET_UNION_VARIANT [
				address-value: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				address-type: value-value data view address-value schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless pointer-type? data types address-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				aggregate-type: type-detail data types address-type
				unless tagged-union? data types aggregate-type [
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						view/operands-ordinal
				]
				field-id: operand-value data view first-operand
					schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
				first-field: type-value data types aggregate-type
					schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
				field-count: type-value data types aggregate-type
					schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
				unless all [
					field-id >= first-field
					field-id < (first-field + field-count)
					(field-value data types field-id schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET)
						= aggregate-type
				][
					return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_VARIANT
						((operand-base view first-operand)
							+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
						view/operands-ordinal
				]
				expected-effects: schema/WIRE_EFFECT_FLAG_WRITE
				allow-volatile?: true
				expected-alias-kind: schema/WIRE_ALIAS_KIND_UNIVERSAL
			]
			true [
				return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
					(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
					view/instructions-ordinal
			]
		]

		failure: verify-effects data result view instruction-id
			expected-effects allow-volatile?
		if failure [return failure]
		failure: verify-alias data result view instruction-id expected-alias-kind
			expected-alias-id alias-error
		if failure [return failure]
		none
	]

	verify: func [data /local result scalar-result instruction-id failure][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS 0 0
		]

		scalar-result: scalar-verifier/verify data
		inherit-scalar-result result scalar-result
		unless scalar-result/valid? [
			return reject result schema/WIRE_MEMORY_AGGREGATE_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		instruction-id: 1
		while [instruction-id <= scalar-result/view/instruction-count][
			failure: verify-memory-instruction data result scalar-result instruction-id
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
