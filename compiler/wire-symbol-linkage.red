Red [
	Title: "Hybrid compiler RSIR symbol, import, and export verifier"
	File:  %wire-symbol-linkage.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-function-signature [do %wire-function-signature.red]
unless value? 'compiler-wire-module-lifecycle [do %wire-module-lifecycle.red]

compiler-wire-symbol-linkage: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	function-verifier: compiler-wire-function-signature
	module-verifier: compiler-wire-module-lifecycle

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	symbol-fields: reduce [
		'name-string       schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
		'kind              schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
		'linkage           schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
		'visibility        schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET
		'type-or-signature schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
		'flags             schema/WIRE_RSIR_SYMBOL_FLAGS_OFFSET
		'owner-symbol      schema/WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET
		'source-location   schema/WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET
	]

	global-fields: reduce [
		'symbol               schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
		'type                 schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET
		'initializer-constant schema/WIRE_RSIR_GLOBAL_INITIALIZER_CONSTANT_OFFSET
		'alignment            schema/WIRE_RSIR_GLOBAL_ALIGNMENT_OFFSET
		'section-class        schema/WIRE_RSIR_GLOBAL_SECTION_CLASS_OFFSET
		'flags                schema/WIRE_RSIR_GLOBAL_FLAGS_OFFSET
		'source-location      schema/WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET
		'reserved             schema/WIRE_RSIR_GLOBAL_RESERVED_OFFSET
	]

	import-fields: reduce [
		'library-string       schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
		'external-name-string schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
		'symbol               schema/WIRE_IMPORT_SYMBOL_OFFSET
		'calling-convention   schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
		'flags                schema/WIRE_IMPORT_FLAGS_OFFSET
		'source-location      schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET
	]

	export-fields: reduce [
		'external-name-string schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
		'symbol               schema/WIRE_EXPORT_SYMBOL_OFFSET
		'ordinal              schema/WIRE_EXPORT_ORDINAL_OFFSET
		'flags                schema/WIRE_EXPORT_FLAGS_OFFSET
	]

	make-view: does [
		make object! [
			symbols-offset: 0
			symbol-count: 0
			symbol-record-size: schema/WIRE_RSIR_SYMBOL_SIZE
			symbols-ordinal: 0
			globals-offset: 0
			global-count: 0
			global-record-size: schema/WIRE_RSIR_GLOBAL_SIZE
			globals-ordinal: 0
			imports-offset: 0
			import-count: 0
			import-record-size: schema/WIRE_IMPORT_SIZE
			imports-ordinal: 0
			exports-offset: 0
			export-count: 0
			export-record-size: schema/WIRE_EXPORT_SIZE
			exports-ordinal: 0
			function-count: 0
			module-kind: 0
			image-kind: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
			container-error: schema/WIRE_CONTAINER_ERROR_SUCCESS
			string-error: schema/WIRE_STRING_TABLE_ERROR_SUCCESS
			file-source-error: schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
			data-layout-error: schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
			type-layout-error: schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
			function-signature-error: schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
			module-lifecycle-error: schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
			error-offset: 0
			error-section: 0
			header: none
			strings: none
			files: none
			layout: none
			types: none
			functions: none
			modules: none
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

	record-value: func [data [binary!] base size id field [integer!]][
		container/read-i31 data ((record-offset base (id - 1) size) + field)
	]

	symbol-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/symbols-offset schema/WIRE_RSIR_SYMBOL_SIZE id field
	]

	global-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/globals-offset schema/WIRE_RSIR_GLOBAL_SIZE id field
	]

	import-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/imports-offset schema/WIRE_IMPORT_SIZE id field
	]

	export-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/exports-offset schema/WIRE_EXPORT_SIZE id field
	]

	function-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/functions-offset schema/WIRE_RSIR_FUNCTION_SIZE id field
	]

	signature-value: func [data [binary!] functions [object!] id field [integer!]][
		record-value data functions/signatures-offset schema/WIRE_RSIR_SIGNATURE_SIZE id field
	]

	module-value: func [data [binary!] modules [object!] field [integer!]][
		container/read-i31 data (modules/modules-offset + field)
	]

	string-size-for-id: func [data [binary!] strings [object!] id [integer!]][
		if any [id <= 0 id > strings/record-count][return none]
		container/read-i31 data (strings/records-offset
			+ (((id - 1) * schema/WIRE_STRING_SIZE)
			+ schema/WIRE_STRING_SIZE_OFFSET))
	]

	type-kind: func [data [binary!] types [object!] id [integer!]][
		if any [id <= 0 id > types/type-count][return none]
		container/read-i31 data (types/types-offset
			+ (((id - 1) * schema/WIRE_RSIR_TYPE_SIZE)
			+ schema/WIRE_RSIR_TYPE_KIND_OFFSET))
	]

	valid-type?: func [types [object!] id [integer!]][
		all [id > 0 id <= types/type-count]
	]

	definition-linkage?: func [linkage [integer!]][
		not none? find reduce [
			schema/WIRE_LINKAGE_LOCAL
			schema/WIRE_LINKAGE_INTERNAL
			schema/WIRE_LINKAGE_EXTERNAL
			schema/WIRE_LINKAGE_WEAK
		] linkage
	]

	requires-definition?: func [linkage [integer!]][
		not none? find reduce [
			schema/WIRE_LINKAGE_LOCAL
			schema/WIRE_LINKAGE_INTERNAL
			schema/WIRE_LINKAGE_WEAK
		] linkage
	]

	linkage-visibility-valid?: func [linkage visibility [integer!]][
		case [
			linkage = schema/WIRE_LINKAGE_LOCAL [
				visibility = schema/WIRE_VISIBILITY_HIDDEN
			]
			linkage = schema/WIRE_LINKAGE_INTERNAL [
				visibility = schema/WIRE_VISIBILITY_HIDDEN
			]
			any [
				linkage = schema/WIRE_LINKAGE_EXTERNAL
				linkage = schema/WIRE_LINKAGE_IMPORT
				linkage = schema/WIRE_LINKAGE_WEAK
			][visibility = schema/WIRE_VISIBILITY_DEFAULT]
			true [false]
		]
	]

	verify: func [
		data
		/local result function-result module-result container-result symbols globals
			imports exports functions view source-count record-index record-base
			field-name field-offset value expected-flags symbol-id global-id function-id import-id
			export-id name-string previous-name previous-kind kind linkage visibility type-ref
			flags owner source-location global-symbol global-type previous-symbol
			function-symbol function-signature library-string external-name
			calling-convention signature-cc ordinal definition-id
			module-ref module-kind lifecycle-offset symbol-kind symbol-linkage
			symbol-signature
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_ARGUMENTS 0 0
		]

		function-result: function-verifier/verify data
		result/header: function-result/header
		unless function-result/valid? [
			result/container-error: function-result/container-error
			result/string-error: function-result/string-error
			result/file-source-error: function-result/file-source-error
			result/data-layout-error: function-result/data-layout-error
			result/type-layout-error: function-result/type-layout-error
			result/function-signature-error: function-result/error
			case [
				function-result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_CONTAINER [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER
						function-result/error-offset function-result/error-section
				]
				function-result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_STRINGS [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_STRINGS
						function-result/error-offset function-result/error-section
				]
				function-result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_FILE_SOURCE [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FILE_SOURCE
						function-result/error-offset function-result/error-section
				]
				function-result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_DATA_LAYOUT [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_DATA_LAYOUT
						function-result/error-offset function-result/error-section
				]
				function-result/error = schema/WIRE_FUNCTION_SIGNATURE_ERROR_INVALID_TYPE_LAYOUT [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_TYPE_LAYOUT
						function-result/error-offset function-result/error-section
				]
				true [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_FUNCTION_SIGNATURE
						function-result/error-offset function-result/error-section
				]
			]
		]

		module-result: module-verifier/verify data schema/WIRE_MAGIC_RSIR
		unless module-result/valid? [
			result/module-lifecycle-error: module-result/error
			return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_MODULE_LIFECYCLE
				module-result/error-offset module-result/error-section
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSIR
		symbols: container/find-section container-result schema/WIRE_RSIR_SECTION_SYMBOLS
		globals: container/find-section container-result schema/WIRE_RSIR_SECTION_GLOBALS
		imports: container/find-section container-result schema/WIRE_RSIR_SECTION_IMPORTS
		exports: container/find-section container-result schema/WIRE_RSIR_SECTION_EXPORTS
		functions: container/find-section container-result schema/WIRE_RSIR_SECTION_FUNCTIONS
		if any [none? symbols none? globals none? imports none? exports none? functions][
			result/container-error: schema/WIRE_CONTAINER_ERROR_MISSING_REQUIRED_SECTION
			return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_INVALID_CONTAINER
				schema/WIRE_HEADER_SIZE 0
		]

		foreach [section code] reduce [
			symbols schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SECTION_FLAGS
			globals schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SECTION_FLAGS
			imports schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SECTION_FLAGS
			exports schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SECTION_FLAGS
		][
			expected-flags: either section = globals [0][expected-index-flags]
			if (select section 'flags) <> expected-flags [
				return reject result code (section-flags-offset section)
					(select section 'ordinal)
			]
		]

		view: make-view
		view/symbols-offset: select symbols 'payload-offset
		view/symbol-count: select symbols 'record-count
		view/symbol-record-size: select symbols 'record-size
		view/symbols-ordinal: select symbols 'ordinal
		view/globals-offset: select globals 'payload-offset
		view/global-count: select globals 'record-count
		view/global-record-size: select globals 'record-size
		view/globals-ordinal: select globals 'ordinal
		view/imports-offset: select imports 'payload-offset
		view/import-count: select imports 'record-count
		view/import-record-size: select imports 'record-size
		view/imports-ordinal: select imports 'ordinal
		view/exports-offset: select exports 'payload-offset
		view/export-count: select exports 'record-count
		view/export-record-size: select exports 'record-size
		view/exports-ordinal: select exports 'ordinal
		view/function-count: function-result/view/function-count
		module-kind: module-value data module-result/view schema/WIRE_RSIR_MODULE_KIND_OFFSET
		view/module-kind: module-kind
		view/image-kind: module-result/view/image-kind
		source-count: function-result/view/source-location-count

		foreach [count base size section-ordinal fields] reduce [
			view/symbol-count view/symbols-offset schema/WIRE_RSIR_SYMBOL_SIZE
				view/symbols-ordinal symbol-fields
			view/global-count view/globals-offset schema/WIRE_RSIR_GLOBAL_SIZE
				view/globals-ordinal global-fields
			view/import-count view/imports-offset schema/WIRE_IMPORT_SIZE
				view/imports-ordinal import-fields
			view/export-count view/exports-offset schema/WIRE_EXPORT_SIZE
				view/exports-ordinal export-fields
		][
			record-index: 0
			while [record-index < count][
				record-base: record-offset base record-index size
				foreach [field-name field-offset] fields [
					value: container/read-i31 data (record-base + field-offset)
					if none? value [
						return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_SCALAR_RANGE
							(record-base + field-offset) section-ordinal
					]
				]
				record-index: record-index + 1
			]
		]

		previous-name: 0
		previous-kind: 0
		symbol-id: 1
		while [symbol-id <= view/symbol-count][
			record-base: record-offset view/symbols-offset (symbol-id - 1)
				schema/WIRE_RSIR_SYMBOL_SIZE
			name-string: symbol-value data view symbol-id
				schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET
			if any [name-string <= 0 name-string > function-result/strings/record-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_NAME_ID
					(record-base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			if zero? string-size-for-id data function-result/strings name-string [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_SYMBOL_NAME
					(record-base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			kind: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless all [kind >= schema/WIRE_SYMBOL_KIND_FUNCTION kind <= schema/WIRE_SYMBOL_KIND_TYPE][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND
					(record-base + schema/WIRE_RSIR_SYMBOL_KIND_OFFSET) view/symbols-ordinal
			]
			if any [
				name-string < previous-name
				all [name-string = previous-name kind < previous-kind]
			][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_SYMBOL_ORDER
					(record-base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			if all [
				name-string = previous-name
				any [
					kind = previous-kind
					all [
						kind <> schema/WIRE_SYMBOL_KIND_TYPE
						previous-kind <> schema/WIRE_SYMBOL_KIND_TYPE
					]
				]
			][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_SYMBOL_NAME
					(record-base + schema/WIRE_RSIR_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			previous-name: name-string
			previous-kind: kind
			linkage: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			unless all [linkage >= schema/WIRE_LINKAGE_LOCAL linkage <= schema/WIRE_LINKAGE_WEAK][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE
					(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET) view/symbols-ordinal
			]
			visibility: symbol-value data view symbol-id
				schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET
			unless all [
				visibility >= schema/WIRE_VISIBILITY_DEFAULT
				visibility <= schema/WIRE_VISIBILITY_HIDDEN
			][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_VISIBILITY
					(record-base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
					view/symbols-ordinal
			]
			type-ref: symbol-value data view symbol-id
				schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			either kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
				if any [
					type-ref <= 0
					type-ref > function-result/view/signature-count
				][
					return reject result
						schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
						(record-base + schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
						view/symbols-ordinal
				]
			][
				if any [
					not valid-type? function-result/types type-ref
					(type-kind data function-result/types type-ref) = schema/WIRE_TYPE_KIND_VOID
				][
					return reject result
						schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_TYPE_OR_SIGNATURE
						(record-base + schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET)
						view/symbols-ordinal
				]
			]
			if (symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_SYMBOL_FLAGS
					(record-base + schema/WIRE_RSIR_SYMBOL_FLAGS_OFFSET) view/symbols-ordinal
			]
			owner: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET
			if owner <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_OWNER_SYMBOL
					(record-base + schema/WIRE_RSIR_SYMBOL_OWNER_SYMBOL_OFFSET)
					view/symbols-ordinal
			]
			source-location: symbol-value data view symbol-id
				schema/WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_SYMBOL_SOURCE_LOCATION_OFFSET)
					view/symbols-ordinal
			]
			unless linkage-visibility-valid? linkage visibility [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LINKAGE_VISIBILITY
					(record-base + schema/WIRE_RSIR_SYMBOL_VISIBILITY_OFFSET)
					view/symbols-ordinal
			]
			if all [
				linkage = schema/WIRE_LINKAGE_IMPORT
				not find reduce [schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL] kind
			][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND_LINKAGE
					(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
					view/symbols-ordinal
			]
			if all [
				find reduce [schema/WIRE_SYMBOL_KIND_CONSTANT schema/WIRE_SYMBOL_KIND_TYPE] kind
				linkage <> schema/WIRE_LINKAGE_LOCAL
			][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYMBOL_KIND_LINKAGE
					(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
					view/symbols-ordinal
			]
			if kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
				symbol-signature: symbol-value data view symbol-id
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				if all [
					(signature-value data function-result/view symbol-signature
						schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
						= schema/WIRE_CALLING_CONVENTION_SYSCALL
					linkage <> schema/WIRE_LINKAGE_EXTERNAL
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
						(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
						view/symbols-ordinal
				]
			]
			symbol-id: symbol-id + 1
		]

		previous-symbol: 0
		global-id: 1
		while [global-id <= view/global-count][
			record-base: record-offset view/globals-offset (global-id - 1)
				schema/WIRE_RSIR_GLOBAL_SIZE
			global-symbol: global-value data view global-id schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET
			if any [global-symbol <= 0 global-symbol > view/symbol-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL
					(record-base + schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) view/globals-ordinal
			]
			if (symbol-value data view global-symbol schema/WIRE_RSIR_SYMBOL_KIND_OFFSET)
				<> schema/WIRE_SYMBOL_KIND_GLOBAL
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SYMBOL_KIND
					(record-base + schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) view/globals-ordinal
			]
			global-type: global-value data view global-id schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET
			if global-type <> symbol-value data view global-symbol
				schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_TYPE_MISMATCH
					(record-base + schema/WIRE_RSIR_GLOBAL_TYPE_OFFSET) view/globals-ordinal
			]
			if global-symbol < previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_GLOBAL_ORDER
					(record-base + schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) view/globals-ordinal
			]
			if global-symbol = previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_GLOBAL_DEFINITION
					(record-base + schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) view/globals-ordinal
			]
			previous-symbol: global-symbol
			if (symbol-value data view global-symbol schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				= schema/WIRE_LINKAGE_IMPORT
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_GLOBAL_DEFINITION
					(record-base + schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) view/globals-ordinal
			]
			source-location: global-value data view global-id
				schema/WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_GLOBAL_SOURCE_LOCATION
					(record-base + schema/WIRE_RSIR_GLOBAL_SOURCE_LOCATION_OFFSET)
					view/globals-ordinal
			]
			if (global-value data view global-id schema/WIRE_RSIR_GLOBAL_RESERVED_OFFSET) <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_GLOBAL_RESERVED
					(record-base + schema/WIRE_RSIR_GLOBAL_RESERVED_OFFSET)
					view/globals-ordinal
			]
			global-id: global-id + 1
		]

		previous-symbol: 0
		function-id: 1
		while [function-id <= view/function-count][
			record-base: record-offset function-result/view/functions-offset (function-id - 1)
				schema/WIRE_RSIR_FUNCTION_SIZE
			function-symbol: function-value data function-result/view function-id
				schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
			kind: symbol-value data view function-symbol schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			if kind <> schema/WIRE_SYMBOL_KIND_FUNCTION [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_FUNCTION_SYMBOL_KIND
					(record-base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					function-result/view/functions-ordinal
			]
			function-signature: function-value data function-result/view function-id
				schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET
			if function-signature <> symbol-value data view function-symbol
				schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_SIGNATURE_MISMATCH
					(record-base + schema/WIRE_RSIR_FUNCTION_SIGNATURE_OFFSET)
					function-result/view/functions-ordinal
			]
			if function-symbol < previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_FUNCTION_ORDER
					(record-base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					function-result/view/functions-ordinal
			]
			if function-symbol = previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_FUNCTION_DEFINITION
					(record-base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					function-result/view/functions-ordinal
			]
			previous-symbol: function-symbol
			if (symbol-value data view function-symbol schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				= schema/WIRE_LINKAGE_IMPORT
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORTED_FUNCTION_DEFINITION
					(record-base + schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET)
					function-result/view/functions-ordinal
			]
			function-id: function-id + 1
		]

		previous-symbol: 0
		import-id: 1
		while [import-id <= view/import-count][
			record-base: record-offset view/imports-offset (import-id - 1) schema/WIRE_IMPORT_SIZE
			library-string: import-value data view import-id schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
			if any [library-string <= 0 library-string > function-result/strings/record-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LIBRARY_ID
					(record-base + schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET) view/imports-ordinal
			]
			if zero? string-size-for-id data function-result/strings library-string [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_LIBRARY
					(record-base + schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET) view/imports-ordinal
			]
			external-name: import-value data view import-id
				schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > function-result/strings/record-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
					(record-base + schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/imports-ordinal
			]
			if zero? string-size-for-id data function-result/strings external-name [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
					(record-base + schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/imports-ordinal
			]
			symbol-id: import-value data view import-id schema/WIRE_IMPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > view/symbol-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL
					(record-base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			kind: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless find reduce [schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL] kind [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SYMBOL_KIND
					(record-base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			if (symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
				<> schema/WIRE_LINKAGE_IMPORT
			[
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_LINKAGE
					(record-base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			calling-convention: import-value data view import-id
				schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
			either kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
				symbol-signature: symbol-value data view symbol-id
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				signature-cc: signature-value data function-result/view symbol-signature
					schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
				if any [
					not find reduce [
						schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
						schema/WIRE_CALLING_CONVENTION_CDECL
						schema/WIRE_CALLING_CONVENTION_STDCALL
					]
						calling-convention
					calling-convention <> signature-cc
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_CALLING_CONVENTION
						(record-base + schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
						view/imports-ordinal
				]
			][
				if calling-convention <> 0 [
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_CALLING_CONVENTION
						(record-base + schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET)
						view/imports-ordinal
				]
			]
			if (import-value data view import-id schema/WIRE_IMPORT_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_IMPORT_FLAGS
					(record-base + schema/WIRE_IMPORT_FLAGS_OFFSET) view/imports-ordinal
			]
			source-location: import-value data view import-id schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET
			if source-location > source-count [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_IMPORT_SOURCE_LOCATION
					(record-base + schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET) view/imports-ordinal
			]
			if symbol-id < previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_IMPORT_ORDER
					(record-base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			if symbol-id = previous-symbol [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_IMPORT_SYMBOL
					(record-base + schema/WIRE_IMPORT_SYMBOL_OFFSET) view/imports-ordinal
			]
			previous-symbol: symbol-id
			import-id: import-id + 1
		]

		symbol-id: 1
		global-id: 1
		function-id: 1
		import-id: 1
		while [symbol-id <= view/symbol-count][
			kind: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			linkage: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			while [
				all [global-id <= view/global-count
					(global-value data view global-id schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) < symbol-id]
			][global-id: global-id + 1]
			while [
				all [function-id <= view/function-count
					(function-value data function-result/view function-id
						schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) < symbol-id]
			][function-id: function-id + 1]
			while [
				all [import-id <= view/import-count
					(import-value data view import-id schema/WIRE_IMPORT_SYMBOL_OFFSET) < symbol-id]
			][import-id: import-id + 1]
			case [
				linkage = schema/WIRE_LINKAGE_IMPORT [
					unless all [
						import-id <= view/import-count
						(import-value data view import-id schema/WIRE_IMPORT_SYMBOL_OFFSET) = symbol-id
					][
						record-base: record-offset view/symbols-offset (symbol-id - 1)
							schema/WIRE_RSIR_SYMBOL_SIZE
						return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_IMPORT
							(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
							view/symbols-ordinal
					]
				]
				all [kind = schema/WIRE_SYMBOL_KIND_GLOBAL requires-definition? linkage][
					unless all [
						global-id <= view/global-count
						(global-value data view global-id schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) = symbol-id
					][
						record-base: record-offset view/symbols-offset (symbol-id - 1)
							schema/WIRE_RSIR_SYMBOL_SIZE
						return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_GLOBAL_DEFINITION
							(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
							view/symbols-ordinal
					]
				]
				kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
					symbol-signature: symbol-value data view symbol-id
						schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
					calling-convention: signature-value data function-result/view symbol-signature
						schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
					either calling-convention = schema/WIRE_CALLING_CONVENTION_SYSCALL [
						if all [
							function-id <= view/function-count
							(function-value data function-result/view function-id
								schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = symbol-id
						][
							record-base: record-offset view/symbols-offset (symbol-id - 1)
								schema/WIRE_RSIR_SYMBOL_SIZE
							return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_SYSCALL_DECLARATION
								(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
								view/symbols-ordinal
						]
					][if requires-definition? linkage [
						unless all [
							function-id <= view/function-count
							(function-value data function-result/view function-id
								schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = symbol-id
						][
							record-base: record-offset view/symbols-offset (symbol-id - 1)
								schema/WIRE_RSIR_SYMBOL_SIZE
							return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_FUNCTION_DEFINITION
								(record-base + schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET)
								view/symbols-ordinal
						]
					]]
				]
			]
			symbol-id: symbol-id + 1
		]

		previous-name: 0
		if all [
			view/export-count > 0
			view/image-kind <> schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
		][
			return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_IMAGE_KIND
				view/exports-offset view/exports-ordinal
		]
		export-id: 1
		while [export-id <= view/export-count][
			record-base: record-offset view/exports-offset (export-id - 1) schema/WIRE_EXPORT_SIZE
			external-name: export-value data view export-id
				schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
			if any [external-name <= 0 external-name > function-result/strings/record-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
					(record-base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			if zero? string-size-for-id data function-result/strings external-name [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
					(record-base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			symbol-id: export-value data view export-id schema/WIRE_EXPORT_SYMBOL_OFFSET
			if any [symbol-id <= 0 symbol-id > view/symbol-count][
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL
					(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			kind: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_KIND_OFFSET
			unless find reduce [schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_KIND_GLOBAL] kind [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SYMBOL_KIND
					(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			if external-name < previous-name [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_EXPORT_ORDER
					(record-base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			if external-name = previous-name [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_DUPLICATE_EXPORT_NAME
					(record-base + schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET)
					view/exports-ordinal
			]
			previous-name: external-name
			ordinal: export-value data view export-id schema/WIRE_EXPORT_ORDINAL_OFFSET
			if ordinal <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_ORDINAL
					(record-base + schema/WIRE_EXPORT_ORDINAL_OFFSET) view/exports-ordinal
			]
			if (export-value data view export-id schema/WIRE_EXPORT_FLAGS_OFFSET) <> 0 [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_NONZERO_EXPORT_FLAGS
					(record-base + schema/WIRE_EXPORT_FLAGS_OFFSET) view/exports-ordinal
			]
			linkage: symbol-value data view symbol-id schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
			if linkage <> schema/WIRE_LINKAGE_EXTERNAL [
				return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_LINKAGE
					(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
			]
			either kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
				definition-id: 1
				while [all [
					definition-id <= view/function-count
					(function-value data function-result/view definition-id
						schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) < symbol-id
				]][definition-id: definition-id + 1]
				unless all [
					definition-id <= view/function-count
					(function-value data function-result/view definition-id
						schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET) = symbol-id
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_EXPORT_DEFINITION
						(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
				]
				symbol-signature: symbol-value data view symbol-id
					schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET
				calling-convention: signature-value data function-result/view symbol-signature
					schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET
				flags: signature-value data function-result/view symbol-signature
					schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET
				unless any [
					all [
						find reduce [
							schema/WIRE_CALLING_CONVENTION_CDECL
							schema/WIRE_CALLING_CONVENTION_STDCALL
						] calling-convention
						(flags and schema/WIRE_FUNCTION_FLAG_CALLBACK) <> 0
					]
					all [
						calling-convention = schema/WIRE_CALLING_CONVENTION_RED_SYSTEM
						(flags and schema/WIRE_FUNCTION_FLAG_CALLBACK) = 0
						module-kind = schema/WIRE_MODULE_KIND_RUNTIME
					]
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_EXPORT_SIGNATURE
						(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
				]
			][
				definition-id: 1
				while [all [
					definition-id <= view/global-count
					(global-value data view definition-id schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) < symbol-id
				]][definition-id: definition-id + 1]
				unless all [
					definition-id <= view/global-count
					(global-value data view definition-id schema/WIRE_RSIR_GLOBAL_SYMBOL_OFFSET) = symbol-id
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_MISSING_EXPORT_DEFINITION
						(record-base + schema/WIRE_EXPORT_SYMBOL_OFFSET) view/exports-ordinal
				]
			]
			export-id: export-id + 1
		]

		foreach lifecycle-offset reduce [
			schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET
			schema/WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET
			schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET
		][
			module-ref: module-value data module-result/view lifecycle-offset
			if module-ref <> 0 [
				function-symbol: function-value data function-result/view module-ref
					schema/WIRE_RSIR_FUNCTION_SYMBOL_OFFSET
				symbol-linkage: symbol-value data view function-symbol
					schema/WIRE_RSIR_SYMBOL_LINKAGE_OFFSET
				if any [
					symbol-linkage = schema/WIRE_LINKAGE_IMPORT
					symbol-linkage = schema/WIRE_LINKAGE_WEAK
					not definition-linkage? symbol-linkage
				][
					return reject result schema/WIRE_SYMBOL_LINKAGE_ERROR_BAD_LIFECYCLE_FUNCTION
						(module-result/view/modules-offset + lifecycle-offset)
						module-result/view/modules-ordinal
				]
			]
		]

		result/strings: function-result/strings
		result/files: function-result/files
		result/layout: function-result/layout
		result/types: function-result/types
		result/functions: function-result/view
		result/modules: module-result/view
		result/view: view
		result/valid?: true
		result
	]
]
