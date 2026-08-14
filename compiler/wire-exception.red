Red [
	Title: "Hybrid compiler RSIR exception verifier"
	File:  %wire-exception.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-call-abi [do %wire-call-abi.red]

compiler-wire-exception: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	call-verifier: compiler-wire-call-abi

	catch-effects: schema/WIRE_EFFECT_FLAG_CONTROL
	throw-effects:
		(schema/WIRE_EFFECT_FLAG_CONTROL + schema/WIRE_EFFECT_FLAG_THROW)
		+ schema/WIRE_EFFECT_FLAG_WRITE

	make-view: does [
		make object! [
			regions-offset: 0
			region-count: 0
			region-record-size: schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
			regions-ordinal: 0
			block-members-offset: 0
			block-member-count: 0
			block-member-record-size: schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE
			block-members-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_EXCEPTION_ERROR_SUCCESS
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
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-call-result: func [result call-result [object!]][
		result/header: call-result/header
		result/call-abi-error: call-result/error
		result/control-flow-error: call-result/control-flow-error
		result/scalar-operation-error: call-result/scalar-operation-error
		result/container-error: call-result/container-error
		result/string-error: call-result/string-error
		result/file-source-error: call-result/file-source-error
		result/data-layout-error: call-result/data-layout-error
		result/type-layout-error: call-result/type-layout-error
		result/function-signature-error: call-result/function-signature-error
		result/module-lifecycle-error: call-result/module-lifecycle-error
		result/symbol-linkage-error: call-result/symbol-linkage-error
		result/constant-initializer-error: call-result/constant-initializer-error
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	region-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/regions-offset schema/WIRE_RSIR_EXCEPTION_REGION_SIZE id field
	]

	member-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/block-members-offset schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE
			id field
	]

	block-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/blocks-offset schema/WIRE_RSIR_BLOCK_SIZE id field
	]

	edge-value: func [data [binary!] control [object!] id field [integer!]][
		record-value data control/edges-offset schema/WIRE_RSIR_EDGE_SIZE id field
	]

	instruction-value: func [data [binary!] scalar [object!] id field [integer!]][
		record-value data scalar/instructions-offset schema/WIRE_RSIR_INSTRUCTION_SIZE
			id field
	]

	operand-value: func [data [binary!] scalar [object!] id field [integer!]][
		record-value data scalar/operands-offset schema/WIRE_RSIR_OPERAND_SIZE id field
	]

	value-value: func [data [binary!] scalar [object!] id field [integer!]][
		record-value data scalar/values-offset schema/WIRE_RSIR_VALUE_SIZE id field
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

	call-value: func [data [binary!] calls [object!] id field [integer!]][
		record-value data calls/calls-offset schema/WIRE_RSIR_CALL_SIZE id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		record-value data constants/constants-offset schema/WIRE_RSIR_CONSTANT_SIZE id field
	]

	region-base: func [view [object!] id [integer!]][
		view/regions-offset + ((id - 1) * schema/WIRE_RSIR_EXCEPTION_REGION_SIZE)
	]

	member-base: func [view [object!] id [integer!]][
		view/block-members-offset + ((id - 1) * schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE)
	]

	block-base: func [functions [object!] id [integer!]][
		functions/blocks-offset + ((id - 1) * schema/WIRE_RSIR_BLOCK_SIZE)
	]

	edge-base: func [control [object!] id [integer!]][
		control/edges-offset + ((id - 1) * schema/WIRE_RSIR_EDGE_SIZE)
	]

	instruction-base: func [scalar [object!] id [integer!]][
		scalar/instructions-offset + ((id - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [scalar [object!] id [integer!]][
		scalar/operands-offset + ((id - 1) * schema/WIRE_RSIR_OPERAND_SIZE)
	]

	signature-base: func [functions [object!] id [integer!]][
		functions/signatures-offset + ((id - 1) * schema/WIRE_RSIR_SIGNATURE_SIZE)
	]

	valid-region-kind?: func [kind [integer!]][
		any [
			kind = schema/WIRE_EXCEPTION_REGION_KIND_FILTER
			kind = schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
		]
	]

	catch-all?: func [data [binary!] view [object!] region-id [integer!]][
		((region-value data view region-id schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET)
			and schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> 0
	]

	ordinary-edge?: func [kind [integer!]][kind <> schema/WIRE_EDGE_KIND_EXCEPTION]

	region-contains-block?: func [
		data [binary!] view [object!] region-id block-id [integer!]
		/local first count index
	][
		first: region-value data view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value data view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			if (member-value data view (first + index)
				schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET) = block-id [return true]
			index: index + 1
		]
		false
	]

	region-subset?: func [
		data [binary!] view [object!] child parent [integer!]
		/local first count index block-id
	][
		first: region-value data view child
			schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value data view child
			schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			block-id: member-value data view (first + index)
				schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
			unless region-contains-block? data view parent block-id [return false]
			index: index + 1
		]
		true
	]

	regions-overlap?: func [
		data [binary!] view [object!] left right [integer!]
		/local first count index block-id
	][
		first: region-value data view left
			schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value data view left
			schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			block-id: member-value data view (first + index)
				schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
			if region-contains-block? data view right block-id [return true]
			index: index + 1
		]
		false
	]

	region-for-handler: func [
		data [binary!] view [object!] handler [integer!]
		/local region-id
	][
		region-id: 1
		while [region-id <= view/region-count][
			if (region-value data view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET) = handler [
				return region-id
			]
			region-id: region-id + 1
		]
		0
	]

	plain-signed-i32?: func [data [binary!] types [object!] type-id [integer!]][
		all [
			type-id > 0
			type-id <= types/type-count
			(type-value data types type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_INTEGER
			(type-value data types type-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET)
				= schema/WIRE_TYPE_FLAG_SIGNED
			(type-value data types type-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value data types type-id schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET)
				= schema/WIRE_GC_KIND_NONE
		]
	]

	value-is-minus-one?: func [
		data [binary!] scalar constants [object!] value-id [integer!]
		/local instruction-id first-operand constant-id kind relative size
			byte-index
	][
		unless (value-value data scalar value-id schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
			= schema/WIRE_VALUE_DEFINITION_INSTRUCTION [return false]
		instruction-id: value-value data scalar value-id
			schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		unless (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = schema/WIRE_OPCODE_CONSTANT [
			return false
		]
		unless (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) = 1 [return false]
		first-operand: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		unless (operand-value data scalar first-operand schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
			= schema/WIRE_OPERAND_KIND_CONSTANT [return false]
		constant-id: operand-value data scalar first-operand
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		kind: constant-value data constants constant-id schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
		unless kind = schema/WIRE_CONSTANT_KIND_SCALAR [return false]
		size: constant-value data constants constant-id schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		unless size = 4 [return false]
		relative: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		byte-index: 0
		while [byte-index < 4][
			unless 255 = to integer! pick data
				(constants/constant-data-offset + relative + byte-index + 1) [return false]
			byte-index: byte-index + 1
		]
		true
	]

	ordinary-edge-count: func [
		data [binary!] functions control [object!] block-id [integer!]
		/local first count index kind
	][
		first: block-value data functions block-id
			schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		count: block-value data functions block-id
			schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
		index: 0
		while [index < count][
			kind: edge-value data control (first + index) schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if kind = schema/WIRE_EDGE_KIND_EXCEPTION [return index]
			index: index + 1
		]
		count
	]

	block-has-ordinary-incoming?: func [
		data [binary!] control [object!] block-id [integer!]
		/local edge-id kind
	][
		edge-id: 1
		while [edge-id <= control/edge-count][
			kind: edge-value data control edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if all [
				ordinary-edge? kind
				(edge-value data control edge-id schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					= block-id
			][return true]
			edge-id: edge-id + 1
		]
		false
	]

	block-first-instruction: func [data [binary!] functions [object!] block-id [integer!]][
		block-value data functions block-id schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
	]

	block-instruction-count: func [data [binary!] functions [object!] block-id [integer!]][
		block-value data functions block-id schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
	]

	block-terminator: func [
		data [binary!] functions scalar [object!] block-id [integer!]
	][
		((block-first-instruction data functions block-id)
			+ (block-instruction-count data functions block-id)) - 1
	]

	jump-target: func [
		data [binary!] scalar [object!] instruction-id [integer!]
		/local operand-id
	][
		operand-id: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
	]

	call-id-for-instruction: func [
		data [binary!] calls [object!] instruction-id [integer!]
		/local call-id
	][
		call-id: 1
		while [call-id <= calls/call-count][
			if (call-value data calls call-id schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
				= instruction-id [return call-id]
			call-id: call-id + 1
		]
		0
	]

	verify-catch-instruction: func [
		data [binary!] result call-result exception-view [object!] instruction-id [integer!]
		/local scalar functions types constants base opcode first-operand operand-count
			handler region-id region-kind region-flags expected-count operand-id value-id
			type-id actual alias-kind alias-id filter-catch-all?
	][
		scalar: call-result/scalar-view
		functions: call-result/functions
		types: call-result/types
		constants: call-result/constants
		base: instruction-base scalar instruction-id
		opcode: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET

		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_SUBOPCODE
				(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_FLAGS
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_RESULT_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				scalar/instructions-ordinal
		]

		first-operand: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if operand-count < 1 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				scalar/instructions-ordinal
		]
		if (operand-value data scalar first-operand schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
			<> schema/WIRE_OPERAND_KIND_BLOCK [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_KIND
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
				scalar/operands-ordinal
		]
		if (operand-value data scalar first-operand
			schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET) <> 0 [
			return reject result
				schema/WIRE_EXCEPTION_ERROR_NONZERO_CATCH_OPERAND_AUXILIARY
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar/operands-ordinal
		]
		handler: operand-value data scalar first-operand schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		region-id: region-for-handler data exception-view handler
		if region-id = 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_HANDLER
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]
		if (region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET) <>
			(block-value data functions
				(instruction-value data scalar instruction-id schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
				schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET) [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_HANDLER
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]

		region-kind: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET
		region-flags: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET
		expected-count: either opcode = schema/WIRE_OPCODE_CATCH_LEAVE [1][
			either region-kind = schema/WIRE_EXCEPTION_REGION_KIND_FILTER [2][1]
		]
		if operand-count <> expected-count [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				scalar/instructions-ordinal
		]

		if all [
			opcode = schema/WIRE_OPCODE_CATCH_ENTER
			region-kind = schema/WIRE_EXCEPTION_REGION_KIND_FILTER
		][
			operand-id: first-operand + 1
			if (operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
				<> schema/WIRE_OPERAND_KIND_VALUE [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_KIND
					((operand-base scalar operand-id) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					scalar/operands-ordinal
			]
			if (operand-value data scalar operand-id
				schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET) <> 0 [
				return reject result
					schema/WIRE_EXCEPTION_ERROR_NONZERO_CATCH_OPERAND_AUXILIARY
					((operand-base scalar operand-id) + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					scalar/operands-ordinal
			]
			value-id: operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			type-id: value-value data scalar value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			unless plain-signed-i32? data types type-id [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_FILTER_TYPE
					((operand-base scalar operand-id) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			filter-catch-all?: value-is-minus-one? data scalar constants value-id
			if (((region-flags and schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> 0)
				<> filter-catch-all?) [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_ALL_FILTER
					((operand-base scalar operand-id) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
		]

		actual: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual <> catch-effects [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_EFFECTS
				(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		alias-kind: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [alias-kind = schema/WIRE_ALIAS_KIND_NONE alias-id = 0][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_ALIAS
				(base + either alias-kind <> schema/WIRE_ALIAS_KIND_NONE [
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET])
				scalar/instructions-ordinal
		]
		none
	]

	verify-throw-instruction: func [
		data [binary!] result call-result [object!] instruction-id [integer!]
		/local scalar types base first-operand value-id type-id actual alias-kind alias-id
	][
		scalar: call-result/scalar-view
		types: call-result/types
		base: instruction-base scalar instruction-id
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_SUBOPCODE
				(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_FLAGS
				(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_RESULT_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) <> 1 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_COUNT
				(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
				scalar/instructions-ordinal
		]
		first-operand: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		if (operand-value data scalar first-operand schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
			<> schema/WIRE_OPERAND_KIND_VALUE [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_KIND
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
				scalar/operands-ordinal
		]
		if (operand-value data scalar first-operand
			schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET) <> 0 [
			return reject result
				schema/WIRE_EXCEPTION_ERROR_NONZERO_THROW_OPERAND_AUXILIARY
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar/operands-ordinal
		]
		value-id: operand-value data scalar first-operand schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		type-id: value-value data scalar value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET
		unless plain-signed-i32? data types type-id [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_TYPE
				((operand-base scalar first-operand) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]
		actual: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual <> throw-effects [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_EFFECTS
				(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		alias-kind: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [alias-kind = schema/WIRE_ALIAS_KIND_UNIVERSAL alias-id = 0][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_ALIAS
				(base + either alias-kind <> schema/WIRE_ALIAS_KIND_UNIVERSAL [
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET])
				scalar/instructions-ordinal
		]
		none
	]

	catch-handler: func [
		data [binary!] scalar [object!] instruction-id [integer!]
		/local operand-id
	][
		operand-id: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
	]

	find-region-enter: func [
		data [binary!] scalar exception-view [object!] region-id [integer!]
		/local handler instruction-id opcode found
	][
		handler: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
		found: 0
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if all [
				opcode = schema/WIRE_OPCODE_CATCH_ENTER
				(catch-handler data scalar instruction-id) = handler
			][
				if found <> 0 [return -1]
				found: instruction-id
			]
			instruction-id: instruction-id + 1
		]
		found
	]

	block-enter-region: func [
		data [binary!] functions scalar exception-view [object!] block-id [integer!]
		/local count instruction-id opcode handler
	][
		count: block-instruction-count data functions block-id
		if count < 2 [return 0]
		instruction-id: ((block-first-instruction data functions block-id) + count) - 2
		opcode: instruction-value data scalar instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode <> schema/WIRE_OPCODE_CATCH_ENTER [return 0]
		handler: catch-handler data scalar instruction-id
		region-for-handler data exception-view handler
	]

	verify-leave-prefix: func [
		data [binary!] functions scalar exception-view [object!] source target [integer!]
		/local instruction-id finish region-id opcode handler expected-handler expected-count
	][
		instruction-id: block-first-instruction data functions target
		finish: instruction-id + (block-instruction-count data functions target)
		expected-count: 0
		region-id: exception-view/region-count
		while [region-id > 0][
			if all [
				region-contains-block? data exception-view region-id source
				not region-contains-block? data exception-view region-id target
			][
				expected-count: expected-count + 1
				if instruction-id >= finish [return false]
				opcode: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				if opcode <> schema/WIRE_OPCODE_CATCH_LEAVE [return false]
				handler: catch-handler data scalar instruction-id
				expected-handler: region-value data exception-view region-id
					schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
				if handler <> expected-handler [return false]
				instruction-id: instruction-id + 1
			]
			region-id: region-id - 1
		]
		if all [
			instruction-id < finish
			(instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = schema/WIRE_OPCODE_CATCH_LEAVE
		][return false]
		expected-count > 0
	]

	verify-region-boundaries: func [
		data [binary!] result call-result exception-view [object!]
		/local functions scalar control edge-id kind source target region-id entered exited
			entered-region source-enter block-id terminator opcode base
	][
		functions: call-result/functions
		scalar: call-result/scalar-view
		control: call-result/control-view
		edge-id: 1
		while [edge-id <= control/edge-count][
			kind: edge-value data control edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if ordinary-edge? kind [
				source: edge-value data control edge-id schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
				target: edge-value data control edge-id schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
				entered: 0
				exited: 0
				entered-region: 0
				region-id: 1
				while [region-id <= exception-view/region-count][
					case [
						all [
							not region-contains-block? data exception-view region-id source
							region-contains-block? data exception-view region-id target
						][
							entered: entered + 1
							entered-region: region-id
						]
						all [
							region-contains-block? data exception-view region-id source
							not region-contains-block? data exception-view region-id target
						][exited: exited + 1]
						true []
					]
					region-id: region-id + 1
				]
				if any [all [entered > 0 exited > 0] entered > 1][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if entered = 1 [
					source-enter: block-enter-region data functions scalar exception-view source
					if source-enter <> entered-region [
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
							((edge-base control edge-id) + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							control/edges-ordinal
					]
				]
				if all [entered = 0 exited = 0
					(block-enter-region data functions scalar exception-view source) <> 0][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if all [exited > 0
					not verify-leave-prefix data functions scalar exception-view source target][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if all [exited = 0
					(instruction-value data scalar
						(block-first-instruction data functions target)
						schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						= schema/WIRE_OPCODE_CATCH_LEAVE][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
						(block-base functions target) functions/blocks-ordinal
				]
			]
			edge-id: edge-id + 1
		]

		block-id: 1
		while [block-id <= functions/block-count][
			terminator: block-terminator data functions scalar block-id
			opcode: instruction-value data scalar terminator
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode = schema/WIRE_OPCODE_RETURN [
				region-id: 1
				while [region-id <= exception-view/region-count][
					if region-contains-block? data exception-view region-id block-id [
						base: instruction-base scalar terminator
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
							(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					region-id: region-id + 1
				]
			]
			block-id: block-id + 1
		]
		none
	]

	verify-catch-positions: func [
		data [binary!] result call-result exception-view [object!]
		/local functions scalar block-id instruction-id finish opcode prefix-count
			seen-body? handler-region base
	][
		functions: call-result/functions
		scalar: call-result/scalar-view
		block-id: 1
		while [block-id <= functions/block-count][
			instruction-id: block-first-instruction data functions block-id
			finish: instruction-id + (block-instruction-count data functions block-id)
			prefix-count: 0
			seen-body?: false
			while [instruction-id < finish][
				opcode: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				either opcode = schema/WIRE_OPCODE_CATCH_LEAVE [
					if seen-body? [
						base: instruction-base scalar instruction-id
						return reject result
							schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
							(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					prefix-count: prefix-count + 1
				][seen-body?: true]
				instruction-id: instruction-id + 1
			]

			handler-region: region-for-handler data exception-view block-id
			if any [
				all [handler-region > 0 prefix-count <> 1]
				all [
					handler-region = 0
					prefix-count > 0
					not block-has-ordinary-incoming? data call-result/control-view block-id
				]
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
					(block-base functions block-id) functions/blocks-ordinal
			]
			block-id: block-id + 1
		]
		none
	]

	verify-handler-nesting: func [
		data [binary!] result exception-view [object!]
		/local region-id other-id function-id handler expected? actual? base
	][
		region-id: 1
		while [region-id <= exception-view/region-count][
			function-id: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			handler: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			other-id: 1
			while [other-id <= exception-view/region-count][
				if all [
					other-id <> region-id
					(region-value data exception-view other-id
						schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET) = function-id
				][
					expected?: to logic! all [
						region-subset? data exception-view region-id other-id
						not region-subset? data exception-view other-id region-id
					]
					actual?: region-contains-block? data exception-view other-id handler
					if expected? <> actual? [
						base: region-base exception-view region-id
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_NESTING
							(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
							exception-view/regions-ordinal
					]
				]
				other-id: other-id + 1
			]
			region-id: region-id + 1
		]
		none
	]

	verify-function-region: func [
		data [binary!] result call-result exception-view [object!] region-id enter-id [integer!]
		/local functions scalar control handler member-id member-block enter-block
			first count terminator ordinary-count first-edge normal-leave handler-count
			normal-count normal-first normal-terminator handler-terminator normal-target
			handler-target throw-id throw-count instruction-id finish opcode effect base
	][
		functions: call-result/functions
		scalar: call-result/scalar-view
		control: call-result/control-view
		count: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		if count <> 1 [
			base: region-base exception-view region-id
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(base + schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
				exception-view/regions-ordinal
		]
		member-id: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		member-block: member-value data exception-view member-id
			schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
		handler: region-value data exception-view region-id
			schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
		enter-block: instruction-value data scalar enter-id schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
		if (block-instruction-count data functions enter-block) <> 2 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions enter-block) functions/blocks-ordinal
		]

		throw-id: 0
		throw-count: 0
		instruction-id: block-first-instruction data functions member-block
		finish: instruction-id + (block-instruction-count data functions member-block)
		while [instruction-id < finish][
			effect: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
			if (effect and schema/WIRE_EFFECT_FLAG_THROW) <> 0 [
				throw-count: throw-count + 1
				throw-id: instruction-id
			]
			instruction-id: instruction-id + 1
		]
		if throw-count <> 1 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions member-block) functions/blocks-ordinal
		]
		opcode: instruction-value data scalar throw-id schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if any [
			opcode <> schema/WIRE_OPCODE_CALL
			(instruction-value data scalar throw-id
				schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) <> 0
		][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((instruction-base scalar throw-id) + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				scalar/instructions-ordinal
		]

		terminator: block-terminator data functions scalar member-block
		ordinary-count: ordinary-edge-count data functions control member-block
		if any [
			ordinary-count <> 1
			(instruction-value data scalar terminator schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				<> schema/WIRE_OPCODE_JUMP
		][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions member-block) functions/blocks-ordinal
		]
		first-edge: block-value data functions member-block
			schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		normal-leave: edge-value data control first-edge schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
		if normal-leave = handler [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((edge-base control first-edge) + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
				control/edges-ordinal
		]
		normal-count: block-instruction-count data functions normal-leave
		handler-count: block-instruction-count data functions handler
		if any [normal-count <> 2 handler-count <> 2][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions either normal-count <> 2 [normal-leave][handler])
				functions/blocks-ordinal
		]
		normal-first: block-first-instruction data functions normal-leave
		first: block-first-instruction data functions handler
		unless all [
			(instruction-value data scalar normal-first schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= schema/WIRE_OPCODE_CATCH_LEAVE
			(catch-handler data scalar normal-first) = handler
			(instruction-value data scalar first schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= schema/WIRE_OPCODE_CATCH_LEAVE
			(catch-handler data scalar first) = handler
		][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions normal-leave) functions/blocks-ordinal
		]
		normal-terminator: block-terminator data functions scalar normal-leave
		handler-terminator: block-terminator data functions scalar handler
		unless all [
			(instruction-value data scalar normal-terminator
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = schema/WIRE_OPCODE_JUMP
			(instruction-value data scalar handler-terminator
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = schema/WIRE_OPCODE_JUMP
		][
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions normal-leave) functions/blocks-ordinal
		]
		normal-target: jump-target data scalar normal-terminator
		handler-target: jump-target data scalar handler-terminator
		if normal-target <> handler-target [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((instruction-base scalar handler-terminator)
					+ schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
				scalar/instructions-ordinal
		]
		none
	]

	verify-throwing-blocks: func [
		data [binary!] result call-result exception-view [object!]
		/local functions scalar control calls block-id first count instruction-id finish
			throw-id throw-count effect opcode terminator ordinary-count total-count
			exception-count expected-count first-edge edge-id region-id expected-handler
			caught? owner-function signature-id signature-flags call-id call-kind
			call-signature calling-convention base region-handler
	][
		functions: call-result/functions
		scalar: call-result/scalar-view
		control: call-result/control-view
		calls: call-result/view
		block-id: 1
		while [block-id <= functions/block-count][
			first: block-first-instruction data functions block-id
			count: block-instruction-count data functions block-id
			finish: first + count
			throw-id: 0
			throw-count: 0
			instruction-id: first
			while [instruction-id < finish][
				effect: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				if (effect and schema/WIRE_EFFECT_FLAG_THROW) <> 0 [
					throw-count: throw-count + 1
					throw-id: instruction-id
				]
				instruction-id: instruction-id + 1
			]
			if throw-count > 1 [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_POSITION
					(block-base functions block-id) functions/blocks-ordinal
			]
			ordinary-count: ordinary-edge-count data functions control block-id
			total-count: block-value data functions block-id
				schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
			exception-count: total-count - ordinary-count

			either throw-count = 0 [
				if exception-count <> 0 [
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_COUNT
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			][
				opcode: instruction-value data scalar throw-id
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				effect: instruction-value data scalar throw-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				unless any [
					opcode = schema/WIRE_OPCODE_CALL
					opcode = schema/WIRE_OPCODE_THROW
				][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROWING_OPCODE
						((instruction-base scalar throw-id)
							+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
				terminator: finish - 1
				if any [
					all [opcode = schema/WIRE_OPCODE_THROW throw-id <> terminator]
					all [opcode = schema/WIRE_OPCODE_CALL throw-id <> (terminator - 1)]
				][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_THROW_POSITION
						((instruction-base scalar throw-id)
							+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						 scalar/instructions-ordinal
				]
				expected-count: 0
				caught?: false
				region-id: exception-view/region-count
				while [region-id > 0][
					if region-contains-block? data exception-view region-id block-id [
						expected-count: expected-count + 1
						if catch-all? data exception-view region-id [
							caught?: true
							region-id: 0
						]
					]
					region-id: region-id - 1
				]
				if exception-count <> expected-count [
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_COUNT
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				first-edge: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
				edge-id: first-edge + ordinary-count
				region-id: exception-view/region-count
				while [region-id > 0][
					if region-contains-block? data exception-view region-id block-id [
						expected-handler: region-value data exception-view region-id
							schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
						if (edge-value data control edge-id
							schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) <> expected-handler [
							return reject result
								schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_TARGET
								((edge-base control edge-id)
									+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
								control/edges-ordinal
						]
						edge-id: edge-id + 1
						if catch-all? data exception-view region-id [region-id: 0]
					]
					region-id: region-id - 1
				]

				owner-function: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				signature-id: function-value data functions owner-function
					schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
				signature-flags: signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				if all [
					not caught?
					(signature-flags and schema/WIRE_FUNCTION_FLAG_MAY_THROW) = 0
				][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_DECLARATION
						((signature-base functions signature-id)
							+ schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
						functions/signatures-ordinal
				]

				if opcode = schema/WIRE_OPCODE_CALL [
					call-id: call-id-for-instruction data calls throw-id
					call-kind: call-value data calls call-id schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
					call-signature: call-value data calls call-id schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET
					calling-convention: signature-value data functions call-signature
						schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
					if any [
						none? find reduce [
							schema/WIRE_CALL_KIND_DIRECT schema/WIRE_CALL_KIND_INDIRECT
						] call-kind
						calling-convention <> schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
					][
						base: instruction-base scalar throw-id
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_EXTERNAL_THROW
							(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
							scalar/instructions-ordinal
					]
					if (effect and schema/WIRE_EFFECT_FLAG_STACK) <> 0 [
						base: instruction-base scalar throw-id
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_STACK_INTERACTION
							(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
							scalar/instructions-ordinal
					]
				]
			]
			block-id: block-id + 1
		]
		none
	]

	verify-callbacks-and-stack: func [
		data [binary!] result call-result exception-view [object!]
		/local functions scalar function-id signature-id flags first count instruction-id
			finish has-exception? stack-id opcode region-id base block-id effect
	][
		functions: call-result/functions
		scalar: call-result/scalar-view
		function-id: 1
		while [function-id <= functions/function-count][
			signature-id: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			flags: signature-value data functions signature-id schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			if all [
				(flags and schema/WIRE_FUNCTION_FLAG_CALLBACK) <> 0
				(flags and schema/WIRE_FUNCTION_FLAG_MAY_THROW) <> 0
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_CALLBACK_THROW
					((signature-base functions signature-id)
						+ schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
					functions/signatures-ordinal
			]
			has-exception?: false
			region-id: 1
			while [region-id <= exception-view/region-count][
				if (region-value data exception-view region-id
					schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET) = function-id [
					has-exception?: true
				]
				region-id: region-id + 1
			]
			stack-id: 0
			first: function-value data functions function-id schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			count: function-value data functions function-id schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-id: first
			while [block-id < (first + count)][
				instruction-id: block-first-instruction data functions block-id
				finish: instruction-id + (block-instruction-count data functions block-id)
				while [instruction-id < finish][
					opcode: instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
					effect: instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
					if any [
						opcode = schema/WIRE_OPCODE_THROW
						opcode = schema/WIRE_OPCODE_CATCH_ENTER
						opcode = schema/WIRE_OPCODE_CATCH_LEAVE
						(effect and schema/WIRE_EFFECT_FLAG_THROW) <> 0
					][has-exception?: true]
					if all [
						opcode >= schema/WIRE_OPCODE_STACK_ALLOC
						opcode <= schema/WIRE_OPCODE_POP_ALL
					][stack-id: instruction-id]
					instruction-id: instruction-id + 1
				]
				block-id: block-id + 1
			]
			if all [has-exception? stack-id <> 0][
				base: instruction-base scalar stack-id
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_STACK_INTERACTION
					(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]
			function-id: function-id + 1
		]
		none
	]

	verify: func [
		data
		/local result call-result container-result regions members exception-view
			call-view scalar functions control record-index record-base field-offset value
			region-id function-id previous-function first count cursor finish member-id
			block-id previous-block handler kind flags prior-id left right failure
			instruction-id opcode enter-id previous-enter handler-first region-function
			entry-block member-first has-incoming? edge-id edge-kind edge-source
			terminator nested-region-id
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_EXCEPTION_ERROR_INVALID_ARGUMENTS 0 0
		]
		call-result: call-verifier/verify data
		inherit-call-result result call-result
		unless call-result/valid? [
			return reject result schema/WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI
				call-result/error-offset call-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		regions: container/find-section container-result
			schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS
		members: container/find-section container-result
			schema/WIRE_RSIR_SECTION_EXCEPTION_BLOCKS
		if any [none? regions none? members][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI
				schema/WIRE_HEADER_SIZE 0
		]
		if (select regions 'flags) <> 0 [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_SECTION_FLAGS
				(section-flags-offset regions) (select regions 'ordinal)
		]
		if (select members 'flags) <> 0 [
			return reject result
				schema/WIRE_EXCEPTION_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS
				(section-flags-offset members) (select members 'ordinal)
		]

		exception-view: make-view
		exception-view/regions-offset: select regions 'payload-offset
		exception-view/region-count: select regions 'record-count
		exception-view/region-record-size: select regions 'record-size
		exception-view/regions-ordinal: select regions 'ordinal
		exception-view/block-members-offset: select members 'payload-offset
		exception-view/block-member-count: select members 'record-count
		exception-view/block-member-record-size: select members 'record-size
		exception-view/block-members-ordinal: select members 'ordinal
		call-view: call-result/view
		scalar: call-result/scalar-view
		functions: call-result/functions
		control: call-result/control-view

		record-index: 0
		while [record-index < exception-view/region-count][
			record-base: exception-view/regions-offset
				+ (record-index * schema/WIRE_RSIR_EXCEPTION_REGION_SIZE)
			foreach field-offset [0 4 8 12 16 20][
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_EXCEPTION_ERROR_SCALAR_RANGE
						(record-base + field-offset) exception-view/regions-ordinal
				]
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < exception-view/block-member-count][
			record-base: exception-view/block-members-offset
				+ (record-index * schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE)
			foreach field-offset [0 4][
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_EXCEPTION_ERROR_SCALAR_RANGE
						(record-base + field-offset) exception-view/block-members-ordinal
				]
			]
			record-index: record-index + 1
		]

		cursor: 1
		previous-function: 0
		region-id: 1
		while [region-id <= exception-view/region-count][
			record-base: region-base exception-view region-id
			function-id: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			if any [function-id <= 0 function-id > functions/function-count][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_FUNCTION
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					exception-view/regions-ordinal
			]
			if function-id < previous-function [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ORDER
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					exception-view/regions-ordinal
			]
			previous-function: function-id
			kind: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET
			unless valid-region-kind? kind [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_KIND
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
					exception-view/regions-ordinal
			]
			flags: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET
			if any [
				(flags and schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> flags
				all [
					kind = schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
					flags <> schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
				]
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_FLAGS
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET)
					exception-view/regions-ordinal
			]

			handler: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			if any [
				handler <= 0 handler > functions/block-count
				all [
					handler > 0 handler <= functions/block-count
					(block-value data functions handler schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
						<> function-id
				]
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_HANDLER
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					exception-view/regions-ordinal
			]
			prior-id: 1
			while [prior-id < region-id][
				if (region-value data exception-view prior-id
					schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET) = handler [
					return reject result schema/WIRE_EXCEPTION_ERROR_DUPLICATE_HANDLER
						(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
						exception-view/regions-ordinal
				]
				prior-id: prior-id + 1
			]

			first: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
			count: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
			if any [count <= 0 first <> cursor][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_RANGE
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET)
					exception-view/regions-ordinal
			]
			finish: first + count - 1
			if finish > exception-view/block-member-count [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_RANGE
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
					exception-view/regions-ordinal
			]
			previous-block: 0
			member-id: first
			while [member-id <= finish][
				if (member-value data exception-view member-id
					schema/WIRE_RSIR_EXCEPTION_BLOCK_REGION_OFFSET) <> region-id [
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_COVERAGE
						(member-base exception-view member-id)
						exception-view/block-members-ordinal
				]
				block-id: member-value data exception-view member-id
					schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
				if any [
					block-id <= 0 block-id > functions/block-count
					all [
						block-id > 0 block-id <= functions/block-count
						(block-value data functions block-id schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
							<> function-id
					]
				][
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER
						((member-base exception-view member-id)
							+ schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						exception-view/block-members-ordinal
				]
				if block-id <= previous-block [
					return reject result either block-id = previous-block [
						schema/WIRE_EXCEPTION_ERROR_DUPLICATE_REGION_MEMBER
					][schema/WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER_ORDER]
						((member-base exception-view member-id)
							+ schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						exception-view/block-members-ordinal
				]
				if block-id = handler [
					return reject result schema/WIRE_EXCEPTION_ERROR_HANDLER_IS_MEMBER
						((member-base exception-view member-id)
							+ schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						exception-view/block-members-ordinal
				]
				entry-block: function-value data functions function-id
					schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
				if block-id = entry-block [
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
						((member-base exception-view member-id)
							+ schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						exception-view/block-members-ordinal
				]
				previous-block: block-id
				member-id: member-id + 1
			]
			cursor: finish + 1
			region-id: region-id + 1
		]
		if cursor <> (exception-view/block-member-count + 1) [
			return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_COVERAGE
				(member-base exception-view cursor) exception-view/block-members-ordinal
		]

		left: 1
		while [left <= exception-view/region-count][
			right: left + 1
			while [right <= exception-view/region-count][
				if all [
					(region-value data exception-view left
						schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
						= (region-value data exception-view right
							schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					regions-overlap? data exception-view left right
				][
					if any [
						(region-value data exception-view left
							schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
							= schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
						(region-value data exception-view right
							schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
							= schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
					][
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
							(region-base exception-view right) exception-view/regions-ordinal
					]
					unless all [
						region-subset? data exception-view right left
						not region-subset? data exception-view left right
					][
						return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_NESTING
							(region-base exception-view right) exception-view/regions-ordinal
					]
				]
				right: right + 1
			]
			left: left + 1
		]
		failure: verify-handler-nesting data result exception-view
		if failure [return failure]

		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			failure: case [
				any [
					opcode = schema/WIRE_OPCODE_CATCH_ENTER
					opcode = schema/WIRE_OPCODE_CATCH_LEAVE
				][verify-catch-instruction data result call-result exception-view instruction-id]
				opcode = schema/WIRE_OPCODE_THROW [
					verify-throw-instruction data result call-result instruction-id
				]
				true [none]
			]
			if failure [return failure]
			instruction-id: instruction-id + 1
		]

		previous-function: 0
		previous-enter: 0
		region-id: 1
		while [region-id <= exception-view/region-count][
			record-base: region-base exception-view region-id
			region-function: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			enter-id: find-region-enter data scalar exception-view region-id
			if enter-id <= 0 [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					exception-view/regions-ordinal
			]
			if region-function <> previous-function [previous-enter: 0]
			if enter-id <= previous-enter [
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ORDER
					(record-base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					exception-view/regions-ordinal
			]
			previous-function: region-function
			previous-enter: enter-id
			block-id: instruction-value data scalar enter-id schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			count: block-instruction-count data functions block-id
			terminator: block-terminator data functions scalar block-id
			if any [
				enter-id <> (terminator - 1)
				(instruction-value data scalar terminator
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) <> schema/WIRE_OPCODE_JUMP
				region-contains-block? data exception-view region-id block-id
				not region-contains-block? data exception-view region-id
					(jump-target data scalar terminator)
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
					((instruction-base scalar enter-id) + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]

			handler: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			handler-first: block-first-instruction data functions handler
			if any [
				(instruction-value data scalar handler-first
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) <> schema/WIRE_OPCODE_CATCH_LEAVE
				(catch-handler data scalar handler-first) <> handler
			][
				return reject result schema/WIRE_EXCEPTION_ERROR_BAD_HANDLER_ENTRY
					(block-base functions handler) functions/blocks-ordinal
			]
			if block-has-ordinary-incoming? data control handler [
				return reject result schema/WIRE_EXCEPTION_ERROR_HANDLER_HAS_ORDINARY_INCOMING
					(block-base functions handler) functions/blocks-ordinal
			]

			member-first: region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
			member-id: member-first
			finish: member-first + (region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
			while [member-id < finish][
				block-id: member-value data exception-view member-id
					schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
				has-incoming?: false
				edge-id: 1
				while [edge-id <= control/edge-count][
					edge-kind: edge-value data control edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
					edge-source: edge-value data control edge-id
						schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
					if all [
						ordinary-edge? edge-kind
						(edge-value data control edge-id
							schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) = block-id
						any [
							region-contains-block? data exception-view region-id edge-source
							edge-source = (instruction-value data scalar enter-id
								schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
						]
					][has-incoming?: true]
					edge-id: edge-id + 1
				]
				if not has-incoming? [
					nested-region-id: region-for-handler data exception-view block-id
					has-incoming?: all [
						nested-region-id > 0
						nested-region-id <> region-id
						region-subset? data exception-view nested-region-id region-id
					]
				]
				unless has-incoming? [
					return reject result schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
						((member-base exception-view member-id)
							+ schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						exception-view/block-members-ordinal
				]
				member-id: member-id + 1
			]

			if (region-value data exception-view region-id
				schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
				= schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION [
				failure: verify-function-region data result call-result exception-view
					region-id enter-id
				if failure [return failure]
			]
			region-id: region-id + 1
		]

		failure: verify-catch-positions data result call-result exception-view
		if failure [return failure]
		failure: verify-region-boundaries data result call-result exception-view
		if failure [return failure]
		failure: verify-throwing-blocks data result call-result exception-view
		if failure [return failure]
		failure: verify-callbacks-and-stack data result call-result exception-view
		if failure [return failure]

		result/strings: call-result/strings
		result/files: call-result/files
		result/layout: call-result/layout
		result/types: call-result/types
		result/functions: call-result/functions
		result/modules: call-result/modules
		result/symbols: call-result/symbols
		result/constants: call-result/constants
		result/scalar-view: scalar
		result/control-view: control
		result/call-view: call-view
		result/view: exception-view
		result/valid?: true
		result
	]
]
