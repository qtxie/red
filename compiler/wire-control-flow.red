Red [
	Title: "Hybrid compiler RSIR control-flow verifier"
	File:  %wire-control-flow.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-scalar-operation [do %wire-scalar-operation.red]

compiler-wire-control-flow: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	scalar-verifier: compiler-wire-scalar-operation

	edge-fields: reduce [
		'source-block schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
		'target-block schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
		'kind schema/WIRE_RSIR_EDGE_KIND_OFFSET
		'selector-constant schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
		'ordinal schema/WIRE_RSIR_EDGE_ORDINAL_OFFSET
		'flags schema/WIRE_RSIR_EDGE_FLAGS_OFFSET
	]

	make-view: does [
		make object! [
			edges-offset: 0
			edge-count: 0
			edge-record-size: schema/WIRE_RSIR_EDGE_SIZE
			edges-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_CONTROL_FLOW_ERROR_SUCCESS
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
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-scalar-result: func [result scalar-result [object!]][
		result/header: scalar-result/header
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
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	edge-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/edges-offset schema/WIRE_RSIR_EDGE_SIZE id field
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

	function-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/functions-offset schema/WIRE_RSIR_FUNCTION_SIZE id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/signatures-offset schema/WIRE_RSIR_SIGNATURE_SIZE id field
	]

	block-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/blocks-offset schema/WIRE_RSIR_BLOCK_SIZE id field
	]

	constant-value: func [data [binary!] constants [object!] id field [integer!]][
		record-value data constants/constants-offset schema/WIRE_RSIR_CONSTANT_SIZE id field
	]

	instruction-base: func [view [object!] id [integer!]][
		view/instructions-offset + ((id - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [view [object!] id [integer!]][
		view/operands-offset + ((id - 1) * schema/WIRE_RSIR_OPERAND_SIZE)
	]

	edge-base: func [view [object!] id [integer!]][
		view/edges-offset + ((id - 1) * schema/WIRE_RSIR_EDGE_SIZE)
	]

	block-base: func [functions [object!] id [integer!]][
		functions/blocks-offset + ((id - 1) * schema/WIRE_RSIR_BLOCK_SIZE)
	]

	terminator?: func [opcode [integer!]][
		find reduce [
			schema/WIRE_OPCODE_BRANCH schema/WIRE_OPCODE_JUMP
			schema/WIRE_OPCODE_SWITCH schema/WIRE_OPCODE_RETURN
			schema/WIRE_OPCODE_THROW schema/WIRE_OPCODE_UNREACHABLE
			schema/WIRE_OPCODE_SUBROUTINE_RETURN
		] opcode
	]

	owned-terminator?: func [opcode [integer!]][
		find reduce [
			schema/WIRE_OPCODE_BRANCH schema/WIRE_OPCODE_JUMP
			schema/WIRE_OPCODE_SWITCH schema/WIRE_OPCODE_RETURN
			schema/WIRE_OPCODE_UNREACHABLE schema/WIRE_OPCODE_SUBROUTINE_RETURN
		] opcode
	]

	ordinary-edge?: func [kind [integer!]][kind <> schema/WIRE_EDGE_KIND_EXCEPTION]

	verify-common-terminator: func [
		data [binary!] result [object!] scalar-view [object!] instruction-id [integer!]
		/local base value
	][
		base: instruction-base scalar-view instruction-id
		foreach [field code expected] reduce [
			schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_SUBOPCODE 0
			schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_INSTRUCTION_FLAGS 0
			schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_EFFECTS
				schema/WIRE_EFFECT_FLAG_CONTROL
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_ALIAS schema/WIRE_ALIAS_KIND_NONE
			schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_ALIAS 0
			schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
				schema/WIRE_CONTROL_FLOW_ERROR_BAD_RESULT_COUNT 0
		][
			value: instruction-value data scalar-view instruction-id field
			if value <> expected [
				return reject result code (base + field) scalar-view/instructions-ordinal
			]
		]
		none
	]

	verify-operand-shape: func [
		data [binary!] result [object!] scalar-view [object!]
		operand-id expected-kind [integer!]
		/local base kind auxiliary
	][
		base: operand-base scalar-view operand-id
		kind: operand-value data scalar-view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
		if kind <> expected-kind [
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_KIND
				(base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
				scalar-view/operands-ordinal
		]
		auxiliary: operand-value data scalar-view operand-id
			schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
		if auxiliary <> 0 [
			return reject result
				schema/WIRE_CONTROL_FLOW_ERROR_NONZERO_OPERAND_AUXILIARY
				(base + schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET)
				scalar-view/operands-ordinal
		]
		none
	]

	ordinary-edge-count: func [
		data [binary!] control-view [object!] functions [object!] block-id [integer!]
		/local first count index kind
	][
		first: block-value data functions block-id
			schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		count: block-value data functions block-id
			schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
		index: 0
		while [index < count][
			kind: edge-value data control-view (first + index)
				schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if kind = schema/WIRE_EDGE_KIND_EXCEPTION [return index]
			index: index + 1
		]
		count
	]

	constant-byte: func [
		data [binary!] constants [object!] constant-id index [integer!]
		/local kind relative
	][
		kind: constant-value data constants constant-id schema/WIRE_RSIR_CONSTANT_KIND_OFFSET
		if kind = schema/WIRE_CONSTANT_KIND_ZERO [return 0]
		relative: constant-value data constants constant-id
			schema/WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
		to integer! pick data (constants/constant-data-offset + relative + index + 1)
	]

	same-switch-constant?: func [
		data [binary!] constants [object!] types [object!] left right [integer!]
		/local left-type right-type size index
	][
		left-type: constant-value data constants left schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
		right-type: constant-value data constants right schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
		if left-type <> right-type [return false]
		size: type-value data types left-type schema/WIRE_RSIR_TYPE_SIZE_OFFSET
		index: 0
		while [index < size][
			if (constant-byte data constants left index)
				<> (constant-byte data constants right index)
			[return false]
			index: index + 1
		]
		true
	]

	verify-terminator: func [
		data [binary!] result [object!] scalar-result [object!]
		control-view [object!] block-id instruction-id [integer!]
		/local scalar-view functions types constants opcode base first-operand
			operand-count ordinary-count first-edge failure operand-id reference
			type-id owner-function signature-id signature-flags return-type
			case-count case-index prior-index constant-id prior-constant edge-id
			expected-kind expected-target outgoing-count
	][
		scalar-view: scalar-result/view
		functions: scalar-result/functions
		types: scalar-result/types
		constants: scalar-result/constants
		opcode: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		base: instruction-base scalar-view instruction-id
		first-operand: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		operand-count: instruction-value data scalar-view instruction-id
			schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		ordinary-count: ordinary-edge-count data control-view functions block-id
		first-edge: block-value data functions block-id
			schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET

		if owned-terminator? opcode [
			failure: verify-common-terminator data result scalar-view instruction-id
			if failure [return failure]
		]

		case [
			opcode = schema/WIRE_OPCODE_JUMP [
				if operand-count <> 1 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar-view/instructions-ordinal
				]
				failure: verify-operand-shape data result scalar-view first-operand
					schema/WIRE_OPERAND_KIND_BLOCK
				if failure [return failure]
				if ordinary-count <> 1 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				expected-target: operand-value data scalar-view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				edge-id: first-edge
				if (edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET)
					<> schema/WIRE_EDGE_KIND_NORMAL
				[
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((edge-base control-view edge-id) + schema/WIRE_RSIR_EDGE_KIND_OFFSET)
						control-view/edges-ordinal
				]
				if (edge-value data control-view edge-id
					schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) <> expected-target
				[
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((edge-base control-view edge-id)
							+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control-view/edges-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_BRANCH [
				if operand-count <> 3 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar-view/instructions-ordinal
				]
				foreach [operand-id expected-kind] reduce [
					first-operand schema/WIRE_OPERAND_KIND_VALUE
					(first-operand + 1) schema/WIRE_OPERAND_KIND_BLOCK
					(first-operand + 2) schema/WIRE_OPERAND_KIND_BLOCK
				][
					failure: verify-operand-shape data result scalar-view operand-id expected-kind
					if failure [return failure]
				]
				reference: operand-value data scalar-view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				type-id: value-value data scalar-view reference schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				if (type-value data types type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
					<> schema/WIRE_TYPE_KIND_LOGIC
				[
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_BRANCH_TYPE
						((operand-base scalar-view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				if ordinary-count <> 2 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				case-index: 0
				while [case-index < 2][
					edge-id: first-edge + case-index
					expected-kind: either case-index = 0 [
						schema/WIRE_EDGE_KIND_TRUE
					][schema/WIRE_EDGE_KIND_FALSE]
					expected-target: operand-value data scalar-view
						(first-operand + case-index + 1)
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET)
						<> expected-kind
					[
						return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
							((edge-base control-view edge-id)
								+ schema/WIRE_RSIR_EDGE_KIND_OFFSET)
							control-view/edges-ordinal
					]
					if (edge-value data control-view edge-id
						schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) <> expected-target
					[
						return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
							((edge-base control-view edge-id)
								+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
							control-view/edges-ordinal
					]
					case-index: case-index + 1
				]
			]
			opcode = schema/WIRE_OPCODE_SWITCH [
				if any [operand-count < 4 not zero? ((operand-count - 2) // 2)][
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar-view/instructions-ordinal
				]
				case-count: (operand-count - 2) / 2
				failure: verify-operand-shape data result scalar-view first-operand
					schema/WIRE_OPERAND_KIND_VALUE
				if failure [return failure]
				case-index: 0
				while [case-index < case-count][
					failure: verify-operand-shape data result scalar-view
						(first-operand + 1 + (case-index * 2))
						schema/WIRE_OPERAND_KIND_CONSTANT
					if failure [return failure]
					failure: verify-operand-shape data result scalar-view
						(first-operand + 2 + (case-index * 2))
						schema/WIRE_OPERAND_KIND_BLOCK
					if failure [return failure]
					case-index: case-index + 1
				]
				failure: verify-operand-shape data result scalar-view
					(first-operand + operand-count - 1) schema/WIRE_OPERAND_KIND_BLOCK
				if failure [return failure]
				reference: operand-value data scalar-view first-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				type-id: value-value data scalar-view reference schema/WIRE_RSIR_VALUE_TYPE_OFFSET
				unless all [
					(type-value data types type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
						= schema/WIRE_TYPE_KIND_INTEGER
					(type-value data types type-id schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET)
						= schema/WIRE_GC_KIND_NONE
				][
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_SELECTOR_TYPE
						((operand-base scalar-view first-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar-view/operands-ordinal
				]
				case-index: 0
				while [case-index < case-count][
					operand-id: first-operand + 1 + (case-index * 2)
					constant-id: operand-value data scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (constant-value data constants constant-id
						schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET) <> type-id
					[
						return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_CASE_TYPE
							((operand-base scalar-view operand-id)
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar-view/operands-ordinal
					]
					prior-index: 0
					while [prior-index < case-index][
						prior-constant: operand-value data scalar-view
							(first-operand + 1 + (prior-index * 2))
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						if same-switch-constant? data constants types
							constant-id prior-constant
						[
							return reject result
								schema/WIRE_CONTROL_FLOW_ERROR_DUPLICATE_SWITCH_CASE
								((operand-base scalar-view operand-id)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar-view/operands-ordinal
						]
						prior-index: prior-index + 1
					]
					case-index: case-index + 1
				]
				if ordinary-count <> (case-count + 1) [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
				case-index: 0
				while [case-index < case-count][
					operand-id: first-operand + 1 + (case-index * 2)
					constant-id: operand-value data scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					expected-target: operand-value data scalar-view (operand-id + 1)
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					edge-id: first-edge + case-index
					foreach [field expected] reduce [
						schema/WIRE_RSIR_EDGE_KIND_OFFSET schema/WIRE_EDGE_KIND_SWITCH_CASE
						schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET constant-id
						schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET expected-target
					][
						if (edge-value data control-view edge-id field) <> expected [
							return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
								((edge-base control-view edge-id) + field)
								control-view/edges-ordinal
						]
					]
					case-index: case-index + 1
				]
				edge-id: first-edge + case-count
				if (edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET)
					<> schema/WIRE_EDGE_KIND_DEFAULT
				[
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((edge-base control-view edge-id) + schema/WIRE_RSIR_EDGE_KIND_OFFSET)
						control-view/edges-ordinal
				]
				expected-target: operand-value data scalar-view
					(first-operand + operand-count - 1)
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				if (edge-value data control-view edge-id
					schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) <> expected-target
				[
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
						((edge-base control-view edge-id)
							+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control-view/edges-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_RETURN [
				owner-function: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				signature-id: function-value data functions owner-function
					schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
				signature-flags: signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				if (signature-flags and schema/WIRE_FUNCTION_FLAG_NO_RETURN) <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_NO_RETURN
						(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar-view/instructions-ordinal
				]
				return-type: signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
				type-id: type-value data types return-type schema/WIRE_RSIR_TYPE_KIND_OFFSET
				case [
					type-id = schema/WIRE_TYPE_KIND_VOID [
						if operand-count <> 0 [
							return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
								(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
								scalar-view/instructions-ordinal
						]
					]
					true [
						if operand-count <> 1 [
							return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
								(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
								scalar-view/instructions-ordinal
						]
						failure: verify-operand-shape data result scalar-view first-operand
							schema/WIRE_OPERAND_KIND_VALUE
						if failure [return failure]
						reference: operand-value data scalar-view first-operand
							schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						if (value-value data scalar-view reference
							schema/WIRE_RSIR_VALUE_TYPE_OFFSET) <> return-type
						[
							return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_RETURN_TYPE
								((operand-base scalar-view first-operand)
									+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
								scalar-view/operands-ordinal
						]
					]
				]
				if ordinary-count <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_SUBROUTINE_RETURN [
				if operand-count > 1 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar-view/instructions-ordinal
				]
				if operand-count = 1 [
					failure: verify-operand-shape data result scalar-view first-operand
						schema/WIRE_OPERAND_KIND_VALUE
					if failure [return failure]
				]
				outgoing-count: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
				if outgoing-count <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_UNREACHABLE [
				if operand-count <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
						(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
						scalar-view/instructions-ordinal
				]
				if ordinary-count <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]
			opcode = schema/WIRE_OPCODE_THROW [
				if ordinary-count <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
						functions/blocks-ordinal
				]
			]
			true [
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR
					(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar-view/instructions-ordinal
			]
		]
		none
	]

	has-ordinary-incoming?: func [
		data [binary!] control-view [object!] block-id [integer!]
		/local edge-id kind
	][
		edge-id: 1
		while [edge-id <= control-view/edge-count][
			kind: edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if all [
				ordinary-edge? kind
				(edge-value data control-view edge-id
					schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) = block-id
			][return true]
			edge-id: edge-id + 1
		]
		false
	]

	mark-reachable: func [
		data [binary!] functions control-view [object!] function-id removed [integer!]
		/local marks block-count first-block entry-block block-id edge-id source target
			kind changed
	][
		block-count: functions/block-count
		marks: make block! block-count
		loop block-count [append marks false]
		first-block: function-value data functions function-id
			schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
		block-count: function-value data functions function-id
			schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
		entry-block: function-value data functions function-id
			schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
		block-id: first-block
		while [block-id < (first-block + block-count)][
			if all [
				block-id <> removed
				any [
					block-id = entry-block
					not has-ordinary-incoming? data control-view block-id
				]
			][poke marks block-id true]
			block-id: block-id + 1
		]
		changed: true
		while [changed][
			changed: false
			edge-id: 1
			while [edge-id <= control-view/edge-count][
				kind: edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
				if ordinary-edge? kind [
					source: edge-value data control-view edge-id
						schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
					target: edge-value data control-view edge-id
						schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
					if all [
						source <> removed target <> removed
						(block-value data functions source schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
							= function-id
						pick marks source
						not pick marks target
					][
						poke marks target true
						changed: true
					]
				]
				edge-id: edge-id + 1
			]
		]
		marks
	]

	verify-reachability: func [
		data [binary!] result [object!] functions control-view [object!]
		/local function-id first-block count block-id marks
	][
		function-id: 1
		while [function-id <= functions/function-count][
			marks: mark-reachable data functions control-view function-id 0
			first-block: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			count: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			block-id: first-block
			while [block-id < (first-block + count)][
				unless pick marks block-id [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_UNROOTED_BLOCK
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
						functions/blocks-ordinal
				]
				block-id: block-id + 1
			]
			function-id: function-id + 1
		]
		none
	]

	block-dominates?: func [
		data [binary!] functions control-view [object!]
		function-id definition-block use-block [integer!]
		/local marks
	][
		marks: mark-reachable data functions control-view function-id definition-block
		not pick marks use-block
	]

	verify-value-uses: func [
		data [binary!] result [object!] scalar-result [object!] control-view [object!]
		/local scalar-view functions instruction-id use-block function-id first-operand
			operand-count operand-id kind value-id definition-kind definition-id
			definition-block base
	][
		scalar-view: scalar-result/view
		functions: scalar-result/functions
		instruction-id: 1
		while [instruction-id <= scalar-view/instruction-count][
			use-block: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			function-id: block-value data functions use-block
				schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			first-operand: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			operand-count: instruction-value data scalar-view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			operand-id: first-operand
			while [operand-count > 0][
				kind: operand-value data scalar-view operand-id schema/WIRE_RSIR_OPERAND_KIND_OFFSET
				if kind = schema/WIRE_OPERAND_KIND_VALUE [
					value-id: operand-value data scalar-view operand-id
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					definition-kind: value-value data scalar-view value-id
						schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
					if definition-kind = schema/WIRE_VALUE_DEFINITION_INSTRUCTION [
						definition-id: value-value data scalar-view value-id
							schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
						definition-block: instruction-value data scalar-view definition-id
							schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
						base: operand-base scalar-view operand-id
						either definition-block = use-block [
							if definition-id >= instruction-id [
								return reject result
									schema/WIRE_CONTROL_FLOW_ERROR_USE_BEFORE_DEFINITION
									(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar-view/operands-ordinal
							]
						][
							unless block-dominates? data functions control-view function-id
								definition-block use-block
							[
								return reject result
									schema/WIRE_CONTROL_FLOW_ERROR_VALUE_NOT_DOMINATING
									(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
									scalar-view/operands-ordinal
							]
						]
					]
				]
				operand-id: operand-id + 1
				operand-count: operand-count - 1
			]
			instruction-id: instruction-id + 1
		]
		none
	]

	verify: func [
		data
		/local result scalar-result container-result edges control-view record-index record-base
			field-name field-offset value edge-id source target kind selector flags
			source-function target-function cursor block-id first count finish index
			seen-exception? instruction-id opcode failure
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_INVALID_ARGUMENTS 0 0
		]

		scalar-result: scalar-verifier/verify data
		inherit-scalar-result result scalar-result
		unless scalar-result/valid? [
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_INVALID_SCALAR_OPERATION
				scalar-result/error-offset scalar-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		edges: container/find-section container-result schema/WIRE_RSIR_SECTION_EDGES
		if none? edges [
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_INVALID_SCALAR_OPERATION
				schema/WIRE_HEADER_SIZE 0
		]
		if (select edges 'flags) <> 0 [
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SECTION_FLAGS
				(section-flags-offset edges) (select edges 'ordinal)
		]

		control-view: make-view
		control-view/edges-offset: select edges 'payload-offset
		control-view/edge-count: select edges 'record-count
		control-view/edge-record-size: select edges 'record-size
		control-view/edges-ordinal: select edges 'ordinal

		; Decode every signed edge scalar before following a reference.
		record-index: 0
		while [record-index < control-view/edge-count][
			record-base: edge-base control-view (record-index + 1)
			foreach [field-name field-offset] edge-fields [
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_SCALAR_RANGE
						(record-base + field-offset) control-view/edges-ordinal
				]
			]
			record-index: record-index + 1
		]

		edge-id: 1
		while [edge-id <= control-view/edge-count][
			record-base: edge-base control-view edge-id
			kind: edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
			unless all [
				kind >= schema/WIRE_EDGE_KIND_NORMAL
				kind <= schema/WIRE_EDGE_KIND_EXCEPTION
			][
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_KIND
					(record-base + schema/WIRE_RSIR_EDGE_KIND_OFFSET)
					control-view/edges-ordinal
			]
			flags: edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_FLAGS_OFFSET
			if flags <> 0 [
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_NONZERO_EDGE_FLAGS
					(record-base + schema/WIRE_RSIR_EDGE_FLAGS_OFFSET)
					control-view/edges-ordinal
			]
			source: edge-value data control-view edge-id
				schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
			if any [source <= 0 source > scalar-result/functions/block-count][
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SOURCE
					(record-base + schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET)
					control-view/edges-ordinal
			]
			target: edge-value data control-view edge-id
				schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
			if any [target <= 0 target > scalar-result/functions/block-count][
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_TARGET
					(record-base + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					control-view/edges-ordinal
			]
			source-function: block-value data scalar-result/functions source
				schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			target-function: block-value data scalar-result/functions target
				schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			if source-function <> target-function [
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_FUNCTION
					(record-base + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
					control-view/edges-ordinal
			]
			selector: edge-value data control-view edge-id
				schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
			either kind = schema/WIRE_EDGE_KIND_SWITCH_CASE [
				if any [selector <= 0 selector > scalar-result/constants/constant-count][
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SELECTOR
						(record-base + schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET)
						control-view/edges-ordinal
				]
			][
				if selector <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SELECTOR
						(record-base + schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET)
						control-view/edges-ordinal
				]
			]
			edge-id: edge-id + 1
		]

		; Blocks partition edges. Ordinary edges precede deferred exception edges.
		cursor: 1
		block-id: 1
		while [block-id <= scalar-result/functions/block-count][
			record-base: block-base scalar-result/functions block-id
			first: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
			count: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
			either count = 0 [
				if first <> 0 [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_BLOCK_EDGE_RANGE
						(record-base + schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET)
						scalar-result/functions/blocks-ordinal
				]
			][
				finish: container/checked-add first (count - 1)
				if any [
					first <> cursor none? finish finish > control-view/edge-count
				][
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_BLOCK_EDGE_RANGE
						(record-base + schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET)
						scalar-result/functions/blocks-ordinal
				]
				index: 0
				seen-exception?: false
				while [index < count][
					edge-id: first + index
					if (edge-value data control-view edge-id
						schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET) <> block-id
					[
						return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SOURCE
							((edge-base control-view edge-id)
								+ schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET)
							control-view/edges-ordinal
					]
					if (edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_ORDINAL_OFFSET)
						<> index
					[
						return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_ORDINAL
							((edge-base control-view edge-id)
								+ schema/WIRE_RSIR_EDGE_ORDINAL_OFFSET)
							control-view/edges-ordinal
					]
					kind: edge-value data control-view edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
					either kind = schema/WIRE_EDGE_KIND_EXCEPTION [
						seen-exception?: true
					][
						if seen-exception? [
							return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_KIND
								((edge-base control-view edge-id)
									+ schema/WIRE_RSIR_EDGE_KIND_OFFSET)
								control-view/edges-ordinal
						]
					]
					index: index + 1
				]
				cursor: finish + 1
			]
			block-id: block-id + 1
		]
		if cursor <> (control-view/edge-count + 1) [
			return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_COVERAGE
				(control-view/edges-offset
					+ ((cursor - 1) * schema/WIRE_RSIR_EDGE_SIZE))
				control-view/edges-ordinal
		]

		; Every block is nonempty and has exactly one final terminator.
		block-id: 1
		while [block-id <= scalar-result/functions/block-count][
			record-base: block-base scalar-result/functions block-id
			first: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			if count = 0 [
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_EMPTY_BLOCK
					(record-base + schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET)
					scalar-result/functions/blocks-ordinal
			]
			instruction-id: first
			while [instruction-id < (first + count - 1)][
				opcode: instruction-value data scalar-result/view instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
				if terminator? opcode [
					return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_POSITION
						((instruction-base scalar-result/view instruction-id)
							+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar-result/view/instructions-ordinal
				]
				instruction-id: instruction-id + 1
			]
			instruction-id: first + count - 1
			opcode: instruction-value data scalar-result/view instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			unless terminator? opcode [
				return reject result schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR
					((instruction-base scalar-result/view instruction-id)
						+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					scalar-result/view/instructions-ordinal
			]
			block-id: block-id + 1
		]

		block-id: 1
		while [block-id <= scalar-result/functions/block-count][
			first: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			count: block-value data scalar-result/functions block-id
				schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			instruction-id: first + count - 1
			failure: verify-terminator data result scalar-result control-view
				block-id instruction-id
			if failure [return failure]
			block-id: block-id + 1
		]

		failure: verify-reachability data result scalar-result/functions control-view
		if failure [return failure]
		failure: verify-value-uses data result scalar-result control-view
		if failure [return failure]

		result/strings: scalar-result/strings
		result/files: scalar-result/files
		result/layout: scalar-result/layout
		result/types: scalar-result/types
		result/functions: scalar-result/functions
		result/modules: scalar-result/modules
		result/symbols: scalar-result/symbols
		result/constants: scalar-result/constants
		result/scalar-view: scalar-result/view
		result/view: control-view
		result/valid?: true
		result
	]
]
