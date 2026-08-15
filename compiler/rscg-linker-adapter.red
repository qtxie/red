Red [
	Title: "Hybrid compiler RSCG to legacy linker adapter"
	File:  %rscg-linker-adapter.red
]

unless value? 'int-to-bin [do %int-to-bin.red]
unless value? 'compiler-wire-rscg-metadata [do %wire-rscg-metadata.red]

; This first compatibility slice is deliberately smaller than the RSCG
; protocol. It accepts one verified Windows x64 glue entry and rejects every
; unrepresentable feature before mutating the legacy linker job.
compiler-rscg-linker-adapter: context [
	schema: compiler-wire-schema
	metadata-verifier: compiler-wire-rscg-metadata
	object-verifier: compiler-wire-rscg-object
	relocation-verifier: compiler-wire-rscg-relocation
	container: compiler-wire-container

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

	string-at: func [
		data [binary!]
		strings [object!]
		id [integer!]
		/local record relative size bytes
	][
		if any [id <= 0 id > strings/record-count][return none]
		record: strings/records-offset + ((id - 1) * schema/WIRE_STRING_SIZE)
		relative: container/read-i31 data
			(record + schema/WIRE_STRING_OFFSET_OFFSET)
		size: container/read-i31 data (record + schema/WIRE_STRING_SIZE_OFFSET)
		if any [none? relative none? size][return none]
		bytes: copy/part at data (strings/data-offset + relative + 1) size
		to string! bytes
	]

	copy-output-section: func [
		data [binary!]
		view [object!]
		section-id [integer!]
		/local relative size
	][
		relative: object-verifier/output-section-value data view section-id
			schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
		size: object-verifier/output-section-value data view section-id
			schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
		copy/part at data (view/output-data-offset + relative + 1) size
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
		/local verified object-view relocation-view metadata-view modules strings
			section-id class code-section data-section name-id section-name
			code data entry-symbol symbol-kind symbol-section symbol-offset symbol-size
			function-symbol function-section function-offset function-size function-name
			function-word gc-function bitmap-section bitmap-offset bitmap-size patch-offset
			bitmap-word-offset import-symbol import-kind import-binding import-visibility
			import-output import-flags library-id external-id library-name external-name
			calling-convention import-record-flags import-source relocation-source-section
			relocation-source-offset relocation-kind relocation-target relocation-addend-low
			relocation-addend-high relocation-width relocation-flags prepared
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

		verified: metadata-verifier/verify artifact
		unless verified/valid? [
			return set-error/at ERROR-INVALID-RSCG
				rejoin ["RSCG metadata verification failed: " verified/error]
				verified/error-offset verified/error-section
		]
		object-view: verified/object-view
		relocation-view: verified/relocation-view
		metadata-view: verified/view
		modules: verified/modules
		strings: verified/strings
		unless all [
			modules/glue-module = 1
			modules/image-kind = schema/WIRE_IMAGE_KIND_EXECUTABLE
			(object-verifier/module-value artifact modules 1
				schema/WIRE_RSCG_MODULE_KIND_OFFSET) = schema/WIRE_MODULE_KIND_GLUE
		][
			return set-error ERROR-LIFECYCLE
				"RSCG executable adapter requires one explicit GLUE module"
		]

		unless all [
			object-view/output-section-count = 2
			object-view/symbol-count = 2
			object-view/function-count = 1
			relocation-view/relocation-count = 1
			relocation-view/import-count = 1
			relocation-view/export-count = 0
			object-view/debug-line-count = 0
			object-view/debug-parameter-count = 0
			metadata-view/gc-frame-count = 1
			metadata-view/unwind-function-count = 0
			verified/files/file-count = 0
			modules/module-count = 1
			object-view/runtime-module = 0
		][
			return set-error ERROR-UNSUPPORTED-FEATURE
				"RSCG linker adapter slice supports one entry function, one exit import relocation, and no exports, debug, runtime, or unwind data"
		]

		code-section: 0
		data-section: 0
		section-id: 1
		while [section-id <= object-view/output-section-count][
			class: object-verifier/output-section-value artifact object-view section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
			name-id: object-verifier/output-section-value artifact object-view section-id
				schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
			section-name: string-at artifact strings name-id
			case [
				all [
					class = schema/WIRE_OUTPUT_SECTION_CLASS_CODE
					section-name = ".text"
					code-section = 0
				][code-section: section-id]
				all [
					class = schema/WIRE_OUTPUT_SECTION_CLASS_DATA
					section-name = ".data"
					data-section = 0
				][data-section: section-id]
				true [
					return set-error ERROR-SECTION
						"RSCG linker adapter slice requires exactly one .text and one .data section"
				]
			]
			section-id: section-id + 1
		]
		if any [code-section = 0 data-section = 0][
			return set-error ERROR-SECTION
				"RSCG linker adapter could not find its required output sections"
		]

		entry-symbol: object-verifier/module-value artifact modules 1
			schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET
		unless all [entry-symbol > 0 entry-symbol <= object-view/symbol-count][
			return set-error ERROR-LIFECYCLE
				"RSCG adapter slice requires an explicit executable entry symbol"
		]

		symbol-kind: object-verifier/symbol-value artifact object-view entry-symbol
			schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
		symbol-section: object-verifier/symbol-value artifact object-view entry-symbol
			schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		symbol-offset: object-verifier/symbol-value artifact object-view entry-symbol
			schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
		symbol-size: object-verifier/symbol-value artifact object-view entry-symbol
			schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
		unless all [
			symbol-kind = schema/WIRE_SYMBOL_KIND_FUNCTION
			symbol-section = code-section
			symbol-offset = 0
		][
			return set-error ERROR-SYMBOL
				"legacy PE executable entry must be a function at .text offset zero"
		]

		function-symbol: object-verifier/function-value artifact object-view 1
			schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
		function-section: object-verifier/function-value artifact object-view 1
			schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
		function-offset: object-verifier/function-value artifact object-view 1
			schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET
		function-size: object-verifier/function-value artifact object-view 1
			schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
		unless all [
			function-symbol = entry-symbol
			function-section = code-section
			function-offset = symbol-offset
			function-size = symbol-size
		][
			return set-error ERROR-SYMBOL
				"RSCG entry function extent does not match its symbol"
		]
		name-id: object-verifier/symbol-value artifact object-view entry-symbol
			schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
		function-name: string-at artifact strings name-id
		function-word: attempt [to word! function-name]
		unless word? function-word [
			return set-error ERROR-SYMBOL
				"RSCG entry symbol name cannot be represented by the legacy linker"
		]

		import-symbol: relocation-verifier/import-value artifact relocation-view 1
			schema/WIRE_IMPORT_SYMBOL_OFFSET
		import-kind: object-verifier/symbol-value artifact object-view import-symbol
			schema/WIRE_RSCG_SYMBOL_KIND_OFFSET
		import-binding: object-verifier/symbol-value artifact object-view import-symbol
			schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
		import-visibility: object-verifier/symbol-value artifact object-view import-symbol
			schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
		import-output: object-verifier/symbol-value artifact object-view import-symbol
			schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
		import-flags: object-verifier/symbol-value artifact object-view import-symbol
			schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
		unless all [
			import-symbol > 0
			import-symbol <= object-view/symbol-count
			import-symbol <> entry-symbol
			import-kind = schema/WIRE_SYMBOL_KIND_FUNCTION
			import-binding = schema/WIRE_SYMBOL_BINDING_GLOBAL
			import-visibility = schema/WIRE_VISIBILITY_DEFAULT
			import-output = 0
			import-flags = schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED
		][
			return set-error ERROR-IMPORT
				"RSCG adapter slice requires one undefined global exit function"
		]
		library-id: relocation-verifier/import-value artifact relocation-view 1
			schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
		external-id: relocation-verifier/import-value artifact relocation-view 1
			schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
		library-name: string-at artifact strings library-id
		external-name: string-at artifact strings external-id
		calling-convention: relocation-verifier/import-value artifact relocation-view 1
			schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
		import-record-flags: relocation-verifier/import-value artifact relocation-view 1
			schema/WIRE_IMPORT_FLAGS_OFFSET
		import-source: relocation-verifier/import-value artifact relocation-view 1
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

		relocation-source-section: relocation-verifier/relocation-value artifact
			relocation-view 1 schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
		relocation-source-offset: relocation-verifier/relocation-value artifact
			relocation-view 1 schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
		relocation-kind: relocation-verifier/relocation-value artifact relocation-view 1
			schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
		relocation-target: relocation-verifier/relocation-value artifact relocation-view 1
			schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
		relocation-addend-low: relocation-verifier/relocation-value artifact
			relocation-view 1 schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_LOW_OFFSET
		relocation-addend-high: relocation-verifier/relocation-value artifact
			relocation-view 1 schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET
		relocation-width: relocation-verifier/relocation-value artifact relocation-view 1
			schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET
		relocation-flags: relocation-verifier/relocation-value artifact relocation-view 1
			schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET
		unless all [
			relocation-source-section = code-section
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

		code: copy-output-section artifact object-view code-section
		data: copy-output-section artifact object-view data-section
		gc-function: metadata-verifier/gc-frame-value artifact metadata-view 1
			schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
		bitmap-section: metadata-verifier/gc-frame-value artifact metadata-view 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET
		bitmap-offset: metadata-verifier/gc-frame-value artifact metadata-view 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET
		bitmap-size: metadata-verifier/gc-frame-value artifact metadata-view 1
			schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET
		patch-offset: metadata-verifier/gc-frame-value artifact metadata-view 1
			schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET
		unless all [
			gc-function = 1
			bitmap-section = data-section
			bitmap-offset = 0
			bitmap-size = length? data
		][
			return set-error ERROR-GC-FRAME
				"RSCG adapter slice requires one standalone bitmap filling .data"
		]
		bitmap-word-offset: to integer! bitmap-offset / 4
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
