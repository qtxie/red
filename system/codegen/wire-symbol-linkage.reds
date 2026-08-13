Red/System [
	Title: "Hybrid compiler RSIR symbol, import, and export verifier"
	File:  %wire-symbol-linkage.reds
]

#include %wire-function-signature.reds
#include %wire-module-lifecycle.reds

wire-symbol-linkage-result!: alias struct! [
	error                    [integer!]
	container-error          [integer!]
	string-error             [integer!]
	file-source-error        [integer!]
	data-layout-error        [integer!]
	type-layout-error        [integer!]
	function-signature-error [integer!]
	module-lifecycle-error   [integer!]
	error-offset             [integer!]
	error-section            [integer!]
]

wire-symbol-linkage!: alias struct! [
	symbols            [byte-ptr!]
	symbol-count       [integer!]
	symbol-record-size [integer!]
	symbols-offset     [integer!]
	symbols-ordinal    [integer!]
	globals            [byte-ptr!]
	global-count       [integer!]
	global-record-size [integer!]
	globals-offset     [integer!]
	globals-ordinal    [integer!]
	imports            [byte-ptr!]
	import-count       [integer!]
	import-record-size [integer!]
	imports-offset     [integer!]
	imports-ordinal    [integer!]
	exports            [byte-ptr!]
	export-count       [integer!]
	export-record-size [integer!]
	exports-offset     [integer!]
	exports-ordinal    [integer!]
	function-count     [integer!]
	module-kind        [integer!]
	image-kind         [integer!]
]

wire-symbol-linkage-reader: context [
	expected-index-flags:
		WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	set-error: func [
		result [wire-symbol-linkage-result!]
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

	symbol-value: func [
		symbols [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value symbols id WIRE_RSIR_SYMBOL_SIZE field-offset
	]

	global-value: func [
		globals [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value globals id WIRE_RSIR_GLOBAL_SIZE field-offset
	]

	import-value: func [
		imports [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value imports id WIRE_IMPORT_SIZE field-offset
	]

	export-value: func [
		exports [wire-section-slice!]
		id field-offset [integer!]
		return: [integer!]
	][
		record-value exports id WIRE_EXPORT_SIZE field-offset
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

	module-value: func [
		modules [wire-module-lifecycle!]
		field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 modules/modules field-offset
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

	valid-type?: func [
		types [wire-type-layout!]
		id [integer!]
		return: [logic!]
	][
		all [id > 0 id <= types/type-count]
	]

	definition-linkage?: func [linkage [integer!] return: [logic!]][
		any [
			linkage = WIRE_LINKAGE_LOCAL
			linkage = WIRE_LINKAGE_INTERNAL
			linkage = WIRE_LINKAGE_EXTERNAL
			linkage = WIRE_LINKAGE_WEAK
		]
	]

	requires-definition?: func [linkage [integer!] return: [logic!]][
		any [
			linkage = WIRE_LINKAGE_LOCAL
			linkage = WIRE_LINKAGE_INTERNAL
			linkage = WIRE_LINKAGE_WEAK
		]
	]

	linkage-visibility-valid?: func [
		linkage visibility [integer!]
		return: [logic!]
	][
		case [
			linkage = WIRE_LINKAGE_LOCAL [return visibility = WIRE_VISIBILITY_HIDDEN]
			linkage = WIRE_LINKAGE_INTERNAL [return visibility = WIRE_VISIBILITY_HIDDEN]
			any [
				linkage = WIRE_LINKAGE_EXTERNAL
				linkage = WIRE_LINKAGE_IMPORT
				linkage = WIRE_LINKAGE_WEAK
			][return visibility = WIRE_VISIBILITY_DEFAULT]
			true [return false]
		]
	]

	definition-present?: func [
		section [byte-ptr!]
		count record-size symbol-offset wanted-symbol [integer!]
		return: [logic!]
		/local low high middle candidate [integer!]
	][
		low: 1
		high: count
		while [low <= high][
			middle: low + ((high - low) / 2)
			candidate: wire-container-reader/read-i31 section
				(((middle - 1) * record-size) + symbol-offset)
			case [
				candidate < wanted-symbol [low: middle + 1]
				candidate > wanted-symbol [high: middle - 1]
				true [return true]
			]
		]
		false
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

	copy-functions: func [destination source [wire-function-signature!]][
		destination/signatures: source/signatures
		destination/signature-count: source/signature-count
		destination/signature-record-size: source/signature-record-size
		destination/signatures-offset: source/signatures-offset
		destination/signatures-ordinal: source/signatures-ordinal
		destination/parameters: source/parameters
		destination/parameter-count: source/parameter-count
		destination/parameter-record-size: source/parameter-record-size
		destination/parameters-offset: source/parameters-offset
		destination/parameters-ordinal: source/parameters-ordinal
		destination/symbol-count: source/symbol-count
		destination/functions: source/functions
		destination/function-count: source/function-count
		destination/function-record-size: source/function-record-size
		destination/functions-offset: source/functions-offset
		destination/functions-ordinal: source/functions-ordinal
		destination/locals: source/locals
		destination/local-count: source/local-count
		destination/local-record-size: source/local-record-size
		destination/locals-offset: source/locals-offset
		destination/locals-ordinal: source/locals-ordinal
		destination/blocks: source/blocks
		destination/block-count: source/block-count
		destination/block-record-size: source/block-record-size
		destination/blocks-offset: source/blocks-offset
		destination/blocks-ordinal: source/blocks-ordinal
		destination/source-location-count: source/source-location-count
	]

	copy-modules: func [destination source [wire-module-lifecycle!]][
		destination/modules: source/modules
		destination/module-count: source/module-count
		destination/module-record-size: source/module-record-size
		destination/modules-offset: source/modules-offset
		destination/modules-ordinal: source/modules-ordinal
		destination/reference-count: source/reference-count
		destination/image-kind: source/image-kind
		destination/glue-module: source/glue-module
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-symbol-linkage-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		types [wire-type-layout!]
		functions [wire-function-signature!]
		modules [wire-module-lifecycle!]
		view [wire-symbol-linkage!]
		return: [integer!]
		/local function-result [wire-function-signature-result!]
			module-result [wire-module-lifecycle-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-types [wire-type-layout!]
			verified-functions [wire-function-signature!]
			module-strings [wire-string-table!]
			module-files [wire-file-source!]
			verified-modules [wire-module-lifecycle!]
			symbols globals imports exports [wire-section-slice!]
			record [byte-ptr!]
			status bad-relative record-index record-base source-count module-kind
			symbol-id global-id function-id import-id export-id previous-name
			previous-kind previous-symbol name-string kind linkage visibility type-ref
			flags owner source-location symbol-signature calling-convention
			global-symbol global-type function-symbol function-signature library-string
			external-name signature-cc ordinal definition-found module-ref
			lifecycle-offset symbol-linkage [integer!]
	][
		if null? result [return WIRE_SYMBOL_LINKAGE_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/type-layout-error: WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		result/function-signature-error: WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
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
			null? view
		][
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_ARGUMENTS 0 0
		]

		function-result: declare wire-function-signature-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-types: declare wire-type-layout!
		verified-functions: declare wire-function-signature!
		status: wire-function-signature-reader/verify data size function-result
			verified-strings verified-files verified-layout verified-types verified-functions
		if status <> WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS [
			result/container-error: function-result/container-error
			result/string-error: function-result/string-error
			result/file-source-error: function-result/file-source-error
			result/data-layout-error: function-result/data-layout-error
			result/type-layout-error: function-result/type-layout-error
			result/function-signature-error: status
			case [
				status = WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER
						function-result/error-offset function-result/error-section
				]
				status = WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_STRINGS [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_STRINGS
						function-result/error-offset function-result/error-section
				]
				status = WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_FILE_SOURCE [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FILE_SOURCE
						function-result/error-offset function-result/error-section
				]
				status = WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_DATA_LAYOUT [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_DATA_LAYOUT
						function-result/error-offset function-result/error-section
				]
				status = WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_TYPE_LAYOUT [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_TYPE_LAYOUT
						function-result/error-offset function-result/error-section
				]
				true [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FUNCTION_SIGNATURE
						function-result/error-offset function-result/error-section
				]
			]
		]

		module-result: declare wire-module-lifecycle-result!
		module-strings: declare wire-string-table!
		module-files: declare wire-file-source!
		verified-modules: declare wire-module-lifecycle!
		status: wire-module-lifecycle-reader/verify data size WIRE_MAGIC_RSIR
			module-result module-strings module-files verified-modules
		if status <> WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS [
			result/module-lifecycle-error: status
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_MODULE_LIFECYCLE
				module-result/error-offset module-result/error-section
		]

		symbols: declare wire-section-slice!
		globals: declare wire-section-slice!
		imports: declare wire-section-slice!
		exports: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_SYMBOLS symbols [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_GLOBALS globals [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_IMPORTS imports [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSIR_SECTION_EXPORTS exports [
			result/container-error: WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]

		if symbols/flags <> expected-index-flags [
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SECTION_FLAGS
				section-flags-offset symbols symbols/ordinal
		]
		if globals/flags <> 0 [
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SECTION_FLAGS
				section-flags-offset globals globals/ordinal
		]
		if imports/flags <> expected-index-flags [
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SECTION_FLAGS
				section-flags-offset imports imports/ordinal
		]
		if exports/flags <> expected-index-flags [
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SECTION_FLAGS
				section-flags-offset exports exports/ordinal
		]

		; Decode all signed scalar tables before following any semantic reference.
		record-index: 0
		while [record-index < symbols/record-count][
			record: symbols/data + (record-index * WIRE_RSIR_SYMBOL_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
					((symbols/offset + (record-index * WIRE_RSIR_SYMBOL_SIZE)) + bad-relative)
					symbols/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < globals/record-count][
			record: globals/data + (record-index * WIRE_RSIR_GLOBAL_SIZE)
			bad-relative: first-bad-scalar record 8
			if bad-relative >= 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
					((globals/offset + (record-index * WIRE_RSIR_GLOBAL_SIZE)) + bad-relative)
					globals/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < imports/record-count][
			record: imports/data + (record-index * WIRE_IMPORT_SIZE)
			bad-relative: first-bad-scalar record 6
			if bad-relative >= 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
					((imports/offset + (record-index * WIRE_IMPORT_SIZE)) + bad-relative)
					imports/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < exports/record-count][
			record: exports/data + (record-index * WIRE_EXPORT_SIZE)
			bad-relative: first-bad-scalar record 4
			if bad-relative >= 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
					((exports/offset + (record-index * WIRE_EXPORT_SIZE)) + bad-relative)
					exports/ordinal
			]
			record-index: record-index + 1
		]

		source-count: verified-functions/source-location-count
		module-kind: module-value verified-modules WIRE_RSIR_MODULE_KIND_OFFSET
		previous-name: 0
		previous-kind: 0
		symbol-id: 1
		while [symbol-id <= symbols/record-count][
			record-base: record-offset symbols symbol-id WIRE_RSIR_SYMBOL_SIZE
			name-string: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
			if any [name-string <= 0 name-string > verified-strings/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_NAME_ID
					(record-base + WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			unless nonempty-string? verified-strings name-string [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_SYMBOL_NAME
					(record-base + WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			kind: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless all [kind >= WIRE_SYMBOL_KIND_FUNCTION kind <= WIRE_SYMBOL_KIND_TYPE][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND
					(record-base + WIRE_RSIR_SYMBOL_KIND_OFFSET) symbols/ordinal
			]
			if any [
				name-string < previous-name
				all [name-string = previous-name kind < previous-kind]
			][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_SYMBOL_ORDER
					(record-base + WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			if all [
				name-string = previous-name
				any [
					kind = previous-kind
					all [kind <> WIRE_SYMBOL_KIND_TYPE previous-kind <> WIRE_SYMBOL_KIND_TYPE]
				]
			][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_SYMBOL_NAME
					(record-base + WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			previous-name: name-string
			previous-kind: kind
			linkage: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			unless all [linkage >= WIRE_LINKAGE_LOCAL linkage <= WIRE_LINKAGE_WEAK][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE
					(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
			]
			visibility: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET
			unless all [visibility >= WIRE_VISIBILITY_DEFAULT visibility <= WIRE_VISIBILITY_HIDDEN][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_VISIBILITY
					(record-base + WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET) symbols/ordinal
			]
			type-ref: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			either kind = WIRE_SYMBOL_KIND_FUNCTION [
				if any [type-ref <= 0 type-ref > verified-functions/signature-count][
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
						(record-base + WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET) symbols/ordinal
				]
			][
				if any [
					not valid-type? verified-types type-ref
					all [
						valid-type? verified-types type-ref
						(type-value verified-types type-ref WIRE_RSIR_TYPE_KIND_OFFSET)
							= WIRE_TYPE_KIND_VOID
					]
				][
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
						(record-base + WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET) symbols/ordinal
				]
			]
			if (symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_SYMBOL_FLAGS
					(record-base + WIRE_RSIR_SYMBOL_FLAGS_OFFSET) symbols/ordinal
			]
			owner: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET
			if owner <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_OWNER_SYMBOL
					(record-base + WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET) symbols/ordinal
			]
			source-location: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SOURCE_LOCATION
					(record-base + WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET) symbols/ordinal
			]
			unless linkage-visibility-valid? linkage visibility [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE_VISIBILITY
					(record-base + WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET) symbols/ordinal
			]
			if all [
				linkage = WIRE_LINKAGE_IMPORT
				not any [kind = WIRE_SYMBOL_KIND_FUNCTION kind = WIRE_SYMBOL_KIND_GLOBAL]
			][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND_LINKAGE
					(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
			]
			if all [
				any [kind = WIRE_SYMBOL_KIND_CONSTANT kind = WIRE_SYMBOL_KIND_TYPE]
				linkage <> WIRE_LINKAGE_LOCAL
			][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND_LINKAGE
					(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
			]
			if kind = WIRE_SYMBOL_KIND_FUNCTION [
				symbol-signature: symbol-value symbols symbol-id
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				if all [
					(signature-value verified-functions symbol-signature
						WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
						= WIRE_CALLING_CONVENTION_SYSCALL
					linkage <> WIRE_LINKAGE_EXTERNAL
				][
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
						(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
				]
			]
			symbol-id: symbol-id + 1
		]

		previous-symbol: 0
		global-id: 1
		while [global-id <= globals/record-count][
			record-base: record-offset globals global-id WIRE_RSIR_GLOBAL_SIZE
			global-symbol: global-value globals global-id WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
			if any [global-symbol <= 0 global-symbol > symbols/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL
					(record-base + WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) globals/ordinal
			]
			if (symbol-value symbols global-symbol WIRE_RSIR_SYMBOL_KIND_OFFSET)
				<> WIRE_SYMBOL_KIND_GLOBAL
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL_KIND
					(record-base + WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) globals/ordinal
			]
			global-type: global-value globals global-id WIRE_RSIR_GLOBAL_TYPE_OFFSET
			if global-type <> (symbol-value symbols global-symbol
				WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_TYPE_MISMATCH
					(record-base + WIRE_RSIR_GLOBAL_TYPE_OFFSET) globals/ordinal
			]
			if global-symbol < previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_ORDER
					(record-base + WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) globals/ordinal
			]
			if global-symbol = previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_GLOBAL_DEFINITION
					(record-base + WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) globals/ordinal
			]
			previous-symbol: global-symbol
			if (symbol-value symbols global-symbol WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				= WIRE_LINKAGE_IMPORT
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_GLOBAL_DEFINITION
					(record-base + WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) globals/ordinal
			]
			source-location: global-value globals global-id WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SOURCE_LOCATION
					(record-base + WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET) globals/ordinal
			]
			if (global-value globals global-id WIRE_RSIR_GLOBAL_RESERVED_OFFSET) <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_GLOBAL_RESERVED
					(record-base + WIRE_RSIR_GLOBAL_RESERVED_OFFSET) globals/ordinal
			]
			global-id: global-id + 1
		]

		previous-symbol: 0
		function-id: 1
		while [function-id <= verified-functions/function-count][
			record-base: verified-functions/functions-offset
				+ ((function-id - 1) * WIRE_RSIR_FUNCTION_SIZE)
			function-symbol: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
			kind: symbol-value symbols function-symbol WIRE_RSIR_SYMBOL_KIND_OFFSET
			if kind <> WIRE_SYMBOL_KIND_FUNCTION [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_FUNCTION_SYMBOL_KIND
					(record-base + WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					verified-functions/functions-ordinal
			]
			function-signature: function-value verified-functions function-id
				WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			if function-signature <> (symbol-value symbols function-symbol
				WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_SIGNATURE_MISMATCH
					(record-base + WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET)
					verified-functions/functions-ordinal
			]
			if function-symbol < previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_ORDER
					(record-base + WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					verified-functions/functions-ordinal
			]
			if function-symbol = previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_FUNCTION_DEFINITION
					(record-base + WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					verified-functions/functions-ordinal
			]
			previous-symbol: function-symbol
			if (symbol-value symbols function-symbol WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				= WIRE_LINKAGE_IMPORT
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_FUNCTION_DEFINITION
					(record-base + WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					verified-functions/functions-ordinal
			]
			function-id: function-id + 1
		]

		previous-symbol: 0
		import-id: 1
		while [import-id <= imports/record-count][
			record-base: record-offset imports import-id WIRE_IMPORT_SIZE
			library-string: import-value imports import-id WIRE_IMPORT_LIBRARY_STRING_OFFSET
			if any [library-string <= 0 library-string > verified-strings/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LIBRARY_ID
					(record-base + WIRE_IMPORT_LIBRARY_STRING_OFFSET) imports/ordinal
			]
			unless nonempty-string? verified-strings library-string [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_LIBRARY
					(record-base + WIRE_IMPORT_LIBRARY_STRING_OFFSET) imports/ordinal
			]
			external-name: import-value imports import-id WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > verified-strings/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
					(record-base + WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET) imports/ordinal
			]
			unless nonempty-string? verified-strings external-name [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
					(record-base + WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET) imports/ordinal
			]
			symbol-id: import-value imports import-id WIRE_IMPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > symbols/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL
					(record-base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			kind: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless any [kind = WIRE_SYMBOL_KIND_FUNCTION kind = WIRE_SYMBOL_KIND_GLOBAL][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL_KIND
					(record-base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			if (symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				<> WIRE_LINKAGE_IMPORT
			[
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LINKAGE
					(record-base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			calling-convention: import-value imports import-id WIRE_IMPORT_CALLING_CONVENTION_OFFSET
			either kind = WIRE_SYMBOL_KIND_FUNCTION [
				symbol-signature: symbol-value symbols symbol-id
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				signature-cc: signature-value verified-functions symbol-signature
					WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
				if any [
					not any [
						calling-convention = WIRE_CALLING_CONVENTION_RED_SYSTEM
						calling-convention = WIRE_CALLING_CONVENTION_CDECL
						calling-convention = WIRE_CALLING_CONVENTION_STDCALL
					]
					calling-convention <> signature-cc
				][
					return set-error result
						WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_CALLING_CONVENTION
						(record-base + WIRE_IMPORT_CALLING_CONVENTION_OFFSET) imports/ordinal
				]
			][
				if calling-convention <> 0 [
					return set-error result
						WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_CALLING_CONVENTION
						(record-base + WIRE_IMPORT_CALLING_CONVENTION_OFFSET) imports/ordinal
				]
			]
			if (import-value imports import-id WIRE_IMPORT_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_IMPORT_FLAGS
					(record-base + WIRE_IMPORT_FLAGS_OFFSET) imports/ordinal
			]
			source-location: import-value imports import-id WIRE_IMPORT_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SOURCE_LOCATION
					(record-base + WIRE_IMPORT_SOURCE_LOCATION_OFFSET) imports/ordinal
			]
			if symbol-id < previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_IMPORT_ORDER
					(record-base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			if symbol-id = previous-symbol [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_IMPORT_SYMBOL
					(record-base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			previous-symbol: symbol-id
			import-id: import-id + 1
		]

		global-id: 1
		function-id: 1
		import-id: 1
		symbol-id: 1
		while [symbol-id <= symbols/record-count][
			kind: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET
			linkage: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			while [all [
				global-id <= globals/record-count
				(global-value globals global-id WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) < symbol-id
			]][global-id: global-id + 1]
			while [all [
				function-id <= verified-functions/function-count
				(function-value verified-functions function-id WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					< symbol-id
			]][function-id: function-id + 1]
			while [all [
				import-id <= imports/record-count
				(import-value imports import-id WIRE_IMPORT_SYMBOL_OFFSET) < symbol-id
			]][import-id: import-id + 1]
			case [
				linkage = WIRE_LINKAGE_IMPORT [
					unless all [
						import-id <= imports/record-count
						(import-value imports import-id WIRE_IMPORT_SYMBOL_OFFSET) = symbol-id
					][
						record-base: record-offset symbols symbol-id WIRE_RSIR_SYMBOL_SIZE
						return set-error result WIRE_SYMBOL_LINKAGE_ERROR_MISSING_IMPORT
							(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
					]
				]
				all [kind = WIRE_SYMBOL_KIND_GLOBAL requires-definition? linkage][
					unless all [
						global-id <= globals/record-count
						(global-value globals global-id WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) = symbol-id
					][
						record-base: record-offset symbols symbol-id WIRE_RSIR_SYMBOL_SIZE
						return set-error result
							WIRE_SYMBOL_LINKAGE_ERROR_MISSING_GLOBAL_DEFINITION
							(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
					]
				]
				kind = WIRE_SYMBOL_KIND_FUNCTION [
					symbol-signature: symbol-value symbols symbol-id
						WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
					calling-convention: signature-value verified-functions symbol-signature
						WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
					either calling-convention = WIRE_CALLING_CONVENTION_SYSCALL [
						if all [
							function-id <= verified-functions/function-count
							(function-value verified-functions function-id
								WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = symbol-id
						][
							record-base: record-offset symbols symbol-id WIRE_RSIR_SYMBOL_SIZE
							return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
								(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
						]
					][if requires-definition? linkage [
						unless all [
							function-id <= verified-functions/function-count
							(function-value verified-functions function-id
								WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = symbol-id
						][
							record-base: record-offset symbols symbol-id WIRE_RSIR_SYMBOL_SIZE
							return set-error result
								WIRE_SYMBOL_LINKAGE_ERROR_MISSING_FUNCTION_DEFINITION
								(record-base + WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) symbols/ordinal
						]
					]]
				]
				true []
			]
			symbol-id: symbol-id + 1
		]

		if all [
			exports/record-count > 0
			verified-modules/image-kind <> WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
		][
			return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_IMAGE_KIND
				exports/offset exports/ordinal
		]
		previous-name: 0
		export-id: 1
		while [export-id <= exports/record-count][
			record-base: record-offset exports export-id WIRE_EXPORT_SIZE
			external-name: export-value exports export-id WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > verified-strings/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
					(record-base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			unless nonempty-string? verified-strings external-name [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
					(record-base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			symbol-id: export-value exports export-id WIRE_EXPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > symbols/record-count][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL
					(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			kind: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless any [kind = WIRE_SYMBOL_KIND_FUNCTION kind = WIRE_SYMBOL_KIND_GLOBAL][
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL_KIND
					(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			if external-name < previous-name [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_EXPORT_ORDER
					(record-base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			if external-name = previous-name [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_EXPORT_NAME
					(record-base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			previous-name: external-name
			ordinal: export-value exports export-id WIRE_EXPORT_ORDINAL_OFFSET
			if ordinal <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_ORDINAL
					(record-base + WIRE_EXPORT_ORDINAL_OFFSET) exports/ordinal
			]
			if (export-value exports export-id WIRE_EXPORT_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_FLAGS
					(record-base + WIRE_EXPORT_FLAGS_OFFSET) exports/ordinal
			]
			linkage: symbol-value symbols symbol-id WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			if linkage <> WIRE_LINKAGE_EXTERNAL [
				return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_LINKAGE
					(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			either kind = WIRE_SYMBOL_KIND_FUNCTION [
				definition-found: either definition-present? verified-functions/functions
					verified-functions/function-count WIRE_RSIR_FUNCTION_SIZE
					WIRE_RSIR_FUNCTION_SYMBOL_OFFSET symbol-id [1][0]
				if definition-found = 0 [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_MISSING_EXPORT_DEFINITION
						(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
				]
				symbol-signature: symbol-value symbols symbol-id
					WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				calling-convention: signature-value verified-functions symbol-signature
					WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
				flags: signature-value verified-functions symbol-signature
					WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				unless any [
					all [
						any [
							calling-convention = WIRE_CALLING_CONVENTION_CDECL
							calling-convention = WIRE_CALLING_CONVENTION_STDCALL
						]
						(flags and WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					]
					all [
						calling-convention = WIRE_CALLING_CONVENTION_RED_SYSTEM
						(flags and WIRE_FUNCTION_FLAG_CALLBACK) = 0
						module-kind = WIRE_MODULE_KIND_RUNTIME
					]
				][
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SIGNATURE
						(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
				]
			][
				definition-found: either definition-present? globals/data globals/record-count
					WIRE_RSIR_GLOBAL_SIZE WIRE_RSIR_GLOBAL_SYMBOL_OFFSET symbol-id [1][0]
				if definition-found = 0 [
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_MISSING_EXPORT_DEFINITION
						(record-base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
				]
			]
			export-id: export-id + 1
		]

		lifecycle-offset: WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET
		while [lifecycle-offset <= WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET][
			module-ref: module-value verified-modules lifecycle-offset
			if module-ref <> 0 [
				function-symbol: function-value verified-functions module-ref
					WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
				symbol-linkage: symbol-value symbols function-symbol WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
				if any [
					symbol-linkage = WIRE_LINKAGE_IMPORT
					symbol-linkage = WIRE_LINKAGE_WEAK
					not definition-linkage? symbol-linkage
				][
					return set-error result WIRE_SYMBOL_LINKAGE_ERROR_BAD_LIFECYCLE_FUNCTION
						(verified-modules/modules-offset + lifecycle-offset)
						verified-modules/modules-ordinal
				]
			]
			lifecycle-offset: lifecycle-offset + 4
		]

		copy-strings strings verified-strings
		copy-files files verified-files
		copy-layout layout verified-layout
		copy-types types verified-types
		copy-functions functions verified-functions
		copy-modules modules verified-modules
		view/symbols: symbols/data
		view/symbol-count: symbols/record-count
		view/symbol-record-size: symbols/record-size
		view/symbols-offset: symbols/offset
		view/symbols-ordinal: symbols/ordinal
		view/globals: globals/data
		view/global-count: globals/record-count
		view/global-record-size: globals/record-size
		view/globals-offset: globals/offset
		view/globals-ordinal: globals/ordinal
		view/imports: imports/data
		view/import-count: imports/record-count
		view/import-record-size: imports/record-size
		view/imports-offset: imports/offset
		view/imports-ordinal: imports/ordinal
		view/exports: exports/data
		view/export-count: exports/record-count
		view/export-record-size: exports/record-size
		view/exports-offset: exports/offset
		view/exports-ordinal: exports/ordinal
		view/function-count: verified-functions/function-count
		view/module-kind: module-kind
		view/image-kind: verified-modules/image-kind
		WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
	]
]
