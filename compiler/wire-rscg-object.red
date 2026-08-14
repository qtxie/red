Red [
	Title: "Hybrid compiler RSCG object-layout verifier"
	File:  %wire-rscg-object.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-data-layout [do %wire-data-layout.red]
unless value? 'compiler-wire-module-lifecycle [do %wire-module-lifecycle.red]

compiler-wire-rscg-object: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	layout-verifier: compiler-wire-data-layout
	module-verifier: compiler-wire-module-lifecycle

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED
	expected-symbol-flags: schema/WIRE_SECTION_FLAG_SORTED
	max-section-alignment: 4096
	exec-image-size: 40

	make-view: does [
		make object! [
			output-sections-offset: 0
			output-section-count: 0
			output-sections-ordinal: 0
			output-data-offset: 0
			output-data-size: 0
			output-data-ordinal: 0
			symbols-offset: 0
			symbol-count: 0
			symbols-ordinal: 0
			functions-offset: 0
			function-count: 0
			functions-ordinal: 0
			debug-line-count: 0
			debug-parameter-count: 0
			runtime-module: 0
			exec-image-symbol: 0
			bitmap-symbol: 0
			lib-image-symbol: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
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

	output-section-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/output-sections-offset
			schema/WIRE_RSCG_OUTPUT_SECTION_SIZE id field
	]

	symbol-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/symbols-offset schema/WIRE_RSCG_SYMBOL_SIZE id field
	]

	function-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/functions-offset schema/WIRE_RSCG_FUNCTION_SIZE id field
	]

	module-value: func [data [binary!] modules [object!] id field [integer!]][
		record-value data modules/modules-offset schema/WIRE_RSCG_MODULE_SIZE id field
	]

	string-size-for-id: func [data [binary!] strings [object!] id [integer!]][
		if any [id <= 0 id > strings/record-count][return none]
		container/read-i31 data (strings/records-offset
			+ (((id - 1) * schema/WIRE_STRING_SIZE)
			+ schema/WIRE_STRING_SIZE_OFFSET))
	]

	string-equals-ascii?: func [
		data [binary!] strings [object!] id [integer!] expected [string!]
		/local record-offset string-offset string-size index
	][
		if any [id <= 0 id > strings/record-count][return false]
		record-offset: strings/records-offset + ((id - 1) * schema/WIRE_STRING_SIZE)
		string-offset: container/read-i31 data
			(record-offset + schema/WIRE_STRING_OFFSET_OFFSET)
		string-size: container/read-i31 data
			(record-offset + schema/WIRE_STRING_SIZE_OFFSET)
		if string-size <> length? expected [return false]
		index: 0
		while [index < string-size][
			if (to integer! pick data (strings/data-offset + string-offset + index + 1))
				<> to integer! pick expected (index + 1)
			[return false]
			index: index + 1
		]
		true
	]

	canonical-range?: func [first count total [integer!]][
		either zero? count [
			zero? first
		][
			all [
				first > 0
				(first - 1) <= total
				count <= (total - (first - 1))
			]
		]
	]

	symbol-defined?: func [data [binary!] view [object!] id [integer!]][
		all [
			(symbol-value data view id schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = 0
			(symbol-value data view id schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) > 0
		]
	]

	find-role-symbols: func [
		data [binary!] strings [object!] view [object!] expected [string!]
		/local id name result
	][
		result: copy []
		id: 1
		while [id <= view/symbol-count][
			name: symbol-value data view id schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
			if string-equals-ascii? data strings name expected [append result id]
			id: id + 1
		]
		result
	]

	role-shape?: func [
		data [binary!] view [object!] id runtime-module expected-size expected-alignment [integer!]
		/local kind binding visibility section offset size alignment flags class
	][
		kind: symbol-value data view id schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
		binding: symbol-value data view id schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
		visibility: symbol-value data view id schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
		section: symbol-value data view id schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		offset: symbol-value data view id schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		size: symbol-value data view id schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
		alignment: symbol-value data view id schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
		flags: symbol-value data view id schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
		if any [section <= 0 section > view/output-section-count][return false]
		class: output-section-value data view section schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
		all [
			kind = schema/WIRE_SYMBOL_KIND_GLOBAL
			binding = schema/WIRE_SYMBOL_BINDING_LOCAL
			visibility = schema/WIRE_VISIBILITY_HIDDEN
			flags = 0
			(symbol-value data view id schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
				= runtime-module
			class = schema/WIRE_OUTPUT_SECTION_CLASS_DATA
			size = expected-size
			alignment = expected-alignment
			zero? offset // alignment
		]
	]

	verify: func [
		data
		/local result container-result module-result layout-result output-sections
			output-data symbols functions debug-lines debug-parameters view section
			record-index record-base field-name field-offset value name-string class flags
			alignment data-offset file-size memory-size reserved cursor previous-class
			previous-name prior-id prior-name symbol-id kind binding visibility
			output-section section-offset symbol-size origin prior-binding prior-origin
			prior-section prior-offset prior-size section-class section-memory
			function-id function-symbol code-section code-offset code-size frame-size
			first-line line-count first-parameter parameter-count previous-code-section
			previous-code-offset previous-code-end found? module-id module-kind runtime-module
			lifecycle-offset lifecycle-symbol role-ids role-id role-section role-offset
			role-size role-data-base header-offset image-kind
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_ARGUMENTS 0 0
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSCG
		result/header: container-result/header
		unless container-result/valid? [
			result/container-error: container-result/error
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
				container-result/error-offset container-result/error-section
		]

		module-result: module-verifier/verify data schema/WIRE_MAGIC_RSCG
		unless module-result/valid? [
			result/container-error: module-result/container-error
			result/string-error: module-result/string-error
			result/file-source-error: module-result/file-source-error
			result/module-lifecycle-error: module-result/error
			case [
				module-result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
						module-result/error-offset module-result/error-section
				]
				module-result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_STRINGS
						module-result/error-offset module-result/error-section
				]
				module-result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_FILE_SOURCE
						module-result/error-offset module-result/error-section
				]
				true [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_MODULE_LIFECYCLE
						module-result/error-offset module-result/error-section
				]
			]
		]

		layout-result: layout-verifier/verify data schema/WIRE_MAGIC_RSCG
		unless layout-result/valid? [
			result/container-error: layout-result/container-error
			result/data-layout-error: layout-result/error
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_INVALID_DATA_LAYOUT
				layout-result/error-offset layout-result/error-section
		]

		output-sections: container/find-section container-result
			schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
		output-data: container/find-section container-result schema/WIRE_RSCG_SECTION_OUTPUT_DATA
		symbols: container/find-section container-result schema/WIRE_RSCG_SECTION_SYMBOLS
		functions: container/find-section container-result schema/WIRE_RSCG_SECTION_FUNCTIONS
		debug-lines: container/find-section container-result schema/WIRE_RSCG_SECTION_DEBUG_LINES
		debug-parameters: container/find-section container-result
			schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS

		if (select output-sections 'flags) <> expected-index-flags [
			return reject result
				schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_SECTION_FLAGS
				section-flags-offset output-sections (select output-sections 'ordinal)
		]
		if (select output-data 'flags) <> 0 [
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_DATA_SECTION_FLAGS
				section-flags-offset output-data (select output-data 'ordinal)
		]
		if (select symbols 'flags) <> expected-symbol-flags [
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_FLAGS
				section-flags-offset symbols (select symbols 'ordinal)
		]
		if (select functions 'flags) <> expected-index-flags [
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION_FLAGS
				section-flags-offset functions (select functions 'ordinal)
		]

		view: make-view
		view/output-sections-offset: select output-sections 'payload-offset
		view/output-section-count: select output-sections 'record-count
		view/output-sections-ordinal: select output-sections 'ordinal
		view/output-data-offset: select output-data 'payload-offset
		view/output-data-size: select output-data 'payload-size
		view/output-data-ordinal: select output-data 'ordinal
		view/symbols-offset: select symbols 'payload-offset
		view/symbol-count: select symbols 'record-count
		view/symbols-ordinal: select symbols 'ordinal
		view/functions-offset: select functions 'payload-offset
		view/function-count: select functions 'record-count
		view/functions-ordinal: select functions 'ordinal
		view/debug-line-count: select debug-lines 'record-count
		view/debug-parameter-count: select debug-parameters 'record-count

		; Every object-layout scalar is nonnegative i31 before references are followed.
		foreach section reduce [output-sections symbols functions][
			record-index: 0
			while [record-index < (select section 'record-count)][
				record-base: (select section 'payload-offset)
					+ (record-index * (select section 'record-size))
				field-offset: 0
				while [field-offset < (select section 'record-size)][
					value: container/read-i31 data (record-base + field-offset)
					if none? value [
						return reject result schema/WIRE_RSCG_OBJECT_ERROR_SCALAR_RANGE
							(record-base + field-offset) (select section 'ordinal)
					]
					field-offset: field-offset + 4
				]
				record-index: record-index + 1
			]
		]

		cursor: 0
		previous-class: 0
		previous-name: 0
		record-index: 0
		while [record-index < view/output-section-count][
			record-base: view/output-sections-offset
				+ (record-index * schema/WIRE_RSCG_OUTPUT_SECTION_SIZE)
			name-string: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
			class: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
			flags: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
			alignment: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
			data-offset: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
			file-size: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
			memory-size: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
			reserved: container/read-i31 data
				(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET)

			if any [name-string <= 0 name-string > module-result/strings/record-count][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_NAME_ID
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
					view/output-sections-ordinal
			]
			if zero? string-size-for-id data module-result/strings name-string [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_EMPTY_OUTPUT_SECTION_NAME
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
					view/output-sections-ordinal
			]
			if any [class < schema/WIRE_OUTPUT_SECTION_CLASS_CODE
				class > schema/WIRE_OUTPUT_SECTION_CLASS_PLATFORM]
			[
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_CLASS
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
					view/output-sections-ordinal
			]
			if class = schema/WIRE_OUTPUT_SECTION_CLASS_PLATFORM [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_UNSUPPORTED_PLATFORM_SECTION
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
					view/output-sections-ordinal
			]
			if flags <> schema/WIRE_RSCG_OUTPUT_SECTION_FLAG_NONE [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FLAGS
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
					view/output-sections-ordinal
			]
			unless all [
				alignment <= max-section-alignment
				container/power-of-two? alignment
			][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_ALIGNMENT
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
					view/output-sections-ordinal
			]
			if zero? memory-size [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_MEMORY_SIZE
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
					view/output-sections-ordinal
			]
			if reserved <> 0 [
				return reject result
					schema/WIRE_RSCG_OBJECT_ERROR_NONZERO_OUTPUT_SECTION_RESERVED
					(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET)
					view/output-sections-ordinal
			]
			if record-index > 0 [
				if any [class < previous-class
					all [class = previous-class name-string <= previous-name]]
				[
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_OUTPUT_SECTION_ORDER
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
						view/output-sections-ordinal
				]
			]
			prior-id: 1
			while [prior-id <= record-index][
				prior-name: output-section-value data view prior-id
					schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
				if prior-name = name-string [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_OUTPUT_SECTION_NAME
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
						view/output-sections-ordinal
				]
				prior-id: prior-id + 1
			]
			either class = schema/WIRE_OUTPUT_SECTION_CLASS_BSS [
				if any [data-offset <> 0 file-size <> 0][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_BSS_SHAPE
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
						view/output-sections-ordinal
				]
			][
				if file-size = 0 [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FILE_SIZE
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
						view/output-sections-ordinal
				]
				if memory-size <> file-size [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_INITIALIZED_SECTION_SHAPE
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
						view/output-sections-ordinal
				]
				if data-offset <> cursor [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_DATA_OFFSET
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
						view/output-sections-ordinal
				]
				if file-size > (view/output-data-size - cursor) [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FILE_SIZE
						(record-base + schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
						view/output-sections-ordinal
				]
				cursor: cursor + file-size
			]
			previous-class: class
			previous-name: name-string
			record-index: record-index + 1
		]
		if cursor <> view/output-data-size [
			return reject result schema/WIRE_RSCG_OBJECT_ERROR_OUTPUT_DATA_COVERAGE
				(view/output-data-offset + cursor) view/output-data-ordinal
		]

		previous-name: 0
		prior-binding: 0
		prior-origin: 0
		symbol-id: 1
		while [symbol-id <= view/symbol-count][
			record-base: view/symbols-offset
				+ ((symbol-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
			name-string: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
			kind: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
			binding: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
			visibility: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
			output-section: symbol-value data view symbol-id
				schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
			section-offset: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
			symbol-size: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
			alignment: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
			flags: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
			origin: symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET

			if any [name-string <= 0 name-string > module-result/strings/record-count][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_NAME_ID
					(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			if zero? string-size-for-id data module-result/strings name-string [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_EMPTY_SYMBOL_NAME
					(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
					view/symbols-ordinal
			]
			unless all [kind >= schema/WIRE_SYMBOL_KIND_FUNCTION
				kind <= schema/WIRE_SYMBOL_KIND_CONSTANT]
			[
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_KIND
					(record-base + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET) view/symbols-ordinal
			]
			unless all [binding >= schema/WIRE_SYMBOL_BINDING_LOCAL
				binding <= schema/WIRE_SYMBOL_BINDING_WEAK]
			[
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING
					(record-base + schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET) view/symbols-ordinal
			]
			unless any [visibility = schema/WIRE_VISIBILITY_DEFAULT
				visibility = schema/WIRE_VISIBILITY_HIDDEN]
			[
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_VISIBILITY
					(record-base + schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET) view/symbols-ordinal
			]
			unless either binding = schema/WIRE_SYMBOL_BINDING_LOCAL [
				visibility = schema/WIRE_VISIBILITY_HIDDEN
			][visibility = schema/WIRE_VISIBILITY_DEFAULT][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING_VISIBILITY
					(record-base + schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET) view/symbols-ordinal
			]
			unless any [flags = 0 flags = schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_FLAGS
					(record-base + schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET) view/symbols-ordinal
			]
			if symbol-id > 1 [
				if any [
					name-string < previous-name
					all [name-string = previous-name binding < prior-binding]
					all [name-string = previous-name binding = prior-binding origin < prior-origin]
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_SYMBOL_ORDER
						(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
						view/symbols-ordinal
				]
			]
			prior-id: 1
			while [prior-id < symbol-id][
				prior-name: symbol-value data view prior-id schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
				if prior-name = name-string [
					prior-binding: symbol-value data view prior-id schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
					prior-origin: symbol-value data view prior-id schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET
					if any [
						all [binding = schema/WIRE_SYMBOL_BINDING_LOCAL
							prior-binding = schema/WIRE_SYMBOL_BINDING_LOCAL origin = prior-origin]
						all [binding <> schema/WIRE_SYMBOL_BINDING_LOCAL
							prior-binding <> schema/WIRE_SYMBOL_BINDING_LOCAL]
					][
						return reject result schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_SYMBOL
							(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
							view/symbols-ordinal
					]
				]
				prior-id: prior-id + 1
			]

			either flags = schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED [
				unless all [
					binding <> schema/WIRE_SYMBOL_BINDING_LOCAL
					output-section = 0
					section-offset = 0
					symbol-size = 0
					alignment = 0
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_DEFINITION_SHAPE
						(record-base + schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
						view/symbols-ordinal
				]
			][
				if any [output-section <= 0 output-section > view/output-section-count][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_OUTPUT_SECTION
						(record-base + schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
						view/symbols-ordinal
				]
				section-class: output-section-value data view output-section
					schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
				section-memory: output-section-value data view output-section
					schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
				unless all [
					alignment <= (output-section-value data view output-section
						schema/WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
					container/power-of-two? alignment
					zero? section-offset // alignment
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_ALIGNMENT
						(record-base + schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET)
						view/symbols-ordinal
				]
				unless all [
					section-offset <= section-memory
					symbol-size <= (section-memory - section-offset)
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_EXTENT
						(record-base + schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
						view/symbols-ordinal
				]
				unless case [
					kind = schema/WIRE_SYMBOL_KIND_FUNCTION [
						section-class = schema/WIRE_OUTPUT_SECTION_CLASS_CODE
					]
					kind = schema/WIRE_SYMBOL_KIND_GLOBAL [
						any [section-class = schema/WIRE_OUTPUT_SECTION_CLASS_DATA
							section-class = schema/WIRE_OUTPUT_SECTION_CLASS_BSS]
					]
					kind = schema/WIRE_SYMBOL_KIND_CONSTANT [
						section-class = schema/WIRE_OUTPUT_SECTION_CLASS_RODATA
					]
					true [false]
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_CLASS
						(record-base + schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
						view/symbols-ordinal
				]
				if symbol-size > 0 [
					prior-id: 1
					while [prior-id < symbol-id][
						if symbol-defined? data view prior-id [
							prior-section: symbol-value data view prior-id
								schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
							prior-offset: symbol-value data view prior-id
								schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
							prior-size: symbol-value data view prior-id schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
							if all [
								prior-size > 0
								prior-section = output-section
								section-offset < (prior-offset + prior-size)
								prior-offset < (section-offset + symbol-size)
							][
								return reject result schema/WIRE_RSCG_OBJECT_ERROR_SYMBOL_OVERLAP
									(record-base + schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
									view/symbols-ordinal
							]
						]
						prior-id: prior-id + 1
					]
				]
			]
			previous-name: name-string
			prior-binding: binding
			prior-origin: origin
			symbol-id: symbol-id + 1
		]

		previous-code-section: 0
		previous-code-offset: 0
		previous-code-end: 0
		function-id: 1
		while [function-id <= view/function-count][
			record-base: view/functions-offset
				+ ((function-id - 1) * schema/WIRE_RSCG_FUNCTION_SIZE)
			function-symbol: function-value data view function-id schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
			code-section: function-value data view function-id schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
			code-offset: function-value data view function-id schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
			code-size: function-value data view function-id schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
			frame-size: function-value data view function-id schema/WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET
			flags: function-value data view function-id schema/WIRE_RSCG_FUNCTION_FLAGS_OFFSET
			first-line: function-value data view function-id
				schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
			line-count: function-value data view function-id
				schema/WIRE_RSCG_FUNCTION_DEBUG_LINE_COUNT_OFFSET
			first-parameter: function-value data view function-id
				schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
			parameter-count: function-value data view function-id
				schema/WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET

			if any [function-symbol <= 0 function-symbol > view/symbol-count][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SYMBOL
					(record-base + schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) view/functions-ordinal
			]
			prior-id: 1
			while [prior-id < function-id][
				if (function-value data view prior-id schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET)
					= function-symbol
				[
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_FUNCTION_SYMBOL
						(record-base + schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET)
						view/functions-ordinal
				]
				prior-id: prior-id + 1
			]
			if any [code-section <= 0 code-section > view/output-section-count][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION
					(record-base + schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET)
					view/functions-ordinal
			]
			if (output-section-value data view code-section
				schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
				<> schema/WIRE_OUTPUT_SECTION_CLASS_CODE
			[
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION
					(record-base + schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET)
					view/functions-ordinal
			]
			unless all [
				symbol-defined? data view function-symbol
				(symbol-value data view function-symbol schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
					= schema/WIRE_SYMBOL_KIND_FUNCTION
				(symbol-value data view function-symbol schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
					= code-section
				(symbol-value data view function-symbol schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
					= code-offset
				(symbol-value data view function-symbol schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET)
					= code-size
			][
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_FUNCTION_SYMBOL_MISMATCH
					(record-base + schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) view/functions-ordinal
			]
			if zero? code-size [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_EXTENT
					(record-base + schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET) view/functions-ordinal
			]
			if function-id > 1 [
				if any [
					code-section < previous-code-section
					all [code-section = previous-code-section code-offset < previous-code-offset]
				][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_FUNCTION_ORDER
						(record-base + schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET)
						view/functions-ordinal
				]
				if all [code-section = previous-code-section code-offset < previous-code-end][
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_EXTENT
						(record-base + schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET)
						view/functions-ordinal
				]
			]
			if not zero? frame-size // 8 [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FRAME_SIZE
					(record-base + schema/WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET)
					view/functions-ordinal
			]
			if flags <> schema/WIRE_RSCG_FUNCTION_FLAG_NONE [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FLAGS
					(record-base + schema/WIRE_RSCG_FUNCTION_FLAGS_OFFSET) view/functions-ordinal
			]
			unless canonical-range? first-line line-count view/debug-line-count [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
					(record-base + schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET)
					view/functions-ordinal
			]
			unless canonical-range? first-parameter parameter-count view/debug-parameter-count [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
					(record-base + schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET)
					view/functions-ordinal
			]
			previous-code-section: code-section
			previous-code-offset: code-offset
			previous-code-end: code-offset + code-size
			function-id: function-id + 1
		]

		symbol-id: 1
		while [symbol-id <= view/symbol-count][
			if all [
				symbol-defined? data view symbol-id
				(symbol-value data view symbol-id schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
					= schema/WIRE_SYMBOL_KIND_FUNCTION
			][
				found?: false
				function-id: 1
				while [function-id <= view/function-count][
					if (function-value data view function-id schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET)
						= symbol-id [found?: true break]
					function-id: function-id + 1
				]
				unless found? [
					record-base: view/symbols-offset
						+ ((symbol-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_MISSING_FUNCTION_RECORD
						(record-base + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET) view/symbols-ordinal
				]
			]
			symbol-id: symbol-id + 1
		]

		module-id: 1
		while [module-id <= module-result/view/module-count][
			foreach lifecycle-offset reduce [
				schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
				schema/WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET
				schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
			][
				lifecycle-symbol: module-value data module-result/view module-id lifecycle-offset
				if lifecycle-symbol <> 0 [
					unless all [
						symbol-defined? data view lifecycle-symbol
						(symbol-value data view lifecycle-symbol schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
							= schema/WIRE_SYMBOL_KIND_FUNCTION
					][
						record-base: module-result/view/modules-offset
							+ ((module-id - 1) * schema/WIRE_RSCG_MODULE_SIZE)
						return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_LIFECYCLE_SYMBOL
							(record-base + lifecycle-offset) module-result/view/modules-ordinal
					]
				]
			]
			module-id: module-id + 1
		]

		runtime-module: 0
		module-id: 1
		while [module-id <= module-result/view/module-count][
			module-kind: module-value data module-result/view module-id
				schema/WIRE_RSCG_MODULE_KIND_OFFSET
			if module-kind = schema/WIRE_MODULE_KIND_RUNTIME [
				if runtime-module <> 0 [
					record-base: module-result/view/modules-offset
						+ ((module-id - 1) * schema/WIRE_RSCG_MODULE_SIZE)
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_RUNTIME_MODULE_COUNT
						(record-base + schema/WIRE_RSCG_MODULE_KIND_OFFSET)
						module-result/view/modules-ordinal
				]
				runtime-module: module-id
			]
			module-id: module-id + 1
		]
		view/runtime-module: runtime-module

		if runtime-module <> 0 [
			role-ids: find-role-symbols data module-result/strings view "***-exec-image"
			if empty? role-ids [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_MISSING_EXEC_IMAGE_ROLE
					view/symbols-offset view/symbols-ordinal
			]
			if (length? role-ids) <> 1 [
				role-id: second role-ids
				record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_EXEC_IMAGE_ROLE
					(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) view/symbols-ordinal
			]
			role-id: first role-ids
			unless role-shape? data view role-id runtime-module exec-image-size 8 [
				record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_EXEC_IMAGE_ROLE
					(record-base + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET) view/symbols-ordinal
			]
			view/exec-image-symbol: role-id

			role-ids: find-role-symbols data module-result/strings view "***-ptr-bitmaps"
			if empty? role-ids [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_MISSING_BITMAP_ROLE
					view/symbols-offset view/symbols-ordinal
			]
			if (length? role-ids) <> 1 [
				role-id: second role-ids
				record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_ROLE
					(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) view/symbols-ordinal
			]
			role-id: first role-ids
			role-section: symbol-value data view role-id schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
			role-offset: symbol-value data view role-id schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
			role-size: symbol-value data view role-id schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
			unless all [
				role-shape? data view role-id runtime-module role-size 4
				role-size > 0
				zero? role-size // 4
				role-offset >= 4
			][
				record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_ROLE
					(record-base + schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET) view/symbols-ordinal
			]
			role-data-base: output-section-value data view role-section
				schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
			header-offset: view/output-data-offset + role-data-base + role-offset - 4
			if not none? container/first-nonzero data header-offset (header-offset + 4) [
				return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_HEADER
					header-offset view/output-data-ordinal
			]
			view/bitmap-symbol: role-id

			image-kind: module-result/view/image-kind
			if image-kind = schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY [
				role-ids: find-role-symbols data module-result/strings view "***-lib-image"
				if empty? role-ids [
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_MISSING_LIB_IMAGE_ROLE
						view/symbols-offset view/symbols-ordinal
				]
				if (length? role-ids) <> 1 [
					role-id: second role-ids
					record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_LIB_IMAGE_ROLE
						(record-base + schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
						view/symbols-ordinal
				]
				role-id: first role-ids
				unless role-shape? data view role-id runtime-module exec-image-size 8 [
					record-base: view/symbols-offset + ((role-id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
					return reject result schema/WIRE_RSCG_OBJECT_ERROR_BAD_LIB_IMAGE_ROLE
						(record-base + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET) view/symbols-ordinal
				]
				view/lib-image-symbol: role-id
			]
		]

		result/strings: module-result/strings
		result/files: module-result/files
		result/layout: layout-result/layout
		result/modules: module-result/view
		result/view: view
		result/valid?: true
		result
	]
]
