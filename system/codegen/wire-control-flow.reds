Red/System [
	Title: "Hybrid compiler RSIR control-flow verifier"
	File:  %wire-control-flow.reds
]

#include %wire-scalar-operation.reds

wire-control-flow-result!: alias struct! [
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

wire-control-flow!: alias struct! [
	edges            [byte-ptr!]
	edge-count       [integer!]
	edge-record-size [integer!]
	edges-offset     [integer!]
	edges-ordinal    [integer!]
]

wire-control-flow-reader: context [
	set-error: func [
		result [wire-control-flow-result!]
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

	edge-value: func [
		view [wire-control-flow!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/edges
			(((id - 1) * WIRE_RSIR_EDGE_SIZE) + field-offset)
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

	edge-base: func [
		view [wire-control-flow!]
		id [integer!]
		return: [integer!]
	][
		view/edges-offset + ((id - 1) * WIRE_RSIR_EDGE_SIZE)
	]

	block-base: func [
		functions [wire-function-signature!]
		id [integer!]
		return: [integer!]
	][
		functions/blocks-offset + ((id - 1) * WIRE_RSIR_BLOCK_SIZE)
	]

	terminator?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_BRANCH
			opcode = WIRE_OPCODE_JUMP
			opcode = WIRE_OPCODE_SWITCH
			opcode = WIRE_OPCODE_RETURN
			opcode = WIRE_OPCODE_THROW
			opcode = WIRE_OPCODE_UNREACHABLE
		]
	]

	owned-terminator?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_BRANCH
			opcode = WIRE_OPCODE_JUMP
			opcode = WIRE_OPCODE_SWITCH
			opcode = WIRE_OPCODE_RETURN
			opcode = WIRE_OPCODE_UNREACHABLE
		]
	]

	ordinary-edge?: func [kind [integer!] return: [logic!]][
		kind <> WIRE_EDGE_KIND_EXCEPTION
	]

	verify-common-terminator: func [
		result [wire-control-flow-result!]
		view [wire-scalar-operation!]
		instruction-id [integer!]
		return: [integer!]
		/local base value [integer!]
	][
		base: instruction-base view instruction-id
		value: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
		if value <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SUBOPCODE
				(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) view/instructions-ordinal
		]
		value: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		if value <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_INSTRUCTION_FLAGS
				(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET) view/instructions-ordinal
		]
		value: instruction-value view instruction-id
			WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		if value <> WIRE_EFFECT_FLAG_CONTROL [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EFFECTS
				(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) view/instructions-ordinal
		]
		value: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		if value <> WIRE_ALIAS_KIND_NONE [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_ALIAS
				(base + WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET) view/instructions-ordinal
		]
		value: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		if value <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_ALIAS
				(base + WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET) view/instructions-ordinal
		]
		value: instruction-value view instruction-id WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		if value <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_RESULT_COUNT
				(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) view/instructions-ordinal
		]
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]

	verify-operand-shape: func [
		result [wire-control-flow-result!]
		view [wire-scalar-operation!]
		operand-id expected-kind [integer!]
		return: [integer!]
		/local base kind auxiliary [integer!]
	][
		base: operand-base view operand-id
		kind: operand-value view operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
		if kind <> expected-kind [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_KIND
				(base + WIRE_RSIR_OPERAND_KIND_OFFSET) view/operands-ordinal
		]
		auxiliary: operand-value view operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
		if auxiliary <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_NONZERO_OPERAND_AUXILIARY
				(base + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET) view/operands-ordinal
		]
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]

	ordinary-edge-count: func [
		control [wire-control-flow!]
		functions [wire-function-signature!]
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

	constant-byte: func [
		constants [wire-constant-initializer!]
		constant-id index [integer!]
		return: [integer!]
		/local kind relative [integer!] p [byte-ptr!]
	][
		kind: constant-value constants constant-id WIRE_RSIR_CONSTANT_KIND_OFFSET
		if kind = WIRE_CONSTANT_KIND_ZERO [return 0]
		relative: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		p: constants/constant-data + (relative + index)
		as integer! p/1
	]

	same-switch-constant?: func [
		constants [wire-constant-initializer!]
		types [wire-type-layout!]
		left right [integer!]
		return: [logic!]
		/local left-type right-type size index [integer!]
	][
		left-type: constant-value constants left WIRE_RSIR_CONSTANT_TYPE_OFFSET
		right-type: constant-value constants right WIRE_RSIR_CONSTANT_TYPE_OFFSET
		if left-type <> right-type [return false]
		size: type-value types left-type WIRE_RSIR_TYPE_SIZE_OFFSET
		index: 0
		while [index < size][
			if (constant-byte constants left index) <> (constant-byte constants right index) [
				return false
			]
			index: index + 1
		]
		true
	]

	verify-terminator: func [
		result [wire-control-flow-result!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		block-id instruction-id [integer!]
		return: [integer!]
		/local opcode base first-operand operand-count ordinary-count first-edge
			status operand-id reference type-id owner-function signature-id
			signature-flags return-type type-kind case-count case-index prior-index
			constant-id prior-constant edge-id expected-kind
			expected-target field actual expected [integer!]
	][
		opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		base: instruction-base scalar instruction-id
		first-operand: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		ordinary-count: ordinary-edge-count control functions block-id
		first-edge: block-value functions block-id
			WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET

		if owned-terminator? opcode [
			status: verify-common-terminator result scalar instruction-id
			if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
		]

		case [
			opcode = WIRE_OPCODE_JUMP [
				if operand-count <> 1 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				status: verify-operand-shape result scalar first-operand WIRE_OPERAND_KIND_BLOCK
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				if ordinary-count <> 1 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				expected-target: operand-value scalar first-operand
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				edge-id: first-edge
				if (edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET)
					<> WIRE_EDGE_KIND_NORMAL
				[
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((edge-base control edge-id) + WIRE_RSIR_EDGE_KIND_OFFSET)
						control/edges-ordinal
				]
				if (edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					<> expected-target
				[
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
			]

			opcode = WIRE_OPCODE_BRANCH [
				if operand-count <> 3 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				status: verify-operand-shape result scalar first-operand WIRE_OPERAND_KIND_VALUE
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				status: verify-operand-shape result scalar (first-operand + 1)
					WIRE_OPERAND_KIND_BLOCK
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				status: verify-operand-shape result scalar (first-operand + 2)
					WIRE_OPERAND_KIND_BLOCK
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				reference: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				type-id: value-value scalar reference WIRE_RSIR_VALUE_TYPE_OFFSET
				if (type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET)
					<> WIRE_TYPE_KIND_LOGIC
				[
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_BRANCH_TYPE
						((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				if ordinary-count <> 2 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				case-index: 0
				while [case-index < 2][
					edge-id: first-edge + case-index
					expected-kind: either case-index = 0 [
						WIRE_EDGE_KIND_TRUE
					][WIRE_EDGE_KIND_FALSE]
					expected-target: operand-value scalar (first-operand + (case-index + 1))
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET) <> expected-kind [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
							((edge-base control edge-id) + WIRE_RSIR_EDGE_KIND_OFFSET)
							control/edges-ordinal
					]
					if (edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						<> expected-target
					[
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
							((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							control/edges-ordinal
					]
					case-index: case-index + 1
				]
			]

			opcode = WIRE_OPCODE_SWITCH [
				if any [
					operand-count < 4
					((operand-count - 2) // 2) <> 0
				][
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				case-count: (operand-count - 2) / 2
				status: verify-operand-shape result scalar first-operand WIRE_OPERAND_KIND_VALUE
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				case-index: 0
				while [case-index < case-count][
					operand-id: first-operand + (1 + (case-index * 2))
					status: verify-operand-shape result scalar operand-id WIRE_OPERAND_KIND_CONSTANT
					if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
					status: verify-operand-shape result scalar (operand-id + 1)
						WIRE_OPERAND_KIND_BLOCK
					if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
					case-index: case-index + 1
				]
				status: verify-operand-shape result scalar
					(first-operand + (operand-count - 1)) WIRE_OPERAND_KIND_BLOCK
				if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
				reference: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				type-id: value-value scalar reference WIRE_RSIR_VALUE_TYPE_OFFSET
				unless all [
					(type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
					(type-value types type-id WIRE_RSIR_TYPE_GC_KIND_OFFSET) = WIRE_GC_KIND_NONE
				][
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_SELECTOR_TYPE
						((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				case-index: 0
				while [case-index < case-count][
					operand-id: first-operand + (1 + (case-index * 2))
					constant-id: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (constant-value constants constant-id WIRE_RSIR_CONSTANT_TYPE_OFFSET)
						<> type-id
					[
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_CASE_TYPE
							((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar/operands-ordinal
					]
					prior-index: 0
					while [prior-index < case-index][
						prior-constant: operand-value scalar
							(first-operand + (1 + (prior-index * 2)))
							WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						if same-switch-constant? constants types constant-id prior-constant [
							return set-error result WIRE_CONTROL_FLOW_ERROR_DUPLICATE_SWITCH_CASE
								((operand-base scalar operand-id)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						prior-index: prior-index + 1
					]
					case-index: case-index + 1
				]
				if ordinary-count <> (case-count + 1) [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				case-index: 0
				while [case-index < case-count][
					operand-id: first-operand + (1 + (case-index * 2))
					constant-id: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					expected-target: operand-value scalar (operand-id + 1)
						WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					edge-id: first-edge + case-index
					field: WIRE_RSIR_EDGE_KIND_OFFSET
					actual: edge-value control edge-id field
					expected: WIRE_EDGE_KIND_SWITCH_CASE
					if actual <> expected [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
							((edge-base control edge-id) + field) control/edges-ordinal
					]
					field: WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
					actual: edge-value control edge-id field
					expected: constant-id
					if actual <> expected [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
							((edge-base control edge-id) + field) control/edges-ordinal
					]
					field: WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
					actual: edge-value control edge-id field
					expected: expected-target
					if actual <> expected [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
							((edge-base control edge-id) + field) control/edges-ordinal
					]
					case-index: case-index + 1
				]
				edge-id: first-edge + case-count
				if (edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET)
					<> WIRE_EDGE_KIND_DEFAULT
				[
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((edge-base control edge-id) + WIRE_RSIR_EDGE_KIND_OFFSET)
						control/edges-ordinal
				]
				expected-target: operand-value scalar (first-operand + (operand-count - 1))
					WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				if (edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					<> expected-target
				[
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((edge-base control edge-id) + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
			]

			opcode = WIRE_OPCODE_RETURN [
				owner-function: block-value functions block-id WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				signature-id: function-value functions owner-function
					WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
				signature-flags: signature-value functions signature-id
					WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				if (signature-flags and WIRE_FUNCTION_FLAG_NO_RETURN) <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_NO_RETURN
						(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
				return-type: signature-value functions signature-id
					WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
				type-kind: type-value types return-type WIRE_RSIR_TYPE_KIND_OFFSET
				either type-kind = WIRE_TYPE_KIND_VOID [
					if operand-count <> 0 [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
							(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if operand-count <> 1 [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
							(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
							scalar/instructions-ordinal
					]
					status: verify-operand-shape result scalar first-operand WIRE_OPERAND_KIND_VALUE
					if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
					reference: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (value-value scalar reference WIRE_RSIR_VALUE_TYPE_OFFSET) <> return-type [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_RETURN_TYPE
							((operand-base scalar first-operand)
								+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar/operands-ordinal
					]
				]
				if ordinary-count <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]

			opcode = WIRE_OPCODE_UNREACHABLE [
				if operand-count <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				if ordinary-count <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]

			opcode = WIRE_OPCODE_THROW [
				if ordinary-count <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]

			true [
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR
					(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]
		]
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]

	has-ordinary-incoming?: func [
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

	clear-marks: func [
		workspace [byte-ptr!]
		first-block block-count [integer!]
		/local block-id [integer!] mark [byte-ptr!]
	][
		block-id: first-block
		while [block-id < (first-block + block-count)][
			mark: workspace + (block-id - 1)
			mark/1: as byte! 0
			block-id: block-id + 1
		]
	]

	mark-reachable: func [
		functions [wire-function-signature!]
		control [wire-control-flow!]
		workspace [byte-ptr!]
		function-id removed [integer!]
		/local first-block block-count entry-block block-id edge-id source target
			kind changed [integer!] mark source-mark target-mark [byte-ptr!]
	][
		first-block: function-value functions function-id WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
		block-count: function-value functions function-id WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
		entry-block: function-value functions function-id WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
		clear-marks workspace first-block block-count
		block-id: first-block
		while [block-id < (first-block + block-count)][
			if all [
				block-id <> removed
				any [block-id = entry-block not has-ordinary-incoming? control block-id]
			][
				mark: workspace + (block-id - 1)
				mark/1: as byte! 1
			]
			block-id: block-id + 1
		]
		changed: 1
		while [changed <> 0][
			changed: 0
			edge-id: 1
			while [edge-id <= control/edge-count][
				kind: edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
				if ordinary-edge? kind [
					source: edge-value control edge-id WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
					target: edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
					if all [
						source <> removed
						target <> removed
						(block-value functions source WIRE_RSIR_BLOCK_FUNCTION_OFFSET) = function-id
					][
						source-mark: workspace + (source - 1)
						target-mark: workspace + (target - 1)
						if all [
							source-mark/1 = as byte! 1
							target-mark/1 = as byte! 0
						][
							target-mark/1: as byte! 1
							changed: 1
						]
					]
				]
				edge-id: edge-id + 1
			]
		]
	]

	verify-reachability: func [
		result [wire-control-flow-result!]
		functions [wire-function-signature!]
		control [wire-control-flow!]
		workspace [byte-ptr!]
		return: [integer!]
		/local function-id first-block count block-id [integer!] mark [byte-ptr!]
	][
		function-id: 1
		while [function-id <= functions/function-count][
			mark-reachable functions control workspace function-id 0
			first-block: function-value functions function-id WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			count: function-value functions function-id WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-id: first-block
			while [block-id < (first-block + count)][
				mark: workspace + (block-id - 1)
				if mark/1 = as byte! 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_UNROOTED_BLOCK
						block-base functions block-id functions/blocks-ordinal
				]
				block-id: block-id + 1
			]
			function-id: function-id + 1
		]
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]

	block-dominates?: func [
		functions [wire-function-signature!]
		control [wire-control-flow!]
		workspace [byte-ptr!]
		function-id definition-block use-block [integer!]
		return: [logic!]
		/local mark [byte-ptr!]
	][
		mark-reachable functions control workspace function-id definition-block
		mark: workspace + (use-block - 1)
		mark/1 = as byte! 0
	]

	verify-value-uses: func [
		result [wire-control-flow-result!]
		functions [wire-function-signature!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		workspace [byte-ptr!]
		return: [integer!]
		/local instruction-id use-block function-id first-operand operand-count
			operand-id kind value-id definition-kind definition-id definition-block
			base [integer!]
	][
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			use-block: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			function-id: block-value functions use-block WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			first-operand: instruction-value scalar instruction-id
				WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value scalar instruction-id
				WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			operand-id: first-operand
			while [operand-count > 0][
				kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
				if kind = WIRE_OPERAND_KIND_VALUE [
					value-id: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					definition-kind: value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
					if definition-kind = WIRE_VALUE_DEFINITION_INSTRUCTION [
						definition-id: value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
						definition-block: instruction-value scalar definition-id
							WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
						base: operand-base scalar operand-id
						either definition-block = use-block [
							if definition-id >= instruction-id [
								return set-error result WIRE_CONTROL_FLOW_ERROR_USE_BEFORE_DEFINITION
									(base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar/operands-ordinal
							]
						][
							unless block-dominates? functions control workspace function-id
								definition-block use-block
							[
								return set-error result WIRE_CONTROL_FLOW_ERROR_VALUE_NOT_DOMINATING
									(base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar/operands-ordinal
							]
						]
					]
				]
				operand-id: operand-id + 1
				operand-count: operand-count - 1
			]
			instruction-id: instruction-id + 1
		]
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]

	copy-view: func [destination source [wire-control-flow!]][
		destination/edges: source/edges
		destination/edge-count: source/edge-count
		destination/edge-record-size: source/edge-record-size
		destination/edges-offset: source/edges-offset
		destination/edges-ordinal: source/edges-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
		result [wire-control-flow-result!]
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
			verified-scalar [wire-scalar-operation!]
			verified-control [wire-control-flow!]
			edges [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative record-index record-base edge-id source target kind
			selector flags source-function target-function cursor block-id first count
			finish index seen-exception instruction-id opcode [integer!]
	][
		if null? result [return WIRE_CONTROL_FLOW_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_CONTROL_FLOW_ERROR_SUCCESS
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
		][
			return set-error result WIRE_CONTROL_FLOW_ERROR_INVALID_ARGUMENTS 0 0
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
		verified-scalar: declare wire-scalar-operation!
		verified-control: declare wire-control-flow!
		status: wire-scalar-operation-reader/verify data size scalar-result
			verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar
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
			return set-error result WIRE_CONTROL_FLOW_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		edges: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_EDGES edges
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONTROL_FLOW_ERROR_INVALID_SCALAR_OPERATION
				WIRE_HEADER_SIZE 0
		]
		if edges/flags <> 0 [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SECTION_FLAGS
				section-flags-offset edges edges/ordinal
		]
		verified-control/edges: edges/data
		verified-control/edge-count: edges/record-count
		verified-control/edge-record-size: edges/record-size
		verified-control/edges-offset: edges/offset
		verified-control/edges-ordinal: edges/ordinal

		; Decode every signed edge scalar before following a reference.
		record-index: 0
		while [record-index < edges/record-count][
			record: edges/data + (record-index * WIRE_RSIR_EDGE_SIZE)
			bad-relative: first-bad-scalar record 6
			if bad-relative >= 0 [
				return set-error result WIRE_CONTROL_FLOW_ERROR_SCALAR_RANGE
					((edges/offset + (record-index * WIRE_RSIR_EDGE_SIZE)) + bad-relative)
					edges/ordinal
			]
			record-index: record-index + 1
		]

		edge-id: 1
		while [edge-id <= verified-control/edge-count][
			record-base: edge-base verified-control edge-id
			kind: edge-value verified-control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
			unless all [kind >= WIRE_EDGE_KIND_NORMAL kind <= WIRE_EDGE_KIND_EXCEPTION][
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_KIND
					(record-base + WIRE_RSIR_EDGE_KIND_OFFSET) verified-control/edges-ordinal
			]
			flags: edge-value verified-control edge-id WIRE_RSIR_EDGE_FLAGS_OFFSET
			if flags <> 0 [
				return set-error result WIRE_CONTROL_FLOW_ERROR_NONZERO_EDGE_FLAGS
					(record-base + WIRE_RSIR_EDGE_FLAGS_OFFSET) verified-control/edges-ordinal
			]
			source: edge-value verified-control edge-id WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
			if any [source <= 0 source > verified-functions/block-count][
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SOURCE
					(record-base + WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET)
					verified-control/edges-ordinal
			]
			target: edge-value verified-control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
			if any [target <= 0 target > verified-functions/block-count][
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_TARGET
					(record-base + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					verified-control/edges-ordinal
			]
			source-function: block-value verified-functions source WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			target-function: block-value verified-functions target WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			if source-function <> target-function [
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_FUNCTION
					(record-base + WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					verified-control/edges-ordinal
			]
			selector: edge-value verified-control edge-id
				WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
			either kind = WIRE_EDGE_KIND_SWITCH_CASE [
				if any [selector <= 0 selector > verified-constants/constant-count][
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SELECTOR
						(record-base + WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET)
						verified-control/edges-ordinal
				]
			][
				if selector <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SELECTOR
						(record-base + WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET)
						verified-control/edges-ordinal
				]
			]
			edge-id: edge-id + 1
		]

		; Blocks partition edges; deferred exception edges form a suffix.
		cursor: 1
		block-id: 1
		while [block-id <= verified-functions/block-count][
			record-base: block-base verified-functions block-id
			first: block-value verified-functions block-id
				WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
			count: block-value verified-functions block-id
				WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
			either count = 0 [
				if first <> 0 [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_BLOCK_EDGE_RANGE
						(record-base + WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET)
						verified-functions/blocks-ordinal
				]
			][
				finish: wire-container-reader/checked-add first (count - 1)
				if any [
					first <> cursor
					finish < 0
					finish > verified-control/edge-count
				][
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_BLOCK_EDGE_RANGE
						(record-base + WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET)
						verified-functions/blocks-ordinal
				]
				index: 0
				seen-exception: 0
				while [index < count][
					edge-id: first + index
					if (edge-value verified-control edge-id
						WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET) <> block-id [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SOURCE
							((edge-base verified-control edge-id)
								+ WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET)
							verified-control/edges-ordinal
					]
					if (edge-value verified-control edge-id WIRE_RSIR_EDGE_ORDINAL_OFFSET)
						<> index [
						return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_ORDINAL
							((edge-base verified-control edge-id)
								+ WIRE_RSIR_EDGE_ORDINAL_OFFSET)
							verified-control/edges-ordinal
					]
					kind: edge-value verified-control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
					either kind = WIRE_EDGE_KIND_EXCEPTION [
						seen-exception: 1
					][
						if seen-exception <> 0 [
							return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_KIND
								((edge-base verified-control edge-id)
									+ WIRE_RSIR_EDGE_KIND_OFFSET)
								verified-control/edges-ordinal
						]
					]
					index: index + 1
				]
				cursor: finish + 1
			]
			block-id: block-id + 1
		]
		if cursor <> (verified-control/edge-count + 1) [
			return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_COVERAGE
				(verified-control/edges-offset
					+ ((cursor - 1) * WIRE_RSIR_EDGE_SIZE))
				verified-control/edges-ordinal
		]

		; Every block is nonempty and has one final terminator.
		block-id: 1
		while [block-id <= verified-functions/block-count][
			record-base: block-base verified-functions block-id
			first: block-value verified-functions block-id WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value verified-functions block-id WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			if count = 0 [
				return set-error result WIRE_CONTROL_FLOW_ERROR_EMPTY_BLOCK
					(record-base + WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET)
					verified-functions/blocks-ordinal
			]
			instruction-id: first
			while [instruction-id < (first + count - 1)][
				opcode: instruction-value verified-scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				if terminator? opcode [
					return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_POSITION
						((instruction-base verified-scalar instruction-id)
							+ WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						verified-scalar/instructions-ordinal
				]
				instruction-id: instruction-id + 1
			]
			instruction-id: first + count - 1
			opcode: instruction-value verified-scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			unless terminator? opcode [
				return set-error result WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR
					((instruction-base verified-scalar instruction-id)
						+ WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					verified-scalar/instructions-ordinal
			]
			block-id: block-id + 1
		]

		block-id: 1
		while [block-id <= verified-functions/block-count][
			first: block-value verified-functions block-id WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value verified-functions block-id WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			instruction-id: first + count - 1
			status: verify-terminator result verified-types verified-functions
				verified-constants verified-scalar verified-control block-id instruction-id
			if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
			block-id: block-id + 1
		]

		; Scratch is needed only for graph closure and dominance; wire errors win first.
		if workspace-size < verified-functions/block-count [
			return set-error result WIRE_CONTROL_FLOW_ERROR_INSUFFICIENT_WORKSPACE 0 0
		]

		status: verify-reachability result verified-functions verified-control workspace
		if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]
		status: verify-value-uses result verified-functions verified-scalar verified-control workspace
		if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [return status]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		wire-scalar-operation-reader/copy-symbols symbols verified-symbols
		wire-scalar-operation-reader/copy-constants constants verified-constants
		wire-scalar-operation-reader/copy-view scalar verified-scalar
		copy-view control verified-control
		WIRE_CONTROL_FLOW_ERROR_SUCCESS
	]
]
