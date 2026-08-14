Red/System [
	Title: "Hybrid compiler native RSCG relocation/import/export verifier"
	File:  %wire-rscg-relocation.reds
]

#include %wire-rscg-object.reds

wire-rscg-relocation-result!: alias struct! [
	error                   [integer!]
	object-error             [integer!]
	container-error          [integer!]
	string-error             [integer!]
	file-source-error        [integer!]
	data-layout-error        [integer!]
	module-lifecycle-error   [integer!]
	error-offset             [integer!]
	error-section            [integer!]
]

wire-rscg-relocation!: alias struct! [
	relocations              [byte-ptr!]
	relocation-count         [integer!]
	relocation-record-size   [integer!]
	relocations-offset       [integer!]
	relocations-ordinal      [integer!]
	imports                   [byte-ptr!]
	import-count              [integer!]
	import-record-size        [integer!]
	imports-offset            [integer!]
	imports-ordinal           [integer!]
	exports                   [byte-ptr!]
	export-count              [integer!]
	export-record-size        [integer!]
	exports-offset            [integer!]
	exports-ordinal           [integer!]
]

wire-rscg-relocation-reader: context [
	expected-index-flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED

	set-error: func [
		result [wire-rscg-relocation-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
	]

	section-flags-offset: func [section [wire-section-slice!] return: [integer!]][
		WIRE_HEADER_SIZE + (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
			+ WIRE_DIRECTORY_FLAGS_OFFSET)
	]

	relocation-value: func [
		view [wire-rscg-relocation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/relocations
			(((id - 1) * WIRE_RSCG_RELOCATION_SIZE) + field-offset)
	]

	import-value: func [
		view [wire-rscg-relocation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/imports
			(((id - 1) * WIRE_IMPORT_SIZE) + field-offset)
	]

	export-value: func [
		view [wire-rscg-relocation!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/exports
			(((id - 1) * WIRE_EXPORT_SIZE) + field-offset)
	]

	output-value: func [
		object-view [wire-rscg-object!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 object-view/output-sections
			(((id - 1) * WIRE_RSCG_OUTPUT_SECTION_SIZE) + field-offset)
	]

	symbol-value: func [
		object-view [wire-rscg-object!]
		id field-offset [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 object-view/symbols
			(((id - 1) * WIRE_RSCG_SYMBOL_SIZE) + field-offset)
	]

	symbol-defined?: func [
		object-view [wire-rscg-object!]
		id [integer!]
		return: [logic!]
	][
		(symbol-value object-view id WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = 0
	]

	string-size-for-id: func [
		strings [wire-string-table!]
		id [integer!]
		return: [integer!]
	][
		if any [id <= 0 id > strings/record-count][return -1]
		wire-container-reader/read-i31 strings/records
			(((id - 1) * WIRE_STRING_SIZE) + WIRE_STRING_SIZE_OFFSET)
	]

	find-import-for-symbol: func [
		view [wire-rscg-relocation!]
		symbol-id [integer!]
		return: [integer!]
		/local low high middle candidate [integer!]
	][
		low: 1
		high: view/import-count
		while [low <= high][
			middle: low + ((high - low) / 2)
			candidate: import-value view middle WIRE_IMPORT_SYMBOL_OFFSET
			case [
				candidate < symbol-id [low: middle + 1]
				candidate > symbol-id [high: middle - 1]
				true [return middle]
			]
		]
		0
	]

	sign-extended-i32-addend?: func [
		data [byte-ptr!]
		base [integer!]
		return: [logic!]
		/local is-negative [logic!] expected high index [integer!] p [byte-ptr!]
	][
		p: data + base
		p: p + WIRE_RSCG_RELOCATION_RAW_ADDEND_LOW_OFFSET
		p: p + 3
		is-negative: (as integer! p/1) > 127
		expected: either is-negative [255][0]
		high: base + WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET
		index: 0
		while [index < 4][
			p: data + high + index
			if (as integer! p/1) <> expected [return false]
			index: index + 1
		]
		true
	]

copy-relocation-view: func [
	destination [wire-rscg-relocation!]
	source [wire-rscg-relocation!]
][
		destination/relocations: source/relocations
		destination/relocation-count: source/relocation-count
		destination/relocation-record-size: source/relocation-record-size
		destination/relocations-offset: source/relocations-offset
		destination/relocations-ordinal: source/relocations-ordinal
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
	]

verify: func [
	data [byte-ptr!]
	size [integer!]
	result [wire-rscg-relocation-result!]
	strings [wire-string-table!]
	files [wire-file-source!]
	layout [wire-data-layout!]
	modules [wire-module-lifecycle!]
	object-output [wire-rscg-object!]
	output [wire-rscg-relocation!]
	return: [integer!]
	/local object-result [wire-rscg-object-result!]
		verified-strings [wire-string-table!]
		verified-files [wire-file-source!]
		verified-layout [wire-data-layout!]
		verified-modules [wire-module-lifecycle!]
		object-view [wire-rscg-object!]
		container-result [wire-container-result!]
		relocations imports exports [wire-section-slice!]
		view [wire-rscg-relocation!]
		status record-id base field-offset field-index bad-relative source-section source-offset kind
		target-symbol width flags source-class source-file-size source-data-offset
		placeholder-offset previous-section previous-offset previous-end target-kind
		import-id library-string external-name symbol-id binding
		calling-convention previous-symbol relocation-id image-kind export-id
		previous-name ordinal [integer!]
		is-defined is-used [logic!]
		expected [integer!]
	][
		if null? result [return WIRE_RSCG_RELOCATION_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		result/object-error: WIRE_RSCG_OBJECT_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0
		if any [
			size < 0 null? data null? strings null? files null? layout
			null? modules null? object-output null? output
		][
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_ARGUMENTS 0 0
		]

		object-result: declare wire-rscg-object-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-modules: declare wire-module-lifecycle!
		object-view: declare wire-rscg-object!
		container-result: declare wire-container-result!
		relocations: declare wire-section-slice!
		imports: declare wire-section-slice!
		exports: declare wire-section-slice!
		view: declare wire-rscg-relocation!

		status: wire-rscg-object-reader/verify data size object-result
			verified-strings verified-files verified-layout verified-modules object-view
		result/object-error: object-result/error
		result/container-error: object-result/container-error
		result/string-error: object-result/string-error
		result/file-source-error: object-result/file-source-error
		result/data-layout-error: object-result/data-layout-error
		result/module-lifecycle-error: object-result/module-lifecycle-error
		if status <> WIRE_RSCG_OBJECT_ERROR_SUCCESS [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
				object-result/error-offset object-result/error-section
		]

		status: wire-container-reader/verify data size WIRE_MAGIC_RSCG container-result
		unless status = WIRE_CONTAINER_ERROR_SUCCESS [
			result/container-error: container-result/error
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
				container-result/error-offset container-result/error-section
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_RELOCATIONS relocations [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_IMPORTS imports [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_EXPORTS exports [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT WIRE_HEADER_SIZE 0
		]

		if relocations/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_SECTION_FLAGS
				section-flags-offset relocations relocations/ordinal
		]
		if imports/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SECTION_FLAGS
				section-flags-offset imports imports/ordinal
		]
		if exports/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SECTION_FLAGS
				section-flags-offset exports exports/ordinal
		]

		view/relocations: relocations/data
		view/relocation-count: relocations/record-count
		view/relocation-record-size: relocations/record-size
		view/relocations-offset: relocations/offset
		view/relocations-ordinal: relocations/ordinal
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

		; Decode all non-raw fields before following any relocation reference.
		record-id: 1
		while [record-id <= view/relocation-count][
			base: (record-id - 1) * WIRE_RSCG_RELOCATION_SIZE
			field-index: 1
			while [field-index <= 6][
				field-offset: case [
					field-index = 1 [WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET]
					field-index = 2 [WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET]
					field-index = 3 [WIRE_RSCG_RELOCATION_KIND_OFFSET]
					field-index = 4 [WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET]
					field-index = 5 [WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET]
					true [WIRE_RSCG_RELOCATION_FLAGS_OFFSET]
				]
				if (wire-container-reader/read-i31 relocations/data
					(base + field-offset)) < 0 [
					return set-error result WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
						(relocations/offset + base + field-offset) relocations/ordinal
				]
				field-index: field-index + 1
			]
			record-id: record-id + 1
		]
		record-id: 0
		while [record-id < imports/record-count][
			base: record-id * imports/record-size
			field-offset: 0
			while [field-offset < imports/record-size][
				if (wire-container-reader/read-i31 imports/data (base + field-offset)) < 0 [
					return set-error result WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
						(imports/offset + base + field-offset) imports/ordinal
			]
				field-offset: field-offset + 4
			]
			record-id: record-id + 1
		]
		record-id: 0
		while [record-id < exports/record-count][
			base: record-id * exports/record-size
			field-offset: 0
			while [field-offset < exports/record-size][
				if (wire-container-reader/read-i31 exports/data (base + field-offset)) < 0 [
					return set-error result WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
						(exports/offset + base + field-offset) exports/ordinal
				]
				field-offset: field-offset + 4
			]
			record-id: record-id + 1
		]

		previous-section: 0
		previous-offset: 0
		previous-end: 0
		record-id: 1
		while [record-id <= view/relocation-count][
			base: (record-id - 1) * WIRE_RSCG_RELOCATION_SIZE
			source-section: relocation-value view record-id WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
			source-offset: relocation-value view record-id WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
			kind: relocation-value view record-id WIRE_RSCG_RELOCATION_KIND_OFFSET
			target-symbol: relocation-value view record-id WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
			width: relocation-value view record-id WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
			flags: relocation-value view record-id WIRE_RSCG_RELOCATION_FLAGS_OFFSET
			if any [source-section <= 0 source-section > object-view/output-section-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_SECTION
					(relocations/offset + base + WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET)
					relocations/ordinal
			]
			if any [
				source-section < previous-section
				all [source-section = previous-section source-offset < previous-offset]
			][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_RELOCATION_ORDER
					(relocations/offset + base + WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					relocations/ordinal
			]
			source-class: output-value object-view source-section WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
			unless any [
				source-class = WIRE_OUTPUT_SECTION_CLASS_CODE
				source-class = WIRE_OUTPUT_SECTION_CLASS_RODATA
				source-class = WIRE_OUTPUT_SECTION_CLASS_DATA
			][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_CLASS
					(relocations/offset + base + WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET)
					relocations/ordinal
			]
			unless all [kind >= WIRE_RELOCATION_KIND_X64_REL32 kind <= WIRE_RELOCATION_KIND_ABSOLUTE64][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_KIND
					(relocations/offset + base + WIRE_RSCG_RELOCATION_KIND_OFFSET)
					relocations/ordinal
			]
			if kind = WIRE_RELOCATION_KIND_ABSOLUTE32 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_UNSUPPORTED_RELOCATION_KIND
					(relocations/offset + base + WIRE_RSCG_RELOCATION_KIND_OFFSET)
					relocations/ordinal
			]
			if any [target-symbol <= 0 target-symbol > object-view/symbol-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_TARGET_SYMBOL
					(relocations/offset + base + WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
					relocations/ordinal
			]
			expected: either kind = WIRE_RELOCATION_KIND_ABSOLUTE64 [8][4]
			if width <> expected [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_ENCODED_WIDTH
					(relocations/offset + base + WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET)
					relocations/ordinal
			]
			source-file-size: output-value object-view source-section WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
			if any [source-offset > source-file-size width > (source-file-size - source-offset)][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_RANGE
					(relocations/offset + base + WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					relocations/ordinal
			]
			if all [source-section = previous-section source-offset < previous-end][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_OVERLAPPING_RELOCATION
					(relocations/offset + base + WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					relocations/ordinal
			]
			if flags <> WIRE_RSCG_RELOCATION_FLAG_NONE [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_FLAGS
					(relocations/offset + base + WIRE_RSCG_RELOCATION_FLAGS_OFFSET)
					relocations/ordinal
			]
			if all [kind <> WIRE_RELOCATION_KIND_ABSOLUTE64
				not sign-extended-i32-addend? relocations/data base][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_ADDEND
					(relocations/offset + base + WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET)
					relocations/ordinal
			]
			source-data-offset: output-value object-view source-section WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
			placeholder-offset: source-data-offset + source-offset
			bad-relative: wire-container-reader/first-nonzero object-view/output-data
				placeholder-offset (placeholder-offset + width)
			if bad-relative >= 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_NONZERO_PLACEHOLDER
					(object-view/output-data-offset + placeholder-offset)
					object-view/output-data-ordinal
			]
			unless either kind = WIRE_RELOCATION_KIND_ABSOLUTE64 [
				any [source-class = WIRE_OUTPUT_SECTION_CLASS_RODATA
					source-class = WIRE_OUTPUT_SECTION_CLASS_DATA]
			][source-class = WIRE_OUTPUT_SECTION_CLASS_CODE][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_SOURCE
					(relocations/offset + base + WIRE_RSCG_RELOCATION_KIND_OFFSET)
					relocations/ordinal
			]
			target-kind: symbol-value object-view target-symbol WIRE_RSCG_SYMBOL_KIND_OFFSET
			is-defined: symbol-defined? object-view target-symbol
			unless case [
				kind = WIRE_RELOCATION_KIND_X64_REL32 [target-kind = WIRE_SYMBOL_KIND_FUNCTION]
				kind = WIRE_RELOCATION_KIND_X64_RIP_REL32 [
					either is-defined [any [target-kind = WIRE_SYMBOL_KIND_FUNCTION
						target-kind = WIRE_SYMBOL_KIND_GLOBAL target-kind = WIRE_SYMBOL_KIND_CONSTANT]]
					[any [target-kind = WIRE_SYMBOL_KIND_FUNCTION target-kind = WIRE_SYMBOL_KIND_GLOBAL]]
				]
				kind = WIRE_RELOCATION_KIND_ABSOLUTE64 [is-defined]
				true [false]
			][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_TARGET
					(relocations/offset + base + WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
					relocations/ordinal
			]
			previous-section: source-section
			previous-offset: source-offset
			previous-end: source-offset + width
			record-id: record-id + 1
		]

		previous-symbol: 0
		import-id: 1
		while [import-id <= view/import-count][
			base: (import-id - 1) * WIRE_IMPORT_SIZE
			library-string: import-value view import-id WIRE_IMPORT_LIBRARY_STRING_OFFSET
			if any [library-string <= 0 library-string > verified-strings/record-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_LIBRARY_ID
					(imports/offset + base + WIRE_IMPORT_LIBRARY_STRING_OFFSET) imports/ordinal
			]
			if (string-size-for-id verified-strings library-string) = 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_LIBRARY
					(imports/offset + base + WIRE_IMPORT_LIBRARY_STRING_OFFSET) imports/ordinal
			]
			external-name: import-value view import-id WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > verified-strings/record-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
					(imports/offset + base + WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET) imports/ordinal
			]
			if (string-size-for-id verified-strings external-name) = 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
					(imports/offset + base + WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET) imports/ordinal
			]
			symbol-id: import-value view import-id WIRE_IMPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > object-view/symbol-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			target-kind: symbol-value object-view symbol-id WIRE_RSCG_SYMBOL_KIND_OFFSET
			unless any [target-kind = WIRE_SYMBOL_KIND_FUNCTION target-kind = WIRE_SYMBOL_KIND_GLOBAL][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL_KIND
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			binding: symbol-value object-view symbol-id WIRE_RSCG_SYMBOL_BINDING_OFFSET
			if binding <> WIRE_SYMBOL_BINDING_GLOBAL [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_BINDING
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			if (symbol-value object-view symbol-id WIRE_RSCG_SYMBOL_FLAGS_OFFSET)
				<> WIRE_RSCG_SYMBOL_FLAG_UNDEFINED [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			calling-convention: import-value view import-id WIRE_IMPORT_CALLING_CONVENTION_OFFSET
			unless either target-kind = WIRE_SYMBOL_KIND_FUNCTION [
				any [calling-convention = WIRE_CALLING_CONVENTION_RED_SYSTEM
					calling-convention = WIRE_CALLING_CONVENTION_CDECL
					calling-convention = WIRE_CALLING_CONVENTION_STDCALL]
			][calling-convention = 0][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_CALLING_CONVENTION
					(imports/offset + base + WIRE_IMPORT_CALLING_CONVENTION_OFFSET) imports/ordinal
			]
			if (import-value view import-id WIRE_IMPORT_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_FLAGS
					(imports/offset + base + WIRE_IMPORT_FLAGS_OFFSET) imports/ordinal
			]
			if (import-value view import-id WIRE_IMPORT_SOURCE_LOCATION_OFFSET) <> 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_SOURCE_LOCATION
					(imports/offset + base + WIRE_IMPORT_SOURCE_LOCATION_OFFSET) imports/ordinal
			]
			if symbol-id < previous-symbol [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_IMPORT_ORDER
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			if symbol-id = previous-symbol [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_IMPORT_SYMBOL
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			is-used: false
			relocation-id: 1
			while [relocation-id <= view/relocation-count][
				if (relocation-value view relocation-id
					WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET) = symbol-id [
					is-used: true
					if (relocation-value view relocation-id WIRE_RSCG_RELOCATION_KIND_OFFSET)
						<> WIRE_RELOCATION_KIND_X64_RIP_REL32 [
						base: (relocation-id - 1) * WIRE_RSCG_RELOCATION_SIZE
						return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_RELOCATION_KIND
							(relocations/offset + base + WIRE_RSCG_RELOCATION_KIND_OFFSET)
							relocations/ordinal
					]
				]
				relocation-id: relocation-id + 1
			]
			unless is-used [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_UNUSED_IMPORT
					(imports/offset + base + WIRE_IMPORT_SYMBOL_OFFSET) imports/ordinal
			]
			previous-symbol: symbol-id
			import-id: import-id + 1
		]

		relocation-id: 1
		while [relocation-id <= view/relocation-count][
			target-symbol: relocation-value view relocation-id WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
			unless symbol-defined? object-view target-symbol [
				if (find-import-for-symbol view target-symbol) = 0 [
					base: (relocation-id - 1) * WIRE_RSCG_RELOCATION_SIZE
					return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_TARGET_SYMBOL
						(relocations/offset + base + WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
						relocations/ordinal
				]
			]
			relocation-id: relocation-id + 1
		]

		image-kind: verified-modules/image-kind
		if all [view/export-count > 0 image-kind <> WIRE_IMAGE_KIND_DYNAMIC_LIBRARY][
			return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_IMAGE_KIND
				exports/offset exports/ordinal
		]
		previous-name: 0
		export-id: 1
		while [export-id <= view/export-count][
			base: (export-id - 1) * WIRE_EXPORT_SIZE
			external-name: export-value view export-id WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > verified-strings/record-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
					(exports/offset + base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			if (string-size-for-id verified-strings external-name) = 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
					(exports/offset + base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			symbol-id: export-value view export-id WIRE_EXPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > object-view/symbol-count][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL
					(exports/offset + base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			target-kind: symbol-value object-view symbol-id WIRE_RSCG_SYMBOL_KIND_OFFSET
			unless any [target-kind = WIRE_SYMBOL_KIND_FUNCTION target-kind = WIRE_SYMBOL_KIND_GLOBAL][
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL_KIND
					(exports/offset + base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			unless symbol-defined? object-view symbol-id [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL
					(exports/offset + base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			binding: symbol-value object-view symbol-id WIRE_RSCG_SYMBOL_BINDING_OFFSET
			if binding <> WIRE_SYMBOL_BINDING_GLOBAL [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_BINDING
					(exports/offset + base + WIRE_EXPORT_SYMBOL_OFFSET) exports/ordinal
			]
			ordinal: export-value view export-id WIRE_EXPORT_ORDINAL_OFFSET
			if ordinal <> 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_ORDINAL
					(exports/offset + base + WIRE_EXPORT_ORDINAL_OFFSET) exports/ordinal
			]
			if (export-value view export-id WIRE_EXPORT_FLAGS_OFFSET) <> 0 [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_FLAGS
					(exports/offset + base + WIRE_EXPORT_FLAGS_OFFSET) exports/ordinal
			]
			if external-name < previous-name [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_EXPORT_ORDER
					(exports/offset + base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			if external-name = previous-name [
				return set-error result WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_EXPORT_NAME
					(exports/offset + base + WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET) exports/ordinal
			]
			previous-name: external-name
			export-id: export-id + 1
		]

		; Commit all views only after the complete object has passed.
		wire-rscg-object-reader/copy-strings strings verified-strings
		wire-rscg-object-reader/copy-files files verified-files
		wire-rscg-object-reader/copy-layout layout verified-layout
		wire-rscg-object-reader/copy-modules modules verified-modules
		wire-rscg-object-reader/copy-view object-output object-view
		copy-relocation-view output view
		result/error: WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		WIRE_RSCG_RELOCATION_ERROR_SUCCESS
	]
]
