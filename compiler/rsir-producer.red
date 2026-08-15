Red [
	Title: "Hybrid compiler minimal Red-side RSIR producer"
	File:  %rsir-producer.red
]

unless value? 'compiler-wire-schema [do %wire-schema.red]
unless value? 'compiler-wire-writer [do %wire-writer.red]

; The first producer slice is intentionally narrow.  It is a semantic input
; boundary for codegen, not a second emitter and not a machine-IR serializer.
compiler-rsir-producer: context [
	schema: compiler-wire-schema
	ERROR-SUCCESS: 0
	ERROR-ARGUMENTS: 1
	ERROR-NAME: 2
	ERROR-KIND: 3
	ERROR-LIMIT: 4
	ERROR-WRITER: 5
	DEFAULT-MAX-BYTES: 16777216
	last-error: none

	set-error: func [code [integer!] message [string!] /local record][
		record: make object! [code: 0 message: none]
		record/code: code
		record/message: message
		last-error: record
		none
	]

	valid-name-bytes?: func [value [string!] /local bytes][
		if empty? value [return false]
		bytes: to binary! value
		not find bytes 0
	]

	canonical-strings: func [
		module-name [string! none!]
		function-name [string!]
		/local values ordered value bytes records data offset
	][
		values: reduce ["" function-name]
		if module-name [append values module-name]
		ordered: sort/case copy values
		values: make block! (length? ordered)
		foreach value ordered [
			unless all [not empty? values strict-equal? value last values][
				append values value
			]
		]
		records: make binary! ((length? values) * 8)
		data: make binary! 64
		offset: 0
		foreach value values [
			bytes: to binary! value
			append records int-to-bin/to-bin32 offset
			append records int-to-bin/to-bin32 (length? bytes)
			append data bytes
			offset: offset + (length? bytes)
		]
		reduce [records data values]
	]

	string-id: func [ordered [block!] name [string!] /local id value][
		id: 1
		foreach value ordered [
			if strict-equal? value name [return id]
			id: id + 1
		]
		none
	]

	serialized-size: func [payload-sizes [block!] /local size kind payload alignment aligned][
		size: schema/WIRE_HEADER_SIZE
			+ (schema/WIRE_RSIR_REQUIRED_SECTION_COUNT * schema/WIRE_DIRECTORY_SIZE)
		repeat kind schema/WIRE_RSIR_REQUIRED_SECTION_COUNT [
			payload: pick payload-sizes kind
			if payload > 0 [
				alignment: pick schema/profiles/RSIR/alignments kind
				aligned: compiler-wire-writer/align-size size alignment
				if none? aligned [return none]
				size: aligned + payload
			]
		]
		size
	]

	write-words-section: func [writer [object!] kind flags values [block!] /local status][
		status: compiler-wire-writer/start-section writer kind flags
		if status <> compiler-wire-writer/ERROR-SUCCESS [return status]
		status: compiler-wire-writer/words writer values
		if status <> compiler-wire-writer/ERROR-SUCCESS [return status]
		compiler-wire-writer/end-section writer
	]

	indexed-section?: func [kind [integer!]][
		to logic! find reduce [
			schema/WIRE_RSIR_SECTION_STRINGS
			schema/WIRE_RSIR_SECTION_FILES
			schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
			schema/WIRE_RSIR_SECTION_SYMBOLS
			schema/WIRE_RSIR_SECTION_IMPORTS
			schema/WIRE_RSIR_SECTION_EXPORTS
			schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		] kind
	]

	write-empty-section: func [writer [object!] kind [integer!] /local flags][
		flags: either indexed-section? kind [
			schema/WIRE_SECTION_FLAG_SORTED + schema/WIRE_SECTION_FLAG_DEDUPLICATED
		][0]
		compiler-wire-writer/empty-section writer kind flags
	]

	build-empty-void-module: func [
		module-name [string! none!]
		function-name [string! word!]
		module-kind image-kind [integer!]
		/limit max-bytes [integer!]
		/local function-text function-bytes module-bytes
			strings records data ordered module-id function-id payload-sizes
			size writer status index-flags entry-function
	][
		last-error: none
		max-bytes: any [max-bytes DEFAULT-MAX-BYTES]
		if max-bytes <= 0 [
			set-error ERROR-LIMIT "RSIR producer received an invalid output limit"
			return none
		]
		function-text: either word? :function-name [form function-name][copy function-name]
		if any [
			all [module-name not valid-name-bytes? module-name]
			not valid-name-bytes? function-text
		][
			set-error ERROR-NAME "RSIR producer received an invalid symbol name"
			return none
		]
		function-bytes: to binary! function-text
		module-bytes: either module-name [to binary! module-name][#{}]
		if any [
			(length? function-bytes) > max-bytes
			(length? module-bytes) > (max-bytes - length? function-bytes)
		][
			set-error ERROR-LIMIT "RSIR producer names exceed its output limit"
			return none
		]
		unless any [
			module-kind = schema/WIRE_MODULE_KIND_USER
			module-kind = schema/WIRE_MODULE_KIND_SUPPORT
			module-kind = schema/WIRE_MODULE_KIND_GLUE
		][
			set-error ERROR-KIND "RSIR producer only supports USER, SUPPORT, or GLUE modules"
			return none
		]
		unless image-kind = schema/WIRE_IMAGE_KIND_EXECUTABLE [
			set-error ERROR-KIND "RSIR producer only supports executable modules"
			return none
		]
		strings: canonical-strings module-name function-text
		records: strings/1
		data: strings/2
		ordered: strings/3
		module-id: either module-name [string-id ordered module-name][0]
		function-id: string-id ordered function-text
		entry-function: either module-kind = schema/WIRE_MODULE_KIND_GLUE [1][0]
		if any [none? module-id none? function-id][
			set-error ERROR-WRITER "RSIR producer lost a canonical string ID"
			return none
		]
		index-flags: schema/WIRE_SECTION_FLAG_SORTED
			+ schema/WIRE_SECTION_FLAG_DEDUPLICATED
		payload-sizes: make block! schema/WIRE_RSIR_REQUIRED_SECTION_COUNT
		append/dup payload-sizes 0 schema/WIRE_RSIR_REQUIRED_SECTION_COUNT
		poke payload-sizes schema/WIRE_RSIR_SECTION_MODULE 32
		poke payload-sizes schema/WIRE_RSIR_SECTION_DATA_LAYOUT 32
		poke payload-sizes schema/WIRE_RSIR_SECTION_STRINGS length? records
		poke payload-sizes schema/WIRE_RSIR_SECTION_STRING_DATA length? data
		poke payload-sizes schema/WIRE_RSIR_SECTION_TYPES 40
		poke payload-sizes schema/WIRE_RSIR_SECTION_SIGNATURES 32
		poke payload-sizes schema/WIRE_RSIR_SECTION_SYMBOLS 32
		poke payload-sizes schema/WIRE_RSIR_SECTION_FUNCTIONS 40
		poke payload-sizes schema/WIRE_RSIR_SECTION_BLOCKS 32
		poke payload-sizes schema/WIRE_RSIR_SECTION_INSTRUCTIONS 48
		size: serialized-size payload-sizes
		if none? size [
			set-error ERROR-LIMIT "RSIR producer could not measure its output"
			return none
		]
		if size > max-bytes [
			set-error ERROR-LIMIT "RSIR producer output exceeds its limit"
			return none
		]
		writer: compiler-wire-writer/new
			schema/WIRE_MAGIC_RSIR
			schema/WIRE_TARGET_X86_64
			schema/WIRE_ABI_WIN64
			schema/WIRE_ENDIAN_LITTLE
			8
			schema/WIRE_RSIR_REQUIRED_SECTION_COUNT
			max-bytes size
		if writer/error <> compiler-wire-writer/ERROR-SUCCESS [
			set-error ERROR-WRITER "RSIR producer could not initialize its writer"
			return none
		]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_MODULE 0 reduce [
			module-id module-kind image-kind 0 0 entry-function 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR module section write failed"]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_DATA_LAYOUT 0 [1 8 8 16 8 8 8 0]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR layout section write failed"]
		status: compiler-wire-writer/start-section writer schema/WIRE_RSIR_SECTION_STRINGS index-flags
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR strings section start failed"]
		status: compiler-wire-writer/bytes writer records
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR strings section write failed"]
		status: compiler-wire-writer/end-section writer
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR strings section end failed"]
		status: compiler-wire-writer/start-section writer schema/WIRE_RSIR_SECTION_STRING_DATA 0
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR string data section start failed"]
		status: compiler-wire-writer/bytes writer data
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR string data section write failed"]
		status: compiler-wire-writer/end-section writer
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR string data section end failed"]
		foreach index reduce [
			schema/WIRE_RSIR_SECTION_FILES
		schema/WIRE_RSIR_SECTION_FILE_CHECKSUM_DATA
	][
			status: write-empty-section writer index
			if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR file section write failed"]
		]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_TYPES 0 reduce [
			schema/WIRE_TYPE_KIND_VOID 0 0 0 0 0 0 0 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR type section write failed"]
		status: write-empty-section writer schema/WIRE_RSIR_SECTION_FIELDS
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR field section write failed"]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_SIGNATURES 0 reduce [
			schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 0 0 0 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR signature section write failed"]
		status: write-empty-section writer schema/WIRE_RSIR_SECTION_PARAMETERS
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR parameter section write failed"]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_SYMBOLS index-flags reduce [
			function-id schema/WIRE_SYMBOL_KIND_FUNCTION
			schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN
			1 0 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR symbol section write failed"]
		foreach index reduce [
			schema/WIRE_RSIR_SECTION_CONSTANTS
			schema/WIRE_RSIR_SECTION_CONSTANT_DATA
			schema/WIRE_RSIR_SECTION_CONSTANT_PARTS
			schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		schema/WIRE_RSIR_SECTION_GLOBALS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
	][
			status: write-empty-section writer index
			if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR declaration section write failed"]
		]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_FUNCTIONS 0 [
			1 1 0 1 1 1 0 0 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR function section write failed"]
		status: write-empty-section writer schema/WIRE_RSIR_SECTION_LOCALS
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR local section write failed"]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_BLOCKS 0 [
			1 0 1 1 0 0 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR block section write failed"]
		status: write-empty-section writer schema/WIRE_RSIR_SECTION_EDGES
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR edge section write failed"]
		status: write-empty-section writer schema/WIRE_RSIR_SECTION_VALUES
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR value section write failed"]
		status: write-words-section writer schema/WIRE_RSIR_SECTION_INSTRUCTIONS 0 reduce [
			1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
			schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
		]
		if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR instruction section write failed"]
		foreach index reduce [
			schema/WIRE_RSIR_SECTION_OPERANDS
			schema/WIRE_RSIR_SECTION_CALLS
			schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS
			schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
			schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS
			schema/WIRE_RSIR_SECTION_EXCEPTION_BLOCKS
			schema/WIRE_RSIR_SECTION_SUBROUTINES
			schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		][
			status: write-empty-section writer index
			if status <> compiler-wire-writer/ERROR-SUCCESS [return set-error ERROR-WRITER "RSIR tail section write failed"]
		]
		status: compiler-wire-writer/finish writer
		if status <> compiler-wire-writer/ERROR-SUCCESS [
			set-error ERROR-WRITER "RSIR producer could not finish its writer"
			return none
		]
		copy writer/output
	]
]
