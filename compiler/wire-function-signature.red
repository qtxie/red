Red [
	Title: "Hybrid compiler RSIR function and signature verifier"
	File:  %wire-function-signature.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-type-layout [do %wire-type-layout.red]

compiler-wire-function-signature: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	type-layout-verifier: compiler-wire-type-layout

	signature-flag-mask: schema/WIRE_FUNCTION_FLAG_VARIADIC
		+ schema/WIRE_FUNCTION_FLAG_TYPED
		+ schema/WIRE_FUNCTION_FLAG_CUSTOM
		+ schema/WIRE_FUNCTION_FLAG_CALLBACK
		+ schema/WIRE_FUNCTION_FLAG_NO_RETURN
		+ schema/WIRE_FUNCTION_FLAG_MAY_THROW
	variable-flag-mask: schema/WIRE_FUNCTION_FLAG_VARIADIC
		+ schema/WIRE_FUNCTION_FLAG_TYPED
		+ schema/WIRE_FUNCTION_FLAG_CUSTOM

	signature-fields: reduce [
		'calling-convention schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
		'flags              schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
		'return-type        schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
		'first-parameter    schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
		'parameter-count    schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
		'logical-arity      schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET
		'source-location    schema/WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET
		'reserved           schema/WIRE_RSIR_SIGNATURE_RESERVED_OFFSET
	]

	parameter-fields: reduce [
		'signature       schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET
		'name-string     schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
		'type            schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
		'flags           schema/WIRE_RSIR_PARAMETER_FLAGS_OFFSET
		'ordinal         schema/WIRE_RSIR_PARAMETER_ORDINAL_OFFSET
		'debug-type-code schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET
		'source-location schema/WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET
		'reserved        schema/WIRE_RSIR_PARAMETER_RESERVED_OFFSET
	]

	function-fields: reduce [
		'symbol          schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
		'signature       schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
		'flags           schema/WIRE_RSIR_FUNCTION_FLAGS_OFFSET
		'first-block     schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
		'block-count     schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
		'entry-block     schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
		'first-local     schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
		'local-count     schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
		'source-location schema/WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET
		'reserved        schema/WIRE_RSIR_FUNCTION_RESERVED_OFFSET
	]

	local-fields: reduce [
		'function        schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET
		'name-string     schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET
		'type            schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
		'kind            schema/WIRE_RSIR_LOCAL_KIND_OFFSET
		'flags           schema/WIRE_RSIR_LOCAL_FLAGS_OFFSET
		'alignment       schema/WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET
		'source-location schema/WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET
		'ordinal         schema/WIRE_RSIR_LOCAL_ORDINAL_OFFSET
	]

	block-fields: reduce [
		'function            schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
		'flags               schema/WIRE_RSIR_BLOCK_FLAGS_OFFSET
		'first-instruction   schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET
		'instruction-count   schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
		'first-outgoing-edge schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET
		'outgoing-edge-count schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET
		'source-location     schema/WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET
		'reserved            schema/WIRE_RSIR_BLOCK_RESERVED_OFFSET
	]

	make-view: does [
		make object! [
			signature-count: 0
			signatures-offset: 0
			signatures-ordinal: 0
			signature-record-size: schema/WIRE_RSIR_SIGNATURE_SIZE
			parameter-count: 0
			parameters-offset: 0
			parameters-ordinal: 0
			parameter-record-size: schema/WIRE_RSIR_PARAMETER_SIZE
			symbol-count: 0
			function-count: 0
			functions-offset: 0
			functions-ordinal: 0
			function-record-size: schema/WIRE_RSIR_FUNCTION_SIZE
			local-count: 0
			locals-offset: 0
			locals-ordinal: 0
			local-record-size: schema/WIRE_RSIR_LOCAL_SIZE
			block-count: 0
			blocks-offset: 0
			blocks-ordinal: 0
			block-record-size: schema/WIRE_RSIR_BLOCK_SIZE
			source-location-count: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			type-layout-error: schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			types: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-offset: func [base index size [integer!]][base + (index * size)]

	signature-value: func [data [binary!] view [object!] id field [integer!]][
		container/read-i31 data ((record-offset view/signatures-offset (id - 1)
			schema/WIRE_RSIR_SIGNATURE_SIZE) + field)
	]

	parameter-value: func [data [binary!] view [object!] id field [integer!]][
		container/read-i31 data ((record-offset view/parameters-offset (id - 1)
			schema/WIRE_RSIR_PARAMETER_SIZE) + field)
	]

	function-value: func [data [binary!] view [object!] id field [integer!]][
		container/read-i31 data ((record-offset view/functions-offset (id - 1)
			schema/WIRE_RSIR_FUNCTION_SIZE) + field)
	]

	local-value: func [data [binary!] view [object!] id field [integer!]][
		container/read-i31 data ((record-offset view/locals-offset (id - 1)
			schema/WIRE_RSIR_LOCAL_SIZE) + field)
	]

	block-value: func [data [binary!] view [object!] id field [integer!]][
		container/read-i31 data ((record-offset view/blocks-offset (id - 1)
			schema/WIRE_RSIR_BLOCK_SIZE) + field)
	]

	type-value: func [data [binary!] types [object!] id field [integer!]][
		container/read-i31 data ((record-offset types/types-offset (id - 1)
			schema/WIRE_RSIR_TYPE_SIZE) + field)
	]

	string-size-for-id: func [data [binary!] strings [object!] id [integer!]][
		if any [id <= 0 id > strings/record-count][return none]
		container/read-i31 data (strings/records-offset
			+ (((id - 1) * schema/WIRE_STRING_SIZE)
			+ schema/WIRE_STRING_SIZE_OFFSET))
	]

	power-of-two?: func [value [integer!]][
		all [value > 0 zero? (value and (value - 1))]
	]

	nonvoid-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			id > 0
			id <= types/type-count
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

	pointer-type?: func [data [binary!] types [object!] id [integer!]][
		all [
			nonvoid-type? data types id
			(type-value data types id schema/WIRE_RSIR_TYPE_KIND_OFFSET)
				= schema/WIRE_TYPE_KIND_POINTER
		]
	]

	debug-code-valid?: func [
		data [binary!] types [object!] type-id code [integer!]
		/local kind flags size
	][
		kind: type-value data types type-id schema/WIRE_RSIR_TYPE_KIND_OFFSET
		flags: type-value data types type-id schema/WIRE_RSIR_TYPE_FLAGS_OFFSET
		size: type-value data types type-id schema/WIRE_RSIR_TYPE_SIZE_OFFSET
		case [
			kind = schema/WIRE_TYPE_KIND_LOGIC [
				code = schema/WIRE_DEBUG_TYPE_CODE_LOGIC
			]
			kind = schema/WIRE_TYPE_KIND_INTEGER [
				case [
					size = 1 [
						either flags = schema/WIRE_TYPE_FLAG_SIGNED [
							code = schema/WIRE_DEBUG_TYPE_CODE_INT8
						][
							any [
								code = schema/WIRE_DEBUG_TYPE_CODE_BYTE
								code = schema/WIRE_DEBUG_TYPE_CODE_UINT8
							]
						]
					]
					size = 2 [
						code = either flags = schema/WIRE_TYPE_FLAG_SIGNED [
							schema/WIRE_DEBUG_TYPE_CODE_INT16
						][schema/WIRE_DEBUG_TYPE_CODE_UINT16]
					]
					size = 4 [
						code = either flags = schema/WIRE_TYPE_FLAG_SIGNED [
							schema/WIRE_DEBUG_TYPE_CODE_INTEGER
						][schema/WIRE_DEBUG_TYPE_CODE_UINT32]
					]
					size = 8 [
						code = either flags = schema/WIRE_TYPE_FLAG_SIGNED [
							schema/WIRE_DEBUG_TYPE_CODE_INT64
						][schema/WIRE_DEBUG_TYPE_CODE_UINT64]
					]
					true [false]
				]
			]
			kind = schema/WIRE_TYPE_KIND_FLOAT [
				code = either size = 4 [
					schema/WIRE_DEBUG_TYPE_CODE_FLOAT32
				][schema/WIRE_DEBUG_TYPE_CODE_FLOAT64]
			]
			kind = schema/WIRE_TYPE_KIND_POINTER [
				either flags = schema/WIRE_TYPE_FLAG_C_STRING [
					code = schema/WIRE_DEBUG_TYPE_CODE_C_STRING
				][
					not none? find reduce [
						schema/WIRE_DEBUG_TYPE_CODE_BYTE_POINTER
						schema/WIRE_DEBUG_TYPE_CODE_INTEGER_POINTER
						schema/WIRE_DEBUG_TYPE_CODE_POINTER_POINTER
						schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE
					] code
				]
			]
			kind = schema/WIRE_TYPE_KIND_FUNCTION [
				code = schema/WIRE_DEBUG_TYPE_CODE_FUNCTION
			]
			any [
				kind = schema/WIRE_TYPE_KIND_STRUCT
				kind = schema/WIRE_TYPE_KIND_UNION
			][code = schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE]
			true [false]
		]
	]

	verify: func [
		data
		/local result type-result container-result signatures parameters symbols
			functions locals blocks view signature-count parameter-count symbol-count
			function-count local-count block-count source-count record-index record-base
			field-name field-offset value signature-id parameter-id function-id local-id
			block-id calling-convention flags return-type first-parameter owned-count
			logical-arity source-location reserved finish expected-first variable-mode
			expected-logical name-string type-id ordinal debug-code parameter-signature
			function-symbol function-signature first-block owned-block-count entry-block
			first-local owned-local-count function-flags owner kind alignment
			type-alignment signature-parameter-count argument-index parameter-name
			parameter-type block-owner max-local-alignment
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_ARGUMENTS 0 0
		]

		type-result: type-layout-verifier/verify data
		result/header: type-result/header
		unless type-result/valid? [
			result/container-error: type-result/container-error
			result/string-error: type-result/string-error
			result/file-source-error: type-result/file-source-error
			result/data-layout-error: type-result/data-layout-error
			result/type-layout-error: type-result/error
			case [
				type-result/error = schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
						type-result/error-offset type-result/error-section
				]
				type-result/error = schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_STRINGS
						type-result/error-offset type-result/error-section
				]
				type-result/error = schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_FILE_SOURCE
						type-result/error-offset type-result/error-section
				]
				type-result/error = schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_DATA_LAYOUT
						type-result/error-offset type-result/error-section
				]
				true [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_TYPE_LAYOUT
						type-result/error-offset type-result/error-section
				]
			]
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		signatures: container/find-section container-result schema/WIRE_RSIR_SECTION_SIGNATURES
		parameters: container/find-section container-result schema/WIRE_RSIR_SECTION_PARAMETERS
		symbols: container/find-section container-result schema/WIRE_RSIR_SECTION_SYMBOLS
		functions: container/find-section container-result schema/WIRE_RSIR_SECTION_FUNCTIONS
		locals: container/find-section container-result schema/WIRE_RSIR_SECTION_LOCALS
		blocks: container/find-section container-result schema/WIRE_RSIR_SECTION_BLOCKS
		if any [
			none? signatures none? parameters none? symbols
			none? functions none? locals none? blocks
		][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		foreach [section code] reduce [
			signatures schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SECTION_FLAGS
			parameters schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SECTION_FLAGS
			functions schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SECTION_FLAGS
			locals schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SECTION_FLAGS
			blocks schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SECTION_FLAGS
		][
			if (select section 'flags) <> 0 [
				return reject result code (section-flags-offset section)
					(select section 'ordinal)
			]
		]

		view: make-view
		view/signature-count: signature-count: select signatures 'record-count
		view/signatures-offset: select signatures 'payload-offset
		view/signatures-ordinal: select signatures 'ordinal
		view/signature-record-size: select signatures 'record-size
		view/parameter-count: parameter-count: select parameters 'record-count
		view/parameters-offset: select parameters 'payload-offset
		view/parameters-ordinal: select parameters 'ordinal
		view/parameter-record-size: select parameters 'record-size
		view/symbol-count: symbol-count: select symbols 'record-count
		view/function-count: function-count: select functions 'record-count
		view/functions-offset: select functions 'payload-offset
		view/functions-ordinal: select functions 'ordinal
		view/function-record-size: select functions 'record-size
		view/local-count: local-count: select locals 'record-count
		view/locals-offset: select locals 'payload-offset
		view/locals-ordinal: select locals 'ordinal
		view/local-record-size: select locals 'record-size
		view/block-count: block-count: select blocks 'record-count
		view/blocks-offset: select blocks 'payload-offset
		view/blocks-ordinal: select blocks 'ordinal
		view/block-record-size: select blocks 'record-size
		view/source-location-count: source-count:
			type-result/view/source-location-count

		foreach [count base size section-ordinal fields] reduce [
			signature-count view/signatures-offset schema/WIRE_RSIR_SIGNATURE_SIZE
				view/signatures-ordinal signature-fields
			parameter-count view/parameters-offset schema/WIRE_RSIR_PARAMETER_SIZE
				view/parameters-ordinal parameter-fields
			function-count view/functions-offset schema/WIRE_RSIR_FUNCTION_SIZE
				view/functions-ordinal function-fields
			local-count view/locals-offset schema/WIRE_RSIR_LOCAL_SIZE
				view/locals-ordinal local-fields
		][
			record-index: 0
			while [record-index < count][
				record-base: record-offset base record-index size
				foreach [field-name field-offset] fields [
					value: container/read-i31 data (record-base + field-offset)
					if none? value [
						return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
							(record-base + field-offset) section-ordinal
					]
				]
				record-index: record-index + 1
			]
		]
		block-id: 1
		while [block-id <= block-count][
			record-base: record-offset view/blocks-offset (block-id - 1)
				schema/WIRE_RSIR_BLOCK_SIZE
			foreach [field-name field-offset] block-fields [
				value: container/read-i31 data (record-base + field-offset)
				if none? value [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_SCALAR_RANGE
						(record-base + field-offset) view/blocks-ordinal
				]
			]
			block-id: block-id + 1
		]

		expected-first: 1
		signature-id: 1
		while [signature-id <= signature-count][
			record-base: record-offset view/signatures-offset (signature-id - 1)
				schema/WIRE_RSIR_SIGNATURE_SIZE
			calling-convention: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
			unless all [
				calling-convention >= schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
				calling-convention <= schema/WIRE_CALLING_CONVENTION_SYSCALL
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_CALLING_CONVENTION
					(record-base + schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
					view/signatures-ordinal
			]
			flags: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			variable-mode: flags and variable-flag-mask
			if any [
				(flags and signature-flag-mask) <> flags
				none? find reduce [0 1 2 4] variable-mode
				all [
					(flags and schema/WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					variable-mode <> 0
				]
				all [
					(flags and schema/WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					not find reduce [
						schema/WIRE_CALLING_CONVENTION_CDECL
						schema/WIRE_CALLING_CONVENTION_STDCALL
					] calling-convention
				]
				all [
					calling-convention = schema/WIRE_CALLING_CONVENTION_SYSCALL
					(flags and (variable-flag-mask
						+ schema/WIRE_FUNCTION_FLAG_CALLBACK)) <> 0
				]
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_FLAGS
					(record-base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
					view/signatures-ordinal
			]
			return-type: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET
			if any [return-type <= 0 return-type > type-result/view/type-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_RETURN_TYPE
					(record-base + schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET)
					view/signatures-ordinal
			]
			first-parameter: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			either owned-count = 0 [
				if first-parameter <> 0 [
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
						(record-base + schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET)
						view/signatures-ordinal
				]
			][
				finish: container/checked-add first-parameter (owned-count - 1)
				if any [
					first-parameter <> expected-first
					none? finish
					finish > parameter-count
				][
					return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_RANGE
						(record-base + schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET)
						view/signatures-ordinal
				]
				expected-first: finish + 1
			]
			logical-arity: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET
			expected-logical: case [
				variable-mode = schema/WIRE_FUNCTION_FLAG_CUSTOM [0]
				variable-mode = schema/WIRE_FUNCTION_FLAG_TYPED [0]
				all [
					variable-mode = schema/WIRE_FUNCTION_FLAG_VARIADIC
					calling-convention <> schema/WIRE_CALLING_CONVENTION_CDECL
				][0]
				true [owned-count]
			]
			if logical-arity <> expected-logical [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOGICAL_ARITY
					(record-base + schema/WIRE_RSIR_SIGNATURE_LOGICAL_ARITY_OFFSET)
					view/signatures-ordinal
			]
			source-location: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_SIGNATURE_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_SIGNATURE_SOURCE_LOCATION_OFFSET)
					view/signatures-ordinal
			]
			reserved: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_RESERVED_OFFSET
			if reserved <> 0 [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_SIGNATURE_RESERVED
					(record-base + schema/WIRE_RSIR_SIGNATURE_RESERVED_OFFSET)
					view/signatures-ordinal
			]
			signature-id: signature-id + 1
		]
		if expected-first <> (parameter-count + 1) [
			return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_COVERAGE
				view/parameters-offset view/parameters-ordinal
		]

		parameter-id: 1
		while [parameter-id <= parameter-count][
			record-base: record-offset view/parameters-offset (parameter-id - 1)
				schema/WIRE_RSIR_PARAMETER_SIZE
			parameter-signature: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET
			if any [parameter-signature <= 0 parameter-signature > signature-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SIGNATURE
					(record-base + schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET)
					view/parameters-ordinal
			]
			first-parameter: signature-value data view parameter-signature
				schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: signature-value data view parameter-signature
				schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			if any [
				owned-count = 0
				parameter-id < first-parameter
				parameter-id >= (first-parameter + owned-count)
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SIGNATURE
					(record-base + schema/WIRE_RSIR_PARAMETER_SIGNATURE_OFFSET)
					view/parameters-ordinal
			]
			name-string: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
			if any [name-string <= 0 name-string > type-result/strings/record-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_NAME_ID
					(record-base + schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET)
					view/parameters-ordinal
			]
			if zero? string-size-for-id data type-result/strings name-string [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_PARAMETER_NAME
					(record-base + schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET)
					view/parameters-ordinal
			]
			type-id: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
			unless nonvoid-type? data type-result/view type-id [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_TYPE
					(record-base + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET)
					view/parameters-ordinal
			]
			if (parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_FLAGS_OFFSET) <> 0
			[
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_FLAGS
					(record-base + schema/WIRE_RSIR_PARAMETER_FLAGS_OFFSET)
					view/parameters-ordinal
			]
			ordinal: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_ORDINAL_OFFSET
			if ordinal <> (parameter-id - first-parameter) [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_ORDINAL
					(record-base + schema/WIRE_RSIR_PARAMETER_ORDINAL_OFFSET)
					view/parameters-ordinal
			]
			debug-code: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET
			unless debug-code-valid? data type-result/view type-id debug-code [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_DEBUG_TYPE_CODE
					(record-base + schema/WIRE_RSIR_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
					view/parameters-ordinal
			]
			source-location: parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PARAMETER_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_PARAMETER_SOURCE_LOCATION_OFFSET)
					view/parameters-ordinal
			]
			if (parameter-value data view parameter-id
				schema/WIRE_RSIR_PARAMETER_RESERVED_OFFSET) <> 0
			[
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_PARAMETER_RESERVED
					(record-base + schema/WIRE_RSIR_PARAMETER_RESERVED_OFFSET)
					view/parameters-ordinal
			]
			parameter-id: parameter-id + 1
		]

		; Typed calls expose an optional prefix of their packed receiver protocol.
		; Private variadics do the same; C cdecl variadics retain ordinary named
		; parameters instead.
		signature-id: 1
		while [signature-id <= signature-count][
			calling-convention: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
			flags: signature-value data view signature-id schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
			variable-mode: flags and variable-flag-mask
			first-parameter: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			owned-count: signature-value data view signature-id
				schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			if all [
				variable-mode = schema/WIRE_FUNCTION_FLAG_CUSTOM
				owned-count <> 0
			][
				record-base: record-offset view/signatures-offset (signature-id - 1)
					schema/WIRE_RSIR_SIGNATURE_SIZE
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
					(record-base + schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
					view/signatures-ordinal
			]
			if any [
				variable-mode = schema/WIRE_FUNCTION_FLAG_TYPED
				all [
					calling-convention <> schema/WIRE_CALLING_CONVENTION_CDECL
					variable-mode = schema/WIRE_FUNCTION_FLAG_VARIADIC
				]
			][
				if owned-count > either variable-mode = schema/WIRE_FUNCTION_FLAG_TYPED [2][3][
					record-base: record-offset view/signatures-offset (signature-id - 1)
						schema/WIRE_RSIR_SIGNATURE_SIZE
					return reject result
						schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
						(record-base + schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET)
						view/signatures-ordinal
				]
				if owned-count >= 1 [
					type-id: parameter-value data view first-parameter
						schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless integer32-type? data type-result/view type-id [
						record-base: record-offset view/parameters-offset
							(first-parameter - 1) schema/WIRE_RSIR_PARAMETER_SIZE
						return reject result
							schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							view/parameters-ordinal
					]
				]
				if owned-count >= 2 [
					type-id: parameter-value data view (first-parameter + 1)
						schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless pointer-type? data type-result/view type-id [
						record-base: record-offset view/parameters-offset first-parameter
							schema/WIRE_RSIR_PARAMETER_SIZE
						return reject result
							schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							view/parameters-ordinal
					]
				]
				if owned-count = 3 [
					type-id: parameter-value data view (first-parameter + 2)
						schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
					unless integer32-type? data type-result/view type-id [
						record-base: record-offset view/parameters-offset (first-parameter + 1)
							schema/WIRE_RSIR_PARAMETER_SIZE
						return reject result
							schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_PROTOCOL_PARAMETERS
							(record-base + schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET)
							view/parameters-ordinal
					]
				]
			]
			signature-id: signature-id + 1
		]

		expected-first: 1
		function-id: 1
		while [function-id <= function-count][
			record-base: record-offset view/functions-offset (function-id - 1)
				schema/WIRE_RSIR_FUNCTION_SIZE
			function-symbol: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
			if any [function-symbol <= 0 function-symbol > symbol-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SYMBOL
					(record-base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					view/functions-ordinal
			]
			function-signature: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			if any [function-signature <= 0 function-signature > signature-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SIGNATURE
					(record-base + schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET)
					view/functions-ordinal
			]
			function-flags: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_FLAGS_OFFSET
			if function-flags <> 0 [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_FLAGS
					(record-base + schema/WIRE_RSIR_FUNCTION_FLAGS_OFFSET)
					view/functions-ordinal
			]
			first-block: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			owned-block-count: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			finish: container/checked-add first-block (owned-block-count - 1)
			if any [
				owned-block-count <= 0
				first-block <> expected-first
				none? finish
				finish > block-count
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_BLOCK_RANGE
					(record-base + schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET)
					view/functions-ordinal
			]
			entry-block: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET
			if any [entry-block < first-block entry-block > finish][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_ENTRY_BLOCK
					(record-base + schema/WIRE_RSIR_FUNCTION_ENTRY_BLOCK_OFFSET)
					view/functions-ordinal
			]
			expected-first: finish + 1
			first-local: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			either owned-local-count = 0 [
				if first-local <> 0 [
					return reject result
						schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						view/functions-ordinal
				]
			][
				finish: container/checked-add first-local (owned-local-count - 1)
				if any [
					first-local <= 0
					none? finish
					finish > local-count
				][
					return reject result
						schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						view/functions-ordinal
				]
			]
			source-location: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_FUNCTION_SOURCE_LOCATION_OFFSET)
					view/functions-ordinal
			]
			if (function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_RESERVED_OFFSET) <> 0
			[
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_FUNCTION_RESERVED
					(record-base + schema/WIRE_RSIR_FUNCTION_RESERVED_OFFSET)
					view/functions-ordinal
			]
			function-id: function-id + 1
		]
		if expected-first <> (block-count + 1) [
			return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_COVERAGE
				view/blocks-offset view/blocks-ordinal
		]

		expected-first: 1
		function-id: 1
		while [function-id <= function-count][
			first-local: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if owned-local-count > 0 [
				if first-local <> expected-first [
					record-base: record-offset view/functions-offset (function-id - 1)
						schema/WIRE_RSIR_FUNCTION_SIZE
					return reject result
						schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_FUNCTION_LOCAL_RANGE
						(record-base + schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET)
						view/functions-ordinal
				]
				expected-first: first-local + owned-local-count
			]
			function-id: function-id + 1
		]
		if expected-first <> (local-count + 1) [
			return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_COVERAGE
				view/locals-offset view/locals-ordinal
		]

		block-id: 1
		while [block-id <= block-count][
			record-base: record-offset view/blocks-offset (block-id - 1)
				schema/WIRE_RSIR_BLOCK_SIZE
			block-owner: block-value data view block-id schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET
			if any [block-owner <= 0 block-owner > function-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_OWNER
					(record-base + schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
					view/blocks-ordinal
			]
			first-block: function-value data view block-owner
				schema/WIRE_RSIR_FUNCTION_FIRST_BLOCK_OFFSET
			owned-block-count: function-value data view block-owner
				schema/WIRE_RSIR_FUNCTION_BLOCK_COUNT_OFFSET
			if any [
				block-id < first-block
				block-id >= (first-block + owned-block-count)
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_OWNER
					(record-base + schema/WIRE_RSIR_BLOCK_FUNCTION_OFFSET)
					view/blocks-ordinal
			]
			if (block-value data view block-id schema/WIRE_RSIR_BLOCK_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_FLAGS
					(record-base + schema/WIRE_RSIR_BLOCK_FLAGS_OFFSET)
					view/blocks-ordinal
			]
			source-location: block-value data view block-id
				schema/WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_BLOCK_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_BLOCK_SOURCE_LOCATION_OFFSET)
					view/blocks-ordinal
			]
			if (block-value data view block-id schema/WIRE_RSIR_BLOCK_RESERVED_OFFSET) <> 0 [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_BLOCK_RESERVED
					(record-base + schema/WIRE_RSIR_BLOCK_RESERVED_OFFSET)
					view/blocks-ordinal
			]
			block-id: block-id + 1
		]

		max-local-alignment: select type-result/layout 'stack-alignment
		local-id: 1
		while [local-id <= local-count][
			record-base: record-offset view/locals-offset (local-id - 1)
				schema/WIRE_RSIR_LOCAL_SIZE
			owner: local-value data view local-id schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET
			if any [owner <= 0 owner > function-count][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_FUNCTION
					(record-base + schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET)
					view/locals-ordinal
			]
			first-local: function-value data view owner schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: function-value data view owner
				schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if any [
				owned-local-count = 0
				local-id < first-local
				local-id >= (first-local + owned-local-count)
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_FUNCTION
					(record-base + schema/WIRE_RSIR_LOCAL_FUNCTION_OFFSET)
					view/locals-ordinal
			]
			kind: local-value data view local-id schema/WIRE_RSIR_LOCAL_KIND_OFFSET
			unless all [kind >= schema/WIRE_LOCAL_KIND_ARGUMENT kind <= schema/WIRE_LOCAL_KIND_MERGE][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_KIND
					(record-base + schema/WIRE_RSIR_LOCAL_KIND_OFFSET) view/locals-ordinal
			]
			name-string: local-value data view local-id schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET
			if any [
				name-string > type-result/strings/record-count
				all [
					name-string = 0
					any [kind = schema/WIRE_LOCAL_KIND_ARGUMENT kind = schema/WIRE_LOCAL_KIND_LOCAL]
				]
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_NAME_ID
					(record-base + schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET)
					view/locals-ordinal
			]
			if all [
				name-string > 0
				zero? string-size-for-id data type-result/strings name-string
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_EMPTY_LOCAL_NAME
					(record-base + schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET)
					view/locals-ordinal
			]
			type-id: local-value data view local-id schema/WIRE_RSIR_LOCAL_TYPE_OFFSET
			unless nonvoid-type? data type-result/view type-id [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_TYPE
					(record-base + schema/WIRE_RSIR_LOCAL_TYPE_OFFSET) view/locals-ordinal
			]
			if (local-value data view local-id schema/WIRE_RSIR_LOCAL_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_NONZERO_LOCAL_FLAGS
					(record-base + schema/WIRE_RSIR_LOCAL_FLAGS_OFFSET) view/locals-ordinal
			]
			alignment: local-value data view local-id schema/WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET
			type-alignment: type-value data type-result/view type-id
				schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			if any [
				all [
					alignment <> 0
					any [
						not power-of-two? alignment
						alignment < type-alignment
						alignment > max-local-alignment
					]
				]
			][
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ALIGNMENT
					(record-base + schema/WIRE_RSIR_LOCAL_ALIGNMENT_OFFSET) view/locals-ordinal
			]
			source-location: local-value data view local-id
				schema/WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result
					schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_LOCAL_SOURCE_LOCATION_OFFSET)
					view/locals-ordinal
			]
			ordinal: local-value data view local-id schema/WIRE_RSIR_LOCAL_ORDINAL_OFFSET
			if ordinal <> (local-id - first-local) [
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_LOCAL_ORDINAL
					(record-base + schema/WIRE_RSIR_LOCAL_ORDINAL_OFFSET) view/locals-ordinal
			]
			local-id: local-id + 1
		]

		function-id: 1
		while [function-id <= function-count][
			function-signature: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			signature-parameter-count: signature-value data view function-signature
				schema/WIRE_RSIR_SIGNATURE_PARAMETER_COUNT_OFFSET
			first-parameter: signature-value data view function-signature
				schema/WIRE_RSIR_SIGNATURE_FIRST_PARAMETER_OFFSET
			first-local: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_FIRST_LOCAL_OFFSET
			owned-local-count: function-value data view function-id
				schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET
			if owned-local-count < signature-parameter-count [
				record-base: record-offset view/functions-offset (function-id - 1)
					schema/WIRE_RSIR_FUNCTION_SIZE
				return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
					(record-base + schema/WIRE_RSIR_FUNCTION_LOCAL_COUNT_OFFSET)
					view/functions-ordinal
			]
			argument-index: 0
			while [argument-index < owned-local-count][
				local-id: first-local + argument-index
				kind: local-value data view local-id schema/WIRE_RSIR_LOCAL_KIND_OFFSET
				either argument-index < signature-parameter-count [
					if kind <> schema/WIRE_LOCAL_KIND_ARGUMENT [
						record-base: record-offset view/locals-offset (local-id - 1)
							schema/WIRE_RSIR_LOCAL_SIZE
						return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + schema/WIRE_RSIR_LOCAL_KIND_OFFSET)
							view/locals-ordinal
					]
					parameter-id: first-parameter + argument-index
					parameter-name: parameter-value data view parameter-id
						schema/WIRE_RSIR_PARAMETER_NAME_STRING_OFFSET
					parameter-type: parameter-value data view parameter-id
						schema/WIRE_RSIR_PARAMETER_TYPE_OFFSET
					if (local-value data view local-id schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET)
						<> parameter-name
					[
						record-base: record-offset view/locals-offset (local-id - 1)
							schema/WIRE_RSIR_LOCAL_SIZE
						return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + schema/WIRE_RSIR_LOCAL_NAME_STRING_OFFSET)
							view/locals-ordinal
					]
					if (local-value data view local-id schema/WIRE_RSIR_LOCAL_TYPE_OFFSET)
						<> parameter-type
					[
						record-base: record-offset view/locals-offset (local-id - 1)
							schema/WIRE_RSIR_LOCAL_SIZE
						return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + schema/WIRE_RSIR_LOCAL_TYPE_OFFSET)
							view/locals-ordinal
					]
				][
					if kind = schema/WIRE_LOCAL_KIND_ARGUMENT [
						record-base: record-offset view/locals-offset (local-id - 1)
							schema/WIRE_RSIR_LOCAL_SIZE
						return reject result schema/WIRE_FUNCTION_SIGNATURE_ERROR_BAD_ARGUMENT_LOCAL
							(record-base + schema/WIRE_RSIR_LOCAL_KIND_OFFSET)
							view/locals-ordinal
					]
				]
				argument-index: argument-index + 1
			]
			function-id: function-id + 1
		]

		result/strings: type-result/strings
		result/files: type-result/files
		result/layout: type-result/layout
		result/types: type-result/view
		result/view: view
		result/valid?: true
		result
	]
]
