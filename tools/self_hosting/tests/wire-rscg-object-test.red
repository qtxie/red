Red [
	Title: "Hybrid compiler RSCG object-layout tests"
]

do %wire-module-lifecycle-test.red
do %../../../compiler/wire-rscg-object.red

rscg-object-verifier: compiler-wire-rscg-object

make-rscg-strings: func [
	values [block!]
	/local ordered records bytes data ids offset id value
][
	ordered: sort/case copy values
	records: make block! ((length? ordered) * 2)
	data: make binary! 512
	ids: make map! ((length? ordered) * 2)
	offset: 0
	id: 1
	foreach value ordered [
		bytes: to binary! value
		repend records [offset length? bytes]
		append data bytes
		put ids value id
		offset: offset + length? bytes
		id: id + 1
	]
	reduce [fixture-writer/words records data ids]
]

rscg-string-id: func [table [block!] value [string!]][select table/3 value]

make-rscg-function-bytes: func [/local output][
	output: copy #{554889E56A006A0068000000006A00}
	append/dup output 144 (31 - length? output)
	append output #{C3}
	output
]

rscg-object-strings: make-rscg-strings [
	"" ".bss" ".data" ".rdata" ".text"
	"***-exec-image" "***-lib-image" "***-lib-placeholder" "***-ptr-bitmaps"
	"entry" "fixture.reds" "glue" "init" "ro-constant" "runtime" "state"
]
rscg-id: :rscg-string-id

rscg-code: make binary! 64
append rscg-code make-rscg-function-bytes
append rscg-code make-rscg-function-bytes
rscg-rodata: #{0102030405060708}
rscg-data: make binary! 88
append/dup rscg-data 0 40
append rscg-data fixture-writer/words [0]
append rscg-data fixture-writer/words [0 0 0 0]
append rscg-data fixture-writer/words [0 0 0 0]
append/dup rscg-data 0 4
append/dup rscg-data 0 8
rscg-output-data: make binary! 160
append rscg-output-data rscg-code
append rscg-output-data rscg-rodata
append rscg-output-data rscg-data

rscg-output-sections: fixture-writer/words reduce [
	rscg-id rscg-object-strings ".text"
		schema/WIRE_OUTPUT_SECTION_CLASS_CODE 0 16 0 64 64 0
	rscg-id rscg-object-strings ".rdata"
		schema/WIRE_OUTPUT_SECTION_CLASS_RODATA 0 8 64 8 8 0
	rscg-id rscg-object-strings ".data"
		schema/WIRE_OUTPUT_SECTION_CLASS_DATA 0 8 72 88 88 0
	rscg-id rscg-object-strings ".bss"
		schema/WIRE_OUTPUT_SECTION_CLASS_BSS 0 8 0 0 16 0
]

; Symbols are ordered by canonical name ID, binding, and origin module.
rscg-symbols: fixture-writer/words reduce [
	rscg-id rscg-object-strings "***-exec-image"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 0 40 8 0 1
	rscg-id rscg-object-strings "***-ptr-bitmaps"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 44 32 4 0 1
	rscg-id rscg-object-strings "entry"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 32 32 16 0 2
	rscg-id rscg-object-strings "init"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 0 32 16 0 1
	rscg-id rscg-object-strings "ro-constant"
		schema/WIRE_SYMBOL_KIND_CONSTANT schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 8 8 0 1
	rscg-id rscg-object-strings "state"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 4 0 16 8 0 1
]

rscg-functions: fixture-writer/words [
	4 1 0 32 16 0 1 1 1 1
	3 1 32 32 0 0 2 1 0 0
]
rscg-files: fixture-writer/words reduce [
	rscg-id rscg-object-strings "fixture.reds" 0 0 0
]
rscg-debug-lines: fixture-writer/words [
	1 0 1 1 0
	2 0 1 2 0
]
rscg-debug-parameters: fixture-writer/words reduce [
	1 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0
]
rscg-gc-frames: fixture-writer/words [
	1 3 44 16 0 9
	2 3 60 16 0 9
]
rscg-modules: fixture-writer/words reduce [
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_MODULE_KIND_RUNTIME schema/WIRE_IMAGE_KIND_EXECUTABLE 4 0 0 0 0
	rscg-id rscg-object-strings "glue"
		schema/WIRE_MODULE_KIND_GLUE schema/WIRE_IMAGE_KIND_EXECUTABLE 0 0 3 0 0
]

build-rscg-object-message: func [
	output-sections output-data symbols relocations imports exports functions
	debug-lines debug-parameters gc-frames modules unwind [binary!]
	/local payloads sections
][
	payloads: make map! 48
	put payloads schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSCG_SECTION_STRINGS rscg-object-strings/1
	put payloads schema/WIRE_RSCG_SECTION_STRING_DATA rscg-object-strings/2
	put payloads schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS output-sections
	put payloads schema/WIRE_RSCG_SECTION_OUTPUT_DATA output-data
	put payloads schema/WIRE_RSCG_SECTION_SYMBOLS symbols
	put payloads schema/WIRE_RSCG_SECTION_RELOCATIONS relocations
	put payloads schema/WIRE_RSCG_SECTION_IMPORTS imports
	put payloads schema/WIRE_RSCG_SECTION_EXPORTS exports
	put payloads schema/WIRE_RSCG_SECTION_FUNCTIONS functions
	put payloads schema/WIRE_RSCG_SECTION_FILES rscg-files
	put payloads schema/WIRE_RSCG_SECTION_DEBUG_LINES debug-lines
	put payloads schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS debug-parameters
	put payloads schema/WIRE_RSCG_SECTION_GC_FRAMES gc-frames
	put payloads schema/WIRE_RSCG_SECTION_MODULES modules
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSCG payloads
	foreach kind reduce [
		schema/WIRE_RSCG_SECTION_STRINGS
		schema/WIRE_RSCG_SECTION_FILES
		schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
		schema/WIRE_RSCG_SECTION_FUNCTIONS
		schema/WIRE_RSCG_SECTION_RELOCATIONS
		schema/WIRE_RSCG_SECTION_IMPORTS
		schema/WIRE_RSCG_SECTION_EXPORTS
		schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS
		schema/WIRE_RSCG_SECTION_GC_FRAMES
	][
		fixture-writer/set-section-flags sections kind
			(rscg-object-verifier/expected-index-flags)
	]
	fixture-writer/set-section-flags sections schema/WIRE_RSCG_SECTION_SYMBOLS
		rscg-object-verifier/expected-symbol-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSCG_SECTION_DEBUG_LINES
		schema/WIRE_SECTION_FLAG_SORTED
	if not empty? unwind [
		append/only sections reduce [
			schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS
			(schema/WIRE_SECTION_FLAG_OPTIONAL + rscg-object-verifier/expected-index-flags)
			schema/WIRE_RSCG_UNWIND_FUNCTION_SIZE 4 unwind
		]
	]
	fixture-writer/build schema/WIRE_MAGIC_RSCG schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64 schema/WIRE_ENDIAN_LITTLE 8 sections
]

valid-rscg-object: build-rscg-object-message
	rscg-output-sections rscg-output-data rscg-symbols #{} #{} #{}
	rscg-functions rscg-debug-lines rscg-debug-parameters rscg-gc-frames
	rscg-modules #{}

rscg-dll-data: make binary! 128
append/dup rscg-dll-data 0 80
append rscg-dll-data fixture-writer/words [0]
append rscg-dll-data fixture-writer/words [0 0 0 0 0 0 0 0]
append/dup rscg-dll-data 0 12
rscg-dll-output-data: make binary! 200
append rscg-dll-output-data rscg-code
append rscg-dll-output-data rscg-rodata
append rscg-dll-output-data rscg-dll-data

rscg-dll-output-sections: fixture-writer/words reduce [
	rscg-id rscg-object-strings ".text"
		schema/WIRE_OUTPUT_SECTION_CLASS_CODE 0 16 0 64 64 0
	rscg-id rscg-object-strings ".rdata"
		schema/WIRE_OUTPUT_SECTION_CLASS_RODATA 0 8 64 8 8 0
	rscg-id rscg-object-strings ".data"
		schema/WIRE_OUTPUT_SECTION_CLASS_DATA 0 8 72 128 128 0
	rscg-id rscg-object-strings ".bss"
		schema/WIRE_OUTPUT_SECTION_CLASS_BSS 0 8 0 0 16 0
]
rscg-dll-symbols: fixture-writer/words reduce [
	rscg-id rscg-object-strings "***-exec-image"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 0 40 8 0 1
	rscg-id rscg-object-strings "***-lib-image"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 40 40 8 0 1
	rscg-id rscg-object-strings "***-ptr-bitmaps"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 84 32 4 0 1
	rscg-id rscg-object-strings "entry"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 32 32 16 0 2
	rscg-id rscg-object-strings "init"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 0 32 16 0 1
	rscg-id rscg-object-strings "ro-constant"
		schema/WIRE_SYMBOL_KIND_CONSTANT schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 8 8 0 1
	rscg-id rscg-object-strings "state"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 4 0 16 8 0 1
]
rscg-dll-functions: fixture-writer/words [
	5 1 0 32 16 0 1 1 1 1
	4 1 32 32 0 0 2 1 0 0
]
rscg-dll-gc-frames: fixture-writer/words [
	1 3 84 16 0 9
	2 3 100 16 0 9
]
rscg-dll-modules: fixture-writer/words reduce [
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_MODULE_KIND_RUNTIME schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY 5 0 0 0 0
	rscg-id rscg-object-strings "glue"
		schema/WIRE_MODULE_KIND_GLUE schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY 0 0 4 0 0
]
valid-rscg-dll-object: build-rscg-object-message
	rscg-dll-output-sections rscg-dll-output-data rscg-dll-symbols #{} #{} #{}
	rscg-dll-functions rscg-debug-lines rscg-debug-parameters rscg-dll-gc-frames
	rscg-dll-modules #{}

result: rscg-object-verifier/verify valid-rscg-object
assert result/valid? [
	"valid RSCG object rejected with error " result/error
	" at " result/error-offset ":" result/error-section
]
assert to logic! all [
	result/error = schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
	result/view/output-section-count = 4
	result/view/output-data-size = 160
	result/view/symbol-count = 6
	result/view/function-count = 2
	result/view/runtime-module = 1
	result/view/exec-image-symbol = 1
	result/view/bitmap-symbol = 2
] "verified RSCG object view changed"

dll-result: rscg-object-verifier/verify valid-rscg-dll-object
assert all [
	dll-result/valid?
	dll-result/view/output-section-count = 4
	dll-result/view/output-data-size = 200
	dll-result/view/symbol-count = 7
	dll-result/view/function-count = 2
	dll-result/view/runtime-module = 1
	dll-result/view/exec-image-symbol = 1
	dll-result/view/lib-image-symbol = 2
	dll-result/view/bitmap-symbol = 3
] [
	"valid RSCG DLL rejected with error " dll-result/error
	" at " dll-result/error-offset ":" dll-result/error-section
]

rscg-object-sections: func [data [binary!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSCG
	reduce [
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_DATA_LAYOUT
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_STRINGS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_OUTPUT_SECTIONS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_OUTPUT_DATA
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_SYMBOLS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_FUNCTIONS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_FILES
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_MODULES
	]
]

valid-object-sections: rscg-object-sections valid-rscg-object
rscg-data-layout-section: valid-object-sections/1
rscg-strings-section: valid-object-sections/2
rscg-output-sections-section: valid-object-sections/3
rscg-output-data-section: valid-object-sections/4
rscg-symbols-section: valid-object-sections/5
rscg-functions-section: valid-object-sections/6
rscg-files-section: valid-object-sections/7
rscg-modules-section: valid-object-sections/8

valid-dll-sections: rscg-object-sections valid-rscg-dll-object
rscg-dll-output-sections-section: valid-dll-sections/3
rscg-dll-output-data-section: valid-dll-sections/4
rscg-dll-symbols-section: valid-dll-sections/5
rscg-dll-functions-section: valid-dll-sections/6
rscg-dll-modules-section: valid-dll-sections/8

rscg-record-offset: func [section [map!] id [integer!]][
	(select section 'payload-offset) + ((id - 1) * (select section 'record-size))
]

malformed-rscg-objects: make block! 256
add-malformed-rscg-object: func [
	name [word!] expected-error expected-container expected-string expected-file
	expected-layout expected-module expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-rscg-objects reduce [
		name expected-error expected-container expected-string expected-file
		expected-layout expected-module expected-offset expected-section data
	]
]

add-object-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-rscg-object name expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		expected-offset expected-section data
]

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-rscg-object 'INVALID-CONTAINER
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy valid-rscg-object
dependency-offset:
	(select rscg-strings-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad dependency-offset 0
add-malformed-rscg-object 'INVALID-STRINGS
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_STRINGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_SECTION_FLAGS
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS
	dependency-offset (select rscg-strings-section 'ordinal) bad

bad: copy valid-rscg-object
dependency-offset:
	(select rscg-files-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad dependency-offset 0
add-malformed-rscg-object 'INVALID-FILE-SOURCE
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_FILE_SOURCE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_BAD_FILES_SECTION_FLAGS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE
	dependency-offset (select rscg-files-section 'ordinal) bad

bad: copy valid-rscg-object
dependency-offset: (select rscg-data-layout-section 'payload-offset)
	+ schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET
fixture-mutations/put-u32 bad dependency-offset 8
add-malformed-rscg-object 'INVALID-DATA-LAYOUT
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_DATA_LAYOUT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	dependency-offset (select rscg-data-layout-section 'ordinal) bad

bad: copy valid-rscg-object
dependency-offset: (rscg-record-offset rscg-modules-section 1)
	+ schema/WIRE_RSCG_MODULE_RESERVED_OFFSET
fixture-mutations/put-u32 bad dependency-offset 1
add-malformed-rscg-object 'INVALID-MODULE-LIFECYCLE
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_MODULE_LIFECYCLE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_RESERVED
	dependency-offset (select rscg-modules-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((select rscg-output-sections-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-rscg-object 'BAD-OUTPUT-SECTION-FLAGS
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((select rscg-output-sections-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	(select rscg-output-sections-section 'ordinal) bad

foreach [name section expected-error bad-flags] reduce [
	'BAD-OUTPUT-DATA-SECTION-FLAGS rscg-output-data-section
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_DATA_SECTION_FLAGS
		schema/WIRE_SECTION_FLAG_SORTED
	'BAD-SYMBOL-SECTION-FLAGS rscg-symbols-section
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_FLAGS 0
	'BAD-FUNCTION-SECTION-FLAGS rscg-functions-section
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION_FLAGS 0
][
	bad: copy valid-rscg-object
	error-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad error-offset bad-flags
	add-object-error name expected-error error-offset (select section 'ordinal) bad
]

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-output-sections-section 1)
		+ schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
	-2147483648
add-malformed-rscg-object 'SCALAR-RANGE
	schema/WIRE_RSCG_OBJECT_ERROR_SCALAR_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-output-sections-section 1)
		+ schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET)
	(select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-OUTPUT-SECTION-NAME-ID
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_NAME_ID
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset (rscg-id rscg-object-strings "")
add-object-error 'EMPTY-OUTPUT-SECTION-NAME
	schema/WIRE_RSCG_OBJECT_ERROR_EMPTY_OUTPUT_SECTION_NAME
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 3)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
fixture-mutations/put-u32 bad error-offset schema/WIRE_OUTPUT_SECTION_CLASS_CODE
add-object-error 'OUTPUT-SECTION-ORDER
	schema/WIRE_RSCG_OBJECT_ERROR_OUTPUT_SECTION_ORDER
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
name-offset: (rscg-record-offset rscg-output-sections-section 3)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad name-offset (rscg-id rscg-object-strings ".text")
add-object-error 'DUPLICATE-OUTPUT-SECTION-NAME
	schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_OUTPUT_SECTION_NAME
	name-offset (select rscg-output-sections-section 'ordinal) bad

foreach [name value expected-error] reduce [
	'BAD-OUTPUT-SECTION-CLASS 0 schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_CLASS
	'UNSUPPORTED-PLATFORM-SECTION schema/WIRE_OUTPUT_SECTION_CLASS_PLATFORM
		schema/WIRE_RSCG_OBJECT_ERROR_UNSUPPORTED_PLATFORM_SECTION
][
	bad: copy valid-rscg-object
	error-offset: (rscg-record-offset rscg-output-sections-section 1)
		+ schema/WIRE_RSCG_OUTPUT_SECTION_CLASS_OFFSET
	fixture-mutations/put-u32 bad error-offset value
	add-object-error name expected-error error-offset
		(select rscg-output-sections-section 'ordinal) bad
]

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_FLAGS_OFFSET
fixture-mutations/put-u32 bad error-offset 1
add-object-error 'BAD-OUTPUT-SECTION-RECORD-FLAGS
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FLAGS
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_ALIGNMENT_OFFSET
fixture-mutations/put-u32 bad error-offset 3
add-object-error 'BAD-OUTPUT-SECTION-ALIGNMENT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_ALIGNMENT
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 2)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET
fixture-mutations/put-u32 bad error-offset 65
add-object-error 'BAD-OUTPUT-SECTION-DATA-OFFSET
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_DATA_OFFSET
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-OUTPUT-SECTION-FILE-SIZE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_FILE_SIZE
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-OUTPUT-SECTION-MEMORY-SIZE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_OUTPUT_SECTION_MEMORY_SIZE
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_RESERVED_OFFSET
fixture-mutations/put-u32 bad error-offset 1
add-object-error 'NONZERO-OUTPUT-SECTION-RESERVED
	schema/WIRE_RSCG_OBJECT_ERROR_NONZERO_OUTPUT_SECTION_RESERVED
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-output-sections-section 4)
		+ schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET) 1
add-malformed-rscg-object 'BAD-BSS
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_BSS_SHAPE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-output-sections-section 4)
		+ schema/WIRE_RSCG_OUTPUT_SECTION_DATA_OFFSET_OFFSET)
	(select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-output-sections-section 1)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
fixture-mutations/put-u32 bad error-offset 63
add-object-error 'BAD-INITIALIZED-SECTION-SHAPE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_INITIALIZED_SECTION_SHAPE
	error-offset (select rscg-output-sections-section 'ordinal) bad

bad: copy valid-rscg-object
file-offset: (rscg-record-offset rscg-output-sections-section 3)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_FILE_SIZE_OFFSET
memory-offset: (rscg-record-offset rscg-output-sections-section 3)
	+ schema/WIRE_RSCG_OUTPUT_SECTION_MEMORY_SIZE_OFFSET
fixture-mutations/put-u32 bad file-offset 87
fixture-mutations/put-u32 bad memory-offset 87
add-object-error 'OUTPUT-DATA-COVERAGE
	schema/WIRE_RSCG_OBJECT_ERROR_OUTPUT_DATA_COVERAGE
	((select rscg-output-data-section 'payload-offset) + 159)
	(select rscg-output-data-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 1)
	+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-SYMBOL-NAME-ID
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_NAME_ID
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 1)
	+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset (rscg-id rscg-object-strings "")
add-object-error 'EMPTY-SYMBOL-NAME
	schema/WIRE_RSCG_OBJECT_ERROR_EMPTY_SYMBOL_NAME
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 3)
	+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset
	(rscg-id rscg-object-strings "***-lib-image")
add-object-error 'SYMBOL-ORDER
	schema/WIRE_RSCG_OBJECT_ERROR_SYMBOL_ORDER
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 2)
	+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET
fixture-mutations/put-u32 bad error-offset
	(rscg-id rscg-object-strings "***-exec-image")
add-object-error 'DUPLICATE-SYMBOL
	schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_SYMBOL
	error-offset (select rscg-symbols-section 'ordinal) bad

foreach [name field value expected-error] reduce [
	'BAD-SYMBOL-KIND schema/WIRE_RSCG_SYMBOL_KIND_OFFSET 0
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_KIND
	'BAD-SYMBOL-BINDING schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET 0
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING
	'BAD-SYMBOL-VISIBILITY schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET 0
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_VISIBILITY
	'BAD-SYMBOL-BINDING-VISIBILITY schema/WIRE_RSCG_SYMBOL_VISIBILITY_OFFSET
		schema/WIRE_VISIBILITY_DEFAULT
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_BINDING_VISIBILITY
	'BAD-SYMBOL-FLAGS schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET 2
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_FLAGS
][
	bad: copy valid-rscg-object
	error-offset: (rscg-record-offset rscg-symbols-section 6) + field
	fixture-mutations/put-u32 bad error-offset value
	add-object-error name expected-error error-offset
		(select rscg-symbols-section 'ordinal) bad
]

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 6)
	+ schema/WIRE_RSCG_SYMBOL_FLAGS_OFFSET
fixture-mutations/put-u32 bad error-offset schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED
add-object-error 'BAD-SYMBOL-DEFINITION-SHAPE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_DEFINITION_SHAPE
	((rscg-record-offset rscg-symbols-section 6)
		+ schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 6)
	+ schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-SYMBOL-OUTPUT-SECTION
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_OUTPUT_SECTION
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 6)
	+ schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET
fixture-mutations/put-u32 bad error-offset 3
add-object-error 'BAD-SYMBOL-ALIGNMENT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_ALIGNMENT
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-symbols-section 5) + schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET) 3
add-malformed-rscg-object 'BAD-SYMBOL-CLASS
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_SECTION_CLASS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-symbols-section 5) + schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
output-section-offset: (rscg-record-offset rscg-symbols-section 6)
	+ schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET
section-offset-offset: (rscg-record-offset rscg-symbols-section 6)
	+ schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET
fixture-mutations/put-u32 bad output-section-offset 3
fixture-mutations/put-u32 bad section-offset-offset 0
add-object-error 'SYMBOL-OVERLAP
	schema/WIRE_RSCG_OBJECT_ERROR_SYMBOL_OVERLAP
	section-offset-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-functions-section 1)
	+ schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-object-error 'BAD-FUNCTION-SYMBOL
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SYMBOL
	error-offset (select rscg-functions-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-functions-section 2)
	+ schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET
fixture-mutations/put-u32 bad error-offset 4
add-object-error 'DUPLICATE-FUNCTION-SYMBOL
	schema/WIRE_RSCG_OBJECT_ERROR_DUPLICATE_FUNCTION_SYMBOL
	error-offset (select rscg-functions-section 'ordinal) bad

bad: copy valid-rscg-object
first-function-offset: rscg-record-offset rscg-functions-section 1
second-function-offset: rscg-record-offset rscg-functions-section 2
first-function-record: copy/part at bad (first-function-offset + 1)
	schema/WIRE_RSCG_FUNCTION_SIZE
second-function-record: copy/part at bad (second-function-offset + 1)
	schema/WIRE_RSCG_FUNCTION_SIZE
fixture-mutations/put-bytes bad first-function-offset second-function-record
fixture-mutations/put-bytes bad second-function-offset first-function-record
add-object-error 'FUNCTION-ORDER
	schema/WIRE_RSCG_OBJECT_ERROR_FUNCTION_ORDER
	(second-function-offset + schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET)
	(select rscg-functions-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-functions-section 1)
	+ schema/WIRE_RSCG_FUNCTION_CODE_SECTION_OFFSET
fixture-mutations/put-u32 bad error-offset 2
add-object-error 'BAD-FUNCTION-SECTION
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_SECTION
	error-offset (select rscg-functions-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-functions-section 2) + schema/WIRE_RSCG_FUNCTION_CODE_OFFSET_OFFSET) 16
add-malformed-rscg-object 'FUNCTION-SYMBOL-MISMATCH
	schema/WIRE_RSCG_OBJECT_ERROR_FUNCTION_SYMBOL_MISMATCH
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-functions-section 2) + schema/WIRE_RSCG_FUNCTION_SYMBOL_OFFSET)
	(select rscg-functions-section 'ordinal) bad

bad: copy valid-rscg-object
symbol-size-offset: (rscg-record-offset rscg-symbols-section 4)
	+ schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
function-size-offset: (rscg-record-offset rscg-functions-section 1)
	+ schema/WIRE_RSCG_FUNCTION_CODE_SIZE_OFFSET
fixture-mutations/put-u32 bad symbol-size-offset 0
fixture-mutations/put-u32 bad function-size-offset 0
add-object-error 'BAD-FUNCTION-EXTENT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_EXTENT
	function-size-offset (select rscg-functions-section 'ordinal) bad

foreach [name field value expected-error] reduce [
	'BAD-FUNCTION-FRAME-SIZE schema/WIRE_RSCG_FUNCTION_FRAME_SIZE_OFFSET 4
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FRAME_SIZE
	'BAD-FUNCTION-FLAGS schema/WIRE_RSCG_FUNCTION_FLAGS_OFFSET 1
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_FUNCTION_FLAGS
	'BAD-DEBUG-LINE-RANGE schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET 3
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
	'BAD-DEBUG-PARAMETER-RANGE
		schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET 2
		schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
][
	bad: copy valid-rscg-object
	error-offset: (rscg-record-offset rscg-functions-section 1) + field
	fixture-mutations/put-u32 bad error-offset value
	add-object-error name expected-error error-offset
		(select rscg-functions-section 'ordinal) bad
]

bad: copy valid-rscg-object
missing-function-base: rscg-record-offset rscg-symbols-section 6
foreach [field value] reduce [
	schema/WIRE_RSCG_SYMBOL_KIND_OFFSET schema/WIRE_SYMBOL_KIND_FUNCTION
	schema/WIRE_RSCG_SYMBOL_OUTPUT_SECTION_OFFSET 1
	schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET 64
	schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET 0
	schema/WIRE_RSCG_SYMBOL_ALIGNMENT_OFFSET 16
][fixture-mutations/put-u32 bad (missing-function-base + field) value]
add-object-error 'MISSING-FUNCTION-RECORD
	schema/WIRE_RSCG_OBJECT_ERROR_MISSING_FUNCTION_RECORD
	(missing-function-base + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-symbols-section 1) + schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET) 32
add-malformed-rscg-object 'BAD-EXEC-IMAGE-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_EXEC_IMAGE_ROLE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-symbols-section 1) + schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-symbols-section 6) + schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET) 24
add-malformed-rscg-object 'BAD-SYMBOL-EXTENT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_SYMBOL_EXTENT
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	((rscg-record-offset rscg-symbols-section 6)
		+ schema/WIRE_RSCG_SYMBOL_SECTION_OFFSET_OFFSET)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-modules-section 1)
	+ schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET
fixture-mutations/put-u32 bad error-offset 5
add-object-error 'BAD-LIFECYCLE-SYMBOL
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_LIFECYCLE_SYMBOL
	error-offset (select rscg-modules-section 'ordinal) bad

bad: copy valid-rscg-object
second-module-base: rscg-record-offset rscg-modules-section 2
fixture-mutations/put-u32 bad
	(second-module-base + schema/WIRE_RSCG_MODULE_KIND_OFFSET)
	schema/WIRE_MODULE_KIND_RUNTIME
fixture-mutations/put-u32 bad
	(second-module-base + schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET) 0
add-object-error 'BAD-RUNTIME-MODULE-COUNT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_RUNTIME_MODULE_COUNT
	(second-module-base + schema/WIRE_RSCG_MODULE_KIND_OFFSET)
	(select rscg-modules-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-symbols-section 1)
		+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
	(rscg-id rscg-object-strings "***-lib-image")
add-object-error 'MISSING-EXEC-IMAGE-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_MISSING_EXEC_IMAGE_ROLE
	(select rscg-symbols-section 'payload-offset)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-symbols-section 2)
		+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
	(rscg-id rscg-object-strings "***-lib-image")
add-object-error 'MISSING-BITMAP-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_MISSING_BITMAP_ROLE
	(select rscg-symbols-section 'payload-offset)
	(select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
error-offset: (rscg-record-offset rscg-symbols-section 2)
	+ schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
fixture-mutations/put-u32 bad error-offset 30
add-object-error 'BAD-BITMAP-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_ROLE
	error-offset (select rscg-symbols-section 'ordinal) bad

bad: copy valid-rscg-object
bitmap-header-offset: (select rscg-output-data-section 'payload-offset) + 112
fixture-mutations/put-u32 bad bitmap-header-offset 1
add-object-error 'BAD-BITMAP-HEADER
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_BITMAP_HEADER
	bitmap-header-offset (select rscg-output-data-section 'ordinal) bad

bad: copy valid-rscg-dll-object
fixture-mutations/put-u32 bad
	((rscg-record-offset rscg-dll-symbols-section 2)
		+ schema/WIRE_RSCG_SYMBOL_NAME_STRING_OFFSET)
	(rscg-id rscg-object-strings "***-lib-placeholder")
add-object-error 'MISSING-LIB-IMAGE-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_MISSING_LIB_IMAGE_ROLE
	(select rscg-dll-symbols-section 'payload-offset)
	(select rscg-dll-symbols-section 'ordinal) bad

bad: copy valid-rscg-dll-object
lib-size-offset: (rscg-record-offset rscg-dll-symbols-section 2)
	+ schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET
fixture-mutations/put-u32 bad lib-size-offset 32
add-object-error 'BAD-LIB-IMAGE-ROLE
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_LIB_IMAGE_ROLE
	((rscg-record-offset rscg-dll-symbols-section 2)
		+ schema/WIRE_RSCG_SYMBOL_KIND_OFFSET)
	(select rscg-dll-symbols-section 'ordinal) bad

foreach fixture malformed-rscg-objects [
	result: rscg-object-verifier/verify fixture/10
	assert to logic! all [
		not result/valid?
		result/error = fixture/2
		result/container-error = fixture/3
		result/string-error = fixture/4
		result/file-source-error = fixture/5
		result/data-layout-error = fixture/6
		result/module-lifecycle-error = fixture/7
		result/error-offset = fixture/8
		result/error-section = fixture/9
	][
		fixture/1 " expected=" fixture/2 " actual=" result/error
		" location=" result/error-offset ":" result/error-section
	]
	assert none? result/view [fixture/1 " published an object view after failure"]
]

invalid-result: rscg-object-verifier/verify "not a binary"
assert to logic! all [
	not invalid-result/valid?
	invalid-result/error = schema/WIRE_RSCG_OBJECT_ERROR_INVALID_ARGUMENTS
	invalid-result/error-offset = 0
	invalid-result/error-section = 0
	none? invalid-result/view
] "RSCG object verifier invalid-argument contract changed"

covered-errors: reduce [
	schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-rscg-objects [
	unless find covered-errors fixture/2 [append covered-errors fixture/2]
]
repeat index 62 [
	assert not none? find covered-errors (index - 1) [
		"RSCG object error code lacks executable coverage: " index - 1
	]
]

unless value? 'generating-wire-rscg-object-fixtures? [
	source-bytes: make binary! 1'048'576
	foreach source-file [
		%wire-rscg-object-test.red
		%wire-module-lifecycle-test.red
		%wire-data-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-rscg-object-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-rscg-object-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System RSCG object fixtures are stale"
	print [
		"PASS: RSCG object layout"
		"valid=" 2
		"malformed=" length? malformed-rscg-objects
	]
]
