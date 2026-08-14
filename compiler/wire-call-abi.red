Red [
	Title: "Hybrid compiler RSIR call and Win64 ABI verifier"
	File:  %wire-call-abi.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-control-flow [do %wire-control-flow.red]

compiler-wire-call-abi: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	control-verifier: compiler-wire-control-flow

	variable-mode-mask:
		schema/WIRE_FUNCTION_FLAG_VARIADIC
		+ schema/WIRE_FUNCTION_FLAG_TYPED
		+ schema/WIRE_FUNCTION_FLAG_CUSTOM
	required-call-effects:
		schema/WIRE_EFFECT_FLAG_READ
		+ schema/WIRE_EFFECT_FLAG_WRITE
		+ schema/WIRE_EFFECT_FLAG_CALL
		+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
		+ schema/WIRE_EFFECT_FLAG_SAFEPOINT
	allowed-call-effects:
		required-call-effects
		+ schema/WIRE_EFFECT_FLAG_THROW
		+ schema/WIRE_EFFECT_FLAG_STACK

	call-fields: reduce [
		'instruction             schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET
		'signature               schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET
		'callee-reference        schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
		'callee-kind             schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
		'flags                   schema/WIRE_RSIR_CALL_FLAGS_OFFSET
		'first-argument-operand  schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
		'argument-count          schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
		'reserved                schema/WIRE_RSIR_CALL_RESERVED_OFFSET
	]

	make-view: does [
		make object! [
			calls-offset: 0
			call-count: 0
			call-record-size: schema/WIRE_RSIR_CALL_SIZE
			calls-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_CALL_ABI_ERROR_SUCCESS
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
			control-view: none
			scalar-view: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-control-result: func [result control-result [object!]][
		result/header: control-result/header
		result/control-flow-error: control-result/error
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
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	call-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/calls-offset schema/WIRE_RSIR_CALL_SIZE id field
	]

	instruction-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/instructions-offset
			schema/WIRE_RSIR_INSTRUCTION_SIZE id field
	]

	operand-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/operands-offset schema/WIRE_RSIR_OPERAND_SIZE id field
	]

	value-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/values-offset schema/WIRE_RSIR_VALUE_SIZE id field
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		record-value data types/types-offset schema/WIRE_RSIR_TYPE_SIZE id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/signatures-offset
		schema/WIRE_RSIR_SIGNATURE_SIZE id field
	]

	parameter-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/parameters-offset
		schema/WIRE_RSIR_PARAMETER_SIZE id field
	]

	symbol-value: func [data [binary!] symbols [object!] id field [integer!]][
		record-value data symbols/symbols-offset
		schema/WIRE_RSIR_SYMBOL_SIZE id field
	]

	import-value: func [data [binary!] symbols [object!] id field [integer!]][
		record-value data symbols/imports-offset
		schema/WIRE_IMPORT_SIZE id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		record-value data constants/constants-offset
		schema/WIRE_RSIR_CONSTANT_SIZE id field
	]

	instruction-base: func [view [object!] id [integer!]][
		view/instructions-offset + ((id - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [view [object!] id [integer!]][
		view/operands-offset + ((id - 1) * schema/WIRE_RSIR_OPERAND_SIZE)
	]

	value-base: func [view [object!] id [integer!]][
		view/values-offset + ((id - 1) * schema/WIRE_RSIR_VALUE_SIZE)
	]

	call-base: func [view [object!] id [integer!]][
		view/calls-offset + ((id - 1) * schema/WIRE_RSIR_CALL_SIZE)
	]

	instruction-field-offset: func [view [object!] id field [integer!]][
		(instruction-base view id) + field
	]

	operand-field-offset: func [view [object!] id field [integer!]][
		(operand-base view id) + field
	]

	call-field-offset: func [view [object!] id field [integer!]][
		(call-base view id) + field
	]

	valid-type?: func [types [object!] id [integer!]][
		all [id > 0 id <= types/type-count]
	]

	nonvoid-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			valid-type? types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				<> schema/WIRE_TYPE_KIND_VOID
		]
	]

	integer32-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			nonvoid-type? data types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_INTEGER
			(type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET)
				= schema/WIRE_TYPE_FLAG_SIGNED
		]
	]

	aggregate-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [
			schema/WIRE_TYPE_KIND_STRUCT schema/WIRE_TYPE_KIND_UNION
		] type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
	]

	packable-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [
			schema/WIRE_TYPE_KIND_LOGIC
			schema/WIRE_TYPE_KIND_INTEGER
			schema/WIRE_TYPE_KIND_FLOAT
			schema/WIRE_TYPE_KIND_POINTER
			schema/WIRE_TYPE_KIND_FUNCTION
		] type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
	]

	syscall-type?: func [data [binary!] types [object!] id [integer!]][
		find reduce [
			schema/WIRE_TYPE_KIND_LOGIC
			schema/WIRE_TYPE_KIND_INTEGER
			schema/WIRE_TYPE_KIND_POINTER
		] type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
	]

	operand-type: func [
		data [binary!] scalar-view [object!] constants [object!] operand-id [integer!]
		/local kind
	][
		kind: operand-value data scalar-view operand-id
			schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		either kind = schema/WIRE_OPERAND_KIND_VALUE [
			value-value data scalar-view
				(operand-value data scalar-view operand-id
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
				schema/WIRE_RSIR_VALUE_TYPE_OFFSET
		][
			either kind = schema/WIRE_OPERAND_KIND_CONSTANT [
				constant-value data constants
					(operand-value data scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
			][none]
		]
	]

	find-import-for-symbol: func [
		data [binary!] symbols [object!] symbol-id [integer!]
		/local import-id
	][
		import-id: 1
		while [import-id <= symbols/import-count][
			if (import-value data symbols import-id schema/WIRE_IMPORT_SYMBOL_OFFSET)
				= symbol-id [return import-id]
			import-id: import-id + 1
		]
		none
	]

	known-negative-i32-constant?: func [
		data [binary!] constants [object!] constant-id [integer!]
		/local constant-kind data-offset data-size byte-offset
	][
		constant-kind: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
		if constant-kind = schema/WIRE_CONSTANT_KIND_ZERO [return false]
		unless constant-kind = schema/WIRE_CONSTANT_KIND_SCALAR [return none]
		data-size: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
		unless data-size = 4 [return none]
		data-offset: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		byte-offset: constants/constant-data-offset + data-offset + 3
		(to integer! pick data (byte-offset + 1)) > 127
	]

	; A value is statically known only when it is the result of CONSTANT.
	; Parameters and computed values deliberately return `none` rather than being
	; guessed from source syntax or backend state.
	known-negative-i32-value?: func [
		data [binary!] scalar-view [object!] constants [object!] value-id [integer!]
		/local definition-kind definition-id opcode first-operand operand-kind constant-id
	][
		definition-kind: value-value data scalar-view value-id
			schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
		unless definition-kind = schema/WIRE_VALUE_DEFINITION_INSTRUCTION [return none]
		definition-id: value-value data scalar-view value-id
			schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
		opcode: instruction-value data scalar-view definition-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		unless opcode = schema/WIRE_OPCODE_CONSTANT [return none]
		unless (instruction-value data scalar-view definition-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) = 1 [return none]
		first-operand: instruction-value data scalar-view definition-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-kind: operand-value data scalar-view first-operand
			schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		unless operand-kind = schema/WIRE_OPERAND_KIND_CONSTANT [return none]
		constant-id: operand-value data scalar-view first-operand
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		known-negative-i32-constant? data constants constant-id
	]

	known-negative-i32-operand?: func [
		data [binary!] scalar-view [object!] constants [object!] operand-id [integer!]
		/local kind reference
	][
		kind: operand-value data scalar-view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value data scalar-view operand-id
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = schema/WIRE_OPERAND_KIND_CONSTANT [
				known-negative-i32-constant? data constants reference
			]
			kind = schema/WIRE_OPERAND_KIND_VALUE [
				known-negative-i32-value? data scalar-view constants reference
			]
			true [none]
		]
	]

	verify-callee: func [
		data [binary!] result [object!] call-view [object!] scalar-view [object!]
		functions [object!] symbols [object!] constants [object!]
		types [object!] call-id [integer!]
		signature-id [integer!] kind [integer!] callee-operand [integer!]
		/local base operand-base-value operand-kind reference auxiliary target-signature
			callee-symbol import-id value-type value-signature constant-id
			constant-type constant-kind data-size cc
		][
		base: call-base call-view call-id
		if any [callee-operand <= 0 callee-operand > scalar-view/operand-count][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(base + schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET)
				call-view/calls-ordinal
		]
		operand-base-value: operand-base scalar-view callee-operand
		operand-kind: operand-value data scalar-view callee-operand
			schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		auxiliary: operand-value data scalar-view callee-operand
			schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
		if auxiliary <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(operand-base-value + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar-view/operands-ordinal
		]
		reference: operand-value data scalar-view callee-operand
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = schema/WIRE_CALL_KIND_DIRECT [
				unless operand-kind = schema/WIRE_OPERAND_KIND_SYMBOL [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar-view/operands-ordinal
				]
				callee-symbol: reference
				unless all [
					callee-symbol > 0 callee-symbol <= symbols/symbol-count
					(symbol-value data symbols callee-symbol
						schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
						= schema/WIRE_SYMBOL_KIND_FUNCTION
				][
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				unless find reduce [
					schema/WIRE_LINKAGE_LOCAL
					schema/WIRE_LINKAGE_INTERNAL
					schema/WIRE_LINKAGE_EXTERNAL
					schema/WIRE_LINKAGE_WEAK
				] symbol-value data symbols callee-symbol
					schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				target-signature: symbol-value data symbols callee-symbol
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			]
			kind = schema/WIRE_CALL_KIND_IMPORT [
				unless operand-kind = schema/WIRE_OPERAND_KIND_SYMBOL [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar-view/operands-ordinal
				]
				callee-symbol: reference
				unless all [
					callee-symbol > 0 callee-symbol <= symbols/symbol-count
					(symbol-value data symbols callee-symbol
						schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
						= schema/WIRE_SYMBOL_KIND_FUNCTION
					(symbol-value data symbols callee-symbol
						schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
						= schema/WIRE_LINKAGE_IMPORT
				][
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				import-id: find-import-for-symbol data symbols callee-symbol
				unless import-id [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				target-signature: symbol-value data symbols callee-symbol
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				if (import-value data symbols import-id
					schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
					<> (signature-value data functions signature-id
						schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET) [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
						((record-offset symbols/imports-offset (import-id - 1)
							schema/WIRE_IMPORT_SIZE)
							schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
						symbols/imports-ordinal
				]
			]
			kind = schema/WIRE_CALL_KIND_INDIRECT [
				unless operand-kind = schema/WIRE_OPERAND_KIND_VALUE [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_INDIRECT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar-view/operands-ordinal
				]
				value-type: value-value data scalar-view reference
					schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless all [
					valid-type? types value-type
					(type-value data types value-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
						= schema/WIRE_TYPE_KIND_FUNCTION
				][
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_INDIRECT_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				value-signature: type-value data types value-type
					schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
				target-signature: value-signature
			]
			kind = schema/WIRE_CALL_KIND_SYSCALL [
				unless operand-kind = schema/WIRE_OPERAND_KIND_CONSTANT [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar-view/operands-ordinal
				]
				constant-id: reference
				unless all [
					constant-id > 0 constant-id <= constants/constant-count
					constant-type: constant-value data constants constant-id
						schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
					integer32-type? data types constant-type
				][
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				constant-kind: constant-value data constants constant-id
					schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
				unless find reduce [
					schema/WIRE_CONSTANT_KIND_ZERO schema/WIRE_CONSTANT_KIND_SCALAR
				] constant-kind [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				if constant-kind = schema/WIRE_CONSTANT_KIND_SCALAR [
					data-size: constant-value data constants constant-id
						schema/WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
					unless data-size = 4 [
						return reject result schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
							(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar-view/operands-ordinal
					]
				]
				if known-negative-i32-constant? data constants constant-id [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_NUMBER
						(operand-base-value + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				target-signature: signature-id
			]
			kind = schema/WIRE_CALL_KIND_SUBROUTINE [
				unless operand-kind = schema/WIRE_OPERAND_KIND_SUBROUTINE [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
						(operand-base-value + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar-view/operands-ordinal
				]
				; The subroutine layer validates ownership and the declared signature.
				target-signature: signature-id
			]
			true [
				return reject result schema/WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
					(base + schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
					call-view/calls-ordinal
			]
		]
		unless all [
			target-signature > 0 target-signature <= functions/signature-count
			target-signature = signature-id
		][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_TARGET_SIGNATURE
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		cc: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
		if all [kind = schema/WIRE_CALL_KIND_SYSCALL
			cc <> schema/WIRE_CALLING_CONVENTION_SYSCALL][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		if all [kind <> schema/WIRE_CALL_KIND_SYSCALL
			cc = schema/WIRE_CALLING_CONVENTION_SYSCALL][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
				call-view/calls-ordinal
		]
		none
	]

	verify-call: func [
		data [binary!] result [object!] call-view [object!]
		control-result [object!] call-id [integer!] instruction-id [integer!]
		/local scalar-view functions symbols constants types base signature-id kind
			callee-operand first-argument argument-count instruction-first instruction-count
			operand-id operand-kind auxiliary argument-type parameter-type
			parameter-count first-parameter
			variable-mode cc flags effect alias-kind alias-id result-count result-type
			result-id return-type return-kind custom? typed? variadic? c-variadic?
			non-c-variadic?
			failure known-negative remaining argument-index error-code
		][
		scalar-view: control-result/scalar-view
		functions: control-result/functions
		symbols: control-result/symbols
		constants: control-result/constants
		types: control-result/types
		base: call-base call-view call-id
		signature-id: call-value data call-view call-id
			schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET
		if any [signature-id <= 0 signature-id > functions/signature-count][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_TARGET_SIGNATURE
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		kind: call-value data call-view call-id
			schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
		if kind = schema/WIRE_CALL_KIND_CUSTOM [
			return reject result schema/WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
				(base + schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
				call-view/calls-ordinal
		]
		unless find reduce [
			schema/WIRE_CALL_KIND_DIRECT schema/WIRE_CALL_KIND_INDIRECT
			schema/WIRE_CALL_KIND_IMPORT schema/WIRE_CALL_KIND_SYSCALL
			schema/WIRE_CALL_KIND_SUBROUTINE
		] kind [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_KIND
				(base + schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
				call-view/calls-ordinal
		]
		if (call-value data call-view call-id schema/WIRE_RSIR_CALL_FLAGS_OFFSET) <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_NONZERO_CALL_FLAGS
				(base + schema/WIRE_RSIR_CALL_FLAGS_OFFSET) call-view/calls-ordinal
		]
		if (call-value data call-view call-id schema/WIRE_RSIR_CALL_RESERVED_OFFSET) <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_NONZERO_CALL_RESERVED
				(base + schema/WIRE_RSIR_CALL_RESERVED_OFFSET) call-view/calls-ordinal
		]
		callee-operand: call-value data call-view call-id
			schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
		instruction-first: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		instruction-count: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if any [instruction-count < 1 callee-operand <> instruction-first][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
				(base + schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET)
				call-view/calls-ordinal
		]
		first-argument: call-value data call-view call-id
			schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
		argument-count: call-value data call-view call-id
			schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
		if any [argument-count < 0 argument-count <> (instruction-count - 1)][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_COUNT
				(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
				call-view/calls-ordinal
		]
		either argument-count = 0 [
			if first-argument <> 0 [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_OPERAND_RANGE
					(base + schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET)
					call-view/calls-ordinal
			]
		][
			unless first-argument = (instruction-first + 1) [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_OPERAND_RANGE
					(base + schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET)
					call-view/calls-ordinal
			]
		]
		failure: verify-callee data result call-view scalar-view functions symbols
			constants types call-id signature-id kind callee-operand
		if failure [return failure]

		; Calls are conservative memory/safepoint barriers. The exception layer
		; later gives THROW edges their stack-state meaning.
		flags: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
		if flags <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_FLAGS
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		if (instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET) <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_SUBOPCODE
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
				scalar-view/instructions-ordinal
		]
		effect: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
		alias-kind: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
		alias-id: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
		unless all [
			(alias-kind = schema/WIRE_ALIAS_KIND_UNIVERSAL) alias-id = 0
		][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ALIAS
				(instruction-field-offset scalar-view instruction-id
					either alias-kind = schema/WIRE_ALIAS_KIND_UNIVERSAL
					[schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET]
					[schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET])
				scalar-view/instructions-ordinal
		]
		return-type: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
		result-count: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
		either (type-value data types return-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
			= schema/WIRE_TYPE_KIND_VOID [
			if result-count <> 0 [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_COUNT
					(instruction-field-offset scalar-view instruction-id
						schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
					scalar-view/instructions-ordinal
			]
		][
			if result-count <> 1 [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_COUNT
					(instruction-field-offset scalar-view instruction-id
						schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
					scalar-view/instructions-ordinal
			]
			result-id: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
			result-type: value-value data scalar-view result-id
				schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			unless result-type = return-type [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_TYPE
					((value-base scalar-view result-id)
						+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
					scalar-view/values-ordinal
			]
		]

		flags: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		variable-mode: flags and variable-mode-mask
		custom?: variable-mode = schema/WIRE_FUNCTION_FLAG_CUSTOM
		typed?: variable-mode = schema/WIRE_FUNCTION_FLAG_TYPED
		variadic?: variable-mode = schema/WIRE_FUNCTION_FLAG_VARIADIC
		cc: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
		c-variadic?: all [variadic? cc = schema/WIRE_CALLING_CONVENTION_CDECL]
		non-c-variadic?: all [variadic? not c-variadic?]
		parameter-count: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
		first-parameter: signature-value data functions signature-id
			schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET

		if custom? [
			unless argument-count = 1 [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CUSTOM_ARGUMENTS
					(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
					call-view/calls-ordinal
			]
		]
		if typed? [
			if cc = schema/WIRE_CALLING_CONVENTION_SYSCALL [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_TYPED_ARGUMENTS
					(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
					call-view/calls-ordinal
			]
		]
		if non-c-variadic? [
			if cc = schema/WIRE_CALLING_CONVENTION_SYSCALL [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
					(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
					call-view/calls-ordinal
			]
		]
		if all [not custom? not typed? not variadic?
			argument-count <> parameter-count][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_COUNT
				(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
				call-view/calls-ordinal
		]
		if c-variadic? [
			if argument-count < parameter-count [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
					(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
					call-view/calls-ordinal
			]
		]

		operand-id: first-argument
		remaining: argument-count
		argument-index: 0
		while [remaining > 0][
			operand-kind: operand-value data scalar-view operand-id
				schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			unless find reduce [
				schema/WIRE_OPERAND_KIND_VALUE schema/WIRE_OPERAND_KIND_CONSTANT
			] operand-kind [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_KIND
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
					scalar-view/operands-ordinal
			]
			auxiliary: operand-value data scalar-view operand-id
				schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
			if auxiliary <> 0 [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_KIND
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
					scalar-view/operands-ordinal
			]
			argument-type: operand-type data scalar-view constants operand-id
			unless nonvoid-type? data types argument-type [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_TYPE
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar-view/operands-ordinal
			]
			if all [
				cc = schema/WIRE_CALLING_CONVENTION_SYSCALL
				aggregate-type? data types argument-type
			][
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_ARGUMENT
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar-view/operands-ordinal
			]
			if all [
				cc = schema/WIRE_CALLING_CONVENTION_SYSCALL
				not syscall-type? data types argument-type
			][
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar-view/operands-ordinal
			]
			if custom? [
				unless integer32-type? data types argument-type [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CUSTOM_ARGUMENTS
						(operand-field-offset scalar-view operand-id
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				known-negative: known-negative-i32-operand? data scalar-view constants
					operand-id
				if known-negative = true [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_VALUE
						(operand-field-offset scalar-view operand-id
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
			]
			if all [
				not custom?
				not typed?
				not non-c-variadic?
				argument-index < parameter-count
			][
				parameter-type: parameter-value data functions
					(first-parameter + argument-index)
					schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
				unless argument-type = parameter-type [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_TYPE
						(operand-field-offset scalar-view operand-id
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
			]
			if all [c-variadic? argument-index >= parameter-count
				(type-value data types argument-type schema/WIRE_RSIR_TYPE_KIND_OFFSET)
					= schema/WIRE_TYPE_KIND_FLOAT
				(type-value data types argument-type schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 4][
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar-view/operands-ordinal
			]
			if any [typed? non-c-variadic?][
				unless packable-type? data types argument-type [
					error-code: either typed? [
						schema/WIRE_CALL_ABI_ERROR_BAD_TYPED_ARGUMENTS
					][
						schema/WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
					]
					return reject result error-code
					(operand-field-offset scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
					scalar-view/operands-ordinal
				]
			]
			remaining: remaining - 1
			argument-index: argument-index + 1
			operand-id: operand-id + 1
		]

		; Signature declaration flags and target ABI must agree with the call kind.
		if all [kind = schema/WIRE_CALL_KIND_SYSCALL
			(flags and (variable-mode-mask
				+ schema/WIRE_FUNCTION_FLAG_CALLBACK)) <> 0][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		return-kind: type-value data types return-type schema/WIRE_RSIR_TYPE_KIND_OFFSET
		if all [
			cc = schema/WIRE_CALLING_CONVENTION_SYSCALL
			aggregate-type? data types return-type
		][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_RETURN
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		if all [
			cc = schema/WIRE_CALLING_CONVENTION_SYSCALL
			return-kind <> schema/WIRE_TYPE_KIND_VOID
			not syscall-type? data types return-type
		][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
				(base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
				call-view/calls-ordinal
		]
		if all [custom? (effect and schema/WIRE_EFFECT_FLAG_STACK) = 0][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		if all [not custom? (effect and schema/WIRE_EFFECT_FLAG_STACK) <> 0][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		unless all [
			(effect and schema/WIRE_EFFECT_FLAG_CALL) <> 0
			(effect and schema/WIRE_EFFECT_FLAG_READ) <> 0
			(effect and schema/WIRE_EFFECT_FLAG_WRITE) <> 0
			(effect and schema/WIRE_EFFECT_FLAG_MAY_TRAP) <> 0
			(effect and schema/WIRE_EFFECT_FLAG_SAFEPOINT) <> 0
			(effect and allowed-call-effects) = effect
		][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_EFFECTS
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		if all [(flags and schema/WIRE_FUNCTION_FLAG_MAY_THROW) = 0
			(effect and schema/WIRE_EFFECT_FLAG_THROW) <> 0][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		if all [(flags and schema/WIRE_FUNCTION_FLAG_MAY_THROW) <> 0
			(effect and schema/WIRE_EFFECT_FLAG_THROW) = 0][
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
				(instruction-field-offset scalar-view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
				scalar-view/instructions-ordinal
		]
		none
	]

	verify: func [data /local result control-result container-result calls
		control-view scalar-view call-view record-index record-base field-name field-offset
		value call-id instruction-id previous-instruction opcode failure header][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_CALL_ABI_ERROR_INVALID_ARGUMENTS 0 0
		]
		control-result: control-verifier/verify data
		inherit-control-result result control-result
		unless control-result/valid? [
			return reject result schema/WIRE_CALL_ABI_ERROR_INVALID_CONTROL_FLOW
				control-result/error-offset control-result/error-section
		]
		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		calls: container/find-section container-result schema/WIRE_RSIR_SECTION_CALLS
		if none? calls [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_CALL_ABI_ERROR_INVALID_CONTROL_FLOW
				schema/WIRE_HEADER_SIZE 0
		]
		if (select calls 'flags) <> 0 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_SECTION_FLAGS
				(section-flags-offset calls) (select calls 'ordinal)
		]
		call-view: make-view
		call-view/calls-offset: select calls 'payload-offset
		call-view/call-count: select calls 'record-count
		call-view/call-record-size: select calls 'record-size
		call-view/calls-ordinal: select calls 'ordinal
		control-view: control-result/view
		scalar-view: control-result/scalar-view
		header: control-result/header
		unless (select header 'target) = schema/WIRE_TARGET_X86_64 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
				schema/WIRE_HEADER_TARGET_OFFSET 0
		]
		unless (select header 'abi) = schema/WIRE_ABI_WIN64 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
				schema/WIRE_HEADER_ABI_OFFSET 0
		]
		unless (select header 'target-endian) = schema/WIRE_ENDIAN_LITTLE [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
				schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0
		]
		unless (select header 'pointer-size) = 8 [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_ABI
				schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0
		]

		record-index: 0
		while [record-index < call-view/call-count][
			record-base: call-base call-view (record-index + 1)
			foreach [field-name field-offset] call-fields [
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_CALL_ABI_ERROR_SCALAR_RANGE
						(record-base + field-offset) call-view/calls-ordinal
				]
			]
			record-index: record-index + 1
		]

		; Each record points at a CALL, and record order is strictly increasing.
		call-id: 1
		previous-instruction: 0
		while [call-id <= call-view/call-count][
			record-base: call-base call-view call-id
			instruction-id: call-value data call-view call-id
				schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET
			if any [
				instruction-id <= 0
				instruction-id > scalar-view/instruction-count
			][
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_INSTRUCTION
					(record-base + schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					call-view/calls-ordinal
			]
			if instruction-id <= previous-instruction [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ORDER
					(record-base + schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					call-view/calls-ordinal
			]
			opcode: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode <> schema/WIRE_OPCODE_CALL [
				return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_INSTRUCTION
					(record-base + schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
					call-view/calls-ordinal
			]
			previous-instruction: instruction-id
			call-id: call-id + 1
		]

		; CALL records and CALL instructions form the same complete partition.
		call-id: 1
		instruction-id: 1
		while [instruction-id <= scalar-view/instruction-count][
			opcode: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode = schema/WIRE_OPCODE_CALL [
				if call-id > call-view/call-count [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
						(instruction-field-offset scalar-view instruction-id
							schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar-view/instructions-ordinal
				]
				if (call-value data call-view call-id
					schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET) <> instruction-id [
					return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
						(instruction-field-offset scalar-view instruction-id
							schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar-view/instructions-ordinal
				]
				failure: verify-call data result call-view control-result
					call-id instruction-id
				if failure [return failure]
				call-id: call-id + 1
			]
			instruction-id: instruction-id + 1
		]
		if call-id <= call-view/call-count [
			return reject result schema/WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
				(call-field-offset call-view call-id
					schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
				call-view/calls-ordinal
		]

		result/strings: control-result/strings
		result/files: control-result/files
		result/layout: control-result/layout
		result/types: control-result/types
		result/functions: control-result/functions
		result/modules: control-result/modules
		result/symbols: control-result/symbols
		result/constants: control-result/constants
		result/control-view: control-view
		result/scalar-view: scalar-view
		result/view: call-view
		result/valid?: true
		result
	]
]
