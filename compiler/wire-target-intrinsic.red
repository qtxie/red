Red [
	Title: "Hybrid compiler RSIR target-intrinsic verifier"
	File:  %wire-target-intrinsic.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-stack [do %wire-stack.red]

compiler-wire-target-intrinsic: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	stack-verifier: compiler-wire-stack

	port-read-effects:
		schema/WIRE_EFFECT_FLAG_READ
		+ schema/WIRE_EFFECT_FLAG_VOLATILE
		+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
	port-write-effects:
		schema/WIRE_EFFECT_FLAG_WRITE
		+ schema/WIRE_EFFECT_FLAG_VOLATILE
		+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
	fragment-effects:
		schema/WIRE_EFFECT_FLAG_READ
		+ schema/WIRE_EFFECT_FLAG_WRITE
		+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
		+ schema/WIRE_EFFECT_FLAG_CONTROL
		+ schema/WIRE_EFFECT_FLAG_OPAQUE
	opaque-effects: schema/WIRE_EFFECT_FLAG_OPAQUE

	fragment-fields: reduce [
		'target          schema/WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET
		'abi             schema/WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET
		'data-offset     schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET
		'data-size       schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET
		'return-type     schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
		'effect-flags    schema/WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET
		'clobber-class   schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET
		'source-location schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET
	]

	make-view: does [
		make object! [
			target-fragments-offset: 0
			target-fragment-count: 0
			target-fragment-record-size: schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE
			target-fragments-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
			stack-error: schema/WIRE_STACK_ERROR_SUCCESS
			exception-error: schema/WIRE_EXCEPTION_ERROR_SUCCESS
			subroutine-error: schema/WIRE_SUBROUTINE_ERROR_SUCCESS
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
			subroutine-view: none
			exception-view: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-stack-result: func [result stack-result [object!]][
		result/header: stack-result/header
		result/stack-error: stack-result/error
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
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data (base + ((id - 1) * size) + field)
	]

	fragment-base: func [view [object!] id [integer!]][
		view/target-fragments-offset + ((id - 1) * schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE)
	]

	fragment-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/target-fragments-offset
			schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE id field
	]

	instruction-value: func [data [binary!] scalar [object!] id field [integer!]][
		stack-verifier/instruction-value data scalar id field
	]

	operand-value: func [data [binary!] scalar [object!] id field [integer!]][
		stack-verifier/operand-value data scalar id field
	]

	value-value: func [data [binary!] scalar [object!] id field [integer!]][
		stack-verifier/value-value data scalar id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		stack-verifier/constant-value data constants id field
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		stack-verifier/type-value data types id field
	]

	call-value: func [data [binary!] calls [object!] id field [integer!]][
		stack-verifier/call-value data calls id field
	]

	instruction-base: func [scalar [object!] id [integer!]][
		stack-verifier/instruction-base scalar id
	]

	operand-base: func [scalar [object!] id [integer!]][
		stack-verifier/operand-base scalar id
	]

	value-base: func [scalar [object!] id [integer!]][
		scalar/values-offset + ((id - 1) * schema/WIRE_RSIR_VALUE_SIZE)
	]

	call-base: func [calls [object!] id [integer!]][
		calls/calls-offset + ((id - 1) * schema/WIRE_RSIR_CALL_SIZE)
	]

	valid-type?: func [types [object!] id [integer!]][
		all [id > 0 id <= types/type-count]
	]

	plain-u8?: func [data [binary!] types [object!] id [integer!]][
		all [
			valid-type? types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_INTEGER
			(type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 1
			(type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET) = 0
		]
	]

	plain-signed-i32?: func [data [binary!] types [object!] id [integer!]][
		all [
			valid-type? types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_INTEGER
			(type-value data types id schema/WIRE_RSIR_TYPE_SIZE_OFFSET) = 4
			(type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET)
				= schema/WIRE_TYPE_FLAG_SIGNED
		]
	]

	ordinary-pointer-detail: func [
		data [binary!] types [object!] id [integer!]
	][
		unless all [
			valid-type? types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_POINTER
			(type-value data types id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET) = 0
		][return none]
		type-value data types id schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
	]

	port-pointee-type: func [
		data [binary!] types [object!] pointer-type [integer!]
		/local detail
	][
		detail: ordinary-pointer-detail data types pointer-type
		unless integer? detail [return none]
		either any [
			plain-u8? data types detail
			plain-signed-i32? data types detail
		][detail][none]
	]

	pointer-to-u8?: func [data [binary!] types [object!] id [integer!] /local detail][
		detail: ordinary-pointer-detail data types id
		all [integer? detail plain-u8? data types detail]
	]

	cpu-register-type?: func [
		data [binary!] types [object!] id [integer!] /local detail
	][
		detail: ordinary-pointer-detail data types id
		all [integer? detail plain-signed-i32? data types detail]
	]

	fragment-return-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			valid-type? types id
			find reduce [
				schema/WIRE_TYPE_KIND_VOID
				schema/WIRE_TYPE_KIND_LOGIC
				schema/WIRE_TYPE_KIND_INTEGER
				schema/WIRE_TYPE_KIND_FLOAT
				schema/WIRE_TYPE_KIND_POINTER
				schema/WIRE_TYPE_KIND_FUNCTION
			] type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET
		]
	]

	operand-type: func [
		data [binary!] scalar constants [object!] operand-id [integer!]
		/local kind reference
	][
		kind: operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		reference: operand-value data scalar operand-id
			schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
		case [
			kind = schema/WIRE_OPERAND_KIND_VALUE [
				value-value data scalar reference schema/WIRE_RSIR_VALUE_TYPE_OFFSET
			]
			kind = schema/WIRE_OPERAND_KIND_CONSTANT [
				constant-value data constants reference schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
			]
			true [none]
		]
	]

	validate-fragments: func [
		data [binary!] result stack-result view [object!]
		/local constants types files header fragment-id base field-name field-offset
			value target abi data-offset data-size finish return-type effects clobber
			source-location cursor
	][
		constants: stack-result/constants
		types: stack-result/types
		files: stack-result/files
		header: stack-result/header

		fragment-id: 1
		while [fragment-id <= view/target-fragment-count][
			base: fragment-base view fragment-id
			foreach [field-name field-offset] fragment-fields [
				value: container/read-i31 data (base + field-offset)
				if none? value [
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_SCALAR_RANGE
						(base + field-offset) view/target-fragments-ordinal
				]
			]
			fragment-id: fragment-id + 1
		]

		cursor: constants/constant-data-owned-size
		fragment-id: 1
		while [fragment-id <= view/target-fragment-count][
			base: fragment-base view fragment-id
			target: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET
			if target <> (select header 'target) [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_TARGET
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET)
					view/target-fragments-ordinal
			]
			abi: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET
			if abi <> (select header 'abi) [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_ABI
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET)
					view/target-fragments-ordinal
			]
			data-offset: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET
			if data-offset <> cursor [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_OFFSET
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET)
					view/target-fragments-ordinal
			]
			data-size: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET
			if data-size <= 0 [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_SIZE
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET)
					view/target-fragments-ordinal
			]
			finish: container/checked-add data-offset data-size
			if any [none? finish finish > constants/constant-data-size][
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_RANGE
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET)
					view/target-fragments-ordinal
			]
			return-type: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
			unless fragment-return-type? data types return-type [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_RETURN_TYPE
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET)
					view/target-fragments-ordinal
			]
			effects: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET
			if effects <> fragment-effects [
				return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_EFFECTS
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET)
					view/target-fragments-ordinal
			]
			clobber: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET
			if clobber <> schema/WIRE_TARGET_CLOBBER_CLASS_WIN64_VOLATILE [
				return reject result
					schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_CLOBBER_CLASS
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET)
					view/target-fragments-ordinal
			]
			source-location: fragment-value data view fragment-id
				schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET
			if source-location > files/source-count [
				return reject result
					schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SOURCE_LOCATION
					(base + schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET)
					view/target-fragments-ordinal
			]
			cursor: finish
			fragment-id: fragment-id + 1
		]

		if cursor <> constants/constant-data-size [
			return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_COVERAGE
				(constants/constant-data-offset + cursor) constants/constant-data-ordinal
		]
		none
	]

	validate-instructions: func [
		data [binary!] result stack-result view [object!]
		/local scalar constants types instruction-id opcode base subopcode flags effects
			expected-effects alias-kind alias-id expected-alias operand-count result-count
			expected-operands expected-results first-operand operand-index operand-id kind
			auxiliary pointer-type pointee-type data-type first-result result-type
			fragment-id reference return-type return-kind expected-result-count
			source-location fragment-source
	][
		scalar: stack-result/scalar-view
		constants: stack-result/constants
		types: stack-result/types
		fragment-id: 1
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if find reduce [
				schema/WIRE_OPCODE_PORT_READ
				schema/WIRE_OPCODE_PORT_WRITE
				schema/WIRE_OPCODE_GET_PC
				schema/WIRE_OPCODE_TARGET_FRAGMENT
				schema/WIRE_OPCODE_CPU_REGISTER_READ
				schema/WIRE_OPCODE_CPU_REGISTER_WRITE
			] opcode [
				base: instruction-base scalar instruction-id
				subopcode: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
				either any [
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_READ
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_WRITE
				][
					unless all [
						subopcode >= schema/WIRE_X64_REGISTER_RAX
						subopcode <= schema/WIRE_X64_REGISTER_R15
					][
						return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER
							(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
					if all [
						opcode = schema/WIRE_OPCODE_CPU_REGISTER_WRITE
						any [
							subopcode = schema/WIRE_X64_REGISTER_RSP
							subopcode = schema/WIRE_X64_REGISTER_RBP
						]
					][
						return reject result
							schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_WRITE
							(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if subopcode <> 0 [
						return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_SUBOPCODE
							(base + schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET)
							scalar/instructions-ordinal
					]
				]

				flags: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
				if flags <> 0 [
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_INSTRUCTION_FLAGS
						(base + schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				expected-effects: case [
					opcode = schema/WIRE_OPCODE_PORT_READ [port-read-effects]
					opcode = schema/WIRE_OPCODE_PORT_WRITE [port-write-effects]
					opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [fragment-effects]
					true [opaque-effects]
				]
				effects: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				if effects <> expected-effects [
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_EFFECTS
						(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
						scalar/instructions-ordinal
				]
				expected-alias: either opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [
					schema/WIRE_ALIAS_KIND_UNIVERSAL
				][schema/WIRE_ALIAS_KIND_NONE]
				alias-kind: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				alias-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
				unless all [alias-kind = expected-alias alias-id = 0][
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_ALIAS
						(base + either alias-kind <> expected-alias [
							schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
						][schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET])
						scalar/instructions-ordinal
				]

				expected-operands: case [
					opcode = schema/WIRE_OPCODE_PORT_READ [1]
					opcode = schema/WIRE_OPCODE_PORT_WRITE [2]
					opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [1]
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_WRITE [1]
					true [0]
				]
				expected-results: case [
					opcode = schema/WIRE_OPCODE_PORT_READ [1]
					opcode = schema/WIRE_OPCODE_GET_PC [1]
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_READ [1]
					opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [-1]
					true [0]
				]
				operand-count: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
				if operand-count <> expected-operands [
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar/instructions-ordinal
				]
				result-count: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
				if any [
					all [expected-results >= 0 result-count <> expected-results]
					all [expected-results < 0 result-count > 1]
				][
					return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_RESULT_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
						scalar/instructions-ordinal
				]

				first-operand: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				operand-index: 0
				while [operand-index < expected-operands][
					operand-id: first-operand + operand-index
					kind: operand-value data scalar operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
					either opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [
						unless kind = schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT [
							return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_KIND
								((operand-base scalar operand-id)
									+ schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
								scalar/operands-ordinal
						]
					][
						unless any [
							kind = schema/WIRE_OPERAND_KIND_VALUE
							kind = schema/WIRE_OPERAND_KIND_CONSTANT
						][
							return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_KIND
								((operand-base scalar operand-id)
									+ schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
								scalar/operands-ordinal
						]
					]
					auxiliary: operand-value data scalar operand-id
						schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
					if auxiliary <> 0 [
						return reject result
							schema/WIRE_TARGET_INTRINSIC_ERROR_NONZERO_OPERAND_AUXILIARY
							((operand-base scalar operand-id)
								+ schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
							scalar/operands-ordinal
					]
					operand-index: operand-index + 1
				]

				case [
					any [
						opcode = schema/WIRE_OPCODE_PORT_READ
						opcode = schema/WIRE_OPCODE_PORT_WRITE
					][
						pointer-type: operand-type data scalar constants first-operand
						pointee-type: either integer? pointer-type [
							port-pointee-type data types pointer-type
						][none]
						unless integer? pointee-type [
							return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_PORT_TYPE
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						either opcode = schema/WIRE_OPCODE_PORT_READ [
							first-result: instruction-value data scalar instruction-id
								schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
							result-type: value-value data scalar first-result
								schema/WIRE_RSIR_VALUE_TYPE_OFFSET
							if result-type <> pointee-type [
								return reject result
									schema/WIRE_TARGET_INTRINSIC_ERROR_PORT_TYPE_MISMATCH
									((value-base scalar first-result)
										+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
									scalar/values-ordinal
							]
						][
							data-type: operand-type data scalar constants (first-operand + 1)
							if data-type <> pointee-type [
								return reject result
									schema/WIRE_TARGET_INTRINSIC_ERROR_PORT_TYPE_MISMATCH
									((operand-base scalar (first-operand + 1))
										+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar/operands-ordinal
							]
						]
					]
					opcode = schema/WIRE_OPCODE_GET_PC [
						first-result: instruction-value data scalar instruction-id
							schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
						result-type: value-value data scalar first-result
							schema/WIRE_RSIR_VALUE_TYPE_OFFSET
						unless pointer-to-u8? data types result-type [
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_GET_PC_RESULT_TYPE
								((value-base scalar first-result)
									+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
								scalar/values-ordinal
						]
					]
					opcode = schema/WIRE_OPCODE_TARGET_FRAGMENT [
						reference: operand-value data scalar first-operand
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						if any [
							fragment-id > view/target-fragment-count
							reference <> fragment-id
						][
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_REFERENCE
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
						return-type: fragment-value data view fragment-id
							schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
						return-kind: type-value data types return-type
							schema/WIRE_RSIR_TYPE_KIND_OFFSET
						expected-result-count: either return-kind = schema/WIRE_TYPE_KIND_VOID [0][1]
						if result-count <> expected-result-count [
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_RETURN_MISMATCH
								(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
								scalar/instructions-ordinal
						]
						if result-count = 1 [
							first-result: instruction-value data scalar instruction-id
								schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
							result-type: value-value data scalar first-result
								schema/WIRE_RSIR_VALUE_TYPE_OFFSET
							if result-type <> return-type [
								return reject result
									schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_RETURN_MISMATCH
									((value-base scalar first-result)
										+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
									scalar/values-ordinal
							]
						]
						source-location: instruction-value data scalar instruction-id
							schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET
						fragment-source: fragment-value data view fragment-id
							schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET
						if source-location <> fragment-source [
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SOURCE_LOCATION
								(base + schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET)
								scalar/instructions-ordinal
						]
						fragment-id: fragment-id + 1
					]
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_READ [
						first-result: instruction-value data scalar instruction-id
							schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
						result-type: value-value data scalar first-result
							schema/WIRE_RSIR_VALUE_TYPE_OFFSET
						unless cpu-register-type? data types result-type [
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_TYPE
								((value-base scalar first-result)
									+ schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
								scalar/values-ordinal
						]
					]
					opcode = schema/WIRE_OPCODE_CPU_REGISTER_WRITE [
						data-type: operand-type data scalar constants first-operand
						unless all [
							integer? data-type
							cpu-register-type? data types data-type
						][
							return reject result
								schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_TYPE
								((operand-base scalar first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar/operands-ordinal
						]
					]
					true []
				]
			]
			instruction-id: instruction-id + 1
		]

		if (fragment-id - 1) <> view/target-fragment-count [
			return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_COVERAGE
				(fragment-base view fragment-id) view/target-fragments-ordinal
		]
		none
	]

	validate-syscalls: func [
		data [binary!] result stack-result [object!]
		/local calls call-id kind argument-count base
	][
		calls: stack-result/call-view
		call-id: 1
		while [call-id <= calls/call-count][
			kind: call-value data calls call-id schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
			if kind = schema/WIRE_CALL_KIND_SYSCALL [
				argument-count: call-value data calls call-id
					schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
				if argument-count > 6 [
					base: call-base calls call-id
					return reject result
						schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_SYSCALL_ARGUMENT_COUNT
						(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
						calls/calls-ordinal
				]
			]
			call-id: call-id + 1
		]
		none
	]

	verify: func [
		data
		/local result stack-result container-result fragments view failure
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_ARGUMENTS 0 0
		]
		stack-result: stack-verifier/verify data
		inherit-stack-result result stack-result
		unless stack-result/valid? [
			return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_STACK
				stack-result/error-offset stack-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		fragments: container/find-section container-result
			schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS
		if none? fragments [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_STACK
				schema/WIRE_HEADER_SIZE 0
		]
		if (select fragments 'flags) <> 0 [
			return reject result
				schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SECTION_FLAGS
				(section-flags-offset fragments) (select fragments 'ordinal)
		]

		view: make-view
		view/target-fragments-offset: select fragments 'payload-offset
		view/target-fragment-count: select fragments 'record-count
		view/target-fragment-record-size: select fragments 'record-size
		view/target-fragments-ordinal: select fragments 'ordinal

		failure: validate-fragments data result stack-result view
		if failure [return failure]
		failure: validate-instructions data result stack-result view
		if failure [return failure]
		failure: validate-syscalls data result stack-result
		if failure [return failure]

		result/strings: stack-result/strings
		result/files: stack-result/files
		result/layout: stack-result/layout
		result/types: stack-result/types
		result/functions: stack-result/functions
		result/modules: stack-result/modules
		result/symbols: stack-result/symbols
		result/constants: stack-result/constants
		result/scalar-view: stack-result/scalar-view
		result/control-view: stack-result/control-view
		result/call-view: stack-result/call-view
		result/subroutine-view: stack-result/subroutine-view
		result/exception-view: stack-result/exception-view
		result/view: view
		result/valid?: true
		result
	]
]
