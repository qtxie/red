Red/System [
	Title: "Hybrid compiler RSIR constant and global-initializer verifier"
	File:  %wire-constant-initializer.reds
]

#include %wire-symbol-linkage.reds

wire-constant-initializer-result!: alias struct! [
	error                    [integer!]
	container-error          [integer!]
	string-error             [integer!]
	file-source-error        [integer!]
	data-layout-error        [integer!]
	type-layout-error        [integer!]
	function-signature-error [integer!]
	module-lifecycle-error   [integer!]
	symbol-linkage-error     [integer!]
	error-offset             [integer!]
	error-section            [integer!]
]

wire-constant-initializer!: alias struct! [
	constants            [byte-ptr!]
	constant-count       [integer!]
	constant-record-size [integer!]
	constants-offset     [integer!]
	constants-ordinal    [integer!]
	constant-data        [byte-ptr!]
	constant-data-size   [integer!]
	constant-data-owned-size [integer!]
	constant-data-offset [integer!]
	constant-data-ordinal [integer!]
	parts                [byte-ptr!]
	part-count           [integer!]
	part-record-size     [integer!]
	parts-offset         [integer!]
	parts-ordinal        [integer!]
	bindings             [byte-ptr!]
	binding-count        [integer!]
	binding-record-size  [integer!]
	bindings-offset      [integer!]
	bindings-ordinal     [integer!]
	global-count         [integer!]
]

wire-constant-initializer-reader: context [
	expected-index-flags:
		WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	set-error: func [
		result [wire-constant-initializer-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	map-symbol-error: func [code [integer!] return: [integer!]][
		case [
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_STRINGS [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_STRINGS
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FILE_SOURCE [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FILE_SOURCE
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_DATA_LAYOUT [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_DATA_LAYOUT
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_TYPE_LAYOUT [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_TYPE_LAYOUT
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FUNCTION_SIGNATURE [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_FUNCTION_SIGNATURE
			]
			code = WIRE_SYMBOL_LINKAGE_ERROR_INVALID_MODULE_LIFECYCLE [
				WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_MODULE_LIFECYCLE
			]
			true [WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_SYMBOL_LINKAGE]
		]
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

	record-value: func [
		section [wire-section-slice!]
		id record-size field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 section/data
			(((id - 1) * record-size) + field-offset)
	]

	record-offset: func [
		section [wire-section-slice!]
		id record-size [integer!]
		return: [integer!]
	][
		section/offset + ((id - 1) * record-size)
	]

	constant-value: func [
		constants [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value constants id WIRE_RSIR_CONSTANT_SIZE field-offset
	]

	part-value: func [
		parts [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value parts id WIRE_RSIR_CONSTANT_PART_SIZE field-offset
	]

	binding-value: func [
		bindings [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value bindings id WIRE_RSIR_CONSTANT_BINDING_SIZE field-offset
	]

	type-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/types
			(((id - 1) * WIRE_RSIR_TYPE_SIZE) + field-offset)
	]

	field-value: func [
		types [wire-type-layout!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 types/fields
			(((id - 1) * WIRE_RSIR_FIELD_SIZE) + field-offset)
	]

	symbol-value: func [
		symbols [wire-symbol-linkage!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 symbols/symbols
			(((id - 1) * WIRE_RSIR_SYMBOL_SIZE) + field-offset)
	]

	global-value: func [
		symbols [wire-symbol-linkage!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 symbols/globals
			(((id - 1) * WIRE_RSIR_GLOBAL_SIZE) + field-offset)
	]

	valid-type?: func [types [wire-type-layout!] id [integer!] return: [logic!]][
		all [id > 0 id <= types/type-count]
	]

	pointer-like-kind?: func [kind [integer!] return: [logic!]][
		any [kind = WIRE_TYPE_KIND_POINTER kind = WIRE_TYPE_KIND_FUNCTION]
	]

	first-bad-logic-byte: func [
		data [byte-ptr!]
		return: [integer!]
		/local cursor [byte-ptr!] index [integer!]
	][
		if all [data/1 <> as byte! 0 data/1 <> as byte! 1][return 0]
		cursor: data + 1
		index: 1
		while [index < 4][
			if cursor/1 <> as byte! 0 [return index]
			cursor: cursor + 1
			index: index + 1
		]
		-1
	]

	first-bad-c-string-byte: func [
		data [byte-ptr!]
		size [integer!]
		return: [integer!]
		/local cursor [byte-ptr!] index [integer!]
	][
		if size <= 0 [return 0]
		cursor: data
		index: 0
		while [index < (size - 1)][
			if cursor/1 = as byte! 0 [return index]
			cursor: cursor + 1
			index: index + 1
		]
		if cursor/1 <> as byte! 0 [return size - 1]
		-1
	]

	first-bad-relative-addend-byte: func [
		data [byte-ptr!]
		return: [integer!]
		/local cursor [byte-ptr!] expected [byte!] index [integer!]
	][
		expected: either data/4 > as byte! 127 [as byte! 255][as byte! 0]
		cursor: data + 4
		index: 4
		while [index < 8][
			if cursor/1 <> expected [return index]
			cursor: cursor + 1
			index: index + 1
		]
		-1
	]

	first-bad-absolute-addend-byte: func [
		data [byte-ptr!]
		return: [integer!]
		/local cursor [byte-ptr!] index [integer!]
	][
		cursor: data
		index: 0
		while [index < 8][
			if cursor/1 <> as byte! 0 [return -1]
			cursor: cursor + 1
			index: index + 1
		]
		0
	]

	copy-symbols: func [destination source [wire-symbol-linkage!]][
		destination/symbols: source/symbols
		destination/symbol-count: source/symbol-count
		destination/symbol-record-size: source/symbol-record-size
		destination/symbols-offset: source/symbols-offset
		destination/symbols-ordinal: source/symbols-ordinal
		destination/globals: source/globals
		destination/global-count: source/global-count
		destination/global-record-size: source/global-record-size
		destination/globals-offset: source/globals-offset
		destination/globals-ordinal: source/globals-ordinal
		destination/imports: source/imports
		destination/import-count: source/import-count
		destination/import-record-size: source/import-record-size
		destination/imports-offset: source/imports-offset
		destination/imports-ordinal: source/imports-ordinal
		destination/exports: source/exports
		destination/export-count: source/export-count
		destination/export-record-size: source/export-record-size
		destination/exports-offset: source/exports-offset
		destination/exports-ordinal: source/exports-ordinal
		destination/function-count: source/function-count
		destination/module-kind: source/module-kind
		destination/image-kind: source/image-kind
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-constant-initializer-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		symbols [wire-symbol-linkage!]
		view [wire-constant-initializer!]
		return: [integer!]
		/local symbol-result [wire-symbol-linkage-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			verified-modules [wire-module-lifecycle!]
			verified-symbols [wire-symbol-linkage!]
			constants constant-data parts bindings target-fragments [wire-section-slice!]
			record direct-data [byte-ptr!]
			status record-index bad-relative record-base constant-id constant-type
			constant-kind flags data-offset data-size first-part owned-part-count
			auxiliary part-cursor data-cursor finish type-kind type-size type-alignment
			type-flags detail-id expected-size field-count part-id part-base parent
			byte-offset part-type part-kind child target addend-offset part-size
			part-alignment previous-end first-field expected-field selected-field
			field-type field-byte-offset symbol-kind bad-data-relative
			previous-symbol binding-id binding-symbol binding-constant binding-cursor
			symbol-id global-id global-base initializer alignment storage-class
			max-alignment [integer!]
	][
		if null? result [return WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/type-layout-error: WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		result/function-signature-error: WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/symbol-linkage-error: WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0

		if any [
			size < 0
			null? data
			null? strings
			null? files
			null? layout
			null? types
			null? functions
			null? modules
			null? symbols
			null? view
		][
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_ARGUMENTS 0 0
		]

		symbol-result: declare wire-symbol-linkage-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		verified-modules: declare wire-module-lifecycle!
		verified-symbols: declare wire-symbol-linkage!
		status: wire-symbol-linkage-reader/verify data size symbol-result
			verified-strings verified-files verified-layout verified-types
			verified-functions verified-modules verified-symbols
		result/container-error: symbol-result/container-error
		result/string-error: symbol-result/string-error
		result/file-source-error: symbol-result/file-source-error
		result/data-layout-error: symbol-result/data-layout-error
		result/type-layout-error: symbol-result/type-layout-error
		result/function-signature-error: symbol-result/function-signature-error
		result/module-lifecycle-error: symbol-result/module-lifecycle-error
		result/symbol-linkage-error: status
		if status <> WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS [
			return set-error result (map-symbol-error status)
				symbol-result/error-offset symbol-result/error-section
		]

		constants: declare wire-section-slice!
		constant-data: declare wire-section-slice!
		parts: declare wire-section-slice!
		bindings: declare wire-section-slice!
		target-fragments: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_CONSTANTS constants
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_CONSTANT_DATA constant-data
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_CONSTANT_PARTS parts
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_CONSTANT_BINDINGS bindings
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSIR_SECTION_TARGET_FRAGMENTS target-fragments
		[
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_INVALID_CONTAINER
				WIRE_HEADER_SIZE 0
		]

		if constants/flags <> 0 [
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_SECTION_FLAGS
				section-flags-offset constants constants/ordinal
		]
		if constant-data/flags <> 0 [
			return set-error result
				WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_SECTION_FLAGS
				section-flags-offset constant-data constant-data/ordinal
		]
		if parts/flags <> 0 [
			return set-error result
				WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_SECTION_FLAGS
				section-flags-offset parts parts/ordinal
		]
		if bindings/flags <> expected-index-flags [
			return set-error result
				WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_BINDING_SECTION_FLAGS
				section-flags-offset bindings bindings/ordinal
		]

		; Decode every signed scalar before following any semantic reference.
		record-index: 0
		while [record-index < constants/record-count][
			record: constants/data + (record-index * WIRE_RSIR_CONSTANT_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_SCALAR_RANGE
					((constants/offset + (record-index * WIRE_RSIR_CONSTANT_SIZE))
						+ bad-relative)
					constants/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < parts/record-count][
			record: parts/data + (record-index * WIRE_RSIR_CONSTANT_PART_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_SCALAR_RANGE
					((parts/offset + (record-index * WIRE_RSIR_CONSTANT_PART_SIZE))
						+ bad-relative)
					parts/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < bindings/record-count][
			record: bindings/data + (record-index * WIRE_RSIR_CONSTANT_BINDING_SIZE)
			bad-relative: first-bad-scalar record 2
			if bad-relative >= 0 [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_SCALAR_RANGE
					((bindings/offset + (record-index * WIRE_RSIR_CONSTANT_BINDING_SIZE))
						+ bad-relative)
					bindings/ordinal
			]
			record-index: record-index + 1
		]

		part-cursor: 1
		data-cursor: 0
		constant-id: 1
		while [constant-id <= constants/record-count][
			record-base: record-offset constants constant-id WIRE_RSIR_CONSTANT_SIZE
			constant-type: constant-value constants constant-id WIRE_RSIR_CONSTANT_TYPE_OFFSET
			if any [
				not valid-type? verified-types constant-type
				(type-value verified-types constant-type WIRE_RSIR_TYPE_KIND_OFFSET)
					= WIRE_TYPE_KIND_VOID
			][
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_TYPE
					(record-base + WIRE_RSIR_CONSTANT_TYPE_OFFSET) constants/ordinal
			]
			constant-kind: constant-value constants constant-id WIRE_RSIR_CONSTANT_KIND_OFFSET
			unless all [
				constant-kind >= WIRE_CONSTANT_KIND_ZERO
				constant-kind <= WIRE_CONSTANT_KIND_ADDRESS
			][
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_KIND
					(record-base + WIRE_RSIR_CONSTANT_KIND_OFFSET) constants/ordinal
			]
			flags: constant-value constants constant-id WIRE_RSIR_CONSTANT_FLAGS_OFFSET
			if flags <> WIRE_CONSTANT_FLAG_NONE [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_CONSTANT_FLAGS
					(record-base + WIRE_RSIR_CONSTANT_FLAGS_OFFSET) constants/ordinal
			]

			data-offset: constant-value constants constant-id
				WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET
			data-size: constant-value constants constant-id WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET
			first-part: constant-value constants constant-id WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET
			owned-part-count: constant-value constants constant-id
				WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET
			auxiliary: constant-value constants constant-id WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET
			either owned-part-count = 0 [
				if first-part <> 0 [
					return set-error result
						WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
						constants/ordinal
				]
			][
				if first-part <> part-cursor [
					return set-error result
						WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
						constants/ordinal
				]
				finish: wire-container-reader/checked-add first-part (owned-part-count - 1)
				if any [finish < 0 finish > parts/record-count][
					return set-error result
						WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_PART_RANGE
						(record-base + WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
						constants/ordinal
				]
			]

			type-kind: type-value verified-types constant-type WIRE_RSIR_TYPE_KIND_OFFSET
			type-size: type-value verified-types constant-type WIRE_RSIR_TYPE_SIZE_OFFSET
			type-flags: type-value verified-types constant-type WIRE_RSIR_TYPE_FLAGS_OFFSET
			case [
				constant-kind = WIRE_CONSTANT_KIND_ZERO [
					unless all [
						data-offset = 0
						data-size = 0
						owned-part-count = 0
						auxiliary = 0
					][
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ZERO_SHAPE
							(record-base + WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							constants/ordinal
					]
				]
				constant-kind = WIRE_CONSTANT_KIND_SCALAR [
					unless any [
						type-kind = WIRE_TYPE_KIND_LOGIC
						type-kind = WIRE_TYPE_KIND_INTEGER
						type-kind = WIRE_TYPE_KIND_FLOAT
					][
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_TYPE
							(record-base + WIRE_RSIR_CONSTANT_TYPE_OFFSET) constants/ordinal
					]
					if data-size <> type-size [
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_DATA_SIZE
							(record-base + WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
							constants/ordinal
					]
					unless all [owned-part-count = 0 auxiliary = 0][
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_SCALAR_SHAPE
							(record-base + WIRE_RSIR_CONSTANT_FIRST_PART_OFFSET)
							constants/ordinal
					]
				]
				constant-kind = WIRE_CONSTANT_KIND_STORAGE [
					if type-kind <> WIRE_TYPE_KIND_POINTER [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_TYPE
							(record-base + WIRE_RSIR_CONSTANT_TYPE_OFFSET) constants/ordinal
					]
					if auxiliary <= 0 [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_COUNT
							(record-base + WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							constants/ordinal
					]
					detail-id: type-value verified-types constant-type WIRE_RSIR_TYPE_DETAIL_ID_OFFSET
					expected-size: wire-container-reader/checked-multiply auxiliary
						(type-value verified-types detail-id WIRE_RSIR_TYPE_SIZE_OFFSET)
					if expected-size < 0 [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_COUNT
							(record-base + WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							constants/ordinal
					]
					if data-size <> expected-size [
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_DATA_SIZE
							(record-base + WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET)
							constants/ordinal
					]
					if all [
						type-flags = WIRE_TYPE_FLAG_C_STRING
						owned-part-count <> 0
					][
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_STORAGE_PART_COUNT
							(record-base + WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
							constants/ordinal
					]
				]
				constant-kind = WIRE_CONSTANT_KIND_AGGREGATE [
					unless any [
						type-kind = WIRE_TYPE_KIND_STRUCT
						type-kind = WIRE_TYPE_KIND_UNION
					][
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_TYPE
							(record-base + WIRE_RSIR_CONSTANT_TYPE_OFFSET) constants/ordinal
					]
					field-count: type-value verified-types constant-type
						WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET
					expected-size: either type-kind = WIRE_TYPE_KIND_STRUCT [field-count][1]
					if owned-part-count <> expected-size [
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_PART_COUNT
							(record-base + WIRE_RSIR_CONSTANT_PART_COUNT_OFFSET)
							constants/ordinal
					]
					if all [type-kind = WIRE_TYPE_KIND_STRUCT auxiliary <> 0][
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
							(record-base + WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
							constants/ordinal
					]
					if any [data-offset <> 0 data-size <> 0][
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_AGGREGATE_AUXILIARY
							(record-base + WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							constants/ordinal
					]
				]
				constant-kind = WIRE_CONSTANT_KIND_ADDRESS [
					unless pointer-like-kind? type-kind [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TYPE
							(record-base + WIRE_RSIR_CONSTANT_TYPE_OFFSET) constants/ordinal
					]
					unless all [
						data-offset = 0
						data-size = 0
						owned-part-count = 1
						auxiliary = 0
					][
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_SHAPE
							(record-base + WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
							constants/ordinal
					]
				]
				true [
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_KIND
						(record-base + WIRE_RSIR_CONSTANT_KIND_OFFSET) constants/ordinal
				]
			]

			if any [
				constant-kind = WIRE_CONSTANT_KIND_SCALAR
				constant-kind = WIRE_CONSTANT_KIND_STORAGE
			][
				if data-offset <> data-cursor [
					return set-error result
						WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CONSTANT_DATA_OFFSET
						(record-base + WIRE_RSIR_CONSTANT_DATA_OFFSET_OFFSET)
						constants/ordinal
				]
				finish: wire-container-reader/checked-add data-offset data-size
				if any [finish < 0 finish > constant-data/size][
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_RANGE
						(record-base + WIRE_RSIR_CONSTANT_DATA_SIZE_OFFSET) constants/ordinal
				]
				if all [
					constant-kind = WIRE_CONSTANT_KIND_SCALAR
					type-kind = WIRE_TYPE_KIND_LOGIC
				][
					direct-data: constant-data/data + data-offset
					bad-data-relative: first-bad-logic-byte direct-data
					if bad-data-relative >= 0 [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_LOGIC_ENCODING
							((constant-data/offset + data-offset) + bad-data-relative)
							constant-data/ordinal
					]
				]
				if all [
					constant-kind = WIRE_CONSTANT_KIND_STORAGE
					type-flags = WIRE_TYPE_FLAG_C_STRING
				][
					direct-data: constant-data/data + data-offset
					bad-data-relative: first-bad-c-string-byte direct-data data-size
					if bad-data-relative >= 0 [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_C_STRING_ENCODING
							((constant-data/offset + data-offset) + bad-data-relative)
							constant-data/ordinal
					]
				]
				data-cursor: finish
			]

			previous-end: 0
			part-id: first-part
			while [owned-part-count > 0][
				part-base: record-offset parts part-id WIRE_RSIR_CONSTANT_PART_SIZE
				parent: part-value parts part-id WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET
				if parent <> constant-id [
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_PARENT
						(part-base + WIRE_RSIR_CONSTANT_PART_PARENT_CONSTANT_OFFSET)
						parts/ordinal
				]
				part-type: part-value parts part-id WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET
				if any [
					not valid-type? verified-types part-type
					(type-value verified-types part-type WIRE_RSIR_TYPE_KIND_OFFSET)
						= WIRE_TYPE_KIND_VOID
				][
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_TYPE
						(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET) parts/ordinal
				]
				part-kind: part-value parts part-id WIRE_RSIR_CONSTANT_PART_KIND_OFFSET
				unless all [
					part-kind >= WIRE_CONSTANT_PART_KIND_VALUE
					part-kind <= WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS
				][
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_KIND
						(part-base + WIRE_RSIR_CONSTANT_PART_KIND_OFFSET) parts/ordinal
				]
				byte-offset: part-value parts part-id WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET
				part-size: type-value verified-types part-type WIRE_RSIR_TYPE_SIZE_OFFSET
				part-alignment: type-value verified-types part-type
					WIRE_RSIR_TYPE_ALIGNMENT_OFFSET

				case [
					constant-kind = WIRE_CONSTANT_KIND_STORAGE [
						finish: wire-container-reader/checked-add byte-offset part-size
						if any [
							finish < 0
							finish > data-size
							part-alignment <= 0
							(byte-offset // part-alignment) <> 0
						][
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								parts/ordinal
						]
						if byte-offset < previous-end [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_PART_OVERLAP
								(part-base + WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								parts/ordinal
						]
						previous-end: finish
					]
					constant-kind = WIRE_CONSTANT_KIND_AGGREGATE [
						first-field: type-value verified-types constant-type
							WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET
						either type-kind = WIRE_TYPE_KIND_STRUCT [
							expected-field: first-field + (part-id - first-part)
						][
							selected-field: auxiliary
							finish: (first-field + field-count) - 1
							if any [
								selected-field < first-field
								selected-field > finish
							][
								return set-error result
									WIRE_CONSTANT_INITIALIZER_ERROR_BAD_UNION_FIELD
									(record-base + WIRE_RSIR_CONSTANT_AUXILIARY_OFFSET)
									constants/ordinal
							]
							expected-field: selected-field
						]
						field-byte-offset: field-value verified-types expected-field
							WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET
						if byte-offset <> field-byte-offset [
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								parts/ordinal
						]
						field-type: field-value verified-types expected-field
							WIRE_RSIR_FIELD_TYPE_OFFSET
						if part-type <> field-type [
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								parts/ordinal
						]
					]
					constant-kind = WIRE_CONSTANT_KIND_ADDRESS [
						if byte-offset <> 0 [
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
								(part-base + WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
								parts/ordinal
						]
						if part-type <> constant-type [
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								parts/ordinal
						]
					]
					true [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_OFFSET
							(part-base + WIRE_RSIR_CONSTANT_PART_BYTE_OFFSET_OFFSET)
							parts/ordinal
					]
				]

				child: part-value parts part-id WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET
				target: part-value parts part-id WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET
				addend-offset: part-value parts part-id
					WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET
				if (part-value parts part-id WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET)
					<> WIRE_CONSTANT_PART_FLAG_NONE
				[
					return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_FLAGS
						(part-base + WIRE_RSIR_CONSTANT_PART_FLAGS_OFFSET) parts/ordinal
				]

				case [
					part-kind = WIRE_CONSTANT_PART_KIND_VALUE [
						if constant-kind = WIRE_CONSTANT_KIND_ADDRESS [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + WIRE_RSIR_CONSTANT_PART_KIND_OFFSET) parts/ordinal
						]
						if any [child <= 0 child > constants/record-count][
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CHILD_CONSTANT
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
						if child >= constant-id [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_ORDER
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
						if (constant-value constants child WIRE_RSIR_CONSTANT_TYPE_OFFSET)
							<> part-type
						[
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_PART_TYPE_MISMATCH
								(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								parts/ordinal
						]
						if any [target <> 0 addend-offset <> 0][
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								parts/ordinal
						]
					]
					part-kind = WIRE_CONSTANT_PART_KIND_SYMBOL_ADDRESS [
						if any [target <= 0 target > verified-symbols/symbol-count][
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL
								(part-base + WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								parts/ordinal
						]
						symbol-kind: symbol-value verified-symbols target WIRE_RSIR_SYMBOL_KIND_OFFSET
						unless any [
							symbol-kind = WIRE_SYMBOL_KIND_FUNCTION
							symbol-kind = WIRE_SYMBOL_KIND_GLOBAL
							symbol-kind = WIRE_SYMBOL_KIND_CONSTANT
						][
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_TARGET_SYMBOL_KIND
								(part-base + WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								parts/ordinal
						]
						either symbol-kind = WIRE_SYMBOL_KIND_FUNCTION [
							unless all [
								(type-value verified-types part-type WIRE_RSIR_TYPE_KIND_OFFSET)
									= WIRE_TYPE_KIND_FUNCTION
								(type-value verified-types part-type WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
									= (symbol-value verified-symbols target
										WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
							][
								return set-error result
									WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
									(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
									parts/ordinal
							]
						][
							unless all [
								(type-value verified-types part-type WIRE_RSIR_TYPE_KIND_OFFSET)
									= WIRE_TYPE_KIND_POINTER
								(type-value verified-types part-type WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
									= (symbol-value verified-symbols target
										WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
							][
								return set-error result
									WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
									(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
									parts/ordinal
							]
						]
						if child <> 0 [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
					]
					part-kind = WIRE_CONSTANT_PART_KIND_CONSTANT_ADDRESS [
						if any [child <= 0 child > constants/record-count][
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_CHILD_CONSTANT
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
						if child >= constant-id [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_ORDER
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
						unless all [
							(constant-value constants child WIRE_RSIR_CONSTANT_KIND_OFFSET)
								= WIRE_CONSTANT_KIND_STORAGE
							(constant-value constants child WIRE_RSIR_CONSTANT_TYPE_OFFSET)
								= part-type
						][
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
								(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								parts/ordinal
						]
						if target <> 0 [
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + WIRE_RSIR_CONSTANT_PART_TARGET_SYMBOL_OFFSET)
								parts/ordinal
						]
					]
					part-kind = WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS [
						unless pointer-like-kind?
							(type-value verified-types part-type WIRE_RSIR_TYPE_KIND_OFFSET)
						[
							return set-error result
								WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDRESS_TARGET_TYPE
								(part-base + WIRE_RSIR_CONSTANT_PART_TYPE_OFFSET)
								parts/ordinal
						]
						if any [child <> 0 target <> 0][
							return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_SHAPE
								(part-base + WIRE_RSIR_CONSTANT_PART_CHILD_CONSTANT_OFFSET)
								parts/ordinal
						]
					]
					true [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_PART_KIND
							(part-base + WIRE_RSIR_CONSTANT_PART_KIND_OFFSET) parts/ordinal
					]
				]

				if part-kind <> WIRE_CONSTANT_PART_KIND_VALUE [
					if addend-offset <> data-cursor [
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_OFFSET
							(part-base + WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET)
							parts/ordinal
					]
					finish: wire-container-reader/checked-add addend-offset 8
					if any [finish < 0 finish > constant-data/size][
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_RANGE
							(part-base + WIRE_RSIR_CONSTANT_PART_RAW_ADDEND_DATA_OFFSET_OFFSET)
							parts/ordinal
					]
					direct-data: constant-data/data + addend-offset
					bad-data-relative: either
						part-kind = WIRE_CONSTANT_PART_KIND_ABSOLUTE_ADDRESS
					[first-bad-absolute-addend-byte direct-data][
						first-bad-relative-addend-byte direct-data
					]
					if bad-data-relative >= 0 [
						return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_ADDEND_ENCODING
							((constant-data/offset + addend-offset) + bad-data-relative)
							constant-data/ordinal
					]
					data-cursor: finish
				]

				if constant-kind = WIRE_CONSTANT_KIND_STORAGE [
					direct-data: constant-data/data + (data-offset + byte-offset)
					bad-data-relative: wire-container-reader/first-nonzero
						direct-data 0 part-size
					if bad-data-relative >= 0 [
						return set-error result
							WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_PART_PLACEHOLDER
							(((constant-data/offset + data-offset) + byte-offset)
								+ bad-data-relative)
							constant-data/ordinal
					]
				]

				part-id: part-id + 1
				part-cursor: part-cursor + 1
				owned-part-count: owned-part-count - 1
			]
			constant-id: constant-id + 1
		]

		if part-cursor <> (parts/record-count + 1) [
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_PART_COVERAGE
				(parts/offset + ((part-cursor - 1) * WIRE_RSIR_CONSTANT_PART_SIZE))
				parts/ordinal
		]
		if all [
			target-fragments/record-count = 0
			data-cursor <> constant-data/size
		][
			return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_CONSTANT_DATA_COVERAGE
				(constant-data/offset + data-cursor) constant-data/ordinal
		]

		previous-symbol: 0
		binding-id: 1
		while [binding-id <= bindings/record-count][
			record-base: record-offset bindings binding-id WIRE_RSIR_CONSTANT_BINDING_SIZE
			binding-symbol: binding-value bindings binding-id
				WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET
			if any [binding-symbol <= 0 binding-symbol > verified-symbols/symbol-count][
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL
					(record-base + WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					bindings/ordinal
			]
			if (symbol-value verified-symbols binding-symbol WIRE_RSIR_SYMBOL_KIND_OFFSET)
				<> WIRE_SYMBOL_KIND_CONSTANT
			[
				return set-error result
					WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_SYMBOL_KIND
					(record-base + WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					bindings/ordinal
			]
			binding-constant: binding-value bindings binding-id
				WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET
			if any [binding-constant <= 0 binding-constant > constants/record-count][
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_BINDING_CONSTANT
					(record-base + WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET)
					bindings/ordinal
			]
			if (constant-value constants binding-constant WIRE_RSIR_CONSTANT_TYPE_OFFSET)
				<> (symbol-value verified-symbols binding-symbol
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
			[
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_TYPE_MISMATCH
					(record-base + WIRE_RSIR_CONSTANT_BINDING_CONSTANT_OFFSET)
					bindings/ordinal
			]
			if binding-symbol < previous-symbol [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BINDING_ORDER
					(record-base + WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					bindings/ordinal
			]
			if binding-symbol = previous-symbol [
				return set-error result
					WIRE_CONSTANT_INITIALIZER_ERROR_DUPLICATE_BINDING_SYMBOL
					(record-base + WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET)
					bindings/ordinal
			]
			previous-symbol: binding-symbol
			binding-id: binding-id + 1
		]

		binding-cursor: 1
		symbol-id: 1
		while [symbol-id <= verified-symbols/symbol-count][
			symbol-kind: symbol-value verified-symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET
			if symbol-kind = WIRE_SYMBOL_KIND_CONSTANT [
				if any [
					binding-cursor > bindings/record-count
					(binding-value bindings binding-cursor
						WIRE_RSIR_CONSTANT_BINDING_SYMBOL_OFFSET) <> symbol-id
				][
					return set-error result
						WIRE_CONSTANT_INITIALIZER_ERROR_MISSING_CONSTANT_BINDING
						((verified-symbols/symbols-offset
							+ ((symbol-id - 1) * WIRE_RSIR_SYMBOL_SIZE))
							+ WIRE_RSIR_SYMBOL_KIND_OFFSET)
						verified-symbols/symbols-ordinal
				]
				binding-cursor: binding-cursor + 1
			]
			symbol-id: symbol-id + 1
		]

		max-alignment: verified-layout/max-aggregate-alignment
		global-id: 1
		while [global-id <= verified-symbols/global-count][
			global-base: verified-symbols/globals-offset
				+ ((global-id - 1) * WIRE_RSIR_GLOBAL_SIZE)
			initializer: global-value verified-symbols global-id
				WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET
			if initializer > constants/record-count [
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_INITIALIZER
					(global-base + WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET)
					verified-symbols/globals-ordinal
			]
			if all [
				initializer > 0
				(constant-value constants initializer WIRE_RSIR_CONSTANT_TYPE_OFFSET)
					<> (global-value verified-symbols global-id WIRE_RSIR_GLOBAL_TYPE_OFFSET)
			][
				return set-error result
					WIRE_CONSTANT_INITIALIZER_ERROR_GLOBAL_INITIALIZER_TYPE_MISMATCH
					(global-base + WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET)
					verified-symbols/globals-ordinal
			]
			constant-type: global-value verified-symbols global-id WIRE_RSIR_GLOBAL_TYPE_OFFSET
			type-alignment: type-value verified-types constant-type WIRE_RSIR_TYPE_ALIGNMENT_OFFSET
			alignment: global-value verified-symbols global-id WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET
			if all [
				alignment <> 0
				any [
					not wire-container-reader/power-of-two? alignment
					alignment < type-alignment
					alignment > max-alignment
				]
			][
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_ALIGNMENT
					(global-base + WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET)
					verified-symbols/globals-ordinal
			]
			storage-class: global-value verified-symbols global-id
				WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET
			if storage-class <> WIRE_GLOBAL_STORAGE_CLASS_MUTABLE [
				return set-error result
					WIRE_CONSTANT_INITIALIZER_ERROR_BAD_GLOBAL_STORAGE_CLASS
					(global-base + WIRE_RSIR_GLOBAL_STORAGE_CLASS_OFFSET)
					verified-symbols/globals-ordinal
			]
			if (global-value verified-symbols global-id WIRE_RSIR_GLOBAL_FLAGS_OFFSET)
				<> WIRE_GLOBAL_FLAG_NONE
			[
				return set-error result WIRE_CONSTANT_INITIALIZER_ERROR_NONZERO_GLOBAL_FLAGS
					(global-base + WIRE_RSIR_GLOBAL_FLAGS_OFFSET)
					verified-symbols/globals-ordinal
			]
			global-id: global-id + 1
		]

		wire-symbol-linkage-reader/copy-strings strings verified-strings
		wire-symbol-linkage-reader/copy-files files verified-files
		wire-symbol-linkage-reader/copy-layout layout verified-layout
		wire-symbol-linkage-reader/copy-types types verified-types
		wire-symbol-linkage-reader/copy-functions functions verified-functions
		wire-symbol-linkage-reader/copy-modules modules verified-modules
		copy-symbols symbols verified-symbols
		view/constants: constants/data
		view/constant-count: constants/record-count
		view/constant-record-size: constants/record-size
		view/constants-offset: constants/offset
		view/constants-ordinal: constants/ordinal
		view/constant-data: constant-data/data
		view/constant-data-size: constant-data/size
		view/constant-data-owned-size: data-cursor
		view/constant-data-offset: constant-data/offset
		view/constant-data-ordinal: constant-data/ordinal
		view/parts: parts/data
		view/part-count: parts/record-count
		view/part-record-size: parts/record-size
		view/parts-offset: parts/offset
		view/parts-ordinal: parts/ordinal
		view/bindings: bindings/data
		view/binding-count: bindings/record-count
		view/binding-record-size: bindings/record-size
		view/bindings-offset: bindings/offset
		view/bindings-ordinal: bindings/ordinal
		view/global-count: verified-symbols/global-count
		WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
	]
]
