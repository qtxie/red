Red/System [
	Title: "Hybrid compiler RSIR target-intrinsic verifier"
	File:  %wire-target-intrinsic.reds
]

#include %wire-stack.reds

wire-target-intrinsic-result!: alias struct! [
	error                      [integer!]
	stack-error                [integer!]
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

wire-target-intrinsic!: alias struct! [
	target-fragments             [byte-ptr!]
	target-fragment-count        [integer!]
	target-fragment-record-size  [integer!]
	target-fragments-offset      [integer!]
	target-fragments-ordinal     [integer!]
]

wire-target-intrinsic-reader: context [
	port-read-effects:
		(WIRE_EFFECT_FLAG_READ + WIRE_EFFECT_FLAG_VOLATILE)
		+ WIRE_EFFECT_FLAG_MAY_TRAP
	port-write-effects:
		(WIRE_EFFECT_FLAG_WRITE + WIRE_EFFECT_FLAG_VOLATILE)
		+ WIRE_EFFECT_FLAG_MAY_TRAP
	fragment-effects:
		(((WIRE_EFFECT_FLAG_READ + WIRE_EFFECT_FLAG_WRITE)
			+ WIRE_EFFECT_FLAG_MAY_TRAP)
			+ WIRE_EFFECT_FLAG_CONTROL)
			+ WIRE_EFFECT_FLAG_OPAQUE
	opaque-effects: WIRE_EFFECT_FLAG_OPAQUE

	set-error: func [
		result [wire-target-intrinsic-result!]
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

	fragment-value: func [
		view [wire-target-intrinsic!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/target-fragments
			(((id - 1) * WIRE_RSIR_TARGET_FRAGMENT_SIZE) + field-offset)
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

	value-value: func [
		view [wire-scalar-operation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/values
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

	call-value: func [
		calls [wire-call-abi!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 calls/calls
			(((id - 1) * WIRE_RSIR_CALL_SIZE) + field-offset)
	]

	fragment-base: func [
		view [wire-target-intrinsic!]
		id [integer!]
		return: [integer!]
	][
		view/target-fragments-offset
			+ ((id - 1) * WIRE_RSIR_TARGET_FRAGMENT_SIZE)
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

	call-base: func [
		view [wire-call-abi!]
		id [integer!]
		return: [integer!]
	][
		view/calls-offset + ((id - 1) * WIRE_RSIR_CALL_SIZE)
	]

	valid-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [id > 0 id <= types/type-count]
	]

	plain-u8?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		if any [id <= 0 id > types/type-count][return false]
		all [
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
			(type-value types id WIRE_RSIR_TYPE_SIZE_OFFSET) = 1
			(type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET) = 0
		]
	]

	plain-signed-i32?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		if any [id <= 0 id > types/type-count][return false]
		all [
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
			(type-value types id WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET) = WIRE_TYPE_FLAG_SIGNED
		]
	]

	ordinary-pointer-detail: func [
		types [wire-type-layout!]
		id [integer!]
		return: [integer!]
	][
		if any [id <= 0 id > types/type-count][return 0]
		if any [
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) <> WIRE_TYPE_KIND_POINTER
			(type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET) <> 0
		][return 0]
		type-value types id WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
	]

	port-pointee-type: func [
		types [wire-type-layout!]
		pointer-type [integer!]
		return: [integer!]
		/local detail [integer!]
	][
		detail: ordinary-pointer-detail types pointer-type
		if detail = 0 [return 0]
		if any [plain-u8? types detail plain-signed-i32? types detail][return detail]
		0
	]

	pointer-to-u8?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local detail [integer!]
	][
		detail: ordinary-pointer-detail types id
		all [detail <> 0 plain-u8? types detail]
	]

	cpu-register-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local detail [integer!]
	][
		detail: ordinary-pointer-detail types id
		all [detail <> 0 plain-signed-i32? types detail]
	]

	fragment-return-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		if any [id <= 0 id > types/type-count][return false]
		kind: type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
		any [
			kind = WIRE_TYPE_KIND_VOID
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

	owned-opcode?: func [opcode [integer!] return: [logic!]][
		any [
			opcode = WIRE_OPCODE_PORT_READ
			opcode = WIRE_OPCODE_PORT_WRITE
			opcode = WIRE_OPCODE_GET_PC
			opcode = WIRE_OPCODE_TARGET_FRAGMENT
			opcode = WIRE_OPCODE_CPU_REGISTER_READ
			opcode = WIRE_OPCODE_CPU_REGISTER_WRITE
		]
	]

	validate-fragments: func [
		result [wire-target-intrinsic-result!]
		files [wire-file-source!]
		types [wire-type-layout!]
		constants [wire-constant-initializer!]
		view [wire-target-intrinsic!]
		target abi [integer!]
		return: [integer!]
		/local record [byte-ptr!]
			fragment-id record-index base bad-relative actual-target actual-abi
			data-offset data-size finish return-type effects clobber source-location
			cursor [integer!]
	][
		record-index: 0
		while [record-index < view/target-fragment-count][
			record: view/target-fragments
				+ (record-index * WIRE_RSIR_TARGET_FRAGMENT_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_SCALAR_RANGE
					((view/target-fragments-offset
						+ (record-index * WIRE_RSIR_TARGET_FRAGMENT_SIZE))
						+ bad-relative)
					view/target-fragments-ordinal
			]
			record-index: record-index + 1
		]

		cursor: constants/constant-data-owned-size
		fragment-id: 1
		while [fragment-id <= view/target-fragment-count][
			base: fragment-base view fragment-id
			actual-target: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET
			if actual-target <> target [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_TARGET
					(base + WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET)
					view/target-fragments-ordinal
			]
			actual-abi: fragment-value view fragment-id WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET
			if actual-abi <> abi [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_ABI
					(base + WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET)
					view/target-fragments-ordinal
			]
			data-offset: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET
			if data-offset <> cursor [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_OFFSET
					(base + WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET)
					view/target-fragments-ordinal
			]
			data-size: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET
			if data-size <= 0 [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_SIZE
					(base + WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET)
					view/target-fragments-ordinal
			]
			finish: wire-container-reader/checked-add data-offset data-size
			if any [finish < 0 finish > constants/constant-data-size][
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_RANGE
					(base + WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET)
					view/target-fragments-ordinal
			]
			return-type: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
			unless fragment-return-type? types return-type [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_RETURN_TYPE
					(base + WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET)
					view/target-fragments-ordinal
			]
			effects: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET
			if effects <> fragment-effects [
				return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_EFFECTS
					(base + WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET)
					view/target-fragments-ordinal
			]
			clobber: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET
			if clobber <> WIRE_TARGET_CLOBBER_CLASS_WIN64_VOLATILE [
				return set-error result
					WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_CLOBBER_CLASS
					(base + WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET)
					view/target-fragments-ordinal
			]
			source-location: fragment-value view fragment-id
				WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET
			if source-location > files/source-count [
				return set-error result
					WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SOURCE_LOCATION
					(base + WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET)
					view/target-fragments-ordinal
			]
			cursor: finish
			fragment-id: fragment-id + 1
		]

		if cursor <> constants/constant-data-size [
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_COVERAGE
				(constants/constant-data-offset + cursor)
				constants/constant-data-ordinal
		]
		WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	]

	validate-instructions: func [
		result [wire-target-intrinsic-result!]
		types [wire-type-layout!]
		constants [wire-constant-initializer!]
		scalar [wire-scalar-operation!]
		view [wire-target-intrinsic!]
		return: [integer!]
		/local instruction-id opcode base subopcode flags effects expected-effects
			alias-kind alias-id expected-alias operand-count result-count expected-operands
			expected-results first-operand operand-index operand-id kind auxiliary
			pointer-type pointee-type data-type first-result result-type fragment-id
			reference return-type return-kind expected-result-count source-location
			fragment-source relative [integer!]
	][
		fragment-id: 1
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if owned-opcode? opcode [
				base: instruction-base scalar instruction-id
				subopcode: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
				either any [
					opcode = WIRE_OPCODE_CPU_REGISTER_READ
					opcode = WIRE_OPCODE_CPU_REGISTER_WRITE
				][
					unless all [
						subopcode >= WIRE_X64_REGISTER_RAX
						subopcode <= WIRE_X64_REGISTER_R15
					][
						return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER
							(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					if all [
						opcode = WIRE_OPCODE_CPU_REGISTER_WRITE
						any [
							subopcode = WIRE_X64_REGISTER_RSP
							subopcode = WIRE_X64_REGISTER_RBP
						]
					][
						return set-error result
							WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_WRITE
							(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if subopcode <> 0 [
						return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_SUBOPCODE
							(base + WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]

				flags: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
				if flags <> 0 [
					return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_INSTRUCTION_FLAGS
						(base + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				expected-effects: case [
					opcode = WIRE_OPCODE_PORT_READ [port-read-effects]
					opcode = WIRE_OPCODE_PORT_WRITE [port-write-effects]
					opcode = WIRE_OPCODE_TARGET_FRAGMENT [fragment-effects]
					true [opaque-effects]
				]
				effects: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				if effects <> expected-effects [
					return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_EFFECTS
						(base + WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				expected-alias: either opcode = WIRE_OPCODE_TARGET_FRAGMENT [
					WIRE_ALIAS_KIND_UNIVERSAL
				][WIRE_ALIAS_KIND_NONE]
				alias-kind: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				alias-id: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
				unless all [alias-kind = expected-alias alias-id = 0][
					relative: either alias-kind <> expected-alias [
						WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
					][WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
					return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_ALIAS
						(base + relative) scalar/instructions-ordinal
				]

				expected-operands: case [
					opcode = WIRE_OPCODE_PORT_READ [1]
					opcode = WIRE_OPCODE_PORT_WRITE [2]
					opcode = WIRE_OPCODE_TARGET_FRAGMENT [1]
					opcode = WIRE_OPCODE_CPU_REGISTER_WRITE [1]
					true [0]
				]
				expected-results: case [
					opcode = WIRE_OPCODE_PORT_READ [1]
					opcode = WIRE_OPCODE_GET_PC [1]
					opcode = WIRE_OPCODE_CPU_REGISTER_READ [1]
					opcode = WIRE_OPCODE_TARGET_FRAGMENT [-1]
					true [0]
				]
				operand-count: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
				if operand-count <> expected-operands [
					return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_COUNT
						(base + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				result-count: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
				if any [
					all [expected-results >= 0 result-count <> expected-results]
					all [expected-results < 0 result-count > 1]
				][
					return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_RESULT_COUNT
						(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
						scalar/instructions-ordinal
				]

				first-operand: instruction-value scalar instruction-id
					WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				operand-index: 0
				while [operand-index < expected-operands][
					operand-id: first-operand + operand-index
					kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
					either opcode = WIRE_OPCODE_TARGET_FRAGMENT [
						unless kind = WIRE_OPERAND_KIND_TARGET_FRAGMENT [
							return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_KIND
								((operand-base scalar operand-id)
									+ WIRE_RSIR_OPERAND_KIND_OFFSET)
								scalar/operands-ordinal
						]
					][
						unless any [
							kind = WIRE_OPERAND_KIND_VALUE
							kind = WIRE_OPERAND_KIND_CONSTANT
						][
							return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_KIND
								((operand-base scalar operand-id)
									+ WIRE_RSIR_OPERAND_KIND_OFFSET)
								scalar/operands-ordinal
						]
					]
					auxiliary: operand-value scalar operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					if auxiliary <> 0 [
						return set-error result
							WIRE_TARGET_INTRINSIC_ERROR_NONZERO_OPERAND_AUXILIARY
							((operand-base scalar operand-id)
								+ WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
							scalar/operands-ordinal
					]
					operand-index: operand-index + 1
				]

				case [
					any [
						opcode = WIRE_OPCODE_PORT_READ
						opcode = WIRE_OPCODE_PORT_WRITE
					][
						pointer-type: operand-type scalar constants first-operand
						pointee-type: port-pointee-type types pointer-type
						if pointee-type = 0 [
							return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_PORT_TYPE
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						either opcode = WIRE_OPCODE_PORT_READ [
							first-result: instruction-value scalar instruction-id
								WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
							result-type: value-value scalar first-result WIRE_RSIR_VALUE_TYPE_OFFSET
							if result-type <> pointee-type [
								return set-error result
									WIRE_TARGET_INTRINSIC_ERROR_PORT_TYPE_MISMATCH
									((value-base scalar first-result)
										+ WIRE_RSIR_VALUE_TYPE_OFFSET)
									scalar/values-ordinal
							]
						][
							data-type: operand-type scalar constants (first-operand + 1)
							if data-type <> pointee-type [
								return set-error result
									WIRE_TARGET_INTRINSIC_ERROR_PORT_TYPE_MISMATCH
									((operand-base scalar (first-operand + 1))
										+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar/operands-ordinal
							]
						]
					]
					opcode = WIRE_OPCODE_GET_PC [
						first-result: instruction-value scalar instruction-id
							WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
						result-type: value-value scalar first-result WIRE_RSIR_VALUE_TYPE_OFFSET
						unless pointer-to-u8? types result-type [
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_BAD_GET_PC_RESULT_TYPE
								((value-base scalar first-result)
									+ WIRE_RSIR_VALUE_TYPE_OFFSET)
								scalar/values-ordinal
						]
					]
					opcode = WIRE_OPCODE_TARGET_FRAGMENT [
						reference: operand-value scalar first-operand
							WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						if any [
							fragment-id > view/target-fragment-count
							reference <> fragment-id
						][
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_REFERENCE
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						return-type: fragment-value view fragment-id
							WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
						return-kind: type-value types return-type WIRE_RSIR_TYPE_KIND_OFFSET
						expected-result-count: either return-kind = WIRE_TYPE_KIND_VOID [0][1]
						if result-count <> expected-result-count [
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_RETURN_MISMATCH
								(base + WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
								scalar/instructions-ordinal
						]
						if result-count = 1 [
							first-result: instruction-value scalar instruction-id
								WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
							result-type: value-value scalar first-result WIRE_RSIR_VALUE_TYPE_OFFSET
							if result-type <> return-type [
								return set-error result
									WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_RETURN_MISMATCH
									((value-base scalar first-result)
										+ WIRE_RSIR_VALUE_TYPE_OFFSET)
									scalar/values-ordinal
							]
						]
						source-location: instruction-value scalar instruction-id
							WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET
						fragment-source: fragment-value view fragment-id
							WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET
						if source-location <> fragment-source [
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SOURCE_LOCATION
								(base + WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET)
								scalar/instructions-ordinal
						]
						fragment-id: fragment-id + 1
					]
					opcode = WIRE_OPCODE_CPU_REGISTER_READ [
						first-result: instruction-value scalar instruction-id
							WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
						result-type: value-value scalar first-result WIRE_RSIR_VALUE_TYPE_OFFSET
						unless cpu-register-type? types result-type [
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_TYPE
								((value-base scalar first-result)
									+ WIRE_RSIR_VALUE_TYPE_OFFSET)
								scalar/values-ordinal
						]
					]
					opcode = WIRE_OPCODE_CPU_REGISTER_WRITE [
						data-type: operand-type scalar constants first-operand
						unless cpu-register-type? types data-type [
							return set-error result
								WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_TYPE
								((operand-base scalar first-operand)
									+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
					true []
				]
			]
			instruction-id: instruction-id + 1
		]

		if (fragment-id - 1) <> view/target-fragment-count [
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_COVERAGE
				(fragment-base view fragment-id) view/target-fragments-ordinal
		]
		WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	]

	validate-syscalls: func [
		result [wire-target-intrinsic-result!]
		calls [wire-call-abi!]
		return: [integer!]
		/local call-id kind argument-count base [integer!]
	][
		call-id: 1
		while [call-id <= calls/call-count][
			kind: call-value calls call-id WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
			if kind = WIRE_CALL_KIND_SYSCALL [
				argument-count: call-value calls call-id WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
				if argument-count > 6 [
					base: call-base calls call-id
					return set-error result
						WIRE_TARGET_INTRINSIC_ERROR_BAD_SYSCALL_ARGUMENT_COUNT
						(base + WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
						calls/calls-ordinal
				]
			]
			call-id: call-id + 1
		]
		WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	]

	copy-view: func [destination source [wire-target-intrinsic!]][
		destination/target-fragments: source/target-fragments
		destination/target-fragment-count: source/target-fragment-count
		destination/target-fragment-record-size: source/target-fragment-record-size
		destination/target-fragments-offset: source/target-fragments-offset
		destination/target-fragments-ordinal: source/target-fragments-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
		result [wire-target-intrinsic-result!]
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
		view [wire-target-intrinsic!]
		return: [integer!]
		/local stack-result [wire-stack-result!]
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
			verified-view [wire-target-intrinsic!]
			fragment-section [wire-section-slice!]
			status target abi [integer!]
	][
		if null? result [return WIRE_TARGET_INTRINSIC_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
		result/stack-error: WIRE_STACK_ERROR_SUCCESS
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
			null? view
		][
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_INVALID_ARGUMENTS 0 0
		]

		stack-result: declare wire-stack-result!
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
		verified-view: declare wire-target-intrinsic!
		status: wire-stack-reader/verify data size workspace workspace-size stack-result
			verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar verified-control verified-calls verified-subroutines
			verified-exceptions
		result/stack-error: status
		result/exception-error: stack-result/exception-error
		result/subroutine-error: stack-result/subroutine-error
		result/call-abi-error: stack-result/call-abi-error
		result/control-flow-error: stack-result/control-flow-error
		result/scalar-operation-error: stack-result/scalar-operation-error
		result/container-error: stack-result/container-error
		result/string-error: stack-result/string-error
		result/file-source-error: stack-result/file-source-error
		result/data-layout-error: stack-result/data-layout-error
		result/type-layout-error: stack-result/type-layout-error
		result/function-signature-error: stack-result/function-signature-error
		result/module-lifecycle-error: stack-result/module-lifecycle-error
		result/symbol-linkage-error: stack-result/symbol-linkage-error
		result/constant-initializer-error: stack-result/constant-initializer-error
		if status <> WIRE_STACK_ERROR_SUCCESS [
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_INVALID_STACK
				stack-result/error-offset stack-result/error-section
		]

		fragment-section: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_TARGET_FRAGMENTS fragment-section
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_INVALID_STACK
				WIRE_HEADER_SIZE 0
		]
		if fragment-section/flags <> 0 [
			return set-error result WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SECTION_FLAGS
				(section-flags-offset fragment-section) fragment-section/ordinal
		]
		verified-view/target-fragments: fragment-section/data
		verified-view/target-fragment-count: fragment-section/record-count
		verified-view/target-fragment-record-size: fragment-section/record-size
		verified-view/target-fragments-offset: fragment-section/offset
		verified-view/target-fragments-ordinal: fragment-section/ordinal

		target: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_OFFSET
		abi: wire-container-reader/read-i31 data WIRE_HEADER_ABI_OFFSET
		status: validate-fragments result verified-files verified-types
			verified-constants verified-view target abi
		if status <> WIRE_TARGET_INTRINSIC_ERROR_SUCCESS [return status]
		status: validate-instructions result verified-types verified-constants
			verified-scalar verified-view
		if status <> WIRE_TARGET_INTRINSIC_ERROR_SUCCESS [return status]
		status: validate-syscalls result verified-calls
		if status <> WIRE_TARGET_INTRINSIC_ERROR_SUCCESS [return status]

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
		copy-view view verified-view
		WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	]
]
