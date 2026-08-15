Red [
	Title: "Hybrid compiler RSCG to legacy linker adapter"
	File:  %rscg-linker-adapter.red
]

unless value? 'int-to-bin [do %int-to-bin.red]
unless value? 'compiler-wire-container [do %wire-container.red]

; This first compatibility slice is deliberately smaller than the RSCG
; protocol. Native codegen verifies the complete RSCG semantics before return.
; This adapter independently checks the container and every field it consumes,
; then rejects every unrepresentable feature before mutating the linker job.
compiler-rscg-linker-adapter: context [
	schema: compiler-wire-schema
	container: compiler-wire-container
	INDEX-FLAGS:
		schema/WIRE_SECTION_FLAG_SORTED
		+ schema/WIRE_SECTION_FLAG_DEDUPLICATED

	section-spec: reduce [
		'data-layout       schema/WIRE_RSCG_SECTION_DATA_LAYOUT
		'strings           schema/WIRE_RSCG_SECTION_STRINGS
		'string-data       schema/WIRE_RSCG_SECTION_STRING_DATA
		'output-sections   schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
		'output-data       schema/WIRE_RSCG_SECTION_OUTPUT_DATA
		'symbols           schema/WIRE_RSCG_SECTION_SYMBOLS
		'relocations       schema/WIRE_RSCG_SECTION_RELOCATIONS
		'imports           schema/WIRE_RSCG_SECTION_IMPORTS
		'exports           schema/WIRE_RSCG_SECTION_EXPORTS
		'functions         schema/WIRE_RSCG_SECTION_FUNCTIONS
		'files             schema/WIRE_RSCG_SECTION_FILES
		'file-checksums    schema/WIRE_RSCG_SECTION_FILE_CHECKSUM_DATA
		'debug-lines       schema/WIRE_RSCG_SECTION_DEBUG_LINES
		'debug-parameters  schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS
		'gc-frames         schema/WIRE_RSCG_SECTION_GC_FRAMES
		'modules           schema/WIRE_RSCG_SECTION_MODULES
		'unwind            schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS
	]

	ERROR-SUCCESS: 0
	ERROR-ARGUMENTS: 1
	ERROR-INVALID-RSCG: 2
	ERROR-UNSUPPORTED-JOB: 3
	ERROR-UNSUPPORTED-FEATURE: 4
	ERROR-LIFECYCLE: 5
	ERROR-SECTION: 6
	ERROR-SYMBOL: 7
	ERROR-GC-FRAME: 8
	ERROR-IMPORT: 9
	ERROR-RELOCATION: 10

	last-error: none
	last-result: none

	set-error: func [
		code [integer!]
		message [string!]
		/at offset section [integer!]
		/local record
	][
		record: make object! [
			code: 0
			message: none
			offset: 0
			section: 0
		]
		record/code: code
		record/message: message
		if at [
			record/offset: offset
			record/section: section
		]
		last-error: record
		last-result: none
		none
	]

	required-job-shape?: func [job [object!] /local name][
		foreach name [
			format OS target ABI type link? runtime? debug? PIC? PIE? static-link?
			red-pass? libRed? libRedRT? libRedRT-update? sections symbols debug-info
		][
			unless in job name [return false]
		]
		all [
			job/format = 'PE
			job/OS = 'Windows
			job/target = 'X86-64
			job/ABI = 'win64
			job/type = 'exe
			job/link?
			not job/runtime?
			not job/debug?
			not job/PIC?
			not job/PIE?
			not job/static-link?
			not job/red-pass?
			not job/libRed?
			not job/libRedRT?
			not job/libRedRT-update?
		]
	]

	open-view: func [
		data [binary!]
		/local verified header view name kind section
	][
		verified: container/verify/expect data schema/WIRE_MAGIC_RSCG
		unless verified/valid? [
			set-error/at ERROR-INVALID-RSCG
				rejoin ["invalid RSCG container: " verified/error]
				verified/error-offset verified/error-section
			return none
		]
		header: verified/header
		unless all [
			(select header 'target) = schema/WIRE_TARGET_X86_64
			(select header 'abi) = schema/WIRE_ABI_WIN64
			(select header 'target-endian) = schema/WIRE_ENDIAN_LITTLE
			(select header 'pointer-size) = 8
			(select header 'feature-mask-low) = 0
			(select header 'feature-mask-high) = 0
		][
			set-error ERROR-INVALID-RSCG
				"RSCG linker adapter requires the baseline Windows x64 data layout"
			return none
		]

		view: make object! [
			container-result: none
			data-layout: none
			strings: none
			string-data: none
			output-sections: none
			output-data: none
			symbols: none
			relocations: none
			imports: none
			exports: none
			functions: none
			files: none
			file-checksums: none
			debug-lines: none
			debug-parameters: none
			gc-frames: none
			modules: none
			unwind: none
		]
		view/container-result: verified
		foreach [name kind] section-spec [
			section: container/find-section verified kind
			if all [name <> 'unwind none? section][
				set-error ERROR-INVALID-RSCG "RSCG is missing a required adapter section"
				return none
			]
			set in view name section
		]
		view
	]

	section-count: func [section [map! none!]][
		either section [select section 'record-count][0]
	]

	section-flags: func [section [map! none!]][
		either section [select section 'flags][0]
	]

	record-value: func [
		data [binary!]
		section [map! none!]
		id field-offset [integer!]
		/local count record-size record-offset
	][
		if none? section [return none]
		count: select section 'record-count
		if any [id <= 0 id > count][return none]
		record-size: select section 'record-size
		if any [field-offset < 0 (field-offset + 4) > record-size][return none]
		record-offset: (select section 'payload-offset)
			+ ((id - 1) * record-size)
		container/read-i31 data (record-offset + field-offset)
	]

	string-at: func [
		data [binary!]
		view [object!]
		id [integer!]
		/local relative size data-size bytes
	][
		relative: record-value data view/strings id schema/WIRE_STRING_OFFSET_OFFSET
		size: record-value data view/strings id schema/WIRE_STRING_SIZE_OFFSET
		if any [none? relative none? size][return none]
		data-size: select view/string-data 'payload-size
		if any [size > data-size relative > (data-size - size)][return none]
		bytes: copy/part at data
			((select view/string-data 'payload-offset) + relative + 1) size
		to string! bytes
	]

	copy-output-section: func [
		data [binary!]
		view [object!]
		section-id [integer!]
		/local relative size
	][
		relative: record-value data view/output-sections section-id
			schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
		size: record-value data view/output-sections section-id
			schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
		if any [none? relative none? size][return none]
		if any [
			size > (select view/output-data 'payload-size)
			relative > ((select view/output-data 'payload-size) - size)
		][return none]
		copy/part at data
			((select view/output-data 'payload-offset) + relative + 1) size
	]

	make-linker-sections: func [
		code data [binary!]
		library external [string!]
		reference [integer!]
		/local sections imports functions references
	][
		references: reduce [reference]
		functions: make block! 2
		append functions external
		append/only functions references
		imports: make block! 2
		append imports library
		append/only imports functions
		sections: make block! 6
		append sections 'code
		append/only sections reduce ['- code]
		append sections 'data
		append/only sections reduce ['- data]
		append sections 'import
		append/only sections reduce ['- '- imports]
		sections
	]

	make-linker-symbols: func [name [word!] code-offset [integer!] /local symbols spec][
		symbols: make hash! 4
		spec: reduce ['native (code-offset + 1) make block! 0]
		append symbols name
		append/only symbols spec
		symbols
	]

	prepare: func [
		artifact job
		/local view section-id class code-section data-section name-id section-name
			output-flags output-alignment output-relative output-size output-memory
			output-reserved output-cursor code data module-kind image-kind initializer
			finalizer entry-symbol module-flags module-reserved symbol-kind
			symbol-binding symbol-visibility symbol-section symbol-offset symbol-size
			symbol-alignment symbol-flags symbol-origin function-symbol function-section
			function-offset function-size function-frame-size function-flags
			function-first-line function-line-count function-first-parameter
			function-parameter-count function-name function-word gc-function
			bitmap-section bitmap-offset bitmap-size gc-flags patch-offset
			bitmap-word-offset import-symbol import-kind import-binding
			import-visibility import-output import-offset import-size import-alignment
			import-flags import-origin library-id external-id library-name external-name
			calling-convention import-record-flags import-source
			relocation-source-section relocation-source-offset relocation-kind
			relocation-target relocation-addend-low relocation-addend-high
			relocation-width relocation-flags prepared
	][
		last-error: none
		last-result: none
		unless all [binary? artifact object? job][
			return set-error ERROR-ARGUMENTS
				"RSCG linker adapter requires a binary artifact and linker job"
		]
		unless required-job-shape? job [
			return set-error ERROR-UNSUPPORTED-JOB
				"RSCG linker adapter supports only linked, runtime-free Windows x64 PE executables"
		]

		view: open-view artifact
		unless object? view [return none]
		module-kind: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_KIND_OFFSET
		image-kind: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_IMAGE_KIND_OFFSET
		initializer: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
		finalizer: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_FINALIZER_SYMBOL_OFFSET
		entry-symbol: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
		module-flags: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_FLAGS_OFFSET
		module-reserved: record-value artifact view/modules 1
			schema/WIRE_RSCG_MODULE_RESERVED_OFFSET
		unless all [
			module-kind = schema/WIRE_MODULE_KIND_GLUE
			image-kind = schema/WIRE_IMAGE_KIND_EXECUTABLE
			initializer = 0
			finalizer = 0
			integer? entry-symbol
			entry-symbol > 0
			entry-symbol <= (section-count view/symbols)
			module-flags = 0
			module-reserved = 0
		][
			return set-error ERROR-LIFECYCLE
				"RSCG executable adapter requires one explicit GLUE entry module"
		]
		unless all [
			(section-count view/data-layout) = 1
			(section-count view/output-sections) = 2
			(section-count view/symbols) = 2
			(section-count view/functions) = 1
			(section-count view/relocations) = 1
			(section-count view/imports) = 1
			(section-count view/exports) = 0
			(section-count view/debug-lines) = 0
			(section-count view/debug-parameters) = 0
			(section-count view/gc-frames) = 1
			(section-count view/files) = 0
			(section-count view/file-checksums) = 0
			(section-count view/modules) = 1
			(section-count view/unwind) = 0
		][
			return set-error ERROR-UNSUPPORTED-FEATURE
				"RSCG linker adapter slice supports one entry function, one exit import relocation, and no exports, debug, runtime, or unwind data"
		]
		unless all [
			(section-flags view/data-layout) = 0
			(section-flags view/strings) = INDEX-FLAGS
			(section-flags view/string-data) = 0
			(section-flags view/output-sections) = INDEX-FLAGS
			(section-flags view/output-data) = 0
			(section-flags view/symbols) = schema/WIRE_SECTION_FLAG_SORTED
			(section-flags view/relocations) = INDEX-FLAGS
			(section-flags view/imports) = INDEX-FLAGS
			(section-flags view/exports) = INDEX-FLAGS
			(section-flags view/functions) = INDEX-FLAGS
			(section-flags view/files) = INDEX-FLAGS
			(section-flags view/file-checksums) = 0
			(section-flags view/debug-lines) = schema/WIRE_SECTION_FLAG_SORTED
			(section-flags view/debug-parameters) = INDEX-FLAGS
			(section-flags view/gc-frames) = INDEX-FLAGS
			(section-flags view/modules) = 0
			any [
				none? view/unwind
				(section-flags view/unwind) =
					(schema/WIRE_SECTION_FLAG_OPTIONAL + INDEX-FLAGS)
			]
		][
			return set-error ERROR-INVALID-RSCG
				"RSCG adapter sections use unsupported ordering flags"
		]
		unless all [
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET) = 1
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET) = 8
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET) = 8
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET) = 16
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET) = 8
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET) = 8
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET) = 8
			(record-value artifact view/data-layout 1
				schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET) = 0
		][
			return set-error ERROR-INVALID-RSCG
				"RSCG adapter received an incompatible data-layout record"
		]

		code-section: 0
		data-section: 0
		output-cursor: 0
		section-id: 1
		while [section-id <= (section-count view/output-sections)][
			class: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
			name-id: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
			output-flags: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET
			output-alignment: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET
			output-relative: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
			output-size: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
			output-memory: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
			output-reserved: record-value artifact view/output-sections section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET
			section-name: either integer? name-id [string-at artifact view name-id][none]
			unless all [
				integer? class
				integer? output-flags
				integer? output-alignment
				integer? output-relative
				integer? output-size
				integer? output-memory
				integer? output-reserved
				output-flags = schema/WIRE_RSCG_OUTPUT_SECTION_FLAG_NONE
				output-relative = output-cursor
				output-size > 0
				output-memory = output-size
				output-reserved = 0
			][
				return set-error ERROR-SECTION
					"RSCG output section has an invalid initialized-data extent"
			]
			case [
				all [
					class = schema/WIRE_OUTPUT_SECTION_CLASS_CODE
					section-name = ".text"
					output-alignment = 16
					code-section = 0
				][code-section: section-id]
				all [
					class = schema/WIRE_OUTPUT_SECTION_CLASS_DATA
					section-name = ".data"
					output-alignment = 4
					data-section = 0
				][data-section: section-id]
				true [
					return set-error ERROR-SECTION
						"RSCG linker adapter slice requires exactly one .text and one .data section"
				]
			]
			output-cursor: output-cursor + output-size
			section-id: section-id + 1
		]
		if any [
			code-section = 0
			data-section = 0
			output-cursor <> (section-count view/output-data)
		][
			return set-error ERROR-SECTION
				"RSCG linker adapter could not establish exact output-data coverage"
		]

		symbol-kind: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
		symbol-binding: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
		symbol-visibility: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
		symbol-section: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		symbol-offset: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		symbol-size: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
		symbol-alignment: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
		symbol-flags: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
		symbol-origin: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET
		unless all [
			symbol-kind = schema/WIRE_SYMBOL_KIND_FUNCTION
			symbol-binding = schema/WIRE_SYMBOL_BINDING_LOCAL
			symbol-visibility = schema/WIRE_VISIBILITY_HIDDEN
			symbol-section = code-section
			symbol-offset = 0
			integer? symbol-size
			symbol-size > 0
			symbol-alignment = 16
			symbol-flags = 0
			symbol-origin = 1
		][
			return set-error ERROR-SYMBOL
				"legacy PE executable entry must be a function at .text offset zero"
		]

		function-symbol: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
		function-section: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
		function-offset: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
		function-size: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
		function-frame-size: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET
		function-flags: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_FLAGS_OFFSET
		function-first-line: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
		function-line-count: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_DEBUG_LINE_COUNT_OFFSET
		function-first-parameter: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
		function-parameter-count: record-value artifact view/functions 1
			schema/WIRE_RSCG_FUNCTION_DEBUG_PARAMETER_COUNT_OFFSET
		unless all [
			function-symbol = entry-symbol
			function-section = code-section
			function-offset = symbol-offset
			function-size = symbol-size
			integer? function-frame-size
			function-flags = schema/WIRE_RSCG_FUNCTION_FLAG_NONE
			function-first-line = 0
			function-line-count = 0
			function-first-parameter = 0
			function-parameter-count = 0
		][
			return set-error ERROR-SYMBOL
				"RSCG entry function extent does not match its symbol"
		]
		name-id: record-value artifact view/symbols entry-symbol
			schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
		function-name: either integer? name-id [string-at artifact view name-id][none]
		function-word: either string? function-name [attempt [to word! function-name]][none]
		unless word? function-word [
			return set-error ERROR-SYMBOL
				"RSCG entry symbol name cannot be represented by the legacy linker"
		]

		import-symbol: record-value artifact view/imports 1
			schema/WIRE_IMPORT_SYMBOL_OFFSET
		unless all [
			integer? import-symbol
			import-symbol > 0
			import-symbol <= (section-count view/symbols)
			import-symbol <> entry-symbol
		][
			return set-error ERROR-IMPORT
				"RSCG adapter slice requires one distinct imported symbol"
		]
		import-kind: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
		import-binding: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
		import-visibility: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
		import-output: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		import-offset: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		import-size: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
		import-alignment: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
		import-flags: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
		import-origin: record-value artifact view/symbols import-symbol
			schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET
		unless all [
			import-kind = schema/WIRE_SYMBOL_KIND_FUNCTION
			import-binding = schema/WIRE_SYMBOL_BINDING_GLOBAL
			import-visibility = schema/WIRE_VISIBILITY_DEFAULT
			import-output = 0
			import-offset = 0
			import-size = 0
			import-alignment = 0
			import-flags = schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED
			import-origin = 1
		][
			return set-error ERROR-IMPORT
				"RSCG adapter slice requires one undefined global exit function"
		]
		library-id: record-value artifact view/imports 1
			schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
		external-id: record-value artifact view/imports 1
			schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
		library-name: either integer? library-id [string-at artifact view library-id][none]
		external-name: either integer? external-id [string-at artifact view external-id][none]
		calling-convention: record-value artifact view/imports 1
			schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
		import-record-flags: record-value artifact view/imports 1
			schema/WIRE_IMPORT_FLAGS_OFFSET
		import-source: record-value artifact view/imports 1
			schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET
		unless all [
			library-name = "kernel32.dll"
			external-name = "ExitProcess"
			calling-convention = schema/WIRE_CALLING_CONVENTION_STDCALL
			import-record-flags = 0
			import-source = 0
		][
			return set-error ERROR-IMPORT
				"RSCG executable entry must import kernel32.dll ExitProcess with stdcall"
		]

		relocation-source-section: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
		relocation-source-offset: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
		relocation-kind: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
		relocation-target: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
		relocation-addend-low: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_LOW_OFFSET
		relocation-addend-high: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET
		relocation-width: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
		relocation-flags: record-value artifact view/relocations 1
			schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET
		unless all [
			relocation-source-section = code-section
			integer? relocation-source-offset
			relocation-source-offset >= function-offset
			relocation-source-offset <= (function-offset + function-size - 4)
			relocation-kind = schema/WIRE_RELOCATION_KIND_X64_RIP_REL32
			relocation-target = import-symbol
			relocation-addend-low = 0
			relocation-addend-high = 0
			relocation-width = 4
			relocation-flags = schema/WIRE_RSCG_RELOCATION_FLAG_NONE
		][
			return set-error ERROR-RELOCATION
				"RSCG exit import requires one zero-addend x64 RIP-relative relocation"
		]

		code: copy-output-section artifact view code-section
		data: copy-output-section artifact view data-section
		unless all [binary? code binary? data][
			return set-error ERROR-SECTION
				"RSCG output section range cannot be represented by the linker"
		]
		unless all [
			function-offset <= (length? code)
			function-size <= ((length? code) - function-offset)
		][
			return set-error ERROR-SYMBOL
				"RSCG function extent falls outside the code section"
		]
		gc-function: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
		bitmap-section: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
		bitmap-offset: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
		bitmap-size: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
		gc-flags: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET
		patch-offset: record-value artifact view/gc-frames 1
			schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET
		unless all [
			gc-function = 1
			bitmap-section = data-section
			bitmap-offset = 0
			bitmap-size = length? data
			bitmap-size >= 16
			zero? (bitmap-size // 4)
			gc-flags = 0
			integer? patch-offset
			patch-offset > 0
			patch-offset <= (function-size - 4)
		][
			return set-error ERROR-GC-FRAME
				"RSCG adapter slice requires one standalone bitmap filling .data"
		]
		bitmap-word-offset: (to integer! bitmap-offset) / 4
		change/part at code (function-offset + patch-offset + 1)
			int-to-bin/to-bin32 bitmap-word-offset 4

		prepared: make object! [
			sections: none
			symbols: none
			debug-info: none
			entry-name: none
			entry-offset: 0
			code-size: 0
			data-size: 0
		]
		prepared/sections: make-linker-sections code data library-name external-name
			(relocation-source-offset + 1)
		prepared/symbols: make-linker-symbols function-word function-offset
		prepared/entry-name: function-word
		prepared/entry-offset: function-offset
		prepared/code-size: length? code
		prepared/data-size: length? data
		prepared
	]

	adapt: func [artifact job /local prepared][
		prepared: prepare artifact job
		unless object? prepared [return false]
		set in job 'sections prepared/sections
		set in job 'symbols prepared/symbols
		set in job 'debug-info prepared/debug-info
		last-error: none
		last-result: prepared
		true
	]
]
