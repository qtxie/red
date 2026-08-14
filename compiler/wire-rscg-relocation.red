Red [
	Title: "Hybrid compiler RSCG relocation/import/export verifier"
	File:  %wire-rscg-relocation.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-rscg-object [do %wire-rscg-object.red]

compiler-wire-rscg-relocation: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	object-verifier: compiler-wire-rscg-object

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	make-view: does [
		make object! [
			relocations-offset: 0
			relocation-count: 0
			relocation-record-size: schema/WIRE_RSCG_RELOCATION_SIZE
			relocations-ordinal: 0
			imports-offset: 0
			import-count: 0
			import-record-size: schema/WIRE_IMPORT_SIZE
			imports-ordinal: 0
			exports-offset: 0
			export-count: 0
			export-record-size: schema/WIRE_EXPORT_SIZE
			exports-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS
			object-error: schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			module-lifecycle-error: schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			modules: none
			object-view: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-object-result: func [result object-result [object!]][
		result/header: object-result/header
		result/object-error: object-result/error
		result/container-error: object-result/container-error
		result/string-error: object-result/string-error
		result/file-source-error: object-result/file-source-error
		result/data-layout-error: object-result/data-layout-error
		result/module-lifecycle-error: object-result/module-lifecycle-error
	]

	section-flags-offset: func [section [map!]][
		(select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	]

	record-base: func [offset id size [integer!]][
		offset + ((id - 1) * size)
	]

	record-value: func [data [binary!] offset id size field [integer!]][
		container/read-i31 data ((record-base offset id size) + field)
	]

	relocation-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/relocations-offset id
			schema/WIRE_RSCG_RELOCATION_SIZE field
	]

	import-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/imports-offset id schema/WIRE_IMPORT_SIZE field
	]

	export-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/exports-offset id schema/WIRE_EXPORT_SIZE field
	]

	output-value: func [data [binary!] object-view [object!] id field [integer!]][
		record-value data object-view/output-sections-offset id
			schema/WIRE_RSCG_OUTPUT_SECTION_SIZE field
	]

	symbol-value: func [data [binary!] object-view [object!] id field [integer!]][
		record-value data object-view/symbols-offset id
			schema/WIRE_RSCG_SYMBOL_SIZE field
	]

	symbol-defined?: func [data [binary!] object-view [object!] id [integer!]][
		(symbol-value data object-view id schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = 0
	]

	string-size-for-id: func [data [binary!] strings [object!] id [integer!]][
		if any [id <= 0 id > strings/record-count][return none]
		container/read-i31 data (strings/records-offset
			+ (((id - 1) * schema/WIRE_STRING_SIZE)
			+ schema/WIRE_STRING_SIZE_OFFSET))
	]

	find-import-for-symbol: func [
		data [binary!] view [object!] symbol-id [integer!]
		/local low high middle candidate
	][
		low: 1
		high: view/import-count
		while [low <= high][
			middle: low + to integer! ((high - low) / 2)
			candidate: import-value data view middle schema/WIRE_IMPORT_SYMBOL_OFFSET
			case [
				candidate < symbol-id [low: middle + 1]
				candidate > symbol-id [high: middle - 1]
				true [return middle]
			]
		]
		none
	]

	sign-extended-i32-addend?: func [
		data [binary!] base [integer!]
		/local negative? expected high index
	][
		negative?: (to integer! pick data
			(base + schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_LOW_OFFSET + 4)) > 127
		expected: either negative? [255][0]
		high: base + schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET
		index: 0
		while [index < 4][
			if (to integer! pick data (high + index + 1)) <> expected [return false]
			index: index + 1
		]
		true
	]

	verify: func [
		data
		/local result object-result container-result relocations imports exports view
			object-view record-id base field-offset value source-section source-offset
			kind target-symbol width flags source-class source-file-size source-data-offset
			placeholder-offset previous-section previous-offset previous-end target-kind
			defined? import-id library-string external-name symbol-id binding
			calling-convention previous-symbol used? relocation-id export-id previous-name
			ordinal image-kind
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_ARGUMENTS 0 0
		]

		object-result: object-verifier/verify data
		inherit-object-result result object-result
		unless object-result/valid? [
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
				object-result/error-offset object-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSCG
		relocations: container/find-section container-result
			schema/WIRE_RSCG_SECTION_RELOCATIONS
		imports: container/find-section container-result schema/WIRE_RSCG_SECTION_IMPORTS
		exports: container/find-section container-result schema/WIRE_RSCG_SECTION_EXPORTS

		if (select relocations 'flags) <> expected-index-flags [
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_SECTION_FLAGS
				section-flags-offset relocations (select relocations 'ordinal)
		]
		if (select imports 'flags) <> expected-index-flags [
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SECTION_FLAGS
				section-flags-offset imports (select imports 'ordinal)
		]
		if (select exports 'flags) <> expected-index-flags [
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SECTION_FLAGS
				section-flags-offset exports (select exports 'ordinal)
		]

		view: make-view
		view/relocations-offset: select relocations 'payload-offset
		view/relocation-count: select relocations 'record-count
		view/relocation-record-size: select relocations 'record-size
		view/relocations-ordinal: select relocations 'ordinal
		view/imports-offset: select imports 'payload-offset
		view/import-count: select imports 'record-count
		view/import-record-size: select imports 'record-size
		view/imports-ordinal: select imports 'ordinal
		view/exports-offset: select exports 'payload-offset
		view/export-count: select exports 'record-count
		view/export-record-size: select exports 'record-size
		view/exports-ordinal: select exports 'ordinal
		object-view: object-result/view

		; Raw addend words are bit containers. Every other field is an i31 scalar.
		record-id: 1
		while [record-id <= view/relocation-count][
			base: record-base view/relocations-offset record-id
				schema/WIRE_RSCG_RELOCATION_SIZE
			foreach field-offset reduce [
				schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
				schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
				schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
				schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
				schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
				schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET
			][
				value: container/read-i31 data (base + field-offset)
				if none? value [
					return reject result schema/WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
						(base + field-offset) view/relocations-ordinal
				]
			]
			record-id: record-id + 1
		]
		foreach section reduce [imports exports][
			record-id: 1
			while [record-id <= (select section 'record-count)][
				base: record-base (select section 'payload-offset) record-id
					(select section 'record-size)
				field-offset: 0
				while [field-offset < (select section 'record-size)][
					if none? container/read-i31 data (base + field-offset) [
						return reject result schema/WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
							(base + field-offset) (select section 'ordinal)
					]
					field-offset: field-offset + 4
				]
				record-id: record-id + 1
			]
		]

		previous-section: 0
		previous-offset: 0
		previous-end: 0
		record-id: 1
		while [record-id <= view/relocation-count][
			base: record-base view/relocations-offset record-id
				schema/WIRE_RSCG_RELOCATION_SIZE
			source-section: relocation-value data view record-id
				schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
			source-offset: relocation-value data view record-id
				schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
			kind: relocation-value data view record-id schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
			target-symbol: relocation-value data view record-id
				schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
			width: relocation-value data view record-id
				schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
			flags: relocation-value data view record-id schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET

			if any [source-section <= 0 source-section > object-view/output-section-count][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_SECTION
					(base + schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET)
					view/relocations-ordinal
			]
			if any [
				source-section < previous-section
				all [source-section = previous-section source-offset < previous-offset]
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_RELOCATION_ORDER
					(base + schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					view/relocations-ordinal
			]
			source-class: output-value data object-view source-section
				schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
			unless find reduce [
				schema/WIRE_OUTPUT_SECTION_CLASS_CODE
				schema/WIRE_OUTPUT_SECTION_CLASS_RODATA
				schema/WIRE_OUTPUT_SECTION_CLASS_DATA
			] source-class [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_CLASS
					(base + schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET)
					view/relocations-ordinal
			]
			unless all [
				kind >= schema/WIRE_RELOCATION_KIND_X64_REL32
				kind <= schema/WIRE_RELOCATION_KIND_ABSOLUTE64
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_KIND
					(base + schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
					view/relocations-ordinal
			]
			if kind = schema/WIRE_RELOCATION_KIND_ABSOLUTE32 [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_UNSUPPORTED_RELOCATION_KIND
					(base + schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
					view/relocations-ordinal
			]
			if any [target-symbol <= 0 target-symbol > object-view/symbol-count][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_TARGET_SYMBOL
					(base + schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
					view/relocations-ordinal
			]
			unless width = either kind = schema/WIRE_RELOCATION_KIND_ABSOLUTE64 [8][4][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_ENCODED_WIDTH
					(base + schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET)
					view/relocations-ordinal
			]
			source-file-size: output-value data object-view source-section
				schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
			unless all [
				source-offset <= source-file-size
				width <= (source-file-size - source-offset)
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_RANGE
					(base + schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					view/relocations-ordinal
			]
			if all [source-section = previous-section source-offset < previous-end][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_OVERLAPPING_RELOCATION
					(base + schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET)
					view/relocations-ordinal
			]
			if flags <> schema/WIRE_RSCG_RELOCATION_FLAG_NONE [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_FLAGS
					(base + schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET)
					view/relocations-ordinal
			]
			if all [
				kind <> schema/WIRE_RELOCATION_KIND_ABSOLUTE64
				not sign-extended-i32-addend? data base
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_ADDEND
					(base + schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET)
					view/relocations-ordinal
			]
			source-data-offset: output-value data object-view source-section
				schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
			placeholder-offset: object-view/output-data-offset
				+ source-data-offset + source-offset
			if not none? container/first-nonzero data placeholder-offset
				(placeholder-offset + width)
			[
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_PLACEHOLDER
					placeholder-offset object-view/output-data-ordinal
			]
			unless either kind = schema/WIRE_RELOCATION_KIND_ABSOLUTE64 [
				find reduce [
					schema/WIRE_OUTPUT_SECTION_CLASS_RODATA
					schema/WIRE_OUTPUT_SECTION_CLASS_DATA
				] source-class
			][
				source-class = schema/WIRE_OUTPUT_SECTION_CLASS_CODE
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_SOURCE
					(base + schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
					view/relocations-ordinal
			]
			target-kind: symbol-value data object-view target-symbol
				schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
			defined?: symbol-defined? data object-view target-symbol
			unless case [
				kind = schema/WIRE_RELOCATION_KIND_X64_REL32 [
					target-kind = schema/WIRE_SYMBOL_KIND_FUNCTION
				]
				kind = schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 [
					either defined? [
						find reduce [
							schema/WIRE_SYMBOL_KIND_FUNCTION
							schema/WIRE_SYMBOL_KIND_GLOBAL
							schema/WIRE_SYMBOL_KIND_CONSTANT
						] target-kind
					][
						find reduce [
							schema/WIRE_SYMBOL_KIND_FUNCTION
							schema/WIRE_SYMBOL_KIND_GLOBAL
						] target-kind
					]
				]
				kind = schema/WIRE_RELOCATION_KIND_ABSOLUTE64 [defined?]
				true [false]
			][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_TARGET
					(base + schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
					view/relocations-ordinal
			]
			previous-section: source-section
			previous-offset: source-offset
			previous-end: source-offset + width
			record-id: record-id + 1
		]

		previous-symbol: 0
		import-id: 1
		while [import-id <= view/import-count][
			base: record-base view/imports-offset import-id schema/WIRE_IMPORT_SIZE
			library-string: import-value data view import-id
				schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
			if any [library-string <= 0 library-string > object-result/strings/record-count][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_LIBRARY_ID
					(base + schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET) view/imports-ordinal
			]
			if zero? string-size-for-id data object-result/strings library-string [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_LIBRARY
					(base + schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET) view/imports-ordinal
			]
			external-name: import-value data view import-id
				schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > object-result/strings/record-count][
				return reject result
					schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
					(base + schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/imports-ordinal
			]
			if zero? string-size-for-id data object-result/strings external-name [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
					(base + schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/imports-ordinal
			]
			symbol-id: import-value data view import-id schema/WIRE_IMPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > object-view/symbol-count][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			target-kind: symbol-value data object-view symbol-id schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
			unless find reduce [
				schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL
			] target-kind [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL_KIND
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			binding: symbol-value data object-view symbol-id schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
			if binding <> schema/WIRE_SYMBOL_BINDING_GLOBAL [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_BINDING
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			unless (symbol-value data object-view symbol-id
				schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED
			[
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			calling-convention: import-value data view import-id
				schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
			unless either target-kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
				find reduce [
					schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
					schema/WIRE_CALLING_CONVENTION_CDECL
					schema/WIRE_CALLING_CONVENTION_STDCALL
				] calling-convention
			][zero? calling-convention][
				return reject result
					schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_CALLING_CONVENTION
					(base + schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
					view/imports-ordinal
			]
			if (import-value data view import-id schema/WIRE_IMPORT_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_FLAGS
					(base + schema/WIRE_IMPORT_FLAGS_OFFSET) view/imports-ordinal
			]
			if (import-value data view import-id schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET) <> 0 [
				return reject result
					schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_SOURCE_LOCATION
					(base + schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET) view/imports-ordinal
			]
			if symbol-id < previous-symbol [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_IMPORT_ORDER
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			if symbol-id = previous-symbol [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_IMPORT_SYMBOL
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			used?: false
			relocation-id: 1
			while [relocation-id <= view/relocation-count][
				if (relocation-value data view relocation-id
					schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET) = symbol-id
				[
					used?: true
					if (relocation-value data view relocation-id
						schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
						<> schema/WIRE_RELOCATION_KIND_X64_RIP_REL32
					[
						return reject result
							schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_RELOCATION_KIND
							(record-base view/relocations-offset relocation-id
								schema/WIRE_RSCG_RELOCATION_SIZE)
							+ schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
							view/relocations-ordinal
					]
				]
				relocation-id: relocation-id + 1
			]
			unless used? [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_UNUSED_IMPORT
					(base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			previous-symbol: symbol-id
			import-id: import-id + 1
		]

		; Every referenced undefined symbol must have one validated import mapping.
		relocation-id: 1
		while [relocation-id <= view/relocation-count][
			target-symbol: relocation-value data view relocation-id
				schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
			unless symbol-defined? data object-view target-symbol [
				if none? find-import-for-symbol data view target-symbol [
					base: record-base view/relocations-offset relocation-id
						schema/WIRE_RSCG_RELOCATION_SIZE
					return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_TARGET_SYMBOL
						(base + schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET)
						view/relocations-ordinal
				]
			]
			relocation-id: relocation-id + 1
		]

		image-kind: object-result/modules/image-kind
		if all [
			view/export-count > 0
			image-kind <> schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
		][
			return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_IMAGE_KIND
				view/exports-offset view/exports-ordinal
		]
		previous-name: 0
		export-id: 1
		while [export-id <= view/export-count][
			base: record-base view/exports-offset export-id schema/WIRE_EXPORT_SIZE
			external-name: export-value data view export-id
				schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > object-result/strings/record-count][
				return reject result
					schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
					(base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			if zero? string-size-for-id data object-result/strings external-name [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
					(base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			symbol-id: export-value data view export-id schema/WIRE_EXPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > object-view/symbol-count][
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL
					(base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			target-kind: symbol-value data object-view symbol-id schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
			unless find reduce [
				schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL
			] target-kind [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL_KIND
					(base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			unless symbol-defined? data object-view symbol-id [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL
					(base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			binding: symbol-value data object-view symbol-id schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
			if binding <> schema/WIRE_SYMBOL_BINDING_GLOBAL [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_BINDING
					(base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			ordinal: export-value data view export-id schema/WIRE_EXPORT_ORDINAL_OFFSET
			if ordinal <> 0 [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_ORDINAL
					(base + schema/WIRE_EXPORT_ORDINAL_OFFSET) view/exports-ordinal
			]
			if (export-value data view export-id schema/WIRE_EXPORT_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_FLAGS
					(base + schema/WIRE_EXPORT_FLAGS_OFFSET) view/exports-ordinal
			]
			if external-name < previous-name [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_EXPORT_ORDER
					(base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			if external-name = previous-name [
				return reject result schema/WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_EXPORT_NAME
					(base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			previous-name: external-name
			export-id: export-id + 1
		]

		result/strings: object-result/strings
		result/files: object-result/files
		result/layout: object-result/layout
		result/modules: object-result/modules
		result/object-view: object-view
		result/view: view
		result/valid?: true
		result
	]
]
