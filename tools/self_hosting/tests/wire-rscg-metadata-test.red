Red [
	Title: "Hybrid compiler RSCG debug, GC, and unwind metadata tests"
]

do %wire-rscg-relocation-test.red
do %../../../compiler/wire-rscg-metadata.red

rscg-metadata-verifier: compiler-wire-rscg-metadata

rscg-metadata-functions: fixture-writer/words [
	4 1 0 32 16 0 1 2 1 2
	3 1 32 32 0 0 3 1 3 1
]
rscg-metadata-debug-lines: fixture-writer/words [
	1 0 1 1 0
	1 8 1 2 3
	2 0 1 3 0
]
rscg-metadata-debug-parameters: fixture-writer/words reduce [
	1 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0
	1 1 schema/WIRE_DEBUG_TYPE_CODE_BYTE 0
	2 0 schema/WIRE_DEBUG_TYPE_CODE_LOGIC 0
]

valid-rscg-metadata: build-rscg-object-message
	rscg-output-sections rscg-output-data rscg-symbols #{} #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-gc-frames rscg-modules #{}

; The exact 31/32 boundary is part of the ABI: 31 slots use one word and
; 32 slots use two words with bit 31 set only on the first word.
rscg-boundary-output-data: copy rscg-output-data
rscg-boundary-bitmaps: fixture-writer/words [
	31 32 0 -2147483647 1
	32 31 -2147483647 1 0
]
fixture-mutations/put-bytes rscg-boundary-output-data 116 rscg-boundary-bitmaps
rscg-boundary-symbols: copy rscg-symbols
fixture-mutations/put-u32 rscg-boundary-symbols
	(schema/WIRE_RSCG_SYMBOL_SIZE + schema/WIRE_RSCG_SYMBOL_SIZE_OFFSET) 40
rscg-boundary-gc-frames: fixture-writer/words [
	1 3 44 20 0 9
	2 3 64 20 0 9
]
valid-rscg-boundary-metadata: build-rscg-object-message
	rscg-output-sections rscg-boundary-output-data rscg-boundary-symbols #{} #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-boundary-gc-frames rscg-modules #{}

; Dynamic argument maps reserve one marker word and declare zero static slots.
rscg-dynamic-output-data: copy rscg-output-data
fixture-mutations/put-u32 rscg-dynamic-output-data 124 1073741824
valid-rscg-dynamic-metadata: build-rscg-object-message
	rscg-output-sections rscg-dynamic-output-data rscg-symbols #{} #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-gc-frames rscg-modules #{}

rscg-metadata-dll-gc-frames: copy rscg-dll-gc-frames
fixture-mutations/put-u32 rscg-metadata-dll-gc-frames
	schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET
	schema/WIRE_RSCG_GC_FRAME_FLAG_LIBRARY_IMAGE
fixture-mutations/put-u32 rscg-metadata-dll-gc-frames
	(schema/WIRE_RSCG_GC_FRAME_SIZE + schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET)
	schema/WIRE_RSCG_GC_FRAME_FLAG_LIBRARY_IMAGE
valid-rscg-dll-metadata: build-rscg-object-message
	rscg-dll-output-sections rscg-dll-output-data rscg-dll-symbols #{} #{} #{}
	rscg-dll-functions rscg-debug-lines rscg-debug-parameters
	rscg-metadata-dll-gc-frames rscg-dll-modules #{}

valid-rscg-metadata-fixtures: reduce [
	reduce ['STANDARD valid-rscg-metadata 3 3 2]
	reduce ['BITMAP-31-32 valid-rscg-boundary-metadata 3 3 2]
	reduce ['DYNAMIC-BITMAP valid-rscg-dynamic-metadata 3 3 2]
	reduce ['DYNAMIC-LIBRARY valid-rscg-dll-metadata 2 1 2]
]

foreach fixture valid-rscg-metadata-fixtures [
	result: rscg-metadata-verifier/verify fixture/2
	assert result/valid? [
		"valid RSCG metadata " fixture/1 " rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert all [
		result/error = schema/WIRE_RSCG_METADATA_ERROR_SUCCESS
		result/relocation-error = schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		result/object-error = schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
		result/view/debug-line-count = fixture/3
		result/view/debug-parameter-count = fixture/4
		result/view/gc-frame-count = fixture/5
		result/view/unwind-function-count = 0
		result/object-view/function-count = 2
	] ["verified RSCG metadata view changed for " fixture/1]
]

rscg-metadata-sections: func [data [binary!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSCG
	reduce [
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_OUTPUT_DATA
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_SYMBOLS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_RELOCATIONS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_FUNCTIONS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_DEBUG_LINES
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_DEBUG_PARAMETERS
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_GC_FRAMES
		container-verifier/find-section verified schema/WIRE_RSCG_SECTION_UNWIND_FUNCTIONS
	]
]

metadata-sections: rscg-metadata-sections valid-rscg-metadata
metadata-output-data-section: metadata-sections/1
metadata-symbols-section: metadata-sections/2
metadata-relocations-section: metadata-sections/3
metadata-functions-section: metadata-sections/4
metadata-debug-lines-section: metadata-sections/5
metadata-debug-parameters-section: metadata-sections/6
metadata-gc-frames-section: metadata-sections/7

malformed-rscg-metadata: make block! 256
add-malformed-rscg-metadata: func [
	name [word!] expected-error expected-relocation expected-object expected-container
	expected-string expected-file expected-layout expected-module expected-offset
	expected-section [integer!] data [binary!]
][
	append/only malformed-rscg-metadata reduce [
		name expected-error expected-relocation expected-object expected-container
		expected-string expected-file expected-layout expected-module expected-offset
		expected-section data
	]
]

add-metadata-error: func [
	name [word!] expected-error expected-offset expected-section [integer!] data [binary!]
][
	add-malformed-rscg-metadata name expected-error
		schema/WIRE_RSCG_RELOCATION_ERROR_SUCCESS
		schema/WIRE_RSCG_OBJECT_ERROR_SUCCESS
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		expected-offset expected-section data
]

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-rscg-metadata 'INVALID-RELOCATIONS
	schema/WIRE_RSCG_METADATA_ERROR_INVALID_RELOCATIONS
	schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
	schema/WIRE_RSCG_OBJECT_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-debug-lines-section 1)
	+ schema/WIRE_RSCG_DEBUG_LINE_COLUMN_OFFSET
fixture-mutations/put-u32 bad error-offset -2147483648
add-metadata-error 'SCALAR-RANGE schema/WIRE_RSCG_METADATA_ERROR_SCALAR_RANGE
	error-offset (select metadata-debug-lines-section 'ordinal) bad

foreach [name section value expected-error] reduce [
	'BAD-DEBUG-LINE-SECTION-FLAGS metadata-debug-lines-section 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_SECTION_FLAGS
	'BAD-DEBUG-PARAMETER-SECTION-FLAGS metadata-debug-parameters-section 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_SECTION_FLAGS
	'BAD-GC-FRAME-SECTION-FLAGS metadata-gc-frames-section 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_SECTION_FLAGS
][
	bad: copy valid-rscg-metadata
	error-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad error-offset value
	add-metadata-error name expected-error error-offset (select section 'ordinal) bad
]

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-functions-section 1)
	+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
fixture-mutations/put-u32 bad error-offset 4
add-malformed-rscg-metadata 'BAD-DEBUG-LINE-RANGE
	schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_RANGE
	schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_LINE_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	error-offset (select metadata-functions-section 'ordinal) bad

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-functions-section 2)
	+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_LINE_OFFSET
fixture-mutations/put-u32 bad error-offset 2
add-metadata-error 'DEBUG-LINE-COVERAGE
	schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_COVERAGE
	error-offset (select metadata-functions-section 'ordinal) bad

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-debug-lines-section 1)
	+ schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-metadata-error 'BAD-DEBUG-LINE-FUNCTION
	schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_FUNCTION
	error-offset (select metadata-debug-lines-section 'ordinal) bad

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad
	((rscg-record-offset metadata-debug-lines-section 1)
		+ schema/WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET) 9
error-offset: (rscg-record-offset metadata-debug-lines-section 2)
	+ schema/WIRE_RSCG_DEBUG_LINE_FUNCTION_OFFSET
add-metadata-error 'DEBUG-LINE-ORDER schema/WIRE_RSCG_METADATA_ERROR_DEBUG_LINE_ORDER
	error-offset (select metadata-debug-lines-section 'ordinal) bad

foreach [name field value expected-error] reduce [
	'BAD-DEBUG-CODE-OFFSET schema/WIRE_RSCG_DEBUG_LINE_CODE_OFFSET_OFFSET 32
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_CODE_OFFSET
	'BAD-DEBUG-FILE schema/WIRE_RSCG_DEBUG_LINE_FILE_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_FILE
	'BAD-DEBUG-LINE-NUMBER schema/WIRE_RSCG_DEBUG_LINE_LINE_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_LINE_NUMBER
][
	bad: copy valid-rscg-metadata
	error-offset: (rscg-record-offset metadata-debug-lines-section 1) + field
	fixture-mutations/put-u32 bad error-offset value
	add-metadata-error name expected-error error-offset
		(select metadata-debug-lines-section 'ordinal) bad
]

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-functions-section 2)
	+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
fixture-mutations/put-u32 bad error-offset 4
add-malformed-rscg-metadata 'BAD-DEBUG-PARAMETER-RANGE
	schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_RANGE
	schema/WIRE_RSCG_RELOCATION_ERROR_INVALID_OBJECT
	schema/WIRE_RSCG_OBJECT_ERROR_BAD_DEBUG_PARAMETER_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	error-offset (select metadata-functions-section 'ordinal) bad

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-functions-section 2)
	+ schema/WIRE_RSCG_FUNCTION_FIRST_DEBUG_PARAMETER_OFFSET
fixture-mutations/put-u32 bad error-offset 2
add-metadata-error 'DEBUG-PARAMETER-COVERAGE
	schema/WIRE_RSCG_METADATA_ERROR_DEBUG_PARAMETER_COVERAGE
	error-offset (select metadata-functions-section 'ordinal) bad

foreach [name record field value expected-error] reduce [
	'BAD-DEBUG-PARAMETER-FUNCTION 1
		schema/WIRE_RSCG_DEBUG_PARAMETER_FUNCTION_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FUNCTION
	'BAD-DEBUG-PARAMETER-ORDINAL 2
		schema/WIRE_RSCG_DEBUG_PARAMETER_ORDINAL_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_ORDINAL
	'BAD-DEBUG-TYPE-CODE 1
		schema/WIRE_RSCG_DEBUG_PARAMETER_DEBUG_TYPE_CODE_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_TYPE_CODE
	'BAD-DEBUG-PARAMETER-FLAGS 1
		schema/WIRE_RSCG_DEBUG_PARAMETER_FLAGS_OFFSET 1
		schema/WIRE_RSCG_METADATA_ERROR_BAD_DEBUG_PARAMETER_FLAGS
][
	bad: copy valid-rscg-metadata
	error-offset: (rscg-record-offset metadata-debug-parameters-section record) + field
	fixture-mutations/put-u32 bad error-offset value
	add-metadata-error name expected-error error-offset
		(select metadata-debug-parameters-section 'ordinal) bad
]

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-gc-frames-section 1)
	+ schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
fixture-mutations/put-u32 bad error-offset 0
add-metadata-error 'BAD-GC-FUNCTION schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FUNCTION
	error-offset (select metadata-gc-frames-section 'ordinal) bad

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad
	((rscg-record-offset metadata-gc-frames-section 1)
		+ schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET) 2
error-offset: (rscg-record-offset metadata-gc-frames-section 2)
	+ schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
fixture-mutations/put-u32 bad error-offset 1
add-metadata-error 'GC-FRAME-ORDER schema/WIRE_RSCG_METADATA_ERROR_GC_FRAME_ORDER
	error-offset (select metadata-gc-frames-section 'ordinal) bad

bad: copy valid-rscg-metadata
error-offset: (rscg-record-offset metadata-gc-frames-section 2)
	+ schema/WIRE_RSCG_GC_FRAME_FUNCTION_OFFSET
fixture-mutations/put-u32 bad error-offset 1
add-metadata-error 'DUPLICATE-GC-FUNCTION
	schema/WIRE_RSCG_METADATA_ERROR_DUPLICATE_GC_FUNCTION
	error-offset (select metadata-gc-frames-section 'ordinal) bad

rscg-missing-gc: copy/part rscg-gc-frames schema/WIRE_RSCG_GC_FRAME_SIZE
bad: build-rscg-object-message
	rscg-output-sections rscg-output-data rscg-symbols #{} #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-missing-gc rscg-modules #{}
missing-sections: rscg-metadata-sections bad
error-offset: rscg-record-offset missing-sections/4 2
add-metadata-error 'MISSING-GC-FRAME schema/WIRE_RSCG_METADATA_ERROR_MISSING_GC_FRAME
	error-offset (select missing-sections/4 'ordinal) bad

foreach [name record field value expected-error] reduce [
	'BAD-BITMAP-SECTION 1 schema/WIRE_RSCG_GC_FRAME_BITMAP_SECTION_OFFSET 2
		schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SECTION
	'BAD-BITMAP-ALIGNMENT 1 schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET 45
		schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ALIGNMENT
	'BAD-BITMAP-RANGE 1 schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET 80
		schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_RANGE
	'BAD-BITMAP-SIZE 1 schema/WIRE_RSCG_GC_FRAME_BITMAP_SIZE_OFFSET 12
		schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SIZE
	'BITMAP-OVERLAP 2 schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET 56
		schema/WIRE_RSCG_METADATA_ERROR_BITMAP_OVERLAP
	'BAD-GC-FRAME-FLAGS 1 schema/WIRE_RSCG_GC_FRAME_FLAGS_OFFSET 2
		schema/WIRE_RSCG_METADATA_ERROR_BAD_GC_FRAME_FLAGS
	'BAD-PROLOG-PATCH 1 schema/WIRE_RSCG_GC_FRAME_PROLOG_PATCH_OFFSET_OFFSET 0
		schema/WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_PATCH
	'BAD-BITMAP-ROLE-COVERAGE 2 schema/WIRE_RSCG_GC_FRAME_BITMAP_OFFSET_OFFSET 64
		schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ROLE_COVERAGE
][
	bad: copy valid-rscg-metadata
	error-offset: (rscg-record-offset metadata-gc-frames-section record) + field
	fixture-mutations/put-u32 bad error-offset value
	add-metadata-error name expected-error error-offset
		(select metadata-gc-frames-section 'ordinal) bad
]

bitmap-base: (select metadata-output-data-section 'payload-offset) + 72 + 44

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad (bitmap-base + 8) -2147483648
add-metadata-error 'BAD-BITMAP-ENCODING
	schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_ENCODING
	(bitmap-base + 16) (select metadata-output-data-section 'ordinal) bad

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad bitmap-base 32
add-metadata-error 'BAD-BITMAP-SLOT-COUNT
	schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_SLOT_COUNT
	bitmap-base (select metadata-output-data-section 'ordinal) bad

bad: copy valid-rscg-metadata
fixture-mutations/put-u32 bad bitmap-base 1
fixture-mutations/put-u32 bad (bitmap-base + 8) 2
add-metadata-error 'BAD-BITMAP-UNUSED-BITS
	schema/WIRE_RSCG_METADATA_ERROR_BAD_BITMAP_UNUSED_BITS
	(bitmap-base + 8) (select metadata-output-data-section 'ordinal) bad

bad: copy valid-rscg-metadata
opcode-offset: (select metadata-output-data-section 'payload-offset) + 8
fixture-mutations/put-u32 bad opcode-offset 106
add-metadata-error 'BAD-PROLOG-OPCODE
	schema/WIRE_RSCG_METADATA_ERROR_BAD_PROLOG_OPCODE
	opcode-offset (select metadata-output-data-section 'ordinal) bad

bad: copy valid-rscg-metadata
patch-offset: (select metadata-output-data-section 'payload-offset) + 9
poke bad (patch-offset + 1) 1
add-metadata-error 'NONZERO-PROLOG-PLACEHOLDER
	schema/WIRE_RSCG_METADATA_ERROR_NONZERO_PROLOG_PLACEHOLDER
	patch-offset (select metadata-output-data-section 'ordinal) bad

rscg-prolog-relocation: fixture-writer/words reduce [
	1 9 schema/WIRE_RELOCATION_KIND_X64_REL32 3 -4 -1 4 0
]
bad: build-rscg-object-message
	rscg-output-sections rscg-output-data rscg-symbols rscg-prolog-relocation #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-gc-frames rscg-modules #{}
conflict-sections: rscg-metadata-sections bad
error-offset: (rscg-record-offset conflict-sections/3 1)
	+ schema/WIRE_RSCG_RELOCATION_SOURCE_OFFSET_OFFSET
add-metadata-error 'PROLOG-RELOCATION-CONFLICT
	schema/WIRE_RSCG_METADATA_ERROR_PROLOG_RELOCATION_CONFLICT
	error-offset (select conflict-sections/3 'ordinal) bad

rscg-unwind-record: fixture-writer/words [1 0 32 0 0 0]
valid-unwind-rscg: build-rscg-object-message
	rscg-output-sections rscg-output-data rscg-symbols #{} #{} #{}
	rscg-metadata-functions rscg-metadata-debug-lines
	rscg-metadata-debug-parameters rscg-gc-frames rscg-modules rscg-unwind-record
unwind-sections: rscg-metadata-sections valid-unwind-rscg
metadata-unwind-section: unwind-sections/8

bad: copy valid-unwind-rscg
error-offset: (select metadata-unwind-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad error-offset schema/WIRE_SECTION_FLAG_OPTIONAL
add-metadata-error 'BAD-UNWIND-SECTION-FLAGS
	schema/WIRE_RSCG_METADATA_ERROR_BAD_UNWIND_SECTION_FLAGS
	error-offset (select metadata-unwind-section 'ordinal) bad

add-metadata-error 'UNSUPPORTED-UNWIND
	schema/WIRE_RSCG_METADATA_ERROR_UNSUPPORTED_UNWIND
	(select metadata-unwind-section 'payload-offset)
	(select metadata-unwind-section 'ordinal) valid-unwind-rscg

foreach fixture malformed-rscg-metadata [
	result: rscg-metadata-verifier/verify fixture/12
	assert to logic! (not result/valid?) ["malformed RSCG metadata accepted: " fixture/1]
	assert all [
		result/error = fixture/2
		result/relocation-error = fixture/3
		result/object-error = fixture/4
		result/container-error = fixture/5
		result/string-error = fixture/6
		result/file-source-error = fixture/7
		result/data-layout-error = fixture/8
		result/module-lifecycle-error = fixture/9
		result/error-offset = fixture/10
		result/error-section = fixture/11
		none? result/view
	] [
		"wrong RSCG metadata failure for " fixture/1
		": got " result/error " at " result/error-offset ":" result/error-section
	]
]

invalid-argument-result: rscg-metadata-verifier/verify none
assert all [
	not invalid-argument-result/valid?
	invalid-argument-result/error = schema/WIRE_RSCG_METADATA_ERROR_INVALID_ARGUMENTS
	invalid-argument-result/error-offset = 0
	invalid-argument-result/error-section = 0
	none? invalid-argument-result/view
] "RSCG metadata invalid-argument handling changed"

seen-errors: make map! 128
put seen-errors schema/WIRE_RSCG_METADATA_ERROR_SUCCESS true
put seen-errors schema/WIRE_RSCG_METADATA_ERROR_INVALID_ARGUMENTS true
foreach fixture malformed-rscg-metadata [put seen-errors fixture/2 true]
repeat error-code 40 [
	assert to logic! select seen-errors (error-code - 1) [
		"RSCG metadata corpus misses error code " (error-code - 1)
	]
]

unless value? 'generating-wire-rscg-metadata-fixtures? [
	source-bytes: make binary! 2'097'152
	foreach source-file [
		%wire-rscg-metadata-test.red
		%wire-rscg-relocation-test.red
		%wire-rscg-object-test.red
		%wire-module-lifecycle-test.red
		%wire-data-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-rscg-metadata-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-rscg-metadata-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System RSCG metadata fixtures are stale"

	print rejoin [
		"RSCG metadata tests passed ("
		length? valid-rscg-metadata-fixtures " valid, "
		length? malformed-rscg-metadata " malformed)"
	]
]
