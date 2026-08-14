Red [
	Title: "Hybrid compiler RSIR subroutine verifier"
	File:  %wire-subroutine.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-call-abi [do %wire-call-abi.red]

compiler-wire-subroutine: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	call-verifier: compiler-wire-call-abi

	subroutine-fields: reduce [
		'function schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
		'name-string schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET
		'signature schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
		'entry-block schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
		'first-block-member schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
		'block-member-count schema/WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
		'source-location schema/WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET
		'flags schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET
	]

	member-fields: reduce [
		'subroutine schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET
		'block schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
	]

	make-view: does [
		make object! [
			subroutines-offset: 0
			subroutine-count: 0
			subroutine-record-size: schema/WIRE_RSIR_SUBROUTINE_SIZE
			subroutines-ordinal: 0
			block-members-offset: 0
			block-member-count: 0
			block-member-record-size: schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
			block-members-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_SUBROUTINE_ERROR_SUCCESS
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

	subroutine-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/subroutines-offset schema/WIRE_RSIR_SUBROUTINE_SIZE
			id field
	]

	member-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/block-members-offset
			schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE id field
	]

	string-value: func [data [binary!] strings [object!] id field [integer!]][
		record-value data strings/records-offset schema/WIRE_STRING_SIZE id field
	]

	function-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/functions-offset schema/WIRE_RSIR_FUNCTION_SIZE
			id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/signatures-offset schema/WIRE_RSIR_SIGNATURE_SIZE
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

	call-value: func [data [binary!] calls [object!] id field [integer!]][
		record-value data calls/calls-offset schema/WIRE_RSIR_CALL_SIZE id field
	]

	subroutine-base: func [view [object!] id [integer!]][
		view/subroutines-offset + ((id - 1) * schema/WIRE_RSIR_SUBROUTINE_SIZE)
	]

	member-base: func [view [object!] id [integer!]][
		view/block-members-offset
			+ ((id - 1) * schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE)
	]

	block-base: func [functions [object!] id [integer!]][
		functions/blocks-offset + ((id - 1) * schema/WIRE_RSIR_BLOCK_SIZE)
	]

	instruction-base: func [scalar [object!] id [integer!]][
		scalar/instructions-offset + ((id - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
	]

	operand-base: func [scalar [object!] id [integer!]][
		scalar/operands-offset + ((id - 1) * schema/WIRE_RSIR_OPERAND_SIZE)
	]

	call-base: func [calls [object!] id [integer!]][
		calls/calls-offset + ((id - 1) * schema/WIRE_RSIR_CALL_SIZE)
	]

	ordinary-edge?: func [kind [integer!]][kind <> schema/WIRE_EDGE_KIND_EXCEPTION]

	region-for-block: func [
		data [binary!] view [object!] block-id [integer!]
		/local member-id
	][
		member-id: 1
		while [member-id <= view/block-member-count][
			if (member-value data view member-id
				schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) = block-id
			[
				return member-value data view member-id
					schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET
			]
			member-id: member-id + 1
		]
		0
	]

	has-ordinary-incoming?: func [
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

	exception-handler?: func [
		data [binary!] regions [map!] block-id [integer!]
		/local region-id base handler
	][
		region-id: 0
		while [region-id < (select regions 'record-count)][
			base: (select regions 'payload-offset)
				+ (region-id * schema/WIRE_RSIR_EXCEPTION_REGION_SIZE)
			handler: container/read-i31 data
				(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
			if all [not none? handler handler = block-id][return true]
			region-id: region-id + 1
		]
		false
	]

	mark-region-reachable: func [
		data [binary!] functions control view [object!] regions [map!]
		root region-id [integer!]
		/local marks block-count block-id edge-id source target changed
	][
		block-count: functions/block-count
		marks: make block! block-count
		loop block-count [append marks false]
		poke marks root true
		block-id: 1
		while [block-id <= block-count][
			if all [
				(region-for-block data view block-id) = region-id
				exception-handler? data regions block-id
			][poke marks block-id true]
			block-id: block-id + 1
		]
		changed: true
		while [changed][
			changed: false
			edge-id: 1
			while [edge-id <= control/edge-count][
				source: edge-value data control edge-id
					schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
				target: edge-value data control edge-id
					schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
				if all [
					(region-for-block data view source) = region-id
					(region-for-block data view target) = region-id
					pick marks source
					not pick marks target
				][
					poke marks target true
					changed: true
				]
				edge-id: edge-id + 1
			]
		]
		marks
	]

	find-call-for-instruction: func [
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

	find-instruction-for-operand: func [
		data [binary!] scalar [object!] operand-id [integer!]
		/local instruction-id first count
	][
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			first: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
			count: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			if all [count > 0 operand-id >= first operand-id < (first + count)][
				return instruction-id
			]
			instruction-id: instruction-id + 1
		]
		0
	]

	verify-reachability: func [
		data [binary!] result [object!] functions control view [object!] regions [map!]
		/local function-id first count entry block-id marks region-id subroutine-id
			member-id
	][
		function-id: 1
		while [function-id <= functions/function-count][
			first: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			count: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			entry: function-value data functions function-id
				schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
			marks: mark-region-reachable data functions control view regions entry 0
			block-id: first
			while [block-id < (first + count)][
				if all [
					(region-for-block data view block-id) = 0
					not pick marks block-id
				][
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_UNROOTED_SUBROUTINE_BLOCK
						((block-base functions block-id)
							+ schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
						functions/blocks-ordinal
				]
				block-id: block-id + 1
			]
			function-id: function-id + 1
		]

		subroutine-id: 1
		while [subroutine-id <= view/subroutine-count][
			entry: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
			marks: mark-region-reachable data functions control view regions entry subroutine-id
			first: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
			count: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
			member-id: first
			while [member-id < (first + count)][
				block-id: member-value data view member-id
					schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
				unless pick marks block-id [
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_UNROOTED_SUBROUTINE_BLOCK
						((member-base view member-id)
							+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
						view/block-members-ordinal
				]
				member-id: member-id + 1
			]
			subroutine-id: subroutine-id + 1
		]
		none
	]

	verify-returns: func [
		data [binary!] result [object!] call-result view [object!]
		/local scalar functions types instruction-id opcode block-id subroutine-id
			signature-id return-type return-kind operand-count first-operand value-id
			found? member-id first member-count instruction-count
	][
		scalar: call-result/scalar-view
		functions: call-result/functions
		types: call-result/types
		instruction-id: 1
		while [instruction-id <= scalar/instruction-count][
			opcode: instruction-value data scalar instruction-id
				schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
			if opcode = schema/WIRE_OPCODE_SUBROUTINE_RETURN [
				block-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
				subroutine-id: region-for-block data view block-id
				if subroutine-id = 0 [
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
						((instruction-base scalar instruction-id)
							+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						scalar/instructions-ordinal
				]
				signature-id: subroutine-value data view subroutine-id
					schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
				return-type: signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
				return-kind: type-value data types return-type
					schema/WIRE_RSIR_TYPE_KIND_OFFSET
				operand-count: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
				either return-kind = schema/WIRE_TYPE_KIND_VOID [
					if operand-count <> 0 [
						return reject result
							schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
							scalar/instructions-ordinal
					]
				][
					if operand-count <> 1 [
						return reject result
							schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
							((instruction-base scalar instruction-id)
								+ schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
							scalar/instructions-ordinal
					]
					first-operand: instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
					value-id: operand-value data scalar first-operand
						schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					if (value-value data scalar value-id schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
						<> return-type
					[
						return reject result
							schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
							((operand-base scalar first-operand)
								+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
							scalar/operands-ordinal
					]
				]
			]
			instruction-id: instruction-id + 1
		]

		subroutine-id: 1
		while [subroutine-id <= view/subroutine-count][
			found?: false
			first: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
			member-count: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
			member-id: first
			while [member-id < (first + member-count)][
				block-id: member-value data view member-id
					schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
				instruction-id: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
				instruction-count: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
				while [instruction-count > 0][
					if (instruction-value data scalar instruction-id
						schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
						= schema/WIRE_OPCODE_SUBROUTINE_RETURN [found?: true]
					instruction-id: instruction-id + 1
					instruction-count: instruction-count - 1
				]
				member-id: member-id + 1
			]
			unless found? [
				return reject result
					schema/WIRE_SUBROUTINE_ERROR_MISSING_SUBROUTINE_RETURN
					((subroutine-base view subroutine-id)
						+ schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
					view/subroutines-ordinal
			]
			subroutine-id: subroutine-id + 1
		]
		none
	]

	verify-calls-and-operands: func [
		data [binary!] result [object!] call-result view [object!]
		/local scalar functions calls call-id kind instruction-id block-id caller-function
			caller-region callee-operand subroutine-id callee-function signature-id
			operand-id operand-kind owning-instruction owning-call
	][
		scalar: call-result/scalar-view
		functions: call-result/functions
		calls: call-result/view
		call-id: 1
		while [call-id <= calls/call-count][
			kind: call-value data calls call-id schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
			if kind = schema/WIRE_CALL_KIND_SUBROUTINE [
				instruction-id: call-value data calls call-id
					schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET
				block-id: instruction-value data scalar instruction-id
					schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
				caller-function: block-value data functions block-id
					schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
				caller-region: region-for-block data view block-id
				callee-operand: call-value data calls call-id
					schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
				subroutine-id: operand-value data scalar callee-operand
					schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				callee-function: subroutine-value data view subroutine-id
					schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
				if callee-function <> caller-function [
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALLEE
						((operand-base scalar callee-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
				signature-id: subroutine-value data view subroutine-id
					schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
				if any [
					(call-value data calls call-id schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
						<> signature-id
					(call-value data calls call-id schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
						<> 0
				][
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALL
						((call-base calls call-id) + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
						calls/calls-ordinal
				]
				if caller-region = subroutine-id [
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_RECURSIVE_SUBROUTINE_CALL
						((operand-base scalar callee-operand)
							+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
						scalar/operands-ordinal
				]
			]
			call-id: call-id + 1
		]

		operand-id: 1
		while [operand-id <= scalar/operand-count][
			operand-kind: operand-value data scalar operand-id
				schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			if operand-kind = schema/WIRE_OPERAND_KIND_SUBROUTINE [
				owning-instruction: find-instruction-for-operand data scalar operand-id
				owning-call: either owning-instruction = 0 [0][
					find-call-for-instruction data calls owning-instruction
				]
				if any [
					owning-call = 0
					all [
						owning-call > 0
						(call-value data calls owning-call
							schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
							<> schema/WIRE_CALL_KIND_SUBROUTINE
					]
					all [
						owning-call > 0
						(call-value data calls owning-call
							schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET)
							<> operand-id
					]
				][
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_OPERAND
						((operand-base scalar operand-id)
							+ schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
						scalar/operands-ordinal
				]
			]
			operand-id: operand-id + 1
		]
		none
	]

	verify: func [
		data
		/local result call-result container-result subroutines members regions view scalar
			functions control strings types record-index record-base field-name
			field-offset value cursor previous-function previous-entry subroutine-id
			function-id name-string prior-id signature-id flags return-type return-kind
			entry first count finish source-location member-id previous-block block-id
			prior-member entry-found? edge-id edge-kind source target source-region
			target-region failure
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_SUBROUTINE_ERROR_INVALID_ARGUMENTS 0 0
		]

		call-result: call-verifier/verify data
		inherit-call-result result call-result
		unless call-result/valid? [
			return reject result schema/WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI
				call-result/error-offset call-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		subroutines: container/find-section container-result
			schema/WIRE_RSIR_SECTION_SUBROUTINES
		members: container/find-section container-result
			schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		regions: container/find-section container-result
			schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS
		if any [none? subroutines none? members none? regions][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI
				schema/WIRE_HEADER_SIZE 0
		]
		if (select subroutines 'flags) <> 0 [
			return reject result
				schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SECTION_FLAGS
				(section-flags-offset subroutines) (select subroutines 'ordinal)
		]
		if (select members 'flags) <> 0 [
			return reject result
				schema/WIRE_SUBROUTINE_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS
				(section-flags-offset members) (select members 'ordinal)
		]

		view: make-view
		view/subroutines-offset: select subroutines 'payload-offset
		view/subroutine-count: select subroutines 'record-count
		view/subroutine-record-size: select subroutines 'record-size
		view/subroutines-ordinal: select subroutines 'ordinal
		view/block-members-offset: select members 'payload-offset
		view/block-member-count: select members 'record-count
		view/block-member-record-size: select members 'record-size
		view/block-members-ordinal: select members 'ordinal
		scalar: call-result/scalar-view
		functions: call-result/functions
		control: call-result/control-view
		strings: call-result/strings
		types: call-result/types

		record-index: 0
		while [record-index < view/subroutine-count][
			record-base: view/subroutines-offset
				+ (record-index * schema/WIRE_RSIR_SUBROUTINE_SIZE)
			foreach [field-name field-offset] subroutine-fields [
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
						(record-base + field-offset) view/subroutines-ordinal
				]
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < view/block-member-count][
			record-base: view/block-members-offset
				+ (record-index * schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE)
			foreach [field-name field-offset] member-fields [
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
						(record-base + field-offset) view/block-members-ordinal
				]
			]
			record-index: record-index + 1
		]

		cursor: 1
		previous-function: 0
		previous-entry: 0
		subroutine-id: 1
		while [subroutine-id <= view/subroutine-count][
			record-base: subroutine-base view subroutine-id
			function-id: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
			if any [function-id <= 0 function-id > functions/function-count][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_FUNCTION
					(record-base + schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET)
					view/subroutines-ordinal
			]
			entry: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
			if any [
				function-id < previous-function
				all [function-id = previous-function entry <= previous-entry]
			][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ORDER
					(record-base + either function-id < previous-function [
						schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
					][schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET])
					view/subroutines-ordinal
			]
			previous-function: function-id
			previous-entry: entry

			name-string: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET
			if any [
				name-string <= 0 name-string > strings/record-count
				all [
					name-string > 0 name-string <= strings/record-count
					(string-value data strings name-string schema/WIRE_STRING_SIZE_OFFSET) = 0
				]
			][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_NAME
					(record-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET)
					view/subroutines-ordinal
			]
			prior-id: 1
			while [prior-id < subroutine-id][
				if all [
					(subroutine-value data view prior-id
						schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET) = function-id
					(subroutine-value data view prior-id
						schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET) = name-string
				][
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_NAME
						(record-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET)
						view/subroutines-ordinal
				]
				prior-id: prior-id + 1
			]

			signature-id: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
			if any [signature-id <= 0 signature-id > functions/signature-count][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SIGNATURE
					(record-base + schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET)
					view/subroutines-ordinal
			]
			flags: signature-value data functions signature-id
				schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			return-type: signature-value data functions signature-id
				schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
			return-kind: type-value data types return-type schema/WIRE_RSIR_TYPE_KIND_OFFSET
			if any [
				(signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
					<> schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
				(flags and schema/WIRE_FUNCTION_FLAG_MAY_THROW) <> flags
				(signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET) <> 0
				(signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET) <> 0
				(signature-value data functions signature-id
					schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET) <> 0
				find reduce [schema/WIRE_TYPE_KIND_STRUCT schema/WIRE_TYPE_KIND_UNION]
					return-kind
			][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SIGNATURE
					(record-base + schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET)
					view/subroutines-ordinal
			]

			if any [
				entry <= 0 entry > functions/block-count
				all [
					entry > 0 entry <= functions/block-count
					(block-value data functions entry schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
						<> function-id
				]
				entry = (function-value data functions function-id
					schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET)
			][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
					(record-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
					view/subroutines-ordinal
			]
			if has-ordinary-incoming? data control entry [
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
					(record-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
					view/subroutines-ordinal
			]

			first: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
			count: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
			finish: container/checked-add first (count - 1)
			if any [
				count <= 0 first <> cursor none? finish
				all [not none? finish finish > view/block-member-count]
			][
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_RANGE
					(record-base + schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET)
					view/subroutines-ordinal
			]
			previous-block: 0
			entry-found?: false
			member-id: first
			while [member-id <= finish][
				if (member-value data view member-id
					schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET) <> subroutine-id
				[
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
						((member-base view member-id)
							+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET)
						view/block-members-ordinal
				]
				block-id: member-value data view member-id
					schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
				if block-id <= previous-block [
					return reject result
						schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER_ORDER
						((member-base view member-id)
							+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
						view/block-members-ordinal
				]
				previous-block: block-id
				if any [
					block-id <= 0 block-id > functions/block-count
					all [
						block-id > 0 block-id <= functions/block-count
						(block-value data functions block-id
							schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET) <> function-id
					]
					block-id = (function-value data functions function-id
						schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET)
				][
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
						((member-base view member-id)
							+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
						view/block-members-ordinal
				]
				prior-member: 1
				while [prior-member < first][
					if (member-value data view prior-member
						schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) = block-id
					[
						return reject result
							schema/WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_MEMBER
							((member-base view member-id)
								+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
							view/block-members-ordinal
					]
					prior-member: prior-member + 1
				]
				if block-id = entry [entry-found?: true]
				member-id: member-id + 1
			]
			unless entry-found? [
				return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
					(record-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
					view/subroutines-ordinal
			]
			cursor: finish + 1

			source-location: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET
			if source-location > functions/source-location-count [
				return reject result
					schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET)
					view/subroutines-ordinal
			]
			flags: subroutine-value data view subroutine-id
				schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET
			if flags <> 0 [
				return reject result
					schema/WIRE_SUBROUTINE_ERROR_NONZERO_SUBROUTINE_FLAGS
					(record-base + schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET)
					view/subroutines-ordinal
			]
			subroutine-id: subroutine-id + 1
		]
		if cursor <> (view/block-member-count + 1) [
			return reject result
				schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_COVERAGE
				(view/block-members-offset
					+ ((cursor - 1) * schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE))
				view/block-members-ordinal
		]

		edge-id: 1
		while [edge-id <= control/edge-count][
			edge-kind: edge-value data control edge-id schema/WIRE_RSIR_EDGE_KIND_OFFSET
			if ordinary-edge? edge-kind [
				source: edge-value data control edge-id schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
				target: edge-value data control edge-id schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
				source-region: region-for-block data view source
				target-region: region-for-block data view target
				if source-region <> target-region [
					return reject result schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_EDGE
						((control/edges-offset
							+ ((edge-id - 1) * schema/WIRE_RSIR_EDGE_SIZE))
							+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
						control/edges-ordinal
				]
			]
			edge-id: edge-id + 1
		]

		failure: verify-reachability data result functions control view regions
		if failure [return failure]
		failure: verify-returns data result call-result view
		if failure [return failure]
		failure: verify-calls-and-operands data result call-result view
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
		result/call-view: call-result/view
		result/view: view
		result/valid?: true
		result
	]
]
