Red/System [
	Title: "Hybrid compiler RSIR call and Win64 ABI verifier"
	File:  %wire-call-abi.reds
]

#include %wire-control-flow.reds

wire-call-abi-result!: alias struct! [
	error                      [integer!]
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

wire-call-abi!: alias struct! [
	calls            [byte-ptr!]
	call-count       [integer!]
	call-record-size [integer!]
	calls-offset     [integer!]
	calls-ordinal    [integer!]
]

wire-call-abi-reader: context [
	variable-mode-mask:
		(WIRE_FUNCTION_FLAG_VARIADIC or WIRE_FUNCTION_FLAG_TYPED)
		or WIRE_FUNCTION_FLAG_CUSTOM
	required-call-effects:
		(((WIRE_EFFECT_FLAG_READ or WIRE_EFFECT_FLAG_WRITE)
			or WIRE_EFFECT_FLAG_CALL) or WIRE_EFFECT_FLAG_MAY_TRAP)
		or WIRE_EFFECT_FLAG_SAFEPOINT
	allowed-call-effects:
		(required-call-effects or WIRE_EFFECT_FLAG_THROW) or WIRE_EFFECT_FLAG_STACK

	set-error: func [
		result [wire-call-abi-result!]
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

	call-value: func [
		view [wire-call-abi!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/calls
			(((id - 1) * WIRE_RSIR_CALL_SIZE) + field-offset)
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

	type-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/types
			(((id - 1) * WIRE_RSIR_TYPE_SIZE) + field-offset)
	]

	signature-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/signatures
			(((id - 1) * WIRE_RSIR_SIGNATURE_SIZE) + field-offset)
	]

	parameter-value: func [
		functions [wire-function-signature!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 functions/parameters
			(((id - 1) * WIRE_RSIR_PARAMETER_SIZE) + field-offset)
	]

	symbol-value: func [
		symbols [wire-symbol-linkage!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 symbols/symbols
			(((id - 1) * WIRE_RSIR_SYMBOL_SIZE) + field-offset)
	]

	import-value: func [
		symbols [wire-symbol-linkage!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 symbols/imports
			(((id - 1) * WIRE_IMPORT_SIZE) + field-offset)
	]

	constant-value: func [
		constants [wire-constant-initializer!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 constants/constants
			(((id - 1) * WIRE_RSIR_CONSTANT_SIZE) + field-offset)
	]

	call-base: func [view [wire-call-abi!] id [integer!] return: [integer!]][
		view/calls-offset + ((id - 1) * WIRE_RSIR_CALL_SIZE)
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

	valid-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [id > 0 id <= types/type-count]
	]

	nonvoid-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			valid-type? types id
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) <> WIRE_TYPE_KIND_VOID
		]
	]

	integer32-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			nonvoid-type? types id
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_INTEGER
			(type-value types id WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value types id WIRE_RSIR_TYPE_FLAGS_OFFSET) = WIRE_TYPE_FLAG_SIGNED
		]
	]

	aggregate-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
		any [kind = WIRE_TYPE_KIND_STRUCT kind = WIRE_TYPE_KIND_UNION]
	]

	packable-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
		any [
			kind = WIRE_TYPE_KIND_LOGIC
			kind = WIRE_TYPE_KIND_INTEGER
			kind = WIRE_TYPE_KIND_FLOAT
			kind = WIRE_TYPE_KIND_POINTER
			kind = WIRE_TYPE_KIND_FUNCTION
		]
	]

	syscall-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
		/local kind [integer!]
	][
		kind: type-value types id WIRE_RSIR_TYPE_KIND_OFFSET
		any [
			kind = WIRE_TYPE_KIND_LOGIC
			kind = WIRE_TYPE_KIND_INTEGER
			kind = WIRE_TYPE_KIND_POINTER
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

	find-import-for-symbol: func [
		symbols [wire-symbol-linkage!]
		symbol-id [integer!]
		return: [integer!]
		/local import-id [integer!]
	][
		import-id: 1
		while [import-id <= symbols/import-count][
			if (import-value symbols import-id WIRE_IMPORT_SYMBOL_OFFSET) = symbol-id [
				return import-id
			]
			import-id: import-id + 1
		]
		0
	]

	; Returns 1 for known negative, 0 for known nonnegative, -1 for unknown.
	known-negative-i32-constant?: func [
		constants [wire-constant-initializer!]
		constant-id [integer!]
		return: [integer!]
		/local kind data-offset data-size [integer!] sign [byte-ptr!]
	][
		kind: constant-value constants constant-id WIRE_RSIR_CONSTANT_KIND_OFFSET
		if kind = WIRE_CONSTANT_KIND_ZERO [return 0]
		if kind <> WIRE_CONSTANT_KIND_SCALAR [return -1]
		data-size: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		if data-size <> 4 [return -1]
		data-offset: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		sign: constants/constant-data + data-offset + 3
		either (as integer! sign/1) > 127 [1][0]
	]

	known-negative-i32-value?: func [
		scalar [wire-scalar-operation!]
		constants [wire-constant-initializer!]
		value-id [integer!]
		return: [integer!]
		/local definition-kind definition-id opcode first-operand operand-kind
			constant-id [integer!]
	][
		definition-kind: value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
		if definition-kind <> WIRE_VALUE_DEFINITION_INSTRUCTION [return -1]
		definition-id: value-value scalar value-id WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		opcode: instruction-value scalar definition-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode <> WIRE_OPCODE_CONSTANT [return -1]
		if (instruction-value scalar definition-id WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
			<> 1 [return -1]
		first-operand: instruction-value scalar definition-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-kind: operand-value scalar first-operand WIRE_RSIR_OPERAND_KIND_OFFSET
		if operand-kind <> WIRE_OPERAND_KIND_CONSTANT [return -1]
		constant-id: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		known-negative-i32-constant? constants constant-id
	]

	known-negative-i32-operand?: func [
		scalar [wire-scalar-operation!]
		constants [wire-constant-initializer!]
		operand-id [integer!]
		return: [integer!]
		/local kind reference [integer!]
	][
		kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value scalar operand-id WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = WIRE_OPERAND_KIND_CONSTANT [
				known-negative-i32-constant? constants reference
			]
			kind = WIRE_OPERAND_KIND_VALUE [
				known-negative-i32-value? scalar constants reference
			]
			true [-1]
		]
	]

	verify-callee: func [
		result [wire-call-abi-result!]
		calls [wire-call-abi!]
		scalar [wire-scalar-operation!]
		functions [wire-function-signature!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		types [wire-type-layout!]
		call-id signature-id kind callee-operand [integer!]
		return: [integer!]
		/local base operand-record-base operand-kind reference auxiliary target-signature
			callee-symbol linkage import-id value-type constant-id constant-type
			constant-kind data-size cc [integer!]
	][
		base: call-base calls call-id
		if any [callee-operand <= 0 callee-operand > scalar/operand-count][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(base + WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET) calls/calls-ordinal
		]
		operand-record-base: operand-base scalar callee-operand
		operand-kind: operand-value scalar callee-operand WIRE_RSIR_OPERAND_KIND_OFFSET
		auxiliary: operand-value scalar callee-operand WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
		if auxiliary <> 0 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(operand-record-base + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar/operands-ordinal
		]
		reference: operand-value scalar callee-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		target-signature: 0
		case [
			kind = WIRE_CALL_KIND_DIRECT [
				if operand-kind <> WIRE_OPERAND_KIND_SYMBOL [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar/operands-ordinal
				]
				callee-symbol: reference
				unless all [
					callee-symbol > 0
					callee-symbol <= symbols/symbol-count
					(symbol-value symbols callee-symbol WIRE_RSIR_SYMBOL_KIND_OFFSET)
						= WIRE_SYMBOL_KIND_FUNCTION
				][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				linkage: symbol-value symbols callee-symbol WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
				unless any [
					linkage = WIRE_LINKAGE_LOCAL
					linkage = WIRE_LINKAGE_INTERNAL
					linkage = WIRE_LINKAGE_EXTERNAL
					linkage = WIRE_LINKAGE_WEAK
				][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				target-signature: symbol-value symbols callee-symbol
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			]
			kind = WIRE_CALL_KIND_IMPORT [
				if operand-kind <> WIRE_OPERAND_KIND_SYMBOL [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar/operands-ordinal
				]
				callee-symbol: reference
				unless all [
					callee-symbol > 0
					callee-symbol <= symbols/symbol-count
					(symbol-value symbols callee-symbol WIRE_RSIR_SYMBOL_KIND_OFFSET)
						= WIRE_SYMBOL_KIND_FUNCTION
					(symbol-value symbols callee-symbol WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
						= WIRE_LINKAGE_IMPORT
				][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				import-id: find-import-for-symbol symbols callee-symbol
				if import-id = 0 [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				target-signature: symbol-value symbols callee-symbol
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				if (import-value symbols import-id WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
					<> (signature-value functions signature-id
						WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
				[
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
						(symbols/imports-offset + (((import-id - 1) * WIRE_IMPORT_SIZE)
							+ WIRE_IMPORT_CALLING_CONVENTION_OFFSET))
						symbols/imports-ordinal
				]
			]
			kind = WIRE_CALL_KIND_INDIRECT [
				if operand-kind <> WIRE_OPERAND_KIND_VALUE [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_INDIRECT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar/operands-ordinal
				]
				value-type: value-value scalar reference WIRE_RSIR_VALUE_TYPE_OFFSET
				unless all [
					valid-type? types value-type
					(type-value types value-type WIRE_RSIR_TYPE_KIND_OFFSET)
						= WIRE_TYPE_KIND_FUNCTION
				][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_INDIRECT_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				target-signature: type-value types value-type WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
			]
			kind = WIRE_CALL_KIND_SYSCALL [
				if operand-kind <> WIRE_OPERAND_KIND_CONSTANT [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar/operands-ordinal
				]
				constant-id: reference
				unless all [constant-id > 0 constant-id <= constants/constant-count][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				constant-type: constant-value constants constant-id
					WIRE_RSIR_CONSTANT_TYPE_OFFSET
				unless integer32-type? types constant-type [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				constant-kind: constant-value constants constant-id
					WIRE_RSIR_CONSTANT_KIND_OFFSET
				unless any [
					constant-kind = WIRE_CONSTANT_KIND_ZERO
					constant-kind = WIRE_CONSTANT_KIND_SCALAR
				][
					return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				if constant-kind = WIRE_CONSTANT_KIND_SCALAR [
					data-size: constant-value constants constant-id
						WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
					if data-size <> 4 [
						return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
							(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar/operands-ordinal
					]
				]
				if (known-negative-i32-constant? constants constant-id) = 1 [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_SYSCALL_NUMBER
						(operand-record-base + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				target-signature: signature-id
			]
			true [
				return set-error result WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
					(base + WIRE_RSIR_CALL_CALLEE_KIND_OFFSET) calls/calls-ordinal
			]
		]
		unless all [
			target-signature > 0
			target-signature <= functions/signature-count
			target-signature = signature-id
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_TARGET_SIGNATURE
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		cc: signature-value functions signature-id WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
		if all [kind = WIRE_CALL_KIND_SYSCALL cc <> WIRE_CALLING_CONVENTION_SYSCALL][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		if all [kind <> WIRE_CALL_KIND_SYSCALL cc = WIRE_CALLING_CONVENTION_SYSCALL][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + WIRE_RSIR_CALL_CALLEE_KIND_OFFSET) calls/calls-ordinal
		]
		WIRE_CALL_ABI_ERROR_SUCCESS
	]

	verify-call: func [
		result [wire-call-abi-result!]
		calls [wire-call-abi!]
		scalar [wire-scalar-operation!]
		functions [wire-function-signature!]
		symbols [wire-symbol-linkage!]
		constants [wire-constant-initializer!]
		types [wire-type-layout!]
		call-id instruction-id [integer!]
		return: [integer!]
		/local base signature-id kind callee-operand first-argument argument-count
			instruction-first instruction-count status flags effect alias-kind alias-id
			return-type return-kind result-count result-id result-type variable-mode cc
			parameter-count first-parameter operand-id remaining argument-index
			operand-kind auxiliary argument-type parameter-type known-negative error-code
			error-field-offset
			[integer!]
			custom? typed? variadic? c-variadic? non-c-variadic? [logic!]
	][
		base: call-base calls call-id
		signature-id: call-value calls call-id WIRE_RSIR_CALL_SIGNATURE_OFFSET
		if any [signature-id <= 0 signature-id > functions/signature-count][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_TARGET_SIGNATURE
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		kind: call-value calls call-id WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
		if any [kind = WIRE_CALL_KIND_CUSTOM kind = WIRE_CALL_KIND_SUBROUTINE][
			return set-error result WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
				(base + WIRE_RSIR_CALL_CALLEE_KIND_OFFSET) calls/calls-ordinal
		]
		unless any [
			kind = WIRE_CALL_KIND_DIRECT
			kind = WIRE_CALL_KIND_INDIRECT
			kind = WIRE_CALL_KIND_IMPORT
			kind = WIRE_CALL_KIND_SYSCALL
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLEE_KIND
				(base + WIRE_RSIR_CALL_CALLEE_KIND_OFFSET) calls/calls-ordinal
		]
		if (call-value calls call-id WIRE_RSIR_CALL_FLAGS_OFFSET) <> 0 [
			return set-error result WIRE_CALL_ABI_ERROR_NONZERO_CALL_FLAGS
				(base + WIRE_RSIR_CALL_FLAGS_OFFSET) calls/calls-ordinal
		]
		if (call-value calls call-id WIRE_RSIR_CALL_RESERVED_OFFSET) <> 0 [
			return set-error result WIRE_CALL_ABI_ERROR_NONZERO_CALL_RESERVED
				(base + WIRE_RSIR_CALL_RESERVED_OFFSET) calls/calls-ordinal
		]
		callee-operand: call-value calls call-id WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
		instruction-first: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		instruction-count: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if any [instruction-count < 1 callee-operand <> instruction-first][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(base + WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET) calls/calls-ordinal
		]
		first-argument: call-value calls call-id WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
		argument-count: call-value calls call-id WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
		if any [argument-count < 0 argument-count <> (instruction-count - 1)][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_COUNT
				(base + WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET) calls/calls-ordinal
		]
		either argument-count = 0 [
			if first-argument <> 0 [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_OPERAND_RANGE
					(base + WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET)
					calls/calls-ordinal
			]
		][
			if first-argument <> (instruction-first + 1) [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_OPERAND_RANGE
					(base + WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET)
					calls/calls-ordinal
			]
		]
		status: verify-callee result calls scalar functions symbols constants types
			call-id signature-id kind callee-operand
		if status <> WIRE_CALL_ABI_ERROR_SUCCESS [return status]

		flags: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		if flags <> 0 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_FLAGS
				((instruction-base scalar instruction-id) + WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
			<> 0
		[
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_SUBOPCODE
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				scalar/instructions-ordinal
		]
		effect: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		alias-kind: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [alias-kind = WIRE_ALIAS_KIND_UNIVERSAL alias-id = 0][
			error-field-offset: either (alias-kind = WIRE_ALIAS_KIND_UNIVERSAL)
				[WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
				[WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET]
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ALIAS
				((instruction-base scalar instruction-id) + error-field-offset)
				scalar/instructions-ordinal
		]
		return-type: signature-value functions signature-id WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
		result-count: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		either (type-value types return-type WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_VOID [
			if result-count <> 0 [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_COUNT
					((instruction-base scalar instruction-id)
						+ WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
					scalar/instructions-ordinal
			]
		][
			if result-count <> 1 [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_COUNT
					((instruction-base scalar instruction-id)
						+ WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
					scalar/instructions-ordinal
			]
			result-id: instruction-value scalar instruction-id
				WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
			result-type: value-value scalar result-id WIRE_RSIR_VALUE_TYPE_OFFSET
			if result-type <> return-type [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_TYPE
					((value-base scalar result-id) + WIRE_RSIR_VALUE_TYPE_OFFSET)
					scalar/values-ordinal
			]
		]

		flags: signature-value functions signature-id WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		variable-mode: (flags and variable-mode-mask)
		custom?: variable-mode = WIRE_FUNCTION_FLAG_CUSTOM
		typed?: variable-mode = WIRE_FUNCTION_FLAG_TYPED
		variadic?: variable-mode = WIRE_FUNCTION_FLAG_VARIADIC
		cc: signature-value functions signature-id WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
		c-variadic?: all [variadic? cc = WIRE_CALLING_CONVENTION_CDECL]
		non-c-variadic?: all [variadic? not c-variadic?]
		parameter-count: signature-value functions signature-id
			WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
		first-parameter: signature-value functions signature-id
			WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET

		if all [custom? argument-count <> 1][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CUSTOM_ARGUMENTS
				(base + WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET) calls/calls-ordinal
		]
		if all [typed? cc = WIRE_CALLING_CONVENTION_SYSCALL][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_TYPED_ARGUMENTS
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		if all [non-c-variadic? cc = WIRE_CALLING_CONVENTION_SYSCALL][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		if all [
			not custom?
			not typed?
			not variadic?
			argument-count <> parameter-count
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_COUNT
				(base + WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET) calls/calls-ordinal
		]
		if all [c-variadic? argument-count < parameter-count][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
				(base + WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET) calls/calls-ordinal
		]

		operand-id: first-argument
		remaining: argument-count
		argument-index: 0
		while [remaining > 0][
			operand-kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
			unless any [
				operand-kind = WIRE_OPERAND_KIND_VALUE
				operand-kind = WIRE_OPERAND_KIND_CONSTANT
			][
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_KIND
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_KIND_OFFSET)
					scalar/operands-ordinal
			]
			auxiliary: operand-value scalar operand-id WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_KIND
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					scalar/operands-ordinal
			]
			argument-type: operand-type scalar constants operand-id
			unless nonvoid-type? types argument-type [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_TYPE
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			if all [
				cc = WIRE_CALLING_CONVENTION_SYSCALL
				aggregate-type? types argument-type
			][
				return set-error result WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_ARGUMENT
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			if all [
				cc = WIRE_CALLING_CONVENTION_SYSCALL
				not syscall-type? types argument-type
			][
				return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			if custom? [
				unless integer32-type? types argument-type [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CUSTOM_ARGUMENTS
						((operand-base scalar operand-id)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				known-negative: known-negative-i32-operand? scalar constants operand-id
				if known-negative = 1 [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_VALUE
						((operand-base scalar operand-id)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
			]
			if all [
				not custom?
				not typed?
				not non-c-variadic?
				argument-index < parameter-count
			][
				parameter-type: parameter-value functions (first-parameter + argument-index)
					WIRE_RSIR_PARAMETER_TYPE_OFFSET
				if argument-type <> parameter-type [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_TYPE
						((operand-base scalar operand-id)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
			]
			if all [
				c-variadic?
				argument-index >= parameter-count
				(type-value types argument-type WIRE_RSIR_TYPE_KIND_OFFSET)
					= WIRE_TYPE_KIND_FLOAT
				(type-value types argument-type WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			][
				return set-error result WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
					((operand-base scalar operand-id) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar/operands-ordinal
			]
			if any [typed? non-c-variadic?][
				unless packable-type? types argument-type [
					error-code: either typed?
						[WIRE_CALL_ABI_ERROR_BAD_TYPED_ARGUMENTS]
						[WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS]
					return set-error result error-code
						((operand-base scalar operand-id)
							+ WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
			]
			remaining: remaining - 1
			argument-index: argument-index + 1
			operand-id: operand-id + 1
		]

		if all [
			kind = WIRE_CALL_KIND_SYSCALL
			(flags and (variable-mode-mask or WIRE_FUNCTION_FLAG_CALLBACK)) <> 0
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		return-kind: type-value types return-type WIRE_RSIR_TYPE_KIND_OFFSET
		if all [cc = WIRE_CALLING_CONVENTION_SYSCALL aggregate-type? types return-type][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_RETURN
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		if all [
			cc = WIRE_CALLING_CONVENTION_SYSCALL
			return-kind <> WIRE_TYPE_KIND_VOID
			not syscall-type? types return-type
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI
				(base + WIRE_RSIR_CALL_SIGNATURE_OFFSET) calls/calls-ordinal
		]
		if all [custom? (effect and WIRE_EFFECT_FLAG_STACK) = 0][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if all [not custom? (effect and WIRE_EFFECT_FLAG_STACK) <> 0][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		unless all [
			(effect and WIRE_EFFECT_FLAG_CALL) <> 0
			(effect and WIRE_EFFECT_FLAG_READ) <> 0
			(effect and WIRE_EFFECT_FLAG_WRITE) <> 0
			(effect and WIRE_EFFECT_FLAG_MAY_TRAP) <> 0
			(effect and WIRE_EFFECT_FLAG_SAFEPOINT) <> 0
			(effect and allowed-call-effects) = effect
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_EFFECTS
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if all [
			(flags and WIRE_FUNCTION_FLAG_MAY_THROW) = 0
			(effect and WIRE_EFFECT_FLAG_THROW) <> 0
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		if all [
			(flags and WIRE_FUNCTION_FLAG_MAY_THROW) <> 0
			(effect and WIRE_EFFECT_FLAG_THROW) = 0
		][
			return set-error result WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				((instruction-base scalar instruction-id)
					+ WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar/instructions-ordinal
		]
		WIRE_CALL_ABI_ERROR_SUCCESS
	]

	copy-view: func [destination source [wire-call-abi!]][
		destination/calls: source/calls
		destination/call-count: source/call-count
		destination/call-record-size: source/call-record-size
		destination/calls-offset: source/calls-offset
		destination/calls-ordinal: source/calls-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		workspace [byte-ptr!]
		workspace-size [integer!]
		result [wire-call-abi-result!]
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
		return: [integer!]
		/local control-result [wire-control-flow-result!]
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
			call-section [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative record-index record-base call-id instruction-id
			previous-instruction opcode target abi endian pointer-size [integer!]
	][
		if null? result [return WIRE_CALL_ABI_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_CALL_ABI_ERROR_SUCCESS
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
		][
			return set-error result WIRE_CALL_ABI_ERROR_INVALID_ARGUMENTS 0 0
		]

		control-result: declare wire-control-flow-result!
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
		status: wire-control-flow-reader/verify data size workspace workspace-size
			control-result verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols verified-constants
			verified-scalar verified-control
		result/control-flow-error: status
		result/scalar-operation-error: control-result/scalar-operation-error
		result/container-error: control-result/container-error
		result/string-error: control-result/string-error
		result/file-source-error: control-result/file-source-error
		result/data-layout-error: control-result/data-layout-error
		result/type-layout-error: control-result/type-layout-error
		result/function-signature-error: control-result/function-signature-error
		result/module-lifecycle-error: control-result/module-lifecycle-error
		result/symbol-linkage-error: control-result/symbol-linkage-error
		result/constant-initializer-error: control-result/constant-initializer-error
		if status <> WIRE_CONTROL_FLOW_ERROR_SUCCESS [
			return set-error result WIRE_CALL_ABI_ERROR_INVALID_CONTROL_FLOW
				control-result/error-offset control-result/error-section
		]

		call-section: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_CALLS call-section
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CALL_ABI_ERROR_INVALID_CONTROL_FLOW WIRE_HEADER_SIZE 0
		]
		if call-section/flags <> 0 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_SECTION_FLAGS
				section-flags-offset call-section call-section/ordinal
		]
		verified-calls/calls: call-section/data
		verified-calls/call-count: call-section/record-count
		verified-calls/call-record-size: call-section/record-size
		verified-calls/calls-offset: call-section/offset
		verified-calls/calls-ordinal: call-section/ordinal

		target: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_OFFSET
		if target <> WIRE_TARGET_X86_64 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI WIRE_HEADER_TARGET_OFFSET 0
		]
		abi: wire-container-reader/read-i31 data WIRE_HEADER_ABI_OFFSET
		if abi <> WIRE_ABI_WIN64 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI WIRE_HEADER_ABI_OFFSET 0
		]
		endian: wire-container-reader/read-i31 data WIRE_HEADER_TARGET_ENDIAN_OFFSET
		if endian <> WIRE_ENDIAN_LITTLE [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI
				WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		pointer-size: wire-container-reader/read-i31 data WIRE_HEADER_POINTER_SIZE_OFFSET
		if pointer-size <> 8 [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_ABI
				WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]

		record-index: 0
		while [record-index < verified-calls/call-count][
			record: verified-calls/calls + (record-index * WIRE_RSIR_CALL_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_CALL_ABI_ERROR_SCALAR_RANGE
					((verified-calls/calls-offset
						+ (record-index * WIRE_RSIR_CALL_SIZE)) + bad-relative)
					verified-calls/calls-ordinal
			]
			record-index: record-index + 1
		]

		call-id: 1
		previous-instruction: 0
		while [call-id <= verified-calls/call-count][
			record-base: call-base verified-calls call-id
			instruction-id: call-value verified-calls call-id WIRE_RSIR_CALL_INSTRUCTION_OFFSET
			if any [
				instruction-id <= 0
				instruction-id > verified-scalar/instruction-count
			][
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_INSTRUCTION
					(record-base + WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					verified-calls/calls-ordinal
			]
			if instruction-id <= previous-instruction [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_ORDER
					(record-base + WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					verified-calls/calls-ordinal
			]
			opcode: instruction-value verified-scalar instruction-id
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode <> WIRE_OPCODE_CALL [
				return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_INSTRUCTION
					(record-base + WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					verified-calls/calls-ordinal
			]
			previous-instruction: instruction-id
			call-id: call-id + 1
		]

		call-id: 1
		instruction-id: 1
		while [instruction-id <= verified-scalar/instruction-count][
			opcode: instruction-value verified-scalar instruction-id
				WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode = WIRE_OPCODE_CALL [
				if call-id > verified-calls/call-count [
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
						((instruction-base verified-scalar instruction-id)
							+ WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						verified-scalar/instructions-ordinal
				]
				if (call-value verified-calls call-id WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					<> instruction-id
				[
					return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
						((instruction-base verified-scalar instruction-id)
							+ WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						verified-scalar/instructions-ordinal
				]
				status: verify-call result verified-calls verified-scalar verified-functions
					verified-symbols verified-constants verified-types call-id instruction-id
				if status <> WIRE_CALL_ABI_ERROR_SUCCESS [return status]
				call-id: call-id + 1
			]
			instruction-id: instruction-id + 1
		]
		if call-id <= verified-calls/call-count [
			return set-error result WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
				((call-base verified-calls call-id) + WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
				verified-calls/calls-ordinal
		]

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
		copy-view calls verified-calls
		WIRE_CALL_ABI_ERROR_SUCCESS
	]
]
