Red/System [
	Title: "Hybrid compiler RSIR explicit-stack verifier"
	File:  %wire-stack.reds
]

#include %wire-exception.reds

wire-stack-result!: alias struct! [
	error                      [integer!]
	exception-error            [integer!]
	subroutine-error           [integer!]
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

wire-stack-state!: alias struct! [
	flags       [integer!]
	kind        [integer!]
	depth       [integer!]
	push-id     [integer!]
	saved-kind  [integer!]
	saved-depth [integer!]
]

wire-stack-count!: alias struct! [
	known [integer!]
	value [integer!]
]

wire-stack-reader: context [
	state-size: 24
	state-flags-offset: 0
	state-kind-offset: 4
	state-depth-offset: 8
	state-push-id-offset: 12
	state-saved-kind-offset: 16
	state-saved-depth-offset: 20
	state-seen-flag: 1
	state-mismatch-flag: 2
	state-exact: 1
	state-dynamic: 2
	max-depth: 7FFFFFFFh
	stack-effects: WIRE_EFFECT_FLAG_STACK
	opaque-stack-effects: WIRE_EFFECT_FLAG_STACK or WIRE_EFFECT_FLAG_OPAQUE

	set-error: func [
		result [wire-stack-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
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

	constant-value: func [
		constants [wire-constant-initializer!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 constants/constants
			(((id - 1) * WIRE_RSIR_CONSTANT_SIZE) + field-offset)
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

	edge-value: func [
		control [wire-control-flow!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 control/edges
			(((id - 1) * WIRE_RSIR_EDGE_SIZE) + field-offset)
	]

	call-value: func [
		calls [wire-call-abi!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 calls/calls
			(((id - 1) * WIRE_RSIR_CALL_SIZE) + field-offset)
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

	value-base: func [
		scalar [wire-scalar-operation!]
		id [integer!]
		return: [integer!]
	][
		scalar/values-offset + ((id - 1) * WIRE_RSIR_VALUE_SIZE)
	]

	block-base: func [
		functions [wire-function-signature!]
		id [integer!]
		return: [integer!]
	][
		functions/blocks-offset + ((id - 1) * WIRE_RSIR_BLOCK_SIZE)
	]

	plain-signed-i32?: func [
		types [wire-type-layout!]
		type-id [integer!]
		return: [logic!]
	][
		all [
			type-id > 0
			type-id <= types/type-count
			(type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET)
				= WIRE_TYPE_KIND_INTEGER
			(type-value types type-id WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET)
				= WIRE_TYPE_FLAG_SIGNED
		]
	]

	stack-pointer-type?: func [
		types [wire-type-layout!]
		type-id [integer!]
		return: [logic!]
		/local detail-id [integer!]
	][
		if any [type-id <= 0 type-id > types/type-count][return false]
		unless (type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET)
			= WIRE_TYPE_KIND_POINTER [return false]
		detail-id: type-value types type-id WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
		plain-signed-i32? types detail-id
	]

	pushable-type?: func [
		types [wire-type-layout!]
		type-id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		if any [type-id <= 0 type-id > types/type-count][return false]
		kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
		any [
			kind = WIRE_TYPE_KIND_LOGIC
			kind = WIRE_TYPE_KIND_INTEGER
			kind = WIRE_TYPE_KIND_FLOAT
			kind = WIRE_TYPE_KIND_POINTER
			kind = WIRE_TYPE_KIND_FUNCTION
		]
	]

	operand-type: func [
		scalar [wire-scalar-operation!]
		constants [wire-constant-initializer!]
		operand-id [integer!]
		return: [integer!]
		/local kind reference [integer!]
	][
		kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = WIRE_OPERAND_KIND_VALUE [
				value-value scalar reference WIRE_RSIR_VALUE_TYPE_OFFSET
			]
			kind = WIRE_OPERAND_KIND_CONSTANT [
				constant-value constants reference WIRE_RSIR_CONSTANT_TYPE_OFFSET
			]
			true [0]
		]
	]

	known-i32-constant: func [
		constants [wire-constant-initializer!]
		constant-id [integer!]
		output [wire-stack-count!]
		/local kind size relative [integer!]
	][
		output/known: 0
		output/value: 0
		kind: constant-value constants constant-id WIRE_RSIR_CONSTANT_KIND_OFFSET
		if kind = WIRE_CONSTANT_KIND_ZERO [
			output/known: 1
			exit
		]
		unless kind = WIRE_CONSTANT_KIND_SCALAR [exit]
		size: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		unless size = 4 [exit]
		relative: constant-value constants constant-id
			WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		output/value: wire-container-reader/read-le32 constants/constant-data relative
		output/known: 1
	]

	known-count: func [
		scalar [wire-scalar-operation!]
		constants [wire-constant-initializer!]
		operand-id [integer!]
		output [wire-stack-count!]
		/local kind reference definition-kind definition-id opcode first
			operand-kind [integer!]
	][
		output/known: 0
		output/value: 0
		kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		if kind = WIRE_OPERAND_KIND_CONSTANT [
			known-i32-constant constants reference output
			exit
		]
		unless kind = WIRE_OPERAND_KIND_VALUE [exit]
		definition-kind: value-value scalar reference WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
		unless definition-kind = WIRE_VALUE_DEFINITION_INSTRUCTION [exit]
		definition-id: value-value scalar reference WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		opcode: instruction-value scalar definition-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless opcode = WIRE_OPCODE_CONSTANT [exit]
		unless (instruction-value scalar definition-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) = 1 [exit]
		first: instruction-value scalar definition-id WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-kind: operand-value scalar first WIRE_RSIR_OPERAND_KIND_OFFSET
		unless operand-kind = WIRE_OPERAND_KIND_CONSTANT [exit]
		known-i32-constant constants
			(operand-value scalar first WIRE_RSIR_OPERAND_REFERENCE_OFFSET) output
	]

	write-state-word: func [
		data [byte-ptr!]
		offset value [integer!]
		/local p [byte-ptr!]
	][
		p: data + offset
		p/1: as byte! value
		p/2: as byte! (value >>> 8)
		p/3: as byte! (value >>> 16)
		p/4: as byte! (value >>> 24)
	]

	state-address: func [
		workspace [byte-ptr!]
		block-id [integer!]
		return: [byte-ptr!]
	][
		workspace + ((block-id - 1) * state-size)
	]

	load-state: func [
		workspace [byte-ptr!]
		block-id [integer!]
		state [wire-stack-state!]
		/local record [byte-ptr!]
	][
		record: state-address workspace block-id
		state/flags: wire-container-reader/read-le32 record state-flags-offset
		state/kind: wire-container-reader/read-le32 record state-kind-offset
		state/depth: wire-container-reader/read-le32 record state-depth-offset
		state/push-id: wire-container-reader/read-le32 record state-push-id-offset
		state/saved-kind: wire-container-reader/read-le32 record state-saved-kind-offset
		state/saved-depth: wire-container-reader/read-le32 record state-saved-depth-offset
	]

	store-state: func [
		workspace [byte-ptr!]
		block-id [integer!]
		state [wire-stack-state!]
		/local record [byte-ptr!]
	][
		record: state-address workspace block-id
		write-state-word record state-flags-offset state/flags
		write-state-word record state-kind-offset state/kind
		write-state-word record state-depth-offset state/depth
		write-state-word record state-push-id-offset state/push-id
		write-state-word record state-saved-kind-offset state/saved-kind
		write-state-word record state-saved-depth-offset state/saved-depth
	]

	copy-state: func [destination source [wire-stack-state!]][
		destination/flags: source/flags
		destination/kind: source/kind
		destination/depth: source/depth
		destination/push-id: source/push-id
		destination/saved-kind: source/saved-kind
		destination/saved-depth: source/saved-depth
	]

	initialize-state: func [state [wire-stack-state!]][
		state/flags: state-seen-flag
		state/kind: state-exact
		state/depth: 0
		state/push-id: 0
		state/saved-kind: state-exact
		state/saved-depth: 0
	]

	join-state: func [
		target incoming [wire-stack-state!]
		return: [integer!]
		/local changed [integer!]
	][
		if (target/flags and state-seen-flag) = 0 [
			copy-state target incoming
			return 1
		]
		if (target/flags and state-mismatch-flag) <> 0 [return 0]
		if any [
			(incoming/flags and state-mismatch-flag) <> 0
			target/push-id <> incoming/push-id
		][
			target/flags: target/flags or state-mismatch-flag
			return 1
		]
		changed: 0
		if all [
			target/kind = state-exact
			any [incoming/kind = state-dynamic target/depth <> incoming/depth]
		][
			target/kind: state-dynamic
			target/depth: 0
			changed: 1
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
			changed: 1
		]
		changed
	]

	clear-states: func [
		workspace [byte-ptr!]
		size [integer!]
		/local cursor finish [byte-ptr!]
	][
		cursor: workspace
		finish: workspace + size
		while [cursor < finish][
			cursor/1: as byte! 0
			cursor: cursor + 1
		]
	]

	seed-entry: func [
		workspace [byte-ptr!]
		block-id [integer!]
		/local target seed [wire-stack-state!] changed [integer!]
	][
		target: declare wire-stack-state!
		seed: declare wire-stack-state!
		load-state workspace block-id target
		initialize-state seed
		changed: join-state target seed
		if changed <> 0 [store-state workspace block-id target]
	]

	adjust-depth: func [
		result [wire-stack-result!]
		state [wire-stack-state!]
		delta instruction-id [integer!]
		scalar [wire-scalar-operation!]
		analysis? [logic!]
		return: [integer!]
		/local amount base [integer!]
	][
		if state/kind = state-dynamic [return WIRE_STACK_ERROR_SUCCESS]
		base: instruction-base scalar instruction-id
		either delta >= 0 [
			if state/depth > (max-depth - delta) [
				either analysis? [
					state/kind: state-dynamic
					state/depth: 0
					return WIRE_STACK_ERROR_SUCCESS
				][
					return set-error result WIRE_STACK_ERROR_SCALAR_RANGE
						(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
			]
			state/depth: state/depth + delta
		][
			amount: 0 - delta
			if state/depth < amount [
				either analysis? [
					state/kind: state-dynamic
					state/depth: 0
					return WIRE_STACK_ERROR_SUCCESS
				][
					return set-error result WIRE_STACK_ERROR_STACK_UNDERFLOW
						(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
			]
			state/depth: state/depth - amount
		]
		WIRE_STACK_ERROR_SUCCESS
	]

	custom-call-count-operand: func [
		calls [wire-call-abi!]
		functions [wire-function-signature!]
		instruction-id [integer!]
		return: [integer!]
		/local call-id signature-id flags [integer!]
	][
		call-id: wire-exception-reader/call-id-for-instruction calls instruction-id
		if call-id = 0 [return 0]
		signature-id: call-value calls call-id WIRE_RSIR_CALL_SIGNATURE_OFFSET
		flags: signature-value functions signature-id WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		if (flags and WIRE_FUNCTION_FLAG_CUSTOM) = 0 [return 0]
		call-value calls call-id WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
	]

	transfer-instruction: func [
		result [wire-stack-result!]
		functions [wire-function-signature!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		calls [wire-call-abi!]
		state [wire-stack-state!]
		instruction-id [integer!]
		analysis? [logic!]
		return: [integer!]
		/local count [wire-stack-count!]
			opcode operand-id status base [integer!]
	][
		count: declare wire-stack-count!
		opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		case [
			opcode = WIRE_OPCODE_STACK_ALLOC [
				operand-id: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				known-count scalar constants operand-id count
				either count/known = 0 [
					state/kind: state-dynamic
					state/depth: 0
				][
					status: adjust-depth result state count/value instruction-id scalar analysis?
					if status <> WIRE_STACK_ERROR_SUCCESS [return status]
				]
			]
			opcode = WIRE_OPCODE_STACK_FREE [
				operand-id: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				known-count scalar constants operand-id count
				either count/known = 0 [
					state/kind: state-dynamic
					state/depth: 0
				][
					status: adjust-depth result state (0 - count/value)
						instruction-id scalar analysis?
					if status <> WIRE_STACK_ERROR_SUCCESS [return status]
				]
			]
			opcode = WIRE_OPCODE_STACK_PUSH [
				status: adjust-depth result state 1 instruction-id scalar analysis?
				if status <> WIRE_STACK_ERROR_SUCCESS [return status]
			]
			opcode = WIRE_OPCODE_STACK_POP [
				status: adjust-depth result state -1 instruction-id scalar analysis?
				if status <> WIRE_STACK_ERROR_SUCCESS [return status]
			]
			opcode = WIRE_OPCODE_PUSH_ALL [
				if state/push-id <> 0 [
					unless analysis? [
						base: instruction-base scalar instruction-id
						return set-error result WIRE_STACK_ERROR_NESTED_PUSH_ALL
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					return WIRE_STACK_ERROR_SUCCESS
				]
				state/push-id: instruction-id
				state/saved-kind: state/kind
				state/saved-depth: state/depth
				state/kind: state-exact
				state/depth: 0
			]
			opcode = WIRE_OPCODE_POP_ALL [
				if state/push-id = 0 [
					unless analysis? [
						base: instruction-base scalar instruction-id
						return set-error result WIRE_STACK_ERROR_UNMATCHED_POP_ALL
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					return WIRE_STACK_ERROR_SUCCESS
				]
				if any [state/kind <> state-exact state/depth <> 0][
					unless analysis? [
						base: instruction-base scalar instruction-id
						return set-error result WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
				state/kind: state/saved-kind
				state/depth: state/saved-depth
				state/push-id: 0
				state/saved-kind: state-exact
				state/saved-depth: 0
			]
			opcode = WIRE_OPCODE_CALL [
				operand-id: custom-call-count-operand calls functions instruction-id
				if operand-id <> 0 [
					known-count scalar constants operand-id count
					either count/known = 0 [
						state/kind: state-dynamic
						state/depth: 0
					][
						status: adjust-depth result state (0 - count/value)
							instruction-id scalar analysis?
						if status <> WIRE_STACK_ERROR_SUCCESS [return status]
					]
				]
			]
			opcode = WIRE_OPCODE_SUBROUTINE_RETURN [
				unless analysis? [
					base: instruction-base scalar instruction-id
					if state/push-id <> 0 [
						return set-error result WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					if any [state/kind <> state-exact state/depth <> 0][
						return set-error result
							WIRE_STACK_ERROR_BAD_SUBROUTINE_STACK_DEPTH
							(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
			]
			true []
		]
		WIRE_STACK_ERROR_SUCCESS
	]

	validate-instruction-shapes: func [
		result [wire-stack-result!]
		types [wire-type-layout!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		return: [integer!]
		/local count [wire-stack-count!]
			instruction-id opcode base subopcode flags effects expected-effects
			alias-kind alias-id expected-operands expected-results operand-count
			result-count first-operand operand-kind auxiliary type-id first-result
			error-field [integer!]
	][
		count: declare wire-stack-count!
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if all [opcode >= WIRE_OPCODE_STACK_ALLOC opcode <= WIRE_OPCODE_POP_ALL][
				base: instruction-base scalar instruction-id
				subopcode: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
				either opcode = WIRE_OPCODE_STACK_ALLOC [
					unless any [
						subopcode = WIRE_STACK_ALLOCATION_MODE_UNINITIALIZED
						subopcode = WIRE_STACK_ALLOCATION_MODE_ZEROED
					][
						return set-error result WIRE_STACK_ERROR_BAD_SUBOPCODE
							(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if subopcode <> 0 [
						return set-error result WIRE_STACK_ERROR_BAD_SUBOPCODE
							(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]
				flags: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
				if flags <> 0 [
					return set-error result WIRE_STACK_ERROR_BAD_INSTRUCTION_FLAGS
						(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				effects: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				expected-effects: either any [
					opcode = WIRE_OPCODE_PUSH_ALL
					opcode = WIRE_OPCODE_POP_ALL
				][opaque-stack-effects][stack-effects]
				if effects <> expected-effects [
					return set-error result WIRE_STACK_ERROR_BAD_EFFECTS
						(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				alias-kind: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				alias-id: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
				if any [alias-kind <> WIRE_ALIAS_KIND_NONE alias-id <> 0][
					error-field: either alias-kind <> WIRE_ALIAS_KIND_NONE [
						WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
					][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
					return set-error result WIRE_STACK_ERROR_BAD_ALIAS
						(base + error-field)
						scalar/instructions-ordinal
				]

				expected-operands: case [
					any [
						opcode = WIRE_OPCODE_STACK_ALLOC
						opcode = WIRE_OPCODE_STACK_FREE
						opcode = WIRE_OPCODE_STACK_PUSH
					][1]
					true [0]
				]
				expected-results: either any [
					opcode = WIRE_OPCODE_STACK_ALLOC
					opcode = WIRE_OPCODE_STACK_POP
				][1][0]
				operand-count: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
				if operand-count <> expected-operands [
					return set-error result WIRE_STACK_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				result-count: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
				if result-count <> expected-results [
					return set-error result WIRE_STACK_ERROR_BAD_RESULT_COUNT
						(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
						scalar/instructions-ordinal
				]

				if expected-operands = 1 [
					first-operand: instruction-value scalar instruction-id
						WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
					operand-kind: operand-value scalar first-operand WIRE_RSIR_OPERAND_KIND_OFFSET
					unless any [
						operand-kind = WIRE_OPERAND_KIND_VALUE
						operand-kind = WIRE_OPERAND_KIND_CONSTANT
					][
						return set-error result WIRE_STACK_ERROR_BAD_OPERAND_KIND
							((operand-base scalar first-operand) + WIRE_RSIR_OPERAND_KIND_OFFSET)
							scalar/operands-ordinal
					]
					auxiliary: operand-value scalar first-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					if auxiliary <> 0 [
						return set-error result WIRE_STACK_ERROR_NONZERO_OPERAND_AUXILIARY
							((operand-base scalar first-operand)
								+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
							scalar/operands-ordinal
					]
					type-id: operand-type scalar constants first-operand
					if any [
						opcode = WIRE_OPCODE_STACK_ALLOC
						opcode = WIRE_OPCODE_STACK_FREE
					][
						unless plain-signed-i32? types type-id [
							return set-error result WIRE_STACK_ERROR_BAD_COUNT_TYPE
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						known-count scalar constants first-operand count
						if all [count/known <> 0 count/value < 0][
							return set-error result WIRE_STACK_ERROR_NEGATIVE_COUNT
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
					if opcode = WIRE_OPCODE_STACK_PUSH [
						unless pushable-type? types type-id [
							return set-error result WIRE_STACK_ERROR_BAD_PUSH_TYPE
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
				]

				if expected-results = 1 [
					first-result: instruction-value scalar instruction-id
						WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
					type-id: value-value scalar first-result WIRE_RSIR_VALUE_TYPE_OFFSET
					if all [
						opcode = WIRE_OPCODE_STACK_ALLOC
						not stack-pointer-type? types type-id
					][
						return set-error result WIRE_STACK_ERROR_BAD_ALLOC_TYPE
							((value-base scalar first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
							scalar/values-ordinal
					]
					if all [
						opcode = WIRE_OPCODE_STACK_POP
						not plain-signed-i32? types type-id
					][
						return set-error result WIRE_STACK_ERROR_BAD_POP_TYPE
							((value-base scalar first-result) + WIRE_RSIR_VALUE_TYPE_OFFSET)
							scalar/values-ordinal
					]
				]
			]
			instruction-id: instruction-id + 1
		]
		WIRE_STACK_ERROR_SUCCESS
	]

	simulate-block: func [
		result [wire-stack-result!]
		functions [wire-function-signature!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		input output [wire-stack-state!]
		block-id [integer!]
		analysis? [logic!]
		return: [integer!]
		/local first count instruction-id status ordinary-count terminator base [integer!]
	][
		copy-state output input
		first: block-value functions block-id WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
		count: block-value functions block-id WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
		instruction-id: first
		while [instruction-id < (first + count)][
			status: transfer-instruction result functions constants scalar calls output
				instruction-id analysis?
			if status <> WIRE_STACK_ERROR_SUCCESS [return status]
			instruction-id: instruction-id + 1
		]
		unless analysis? [
			ordinary-count: wire-exception-reader/ordinary-edge-count
				functions control block-id
			if all [output/push-id <> 0 ordinary-count = 0][
				terminator: (first + count) - 1
				base: instruction-base scalar terminator
				return set-error result WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
					(base + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar/instructions-ordinal
			]
		]
		WIRE_STACK_ERROR_SUCCESS
	]

	verify-states: func [
		result [wire-stack-result!]
		functions [wire-function-signature!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		control [wire-control-flow!]
		calls [wire-call-abi!]
		subroutines [wire-subroutine!]
		workspace [byte-ptr!]
		required-size [integer!]
		return: [integer!]
		/local state output target-state [wire-stack-state!]
			block-id function-id subroutine-id entry changed status first-edge
			edge-count edge-id kind target joined [integer!]
	][
		state: declare wire-stack-state!
		output: declare wire-stack-state!
		target-state: declare wire-stack-state!
		clear-states workspace required-size

		block-id: 1
		while [block-id <= functions/block-count][
			unless wire-exception-reader/block-has-ordinary-incoming? control block-id [
				seed-entry workspace block-id
			]
			block-id: block-id + 1
		]
		function-id: 1
		while [function-id <= functions/function-count][
			entry: function-value functions function-id WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
			seed-entry workspace entry
			function-id: function-id + 1
		]
		subroutine-id: 1
		while [subroutine-id <= subroutines/subroutine-count][
			entry: wire-subroutine-reader/subroutine-value subroutines subroutine-id
				WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
			seed-entry workspace entry
			subroutine-id: subroutine-id + 1
		]

		changed: 1
		while [changed <> 0][
			changed: 0
			block-id: 1
			while [block-id <= functions/block-count][
				load-state workspace block-id state
				if all [
					(state/flags and state-seen-flag) <> 0
					(state/flags and state-mismatch-flag) = 0
				][
					status: simulate-block result functions constants scalar control calls
						state output block-id true
					if status <> WIRE_STACK_ERROR_SUCCESS [return status]
					first-edge: block-value functions block-id
						WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
					edge-count: block-value functions block-id
						WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
					edge-id: first-edge
					while [edge-count > 0][
						kind: edge-value control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
						if wire-exception-reader/ordinary-edge? kind [
							target: edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
							load-state workspace target target-state
							joined: join-state target-state output
							if joined <> 0 [
								store-state workspace target target-state
								changed: 1
							]
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
			load-state workspace block-id state
			if (state/flags and state-mismatch-flag) <> 0 [
				return set-error result WIRE_STACK_ERROR_STACK_STATE_MISMATCH
					(block-base functions block-id) functions/blocks-ordinal
			]
			block-id: block-id + 1
		]
		block-id: 1
		while [block-id <= functions/block-count][
			load-state workspace block-id state
			if (state/flags and state-seen-flag) <> 0 [
				status: simulate-block result functions constants scalar control calls
					state output block-id false
				if status <> WIRE_STACK_ERROR_SUCCESS [return status]
			]
			block-id: block-id + 1
		]
		WIRE_STACK_ERROR_SUCCESS
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
		result [wire-stack-result!]
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
		subroutines [wire-subroutine!]
		exceptions [wire-exception!]
		return: [integer!]
		/local exception-result [wire-exception-result!]
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
			verified-subroutines [wire-subroutine!]
			verified-exceptions [wire-exception!]
			status required-size [integer!]
	][
		if null? result [return WIRE_STACK_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_STACK_ERROR_SUCCESS
		result/exception-error: WIRE_EXCEPTION_ERROR_SUCCESS
		result/subroutine-error: WIRE_SUBROUTINE_ERROR_SUCCESS
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
			null? subroutines
			null? exceptions
		][
			return set-error result WIRE_STACK_ERROR_INVALID_ARGUMENTS 0 0
		]

		exception-result: declare wire-exception-result!
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
		verified-subroutines: declare wire-subroutine!
		verified-exceptions: declare wire-exception!
		status: wire-exception-reader/verify data size workspace workspace-size
			exception-result verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar verified-control verified-calls verified-subroutines
			verified-exceptions
		result/exception-error: status
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
		result/constant-initializer-error: exception-result/constant-initializer-error
		if status <> WIRE_EXCEPTION_ERROR_SUCCESS [
			return set-error result WIRE_STACK_ERROR_INVALID_EXCEPTION
				exception-result/error-offset exception-result/error-section
		]

		status: validate-instruction-shapes result verified-types verified-constants
			verified-scalar
		if status <> WIRE_STACK_ERROR_SUCCESS [return status]
		required-size: wire-container-reader/checked-multiply
			verified-functions/block-count state-size
		if required-size < 0 [
			return set-error result WIRE_STACK_ERROR_SCALAR_RANGE 0 0
		]
		if workspace-size < required-size [
			return set-error result WIRE_STACK_ERROR_INSUFFICIENT_WORKSPACE 0 0
		]
		status: verify-states result verified-functions verified-constants
			verified-scalar verified-control verified-calls verified-subroutines
			workspace required-size
		if status <> WIRE_STACK_ERROR_SUCCESS [return status]

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
		wire-subroutine-reader/copy-view subroutines verified-subroutines
		wire-exception-reader/copy-view exceptions verified-exceptions
		WIRE_STACK_ERROR_SUCCESS
	]
]
