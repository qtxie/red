Red [
	Title: "Hybrid compiler RSCG relocation/import/export tests"
]

do %wire-rscg-object-test.red
do %../../../compiler/wire-rscg-relocation.red

rscg-relocation-verifier: compiler-wire-rscg-relocation

make-zeroed-relocation-code: func [/local code zeros][
	code: copy rscg-code
	zeros: make binary! 12
	append/dup zeros 0 12
	change/part at code 17 zeros 12
	code
]

rscg-relocation-code: make-zeroed-relocation-code
rscg-relocation-rodata: make binary! 8
append/dup rscg-relocation-rodata 0 8
rscg-relocation-output-data: make binary! 160
append rscg-relocation-output-data rscg-relocation-code
append rscg-relocation-output-data rscg-relocation-rodata
append rscg-relocation-output-data rscg-data

; Global definitions are exportable; unresolved GLOBAL symbols model an IAT
; function and an IAT variable. Symbol order remains canonical by string ID.
rscg-relocation-symbols: fixture-writer/words reduce [
	rscg-id rscg-object-strings "***-exec-image"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 0 40 8 0 1
	rscg-id rscg-object-strings "***-ptr-bitmaps"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 3 44 32 4 0 1
	rscg-id rscg-object-strings "entry"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 1 32 32 16 0 2
	rscg-id rscg-object-strings "glue"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 0 0 0 0
		schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 2
	rscg-id rscg-object-strings "init"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 0 32 16 0 1
	rscg-id rscg-object-strings "ro-constant"
		schema/WIRE_SYMBOL_KIND_CONSTANT schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 8 8 0 1
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 0 0 0 0
		schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 2
	rscg-id rscg-object-strings "state"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 4 0 16 8 0 1
]

rscg-relocation-functions: fixture-writer/words [
	5 1 0 32 16 0 1 1 1 1
	3 1 32 32 0 0 2 1 0 0
]
rscg-relocation-modules: fixture-writer/words reduce [
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_MODULE_KIND_RUNTIME schema/WIRE_IMAGE_KIND_EXECUTABLE 5 0 0 0 0
	rscg-id rscg-object-strings "glue"
		schema/WIRE_MODULE_KIND_GLUE schema/WIRE_IMAGE_KIND_EXECUTABLE 0 0 3 0 0
]

; Relative addends are sign-extended i32. ABSOLUTE64 rows deliberately use
; nontrivial high words to prove that their complete 64-bit bit pattern survives.
rscg-relocations: fixture-writer/words reduce [
	1 9 schema/WIRE_RELOCATION_KIND_X64_REL32 3 -4 -1 4 0
	1 16 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 4 0 0 4 0
	1 20 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 7 0 0 4 0
	1 24 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 6 4 0 4 0
	2 0 schema/WIRE_RELOCATION_KIND_ABSOLUTE64 8 -1 2147483647 8 0
	3 80 schema/WIRE_RELOCATION_KIND_ABSOLUTE64 3 0 -2147483648 8 0
]
rscg-imports: fixture-writer/words reduce [
	rscg-id rscg-object-strings "fixture.reds"
		rscg-id rscg-object-strings "entry" 4
		schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 0
	rscg-id rscg-object-strings "fixture.reds"
		rscg-id rscg-object-strings "state" 7 0 0 0
]
rscg-exe-exports: fixture-writer/words reduce [
	rscg-id rscg-object-strings "entry" 3 0 0
	rscg-id rscg-object-strings "state" 8 0 0
]

valid-rscg-relocation: build-rscg-object-message
	rscg-output-sections rscg-relocation-output-data rscg-relocation-symbols
	rscg-relocations rscg-imports #{} rscg-relocation-functions
	rscg-debug-lines rscg-debug-parameters rscg-gc-frames
	rscg-relocation-modules #{}

rscg-dll-relocation-output-data: make binary! 200
append rscg-dll-relocation-output-data rscg-relocation-code
append rscg-dll-relocation-output-data rscg-relocation-rodata
append rscg-dll-relocation-output-data rscg-dll-data

rscg-dll-relocation-symbols: fixture-writer/words reduce [
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
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 1 32 32 16 0 2
	rscg-id rscg-object-strings "glue"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 0 0 0 0
		schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 2
	rscg-id rscg-object-strings "init"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 1 0 32 16 0 1
	rscg-id rscg-object-strings "ro-constant"
		schema/WIRE_SYMBOL_KIND_CONSTANT schema/WIRE_SYMBOL_BINDING_LOCAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 8 8 0 1
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 0 0 0 0
		schema/WIRE_RSCG_SYMBOL_FLAG_UNDEFINED 2
	rscg-id rscg-object-strings "state"
		schema/WIRE_SYMBOL_KIND_GLOBAL schema/WIRE_SYMBOL_BINDING_GLOBAL
		schema/WIRE_VISIBILITY_DEFAULT 4 0 16 8 0 1
]
rscg-dll-relocations: fixture-writer/words reduce [
	1 9 schema/WIRE_RELOCATION_KIND_X64_REL32 4 -4 -1 4 0
	1 16 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 5 0 0 4 0
	1 20 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 8 0 0 4 0
	1 24 schema/WIRE_RELOCATION_KIND_X64_RIP_REL32 7 4 0 4 0
	2 0 schema/WIRE_RELOCATION_KIND_ABSOLUTE64 9 -1 2147483647 8 0
	3 120 schema/WIRE_RELOCATION_KIND_ABSOLUTE64 4 0 -2147483648 8 0
]
rscg-dll-imports: fixture-writer/words reduce [
	rscg-id rscg-object-strings "fixture.reds"
		rscg-id rscg-object-strings "entry" 5
		schema/WIRE_CALLING_CONVENTION_CDECL 0 0
	rscg-id rscg-object-strings "fixture.reds"
		rscg-id rscg-object-strings "state" 8 0 0 0
]
rscg-dll-exports: fixture-writer/words reduce [
	rscg-id rscg-object-strings "entry" 4 0 0
	rscg-id rscg-object-strings "state" 9 0 0
]
rscg-dll-relocation-functions: fixture-writer/words [
	6 1 0 32 16 0 1 1 1 1
	4 1 32 32 0 0 2 1 0 0
]
rscg-dll-relocation-modules: fixture-writer/words reduce [
	rscg-id rscg-object-strings "runtime"
		schema/WIRE_MODULE_KIND_RUNTIME schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY 6 0 0 0 0
	rscg-id rscg-object-strings "glue"
		schema/WIRE_MODULE_KIND_GLUE schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY 0 0 4 0 0
]
valid-rscg-dll-relocation: build-rscg-object-message
	rscg-dll-output-sections rscg-dll-relocation-output-data rscg-dll-relocation-symbols
	rscg-dll-relocations rscg-dll-imports rscg-dll-exports
	rscg-dll-relocation-functions rscg-debug-lines rscg-debug-parameters
	rscg-dll-gc-frames rscg-dll-relocation-modules #{}

valid-rscg-relocations: reduce [
	reduce ['EMPTY valid-rscg-object 0 0 0]
	reduce ['EXECUTABLE valid-rscg-relocation 6 2 0]
	reduce ['DYNAMIC-LIBRARY valid-rscg-dll-relocation 6 2 2]
]

foreach fixture valid-rscg-relocations [
	result: rscg-relocation-verifier/verify fixture/2
	assert result/valid? [
		"valid RSCG relocation object " fixture/1 " rejected with error " result/error
		" (object " result/object-error ")"
		" at " result/error-offset ":" result/error-section
	]
	assert all [
		result/error = schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		result/object-error = schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
		result/view/relocation-count = fixture/3
		result/view/import-count = fixture/4
		result/view/export-count = fixture/5
		result/object-view/output-section-count = 4
	] ["verified RSCG relocation view changed for " fixture/1]
]

rscg-relocation-sections: func [data [binary!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSCG
	reduce [
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_OUTPUT_DATA
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_SYMBOLS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_RELOCATIONS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_IMPORTS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_EXPORTS
	]
]

valid-relocation-sections: rscg-relocation-sections valid-rscg-relocation
rscg-relocation-output-data-section: valid-relocation-sections/1
rscg-relocation-symbols-section: valid-relocation-sections/2
rscg-relocations-section: valid-relocation-sections/3
rscg-imports-section: valid-relocation-sections/4
rscg-exports-section: valid-relocation-sections/5

valid-dll-relocation-sections: rscg-relocation-sections valid-rscg-dll-relocation
rscg-dll-relocations-section: valid-dll-relocation-sections/3
rscg-dll-imports-section: valid-dll-relocation-sections/4
rscg-dll-exports-section: valid-dll-relocation-sections/5

rscg-relocation-record-offset: func [section [map!] id [integer!]][
	(select section 'payload-offset) + ((id - 1) * (select section 'record-size))
]

replace-record: func [data [binary!] section [map!] destination source [integer!]][
	change/part at data ((rscg-relocation-record-offset section destination) + 1)
		copy/part at data ((rscg-relocation-record-offset section source) + 1)
			(select section 'record-size)
		(select section 'record-size)
	data
]

swap-records: func [data [binary!] section [map!] left right [integer!] /local a b size][
	size: select section 'record-size
	a: copy/part at data ((rscg-relocation-record-offset section left) + 1) size
	b: copy/part at data ((rscg-relocation-record-offset section right) + 1) size
	change/part at data ((rscg-relocation-record-offset section left) + 1) b size
	change/part at data ((rscg-relocation-record-offset section right) + 1) a size
	data
]

malformed-rscg-relocations: make block! 256
add-malformed-rscg-relocation: func [
	name [word!] expected-error expected-object expected-container expected-string
	expected-file expected-layout expected-module expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-rscg-relocations reduce [
		name expected-error expected-object expected-container expected-string
		expected-file expected-layout expected-module expected-offset expected-section data
	]
]

add-relocation-error: func [
	name [word!] expected-error expected-offset expected-section [integer!] data [binary!]
][
	add-malformed-rscg-relocation name expected-error
		schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		expected-offset expected-section data
]

bad: copy valid-rscg-relocation
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-rscg-relocation 'INVALID-OBJECT
	schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocations-section 1)
	+ schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET
fixture-mutations/put-u32 bad error-offset -2147483648
add-relocation-error 'SCALAR-RANGE schema/WIRE_RSCG_RELOCATION_ERROR_SCALAR_RANGE
	error-offset (select rscg-relocations-section 'ordinal) bad

foreach [name section expected-error] reduce [
	'BAD-RELOCATION-SECTION-FLAGS rscg-relocations-section
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_SECTION_FLAGS
	'BAD-IMPORT-SECTION-FLAGS rscg-imports-section
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SECTION_FLAGS
	'BAD-EXPORT-SECTION-FLAGS rscg-exports-section
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SECTION_FLAGS
][
	bad: copy valid-rscg-relocation
	error-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad error-offset 0
	add-relocation-error name expected-error error-offset (select section 'ordinal) bad
]

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocations-section 2)
	+ schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
fixture-mutations/put-u32 bad error-offset 8
add-relocation-error 'RELOCATION-ORDER schema/WIRE_RSCG_RELOCATION_ERROR_RELOCATION_ORDER
	error-offset (select rscg-relocations-section 'ordinal) bad

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocations-section 2)
	+ schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
fixture-mutations/put-u32 bad error-offset 11
add-relocation-error 'OVERLAPPING-RELOCATION
	schema/WIRE_RSCG_RELOCATION_ERROR_OVERLAPPING_RELOCATION
	error-offset (select rscg-relocations-section 'ordinal) bad

foreach [name record field value expected-error] reduce [
	'BAD-SOURCE-SECTION 1 schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_SECTION
	'BAD-SOURCE-CLASS 6 schema/WIRE_RSCG_RELOCATION_SOURCE_SECTION_OFFSET 4
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_CLASS
	'BAD-SOURCE-RANGE 6 schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET 85
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_SOURCE_RANGE
	'BAD-RELOCATION-KIND 1 schema/WIRE_RSCG_RELOCATION_KIND_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_KIND
	'UNSUPPORTED-RELOCATION-KIND 6 schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
		schema/WIRE_RELOCATION_KIND_ABSOLUTE32
		schema/WIRE_RSCG_RELOCATION_ERROR_UNSUPPORTED_RELOCATION_KIND
	'BAD-TARGET-SYMBOL 1 schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_TARGET_SYMBOL
	'BAD-ENCODED-WIDTH 1 schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET 8
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_ENCODED_WIDTH
	'BAD-RELOCATION-FLAGS 1 schema/WIRE_RSCG_RELOCATION_FLAGS_OFFSET 1
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_RELOCATION_FLAGS
	'BAD-ADDEND 1 schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_ADDEND
	'BAD-KIND-TARGET 1 schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET 8
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_TARGET
][
	bad: copy valid-rscg-relocation
	error-offset: (rscg-relocation-record-offset rscg-relocations-section record) + field
	fixture-mutations/put-u32 bad error-offset value
	add-relocation-error name expected-error error-offset
		(select rscg-relocations-section 'ordinal) bad
]

bad: copy valid-rscg-relocation
error-offset: (select rscg-relocation-output-data-section 'payload-offset) + 9
poke bad (error-offset + 1) 1
add-relocation-error 'NONZERO-PLACEHOLDER
	schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_PLACEHOLDER
	error-offset (select rscg-relocation-output-data-section 'ordinal) bad

bad: copy valid-rscg-relocation
base: rscg-relocation-record-offset rscg-relocations-section 6
fixture-mutations/put-u32 bad (base + schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
	schema/WIRE_RELOCATION_KIND_X64_REL32
fixture-mutations/put-u32 bad (base + schema/WIRE_RSCG_RELOCATION_ENCODED_WIDTH_OFFSET) 4
fixture-mutations/put-u32 bad (base + schema/WIRE_RSCG_RELOCATION_RAW_ADDEND_HIGH_OFFSET) 0
add-relocation-error 'BAD-KIND-SOURCE schema/WIRE_RSCG_RELOCATION_ERROR_BAD_KIND_SOURCE
	(base + schema/WIRE_RSCG_RELOCATION_KIND_OFFSET)
	(select rscg-relocations-section 'ordinal) bad

foreach [name record field value expected-error] reduce [
	'BAD-IMPORT-LIBRARY-ID 1 schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_LIBRARY_ID
	'EMPTY-IMPORT-LIBRARY 1 schema/WIRE_IMPORT_LIBRARY_STRING_OFFSET
		(rscg-id rscg-object-strings "")
		schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_LIBRARY
	'BAD-IMPORT-EXTERNAL-NAME-ID 1 schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_EXTERNAL_NAME_ID
	'EMPTY-IMPORT-EXTERNAL-NAME 1 schema/WIRE_IMPORT_EXTERNAL_NAME_STRING_OFFSET
		(rscg-id rscg-object-strings "")
		schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_IMPORT_EXTERNAL_NAME
	'BAD-IMPORT-SYMBOL 1 schema/WIRE_IMPORT_SYMBOL_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL
	'BAD-IMPORT-SYMBOL-KIND 1 schema/WIRE_IMPORT_SYMBOL_OFFSET 6
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_SYMBOL_KIND
	'BAD-IMPORT-CALLING-CONVENTION 1 schema/WIRE_IMPORT_CALLING_CONVENTION_OFFSET
		schema/WIRE_CALLING_CONVENTION_SYSCALL
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_CALLING_CONVENTION
	'NONZERO-IMPORT-FLAGS 1 schema/WIRE_IMPORT_FLAGS_OFFSET 1
		schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_FLAGS
	'NONZERO-IMPORT-SOURCE-LOCATION 1 schema/WIRE_IMPORT_SOURCE_LOCATION_OFFSET 1
		schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_IMPORT_SOURCE_LOCATION
][
	bad: copy valid-rscg-relocation
	error-offset: (rscg-relocation-record-offset rscg-imports-section record) + field
	fixture-mutations/put-u32 bad error-offset value
	add-relocation-error name expected-error error-offset (select rscg-imports-section 'ordinal) bad
]

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocation-symbols-section 4)
	+ schema/WIRE_RSCG_SYMBOL_BINDING_OFFSET
fixture-mutations/put-u32 bad error-offset schema/WIRE_SYMBOL_BINDING_WEAK
add-relocation-error 'BAD-IMPORT-BINDING schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_BINDING
	((rscg-relocation-record-offset rscg-imports-section 1)
		+ schema/WIRE_IMPORT_SYMBOL_OFFSET)
	(select rscg-imports-section 'ordinal) bad

bad: copy valid-rscg-relocation
swap-records bad rscg-imports-section 1 2
error-offset: (rscg-relocation-record-offset rscg-imports-section 2)
	+ schema/WIRE_IMPORT_SYMBOL_OFFSET
add-relocation-error 'IMPORT-ORDER schema/WIRE_RSCG_RELOCATION_ERROR_IMPORT_ORDER
	error-offset (select rscg-imports-section 'ordinal) bad

bad: copy valid-rscg-relocation
replace-record bad rscg-imports-section 2 1
error-offset: (rscg-relocation-record-offset rscg-imports-section 2)
	+ schema/WIRE_IMPORT_SYMBOL_OFFSET
add-relocation-error 'DUPLICATE-IMPORT-SYMBOL
	schema/WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_IMPORT_SYMBOL
	error-offset (select rscg-imports-section 'ordinal) bad

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocations-section 3)
	+ schema/WIRE_RSCG_RELOCATION_TARGET_SYMBOL_OFFSET
fixture-mutations/put-u32 bad error-offset 8
add-relocation-error 'UNUSED-IMPORT schema/WIRE_RSCG_RELOCATION_ERROR_UNUSED_IMPORT
	((rscg-relocation-record-offset rscg-imports-section 2) + schema/WIRE_IMPORT_SYMBOL_OFFSET)
	(select rscg-imports-section 'ordinal) bad

bad: copy valid-rscg-relocation
error-offset: (rscg-relocation-record-offset rscg-relocations-section 2)
	+ schema/WIRE_RSCG_RELOCATION_KIND_OFFSET
fixture-mutations/put-u32 bad error-offset schema/WIRE_RELOCATION_KIND_X64_REL32
add-relocation-error 'BAD-IMPORT-RELOCATION-KIND
	schema/WIRE_RSCG_RELOCATION_ERROR_BAD_IMPORT_RELOCATION_KIND
	error-offset (select rscg-relocations-section 'ordinal) bad

bad-exe-exports: build-rscg-object-message
	rscg-output-sections rscg-relocation-output-data rscg-relocation-symbols
	rscg-relocations rscg-imports rscg-exe-exports rscg-relocation-functions
	rscg-debug-lines rscg-debug-parameters rscg-gc-frames
	rscg-relocation-modules #{}
bad-exe-export-section: fifth rscg-relocation-sections bad-exe-exports
add-relocation-error 'BAD-EXPORT-IMAGE-KIND
	schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_IMAGE_KIND
	(select bad-exe-export-section 'payload-offset)
	(select bad-exe-export-section 'ordinal) bad-exe-exports

foreach [name record field value expected-error] reduce [
	'BAD-EXPORT-EXTERNAL-NAME-ID 1 schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_EXTERNAL_NAME_ID
	'EMPTY-EXPORT-EXTERNAL-NAME 1 schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
		(rscg-id rscg-object-strings "")
		schema/WIRE_RSCG_RELOCATION_ERROR_EMPTY_EXPORT_EXTERNAL_NAME
	'BAD-EXPORT-SYMBOL 1 schema/WIRE_EXPORT_SYMBOL_OFFSET 0
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL
	'BAD-EXPORT-SYMBOL-KIND 1 schema/WIRE_EXPORT_SYMBOL_OFFSET 7
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_SYMBOL_KIND
	'BAD-EXPORT-BINDING 1 schema/WIRE_EXPORT_SYMBOL_OFFSET 6
		schema/WIRE_RSCG_RELOCATION_ERROR_BAD_EXPORT_BINDING
	'NONZERO-EXPORT-ORDINAL 1 schema/WIRE_EXPORT_ORDINAL_OFFSET 1
		schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_ORDINAL
	'NONZERO-EXPORT-FLAGS 1 schema/WIRE_EXPORT_FLAGS_OFFSET 1
		schema/WIRE_RSCG_RELOCATION_ERROR_NONZERO_EXPORT_FLAGS
][
	bad: copy valid-rscg-dll-relocation
	error-offset: (rscg-relocation-record-offset rscg-dll-exports-section record) + field
	fixture-mutations/put-u32 bad error-offset value
	add-relocation-error name expected-error error-offset
		(select rscg-dll-exports-section 'ordinal) bad
]

bad: copy valid-rscg-dll-relocation
swap-records bad rscg-dll-exports-section 1 2
error-offset: (rscg-relocation-record-offset rscg-dll-exports-section 2)
	+ schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
add-relocation-error 'EXPORT-ORDER schema/WIRE_RSCG_RELOCATION_ERROR_EXPORT_ORDER
	error-offset (select rscg-dll-exports-section 'ordinal) bad

bad: copy valid-rscg-dll-relocation
replace-record bad rscg-dll-exports-section 2 1
error-offset: (rscg-relocation-record-offset rscg-dll-exports-section 2)
	+ schema/WIRE_EXPORT_EXTERNAL_NAME_STRING_OFFSET
add-relocation-error 'DUPLICATE-EXPORT-NAME
	schema/WIRE_RSCG_RELOCATION_ERROR_DUPLICATE_EXPORT_NAME
	error-offset (select rscg-dll-exports-section 'ordinal) bad

foreach fixture malformed-rscg-relocations [
	result: rscg-relocation-verifier/verify fixture/11
	assert to logic! (not result/valid?) ["malformed RSCG relocation accepted: " fixture/1]
	assert all [
		result/error = fixture/2
		result/object-error = fixture/3
		result/container-error = fixture/4
		result/string-error = fixture/5
		result/file-source-error = fixture/6
		result/data-layout-error = fixture/7
		result/module-lifecycle-error = fixture/8
		result/error-offset = fixture/9
		result/error-section = fixture/10
	] [
		"wrong RSCG relocation failure for " fixture/1
		": got " result/error " at " result/error-offset ":" result/error-section
	]
]

invalid-argument-result: rscg-relocation-verifier/verify none
assert all [
	not invalid-argument-result/valid?
	invalid-argument-result/error = schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_ARGUMENTS
	invalid-argument-result/error-offset = 0
	invalid-argument-result/error-section = 0
] "RSCG relocation invalid-argument handling changed"

seen-errors: make map! 128
put seen-errors schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS true
put seen-errors schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_ARGUMENTS true
foreach fixture malformed-rscg-relocations [put seen-errors fixture/2 true]
repeat error-code 45 [
	assert to logic! select seen-errors (error-code - 1) [
		"RSCG relocation corpus misses error code " (error-code - 1)
	]
]

unless value? 'generating-wire-rscg-relocation-fixtures? [
	source-bytes: make binary! 2'097'152
	foreach source-file [
		%wire-rscg-relocation-test.red
		%wire-rscg-object-test.red
		%wire-module-lifecycle-test.red
		%wire-data-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-rscg-relocation-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-rscg-relocation-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System RSCG relocation fixtures are stale"

	print rejoin [
		"RSCG relocation tests passed ("
		length? valid-rscg-relocations " valid, "
		length? malformed-rscg-relocations " malformed)"
	]
]
