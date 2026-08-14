Red/System [
	Title: "Hybrid compiler RSIR exception verifier"
	File:  %wire-exception.reds
]

#include %wire-call-abi.reds

wire-exception-result!: alias struct! [
	error                      [integer!]
	call-abi-error             [integer!]
	control-flow-error         [integer!]
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

wire-exception!: alias struct! [
	regions                  [byte-ptr!]
	region-count             [integer!]
	region-record-size       [integer!]
	regions-offset           [integer!]
	regions-ordinal          [integer!]
	block-members            [byte-ptr!]
	block-member-count       [integer!]
	block-member-record-size [integer!]
	block-members-offset     [integer!]
	block-members-ordinal    [integer!]
]

wire-exception-reader: context [
	catch-effects: WIRE_EFFECT_FLAG_CONTROL
	throw-effects:
		(WIRE_EFFECT_FLAG_CONTROL or WIRE_EFFECT_FLAG_THROW)
		or WIRE_EFFECT_FLAG_WRITE

	set-error: func [
		result [wire-exception-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
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
		/local index relative value [integer!]
	][
		index: 0
		while [index < word-count][
			relative: index * 4
			value: wire-container-reader/read-i31 record relative
			if value < 0 [return relative]
			index: index + 1
		]
		-1
	]

	region-value: func [
		view [wire-exception!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/regions
			(((id - 1) * WIRE_RSIR_EXCEPTION_REGION_SIZE) + field-offset)
	]

	member-value: func [
		view [wire-exception!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/block-members
			(((id - 1) * WIRE_RSIR_EXCEPTION_BLOCK_SIZE) + field-offset)
	]

	block-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/blocks
			(((id - 1) * WIRE_RSIR_BLOCK_SIZE) + field-offset)
	]

	edge-value: func [
		control [wire-control-flow!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 control/edges
			(((id - 1) * WIRE_RSIR_EDGE_SIZE) + field-offset)
	]

	instruction-value: func [
		scalar [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 scalar/instructions
			(((id - 1) * WIRE_RSIR_INSTRUCTION_SIZE) + field-offset)
	]

	operand-value: func [
		scalar [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 scalar/operands
			(((id - 1) * WIRE_RSIR_OPERAND_SIZE) + field-offset)
	]

	value-value: func [
		scalar [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 scalar/values
			(((id - 1) * WIRE_RSIR_VALUE_SIZE) + field-offset)
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

	call-value: func [
		calls [wire-call-abi!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 calls/calls
			(((id - 1) * WIRE_RSIR_CALL_SIZE) + field-offset)
	]

	constant-value: func [
		constants [wire-constant-initializer!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 constants/constants
			(((id - 1) * WIRE_RSIR_CONSTANT_SIZE) + field-offset)
	]

	region-base: func [view [wire-exception!] id [integer!] return: [integer!]][
		view/regions-offset + ((id - 1) * WIRE_RSIR_EXCEPTION_REGION_SIZE)
	]

	member-base: func [view [wire-exception!] id [integer!] return: [integer!]][
		view/block-members-offset + ((id - 1) * WIRE_RSIR_EXCEPTION_BLOCK_SIZE)
	]

	block-base: func [
		functions [wire-function-signature!]
		id [integer!]
		return: [integer!]
	][
		functions/blocks-offset + ((id - 1) * WIRE_RSIR_BLOCK_SIZE)
	]

	edge-base: func [control [wire-control-flow!] id [integer!] return: [integer!]][
		control/edges-offset + ((id - 1) * WIRE_RSIR_EDGE_SIZE)
	]

	instruction-base: func [
		scalar [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		scalar/instructions-offset + ((id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [
		scalar [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		scalar/operands-offset + ((id - 1) * WIRE_RSIR_OPERAND_SIZE)
	]

	signature-base: func [
		functions [wire-function-signature!]
		id [integer!]
		return: [integer!]
	][
		functions/signatures-offset + ((id - 1) * WIRE_RSIR_SIGNATURE_SIZE)
	]

	valid-region-kind?: func [kind [integer!] return: [logic!]][
		any [
			kind = WIRE_EXCEPTION_REGION_KIND_FILTER
			kind = WIRE_EXCEPTION_REGION_KIND_FUNCTION
		]
	]

	catch-all?: func [
		view [wire-exception!]
		region-id [integer!]
		return: [logic!]
	][
		((region-value view region-id WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET)
			and WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> 0
	]

	ordinary-edge?: func [kind [integer!] return: [logic!]][
		kind <> WIRE_EDGE_KIND_EXCEPTION
	]

	region-contains-block?: func [
		view [wire-exception!]
		region-id block-id [integer!]
		return: [logic!]
		/local first count index [integer!]
	][
		first: region-value view region-id
			WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value view region-id
			WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			if (member-value view (first + index) WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
				= block-id [return true]
			index: index + 1
		]
		false
	]

	region-subset?: func [
		view [wire-exception!]
		child parent [integer!]
		return: [logic!]
		/local first count index block-id [integer!]
	][
		first: region-value view child
			WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value view child
			WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			block-id: member-value view (first + index) WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
			unless region-contains-block? view parent block-id [return false]
			index: index + 1
		]
		true
	]

	regions-overlap?: func [
		view [wire-exception!]
		left right [integer!]
		return: [logic!]
		/local first count index block-id [integer!]
	][
		first: region-value view left
			WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		count: region-value view left
			WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		index: 0
		while [index < count][
			block-id: member-value view (first + index) WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
			if region-contains-block? view right block-id [return true]
			index: index + 1
		]
		false
	]

	region-for-handler: func [
		view [wire-exception!]
		handler [integer!]
		return: [integer!]
		/local region-id [integer!]
	][
		region-id: 1
		while [region-id <= view/region-count][
			if (region-value view region-id WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
				= handler [return region-id]
			region-id: region-id + 1
		]
		0
	]

	plain-signed-i32?: func [
		types [wire-type-layout!]
		type-id [integer!]
		return: [logic!]
	][
		all [
			type-id > 0
			type-id <= types/type-count
			(type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
			(type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET) = WIRE_TYPE_FLAG_SIGNED
			(type-value types type-id WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value types type-id WIRE_RSIR_TYPE_GC_KIND_OFFSET) = WIRE_GC_KIND_NONE
		]
	]

	value-is-minus-one?: func [
		scalar [wire-scalar-operation!]
		constants [wire-constant-initializer!]
		value-id [integer!]
		return: [logic!]
		/local instruction-id first-operand constant-id kind relative size
			byte-index [integer!] cursor [byte-ptr!]
	][
		unless (value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET)
			= WIRE_VALUE_DEFINITION_INSTRUCTION [return false]
		instruction-id: value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		unless (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
			= WIRE_OPCODE_CONSTANT [return false]
		unless (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
			= 1 [return false]
		first-operand: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		unless (operand-value scalar first-operand WIRE_RSIR_OPERAND_KIND_OFFSET)
			= WIRE_OPERAND_KIND_CONSTANT [return false]
		constant-id: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		kind: constant-value constants constant-id WIRE_RSIR_CONSTANT_KIND_OFFSET
		unless kind = WIRE_CONSTANT_KIND_SCALAR [return false]
		size: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		unless size = 4 [return false]
		relative: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		cursor: constants/constant-data + relative
		byte-index: 0
		while [byte-index < 4][
			if cursor/1 <> as byte! 255 [return false]
			cursor: cursor + 1
			byte-index: byte-index + 1
		]
		true
	]

	ordinary-edge-count: func [
		functions [wire-function-signature!]
		control [wire-control-flow!]
		block-id [integer!]
		return: [integer!]
		/local first count index kind [integer!]
	][
		first: block-value functions block-id WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		count: block-value functions block-id WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
		index: 0
		while [index < count][
			kind: edge-value control (first + index) WIRE_RSIR_EDGE_KIND_OFFSET
			if kind = WIRE_EDGE_KIND_EXCEPTION [return index]
			index: index + 1
		]
		count
	]

	block-has-ordinary-incoming?: func [
		control [wire-control-flow!]
		block-id [integer!]
		return: [logic!]
		/local edge-id kind [integer!]
	][
		edge-id: 1
		while [edge-id <= control/edge-count][
			kind: edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
			if all [
				ordinary-edge? kind
				(edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) = block-id
			][return true]
			edge-id: edge-id + 1
		]
		false
	]

	block-first-instruction: func [
		functions [wire-function-signature!]
		block-id [integer!]
		return: [integer!]
	][
		block-value functions block-id WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
	]

	block-instruction-count: func [
		functions [wire-function-signature!]
		block-id [integer!]
		return: [integer!]
	][
		block-value functions block-id WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
	]

	block-terminator: func [
		functions [wire-function-signature!]
		block-id [integer!]
		return: [integer!]
	][
		((block-first-instruction functions block-id)
			+ (block-instruction-count functions block-id)) - 1
	]

	jump-target: func [
		scalar [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local operand-id [integer!]
	][
		operand-id: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
	]

	call-id-for-instruction: func [
		calls [wire-call-abi!]
		instruction-id [integer!]
		return: [integer!]
		/local call-id [integer!]
	][
		call-id: 1
		while [call-id <= calls/call-count][
			if (call-value calls call-id WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
				= instruction-id [return call-id]
			call-id: call-id + 1
		]
		0
	]

	verify-catch-instruction: func [
		result [wire-exception-result!]
		view [wire-exception!]
		scalar [wire-scalar-operation!]
		functions [wire-function-signature!]
		types [wire-type-layout!]
		constants [wire-constant-initializer!]
		instruction-id [integer!]
		return: [integer!]
		/local base opcode first-operand operand-count handler region-id region-kind
			region-flags expected-count operand-id value-id type-id actual alias-kind
			alias-id relative [integer!] filter-catch-all? [logic!]
	][
		base: instruction-base scalar instruction-id
		opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_SUBOPCODE
				(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_FLAGS
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) scalar/instructions-ordinal
		]

		first-operand: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if operand-count < 1 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) scalar/instructions-ordinal
		]
		if (operand-value scalar first-operand WIRE_RSIR_OPERAND_KIND_OFFSET)
			<> WIRE_OPERAND_KIND_BLOCK [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_KIND
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_KIND_OFFSET)
				scalar/operands-ordinal
		]
		if (operand-value scalar first-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_NONZERO_CATCH_OPERAND_AUXILIARY
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar/operands-ordinal
		]
		handler: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		region-id: region-for-handler view handler
		if region-id = 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_HANDLER
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]
		if (region-value view region-id WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
			<> (block-value functions
				(instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
				WIRE_RSIR_BLOCK_FUNCTION_OFFSET) [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_HANDLER
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]

		region-kind: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET
		region-flags: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET
		expected-count: either opcode = WIRE_OPCODE_CATCH_LEAVE [1][
			either region-kind = WIRE_EXCEPTION_REGION_KIND_FILTER [2][1]
		]
		if operand-count <> expected-count [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) scalar/instructions-ordinal
		]

		if all [
			opcode = WIRE_OPCODE_CATCH_ENTER
			region-kind = WIRE_EXCEPTION_REGION_KIND_FILTER
		][
			operand-id: first-operand + 1
			if (operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET)
				<> WIRE_OPERAND_KIND_VALUE [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_KIND
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_KIND_OFFSET)
					scalar/operands-ordinal
			]
			if (operand-value scalar operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				<> 0 [
				return set-error result WIRE_EXCEPTION_ERROR_NONZERO_CATCH_OPERAND_AUXILIARY
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					scalar/operands-ordinal
			]
			value-id: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			type-id: value-value scalar value-id WIRE_RSIR_VALUE_TYPE_OFFSET
			unless plain-signed-i32? types type-id [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_FILTER_TYPE
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			filter-catch-all?: value-is-minus-one? scalar constants value-id
			if (((region-flags and WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> 0)
				<> filter-catch-all?) [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_ALL_FILTER
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
		]

		actual: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual <> catch-effects [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_EFFECTS
				(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) scalar/instructions-ordinal
		]
		alias-kind: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [alias-kind = WIRE_ALIAS_KIND_NONE alias-id = 0][
			relative: either alias-kind <> WIRE_ALIAS_KIND_NONE [
				WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
			][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
			return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_ALIAS
				(base + relative) scalar/instructions-ordinal
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-throw-instruction: func [
		result [wire-exception-result!]
		scalar [wire-scalar-operation!]
		types [wire-type-layout!]
		instruction-id [integer!]
		return: [integer!]
		/local base first-operand value-id type-id actual alias-kind alias-id
			relative [integer!]
	][
		base: instruction-base scalar instruction-id
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_SUBOPCODE
				(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_FLAGS
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
			<> 1 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_COUNT
				(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) scalar/instructions-ordinal
		]
		first-operand: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		if (operand-value scalar first-operand WIRE_RSIR_OPERAND_KIND_OFFSET)
			<> WIRE_OPERAND_KIND_VALUE [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_KIND
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_KIND_OFFSET)
				scalar/operands-ordinal
		]
		if (operand-value scalar first-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
			<> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_NONZERO_THROW_OPERAND_AUXILIARY
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar/operands-ordinal
		]
		value-id: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		type-id: value-value scalar value-id WIRE_RSIR_VALUE_TYPE_OFFSET
		unless plain-signed-i32? types type-id [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_TYPE
				((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				scalar/operands-ordinal
		]
		actual: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if actual <> throw-effects [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_EFFECTS
				(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) scalar/instructions-ordinal
		]
		alias-kind: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [alias-kind = WIRE_ALIAS_KIND_UNIVERSAL alias-id = 0][
			relative: either alias-kind <> WIRE_ALIAS_KIND_UNIVERSAL [
				WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
			][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
			return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_ALIAS
				(base + relative) scalar/instructions-ordinal
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	catch-handler: func [
		scalar [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local operand-id [integer!]
	][
		operand-id: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
	]

	find-region-enter: func [
		scalar [wire-scalar-operation!]
		view [wire-exception!]
		region-id [integer!]
		return: [integer!]
		/local handler instruction-id opcode found [integer!]
	][
		handler: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
		found: 0
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if all [
				opcode = WIRE_OPCODE_CATCH_ENTER
				(catch-handler scalar instruction-id) = handler
			][
				if found <> 0 [return -1]
				found: instruction-id
			]
			instruction-id: instruction-id + 1
		]
		found
	]

	block-enter-region: func [
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		view [wire-exception!]
		block-id [integer!]
		return: [integer!]
		/local count instruction-id opcode handler [integer!]
	][
		count: block-instruction-count functions block-id
		if count < 2 [return 0]
		instruction-id:
			((block-first-instruction functions block-id) + count) - 2
		opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode <> WIRE_OPCODE_CATCH_ENTER [return 0]
		handler: catch-handler scalar instruction-id
		region-for-handler view handler
	]

	verify-leave-prefix: func [
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		view [wire-exception!]
		source target [integer!]
		return: [logic!]
		/local instruction-id finish region-id opcode handler expected-handler
			expected-count [integer!]
	][
		instruction-id: block-first-instruction functions target
		finish: instruction-id + (block-instruction-count functions target)
		expected-count: 0
		region-id: view/region-count
		while [region-id > 0][
			if all [
				region-contains-block? view region-id source
				not region-contains-block? view region-id target
			][
				expected-count: expected-count + 1
				if instruction-id >= finish [return false]
				opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				if opcode <> WIRE_OPCODE_CATCH_LEAVE [return false]
				handler: catch-handler scalar instruction-id
				expected-handler: region-value view region-id
					WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
				if handler <> expected-handler [return false]
				instruction-id: instruction-id + 1
			]
			region-id: region-id - 1
		]
		if all [
			instruction-id < finish
			(instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= WIRE_OPCODE_CATCH_LEAVE
		][return false]
		expected-count > 0
	]

	verify-region-boundaries: func [
		result [wire-exception-result!]
		view [wire-exception!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		return: [integer!]
		/local edge-id kind source target region-id entered exited entered-region
			source-enter block-id terminator opcode base [integer!]
	][
		edge-id: 1
		while [edge-id <= control/edge-count][
			kind: edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
			if ordinary-edge? kind [
				source: edge-value control edge-id WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
				target: edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
				entered: 0
				exited: 0
				entered-region: 0
				region-id: 1
				while [region-id <= view/region-count][
					case [
						all [
							not region-contains-block? view region-id source
							region-contains-block? view region-id target
						][
							entered: entered + 1
							entered-region: region-id
						]
						all [
							region-contains-block? view region-id source
							not region-contains-block? view region-id target
						][exited: exited + 1]
						true []
					]
					region-id: region-id + 1
				]
				if any [all [entered > 0 exited > 0] entered > 1][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if entered = 1 [
					source-enter: block-enter-region functions scalar view source
					if source-enter <> entered-region [
						return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
							((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							control/edges-ordinal
					]
				]
				if all [
					entered = 0
					exited = 0
					(block-enter-region functions scalar view source) <> 0
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if all [
					exited > 0
					not verify-leave-prefix functions scalar view source target
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
						((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
				if all [
					exited = 0
					(instruction-value scalar
						(block-first-instruction functions target)
						WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) = WIRE_OPCODE_CATCH_LEAVE
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
						(block-base functions target) functions/blocks-ordinal
				]
			]
			edge-id: edge-id + 1
		]

		block-id: 1
		while [block-id <= functions/block-count][
			terminator: block-terminator functions block-id
			opcode: instruction-value scalar terminator WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode = WIRE_OPCODE_RETURN [
				region-id: 1
				while [region-id <= view/region-count][
					if region-contains-block? view region-id block-id [
						base: instruction-base scalar terminator
						return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					region-id: region-id + 1
				]
			]
			block-id: block-id + 1
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-catch-positions: func [
		result [wire-exception-result!]
		view [wire-exception!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		return: [integer!]
		/local block-id instruction-id finish opcode prefix-count handler-region
			base [integer!] seen-body? [logic!]
	][
		block-id: 1
		while [block-id <= functions/block-count][
			instruction-id: block-first-instruction functions block-id
			finish: instruction-id + (block-instruction-count functions block-id)
			prefix-count: 0
			seen-body?: false
			while [instruction-id < finish][
				opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				either opcode = WIRE_OPCODE_CATCH_LEAVE [
					if seen-body? [
						base: instruction-base scalar instruction-id
						return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					prefix-count: prefix-count + 1
				][seen-body?: true]
				instruction-id: instruction-id + 1
			]
			handler-region: region-for-handler view block-id
			if any [
				all [handler-region > 0 prefix-count <> 1]
				all [
					handler-region = 0
					prefix-count > 0
					not block-has-ordinary-incoming? control block-id
				]
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
					(block-base functions block-id) functions/blocks-ordinal
			]
			block-id: block-id + 1
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-handler-nesting: func [
		result [wire-exception-result!]
		view [wire-exception!]
		return: [integer!]
		/local region-id other-id function-id handler base [integer!]
			expected? actual? [logic!]
	][
		region-id: 1
		while [region-id <= view/region-count][
			function-id: region-value view region-id
				WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			handler: region-value view region-id
				WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			other-id: 1
			while [other-id <= view/region-count][
				if all [
					other-id <> region-id
					(region-value view other-id WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
						= function-id
				][
					expected?: all [
						region-subset? view region-id other-id
						not region-subset? view other-id region-id
					]
					actual?: region-contains-block? view other-id handler
					if expected? <> actual? [
						base: region-base view region-id
						return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_NESTING
							(base + WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
							view/regions-ordinal
					]
				]
				other-id: other-id + 1
			]
			region-id: region-id + 1
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-function-region: func [
		result [wire-exception-result!]
		view [wire-exception!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		region-id enter-id [integer!]
		return: [integer!]
		/local handler member-id member-block enter-block first count terminator
			ordinary-count first-edge normal-leave handler-count normal-count normal-first
			normal-terminator handler-terminator normal-target handler-target throw-id
			throw-count instruction-id finish opcode effect base bad-block [integer!]
	][
		count: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
		if count <> 1 [
			base: region-base view region-id
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(base + WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
				view/regions-ordinal
		]
		member-id: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
		member-block: member-value view member-id WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
		handler: region-value view region-id WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
		enter-block: instruction-value scalar enter-id WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
		if (block-instruction-count functions enter-block) <> 2 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions enter-block) functions/blocks-ordinal
		]

		throw-id: 0
		throw-count: 0
		instruction-id: block-first-instruction functions member-block
		finish: instruction-id + (block-instruction-count functions member-block)
		while [instruction-id < finish][
			effect: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
			if (effect and WIRE_EFFECT_FLAG_THROW) <> 0 [
				throw-count: throw-count + 1
				throw-id: instruction-id
			]
			instruction-id: instruction-id + 1
		]
		if throw-count <> 1 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions member-block) functions/blocks-ordinal
		]
		opcode: instruction-value scalar throw-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if any [
			opcode <> WIRE_OPCODE_CALL
			(instruction-value scalar throw-id WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) <> 0
		][
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((instruction-base scalar throw-id) + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				scalar/instructions-ordinal
		]

		terminator: block-terminator functions member-block
		ordinary-count: ordinary-edge-count functions control member-block
		if any [
			ordinary-count <> 1
			(instruction-value scalar terminator WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				<> WIRE_OPCODE_JUMP
		][
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions member-block) functions/blocks-ordinal
		]
		first-edge: block-value functions member-block WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		normal-leave: edge-value control first-edge WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
		if normal-leave = handler [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((edge-base control first-edge) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
				control/edges-ordinal
		]
		normal-count: block-instruction-count functions normal-leave
		handler-count: block-instruction-count functions handler
		if any [normal-count <> 2 handler-count <> 2][
			bad-block: either normal-count <> 2 [normal-leave][handler]
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions bad-block) functions/blocks-ordinal
		]
		normal-first: block-first-instruction functions normal-leave
		first: block-first-instruction functions handler
		unless all [
			(instruction-value scalar normal-first WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= WIRE_OPCODE_CATCH_LEAVE
			(catch-handler scalar normal-first) = handler
			(instruction-value scalar first WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= WIRE_OPCODE_CATCH_LEAVE
			(catch-handler scalar first) = handler
		][
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions normal-leave) functions/blocks-ordinal
		]
		normal-terminator: block-terminator functions normal-leave
		handler-terminator: block-terminator functions handler
		unless all [
			(instruction-value scalar normal-terminator WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= WIRE_OPCODE_JUMP
			(instruction-value scalar handler-terminator WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
				= WIRE_OPCODE_JUMP
		][
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				(block-base functions normal-leave) functions/blocks-ordinal
		]
		normal-target: jump-target scalar normal-terminator
		handler-target: jump-target scalar handler-terminator
		if normal-target <> handler-target [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
				((instruction-base scalar handler-terminator)
					+ WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET)
				scalar/instructions-ordinal
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-throwing-blocks: func [
		result [wire-exception-result!]
		view [wire-exception!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		return: [integer!]
		/local block-id first count instruction-id finish throw-id throw-count effect
			opcode terminator ordinary-count total-count exception-count expected-count
			first-edge edge-id region-id expected-handler owner-function signature-id
			signature-flags call-id call-kind call-signature calling-convention base
			[integer!] caught? [logic!]
	][
		block-id: 1
		while [block-id <= functions/block-count][
			first: block-first-instruction functions block-id
			count: block-instruction-count functions block-id
			finish: first + count
			throw-id: 0
			throw-count: 0
			instruction-id: first
			while [instruction-id < finish][
				effect: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				if (effect and WIRE_EFFECT_FLAG_THROW) <> 0 [
					throw-count: throw-count + 1
					throw-id: instruction-id
				]
				instruction-id: instruction-id + 1
			]
			if throw-count > 1 [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_POSITION
					(block-base functions block-id) functions/blocks-ordinal
			]
			ordinary-count: ordinary-edge-count functions control block-id
			total-count: block-value functions block-id WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
			exception-count: total-count - ordinary-count

			either throw-count = 0 [
				if exception-count <> 0 [
					return set-error result WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_COUNT
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			][
				opcode: instruction-value scalar throw-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				effect: instruction-value scalar throw-id
					WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				unless any [opcode = WIRE_OPCODE_CALL opcode = WIRE_OPCODE_THROW][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_THROWING_OPCODE
						((instruction-base scalar throw-id) + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
				terminator: finish - 1
				if any [
					all [opcode = WIRE_OPCODE_THROW throw-id <> terminator]
					all [opcode = WIRE_OPCODE_CALL throw-id <> (terminator - 1)]
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_THROW_POSITION
						((instruction-base scalar throw-id) + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]

				expected-count: 0
				caught?: false
				region-id: view/region-count
				while [region-id > 0][
					if region-contains-block? view region-id block-id [
						expected-count: expected-count + 1
						if catch-all? view region-id [
							caught?: true
							region-id: 0
						]
					]
					region-id: region-id - 1
				]
				if exception-count <> expected-count [
					return set-error result WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_COUNT
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				first-edge: block-value functions block-id
					WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
				edge-id: first-edge + ordinary-count
				region-id: view/region-count
				while [region-id > 0][
					if region-contains-block? view region-id block-id [
						expected-handler: region-value view region-id
							WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
						if (edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							<> expected-handler [
							return set-error result WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_TARGET
								((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
								control/edges-ordinal
						]
						edge-id: edge-id + 1
						if catch-all? view region-id [region-id: 0]
					]
					region-id: region-id - 1
				]

				owner-function: block-value functions block-id WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				signature-id: function-value functions owner-function WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
				signature-flags: signature-value functions signature-id WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				if all [
					not caught?
					(signature-flags and WIRE_FUNCTION_FLAG_MAY_THROW) = 0
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_DECLARATION
						((signature-base functions signature-id) + WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
						functions/signatures-ordinal
				]

				if opcode = WIRE_OPCODE_CALL [
					call-id: call-id-for-instruction calls throw-id
					call-kind: call-value calls call-id WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
					call-signature: call-value calls call-id WIRE_RSIR_CALL_SIGNATURE_OFFSET
					calling-convention: signature-value functions call-signature
						WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
					if any [
						not (any [
							call-kind = WIRE_CALL_KIND_DIRECT
							call-kind = WIRE_CALL_KIND_INDIRECT
						])
						calling-convention <> WIRE_CALLING_CONVENTION_RED_SYSTEM
					][
						base: instruction-base scalar throw-id
						return set-error result WIRE_EXCEPTION_ERROR_BAD_EXTERNAL_THROW
							(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
							scalar/instructions-ordinal
					]
					if (effect and WIRE_EFFECT_FLAG_STACK) <> 0 [
						base: instruction-base scalar throw-id
						return set-error result WIRE_EXCEPTION_ERROR_BAD_STACK_INTERACTION
							(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
							scalar/instructions-ordinal
					]
				]
			]
			block-id: block-id + 1
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	verify-callbacks-and-stack: func [
		result [wire-exception-result!]
		view [wire-exception!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		return: [integer!]
		/local function-id signature-id flags first count instruction-id finish
			stack-id opcode region-id base block-id effect [integer!]
			has-exception? [logic!]
	][
		function-id: 1
		while [function-id <= functions/function-count][
			signature-id: function-value functions function-id WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			flags: signature-value functions signature-id WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			if all [
				(flags and WIRE_FUNCTION_FLAG_CALLBACK) <> 0
				(flags and WIRE_FUNCTION_FLAG_MAY_THROW) <> 0
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_CALLBACK_THROW
					((signature-base functions signature-id) + WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
					functions/signatures-ordinal
			]
			has-exception?: false
			region-id: 1
			while [region-id <= view/region-count][
				if (region-value view region-id WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					= function-id [has-exception?: true]
				region-id: region-id + 1
			]
			stack-id: 0
			first: function-value functions function-id WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			count: function-value functions function-id WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-id: first
			while [block-id < (first + count)][
				instruction-id: block-first-instruction functions block-id
				finish: instruction-id + (block-instruction-count functions block-id)
				while [instruction-id < finish][
					opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
					effect: instruction-value scalar instruction-id
						WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
					if any [
						opcode = WIRE_OPCODE_THROW
						opcode = WIRE_OPCODE_CATCH_ENTER
						opcode = WIRE_OPCODE_CATCH_LEAVE
						(effect and WIRE_EFFECT_FLAG_THROW) <> 0
					][has-exception?: true]
					if all [
						opcode >= WIRE_OPCODE_STACK_ALLOC
						opcode <= WIRE_OPCODE_POP_ALL
					][stack-id: instruction-id]
					instruction-id: instruction-id + 1
				]
				block-id: block-id + 1
			]
			if all [has-exception? stack-id <> 0][
				base: instruction-base scalar stack-id
				return set-error result WIRE_EXCEPTION_ERROR_BAD_STACK_INTERACTION
					(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]
			function-id: function-id + 1
		]
		WIRE_EXCEPTION_ERROR_SUCCESS
	]

	copy-view: func [destination source [wire-exception!]][
		destination/regions: source/regions
		destination/region-count: source/region-count
		destination/region-record-size: source/region-record-size
		destination/regions-offset: source/regions-offset
		destination/regions-ordinal: source/regions-ordinal
		destination/block-members: source/block-members
		destination/block-member-count: source/block-member-count
		destination/block-member-record-size: source/block-member-record-size
		destination/block-members-offset: source/block-members-offset
		destination/block-members-ordinal: source/block-members-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
		result [wire-exception-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		exceptions [wire-exception!]
		return: [integer!]
		/local call-result [wire-call-abi-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			verified-modules [wire-module-lifecycle!]
			verified-symbols [wire-symbol-linkage!]
			verified-constants [wire-constant-initializer!]
			verified-scalar [wire-scalar-operation!]
			verified-control [wire-control-flow!]
			verified-calls [wire-call-abi!]
			verified-exceptions [wire-exception!]
			regions members [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative record-index record-base region-id function-id
			previous-function first count cursor finish member-id block-id previous-block
			handler kind flags prior-id left right instruction-id opcode enter-id
			previous-enter handler-first region-function entry-block member-first edge-id
			edge-kind edge-source terminator nested-region-id [integer!]
			has-incoming? [logic!]
	][
		if null? result [return WIRE_EXCEPTION_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_EXCEPTION_ERROR_SUCCESS
		result/call-abi-error: WIRE_CALL_ABI_ERROR_SUCCESS
		result/control-flow-error: WIRE_CONTROL_FLOW_ERROR_SUCCESS
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
			workspace-size < 0
			null? data
			null? workspace
			null? strings
			null? files
			null? layout
			null? types
			null? functions
			null? modules
			null? symbols
			null? constants
			null? scalar
			null? control
			null? calls
			null? exceptions
		][
			return set-error result WIRE_EXCEPTION_ERROR_INVALID_ARGUMENTS 0 0
		]

		call-result: declare wire-call-abi-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		verified-modules: declare wire-module-lifecycle!
		verified-symbols: declare wire-symbol-linkage!
		verified-constants: declare wire-constant-initializer!
		verified-scalar: declare wire-scalar-operation!
		verified-control: declare wire-control-flow!
		verified-calls: declare wire-call-abi!
		verified-exceptions: declare wire-exception!
		status: wire-call-abi-reader/verify data size workspace workspace-size
			call-result verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar verified-control verified-calls
		result/call-abi-error: status
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
		if status <> WIRE_CALL_ABI_ERROR_SUCCESS [
			return set-error result WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI
				call-result/error-offset call-result/error-section
		]

		regions: declare wire-section-slice!
		members: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_EXCEPTION_REGIONS regions
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_EXCEPTION_BLOCKS members
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI WIRE_HEADER_SIZE 0
		]
		if regions/flags <> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_SECTION_FLAGS
				section-flags-offset regions regions/ordinal
		]
		if members/flags <> 0 [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS
				section-flags-offset members members/ordinal
		]

		verified-exceptions/regions: regions/data
		verified-exceptions/region-count: regions/record-count
		verified-exceptions/region-record-size: regions/record-size
		verified-exceptions/regions-offset: regions/offset
		verified-exceptions/regions-ordinal: regions/ordinal
		verified-exceptions/block-members: members/data
		verified-exceptions/block-member-count: members/record-count
		verified-exceptions/block-member-record-size: members/record-size
		verified-exceptions/block-members-offset: members/offset
		verified-exceptions/block-members-ordinal: members/ordinal

		record-index: 0
		while [record-index < verified-exceptions/region-count][
			record: verified-exceptions/regions
				+ (record-index * WIRE_RSIR_EXCEPTION_REGION_SIZE)
			bad-relative: first-bad-scalar record 6
			if bad-relative >= 0 [
				return set-error result WIRE_EXCEPTION_ERROR_SCALAR_RANGE
					((verified-exceptions/regions-offset
						+ (record-index * WIRE_RSIR_EXCEPTION_REGION_SIZE)) + bad-relative)
					verified-exceptions/regions-ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < verified-exceptions/block-member-count][
			record: verified-exceptions/block-members
				+ (record-index * WIRE_RSIR_EXCEPTION_BLOCK_SIZE)
			bad-relative: first-bad-scalar record 2
			if bad-relative >= 0 [
				return set-error result WIRE_EXCEPTION_ERROR_SCALAR_RANGE
					((verified-exceptions/block-members-offset
						+ (record-index * WIRE_RSIR_EXCEPTION_BLOCK_SIZE)) + bad-relative)
					verified-exceptions/block-members-ordinal
			]
			record-index: record-index + 1
		]

		cursor: 1
		previous-function: 0
		region-id: 1
		while [region-id <= verified-exceptions/region-count][
			record-base: region-base verified-exceptions region-id
			function-id: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			if any [function-id <= 0 function-id > verified-functions/function-count][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_FUNCTION
					(record-base + WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					verified-exceptions/regions-ordinal
			]
			if function-id < previous-function [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ORDER
					(record-base + WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					verified-exceptions/regions-ordinal
			]
			previous-function: function-id
			kind: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET
			unless valid-region-kind? kind [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_KIND
					(record-base + WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
					verified-exceptions/regions-ordinal
			]
			flags: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET
			if any [
				(flags and WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL) <> flags
				all [
					kind = WIRE_EXCEPTION_REGION_KIND_FUNCTION
					flags <> WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
				]
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_FLAGS
					(record-base + WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET)
					verified-exceptions/regions-ordinal
			]

			handler: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			if any [
				handler <= 0
				handler > verified-functions/block-count
				all [
					handler > 0
					handler <= verified-functions/block-count
					(block-value verified-functions handler WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
						<> function-id
				]
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_HANDLER
					(record-base + WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					verified-exceptions/regions-ordinal
			]
			prior-id: 1
			while [prior-id < region-id][
				if (region-value verified-exceptions prior-id
					WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET) = handler [
					return set-error result WIRE_EXCEPTION_ERROR_DUPLICATE_HANDLER
						(record-base + WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
						verified-exceptions/regions-ordinal
				]
				prior-id: prior-id + 1
			]

			first: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
			count: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET
			if any [count <= 0 first <> cursor][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_RANGE
					(record-base + WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET)
					verified-exceptions/regions-ordinal
			]
			finish: (first + count) - 1
			if finish > verified-exceptions/block-member-count [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_RANGE
					(record-base + WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
					verified-exceptions/regions-ordinal
			]
			previous-block: 0
			member-id: first
			while [member-id <= finish][
				if (member-value verified-exceptions member-id
					WIRE_RSIR_EXCEPTION_BLOCK_REGION_OFFSET) <> region-id [
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_COVERAGE
						(member-base verified-exceptions member-id)
						verified-exceptions/block-members-ordinal
				]
				block-id: member-value verified-exceptions member-id
					WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
				if any [
					block-id <= 0
					block-id > verified-functions/block-count
					all [
						block-id > 0
						block-id <= verified-functions/block-count
						(block-value verified-functions block-id WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
							<> function-id
					]
				][
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER
						((member-base verified-exceptions member-id)
							+ WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						verified-exceptions/block-members-ordinal
				]
				if block-id <= previous-block [
					status: either block-id = previous-block [
						WIRE_EXCEPTION_ERROR_DUPLICATE_REGION_MEMBER
					][WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER_ORDER]
					return set-error result status
						((member-base verified-exceptions member-id)
							+ WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						verified-exceptions/block-members-ordinal
				]
				if block-id = handler [
					return set-error result WIRE_EXCEPTION_ERROR_HANDLER_IS_MEMBER
						((member-base verified-exceptions member-id)
							+ WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						verified-exceptions/block-members-ordinal
				]
				entry-block: function-value verified-functions function-id
					WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
				if block-id = entry-block [
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
						((member-base verified-exceptions member-id)
							+ WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						verified-exceptions/block-members-ordinal
				]
				previous-block: block-id
				member-id: member-id + 1
			]
			cursor: finish + 1
			region-id: region-id + 1
		]
		if cursor <> (verified-exceptions/block-member-count + 1) [
			return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_COVERAGE
				(member-base verified-exceptions cursor)
				verified-exceptions/block-members-ordinal
		]

		left: 1
		while [left <= verified-exceptions/region-count][
			right: left + 1
			while [right <= verified-exceptions/region-count][
				if all [
					(region-value verified-exceptions left
						WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
						= (region-value verified-exceptions right
							WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET)
					regions-overlap? verified-exceptions left right
				][
					if any [
						(region-value verified-exceptions left
							WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
							= WIRE_EXCEPTION_REGION_KIND_FUNCTION
						(region-value verified-exceptions right
							WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
							= WIRE_EXCEPTION_REGION_KIND_FUNCTION
					][
						return set-error result WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION
							(region-base verified-exceptions right)
							verified-exceptions/regions-ordinal
					]
					unless all [
						region-subset? verified-exceptions right left
						not region-subset? verified-exceptions left right
					][
						return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_NESTING
							(region-base verified-exceptions right)
							verified-exceptions/regions-ordinal
					]
				]
				right: right + 1
			]
			left: left + 1
		]
		status: verify-handler-nesting result verified-exceptions
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]

		instruction-id: 1
		while [instruction-id <= verified-scalar/instruction-count][
			opcode: instruction-value verified-scalar instruction-id
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			status: case [
				any [opcode = WIRE_OPCODE_CATCH_ENTER opcode = WIRE_OPCODE_CATCH_LEAVE][
					verify-catch-instruction result verified-exceptions verified-scalar
						verified-functions verified-types verified-constants instruction-id
				]
				opcode = WIRE_OPCODE_THROW [
					verify-throw-instruction result verified-scalar verified-types instruction-id
				]
				true [WIRE_EXCEPTION_ERROR_SUCCESS]
			]
			if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]
			instruction-id: instruction-id + 1
		]

		previous-function: 0
		previous-enter: 0
		region-id: 1
		while [region-id <= verified-exceptions/region-count][
			record-base: region-base verified-exceptions region-id
			region-function: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET
			enter-id: find-region-enter verified-scalar verified-exceptions region-id
			if enter-id <= 0 [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
					(record-base + WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					verified-exceptions/regions-ordinal
			]
			if region-function <> previous-function [previous-enter: 0]
			if enter-id <= previous-enter [
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ORDER
					(record-base + WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
					verified-exceptions/regions-ordinal
			]
			previous-function: region-function
			previous-enter: enter-id
			block-id: instruction-value verified-scalar enter-id
				WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			terminator: block-terminator verified-functions block-id
			if any [
				enter-id <> (terminator - 1)
				(instruction-value verified-scalar terminator WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					<> WIRE_OPCODE_JUMP
				region-contains-block? verified-exceptions region-id block-id
				not region-contains-block? verified-exceptions region-id
					(jump-target verified-scalar terminator)
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
					((instruction-base verified-scalar enter-id)
						+ WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					verified-scalar/instructions-ordinal
			]

			handler: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
			handler-first: block-first-instruction verified-functions handler
			if any [
				(instruction-value verified-scalar handler-first
					WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) <> WIRE_OPCODE_CATCH_LEAVE
				(catch-handler verified-scalar handler-first) <> handler
			][
				return set-error result WIRE_EXCEPTION_ERROR_BAD_HANDLER_ENTRY
					(block-base verified-functions handler) verified-functions/blocks-ordinal
			]
			if block-has-ordinary-incoming? verified-control handler [
				return set-error result WIRE_EXCEPTION_ERROR_HANDLER_HAS_ORDINARY_INCOMING
					(block-base verified-functions handler) verified-functions/blocks-ordinal
			]

			member-first: region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
			member-id: member-first
			finish: member-first + (region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET)
			while [member-id < finish][
				block-id: member-value verified-exceptions member-id
					WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
				has-incoming?: false
				edge-id: 1
				while [edge-id <= verified-control/edge-count][
					edge-kind: edge-value verified-control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
					edge-source: edge-value verified-control edge-id
						WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
					if all [
						ordinary-edge? edge-kind
						(edge-value verified-control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							= block-id
						any [
							region-contains-block? verified-exceptions region-id edge-source
							edge-source = (instruction-value verified-scalar enter-id
								WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET)
						]
					][has-incoming?: true]
					edge-id: edge-id + 1
				]
				if not has-incoming? [
					nested-region-id: region-for-handler verified-exceptions block-id
					has-incoming?: all [
						nested-region-id > 0
						nested-region-id <> region-id
						region-subset? verified-exceptions nested-region-id region-id
					]
				]
				unless has-incoming? [
					return set-error result WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
						((member-base verified-exceptions member-id)
							+ WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
						verified-exceptions/block-members-ordinal
				]
				member-id: member-id + 1
			]

			if (region-value verified-exceptions region-id
				WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET) = WIRE_EXCEPTION_REGION_KIND_FUNCTION [
				status: verify-function-region result verified-exceptions verified-functions
					verified-scalar verified-control region-id enter-id
				if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]
			]
			region-id: region-id + 1
		]

		status: verify-catch-positions result verified-exceptions verified-functions
			verified-scalar verified-control
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]
		status: verify-region-boundaries result verified-exceptions verified-functions
			verified-scalar verified-control
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]
		status: verify-throwing-blocks result verified-exceptions verified-functions
			verified-scalar verified-control verified-calls
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]
		status: verify-callbacks-and-stack result verified-exceptions verified-functions
			verified-scalar
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [return status]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		wire-scalar-operation-reader/copy-symbols symbols verified-symbols
		wire-scalar-operation-reader/copy-constants constants verified-constants
		wire-scalar-operation-reader/copy-view scalar verified-scalar
		wire-control-flow-reader/copy-view control verified-control
		wire-call-abi-reader/copy-view calls verified-calls
		copy-view exceptions verified-exceptions
		WIRE_EXCEPTION_ERROR_SUCCESS
	]
]
