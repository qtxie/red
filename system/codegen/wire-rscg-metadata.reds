Red/System [
	Title: "Hybrid compiler native RSCG debug, GC, and unwind metadata verifier"
	File:  %wire-rscg-metadata.reds
]

#include %wire-rscg-relocation.reds

wire-rscg-metadata-result!: alias struct! [
	error                  [integer!]
	relocation-error       [integer!]
	object-error            [integer!]
	container-error         [integer!]
	string-error            [integer!]
	file-source-error       [integer!]
	data-layout-error       [integer!]
	module-lifecycle-error  [integer!]
	error-offset            [integer!]
	error-section           [integer!]
]

wire-rscg-metadata!: alias struct! [
	debug-lines              [byte-ptr!]
	debug-line-count         [integer!]
	debug-lines-offset       [integer!]
	debug-lines-ordinal      [integer!]
	debug-parameters         [byte-ptr!]
	debug-parameter-count    [integer!]
	debug-parameters-offset  [integer!]
	debug-parameters-ordinal [integer!]
	gc-frames                [byte-ptr!]
	gc-frame-count           [integer!]
	gc-frames-offset         [integer!]
	gc-frames-ordinal        [integer!]
	unwind-present           [integer!]
	unwind-functions         [byte-ptr!]
	unwind-function-count    [integer!]
	unwind-functions-offset  [integer!]
	unwind-functions-ordinal [integer!]
]

wire-rscg-metadata-reader: context [
	expected-index-flags: WIRE_SECTION_FLAG_SORTED or WIRE_SECTION_FLAG_DEDUPLICATED
	expected-debug-line-flags: WIRE_SECTION_FLAG_SORTED
	expected-unwind-flags: WIRE_SECTION_FLAG_OPTIONAL or expected-index-flags

	set-error: func [
		result [wire-rscg-metadata-result!]
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

	debug-line-value: func [
		view [wire-rscg-metadata!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/debug-lines
			(((id - 1) * WIRE_RSCG_DEBUG_LINE_SIZE) + field)
	]

	debug-parameter-value: func [
		view [wire-rscg-metadata!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/debug-parameters
			(((id - 1) * WIRE_RSCG_DEBUG_PARAMETER_SIZE) + field)
	]

	gc-frame-value: func [
		view [wire-rscg-metadata!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 view/gc-frames
			(((id - 1) * WIRE_RSCG_GC_FRAME_SIZE) + field)
	]

	function-value: func [
		object-view [wire-rscg-object!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 object-view/functions
			(((id - 1) * WIRE_RSCG_FUNCTION_SIZE) + field)
	]

	output-value: func [
		object-view [wire-rscg-object!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 object-view/output-sections
			(((id - 1) * WIRE_RSCG_OUTPUT_SECTION_SIZE) + field)
	]

	symbol-value: func [
		object-view [wire-rscg-object!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 object-view/symbols
			(((id - 1) * WIRE_RSCG_SYMBOL_SIZE) + field)
	]

	relocation-value: func [
		relocation-view [wire-rscg-relocation!]
		id field [integer!]
		return: [integer!]
	][
		wire-container-reader/read-i31 relocation-view/relocations
			(((id - 1) * WIRE_RSCG_RELOCATION_SIZE) + field)
	]

	debug-code-valid?: func [code [integer!] return: [logic!]][
		any [
			all [code >= WIRE_DEBUG_TYPE_CODE_LOGIC code <= WIRE_DEBUG_TYPE_CODE_UINT32]
			code = WIRE_DEBUG_TYPE_CODE_AGGREGATE
		]
	]

	first-bad-scalar: func [
		section [wire-section-slice!]
		return: [integer!]
		/local offset value [integer!]
	][
		offset: 0
		while [offset < section/size][
			value: wire-container-reader/read-i31 section/data offset
			if value < 0 [return offset]
			offset: offset + 4
		]
		-1
	]

	word-extension?: func [
		data [byte-ptr!]
		offset [integer!]
		return: [logic!]
		/local p [byte-ptr!]
	][
		p: data + offset
		p/4 > as byte! 127
	]

	word-low31: func [data [byte-ptr!] offset [integer!] return: [integer!]][
		(wire-container-reader/read-le32 data offset) and 7FFFFFFFh
	]

	word-count-for-slots: func [slots [integer!] return: [integer!]][
		either slots = 0 [1][((slots - 1) / 31) + 1]
	]

	unused-bits?: func [word slots [integer!] return: [logic!] /local used allowed [integer!]][
		if slots = 0 [return word <> 0]
		used: slots // 31
		if used = 0 [return false]
		allowed: (1 << used) - 1
		(word and (7FFFFFFFh xor allowed)) <> 0
	]

	scan-word-chain: func [
		data [byte-ptr!]
		start finish [integer!]
		return: [integer!]
		/local cursor [integer!] extension [logic!]
	][
		cursor: start
		until [
			if cursor >= finish [return -1]
			extension: word-extension? data cursor
			cursor: cursor + 4
			not extension
		]
		cursor
	]

	copy-view: func [destination source [wire-rscg-metadata!]][
		destination/debug-lines: source/debug-lines
		destination/debug-line-count: source/debug-line-count
		destination/debug-lines-offset: source/debug-lines-offset
		destination/debug-lines-ordinal: source/debug-lines-ordinal
		destination/debug-parameters: source/debug-parameters
		destination/debug-parameter-count: source/debug-parameter-count
		destination/debug-parameters-offset: source/debug-parameters-offset
		destination/debug-parameters-ordinal: source/debug-parameters-ordinal
		destination/gc-frames: source/gc-frames
		destination/gc-frame-count: source/gc-frame-count
		destination/gc-frames-offset: source/gc-frames-offset
		destination/gc-frames-ordinal: source/gc-frames-ordinal
		destination/unwind-present: source/unwind-present
		destination/unwind-functions: source/unwind-functions
		destination/unwind-function-count: source/unwind-function-count
		destination/unwind-functions-offset: source/unwind-functions-offset
		destination/unwind-functions-ordinal: source/unwind-functions-ordinal
	]

	verify: func [
		data [byte-ptr!]
		size [integer!]
		result [wire-rscg-metadata-result!]
		strings [wire-string-table!]
		files [wire-file-source!]
		layout [wire-data-layout!]
		modules [wire-module-lifecycle!]
		object-output [wire-rscg-object!]
		relocation-output [wire-rscg-relocation!]
		output [wire-rscg-metadata!]
		return: [integer!]
		/local dependency-result [wire-rscg-relocation-result!]
			verified-strings [wire-string-table!]
			verified-files [wire-file-source!]
			verified-layout [wire-data-layout!]
			verified-modules [wire-module-lifecycle!]
			object-view [wire-rscg-object!]
			relocation-view [wire-rscg-relocation!]
			container-result [wire-container-result!]
			debug-lines debug-parameters gc-frames unwind [wire-section-slice!]
			view [wire-rscg-metadata!]
			status bad-relative record-id record-offset function-id code-offset file-id
			line-number previous-function previous-code first count cursor expected
			record-function ordinal type-code flags previous-ordinal bitmap-symbol
			role-section role-offset role-size role-end bitmap-section bitmap-offset
			bitmap-size bitmap-end section-file-size section-data-offset bitmap-absolute
			arg-slots local-slots arg-start arg-end arg-word-count local-start local-end
			local-word-count expected-words first-word last-word function-code-section
			function-code-offset function-code-size patch-offset patch-section-offset
			code-data-offset patch-data-offset relocation-id relocation-section
			relocation-offset relocation-width prior-id prior-offset prior-size prior-end
			prior-section role-cursor consumed [integer!]
			bitmap-data code-data p [byte-ptr!]
			unwind-present dynamic found [logic!]
	][
		if null? result [return WIRE_RSCG_METADATA_ERROR_INVALID_ARGUMENTS]
		result/error: WIRE_RSCG_METADATA_ERROR_SUCCESS
		result/relocation-error: WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		result/object-error: WIRE_RSCG_OBJECT_ERROR_SUCCESS
		result/container-error: WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error: WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error: WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error: WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/module-lifecycle-error: WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/error-offset: 0
		result/error-section: 0
		if any [
			size < 0 null? data null? strings null? files null? layout null? modules
			null? object-output null? relocation-output null? output
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_ARGUMENTS 0 0
		]

		dependency-result: declare wire-rscg-relocation-result!
		verified-strings: declare wire-string-table!
		verified-files: declare wire-file-source!
		verified-layout: declare wire-data-layout!
		verified-modules: declare wire-module-lifecycle!
		object-view: declare wire-rscg-object!
		relocation-view: declare wire-rscg-relocation!
		status: wire-rscg-relocation-reader/verify data size dependency-result
			verified-strings verified-files verified-layout verified-modules
			object-view relocation-view
		result/relocation-error: dependency-result/error
		result/object-error: dependency-result/object-error
		result/container-error: dependency-result/container-error
		result/string-error: dependency-result/string-error
		result/file-source-error: dependency-result/file-source-error
		result/data-layout-error: dependency-result/data-layout-error
		result/module-lifecycle-error: dependency-result/module-lifecycle-error
		if status <> WIRE_RSCG_RELOCATION_ERROR_SUCCESS [
			if all [
				status = WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
				dependency-result/object-error = WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
			][
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_RANGE
					dependency-result/error-offset dependency-result/error-section
			]
			if all [
				status = WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
				dependency-result/object-error = WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
			][
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_RANGE
					dependency-result/error-offset dependency-result/error-section
			]
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
				dependency-result/error-offset dependency-result/error-section
		]

		container-result: declare wire-container-result!
		status: wire-container-reader/verify data size WIRE_MAGIC_RSCG container-result
		if status <> WIRE_CONTAINER_ERROR_SUCCESS [
			result/container-error: status
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
				container-result/error-offset container-result/error-section
		]
		debug-lines: declare wire-section-slice!
		debug-parameters: declare wire-section-slice!
		gc-frames: declare wire-section-slice!
		unwind: declare wire-section-slice!
		unless wire-container-reader/find-verified-section
			data WIRE_RSCG_SECTION_DEBUG_LINES debug-lines
		[
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSCG_SECTION_DEBUG_PARAMETERS debug-parameters
		[
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
				WIRE_HEADER_SIZE 0
		]
		unless wire-container-reader/find-verified-section
			data WIRE_RSCG_SECTION_GC_FRAMES gc-frames
		[
			return set-error result WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
				WIRE_HEADER_SIZE 0
		]
		unwind-present: wire-container-reader/find-verified-section
			data WIRE_RSCG_SECTION_UNWIND_FUNCTIONS unwind

		if debug-lines/flags <> expected-debug-line-flags [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_SECTION_FLAGS
				section-flags-offset debug-lines debug-lines/ordinal
		]
		if debug-parameters/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_SECTION_FLAGS
				section-flags-offset debug-parameters debug-parameters/ordinal
		]
		if gc-frames/flags <> expected-index-flags [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_SECTION_FLAGS
				section-flags-offset gc-frames gc-frames/ordinal
		]
		if all [unwind-present unwind/flags <> expected-unwind-flags][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_UNWIND_SECTION_FLAGS
				section-flags-offset unwind unwind/ordinal
		]

		view: declare wire-rscg-metadata!
		view/debug-lines: debug-lines/data
		view/debug-line-count: debug-lines/record-count
		view/debug-lines-offset: debug-lines/offset
		view/debug-lines-ordinal: debug-lines/ordinal
		view/debug-parameters: debug-parameters/data
		view/debug-parameter-count: debug-parameters/record-count
		view/debug-parameters-offset: debug-parameters/offset
		view/debug-parameters-ordinal: debug-parameters/ordinal
		view/gc-frames: gc-frames/data
		view/gc-frame-count: gc-frames/record-count
		view/gc-frames-offset: gc-frames/offset
		view/gc-frames-ordinal: gc-frames/ordinal
		either unwind-present [
			view/unwind-present: 1
			view/unwind-functions: unwind/data
			view/unwind-function-count: unwind/record-count
			view/unwind-functions-offset: unwind/offset
			view/unwind-functions-ordinal: unwind/ordinal
		][
			view/unwind-present: 0
			view/unwind-functions: as byte-ptr! 0
			view/unwind-function-count: 0
			view/unwind-functions-offset: 0
			view/unwind-functions-ordinal: 0
		]

		bad-relative: first-bad-scalar debug-lines
		if bad-relative >= 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
				(debug-lines/offset + bad-relative) debug-lines/ordinal
		]
		bad-relative: first-bad-scalar debug-parameters
		if bad-relative >= 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
				(debug-parameters/offset + bad-relative) debug-parameters/ordinal
		]
		bad-relative: first-bad-scalar gc-frames
		if bad-relative >= 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
				(gc-frames/offset + bad-relative) gc-frames/ordinal
		]
		if unwind-present [
			bad-relative: first-bad-scalar unwind
			if bad-relative >= 0 [
				return set-error result WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
					(unwind/offset + bad-relative) unwind/ordinal
			]
		]

		previous-function: 0
		previous-code: 0
		record-id: 1
		while [record-id <= view/debug-line-count][
			record-offset: (record-id - 1) * WIRE_RSCG_DEBUG_LINE_SIZE
			function-id: debug-line-value view record-id WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
			code-offset: debug-line-value view record-id WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET
			file-id: debug-line-value view record-id WIRE_RSCG_DEBUG_LINE_FILE_OFFSET
			line-number: debug-line-value view record-id WIRE_RSCG_DEBUG_LINE_LINE_OFFSET
			if any [function-id <= 0 function-id > object-view/function-count][
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_FUNCTION
					(debug-lines/offset + record-offset + WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET)
					debug-lines/ordinal
			]
			if any [
				function-id < previous-function
				all [function-id = previous-function code-offset < previous-code]
			][
				return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_ORDER
					(debug-lines/offset + record-offset + WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET)
					debug-lines/ordinal
			]
			if code-offset >= (function-value object-view function-id
				WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET)
			[
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_CODE_OFFSET
					(debug-lines/offset + record-offset + WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET)
					debug-lines/ordinal
			]
			if any [file-id <= 0 file-id > verified-files/file-count][
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_FILE
					(debug-lines/offset + record-offset + WIRE_RSCG_DEBUG_LINE_FILE_OFFSET)
					debug-lines/ordinal
			]
			if line-number <= 0 [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_NUMBER
					(debug-lines/offset + record-offset + WIRE_RSCG_DEBUG_LINE_LINE_OFFSET)
					debug-lines/ordinal
			]
			previous-function: function-id
			previous-code: code-offset
			record-id: record-id + 1
		]

		cursor: 1
		function-id: 1
		while [function-id <= object-view/function-count][
			first: function-value object-view function-id WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
			count: function-value object-view function-id WIRE_RSCG_FUNCTION_DEBUG_LINE_COUNT_OFFSET
			if count > 0 [
				if first <> cursor [
					return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
						(object-view/functions-offset
							+ (((function-id - 1) * WIRE_RSCG_FUNCTION_SIZE)
							+ WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET))
						object-view/functions-ordinal
				]
				expected: 0
				while [expected < count][
					record-id: first + expected
					record-function: debug-line-value view record-id
						WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
					if record-function <> function-id [
						return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
							(debug-lines/offset
								+ (((record-id - 1) * WIRE_RSCG_DEBUG_LINE_SIZE)
								+ WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET))
							debug-lines/ordinal
					]
					expected: expected + 1
				]
				cursor: first + count
			]
			function-id: function-id + 1
		]
		if cursor <> (view/debug-line-count + 1) [
			return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
				view/debug-lines-offset view/debug-lines-ordinal
		]

		previous-function: 0
		previous-ordinal: 0
		record-id: 1
		while [record-id <= view/debug-parameter-count][
			record-offset: (record-id - 1) * WIRE_RSCG_DEBUG_PARAMETER_SIZE
			function-id: debug-parameter-value view record-id
				WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET
			ordinal: debug-parameter-value view record-id WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET
			type-code: debug-parameter-value view record-id
				WIRE_RSCG_DEBUG_PARAMETER_DEBUG_TYPE_CODE_OFFSET
			flags: debug-parameter-value view record-id WIRE_RSCG_DEBUG_PARAMETER_FLAGS_OFFSET
			if any [function-id <= 0 function-id > object-view/function-count][
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FUNCTION
					(debug-parameters/offset + record-offset
						+ WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET)
					debug-parameters/ordinal
			]
			expected: either function-id = previous-function [previous-ordinal + 1][0]
			if ordinal <> expected [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_ORDINAL
					(debug-parameters/offset + record-offset
						+ WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET)
					debug-parameters/ordinal
			]
			if ordinal >= (function-value object-view function-id
				WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET)
			[
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_ORDINAL
					(debug-parameters/offset + record-offset
						+ WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET)
					debug-parameters/ordinal
			]
			unless debug-code-valid? type-code [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_TYPE_CODE
					(debug-parameters/offset + record-offset
						+ WIRE_RSCG_DEBUG_PARAMETER_DEBUG_TYPE_CODE_OFFSET)
					debug-parameters/ordinal
			]
			if flags <> WIRE_RSCG_DEBUG_PARAMETER_FLAG_NONE [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FLAGS
					(debug-parameters/offset + record-offset
						+ WIRE_RSCG_DEBUG_PARAMETER_FLAGS_OFFSET)
					debug-parameters/ordinal
			]
			previous-function: function-id
			previous-ordinal: ordinal
			record-id: record-id + 1
		]

		cursor: 1
		function-id: 1
		while [function-id <= object-view/function-count][
			first: function-value object-view function-id
				WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
			count: function-value object-view function-id
				WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET
			if count > 0 [
				if first <> cursor [
					return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
						(object-view/functions-offset
							+ (((function-id - 1) * WIRE_RSCG_FUNCTION_SIZE)
							+ WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET))
						object-view/functions-ordinal
				]
				expected: 0
				while [expected < count][
					record-id: first + expected
					record-function: debug-parameter-value view record-id
						WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET
					if record-function <> function-id [
						return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
							(debug-parameters/offset
								+ (((record-id - 1) * WIRE_RSCG_DEBUG_PARAMETER_SIZE)
								+ WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET))
							debug-parameters/ordinal
					]
					expected: expected + 1
				]
				cursor: first + count
			]
			function-id: function-id + 1
		]
		if cursor <> (view/debug-parameter-count + 1) [
			return set-error result WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
				view/debug-parameters-offset view/debug-parameters-ordinal
		]

		bitmap-symbol: object-view/bitmap-symbol
	role-section: 0
	role-offset: 0
	role-size: 0
	if bitmap-symbol <> 0 [
		role-section: symbol-value object-view bitmap-symbol WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		role-offset: symbol-value object-view bitmap-symbol WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		role-size: symbol-value object-view bitmap-symbol WIRE_RSCG_SYMBOL_SIZE_OFFSET
	]
	role-end: role-offset + role-size

	previous-function: 0
	record-id: 1
	while [record-id <= view/gc-frame-count][
		record-offset: (record-id - 1) * WIRE_RSCG_GC_FRAME_SIZE
		function-id: gc-frame-value view record-id WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
		bitmap-section: gc-frame-value view record-id
			WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
		bitmap-offset: gc-frame-value view record-id
			WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
		bitmap-size: gc-frame-value view record-id
			WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
		flags: gc-frame-value view record-id WIRE_RSCG_GC_FRAME_FLAGS_OFFSET
		patch-offset: gc-frame-value view record-id
			WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET

		if any [function-id <= 0 function-id > object-view/function-count][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_GC_FUNCTION
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
				gc-frames/ordinal
		]
		if function-id < previous-function [
			return set-error result WIRE_RSCG_METADATA_ERROR_GC_FRAME_ORDER
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
				gc-frames/ordinal
		]
		if function-id = previous-function [
			return set-error result WIRE_RSCG_METADATA_ERROR_DUPLICATE_GC_FUNCTION
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
				gc-frames/ordinal
		]
		unless any [
			flags = 0
			flags = WIRE_RSCG_GC_FRAME_FLAG_LIBRARY_IMAGE
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_FLAGS
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_FLAGS_OFFSET)
				gc-frames/ordinal
		]
		if any [
			bitmap-section <= 0
			bitmap-section > object-view/output-section-count
			all [
				bitmap-section <= object-view/output-section-count
				(output-value object-view bitmap-section
					WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET)
					<> WIRE_OUTPUT_SECTION_CLASS_DATA
			]
			all [bitmap-symbol <> 0 bitmap-section <> role-section]
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SECTION
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET)
				gc-frames/ordinal
		]
		if (bitmap-offset // 4) <> 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ALIGNMENT
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
				gc-frames/ordinal
		]
		if any [bitmap-size < 16 (bitmap-size // 4) <> 0][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SIZE
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET)
				gc-frames/ordinal
		]
		section-file-size: output-value object-view bitmap-section
			WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
		if any [
			bitmap-offset > section-file-size
			bitmap-size > (section-file-size - bitmap-offset)
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_RANGE
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
				gc-frames/ordinal
		]
		bitmap-end: bitmap-offset + bitmap-size
		section-data-offset: output-value object-view bitmap-section
			WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
		bitmap-absolute: object-view/output-data-offset + section-data-offset + bitmap-offset
		bitmap-data: object-view/output-data + section-data-offset + bitmap-offset
		if word-extension? bitmap-data 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
				bitmap-absolute object-view/output-data-ordinal
		]
		if word-extension? bitmap-data 4 [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
				(bitmap-absolute + 4) object-view/output-data-ordinal
		]
		arg-slots: wire-container-reader/read-le32 bitmap-data 0
		local-slots: wire-container-reader/read-le32 bitmap-data 4
		arg-start: 8
		arg-end: scan-word-chain bitmap-data arg-start bitmap-size
		if arg-end < 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
				(bitmap-absolute + arg-start) object-view/output-data-ordinal
		]
		local-start: arg-end
		local-end: scan-word-chain bitmap-data local-start bitmap-size
		if local-end < 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
				(bitmap-absolute + local-start) object-view/output-data-ordinal
		]
		if local-end <> bitmap-size [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
				(bitmap-absolute + local-end) object-view/output-data-ordinal
		]

		first-word: word-low31 bitmap-data arg-start
		dynamic: any [first-word = 40000000h first-word = 20000000h]
		arg-word-count: (arg-end - arg-start) / 4
		local-word-count: (local-end - local-start) / 4
		either dynamic [
			if arg-word-count <> 1 [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
					(bitmap-absolute + arg-start) object-view/output-data-ordinal
			]
			if arg-slots <> 0 [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
					bitmap-absolute object-view/output-data-ordinal
			]
		][
			expected-words: word-count-for-slots arg-slots
			if arg-word-count <> expected-words [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
					bitmap-absolute object-view/output-data-ordinal
			]
			last-word: word-low31 bitmap-data
				(arg-start + ((arg-word-count - 1) * 4))
			if unused-bits? last-word arg-slots [
				return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_UNUSED_BITS
					(bitmap-absolute + arg-start + ((arg-word-count - 1) * 4))
					object-view/output-data-ordinal
			]
		]
		expected-words: word-count-for-slots local-slots
		if local-word-count <> expected-words [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
				(bitmap-absolute + 4) object-view/output-data-ordinal
		]
		last-word: word-low31 bitmap-data
			(local-start + ((local-word-count - 1) * 4))
		if unused-bits? last-word local-slots [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_UNUSED_BITS
				(bitmap-absolute + local-start + ((local-word-count - 1) * 4))
				object-view/output-data-ordinal
		]

		function-code-section: function-value object-view function-id
			WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
		function-code-offset: function-value object-view function-id
			WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
		function-code-size: function-value object-view function-id
			WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
		if any [
			patch-offset <= 0
			patch-offset > function-code-size
			4 > (function-code-size - patch-offset)
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_PATCH
				(gc-frames/offset + record-offset
					+ WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET)
				gc-frames/ordinal
		]
		patch-section-offset: function-code-offset + patch-offset
		code-data-offset: output-value object-view function-code-section
			WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
		code-data: object-view/output-data + code-data-offset + patch-section-offset
		p: code-data - 1
		if p/1 <> as byte! 68h [
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_OPCODE
				(object-view/output-data-offset + code-data-offset
					+ patch-section-offset - 1)
				object-view/output-data-ordinal
		]
		patch-data-offset: object-view/output-data-offset + code-data-offset
			+ patch-section-offset
		bad-relative: wire-container-reader/first-nonzero data patch-data-offset
			(patch-data-offset + 4)
		if bad-relative >= 0 [
			return set-error result WIRE_RSCG_METADATA_ERROR_NONZERO_PROLOG_PLACEHOLDER
				patch-data-offset object-view/output-data-ordinal
		]

		relocation-id: 1
		while [relocation-id <= relocation-view/relocation-count][
			relocation-section: relocation-value relocation-view relocation-id
				WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
			relocation-offset: relocation-value relocation-view relocation-id
				WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
			relocation-width: relocation-value relocation-view relocation-id
				WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
			if all [
				relocation-section = function-code-section
				relocation-offset < (patch-section-offset + 4)
				patch-section-offset < (relocation-offset + relocation-width)
			][
				return set-error result WIRE_RSCG_METADATA_ERROR_PROLOG_RELOCATION_CONFLICT
					(relocation-view/relocations-offset
						+ (((relocation-id - 1) * WIRE_RSCG_RELOCATION_SIZE)
						+ WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET))
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
			found: false
			record-id: 1
			while [record-id <= view/gc-frame-count][
				if (gc-frame-value view record-id WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET)
					= function-id [found: true break]
				record-id: record-id + 1
			]
			unless found [
				return set-error result WIRE_RSCG_METADATA_ERROR_MISSING_GC_FRAME
					(object-view/functions-offset
						+ ((function-id - 1) * WIRE_RSCG_FUNCTION_SIZE))
					object-view/functions-ordinal
			]
			function-id: function-id + 1
		]
	]

	; Standalone objects own bitmap bytes through each explicit DATA slice.
	; Runtime-containing objects additionally require compatibility-role coverage.
	record-id: 1
	while [record-id <= view/gc-frame-count][
		record-offset: (record-id - 1) * WIRE_RSCG_GC_FRAME_SIZE
		bitmap-section: gc-frame-value view record-id
			WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
		bitmap-offset: gc-frame-value view record-id WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
		bitmap-size: gc-frame-value view record-id WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
		bitmap-end: bitmap-offset + bitmap-size
		if all [
			bitmap-symbol <> 0
			any [bitmap-offset < role-offset bitmap-end > role-end]
		][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ROLE_COVERAGE
				(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
				gc-frames/ordinal
		]
		prior-id: 1
		while [prior-id < record-id][
			prior-section: gc-frame-value view prior-id
				WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
			prior-offset: gc-frame-value view prior-id WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
			prior-size: gc-frame-value view prior-id WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
			prior-end: prior-offset + prior-size
			if all [
				bitmap-section = prior-section
				bitmap-offset < prior-end
				prior-offset < bitmap-end
			][
				return set-error result WIRE_RSCG_METADATA_ERROR_BITMAP_OVERLAP
					(gc-frames/offset + record-offset + WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
					gc-frames/ordinal
			]
			prior-id: prior-id + 1
		]
		record-id: record-id + 1
	]

	if bitmap-symbol <> 0 [
		role-cursor: role-offset
		consumed: 0
		while [consumed < view/gc-frame-count][
			found: false
			record-id: 1
			while [record-id <= view/gc-frame-count][
				if (gc-frame-value view record-id WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET)
					= role-cursor [
					role-cursor: role-cursor + (gc-frame-value view record-id
						WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET)
					found: true
					break
				]
				record-id: record-id + 1
			]
			unless found [break]
			consumed: consumed + 1
		]
		if any [consumed <> view/gc-frame-count role-cursor <> role-end][
			return set-error result WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ROLE_COVERAGE
				(object-view/symbols-offset
					+ (((bitmap-symbol - 1) * WIRE_RSCG_SYMBOL_SIZE)
					+ WIRE_RSCG_SYMBOL_SIZE_OFFSET))
				object-view/symbols-ordinal
		]
	]

	if view/unwind-function-count > 0 [
		return set-error result WIRE_RSCG_METADATA_ERROR_UNSUPPORTED_UNWIND
			view/unwind-functions-offset view/unwind-functions-ordinal
	]

	wire-rscg-object-reader/copy-strings strings verified-strings
	wire-rscg-object-reader/copy-files files verified-files
	wire-rscg-object-reader/copy-layout layout verified-layout
	wire-rscg-object-reader/copy-modules modules verified-modules
	wire-rscg-object-reader/copy-view object-output object-view
	wire-rscg-relocation-reader/copy-relocation-view relocation-output relocation-view
	copy-view output view
	result/error: WIRE_RSCG_METADATA_ERROR_SUCCESS
	WIRE_RSCG_METADATA_ERROR_SUCCESS
	]
]
