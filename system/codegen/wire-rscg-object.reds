Red/System [
	Title: "Hybrid compiler native RSCG object-layout verifier"
	File:  %wire-rscg-object.reds
]

#include %wire-data-layout.reds
#include %wire-module-lifecycle.reds

wire-rscg-object-result!: alias struct! [
	error                  [integer!]
	container-error        [integer!]
	string-error           [integer!]
	file-source-error      [integer!]
	data-layout-error      [integer!]
	module-lifecycle-error [integer!]
	error-offset           [integer!]
	error-section          [integer!]
]

wire-rscg-object!: alias struct! [
	output-sections        [byte-ptr!]
	output-section-count   [integer!]
	output-section-size    [integer!]
	output-sections-offset [integer!]
	output-sections-ordinal [integer!]
	output-data            [byte-ptr!]
	output-data-size       [integer!]
	output-data-offset     [integer!]
	output-data-ordinal    [integer!]
	symbols                [byte-ptr!]
	symbol-count           [integer!]
	symbol-size            [integer!]
	symbols-offset         [integer!]
	symbols-ordinal        [integer!]
	functions              [byte-ptr!]
	function-count         [integer!]
	function-size          [integer!]
	functions-offset       [integer!]
	functions-ordinal     [integer!]
	debug-line-count       [integer!]
	debug-parameter-count  [integer!]
	runtime-module         [integer!]
	exec-image-symbol      [integer!]
	bitmap-symbol          [integer!]
	lib-image-symbol       [integer!]
]

wire-rscg-object-reader: context [
	expected-index-flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED
	expected-symbol-flags: WIRE_SECTION_FLAG_SORTED
	max-section-alignment: 4096
	exec-image-size: 40

	set-error: func [
		result [wire-rscg-object-result!]
		code offset section [integer!]
		return: [integer!]
	][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		code
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

	copy-view: func [destination source [wire-rscg-object!]][
		destination/output-sections: source/output-sections
		destination/output-section-count: source/output-section-count
		destination/output-section-size: source/output-section-size
		destination/output-sections-offset: source/output-sections-offset
		destination/output-sections-ordinal: source/output-sections-ordinal
		destination/output-data: source/output-data
		destination/output-data-size: source/output-data-size
		destination/output-data-offset: source/output-data-offset
		destination/output-data-ordinal: source/output-data-ordinal
		destination/symbols: source/symbols
		destination/symbol-count: source/symbol-count
		destination/symbol-size: source/symbol-size
		destination/symbols-offset: source/symbols-offset
		destination/symbols-ordinal: source/symbols-ordinal
		destination/functions: source/functions
		destination/function-count: source/function-count
		destination/function-size: source/function-size
		destination/functions-offset: source/functions-offset
		destination/functions-ordinal: source/functions-ordinal
		destination/debug-line-count: source/debug-line-count
		destination/debug-parameter-count: source/debug-parameter-count
		destination/runtime-module: source/runtime-module
		destination/exec-image-symbol: source/exec-image-symbol
		destination/bitmap-symbol: source/bitmap-symbol
		destination/lib-image-symbol: source/lib-image-symbol
	]

	section-flags-offset: func [section [wire-section-slice!] return: [integer!]][
		WIRE_HEADER_SIZE + (((section/ordinal - 1) * WIRE_DIRECTORY_SIZE)
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

	output-value: func [view [wire-rscg-object!] id field [integer!] return: [integer!]][
		wire-container-reader/read-i31 view/output-sections
			(((id - 1) * WIRE_RSCG_OUTPUT_SECTION_SIZE) + field)
	]

	symbol-value: func [view [wire-rscg-object!] id field [integer!] return: [integer!]][
		wire-container-reader/read-i31 view/symbols
			(((id - 1) * WIRE_RSCG_SYMBOL_SIZE) + field)
	]

	function-value: func [view [wire-rscg-object!] id field [integer!] return: [integer!]][
		wire-container-reader/read-i31 view/functions
			(((id - 1) * WIRE_RSCG_FUNCTION_SIZE) + field)
	]

	module-value: func [modules [wire-module-lifecycle!] id field [integer!] return: [integer!]][
		wire-container-reader/read-i31 modules/modules
			(((id - 1) * modules/module-record-size) + field)
	]

	string-size-for-id: func [strings [wire-string-table!] id [integer!] return: [integer!]][
		if any [id <= 0 id > strings/record-count][return -1]
		wire-container-reader/read-i31 strings/records
			(((id - 1) * WIRE_STRING_SIZE) + WIRE_STRING_SIZE_OFFSET)
	]

	ascii-equals?: func [
		strings [wire-string-table!]
		id [integer!]
		expected [byte-ptr!]
		expected-size [integer!]
		return: [logic!]
		/local slice [wire-string-slice!] left right [byte-ptr!] index [integer!]
	][
		slice: declare wire-string-slice!
		unless wire-string-table-reader/get-slice strings id slice [return false]
		unless slice/size = expected-size [return false]
		left: slice/data
		right: expected
		index: 0
		while [index < expected-size][
			if left/1 <> right/1 [return false]
			left: left + 1
			right: right + 1
			index: index + 1
		]
		true
	]

canonical-range?: func [first count total [integer!] return: [logic!]][
		either count = 0 [
			first = 0
		][
			all [first > 0 (first - 1) <= total count <= (total - (first - 1))]
		]
	]

symbol-defined?: func [view [wire-rscg-object!] id [integer!] return: [logic!]][
		all [
			(symbol-value view id WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = 0
			(symbol-value view id WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) > 0
		]
	]

count-role: func [
	strings [wire-string-table!]
	view [wire-rscg-object!]
	name [byte-ptr!]
	name-size [integer!]
	return: [integer!]
	/local id count [integer!]
	][
		count: 0
		id: 1
		while [id <= view/symbol-count][
			if ascii-equals? strings
				(symbol-value view id WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) name name-size
			[
				count: count + 1
			]
			id: id + 1
		]
		count
	]

first-role: func [
	strings [wire-string-table!]
	view [wire-rscg-object!]
	name [byte-ptr!]
	name-size [integer!]
	return: [integer!]
	/local id [integer!]
	][
		id: 1
		while [id <= view/symbol-count][
			if ascii-equals? strings
				(symbol-value view id WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) name name-size
			[return id]
			id: id + 1
		]
		0
	]

role-shape?: func [
	view [wire-rscg-object!]
	id runtime-module expected-size expected-alignment [integer!]
	return: [logic!]
	/local section class [integer!]
	][
		section: symbol-value view id WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		if any [section <= 0 section > view/output-section-count][return false]
		class: output-value view section WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
		all [
			(symbol-value view id WIRE_RSCG_SYMBOL_KIND_OFFSET) = WIRE_SYMBOL_KIND_GLOBAL
			(symbol-value view id WIRE_RSCG_SYMBOL_BINDING_OFFSET) = WIRE_SYMBOL_BINDING_LOCAL
			(symbol-value view id WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET) = WIRE_VISIBILITY_HIDDEN
			(symbol-value view id WIRE_RSCG_SYMBOL_FLAGS_OFFSET) = 0
			(symbol-value view id WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET) = runtime-module
			class = WIRE_OUTPUT_SECTION_CLASS_DATA
			(symbol-value view id WIRE_RSCG_SYMBOL_SIZE_OFFSET) = expected-size
			(symbol-value view id WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET) = expected-alignment
			zero? ((symbol-value view id WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
				// expected-alignment)
		]
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-rscg-object-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		modules [wire-module-lifecycle!]
		output-view [wire-rscg-object!]
		return: [integer!]
		/local container [wire-container-result!]
			module-result [wire-module-lifecycle-result!]
			layout-result [wire-data-layout-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-modules [wire-module-lifecycle!]
			view [wire-rscg-object!]
			output-sections output-data symbols functions debug-lines debug-parameters [wire-section-slice!]
			record [byte-ptr!]
			status [integer!]
			record-index record-offset bad-relative name-string class flags alignment
			data-offset file-size memory-size reserved cursor previous-class previous-name
			prior-id prior-name symbol-id binding origin prior-binding prior-origin kind visibility
			output-section section-offset symbol-size symbol-alignment section-class section-memory
			prior-section prior-offset prior-size
			function-id function-symbol code-section code-offset code-size frame-size first-line
			line-count first-parameter parameter-count previous-code-section previous-code-offset
			previous-code-end found module-id module-kind runtime-module lifecycle-index
			lifecycle-offset lifecycle-symbol
			role-count role-id role-section role-offset role-size role-data-base header-offset
	][
		if null? result [return WIRE_RSCG_OBJECT_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_RSCG_OBJECT_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0
		if any [size < 0 null? data null? strings null? files null? layout null? modules null? output-view][
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_ARGUMENTS 0 0
		]

		container: declare wire-container-result!
		status: wire-container-reader/verify data size WIRE_MAGIC_RSCG container
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			result/container-error: status
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
				container/error-offset container/error-section
		]
		module-result: declare wire-module-lifecycle-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-modules: declare wire-module-lifecycle!
		status: wire-module-lifecycle-reader/verify data size WIRE_MAGIC_RSCG
			module-result verified-strings verified-files verified-modules
		if status <> WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS [
			result/container-error: module-result/container-error
			result/string-error: module-result/string-error
			result/file-source-error: module-result/file-source-error
			result/module-lifecycle-error: status
			if status = WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER [
				return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
					module-result/error-offset module-result/error-section
			]
			if status = WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS [
				return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_STRINGS
					module-result/error-offset module-result/error-section
			]
			if status = WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE [
				return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_FILE_SOURCE
					module-result/error-offset module-result/error-section
			]
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_MODULE_LIFECYCLE
				module-result/error-offset module-result/error-section
		]

		layout-result: declare wire-data-layout-result!
		verified-layout: declare wire-data-layout!
		status: wire-data-layout-reader/verify data size WIRE_MAGIC_RSCG layout-result verified-layout
		if status <> WIRE_DATA_LAYOUT_ERROR_SUCCESS [
			result/container-error: layout-result/container-error
			result/data-layout-error: status
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_DATA_LAYOUT
				layout-result/error-offset layout-result/error-section
		]

		output-sections: declare wire-section-slice!
		output-data: declare wire-section-slice!
		symbols: declare wire-section-slice!
		functions: declare wire-section-slice!
		debug-lines: declare wire-section-slice!
		debug-parameters: declare wire-section-slice!
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_OUTPUT_SECTIONS output-sections [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_OUTPUT_DATA output-data [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_SYMBOLS symbols [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_FUNCTIONS functions [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_DEBUG_LINES debug-lines [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section data WIRE_RSCG_SECTION_DEBUG_PARAMETERS debug-parameters [
			return set-error result WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER WIRE_HEADER_SIZE 0
		]

		if output-sections/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_SECTION_FLAGS
				section-flags-offset output-sections output-sections/ordinal
		]
		if output-data/flags <> 0 [
			return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_DATA_SECTION_FLAGS
				section-flags-offset output-data output-data/ordinal
		]
		if symbols/flags <> expected-symbol-flags [
			return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_FLAGS
				section-flags-offset symbols symbols/ordinal
		]
		if functions/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION_FLAGS
				section-flags-offset functions functions/ordinal
		]

		; Keep all views private until every rule succeeds.
		view: declare wire-rscg-object!
		view/output-sections: output-sections/data
		view/output-section-count: output-sections/record-count
		view/output-section-size: output-sections/record-size
		view/output-sections-offset: output-sections/offset
		view/output-sections-ordinal: output-sections/ordinal
		view/output-data: output-data/data
		view/output-data-size: output-data/size
		view/output-data-offset: output-data/offset
		view/output-data-ordinal: output-data/ordinal
		view/symbols: symbols/data
		view/symbol-count: symbols/record-count
		view/symbol-size: symbols/record-size
		view/symbols-offset: symbols/offset
		view/symbols-ordinal: symbols/ordinal
		view/functions: functions/data
		view/function-count: functions/record-count
		view/function-size: functions/record-size
		view/functions-offset: functions/offset
		view/functions-ordinal: functions/ordinal
		view/debug-line-count: debug-lines/record-count
		view/debug-parameter-count: debug-parameters/record-count
		view/runtime-module: 0
		view/exec-image-symbol: 0
		view/bitmap-symbol: 0
		view/lib-image-symbol: 0

		; Decode every object-layout scalar before following references.
		record-index: 0
		while [record-index < output-sections/record-count][
			record: output-sections/data + (record-index * output-sections/record-size)
			bad-relative: first-bad-scalar record
				(output-sections/record-size / 4)
			if bad-relative >= 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_SCALAR_RANGE
					((output-sections/offset + (record-index * output-sections/record-size))
						+ bad-relative)
					output-sections/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < symbols/record-count][
			record: symbols/data + (record-index * symbols/record-size)
			bad-relative: first-bad-scalar record (symbols/record-size / 4)
			if bad-relative >= 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_SCALAR_RANGE
					((symbols/offset + (record-index * symbols/record-size)) + bad-relative)
					symbols/ordinal
			]
			record-index: record-index + 1
		]
		record-index: 0
		while [record-index < functions/record-count][
			record: functions/data + (record-index * functions/record-size)
			bad-relative: first-bad-scalar record (functions/record-size / 4)
			if bad-relative >= 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_SCALAR_RANGE
					((functions/offset + (record-index * functions/record-size)) + bad-relative)
					functions/ordinal
			]
			record-index: record-index + 1
		]

		; Output-section scalar and extent rules.
		cursor: 0
		previous-class: 0
		previous-name: 0
		record-index: 0
		while [record-index < output-sections/record-count][
			record-offset: record-index * output-sections/record-size
			name-string: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
			class: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
			flags: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
			alignment: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
			data-offset: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
			file-size: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
			memory-size: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
			reserved: wire-container-reader/read-i31 output-sections/data
				(record-offset + WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET)
			if any [name-string <= 0 name-string > verified-strings/record-count][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_NAME_ID
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
					output-sections/ordinal
			]
			if (string-size-for-id verified-strings name-string) = 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_EMPTY_OUTPUT_SECTION_NAME
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
					output-sections/ordinal
			]
			if any [class < WIRE_OUTPUT_SECTION_CLASS_CODE class > WIRE_OUTPUT_SECTION_CLASS_PLATFORM][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_CLASS
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
					output-sections/ordinal
			]
			if class = WIRE_OUTPUT_SECTION_CLASS_PLATFORM [
				return set-error result WIRE_RSCG_OBJECT_ERROR_UNSUPPORTED_PLATFORM_SECTION
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
					output-sections/ordinal
			]
			if flags <> WIRE_RSCG_OUTPUT_SECTION_FLAG_NONE [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FLAGS
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
					output-sections/ordinal
			]
			unless all [alignment <= max-section-alignment wire-container-reader/power-of-two? alignment][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_ALIGNMENT
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
					output-sections/ordinal
			]
			if memory-size = 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_MEMORY_SIZE
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
					output-sections/ordinal
			]
			if reserved <> 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_NONZERO_OUTPUT_SECTION_RESERVED
					(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET)
					output-sections/ordinal
			]
			if record-index > 0 [
				if any [class < previous-class all [class = previous-class name-string <= previous-name]][
					return set-error result WIRE_RSCG_OBJECT_ERROR_OUTPUT_SECTION_ORDER
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
						output-sections/ordinal
				]
			]
			prior-id: 1
			while [prior-id <= record-index][
				prior-name: output-value view prior-id WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
				if prior-name = name-string [
					return set-error result WIRE_RSCG_OBJECT_ERROR_DUPLICATE_OUTPUT_SECTION_NAME
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET)
						output-sections/ordinal
				]
				prior-id: prior-id + 1
			]
			either class = WIRE_OUTPUT_SECTION_CLASS_BSS [
				if any [data-offset <> 0 file-size <> 0][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_BSS_SHAPE
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
						output-sections/ordinal
				]
			][
				if file-size = 0 [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FILE_SIZE
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
						output-sections/ordinal
				]
				if memory-size <> file-size [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_INITIALIZED_SECTION_SHAPE
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET)
						output-sections/ordinal
				]
				if data-offset <> cursor [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_DATA_OFFSET
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
						output-sections/ordinal
				]
				if file-size > (output-data/size - cursor) [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FILE_SIZE
						(output-sections/offset + record-offset + WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
						output-sections/ordinal
				]
				cursor: cursor + file-size
			]
			previous-class: class
			previous-name: name-string
			record-index: record-index + 1
		]
		if cursor <> output-data/size [
			return set-error result WIRE_RSCG_OBJECT_ERROR_OUTPUT_DATA_COVERAGE
				(output-data/offset + cursor) output-data/ordinal
		]

		; Symbol shape, canonical order, and non-overlap.
		previous-name: 0
		prior-binding: 0
		prior-origin: 0
		symbol-id: 1
		while [symbol-id <= symbols/record-count][
			record-offset: (symbol-id - 1) * symbols/record-size
			name-string: symbol-value view symbol-id WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
			kind: symbol-value view symbol-id WIRE_RSCG_SYMBOL_KIND_OFFSET
			binding: symbol-value view symbol-id WIRE_RSCG_SYMBOL_BINDING_OFFSET
			visibility: symbol-value view symbol-id WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
			output-section: symbol-value view symbol-id WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
			section-offset: symbol-value view symbol-id WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
			symbol-size: symbol-value view symbol-id WIRE_RSCG_SYMBOL_SIZE_OFFSET
			symbol-alignment: symbol-value view symbol-id WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
			flags: symbol-value view symbol-id WIRE_RSCG_SYMBOL_FLAGS_OFFSET
			origin: symbol-value view symbol-id WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET
			if any [name-string <= 0 name-string > verified-strings/record-count][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_NAME_ID
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			if (string-size-for-id verified-strings name-string) = 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_EMPTY_SYMBOL_NAME
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
			]
			unless all [kind >= WIRE_SYMBOL_KIND_FUNCTION kind <= WIRE_SYMBOL_KIND_CONSTANT][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_KIND
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_KIND_OFFSET) symbols/ordinal
			]
			unless all [binding >= WIRE_SYMBOL_BINDING_LOCAL binding <= WIRE_SYMBOL_BINDING_WEAK][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_BINDING_OFFSET) symbols/ordinal
			]
			unless any [visibility = WIRE_VISIBILITY_DEFAULT visibility = WIRE_VISIBILITY_HIDDEN][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_VISIBILITY
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET) symbols/ordinal
			]
			if any [
				all [binding = WIRE_SYMBOL_BINDING_LOCAL visibility <> WIRE_VISIBILITY_HIDDEN]
				all [binding <> WIRE_SYMBOL_BINDING_LOCAL visibility <> WIRE_VISIBILITY_DEFAULT]
			][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING_VISIBILITY
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET) symbols/ordinal
			]
			unless any [flags = 0 flags = WIRE_RSCG_SYMBOL_FLAG_UNDEFINED][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_FLAGS
					(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_FLAGS_OFFSET) symbols/ordinal
			]
			if symbol-id > 1 [
				if any [
					name-string < previous-name
					all [name-string = previous-name binding < prior-binding]
					all [name-string = previous-name binding = prior-binding origin < prior-origin]
				][
					return set-error result WIRE_RSCG_OBJECT_ERROR_SYMBOL_ORDER
						(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
				]
			]
			prior-id: 1
			while [prior-id < symbol-id][
				prior-name: symbol-value view prior-id WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
				if prior-name = name-string [
					prior-binding: symbol-value view prior-id WIRE_RSCG_SYMBOL_BINDING_OFFSET
					prior-origin: symbol-value view prior-id WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET
					if any [
						all [binding = WIRE_SYMBOL_BINDING_LOCAL prior-binding = WIRE_SYMBOL_BINDING_LOCAL origin = prior-origin]
						all [binding <> WIRE_SYMBOL_BINDING_LOCAL prior-binding <> WIRE_SYMBOL_BINDING_LOCAL]
					][
						return set-error result WIRE_RSCG_OBJECT_ERROR_DUPLICATE_SYMBOL
							(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET) symbols/ordinal
					]
				]
				prior-id: prior-id + 1
			]
			either flags = WIRE_RSCG_SYMBOL_FLAG_UNDEFINED [
				unless all [binding <> WIRE_SYMBOL_BINDING_LOCAL output-section = 0 section-offset = 0 symbol-size = 0 symbol-alignment = 0][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_DEFINITION_SHAPE
						(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) symbols/ordinal
				]
			][
				if any [output-section <= 0 output-section > view/output-section-count][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_OUTPUT_SECTION
						(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) symbols/ordinal
				]
				section-class: output-value view output-section WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
				section-memory: output-value view output-section WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
				unless all [
					symbol-alignment <= (output-value view output-section
						WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET)
					wire-container-reader/power-of-two? symbol-alignment
					zero? (section-offset // symbol-alignment)
				][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_ALIGNMENT
						(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET) symbols/ordinal
				]
				unless all [
					section-offset <= section-memory
					symbol-size <= (section-memory - section-offset)
				][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_EXTENT
						(symbols/offset + record-offset
							+ WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
						symbols/ordinal
				]
				unless case [
					kind = WIRE_SYMBOL_KIND_FUNCTION [section-class = WIRE_OUTPUT_SECTION_CLASS_CODE]
					kind = WIRE_SYMBOL_KIND_GLOBAL [any [section-class = WIRE_OUTPUT_SECTION_CLASS_DATA section-class = WIRE_OUTPUT_SECTION_CLASS_BSS]]
					kind = WIRE_SYMBOL_KIND_CONSTANT [section-class = WIRE_OUTPUT_SECTION_CLASS_RODATA]
					true [false]
				][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_CLASS
						(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) symbols/ordinal
				]
				if symbol-size > 0 [
					prior-id: 1
					while [prior-id < symbol-id][
						if symbol-defined? view prior-id [
							prior-section: symbol-value view prior-id WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
							prior-offset: symbol-value view prior-id WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
							prior-size: symbol-value view prior-id WIRE_RSCG_SYMBOL_SIZE_OFFSET
							if all [prior-size > 0 prior-section = output-section
								section-offset < (prior-offset + prior-size)
								prior-offset < (section-offset + symbol-size)][
								return set-error result WIRE_RSCG_OBJECT_ERROR_SYMBOL_OVERLAP
									(symbols/offset + record-offset + WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET) symbols/ordinal
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

		; Function records are ordered by code section and offset.
		previous-code-section: 0
		previous-code-offset: 0
		previous-code-end: 0
		function-id: 1
		while [function-id <= functions/record-count][
			record-offset: (function-id - 1) * functions/record-size
			function-symbol: function-value view function-id WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
			code-section: function-value view function-id WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
			code-offset: function-value view function-id WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
			code-size: function-value view function-id WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
			frame-size: function-value view function-id WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET
			flags: function-value view function-id WIRE_RSCG_FUNCTION_FLAGS_OFFSET
			first-line: function-value view function-id WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
			line-count: function-value view function-id WIRE_RSCG_FUNCTION_DEBUG_LINE_COUNT_OFFSET
			first-parameter: function-value view function-id WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
			parameter-count: function-value view function-id WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET
			if any [function-symbol <= 0 function-symbol > view/symbol-count][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SYMBOL
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) functions/ordinal
			]
			prior-id: 1
			while [prior-id < function-id][
				if (function-value view prior-id WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) = function-symbol [
					return set-error result WIRE_RSCG_OBJECT_ERROR_DUPLICATE_FUNCTION_SYMBOL
						(functions/offset + record-offset + WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) functions/ordinal
				]
				prior-id: prior-id + 1
			]
			if any [code-section <= 0 code-section > view/output-section-count][
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET) functions/ordinal
			]
			if (output-value view code-section WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
				<> WIRE_OUTPUT_SECTION_CLASS_CODE
			[
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET) functions/ordinal
			]
			unless all [
				symbol-defined? view function-symbol
				(symbol-value view function-symbol WIRE_RSCG_SYMBOL_KIND_OFFSET)
					= WIRE_SYMBOL_KIND_FUNCTION
				(symbol-value view function-symbol WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
					= code-section
				(symbol-value view function-symbol WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
					= code-offset
				(symbol-value view function-symbol WIRE_RSCG_SYMBOL_SIZE_OFFSET) = code-size
			][
				return set-error result WIRE_RSCG_OBJECT_ERROR_FUNCTION_SYMBOL_MISMATCH
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_SYMBOL_OFFSET) functions/ordinal
			]
			if code-size = 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_EXTENT
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET) functions/ordinal
			]
			if function-id > 1 [
				if any [code-section < previous-code-section all [code-section = previous-code-section code-offset < previous-code-offset]][
					return set-error result WIRE_RSCG_OBJECT_ERROR_FUNCTION_ORDER
						(functions/offset + record-offset + WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET) functions/ordinal
				]
				if all [code-section = previous-code-section code-offset < previous-code-end][
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_EXTENT
						(functions/offset + record-offset + WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET) functions/ordinal
				]
			]
			if (frame-size // 8) <> 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FRAME_SIZE
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET) functions/ordinal
			]
			if flags <> WIRE_RSCG_FUNCTION_FLAG_NONE [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FLAGS
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_FLAGS_OFFSET) functions/ordinal
			]
			unless canonical-range? first-line line-count debug-lines/record-count [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET) functions/ordinal
			]
			unless canonical-range? first-parameter parameter-count debug-parameters/record-count [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
					(functions/offset + record-offset + WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET) functions/ordinal
			]
			previous-code-section: code-section
			previous-code-offset: code-offset
			previous-code-end: code-offset + code-size
			function-id: function-id + 1
		]

		symbol-id: 1
		while [symbol-id <= view/symbol-count][
			if all [
				symbol-defined? view symbol-id
				(symbol-value view symbol-id WIRE_RSCG_SYMBOL_KIND_OFFSET)
					= WIRE_SYMBOL_KIND_FUNCTION
			][
				found: 0
				function-id: 1
				while [function-id <= view/function-count][
					if (function-value view function-id WIRE_RSCG_FUNCTION_SYMBOL_OFFSET)
						= symbol-id
					[found: 1 break]
					function-id: function-id + 1
				]
				if found = 0 [
					return set-error result WIRE_RSCG_OBJECT_ERROR_MISSING_FUNCTION_RECORD
						(view/symbols-offset + ((symbol-id - 1) * WIRE_RSCG_SYMBOL_SIZE) + WIRE_RSCG_SYMBOL_KIND_OFFSET)
						symbols/ordinal
				]
			]
			symbol-id: symbol-id + 1
		]

		module-id: 1
		while [module-id <= verified-modules/module-count][
			lifecycle-index: 1
			while [lifecycle-index <= 3][
				lifecycle-offset: case [
					lifecycle-index = 1 [WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET]
					lifecycle-index = 2 [WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET]
					true [WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET]
				]
				lifecycle-symbol: module-value verified-modules module-id lifecycle-offset
				if lifecycle-symbol <> 0 [
					unless all [
						symbol-defined? view lifecycle-symbol
						(symbol-value view lifecycle-symbol WIRE_RSCG_SYMBOL_KIND_OFFSET)
							= WIRE_SYMBOL_KIND_FUNCTION
					][
						return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_LIFECYCLE_SYMBOL
							(verified-modules/modules-offset + ((module-id - 1) * WIRE_RSCG_MODULE_SIZE) + lifecycle-offset)
							verified-modules/modules-ordinal
					]
				]
				lifecycle-index: lifecycle-index + 1
			]
			module-id: module-id + 1
		]
		runtime-module: 0
		module-id: 1
		while [module-id <= verified-modules/module-count][
			module-kind: module-value verified-modules module-id WIRE_RSCG_MODULE_KIND_OFFSET
			if module-kind = WIRE_MODULE_KIND_RUNTIME [
				if runtime-module <> 0 [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_RUNTIME_MODULE_COUNT
						(verified-modules/modules-offset + ((module-id - 1) * WIRE_RSCG_MODULE_SIZE) + WIRE_RSCG_MODULE_KIND_OFFSET)
						verified-modules/modules-ordinal
				]
				runtime-module: module-id
			]
			module-id: module-id + 1
		]
		view/runtime-module: runtime-module

		if runtime-module <> 0 [
			role-count: count-role verified-strings view
				(as byte-ptr! "***-exec-image") 14
			if role-count = 0 [return set-error result WIRE_RSCG_OBJECT_ERROR_MISSING_EXEC_IMAGE_ROLE view/symbols-offset symbols/ordinal]
			if role-count <> 1 [return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_EXEC_IMAGE_ROLE view/symbols-offset symbols/ordinal]
			role-id: first-role verified-strings view
				(as byte-ptr! "***-exec-image") 14
			unless role-shape? view role-id runtime-module exec-image-size 8 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_EXEC_IMAGE_ROLE
					(view/symbols-offset + ((role-id - 1) * WIRE_RSCG_SYMBOL_SIZE) + WIRE_RSCG_SYMBOL_KIND_OFFSET)
					symbols/ordinal
			]
			view/exec-image-symbol: role-id
			role-count: count-role verified-strings view
				(as byte-ptr! "***-ptr-bitmaps") 15
			if role-count = 0 [return set-error result WIRE_RSCG_OBJECT_ERROR_MISSING_BITMAP_ROLE view/symbols-offset symbols/ordinal]
			if role-count <> 1 [return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_ROLE view/symbols-offset symbols/ordinal]
			role-id: first-role verified-strings view
				(as byte-ptr! "***-ptr-bitmaps") 15
			role-section: symbol-value view role-id WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
			role-offset: symbol-value view role-id WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
			role-size: symbol-value view role-id WIRE_RSCG_SYMBOL_SIZE_OFFSET
			unless all [role-shape? view role-id runtime-module role-size 4
				role-size > 0 (role-size // 4) = 0 role-offset >= 4]
			[
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_ROLE
					(view/symbols-offset + ((role-id - 1) * WIRE_RSCG_SYMBOL_SIZE) + WIRE_RSCG_SYMBOL_SIZE_OFFSET)
					symbols/ordinal
			]
			role-data-base: output-value view role-section
				WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
			header-offset: view/output-data-offset + role-data-base + role-offset - 4
			if (wire-container-reader/first-nonzero data header-offset (header-offset + 4)) >= 0 [
				return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_HEADER header-offset output-data/ordinal
			]
			view/bitmap-symbol: role-id
			if verified-modules/image-kind = WIRE_IMAGE_KIND_DYNAMIC_LIBRARY [
				role-count: count-role verified-strings view
					(as byte-ptr! "***-lib-image") 13
				if role-count = 0 [return set-error result WIRE_RSCG_OBJECT_ERROR_MISSING_LIB_IMAGE_ROLE view/symbols-offset symbols/ordinal]
				if role-count <> 1 [return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_LIB_IMAGE_ROLE view/symbols-offset symbols/ordinal]
				role-id: first-role verified-strings view
					(as byte-ptr! "***-lib-image") 13
				unless role-shape? view role-id runtime-module exec-image-size 8 [
					return set-error result WIRE_RSCG_OBJECT_ERROR_BAD_LIB_IMAGE_ROLE
						(view/symbols-offset + ((role-id - 1) * WIRE_RSCG_SYMBOL_SIZE) + WIRE_RSCG_SYMBOL_KIND_OFFSET)
						symbols/ordinal
				]
				view/lib-image-symbol: role-id
			]
		]

		copy-strings strings verified-strings
		copy-files files verified-files
		copy-layout layout verified-layout
		copy-modules modules verified-modules
		copy-view output-view view
		result/error: WIRE_RSCG_OBJECT_ERROR_SUCCESS
		WIRE_RSCG_OBJECT_ERROR_SUCCESS
	]
]
