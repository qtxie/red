Red/System [
	Title: "Hybrid compiler RSIR function and signature verifier"
	File:  %wire-function-signature.reds
]

#include %wire-type-layout.reds

wire-function-signature-result!: alias struct! [
	error             [integer!]
	container-error   [integer!]
	string-error      [integer!]
	file-source-error [integer!]
	data-layout-error [integer!]
	type-layout-error [integer!]
	error-offset      [integer!]
	error-section     [integer!]
]

wire-function-signature!: alias struct! [
	signatures            [byte-ptr!]
	signature-count       [integer!]
	signature-record-size [integer!]
	signatures-offset     [integer!]
	signatures-ordinal    [integer!]
	parameters            [byte-ptr!]
	parameter-count       [integer!]
	parameter-record-size [integer!]
	parameters-offset     [integer!]
	parameters-ordinal    [integer!]
	symbol-count          [integer!]
	functions             [byte-ptr!]
	function-count        [integer!]
	function-record-size  [integer!]
	functions-offset      [integer!]
	functions-ordinal     [integer!]
	locals                [byte-ptr!]
	local-count           [integer!]
	local-record-size     [integer!]
	locals-offset         [integer!]
	locals-ordinal        [integer!]
	blocks                [byte-ptr!]
	block-count           [integer!]
	block-record-size     [integer!]
	blocks-offset         [integer!]
	blocks-ordinal        [integer!]
	source-location-count [integer!]
]

wire-function-signature-reader: context [
	signature-flag-mask: WIRE_FUNCTION_FLAG_VARIADIC
		+ WIRE_FUNCTION_FLAG_TYPED
		+ WIRE_FUNCTION_FLAG_CUSTOM
		+ WIRE_FUNCTION_FLAG_CALLBACK
		+ WIRE_FUNCTION_FLAG_NO_RETURN
		+ WIRE_FUNCTION_FLAG_MAY_THROW
	variable-flag-mask: WIRE_FUNCTION_FLAG_VARIADIC
		+ WIRE_FUNCTION_FLAG_TYPED
		+ WIRE_FUNCTION_FLAG_CUSTOM

	set-error: func [
		result [wire-function-signature-result!]
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

	record-offset: func [
		section [wire-section-slice!]
		id record-size [integer!]
		return: [integer!]
	][
		section/offset + ((id - 1) * record-size)
	]

	record-value: func [
		section [wire-section-slice!]
		id record-size field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 section/data
			(((id - 1) * record-size) + field-offset)
	]

	type-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/types
			(((id - 1) * WIRE_RSIR_TYPE_SIZE) + field-offset)
	]

	nonempty-string?: func [
		strings [wire-string-table!]
		id [integer!]
		return: [logic!]
		/local slice [wire-string-slice!]
	][
		slice: declare wire-string-slice!
		all [
			wire-string-table-reader/get-slice strings id slice
			slice/size > 0
		]
	]

	nonvoid-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			id > 0
			id <= types/type-count
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

	pointer-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [
			nonvoid-type? types id
			(type-value types id WIRE_RSIR_TYPE_KIND_OFFSET) = WIRE_TYPE_KIND_POINTER
		]
	]

	debug-code-valid?: func [
		types [wire-type-layout!]
		type-id code [integer!]
		return: [logic!]
		/local kind flags type-size [integer!]
	][
		kind: type-value types type-id WIRE_RSIR_TYPE_KIND_OFFSET
		flags: type-value types type-id WIRE_RSIR_TYPE_FLAGS_OFFSET
		type-size: type-value types type-id WIRE_RSIR_TYPE_SIZE_OFFSET
		case [
			kind = WIRE_TYPE_KIND_LOGIC [
				return code = WIRE_DEBUG_TYPE_CODE_LOGIC
			]
			kind = WIRE_TYPE_KIND_INTEGER [
				case [
					type-size = 1 [
						either flags = WIRE_TYPE_FLAG_SIGNED [
							return code = WIRE_DEBUG_TYPE_CODE_INT8
						][
							return any [
								code = WIRE_DEBUG_TYPE_CODE_BYTE
								code = WIRE_DEBUG_TYPE_CODE_UINT8
							]
						]
					]
					type-size = 2 [
						either flags = WIRE_TYPE_FLAG_SIGNED [
							return code = WIRE_DEBUG_TYPE_CODE_INT16
						][return code = WIRE_DEBUG_TYPE_CODE_UINT16]
					]
					type-size = 4 [
						either flags = WIRE_TYPE_FLAG_SIGNED [
							return code = WIRE_DEBUG_TYPE_CODE_INTEGER
						][return code = WIRE_DEBUG_TYPE_CODE_UINT32]
					]
					type-size = 8 [
						either flags = WIRE_TYPE_FLAG_SIGNED [
							return code = WIRE_DEBUG_TYPE_CODE_INT64
						][return code = WIRE_DEBUG_TYPE_CODE_UINT64]
					]
					true [return false]
				]
			]
			kind = WIRE_TYPE_KIND_FLOAT [
				either type-size = 4 [
					return code = WIRE_DEBUG_TYPE_CODE_FLOAT32
				][return code = WIRE_DEBUG_TYPE_CODE_FLOAT64]
			]
			kind = WIRE_TYPE_KIND_POINTER [
				either flags = WIRE_TYPE_FLAG_C_STRING [
					return code = WIRE_DEBUG_TYPE_CODE_C_STRING
				][
					return any [
						code = WIRE_DEBUG_TYPE_CODE_BYTE_POINTER
						code = WIRE_DEBUG_TYPE_CODE_INTEGER_POINTER
						code = WIRE_DEBUG_TYPE_CODE_POINTER_POINTER
						code = WIRE_DEBUG_TYPE_CODE_AGGREGATE
					]
				]
			]
			kind = WIRE_TYPE_KIND_FUNCTION [
				return code = WIRE_DEBUG_TYPE_CODE_FUNCTION
			]
			any [kind = WIRE_TYPE_KIND_STRUCT kind = WIRE_TYPE_KIND_UNION] [
				return code = WIRE_DEBUG_TYPE_CODE_AGGREGATE
			]
			true [return false]
		]
	]

	copy-strings: func [destination source [wire-string-table!]][
		destination/records: source/records
		destination/record-count: source/record-count
		destination/record-size: source/record-size
		destination/records-offset: source/records-offset
		destination/records-ordinal: source/records-ordinal
		destination/data: source/data
		destination/data-size: source/data-size
		destination/data-offset: source/data-offset
		destination/data-ordinal: source/data-ordinal
	]

	copy-files: func [destination source [wire-file-source!]][
		destination/files: source/files
		destination/file-count: source/file-count
		destination/file-record-size: source/file-record-size
		destination/files-offset: source/files-offset
		destination/files-ordinal: source/files-ordinal
		destination/checksum-data: source/checksum-data
		destination/checksum-data-size: source/checksum-data-size
		destination/checksum-data-offset: source/checksum-data-offset
		destination/checksum-data-ordinal: source/checksum-data-ordinal
		destination/source-present: source/source-present
		destination/sources: source/sources
		destination/source-count: source/source-count
		destination/source-record-size: source/source-record-size
		destination/source-offset: source/source-offset
		destination/source-ordinal: source/source-ordinal
	]

	copy-layout: func [destination source [wire-data-layout!]][
		destination/address-unit: source/address-unit
		destination/pointer-size: source/pointer-size
		destination/pointer-alignment: source/pointer-alignment
		destination/stack-alignment: source/stack-alignment
		destination/max-scalar-alignment: source/max-scalar-alignment
		destination/max-aggregate-alignment: source/max-aggregate-alignment
		destination/integer-register-width: source/integer-register-width
		destination/flags: source/flags
	]

	copy-types: func [destination source [wire-type-layout!]][
		destination/types: source/types
		destination/type-count: source/type-count
		destination/type-record-size: source/type-record-size
		destination/types-offset: source/types-offset
		destination/types-ordinal: source/types-ordinal
		destination/fields: source/fields
		destination/field-count: source/field-count
		destination/field-record-size: source/field-record-size
		destination/fields-offset: source/fields-offset
		destination/fields-ordinal: source/fields-ordinal
		destination/signature-count: source/signature-count
		destination/source-location-count: source/source-location-count
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-function-signature-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		types [wire-type-layout!]
		view [wire-function-signature!]
		return: [integer!]
		/local type-result [wire-type-layout-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			signatures parameters symbols functions locals blocks [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative signature-count parameter-count symbol-count
			function-count local-count block-count source-count record-index
			signature-id parameter-id function-id local-id block-id record-base
			calling-convention flags variable-mode return-type first-parameter
			owned-count finish logical-arity expected-logical source-location
			expected-first parameter-signature name-string type-id ordinal debug-code
			function-symbol function-signature function-flags first-block
			owned-block-count entry-block first-local owned-local-count block-owner
			kind alignment type-alignment max-local-alignment
			signature-parameter-count argument-index parameter-name parameter-type
			expected-max [integer!]
	][
		if null? result [return WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/type-layout-error: WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [
			size < 0
			null? data
			null? strings
			null? files
			null? layout
			null? types
			null? view
		][
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_ARGUMENTS 0 0
		]

		type-result: declare wire-type-layout-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		status: wire-type-layout-reader/verify data size type-result
			verified-strings verified-files verified-layout verified-types
		if status <> WIRE_TYPE_LAYOUT_ERROR_SUCCESS [
			result/container-error: type-result/container-error
			result/string-error: type-result/string-error
			result/file-source-error: type-result/file-source-error
			result/data-layout-error: type-result/data-layout-error
			result/type-layout-error: status
			case [
				status = WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
						type-result/error-offset type-result/error-section
				]
				status = WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_STRINGS
						type-result/error-offset type-result/error-section
				]
				status = WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_FILE_SOURCE
						type-result/error-offset type-result/error-section
				]
				status = WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_DATA_LAYOUT
						type-result/error-offset type-result/error-section
				]
				true [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_TYPE_LAYOUT
						type-result/error-offset type-result/error-section
				]
			]
		]

		signatures: declare wire-section-slice!
		parameters: declare wire-section-slice!
		symbols: declare wire-section-slice!
		functions: declare wire-section-slice!
		locals: declare wire-section-slice!
		blocks: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_SIGNATURES signatures
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_PARAMETERS parameters
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_SYMBOLS symbols [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_FUNCTIONS functions
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_LOCALS locals [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_BLOCKS blocks [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if signatures/flags <> 0 [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SECTION_FLAGS
				section-flags-offset signatures signatures/ordinal
		]
		if parameters/flags <> 0 [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SECTION_FLAGS
				section-flags-offset parameters parameters/ordinal
		]
		if functions/flags <> 0 [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SECTION_FLAGS
				section-flags-offset functions functions/ordinal
		]
		if locals/flags <> 0 [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SECTION_FLAGS
				section-flags-offset locals locals/ordinal
		]
		if blocks/flags <> 0 [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SECTION_FLAGS
				section-flags-offset blocks blocks/ordinal
		]

		signature-count: signatures/record-count
		parameter-count: parameters/record-count
		symbol-count: symbols/record-count
		function-count: functions/record-count
		local-count: locals/record-count
		block-count: blocks/record-count
		source-count: verified-types/source-location-count

		; Decode every signed scalar before following any semantic reference.
		record-index: 0
		while [record-index < signature-count][
			record: signatures/data + (record-index * WIRE_RSIR_SIGNATURE_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
					((signatures/offset + (record-index * WIRE_RSIR_SIGNATURE_SIZE))
						+ bad-relative) signatures/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < parameter-count][
			record: parameters/data + (record-index * WIRE_RSIR_PARAMETER_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
					((parameters/offset + (record-index * WIRE_RSIR_PARAMETER_SIZE))
						+ bad-relative) parameters/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < function-count][
			record: functions/data + (record-index * WIRE_RSIR_FUNCTION_SIZE)
			bad-relative: first-bad-scalar record 10
			if bad-relative >= 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
					((functions/offset + (record-index * WIRE_RSIR_FUNCTION_SIZE))
						+ bad-relative) functions/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < local-count][
			record: locals/data + (record-index * WIRE_RSIR_LOCAL_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
					((locals/offset + (record-index * WIRE_RSIR_LOCAL_SIZE))
						+ bad-relative) locals/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < block-count][
			record: blocks/data + (record-index * WIRE_RSIR_BLOCK_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
					((blocks/offset + (record-index * WIRE_RSIR_BLOCK_SIZE))
						+ bad-relative) blocks/ordinal
			]
			record-index: record-index + 1
		]

		; Signatures own one contiguous parameter slice in stable table order.
		expected-first: 1
		signature-id: 1
		while [signature-id <= signature-count][
			record-base: record-offset signatures signature-id WIRE_RSIR_SIGNATURE_SIZE
			calling-convention: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
			unless all [
				calling-convention >= WIRE_CALLING_CONVENTION_RED_SYSTEM
				calling-convention <= WIRE_CALLING_CONVENTION_SYSCALL
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_CALLING_CONVENTION
					(record-base + WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
					signatures/ordinal
			]
			flags: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			variable-mode: flags and variable-flag-mask
			if any [
				(flags and signature-flag-mask) <> flags
				not any [
					variable-mode = 0
					variable-mode = WIRE_FUNCTION_FLAG_VARIADIC
					variable-mode = WIRE_FUNCTION_FLAG_TYPED
					variable-mode = WIRE_FUNCTION_FLAG_CUSTOM
				]
				all [
					(flags and WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					variable-mode <> 0
				]
				all [
					(flags and WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					not any [
						calling-convention = WIRE_CALLING_CONVENTION_CDECL
						calling-convention = WIRE_CALLING_CONVENTION_STDCALL
					]
				]
				all [
					calling-convention = WIRE_CALLING_CONVENTION_SYSCALL
					(flags and (variable-flag-mask + WIRE_FUNCTION_FLAG_CALLBACK)) <> 0
				]
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
					(record-base + WIRE_RSIR_SIGNATURE_FLAGS_OFFSET) signatures/ordinal
			]
			return-type: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
			if any [return-type <= 0 return-type > verified-types/type-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_RETURN_TYPE
					(record-base + WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET)
					signatures/ordinal
			]
			first-parameter: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			either owned-count = 0 [
				if first-parameter <> 0 [
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
						(record-base + WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET)
						signatures/ordinal
				]
			][
				finish: wire-container-reader/checked-add first-parameter (owned-count - 1)
				if any [
					first-parameter <> expected-first
					finish < 0
					finish > parameter-count
				][
					return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
						(record-base + WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET)
						signatures/ordinal
				]
				expected-first: finish + 1
			]
			logical-arity: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET
			expected-logical: case [
				variable-mode = WIRE_FUNCTION_FLAG_CUSTOM [0]
				variable-mode = WIRE_FUNCTION_FLAG_TYPED [0]
				all [
					variable-mode = WIRE_FUNCTION_FLAG_VARIADIC
					calling-convention <> WIRE_CALLING_CONVENTION_CDECL
				][0]
				true [owned-count]
			]
			if logical-arity <> expected-logical [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOGICAL_ARITY
					(record-base + WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET)
					signatures/ordinal
			]
			source-location: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SOURCE_LOCATION
					(record-base + WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET)
					signatures/ordinal
			]
			if (record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_RESERVED_OFFSET) <> 0
			[
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_SIGNATURE_RESERVED
					(record-base + WIRE_RSIR_SIGNATURE_RESERVED_OFFSET)
					signatures/ordinal
			]
			signature-id: signature-id + 1
		]
		if expected-first <> (parameter-count + 1) [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_COVERAGE
				parameters/offset parameters/ordinal
		]

		; Parameters carry source names/types and reverse ownership references.
		parameter-id: 1
		while [parameter-id <= parameter-count][
			record-base: record-offset parameters parameter-id WIRE_RSIR_PARAMETER_SIZE
			parameter-signature: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET
			if any [parameter-signature <= 0 parameter-signature > signature-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SIGNATURE
					(record-base + WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET)
					parameters/ordinal
			]
			first-parameter: record-value signatures parameter-signature
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: record-value signatures parameter-signature
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			if any [
				owned-count = 0
				parameter-id < first-parameter
				parameter-id >= (first-parameter + owned-count)
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SIGNATURE
					(record-base + WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET)
					parameters/ordinal
			]
			name-string: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
			if any [name-string <= 0 name-string > verified-strings/record-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_NAME_ID
					(record-base + WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET)
					parameters/ordinal
			]
			unless nonempty-string? verified-strings name-string [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_PARAMETER_NAME
					(record-base + WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET)
					parameters/ordinal
			]
			type-id: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_TYPE_OFFSET
			unless nonvoid-type? verified-types type-id [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_TYPE
					(record-base + WIRE_RSIR_PARAMETER_TYPE_OFFSET) parameters/ordinal
			]
			if (record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_FLAGS_OFFSET) <> 0
			[
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_FLAGS
					(record-base + WIRE_RSIR_PARAMETER_FLAGS_OFFSET) parameters/ordinal
			]
			ordinal: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_ORDINAL_OFFSET
			if ordinal <> (parameter-id - first-parameter) [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_ORDINAL
					(record-base + WIRE_RSIR_PARAMETER_ORDINAL_OFFSET) parameters/ordinal
			]
			debug-code: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET
			unless debug-code-valid? verified-types type-id debug-code [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_DEBUG_TYPE_CODE
					(record-base + WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
					parameters/ordinal
			]
			source-location: record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SOURCE_LOCATION
					(record-base + WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET)
					parameters/ordinal
			]
			if (record-value parameters parameter-id
				WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_RESERVED_OFFSET) <> 0
			[
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_RESERVED
					(record-base + WIRE_RSIR_PARAMETER_RESERVED_OFFSET)
					parameters/ordinal
			]
			parameter-id: parameter-id + 1
		]

		; Typed calls expose an optional prefix of their packed receiver protocol.
		; Private variadics do the same; C cdecl variadics retain ordinary named
		; parameters instead.
		signature-id: 1
		while [signature-id <= signature-count][
			calling-convention: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
			flags: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			variable-mode: flags and variable-flag-mask
			first-parameter: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: record-value signatures signature-id
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			if all [
				variable-mode = WIRE_FUNCTION_FLAG_CUSTOM
				owned-count <> 0
			][
				record-base: record-offset signatures signature-id WIRE_RSIR_SIGNATURE_SIZE
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
					(record-base + WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
					signatures/ordinal
			]
			if any [
				variable-mode = WIRE_FUNCTION_FLAG_TYPED
				all [
					calling-convention <> WIRE_CALLING_CONVENTION_CDECL
					variable-mode = WIRE_FUNCTION_FLAG_VARIADIC
				]
			][
				expected-max: either variable-mode = WIRE_FUNCTION_FLAG_TYPED [2][3]
				if owned-count > expected-max [
					record-base: record-offset signatures signature-id WIRE_RSIR_SIGNATURE_SIZE
					return set-error result
						WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
						(record-base + WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
						signatures/ordinal
				]
				if owned-count >= 1 [
					type-id: record-value parameters first-parameter
						WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless integer32-type? verified-types type-id [
						record-base: record-offset parameters first-parameter
							WIRE_RSIR_PARAMETER_SIZE
						return set-error result
							WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							parameters/ordinal
					]
				]
				if owned-count >= 2 [
					type-id: record-value parameters (first-parameter + 1)
						WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless pointer-type? verified-types type-id [
						record-base: record-offset parameters (first-parameter + 1)
							WIRE_RSIR_PARAMETER_SIZE
						return set-error result
							WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							parameters/ordinal
					]
				]
				if owned-count = 3 [
					type-id: record-value parameters (first-parameter + 2)
						WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless integer32-type? verified-types type-id [
						record-base: record-offset parameters (first-parameter + 2)
							WIRE_RSIR_PARAMETER_SIZE
						return set-error result
							WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							parameters/ordinal
					]
				]
			]
			signature-id: signature-id + 1
		]

		; Function records are body definitions, not declarations. They own at
		; least one block and may own an empty or contiguous local slice.
		expected-first: 1
		function-id: 1
		while [function-id <= function-count][
			record-base: record-offset functions function-id WIRE_RSIR_FUNCTION_SIZE
			function-symbol: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
			if any [function-symbol <= 0 function-symbol > symbol-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SYMBOL
					(record-base + WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) functions/ordinal
			]
			function-signature: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			if any [function-signature <= 0 function-signature > signature-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SIGNATURE
					(record-base + WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET) functions/ordinal
			]
			function-flags: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FLAGS_OFFSET
			if function-flags <> 0 [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_FLAGS
					(record-base + WIRE_RSIR_FUNCTION_FLAGS_OFFSET) functions/ordinal
			]
			first-block: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			owned-block-count: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			finish: wire-container-reader/checked-add first-block (owned-block-count - 1)
			if any [
				owned-block-count <= 0
				first-block <> expected-first
				finish < 0
				finish > block-count
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_BLOCK_RANGE
					(record-base + WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET) functions/ordinal
			]
			entry-block: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
			if any [entry-block < first-block entry-block > finish][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_ENTRY_BLOCK
					(record-base + WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET) functions/ordinal
			]
			expected-first: finish + 1
			first-local: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			either owned-local-count = 0 [
				if first-local <> 0 [
					return set-error result
						WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						functions/ordinal
				]
			][
				finish: wire-container-reader/checked-add first-local (owned-local-count - 1)
				if any [first-local <= 0 finish < 0 finish > local-count][
					return set-error result
						WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						functions/ordinal
				]
			]
			source-location: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SOURCE_LOCATION
					(record-base + WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET)
					functions/ordinal
			]
			if (record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_RESERVED_OFFSET) <> 0
			[
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_RESERVED
					(record-base + WIRE_RSIR_FUNCTION_RESERVED_OFFSET)
					functions/ordinal
			]
			function-id: function-id + 1
		]
		if expected-first <> (block-count + 1) [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_COVERAGE
				blocks/offset blocks/ordinal
		]

		expected-first: 1
		function-id: 1
		while [function-id <= function-count][
			first-local: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if owned-local-count > 0 [
				if first-local <> expected-first [
					record-base: record-offset functions function-id WIRE_RSIR_FUNCTION_SIZE
					return set-error result
						WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						functions/ordinal
				]
				expected-first: first-local + owned-local-count
			]
			function-id: function-id + 1
		]
		if expected-first <> (local-count + 1) [
			return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_COVERAGE
				locals/offset locals/ordinal
		]

		block-id: 1
		while [block-id <= block-count][
			record-base: record-offset blocks block-id WIRE_RSIR_BLOCK_SIZE
			block-owner: record-value blocks block-id
				WIRE_RSIR_BLOCK_SIZE WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			if any [block-owner <= 0 block-owner > function-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_OWNER
					(record-base + WIRE_RSIR_BLOCK_FUNCTION_OFFSET) blocks/ordinal
			]
			first-block: record-value functions block-owner
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			owned-block-count: record-value functions block-owner
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			if any [
				block-id < first-block
				block-id >= (first-block + owned-block-count)
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_OWNER
					(record-base + WIRE_RSIR_BLOCK_FUNCTION_OFFSET) blocks/ordinal
			]
			if (record-value blocks block-id
				WIRE_RSIR_BLOCK_SIZE WIRE_RSIR_BLOCK_FLAGS_OFFSET) <> 0
			[
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_FLAGS
					(record-base + WIRE_RSIR_BLOCK_FLAGS_OFFSET) blocks/ordinal
			]
			source-location: record-value blocks block-id
				WIRE_RSIR_BLOCK_SIZE WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SOURCE_LOCATION
					(record-base + WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET) blocks/ordinal
			]
			if (record-value blocks block-id
				WIRE_RSIR_BLOCK_SIZE WIRE_RSIR_BLOCK_RESERVED_OFFSET) <> 0
			[
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_RESERVED
					(record-base + WIRE_RSIR_BLOCK_RESERVED_OFFSET) blocks/ordinal
			]
			block-id: block-id + 1
		]

		max-local-alignment: verified-layout/stack-alignment
		local-id: 1
		while [local-id <= local-count][
			record-base: record-offset locals local-id WIRE_RSIR_LOCAL_SIZE
			function-id: record-value locals local-id
				WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_FUNCTION_OFFSET
			if any [function-id <= 0 function-id > function-count][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_FUNCTION
					(record-base + WIRE_RSIR_LOCAL_FUNCTION_OFFSET) locals/ordinal
			]
			first-local: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if any [
				owned-local-count = 0
				local-id < first-local
				local-id >= (first-local + owned-local-count)
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_FUNCTION
					(record-base + WIRE_RSIR_LOCAL_FUNCTION_OFFSET) locals/ordinal
			]
			kind: record-value locals local-id WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_KIND_OFFSET
			unless all [kind >= WIRE_LOCAL_KIND_ARGUMENT kind <= WIRE_LOCAL_KIND_MERGE][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_KIND
					(record-base + WIRE_RSIR_LOCAL_KIND_OFFSET) locals/ordinal
			]
			name-string: record-value locals local-id
				WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_NAME_STRING_OFFSET
			if any [
				name-string > verified-strings/record-count
				all [
					name-string = 0
					any [kind = WIRE_LOCAL_KIND_ARGUMENT kind = WIRE_LOCAL_KIND_LOCAL]
				]
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_NAME_ID
					(record-base + WIRE_RSIR_LOCAL_NAME_STRING_OFFSET) locals/ordinal
			]
			if all [name-string > 0 not nonempty-string? verified-strings name-string][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_LOCAL_NAME
					(record-base + WIRE_RSIR_LOCAL_NAME_STRING_OFFSET) locals/ordinal
			]
			type-id: record-value locals local-id WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_TYPE_OFFSET
			unless nonvoid-type? verified-types type-id [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_TYPE
					(record-base + WIRE_RSIR_LOCAL_TYPE_OFFSET) locals/ordinal
			]
			if (record-value locals local-id
				WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_FLAGS_OFFSET) <> 0
			[
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_LOCAL_FLAGS
					(record-base + WIRE_RSIR_LOCAL_FLAGS_OFFSET) locals/ordinal
			]
			alignment: record-value locals local-id
				WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET
			type-alignment: type-value verified-types type-id WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			if all [
				alignment <> 0
				any [
					not wire-container-reader/power-of-two? alignment
					alignment < type-alignment
					alignment > max-local-alignment
				]
			][
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ALIGNMENT
					(record-base + WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET) locals/ordinal
			]
			source-location: record-value locals local-id
				WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result
					WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SOURCE_LOCATION
					(record-base + WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET) locals/ordinal
			]
			ordinal: record-value locals local-id WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_ORDINAL_OFFSET
			if ordinal <> (local-id - first-local) [
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ORDINAL
					(record-base + WIRE_RSIR_LOCAL_ORDINAL_OFFSET) locals/ordinal
			]
			local-id: local-id + 1
		]

		; Argument locals are the exact name/type prefix of the function's
		; signature. No later local may claim argument kind.
		function-id: 1
		while [function-id <= function-count][
			function-signature: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			signature-parameter-count: record-value signatures function-signature
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			first-parameter: record-value signatures function-signature
				WIRE_RSIR_SIGNATURE_SIZE WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			first-local: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: record-value functions function-id
				WIRE_RSIR_FUNCTION_SIZE WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if owned-local-count < signature-parameter-count [
				record-base: record-offset functions function-id WIRE_RSIR_FUNCTION_SIZE
				return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
					(record-base + WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET) functions/ordinal
			]
			argument-index: 0
			while [argument-index < owned-local-count][
				local-id: first-local + argument-index
				kind: record-value locals local-id WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_KIND_OFFSET
				either argument-index < signature-parameter-count [
					if kind <> WIRE_LOCAL_KIND_ARGUMENT [
						record-base: record-offset locals local-id WIRE_RSIR_LOCAL_SIZE
						return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + WIRE_RSIR_LOCAL_KIND_OFFSET) locals/ordinal
					]
					parameter-id: first-parameter + argument-index
					parameter-name: record-value parameters parameter-id
						WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
					parameter-type: record-value parameters parameter-id
						WIRE_RSIR_PARAMETER_SIZE WIRE_RSIR_PARAMETER_TYPE_OFFSET
					if (record-value locals local-id
						WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_NAME_STRING_OFFSET) <> parameter-name
					[
						record-base: record-offset locals local-id WIRE_RSIR_LOCAL_SIZE
						return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + WIRE_RSIR_LOCAL_NAME_STRING_OFFSET) locals/ordinal
					]
					if (record-value locals local-id
						WIRE_RSIR_LOCAL_SIZE WIRE_RSIR_LOCAL_TYPE_OFFSET) <> parameter-type
					[
						record-base: record-offset locals local-id WIRE_RSIR_LOCAL_SIZE
						return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + WIRE_RSIR_LOCAL_TYPE_OFFSET) locals/ordinal
					]
				][
					if kind = WIRE_LOCAL_KIND_ARGUMENT [
						record-base: record-offset locals local-id WIRE_RSIR_LOCAL_SIZE
						return set-error result WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + WIRE_RSIR_LOCAL_KIND_OFFSET) locals/ordinal
					]
				]
				argument-index: argument-index + 1
			]
			function-id: function-id + 1
		]

		copy-strings strings verified-strings
		copy-files files verified-files
		copy-layout layout verified-layout
		copy-types types verified-types
		view/signatures: signatures/data
		view/signature-count: signature-count
		view/signature-record-size: signatures/record-size
		view/signatures-offset: signatures/offset
		view/signatures-ordinal: signatures/ordinal
		view/parameters: parameters/data
		view/parameter-count: parameter-count
		view/parameter-record-size: parameters/record-size
		view/parameters-offset: parameters/offset
		view/parameters-ordinal: parameters/ordinal
		view/symbol-count: symbol-count
		view/functions: functions/data
		view/function-count: function-count
		view/function-record-size: functions/record-size
		view/functions-offset: functions/offset
		view/functions-ordinal: functions/ordinal
		view/locals: locals/data
		view/local-count: local-count
		view/local-record-size: locals/record-size
		view/locals-offset: locals/offset
		view/locals-ordinal: locals/ordinal
		view/blocks: blocks/data
		view/block-count: block-count
		view/block-record-size: blocks/record-size
		view/blocks-offset: blocks/offset
		view/blocks-ordinal: blocks/ordinal
		view/source-location-count: source-count
		WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
	]
]
