Red [
	Title: "Hybrid compiler file and source metadata tests"
]

do %wire-string-table-test.red
do %../../../compiler/wire-file-source.red

file-source-verifier: compiler-wire-file-source

bytes-of-size: func [size [integer!] /local output index][
	output: make binary! size
	repeat index size [append output ((index - 1) and 255)]
	output
]

build-file-source-message: func [
	magic [integer!]
	string-records string-data file-records checksum-data source-records [binary!]
	/local payloads string-kinds metadata-kinds sections
][
	payloads: make map! 16
	case [
		magic = schema/WIRE_MAGIC_RSIR [
			put payloads schema/WIRE_RSIR_SECTION_MODULE
				fixture-writer/words [2 2 1 0 0 0 0 0]
			put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
		]
		magic = schema/WIRE_MAGIC_RSCG [
			put payloads schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
			put payloads schema/WIRE_RSCG_SECTION_MODULES
				fixture-writer/words [2 2 1 0 0 0 0 0]
		]
		true [return none]
	]
	string-kinds: string-verifier/section-kinds-for magic
	metadata-kinds: file-source-verifier/section-kinds-for magic
	put payloads string-kinds/1 string-records
	put payloads string-kinds/2 string-data
	put payloads metadata-kinds/1 file-records
	put payloads metadata-kinds/2 checksum-data
	if metadata-kinds/3 <> 0 [put payloads metadata-kinds/3 source-records]
	sections: fixture-writer/sections-for magic payloads
	fixture-writer/set-section-flags sections string-kinds/1
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections metadata-kinds/1
		file-source-verifier/expected-index-flags
	if metadata-kinds/3 <> 0 [
		fixture-writer/set-section-flags sections metadata-kinds/3
			file-source-verifier/expected-index-flags
	]
	fixture-writer/build
		magic
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

file-source-sections: func [
	data [binary!]
	magic [integer!]
	/local result kinds
][
	result: container-verifier/verify/expect data magic
	assert result/valid? "file/source fixture is not a valid common container"
	kinds: file-source-verifier/section-kinds-for magic
	reduce [
		container-verifier/find-section result kinds/1
		container-verifier/find-section result kinds/2
		either kinds/3 = 0 [none][container-verifier/find-section result kinds/3]
	]
]

result: file-source-verifier/verify none schema/WIRE_MAGIC_RSIR
assert all [
	not result/valid?
	result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/view
] "non-binary file/source input did not return INVALID_ARGUMENTS"

result: file-source-verifier/verify rsir 'RSIR
assert result/error = schema/WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS
	"non-integer file/source magic did not return INVALID_ARGUMENTS"

result: file-source-verifier/verify rsdg schema/WIRE_MAGIC_RSDG
assert all [
	not result/valid?
	result/error = schema/WIRE_FILE_SOURCE_ERROR_UNSUPPORTED_MESSAGE
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/view
] "unsupported file/source message kind was accepted"

path-string-records: fixture-writer/words [0 0 0 5 5 5]
path-string-data: #{612E726564622E726564}
checksum-32: bytes-of-size 32
valid-file-records: fixture-writer/words [
	2 0 0 0
	3 1 0 32
]
valid-source-records: fixture-writer/words [
	1 1 1 0
	1 1 2 1
	2 3 4 10
]

metadata-rsir: build-file-source-message
	schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data
	valid-file-records checksum-32 valid-source-records
metadata-rscg: build-file-source-message
	schema/WIRE_MAGIC_RSCG
	path-string-records path-string-data
	valid-file-records checksum-32 #{}

valid-file-sources: make block! 16
add-valid-file-source: func [name [word!] magic [integer!] data [binary!]][
	append/only valid-file-sources reduce [name magic data]
]

add-valid-file-source 'RSIR-EMPTY schema/WIRE_MAGIC_RSIR rsir
add-valid-file-source 'RSCG-EMPTY schema/WIRE_MAGIC_RSCG rscg
add-valid-file-source 'RSIR-METADATA schema/WIRE_MAGIC_RSIR metadata-rsir
add-valid-file-source 'RSCG-METADATA schema/WIRE_MAGIC_RSCG metadata-rscg

foreach fixture valid-file-sources [
	result: file-source-verifier/verify fixture/3 fixture/2
	assert result/valid? [
		fixture/1 " valid file/source metadata rejected with error " result/error
	]
	assert result/error = schema/WIRE_FILE_SOURCE_ERROR_SUCCESS [
		fixture/1 " valid file/source metadata returned a nonzero error"
	]
	assert result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS [
		fixture/1 " valid file/source metadata returned a container error"
	]
	assert result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS [
		fixture/1 " valid file/source metadata returned a string error"
	]
	assert all [result/error-offset = 0 result/error-section = 0][
		fixture/1 " valid file/source metadata returned an error location"
	]
	assert all [object? result/strings object? result/view][
		fixture/1 " valid file/source metadata exposed no verified view"
	]
]

metadata-sections: file-source-sections metadata-rsir schema/WIRE_MAGIC_RSIR
files-section: metadata-sections/1
checksum-section: metadata-sections/2
source-section: metadata-sections/3
files-offset: select files-section 'payload-offset
files-ordinal: select files-section 'ordinal
checksum-offset: select checksum-section 'payload-offset
checksum-ordinal: select checksum-section 'ordinal
source-offset: select source-section 'payload-offset
source-ordinal: select source-section 'ordinal

result: file-source-verifier/verify metadata-rsir schema/WIRE_MAGIC_RSIR
assert all [
	result/strings/record-count = 3
	result/view/file-count = 2
	result/view/files-offset = files-offset
	result/view/files-ordinal = files-ordinal
	result/view/file-record-size = schema/WIRE_FILE_SIZE
	result/view/checksum-data-offset = checksum-offset
	result/view/checksum-data-size = 32
	result/view/checksum-data-ordinal = checksum-ordinal
	result/view/source-present?
	result/view/source-count = 3
	result/view/source-offset = source-offset
	result/view/source-ordinal = source-ordinal
	result/view/source-record-size = schema/WIRE_SOURCE_LOCATION_SIZE
] "verified RSIR file/source view changed"

result: file-source-verifier/verify metadata-rscg schema/WIRE_MAGIC_RSCG
assert all [
	result/view/file-count = 2
	not result/view/source-present?
	result/view/source-count = 0
	result/view/source-offset = 0
	result/view/source-ordinal = 0
] "verified RSCG file view changed"

malformed-file-sources: make block! 192
add-malformed-file-source: func [
	name [word!]
	magic expected-error expected-container expected-string expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-file-sources reduce [
		name magic expected-error expected-container expected-string
		expected-offset expected-section data
	]
]

bad: copy metadata-rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-file-source 'INVALID-CONTAINER schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

metadata-string-sections: string-sections metadata-rsir schema/WIRE_MAGIC_RSIR
metadata-string-data: metadata-string-sections/2
bad: copy metadata-rsir
fixture-mutations/put-bytes bad (select metadata-string-data 'payload-offset) #{80}
add-malformed-file-source 'INVALID-STRINGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
	(select metadata-string-data 'payload-offset)
	(select metadata-string-data 'ordinal) bad

foreach [field-name field-offset] file-source-verifier/file-fields [
	bad: copy metadata-rsir
	fixture-mutations/put-bytes bad (files-offset + field-offset) #{00000080}
	add-malformed-file-source to word! rejoin ["SCALAR-FILE-" field-name]
		schema/WIRE_MAGIC_RSIR schema/WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
		schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		(files-offset + field-offset) files-ordinal bad
]

foreach [field-name field-offset] file-source-verifier/source-fields [
	bad: copy metadata-rsir
	fixture-mutations/put-bytes bad (source-offset + field-offset) #{00000080}
	add-malformed-file-source to word! rejoin ["SCALAR-SOURCE-" field-name]
		schema/WIRE_MAGIC_RSIR schema/WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
		schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		(source-offset + field-offset) source-ordinal bad
]

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	((select files-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-file-source 'BAD-FILES-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_FILES_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select files-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	((select checksum-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_SORTED
add-malformed-file-source 'BAD-CHECKSUM-DATA-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_DATA_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select checksum-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	checksum-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	((select source-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-file-source 'BAD-SOURCE-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select source-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	source-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) 0
add-malformed-file-source 'FILE-PATH-ZERO schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) 4
add-malformed-file-source 'FILE-PATH-RANGE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) 1
add-malformed-file-source 'EMPTY-FILE-PATH schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_EMPTY_FILE_PATH
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) files-ordinal bad

bad-order-files: fixture-writer/words [
	3 0 0 0
	2 1 0 32
]
bad-order: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data bad-order-files checksum-32 #{}
bad-order-sections: file-source-sections bad-order schema/WIRE_MAGIC_RSIR
bad-order-file-section: bad-order-sections/1
add-malformed-file-source 'FILE-ORDER schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_FILE_ORDER
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select bad-order-file-section 'payload-offset) + schema/WIRE_FILE_SIZE)
	(select bad-order-file-section 'ordinal) bad-order

duplicate-files: fixture-writer/words [
	2 0 0 0
	2 1 0 32
]
duplicate-file-message: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data duplicate-files checksum-32 #{}
duplicate-file-sections:
	file-source-sections duplicate-file-message schema/WIRE_MAGIC_RSIR
duplicate-file-section: duplicate-file-sections/1
add-malformed-file-source 'DUPLICATE-FILE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_FILE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select duplicate-file-section 'payload-offset) + schema/WIRE_FILE_SIZE)
	(select duplicate-file-section 'ordinal) duplicate-file-message

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_CHECKSUM_KIND_OFFSET) 2
add-malformed-file-source 'BAD-CHECKSUM-KIND schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_KIND
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_CHECKSUM_KIND_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) 1
add-malformed-file-source 'BAD-NONE-OFFSET schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_OFFSET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET) 1
add-malformed-file-source 'BAD-NONE-SIZE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(files-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET) files-ordinal bad

second-file-offset: files-offset + schema/WIRE_FILE_SIZE
bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET) 31
add-malformed-file-source 'BAD-SHA256-SIZE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SIZE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_SIZE_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) 1
add-malformed-file-source 'CHECKSUM-SLICE-RANGE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SLICE_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) files-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) 2147483647
add-malformed-file-source 'CHECKSUM-SLICE-OVERFLOW schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_BAD_CHECKSUM_SLICE_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(second-file-offset + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET) files-ordinal bad

checksum-gap-files: fixture-writer/words [
	2 1 0 32
	3 1 33 32
]
checksum-gap: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data checksum-gap-files (bytes-of-size 65) #{}
checksum-gap-sections: file-source-sections checksum-gap schema/WIRE_MAGIC_RSIR
checksum-gap-file-section: checksum-gap-sections/1
add-malformed-file-source 'CHECKSUM-COVERAGE-GAP schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select checksum-gap-file-section 'payload-offset)
		+ schema/WIRE_FILE_SIZE + schema/WIRE_FILE_CHECKSUM_OFFSET_OFFSET)
	(select checksum-gap-file-section 'ordinal) checksum-gap

checksum-trailing-files: fixture-writer/words [2 1 0 32]
checksum-trailing: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data
	checksum-trailing-files (bytes-of-size 33) #{}
checksum-trailing-sections:
	file-source-sections checksum-trailing schema/WIRE_MAGIC_RSIR
checksum-trailing-data: checksum-trailing-sections/2
add-malformed-file-source 'CHECKSUM-COVERAGE-TRAILING schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_CHECKSUM_DATA_COVERAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select checksum-trailing-data 'payload-offset) + 32)
	(select checksum-trailing-data 'ordinal) checksum-trailing

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(source-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET) 0
add-malformed-file-source 'SOURCE-FILE-ZERO schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SOURCE_FILE_ID
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(source-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET) source-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(source-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET) 3
add-malformed-file-source 'SOURCE-FILE-RANGE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SOURCE_FILE_ID
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(source-offset + schema/WIRE_SOURCE_LOCATION_FILE_OFFSET) source-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(source-offset + schema/WIRE_SOURCE_LOCATION_LINE_OFFSET) 0
add-malformed-file-source 'SOURCE-LINE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SOURCE_LINE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(source-offset + schema/WIRE_SOURCE_LOCATION_LINE_OFFSET) source-ordinal bad

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(source-offset + schema/WIRE_SOURCE_LOCATION_COLUMN_OFFSET) 0
add-malformed-file-source 'SOURCE-COLUMN schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SOURCE_COLUMN
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	(source-offset + schema/WIRE_SOURCE_LOCATION_COLUMN_OFFSET) source-ordinal bad

one-file: fixture-writer/words [2 0 0 0]
source-order-records: fixture-writer/words [
	1 1 1 1
	1 1 2 0
]
source-order-message: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data one-file #{} source-order-records
source-order-sections:
	file-source-sections source-order-message schema/WIRE_MAGIC_RSIR
source-order-section: source-order-sections/3
add-malformed-file-source 'SOURCE-ORDER schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SOURCE_ORDER
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select source-order-section 'payload-offset) + schema/WIRE_SOURCE_LOCATION_SIZE)
	(select source-order-section 'ordinal) source-order-message

duplicate-source-records: fixture-writer/words [
	1 1 1 0
	1 1 1 0
]
duplicate-source-message: build-file-source-message schema/WIRE_MAGIC_RSIR
	path-string-records path-string-data one-file #{} duplicate-source-records
duplicate-source-sections:
	file-source-sections duplicate-source-message schema/WIRE_MAGIC_RSIR
duplicate-source-section: duplicate-source-sections/3
add-malformed-file-source 'DUPLICATE-SOURCE schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select duplicate-source-section 'payload-offset)
		+ schema/WIRE_SOURCE_LOCATION_SIZE)
	(select duplicate-source-section 'ordinal) duplicate-source-message

bad: copy metadata-rsir
fixture-mutations/put-u32 bad
	(files-offset + schema/WIRE_FILE_PATH_STRING_OFFSET) 0
last-source-byte-field:
	source-offset
	+ ((3 - 1) * schema/WIRE_SOURCE_LOCATION_SIZE)
	+ schema/WIRE_SOURCE_LOCATION_BYTE_OFFSET_OFFSET
fixture-mutations/put-bytes bad last-source-byte-field #{00000080}
add-malformed-file-source 'SCALAR-BEFORE-PATH schema/WIRE_MAGIC_RSIR
	schema/WIRE_FILE_SOURCE_ERROR_SCALAR_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	last-source-byte-field source-ordinal bad

rscg-sections: file-source-sections metadata-rscg schema/WIRE_MAGIC_RSCG
rscg-files-section: rscg-sections/1
bad: copy metadata-rscg
fixture-mutations/put-u32 bad
	((select rscg-files-section 'payload-offset) + schema/WIRE_FILE_PATH_STRING_OFFSET) 0
add-malformed-file-source 'RSCG-FILE-PATH schema/WIRE_MAGIC_RSCG
	schema/WIRE_FILE_SOURCE_ERROR_FILE_PATH_ID
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select rscg-files-section 'payload-offset) + schema/WIRE_FILE_PATH_STRING_OFFSET)
	(select rscg-files-section 'ordinal) bad

foreach fixture malformed-file-sources [
	result: file-source-verifier/verify fixture/8 fixture/2
	assert not result/valid? [fixture/1 " malformed file/source metadata was accepted"]
	assert all [none? result/strings none? result/view][
		fixture/1 " malformed file/source metadata exposed verified views"
	]
	assert result/error = fixture/3 [
		fixture/1 " expected error " fixture/3 " but got " result/error
	]
	assert result/container-error = fixture/4 [
		fixture/1 " expected container error " fixture/4
		" but got " result/container-error
	]
	assert result/string-error = fixture/5 [
		fixture/1 " expected string error " fixture/5
		" but got " result/string-error
	]
	assert all [
		result/error-offset = fixture/6
		result/error-section = fixture/7
	][
		fixture/1 " expected location " fixture/6 ":" fixture/7
		" but got " result/error-offset ":" result/error-section
	]
]

covered-errors: reduce [
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_ARGUMENTS
	schema/WIRE_FILE_SOURCE_ERROR_UNSUPPORTED_MESSAGE
]
foreach fixture malformed-file-sources [append covered-errors fixture/3]
repeat error-index (schema/WIRE_FILE_SOURCE_ERROR_DUPLICATE_SOURCE + 1)[
	expected-error: error-index - 1
	assert not none? find covered-errors expected-error [
		"file/source error code has no directed Red test: " expected-error
	]
]

generating?: all [
	value? 'generating-wire-file-source-fixtures?
	get 'generating-wire-file-source-fixtures?
]
unless generating? [
	source-bytes: make binary! 131072
	append source-bytes read %wire-file-source-test.red
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-file-source-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-file-source-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System file/source semantic fixtures are stale"
]

print [
	"PASS: file/source metadata semantics"
	"valid=" length? valid-file-sources
	"malformed=" length? malformed-file-sources
]
