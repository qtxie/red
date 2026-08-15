Red [
	Title: "Hybrid compiler RSCG debug, GC, and unwind metadata verifier"
	File:  %wire-rscg-metadata.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-container [do %wire-container.red]
unless value? 'compiler-wire-rscg-relocation [do %wire-rscg-relocation.red]

compiler-wire-rscg-metadata: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	relocation-verifier: compiler-wire-rscg-relocation

	expected-index-flags:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED
	expected-debug-line-flags: schema/WIRE_SECTION_FLAG_SORTED
	expected-unwind-flags:
		schema/WIRE_SECTION_FLAG_OPTIONAL + expected-index-flags
	bitmap-variadic-marker: 1073741824
	bitmap-typed-marker: 536870912

	make-view: does [
		make object! [
			debug-lines-offset: 0
			debug-line-count: 0
			debug-lines-ordinal: 0
			debug-parameters-offset: 0
			debug-parameter-count: 0
			debug-parameters-ordinal: 0
			gc-frames-offset: 0
			gc-frame-count: 0
			gc-frames-ordinal: 0
			unwind-present?: false
			unwind-functions-offset: 0
			unwind-function-count: 0
			unwind-functions-ordinal: 0
		]
	]

	make-result: does [
		make object! [
			valid?: false
			error: schema/WIRE_RSCG_METADATA_ERROR_SUCCESS
			relocation-error: schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS
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
			relocation-view: none
			view: none
		]
	]

	reject: func [result [object!] code offset section [integer!]][
		result/error: code
		result/error-offset: offset
		result/error-section: section
		result
	]

	inherit-relocation-result: func [result dependency [object!]][
		result/header: dependency/header
		result/relocation-error: dependency/error
		result/object-error: dependency/object-error
		result/container-error: dependency/container-error
		result/string-error: dependency/string-error
		result/file-source-error: dependency/file-source-error
		result/data-layout-error: dependency/data-layout-error
		result/module-lifecycle-error: dependency/module-lifecycle-error
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

	debug-line-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/debug-lines-offset id schema/WIRE_RSCG_DEBUG_LINE_SIZE field
	]

	debug-parameter-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/debug-parameters-offset id
			schema/WIRE_RSCG_DEBUG_PARAMETER_SIZE field
	]

	gc-frame-value: func [data [binary!] view [object!] id field [integer!]][
		record-value data view/gc-frames-offset id schema/WIRE_RSCG_GC_FRAME_SIZE field
	]

	function-value: func [data [binary!] object-view [object!] id field [integer!]][
		record-value data object-view/functions-offset id schema/WIRE_RSCG_FUNCTION_SIZE field
	]

	output-value: func [data [binary!] object-view [object!] id field [integer!]][
		record-value data object-view/output-sections-offset id
			schema/WIRE_RSCG_OUTPUT_SECTION_SIZE field
	]

	symbol-value: func [data [binary!] object-view [object!] id field [integer!]][
		record-value data object-view/symbols-offset id schema/WIRE_RSCG_SYMBOL_SIZE field
	]

	relocation-value: func [data [binary!] relocation-view [object!] id field [integer!]][
		record-value data relocation-view/relocations-offset id
			schema/WIRE_RSCG_RELOCATION_SIZE field
	]

	debug-code-valid?: func [code [integer!]][
		any [
			all [code >= schema/WIRE_DEBUG_TYPE_CODE_LOGIC
				code <= schema/WIRE_DEBUG_TYPE_CODE_UINT32]
			code = schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE
		]
	]

	word-extension?: func [data [binary!] offset [integer!]][
		(to integer! pick data (offset + 4)) > 127
	]

	word-low31: func [data [binary!] offset [integer!]][
		(to integer! pick data (offset + 1))
			+ ((to integer! pick data (offset + 2)) * 256)
			+ ((to integer! pick data (offset + 3)) * 65536)
			+ (((to integer! pick data (offset + 4)) and 127) * 16777216)
	]

	word-count-for-slots: func [slots [integer!]][
		either zero? slots [1][(to integer! ((slots - 1) / 31)) + 1]
	]

	unused-bits?: func [word slots [integer!] /local used allowed][
		if zero? slots [return word <> 0]
		used: slots // 31
		if zero? used [return false]
		allowed: (shift/left 1 used) - 1
		not zero? (word and (complement allowed))
	]

	scan-word-chain: func [
		data [binary!] start finish [integer!]
		/local cursor count extension?
	][
		cursor: start
		count: 0
		until [
			if cursor >= finish [return none]
			extension?: word-extension? data cursor
			count: count + 1
			cursor: cursor + 4
			not extension?
		]
		reduce [cursor count]
	]

	verify: func [
		data
		/local result dependency container-result debug-lines debug-parameters
			gc-frames unwind view object-view relocation-view section record-id base
			field-offset value function-id code-offset file-id line-number previous-function
			previous-code first count cursor expected record-function ordinal type-code flags
			previous-ordinal bitmap-symbol role-section role-offset role-size role-end
			bitmap-section bitmap-offset bitmap-size bitmap-end bitmap-base bitmap-finish
			arg-slots local-slots arg-start arg-chain arg-end arg-word-count local-start
			local-chain local-end local-word-count expected-words first-word last-word
			dynamic? function-code-section function-code-offset function-code-size
			patch-offset patch-section-offset code-data-offset patch-data-offset
			relocation-id relocation-section relocation-offset relocation-width
			prior-id prior-section prior-offset prior-size prior-end role-cursor found? consumed
			unwind-records
	][
		result: make-result
		unless binary? data [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_INVALID_ARGUMENTS 0 0
		]

		dependency: relocation-verifier/verify data
		inherit-relocation-result result dependency
		unless dependency/valid? [
			case [
				all [
					dependency/error = schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
					dependency/object-error = schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
				][
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_RANGE
						dependency/error-offset dependency/error-section
				]
				all [
					dependency/error = schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
					dependency/object-error = schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
				][
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_RANGE
						dependency/error-offset dependency/error-section
				]
				true [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
						dependency/error-offset dependency/error-section
				]
			]
		]

		container-result: container/verify/expect data schema/WIRE_MAGIC_RSCG
		debug-lines: container/find-section container-result schema/WIRE_RSCG_SECTION_DEBUG_LINES
		debug-parameters: container/find-section container-result
			schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS
		gc-frames: container/find-section container-result schema/WIRE_RSCG_SECTION_GC_FRAMES
		unwind: container/find-section container-result schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS

		if (select debug-lines 'flags) <> expected-debug-line-flags [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_SECTION_FLAGS
				section-flags-offset debug-lines (select debug-lines 'ordinal)
		]
		if (select debug-parameters 'flags) <> expected-index-flags [
			return reject result
				schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_SECTION_FLAGS
				section-flags-offset debug-parameters (select debug-parameters 'ordinal)
		]
		if (select gc-frames 'flags) <> expected-index-flags [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_SECTION_FLAGS
				section-flags-offset gc-frames (select gc-frames 'ordinal)
		]
		if all [not none? unwind (select unwind 'flags) <> expected-unwind-flags][
			return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_UNWIND_SECTION_FLAGS
				section-flags-offset unwind (select unwind 'ordinal)
		]

		view: make-view
		view/debug-lines-offset: select debug-lines 'payload-offset
		view/debug-line-count: select debug-lines 'record-count
		view/debug-lines-ordinal: select debug-lines 'ordinal
		view/debug-parameters-offset: select debug-parameters 'payload-offset
		view/debug-parameter-count: select debug-parameters 'record-count
		view/debug-parameters-ordinal: select debug-parameters 'ordinal
		view/gc-frames-offset: select gc-frames 'payload-offset
		view/gc-frame-count: select gc-frames 'record-count
		view/gc-frames-ordinal: select gc-frames 'ordinal
		unless none? unwind [
			view/unwind-present?: true
			view/unwind-functions-offset: select unwind 'payload-offset
			view/unwind-function-count: select unwind 'record-count
			view/unwind-functions-ordinal: select unwind 'ordinal
		]
		object-view: dependency/object-view
		relocation-view: dependency/view

		; Decode every metadata scalar before applying semantic rules. Bitmap words
		; remain raw bit containers and are decoded separately below.
		foreach section reduce [debug-lines debug-parameters gc-frames unwind][
			unless none? section [
				record-id: 1
				while [record-id <= (select section 'record-count)][
					base: record-base (select section 'payload-offset) record-id
						(select section 'record-size)
					field-offset: 0
					while [field-offset < (select section 'record-size)][
						value: container/read-i31 data (base + field-offset)
						if none? value [
							return reject result schema/WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
								(base + field-offset) (select section 'ordinal)
						]
						field-offset: field-offset + 4
					]
					record-id: record-id + 1
				]
			]
		]

		; Debug lines are sorted by function and function-relative code offset.
		previous-function: 0
		previous-code: 0
		record-id: 1
		while [record-id <= view/debug-line-count][
			base: record-base view/debug-lines-offset record-id schema/WIRE_RSCG_DEBUG_LINE_SIZE
			function-id: debug-line-value data view record-id
				schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
			code-offset: debug-line-value data view record-id
				schema/WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET
			file-id: debug-line-value data view record-id schema/WIRE_RSCG_DEBUG_LINE_FILE_OFFSET
			line-number: debug-line-value data view record-id schema/WIRE_RSCG_DEBUG_LINE_LINE_OFFSET
			if any [function-id <= 0 function-id > object-view/function-count][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_FUNCTION
					(base + schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET)
					view/debug-lines-ordinal
			]
			if any [
				function-id < previous-function
				all [function-id = previous-function code-offset < previous-code]
			][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_ORDER
					(base + schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET)
					view/debug-lines-ordinal
			]
			if code-offset >= (function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET)
			[
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_CODE_OFFSET
					(base + schema/WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET)
					view/debug-lines-ordinal
			]
			if any [file-id <= 0 file-id > dependency/files/file-count][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_FILE
					(base + schema/WIRE_RSCG_DEBUG_LINE_FILE_OFFSET)
					view/debug-lines-ordinal
			]
			if line-number <= 0 [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_NUMBER
					(base + schema/WIRE_RSCG_DEBUG_LINE_LINE_OFFSET)
					view/debug-lines-ordinal
			]
			previous-function: function-id
			previous-code: code-offset
			record-id: record-id + 1
		]

		cursor: 1
		function-id: 1
		while [function-id <= object-view/function-count][
			first: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
			count: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_DEBUG_LINE_COUNT_OFFSET
			if count > 0 [
				if first <> cursor [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
						(object-view/functions-offset
							+ (((function-id - 1) * schema/WIRE_RSCG_FUNCTION_SIZE)
							+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET))
						object-view/functions-ordinal
				]
				repeat expected count [
					record-function: debug-line-value data view (first + expected - 1)
						schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
					if record-function <> function-id [
						base: record-base view/debug-lines-offset (first + expected - 1)
							schema/WIRE_RSCG_DEBUG_LINE_SIZE
						return reject result schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
							(base + schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET)
							view/debug-lines-ordinal
					]
				]
				cursor: first + count
			]
			function-id: function-id + 1
		]
		if cursor <> (view/debug-line-count + 1) [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
				view/debug-lines-offset view/debug-lines-ordinal
		]

		; Parameter ordinals are dense and zero-based inside each function range.
		previous-function: 0
		previous-ordinal: 0
		record-id: 1
		while [record-id <= view/debug-parameter-count][
			base: record-base view/debug-parameters-offset record-id
				schema/WIRE_RSCG_DEBUG_PARAMETER_SIZE
			function-id: debug-parameter-value data view record-id
				schema/WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET
			ordinal: debug-parameter-value data view record-id
				schema/WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET
			type-code: debug-parameter-value data view record-id
				schema/WIRE_RSCG_DEBUG_PARAMETER_DEBUG_TYPE_CODE_OFFSET
			flags: debug-parameter-value data view record-id
				schema/WIRE_RSCG_DEBUG_PARAMETER_FLAGS_OFFSET
			if any [function-id <= 0 function-id > object-view/function-count][
				return reject result
					schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FUNCTION
					(base + schema/WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET)
					view/debug-parameters-ordinal
			]
			expected: either function-id = previous-function [previous-ordinal + 1][0]
			if ordinal <> expected [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_ORDINAL
					(base + schema/WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET)
					view/debug-parameters-ordinal
			]
			if ordinal >= (function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET)
			[
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_ORDINAL
					(base + schema/WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET)
					view/debug-parameters-ordinal
			]
			unless debug-code-valid? type-code [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_TYPE_CODE
					(base + schema/WIRE_RSCG_DEBUG_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
					view/debug-parameters-ordinal
			]
			if flags <> schema/WIRE_RSCG_DEBUG_PARAMETER_FLAG_NONE [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FLAGS
					(base + schema/WIRE_RSCG_DEBUG_PARAMETER_FLAGS_OFFSET)
					view/debug-parameters-ordinal
			]
			previous-function: function-id
			previous-ordinal: ordinal
			record-id: record-id + 1
		]

		cursor: 1
		function-id: 1
		while [function-id <= object-view/function-count][
			first: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
			count: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET
			if count > 0 [
				if first <> cursor [
					return reject result
						schema/WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
						(object-view/functions-offset
							+ (((function-id - 1) * schema/WIRE_RSCG_FUNCTION_SIZE)
							+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET))
						object-view/functions-ordinal
				]
				repeat expected count [
					record-function: debug-parameter-value data view (first + expected - 1)
						schema/WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET
					if record-function <> function-id [
						base: record-base view/debug-parameters-offset (first + expected - 1)
							schema/WIRE_RSCG_DEBUG_PARAMETER_SIZE
						return reject result
							schema/WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
							(base + schema/WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET)
							view/debug-parameters-ordinal
					]
				]
				cursor: first + count
			]
			function-id: function-id + 1
		]
		if cursor <> (view/debug-parameter-count + 1) [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
				view/debug-parameters-offset view/debug-parameters-ordinal
		]

		bitmap-symbol: object-view/bitmap-symbol
		role-section: either bitmap-symbol = 0 [0][
			symbol-value data object-view bitmap-symbol
				schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		]
		role-offset: either bitmap-symbol = 0 [0][
			symbol-value data object-view bitmap-symbol schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		]
		role-size: either bitmap-symbol = 0 [0][
			symbol-value data object-view bitmap-symbol schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
		]
		role-end: role-offset + role-size

		previous-function: 0
		record-id: 1
		while [record-id <= view/gc-frame-count][
			base: record-base view/gc-frames-offset record-id schema/WIRE_RSCG_GC_FRAME_SIZE
			function-id: gc-frame-value data view record-id schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
			bitmap-section: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
			bitmap-offset: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
			bitmap-size: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
			flags: gc-frame-value data view record-id schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET
			patch-offset: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET

			if any [function-id <= 0 function-id > object-view/function-count][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FUNCTION
					(base + schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
					view/gc-frames-ordinal
			]
			if function-id < previous-function [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_GC_FRAME_ORDER
					(base + schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
					view/gc-frames-ordinal
			]
			if function-id = previous-function [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_DUPLICATE_GC_FUNCTION
					(base + schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
					view/gc-frames-ordinal
			]
			unless any [
				flags = 0
				flags = schema/WIRE_RSCG_GC_FRAME_FLAG_LIBRARY_IMAGE
			][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_FLAGS
					(base + schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET)
					view/gc-frames-ordinal
			]
			if any [
				bitmap-section <= 0
				bitmap-section > object-view/output-section-count
				all [
					bitmap-section <= object-view/output-section-count
					(output-value data object-view bitmap-section
						schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
						<> schema/WIRE_OUTPUT_SECTION_CLASS_DATA
				]
				all [bitmap-symbol <> 0 bitmap-section <> role-section]
			][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SECTION
					(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET)
					view/gc-frames-ordinal
			]
			if not zero? bitmap-offset // 4 [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ALIGNMENT
					(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
					view/gc-frames-ordinal
			]
			if any [bitmap-size < 16 not zero? bitmap-size // 4][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SIZE
					(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET)
					view/gc-frames-ordinal
			]
			bitmap-end: bitmap-offset + bitmap-size
			if any [
				bitmap-offset > (output-value data object-view bitmap-section
					schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET)
				bitmap-size > ((output-value data object-view bitmap-section
					schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET) - bitmap-offset)
			][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_RANGE
					(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
					view/gc-frames-ordinal
			]

			bitmap-base: object-view/output-data-offset
				+ (output-value data object-view bitmap-section
					schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
				+ bitmap-offset
			bitmap-finish: bitmap-base + bitmap-size
			if word-extension? data bitmap-base [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
					bitmap-base object-view/output-data-ordinal
			]
			if word-extension? data (bitmap-base + 4) [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
					(bitmap-base + 4) object-view/output-data-ordinal
			]
			arg-slots: container/read-u32 data bitmap-base
			local-slots: container/read-u32 data (bitmap-base + 4)
			arg-start: bitmap-base + 8
			arg-chain: scan-word-chain data arg-start bitmap-finish
			if none? arg-chain [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
					arg-start object-view/output-data-ordinal
			]
			arg-end: arg-chain/1
			arg-word-count: arg-chain/2
			local-start: arg-end
			local-chain: scan-word-chain data local-start bitmap-finish
			if none? local-chain [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
					local-start object-view/output-data-ordinal
			]
			local-end: local-chain/1
			local-word-count: local-chain/2
			if local-end <> bitmap-finish [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
					local-end object-view/output-data-ordinal
			]

			first-word: word-low31 data arg-start
			dynamic?: any [
				first-word = bitmap-variadic-marker
				first-word = bitmap-typed-marker
			]
			either dynamic? [
				if arg-word-count <> 1 [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
						arg-start object-view/output-data-ordinal
				]
				if arg-slots <> 0 [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
						bitmap-base object-view/output-data-ordinal
				]
			][
				expected-words: word-count-for-slots arg-slots
				if arg-word-count <> expected-words [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
						bitmap-base object-view/output-data-ordinal
				]
				last-word: word-low31 data (arg-start + ((arg-word-count - 1) * 4))
				if unused-bits? last-word arg-slots [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_UNUSED_BITS
						(arg-start + ((arg-word-count - 1) * 4))
						object-view/output-data-ordinal
				]
			]
			expected-words: word-count-for-slots local-slots
			if local-word-count <> expected-words [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
					(bitmap-base + 4) object-view/output-data-ordinal
			]
			last-word: word-low31 data (local-start + ((local-word-count - 1) * 4))
			if unused-bits? last-word local-slots [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_UNUSED_BITS
					(local-start + ((local-word-count - 1) * 4))
					object-view/output-data-ordinal
			]

			function-code-section: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
			function-code-offset: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
			function-code-size: function-value data object-view function-id
				schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
			if any [patch-offset <= 0 patch-offset > function-code-size
				4 > (function-code-size - patch-offset)]
			[
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_PATCH
					(base + schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET)
					view/gc-frames-ordinal
			]
			patch-section-offset: function-code-offset + patch-offset
			code-data-offset: object-view/output-data-offset
				+ (output-value data object-view function-code-section
					schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
			patch-data-offset: code-data-offset + patch-section-offset
			if (to integer! pick data patch-data-offset) <> 104 [
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_OPCODE
					(patch-data-offset - 1) object-view/output-data-ordinal
			]
			if not none? container/first-nonzero data patch-data-offset
				(patch-data-offset + 4)
			[
				return reject result
					schema/WIRE_RSCG_METADATA_ERROR_NONZERO_PROLOG_PLACEHOLDER
					patch-data-offset object-view/output-data-ordinal
			]

			relocation-id: 1
			while [relocation-id <= relocation-view/relocation-count][
				relocation-section: relocation-value data relocation-view relocation-id
					schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
				relocation-offset: relocation-value data relocation-view relocation-id
					schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
				relocation-width: relocation-value data relocation-view relocation-id
					schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
				if all [
					relocation-section = function-code-section
					relocation-offset < (patch-section-offset + 4)
					patch-section-offset < (relocation-offset + relocation-width)
				][
					return reject result
						schema/WIRE_RSCG_METADATA_ERROR_PROLOG_RELOCATION_CONFLICT
						(relocation-view/relocations-offset
							+ (((relocation-id - 1) * schema/WIRE_RSCG_RELOCATION_SIZE)
							+ schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET))
						relocation-view/relocations-ordinal
				]
				relocation-id: relocation-id + 1
			]
			previous-function: function-id
			record-id: record-id + 1
		]

		if view/gc-frame-count <> object-view/function-count [
			function-id: 1
			while [function-id <= object-view/function-count][
				found?: false
				record-id: 1
				while [record-id <= view/gc-frame-count][
					if (gc-frame-value data view record-id
						schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET) = function-id
					[found?: true break]
					record-id: record-id + 1
				]
				unless found? [
					return reject result schema/WIRE_RSCG_METADATA_ERROR_MISSING_GC_FRAME
						(object-view/functions-offset
							+ ((function-id - 1) * schema/WIRE_RSCG_FUNCTION_SIZE))
						object-view/functions-ordinal
				]
				function-id: function-id + 1
			]
		]

		; Standalone objects own bitmap bytes through each explicit DATA slice.
		; A merged object containing the runtime additionally requires exact
		; coverage of its compatibility symbol.
		record-id: 1
		while [record-id <= view/gc-frame-count][
			base: record-base view/gc-frames-offset record-id schema/WIRE_RSCG_GC_FRAME_SIZE
			bitmap-section: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
			bitmap-offset: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
			bitmap-size: gc-frame-value data view record-id
				schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
			bitmap-end: bitmap-offset + bitmap-size
			if all [
				bitmap-symbol <> 0
				any [bitmap-offset < role-offset bitmap-end > role-end]
			][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ROLE_COVERAGE
					(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
					view/gc-frames-ordinal
			]
			prior-id: 1
			while [prior-id < record-id][
				prior-section: gc-frame-value data view prior-id
					schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
				prior-offset: gc-frame-value data view prior-id
					schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
				prior-size: gc-frame-value data view prior-id
					schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
				prior-end: prior-offset + prior-size
				if all [
					bitmap-section = prior-section
					bitmap-offset < prior-end
					prior-offset < bitmap-end
				][
					return reject result schema/WIRE_RSCG_METADATA_ERROR_BITMAP_OVERLAP
						(base + schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
						view/gc-frames-ordinal
				]
				prior-id: prior-id + 1
			]
			record-id: record-id + 1
		]

		if bitmap-symbol <> 0 [
			role-cursor: role-offset
			consumed: 0
			while [consumed < view/gc-frame-count][
				found?: false
				record-id: 1
				while [record-id <= view/gc-frame-count][
					if (gc-frame-value data view record-id
						schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET) = role-cursor
					[
						role-cursor: role-cursor + (gc-frame-value data view record-id
							schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET)
						found?: true
						break
					]
					record-id: record-id + 1
				]
				unless found? [break]
				consumed: consumed + 1
			]
			if any [consumed <> view/gc-frame-count role-cursor <> role-end][
				return reject result schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ROLE_COVERAGE
					(object-view/symbols-offset
						+ (((bitmap-symbol - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
						+ schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET))
					object-view/symbols-ordinal
			]
		]

		unwind-records: view/unwind-function-count
		if unwind-records > 0 [
			return reject result schema/WIRE_RSCG_METADATA_ERROR_UNSUPPORTED_UNWIND
				view/unwind-functions-offset view/unwind-functions-ordinal
		]

		result/strings: dependency/strings
		result/files: dependency/files
		result/layout: dependency/layout
		result/modules: dependency/modules
		result/object-view: object-view
		result/relocation-view: relocation-view
		result/view: view
		result/valid?: true
		result
	]
]
