Red/System [
	Title: "Hybrid compiler RSIR subroutine verifier"
	File:  %wire-subroutine.reds
]

#include %wire-call-abi.reds

wire-subroutine-result!: alias struct! [
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

wire-subroutine!: alias struct! [
	subroutines             [byte-ptr!]
	subroutine-count        [integer!]
	subroutine-record-size  [integer!]
	subroutines-offset      [integer!]
	subroutines-ordinal     [integer!]
	block-members           [byte-ptr!]
	block-member-count      [integer!]
	block-member-record-size [integer!]
	block-members-offset    [integer!]
	block-members-ordinal   [integer!]
]

wire-subroutine-reader: context [
	set-error: func [
		result [wire-subroutine-result!]
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
		/local index relative [integer!]
	][
		index: 0
		while [index < word-count][
			relative: index * 4
			if (wire-container-reader/read-i31 record relative) < 0 [return relative]
			index: index + 1
		]
		-1
	]

subroutine-value: func [
	view [wire-subroutine!]
	id field-offset [integer!]
	return: [integer!]
	][
	wire-container-reader/read-i31 view/subroutines
		(((id - 1) * WIRE_RSIR_SUBROUTINE_SIZE) + field-offset)
	]

member-value: func [
	view [wire-subroutine!]
	id field-offset [integer!]
	return: [integer!]
	][
	wire-container-reader/read-i31 view/block-members
		(((id - 1) * WIRE_RSIR_SUBROUTINE_BLOCK_SIZE) + field-offset)
	]

string-value: func [
	strings [wire-string-table!]
	id field-offset [integer!]
	return: [integer!]
	][
	wire-container-reader/read-i31 strings/records
		(((id - 1) * WIRE_STRING_SIZE) + field-offset)
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

call-value: func [
	calls [wire-call-abi!]
	id field-offset [integer!]
	return: [integer!]
	][
	wire-container-reader/read-i31 calls/calls
		(((id - 1) * WIRE_RSIR_CALL_SIZE) + field-offset)
	]

subroutine-base: func [view [wire-subroutine!] id [integer!] return: [integer!]][
	view/subroutines-offset + ((id - 1) * WIRE_RSIR_SUBROUTINE_SIZE)
]

member-base: func [view [wire-subroutine!] id [integer!] return: [integer!]][
	view/block-members-offset + ((id - 1) * WIRE_RSIR_SUBROUTINE_BLOCK_SIZE)
]

block-base: func [functions [wire-function-signature!] id [integer!] return: [integer!]][
	functions/blocks-offset + ((id - 1) * WIRE_RSIR_BLOCK_SIZE)
]

instruction-base: func [scalar [wire-scalar-operation!] id [integer!] return: [integer!]][
	scalar/instructions-offset + ((id - 1) * WIRE_RSIR_INSTRUCTION_SIZE)
]

operand-base: func [scalar [wire-scalar-operation!] id [integer!] return: [integer!]][
	scalar/operands-offset + ((id - 1) * WIRE_RSIR_OPERAND_SIZE)
]

call-base: func [calls [wire-call-abi!] id [integer!] return: [integer!]][
	calls/calls-offset + ((id - 1) * WIRE_RSIR_CALL_SIZE)
]

region-for-block: func [
	view [wire-subroutine!]
	block-id [integer!]
	return: [integer!]
	/local member-id [integer!]
][
	member-id: 1
	while [member-id <= view/block-member-count][
		if (member-value view member-id WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
			= block-id
		[
			return member-value view member-id
				WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET
		]
		member-id: member-id + 1
	]
	0
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
			kind <> WIRE_EDGE_KIND_EXCEPTION
			(edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) = block-id
		][return true]
		edge-id: edge-id + 1
	]
	false
]

exception-handler?: func [
	regions [wire-section-slice!]
	block-id [integer!]
	return: [logic!]
	/local region-id handler [integer!]
][
	region-id: 0
	while [region-id < regions/record-count][
		handler: wire-container-reader/read-i31 regions/data
			((region-id * WIRE_RSIR_EXCEPTION_REGION_SIZE)
				+ WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
		if handler = block-id [return true]
		region-id: region-id + 1
	]
	false
]

clear-marks: func [
	functions [wire-function-signature!]
	workspace [byte-ptr!]
	/local block-id [integer!] mark [byte-ptr!]
][
	block-id: 1
	while [block-id <= functions/block-count][
		mark: workspace + (block-id - 1)
		mark/1: as byte! 0
		block-id: block-id + 1
	]
]

mark-region-reachable: func [
	functions [wire-function-signature!]
	control [wire-control-flow!]
	view [wire-subroutine!]
	regions [wire-section-slice!]
	workspace [byte-ptr!]
	root region-id [integer!]
	/local changed block-id edge-id source target [integer!]
		source-mark target-mark mark [byte-ptr!]
][
	clear-marks functions workspace
	mark: workspace + (root - 1)
	mark/1: as byte! 1
	block-id: 1
	while [block-id <= functions/block-count][
		if all [
			(region-for-block view block-id) = region-id
			exception-handler? regions block-id
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
			source: edge-value control edge-id WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
			target: edge-value control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
			if all [
				(region-for-block view source) = region-id
				(region-for-block view target) = region-id
			][
				source-mark: workspace + (source - 1)
				target-mark: workspace + (target - 1)
				if all [source-mark/1 = as byte! 1 target-mark/1 = as byte! 0][
					target-mark/1: as byte! 1
					changed: 1
				]
			]
			edge-id: edge-id + 1
		]
	]
]

find-call-for-instruction: func [
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

find-instruction-for-operand: func [
	scalar [wire-scalar-operation!]
	operand-id [integer!]
	return: [integer!]
	/local instruction-id first count [integer!]
][
	instruction-id: 1
	while [instruction-id <= scalar/instruction-count][
		first: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
		count: instruction-value scalar instruction-id
			WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
		if all [count > 0 operand-id >= first operand-id < (first + count)][
			return instruction-id
		]
		instruction-id: instruction-id + 1
	]
	0
]

verify-reachability: func [
	result [wire-subroutine-result!]
	functions [wire-function-signature!]
	control [wire-control-flow!]
	view [wire-subroutine!]
	regions [wire-section-slice!]
	workspace [byte-ptr!]
	return: [integer!]
	/local function-id first count entry block-id subroutine-id member-id [integer!]
		mark [byte-ptr!]
][
	function-id: 1
	while [function-id <= functions/function-count][
		first: function-value functions function-id WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
		count: function-value functions function-id WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
		entry: function-value functions function-id WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
		mark-region-reachable functions control view regions workspace entry 0
		block-id: first
		while [block-id < (first + count)][
			mark: workspace + (block-id - 1)
			if all [
				(region-for-block view block-id) = 0
				mark/1 = as byte! 0
			][
				return set-error result WIRE_SUBROUTINE_ERROR_UNROOTED_SUBROUTINE_BLOCK
					(block-base functions block-id) + WIRE_RSIR_BLOCK_FUNCTION_OFFSET
					functions/blocks-ordinal
			]
			block-id: block-id + 1
		]
		function-id: function-id + 1
	]
	subroutine-id: 1
	while [subroutine-id <= view/subroutine-count][
		entry: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
		mark-region-reachable functions control view regions workspace entry subroutine-id
		first: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
		count: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
		member-id: first
		while [member-id < (first + count)][
			block-id: member-value view member-id WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
			mark: workspace + (block-id - 1)
			if mark/1 = as byte! 0 [
				return set-error result WIRE_SUBROUTINE_ERROR_UNROOTED_SUBROUTINE_BLOCK
					(member-base view member-id) + WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
					view/block-members-ordinal
			]
			member-id: member-id + 1
		]
		subroutine-id: subroutine-id + 1
	]
	WIRE_SUBROUTINE_ERROR_SUCCESS
]

verify-returns: func [
	result [wire-subroutine-result!]
	scalar [wire-scalar-operation!]
	functions [wire-function-signature!]
	types [wire-type-layout!]
	view [wire-subroutine!]
	return: [integer!]
	/local instruction-id opcode block-id subroutine-id signature-id return-type return-kind
		operand-count first-operand value-id member-id first count instruction-count
		[integer!]
		found? [logic!]
][
	instruction-id: 1
	while [instruction-id <= scalar/instruction-count][
		opcode: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
		if opcode = WIRE_OPCODE_SUBROUTINE_RETURN [
			block-id: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			subroutine-id: region-for-block view block-id
			if subroutine-id = 0 [
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
					(instruction-base scalar instruction-id) + WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
					scalar/instructions-ordinal
			]
			signature-id: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
			return-type: signature-value functions signature-id WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
			return-kind: type-value types return-type WIRE_RSIR_TYPE_KIND_OFFSET
			operand-count: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
			either return-kind = WIRE_TYPE_KIND_VOID [
				if operand-count <> 0 [
					return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
						(instruction-base scalar instruction-id) + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
						scalar/instructions-ordinal
				]
			][
				if operand-count <> 1 [
					return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
						(instruction-base scalar instruction-id) + WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
						scalar/instructions-ordinal
				]
				first-operand: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
				value-id: operand-value scalar first-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
				if (value-value scalar value-id WIRE_RSIR_VALUE_TYPE_OFFSET) <> return-type [
					return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
						(operand-base scalar first-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET
						scalar/operands-ordinal
				]
			]
		]
		instruction-id: instruction-id + 1
	]
	subroutine-id: 1
	while [subroutine-id <= view/subroutine-count][
		found?: false
		first: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
		count: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
		member-id: first
		while [member-id < (first + count)][
			block-id: member-value view member-id WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
			instruction-id: block-value functions block-id WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
			instruction-count: block-value functions block-id WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
			while [instruction-count > 0][
				if (instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
					= WIRE_OPCODE_SUBROUTINE_RETURN [found?: true]
				instruction-id: instruction-id + 1
				instruction-count: instruction-count - 1
			]
			member-id: member-id + 1
		]
		if not found? [
			return set-error result WIRE_SUBROUTINE_ERROR_MISSING_SUBROUTINE_RETURN
				(subroutine-base view subroutine-id) + WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
				view/subroutines-ordinal
		]
		subroutine-id: subroutine-id + 1
	]
	WIRE_SUBROUTINE_ERROR_SUCCESS
]

verify-calls-and-operands: func [
	result [wire-subroutine-result!]
	scalar [wire-scalar-operation!]
	functions [wire-function-signature!]
	calls [wire-call-abi!]
	view [wire-subroutine!]
	return: [integer!]
	/local call-id kind instruction-id block-id caller-function caller-region callee-operand
		subroutine-id callee-function signature-id operand-id operand-kind owning-instruction owning-call
		[integer!]
][
	call-id: 1
	while [call-id <= calls/call-count][
		kind: call-value calls call-id WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
		if kind = WIRE_CALL_KIND_SUBROUTINE [
			instruction-id: call-value calls call-id WIRE_RSIR_CALL_INSTRUCTION_OFFSET
			block-id: instruction-value scalar instruction-id WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
			caller-function: block-value functions block-id WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			caller-region: region-for-block view block-id
			callee-operand: call-value calls call-id WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
			subroutine-id: operand-value scalar callee-operand WIRE_RSIR_OPERAND_REFERENCE_OFFSET
			callee-function: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
			if callee-function <> caller-function [
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALLEE
					(operand-base scalar callee-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					scalar/operands-ordinal
			]
			signature-id: subroutine-value view subroutine-id WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
			if any [
				(call-value calls call-id WIRE_RSIR_CALL_SIGNATURE_OFFSET) <> signature-id
				(call-value calls call-id WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET) <> 0
			][
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALL
					(call-base calls call-id) + WIRE_RSIR_CALL_SIGNATURE_OFFSET
					calls/calls-ordinal
			]
			if caller-region = subroutine-id [
				return set-error result WIRE_SUBROUTINE_ERROR_RECURSIVE_SUBROUTINE_CALL
					(operand-base scalar callee-operand) + WIRE_RSIR_OPERAND_REFERENCE_OFFSET
					scalar/operands-ordinal
			]
		]
		call-id: call-id + 1
	]
	operand-id: 1
	while [operand-id <= scalar/operand-count][
		operand-kind: operand-value scalar operand-id WIRE_RSIR_OPERAND_KIND_OFFSET
		if operand-kind = WIRE_OPERAND_KIND_SUBROUTINE [
			owning-instruction: find-instruction-for-operand scalar operand-id
			owning-call: either owning-instruction = 0 [0][
				find-call-for-instruction calls owning-instruction
			]
			if any [
				owning-call = 0
				all [
					owning-call > 0
					(call-value calls owning-call WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
						<> WIRE_CALL_KIND_SUBROUTINE
				]
				all [
					owning-call > 0
					(call-value calls owning-call WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET)
						<> operand-id
				]
			][
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_OPERAND
					(operand-base scalar operand-id) + WIRE_RSIR_OPERAND_KIND_OFFSET
					scalar/operands-ordinal
			]
		]
		operand-id: operand-id + 1
	]
	WIRE_SUBROUTINE_ERROR_SUCCESS
]

copy-view: func [destination source [wire-subroutine!]][
	destination/subroutines: source/subroutines
	destination/subroutine-count: source/subroutine-count
	destination/subroutine-record-size: source/subroutine-record-size
	destination/subroutines-offset: source/subroutines-offset
	destination/subroutines-ordinal: source/subroutines-ordinal
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
	result [wire-subroutine-result!]
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
		verified-subroutines [wire-subroutine!]
		subroutine-sections members regions [wire-section-slice!]
		record [byte-ptr!]
		record-index bad-relative field-offset record-base [integer!]
		status function-id entry previous-function previous-entry subroutine-id
		name-string signature-id flags return-type return-kind first count finish
		cursor member-id previous-block block-id prior-id prior-member entry-found
		source-location edge-id edge-kind source target source-region target-region
		instruction-id opcode operand-count first-operand value-id instruction-count
		found [integer!]
	][
	if null? result [return WIRE_SUBROUTINE_ERROR_INVALID_ARGUMENTS]
	result/error: WIRE_SUBROUTINE_ERROR_SUCCESS
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
		size < 0 workspace-size < 0 null? data null? workspace
		null? strings null? files null? layout null? types null? functions
		null? modules null? symbols null? constants null? scalar null? control
		null? calls null? subroutines
	][return set-error result WIRE_SUBROUTINE_ERROR_INVALID_ARGUMENTS 0 0]

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
	status: wire-call-abi-reader/verify data size workspace workspace-size call-result
		verified-strings verified-files verified-layout verified-types verified-functions
		verified-modules verified-symbols verified-constants verified-scalar verified-control
		verified-calls
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
		return set-error result WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI
			call-result/error-offset call-result/error-section
	]

	subroutine-sections: declare wire-section-slice!
	members: declare wire-section-slice!
	regions: declare wire-section-slice!
	unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_SUBROUTINES
		subroutine-sections
	[
		result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
		return set-error result WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI WIRE_HEADER_SIZE 0
	]
	unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		members
	[
		result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
		return set-error result WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI WIRE_HEADER_SIZE 0
	]
	unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_EXCEPTION_REGIONS
		regions
	[
		result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
		return set-error result WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI WIRE_HEADER_SIZE 0
	]
	if subroutine-sections/flags <> 0 [
		return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SECTION_FLAGS
			section-flags-offset subroutine-sections subroutine-sections/ordinal
	]
	if members/flags <> 0 [
		return set-error result WIRE_SUBROUTINE_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS
			section-flags-offset members members/ordinal
	]

	verified-subroutines: declare wire-subroutine!
	verified-subroutines/subroutines: subroutine-sections/data
	verified-subroutines/subroutine-count: subroutine-sections/record-count
	verified-subroutines/subroutine-record-size: subroutine-sections/record-size
	verified-subroutines/subroutines-offset: subroutine-sections/offset
	verified-subroutines/subroutines-ordinal: subroutine-sections/ordinal
	verified-subroutines/block-members: members/data
	verified-subroutines/block-member-count: members/record-count
	verified-subroutines/block-member-record-size: members/record-size
	verified-subroutines/block-members-offset: members/offset
	verified-subroutines/block-members-ordinal: members/ordinal

	record-index: 0
	while [record-index < subroutine-sections/record-count][
		record: subroutine-sections/data + (record-index * WIRE_RSIR_SUBROUTINE_SIZE)
		bad-relative: first-bad-scalar record 8
		if bad-relative >= 0 [
			return set-error result WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
				(subroutine-sections/offset + (record-index * WIRE_RSIR_SUBROUTINE_SIZE))
				+ bad-relative subroutine-sections/ordinal
		]
		record-index: record-index + 1
	]
	record-index: 0
	while [record-index < members/record-count][
		record: members/data + (record-index * WIRE_RSIR_SUBROUTINE_BLOCK_SIZE)
		bad-relative: first-bad-scalar record 2
		if bad-relative >= 0 [
			return set-error result WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
				(members/offset + (record-index * WIRE_RSIR_SUBROUTINE_BLOCK_SIZE))
				+ bad-relative members/ordinal
		]
		record-index: record-index + 1
	]

	cursor: 1
	previous-function: 0
	previous-entry: 0
	subroutine-id: 1
	while [subroutine-id <= verified-subroutines/subroutine-count][
		record-base: subroutine-base verified-subroutines subroutine-id
		function-id: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET
		if any [function-id <= 0 function-id > verified-functions/function-count][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_FUNCTION
				record-base + WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET verified-subroutines/subroutines-ordinal
		]
		entry: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
		if any [
			function-id < previous-function
			all [function-id = previous-function entry <= previous-entry]
		][
			field-offset: either function-id < previous-function
				[WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET]
				[WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET]
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ORDER
				record-base + field-offset verified-subroutines/subroutines-ordinal
		]
		previous-function: function-id
		previous-entry: entry
		name-string: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET
		if any [
			name-string <= 0 name-string > verified-strings/record-count
			all [name-string > 0 name-string <= verified-strings/record-count
				(string-value verified-strings name-string WIRE_STRING_SIZE_OFFSET) = 0]
		][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_NAME
				record-base + WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET verified-subroutines/subroutines-ordinal
		]
		prior-id: 1
		while [prior-id < subroutine-id][
			if all [
				(subroutine-value verified-subroutines prior-id WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET) = function-id
				(subroutine-value verified-subroutines prior-id WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET) = name-string
			][
				return set-error result WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_NAME
					record-base + WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET verified-subroutines/subroutines-ordinal
			]
			prior-id: prior-id + 1
		]
		signature-id: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET
		if any [signature-id <= 0 signature-id > verified-functions/signature-count][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SIGNATURE
				record-base + WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET verified-subroutines/subroutines-ordinal
		]
		flags: signature-value verified-functions signature-id WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		return-type: signature-value verified-functions signature-id WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
		return-kind: type-value verified-types return-type WIRE_RSIR_TYPE_KIND_OFFSET
		if any [
			(signature-value verified-functions signature-id
				WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
				<> WIRE_CALLING_CONVENTION_RED_SYSTEM
			(flags and WIRE_FUNCTION_FLAG_MAY_THROW) <> flags
			(signature-value verified-functions signature-id
				WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET) <> 0
			(signature-value verified-functions signature-id
				WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET) <> 0
			(signature-value verified-functions signature-id
				WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET) <> 0
			any [return-kind = WIRE_TYPE_KIND_STRUCT return-kind = WIRE_TYPE_KIND_UNION]
		][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SIGNATURE
				record-base + WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET verified-subroutines/subroutines-ordinal
		]
		if any [
			entry <= 0 entry > verified-functions/block-count
			all [entry > 0 entry <= verified-functions/block-count
				(block-value verified-functions entry WIRE_RSIR_BLOCK_FUNCTION_OFFSET) <> function-id]
			entry = (function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET)
		][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
				record-base + WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET verified-subroutines/subroutines-ordinal
		]
		if has-ordinary-incoming? verified-control entry [
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
				record-base + WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET verified-subroutines/subroutines-ordinal
		]
		first: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET
		count: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET
		finish: wire-container-reader/checked-add first (count - 1)
		if any [count <= 0 first <> cursor finish < 0 finish > members/record-count][
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_RANGE
				record-base + WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET verified-subroutines/subroutines-ordinal
		]
		previous-block: 0
		entry-found: 0
		member-id: first
		while [member-id <= finish][
			if (member-value verified-subroutines member-id WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET)
				<> subroutine-id [
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
					(member-base verified-subroutines member-id) + WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET
					verified-subroutines/block-members-ordinal
			]
			block-id: member-value verified-subroutines member-id WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
			if block-id <= previous-block [
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER_ORDER
					(member-base verified-subroutines member-id) + WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
					verified-subroutines/block-members-ordinal
			]
			previous-block: block-id
			if any [
				block-id <= 0 block-id > verified-functions/block-count
				all [block-id > 0 block-id <= verified-functions/block-count
					(block-value verified-functions block-id WIRE_RSIR_BLOCK_FUNCTION_OFFSET) <> function-id]
				block-id = (function-value verified-functions function-id
					WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET)
			][
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
					(member-base verified-subroutines member-id) + WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
					verified-subroutines/block-members-ordinal
			]
			prior-member: 1
			while [prior-member < first][
				if (member-value verified-subroutines prior-member WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
					= block-id [
					return set-error result WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_MEMBER
						(member-base verified-subroutines member-id) + WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET
						verified-subroutines/block-members-ordinal
				]
				prior-member: prior-member + 1
			]
			if block-id = entry [entry-found: 1]
			member-id: member-id + 1
		]
		if entry-found = 0 [
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
				record-base + WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET verified-subroutines/subroutines-ordinal
		]
		cursor: finish + 1
		source-location: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET
		if source-location > verified-functions/source-location-count [
			return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SOURCE_LOCATION
				record-base + WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET verified-subroutines/subroutines-ordinal
		]
		flags: subroutine-value verified-subroutines subroutine-id WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET
		if flags <> 0 [
			return set-error result WIRE_SUBROUTINE_ERROR_NONZERO_SUBROUTINE_FLAGS
				record-base + WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET verified-subroutines/subroutines-ordinal
		]
		subroutine-id: subroutine-id + 1
	]
	if cursor <> (members/record-count + 1) [
		return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_COVERAGE
			members/offset + ((cursor - 1) * WIRE_RSIR_SUBROUTINE_BLOCK_SIZE) members/ordinal
	]

	edge-id: 1
	while [edge-id <= verified-control/edge-count][
		edge-kind: edge-value verified-control edge-id WIRE_RSIR_EDGE_KIND_OFFSET
		if edge-kind <> WIRE_EDGE_KIND_EXCEPTION [
			source: edge-value verified-control edge-id WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
			target: edge-value verified-control edge-id WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
			source-region: region-for-block verified-subroutines source
			target-region: region-for-block verified-subroutines target
			if source-region <> target-region [
				return set-error result WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_EDGE
					(verified-control/edges-offset + ((edge-id - 1) * WIRE_RSIR_EDGE_SIZE))
					+ WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET verified-control/edges-ordinal
			]
		]
		edge-id: edge-id + 1
	]
	status: verify-reachability result verified-functions verified-control verified-subroutines
		regions workspace
	if status <> WIRE_SUBROUTINE_ERROR_SUCCESS [return status]
	status: verify-returns result verified-scalar verified-functions verified-types verified-subroutines
	if status <> WIRE_SUBROUTINE_ERROR_SUCCESS [return status]
	status: verify-calls-and-operands result verified-scalar verified-functions verified-calls verified-subroutines
	if status <> WIRE_SUBROUTINE_ERROR_SUCCESS [return status]

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
	copy-view subroutines verified-subroutines
	WIRE_SUBROUTINE_ERROR_SUCCESS
]
]
