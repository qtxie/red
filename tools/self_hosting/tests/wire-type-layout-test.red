Red [
	Title: "Hybrid compiler RSIR type and aggregate-layout tests"
]

do %wire-file-source-test.red
do %../../../compiler/wire-data-layout.red
do %../../../compiler/wire-type-layout.red

type-layout-verifier: compiler-wire-type-layout

build-type-layout-message: func [
	string-records string-data type-records field-records signature-records
	/local payloads sections
][
	payloads: make map! 32
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [1 0 0 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSIR_SECTION_TYPES type-records
	put payloads schema/WIRE_RSIR_SECTION_FIELDS field-records
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES signature-records
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

type-layout-sections: func [data [binary!] /local result][
	result: container-verifier/verify/expect data schema/WIRE_MAGIC_RSIR
	assert result/valid? "type-layout fixture is not a valid common container"
	reduce [
		container-verifier/find-section result schema/WIRE_RSIR_SECTION_TYPES
		container-verifier/find-section result schema/WIRE_RSIR_SECTION_FIELDS
		container-verifier/find-section result schema/WIRE_RSIR_SECTION_SIGNATURES
	]
]

result: type-layout-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/file-source-error = schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	result/data-layout-error = schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/files
	none? result/layout
	none? result/view
] "non-binary type-layout input did not return INVALID_ARGUMENTS"

type-strings: fixture-writer/words [
	0 0
	0 1
	1 1
	2 1
	3 1
	4 1
	5 1
	6 1
	7 1
]
type-string-data: to binary! "abcdefgh"

valid-types: fixture-writer/words [
	; kind flags size align reserved detail reserved first count gc
	1 0 0 0 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 2
	4 0 8 8 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	5 0 8 8 0 13 0 0 0 1
	5 4 8 8 0 2 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
	7 0 8 4 0 0 0 1 2 0
	8 0 8 8 0 0 0 3 2 0
	8 2 16 8 0 2 0 5 2 0
	7 0 24 8 0 0 0 7 3 0
]
valid-fields: fixture-writer/words [
	; owner name type offset flags ordinal source reserved
	10 6 2 0 0 0 0 0
	10 7 3 4 0 1 0 0
	11 3 3 0 0 0 0 0
	11 4 5 0 0 1 0 0
	12 3 3 8 0 0 0 0
	12 4 5 8 0 1 0 0
	13 6 2 0 0 0 0 0
	13 8 10 4 0 1 0 0
	13 9 7 16 0 2 0 0
]
signature-placeholder: fixture-writer/words [1 0 1 0 0 0 0 0]

type-layout-message: build-type-layout-message
	type-strings type-string-data valid-types valid-fields signature-placeholder
empty-type-layout-message: build-type-layout-message
	fixture-writer/words [0 0] #{} #{} #{} #{}

build-tag-width-boundary-message: func [
	/local string-record-values string-data field-values index name
][
	string-record-values: make block! 520
	append string-record-values [0 0]
	string-data: make binary! 1024
	field-values: make block! 2048
	repeat index 256 [
		name: form (999 + index)
		repend string-record-values [length? string-data length? name]
		append string-data to binary! name
		repend field-values [3 (index + 1) 1 2 0 (index - 1) 0 0]
	]
	build-type-layout-message
		fixture-writer/words string-record-values
		string-data
		fixture-writer/words [
			; uint8, uint16, then a 256-variant tagged union.
			3 0 1 1 0 0 0 0 0 0
			3 0 2 2 0 0 0 0 0 0
			8 2 3 1 0 2 0 1 256 0
		]
		fixture-writer/words field-values
		#{}
]

tag-width-boundary-message: build-tag-width-boundary-message

valid-type-layouts: make block! 8
add-valid-type-layout: func [name [word!] data [binary!]][
	append/only valid-type-layouts reduce [name data]
]
add-valid-type-layout 'EMPTY empty-type-layout-message
add-valid-type-layout 'REPRESENTATIONS type-layout-message
add-valid-type-layout 'TAG-WIDTH-256 tag-width-boundary-message

foreach fixture valid-type-layouts [
	result: type-layout-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid type layout rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert result/error = schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS [
		fixture/1 " valid type layout returned a nonzero error"
	]
	assert to logic! all [
		result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error = schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/data-layout-error = schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		result/error-offset = 0
		result/error-section = 0
		object? result/strings
		object? result/files
		map? result/layout
		object? result/view
	][fixture/1 " valid type layout did not publish complete views"]
]

result: type-layout-verifier/verify type-layout-message
assert to logic! all [
	result/view/type-count = 13
	result/view/field-count = 9
	result/view/signature-count = 1
	result/view/source-location-count = 0
	result/view/type-record-size = schema/WIRE_RSIR_TYPE_SIZE
	result/view/field-record-size = schema/WIRE_RSIR_FIELD_SIZE
] "verified type-layout view changed"

type-layout-section-list: type-layout-sections type-layout-message
types-section: type-layout-section-list/1
fields-section: type-layout-section-list/2
signatures-section: type-layout-section-list/3
type-layout-container:
	container-verifier/verify/expect type-layout-message schema/WIRE_MAGIC_RSIR
data-layout-section: container-verifier/find-section type-layout-container
	schema/WIRE_RSIR_SECTION_DATA_LAYOUT
source-location-section: container-verifier/find-section type-layout-container
	schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
types-offset: select types-section 'payload-offset
types-ordinal: select types-section 'ordinal
fields-offset: select fields-section 'payload-offset
fields-ordinal: select fields-section 'ordinal

type-offset: func [id [integer!]][
	types-offset + ((id - 1) * schema/WIRE_RSIR_TYPE_SIZE)
]
field-offset: func [id [integer!]][
	fields-offset + ((id - 1) * schema/WIRE_RSIR_FIELD_SIZE)
]

malformed-type-layouts: make block! 384
add-malformed-type-layout: func [
	name [word!]
	expected-error expected-container expected-string expected-file expected-layout
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-type-layouts reduce [
		name expected-error expected-container expected-string expected-file expected-layout
		expected-offset expected-section data
	]
]

bad: copy type-layout-message
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-type-layout 'INVALID-CONTAINER
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

string-section-list: string-sections type-layout-message schema/WIRE_MAGIC_RSIR
string-data-section: string-section-list/2
bad: copy type-layout-message
fixture-mutations/put-bytes bad (select string-data-section 'payload-offset) #{80}
add-malformed-type-layout 'INVALID-STRINGS
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_STRINGS schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	(select string-data-section 'payload-offset) (select string-data-section 'ordinal) bad

bad: copy type-layout-message
fixture-mutations/put-u32 bad
	((select source-location-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-type-layout 'INVALID-FILE-SOURCE
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_FILE_SOURCE schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	((select source-location-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	(select source-location-section 'ordinal) bad

bad: copy type-layout-message
fixture-mutations/put-u32 bad
	((select data-layout-section 'payload-offset)
		+ schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET) 8
add-malformed-type-layout 'INVALID-DATA-LAYOUT
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_DATA_LAYOUT schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT
	((select data-layout-section 'payload-offset)
		+ schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET)
	(select data-layout-section 'ordinal) bad

bad: copy type-layout-message
fixture-mutations/put-u32 bad
	((select types-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_SORTED
add-malformed-type-layout 'BAD-TYPE-SECTION-FLAGS
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	((select types-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	types-ordinal bad

bad: copy type-layout-message
fixture-mutations/put-u32 bad
	((select fields-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_DEDUPLICATED
add-malformed-type-layout 'BAD-FIELD-SECTION-FLAGS
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	((select fields-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	fields-ordinal bad

foreach [field-name field-relative] type-layout-verifier/type-fields [
	bad: copy type-layout-message
	fixture-mutations/put-bytes bad ((type-offset 1) + field-relative) #{00000080}
	add-malformed-type-layout to word! rejoin ["SCALAR-TYPE-" field-name]
		schema/WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS ((type-offset 1) + field-relative)
		types-ordinal bad
]

foreach [field-name field-relative] type-layout-verifier/field-fields [
	bad: copy type-layout-message
	fixture-mutations/put-bytes bad ((field-offset 1) + field-relative) #{00000080}
	add-malformed-type-layout to word! rejoin ["SCALAR-FIELD-" field-name]
		schema/WIRE_TYPE_LAYOUT_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS ((field-offset 1) + field-relative)
		fields-ordinal bad
]

mutate-type: func [name [word!] id field-relative value expected-error [integer!]][
	bad: copy type-layout-message
	fixture-mutations/put-u32 bad ((type-offset id) + field-relative) value
	add-malformed-type-layout name expected-error schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS ((type-offset id) + field-relative)
		types-ordinal bad
]

mutate-field: func [name [word!] id field-relative value expected-error [integer!]][
	bad: copy type-layout-message
	fixture-mutations/put-u32 bad ((field-offset id) + field-relative) value
	add-malformed-type-layout name expected-error schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS ((field-offset id) + field-relative)
		fields-ordinal bad
]

mutate-type 'BAD-KIND 2 schema/WIRE_RSIR_TYPE_KIND_OFFSET 9
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_KIND
mutate-type 'BAD-FLAGS 5 schema/WIRE_RSIR_TYPE_FLAGS_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FLAGS
mutate-type 'BAD-VOID-SIZE 1 schema/WIRE_RSIR_TYPE_SIZE_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE
mutate-type 'BAD-LOGIC-ALIGNMENT 6 schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET 8
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
mutate-type 'NONZERO-TYPE-RESERVED-0 4 schema/WIRE_RSIR_TYPE_RESERVED_0_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
mutate-type 'NONZERO-TYPE-RESERVED-1 4 schema/WIRE_RSIR_TYPE_RESERVED_1_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_TYPE_RESERVED
mutate-type 'BAD-POINTER-DETAIL 7 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 14
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
mutate-type 'MISSING-POINTER-DETAIL 7 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
mutate-type 'VOID-POINTER-DETAIL 7 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
mutate-type 'BAD-FUNCTION-DETAIL 9 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 2
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
mutate-type 'BAD-C-STRING-DETAIL 8 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 3
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID
mutate-type 'BAD-TAG-TYPE 12 schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET 3
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID

tag-width-section-list: type-layout-sections tag-width-boundary-message
tag-width-types-section: tag-width-section-list/1
tag-width-type-offset: (select tag-width-types-section 'payload-offset)
	+ (2 * schema/WIRE_RSIR_TYPE_SIZE)
bad: copy tag-width-boundary-message
fixture-mutations/put-u32 bad
	(tag-width-type-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) 1
add-malformed-type-layout 'BAD-TAG-WIDTH-256
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_DETAIL_ID schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	(tag-width-type-offset + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET)
	(select tag-width-types-section 'ordinal) bad

mutate-type 'BAD-FIELD-RANGE-ZERO 10 schema/WIRE_RSIR_TYPE_FIRST_FIELD_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
mutate-type 'BAD-FIELD-RANGE-END 13 schema/WIRE_RSIR_TYPE_FIELD_COUNT_OFFSET 4
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_RANGE
mutate-type 'BAD-GC-KIND 7 schema/WIRE_RSIR_TYPE_GC_KIND_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_GC_KIND

mutate-field 'BAD-FIELD-OWNER-ZERO 1 schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
mutate-field 'BAD-FIELD-OWNER-SCALAR 1 schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET 3
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
mutate-field 'BAD-FIELD-OWNER-RANGE 1 schema/WIRE_RSIR_FIELD_OWNER_TYPE_OFFSET 11
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OWNER
mutate-field 'BAD-FIELD-NAME-ZERO 1 schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_NAME_ID
mutate-field 'BAD-FIELD-NAME-RANGE 1 schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET 10
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_NAME_ID
mutate-field 'EMPTY-FIELD-NAME 1 schema/WIRE_RSIR_FIELD_NAME_STRING_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_EMPTY_FIELD_NAME
mutate-field 'BAD-FIELD-TYPE-ZERO 1 schema/WIRE_RSIR_FIELD_TYPE_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
mutate-field 'BAD-FIELD-TYPE-VOID 1 schema/WIRE_RSIR_FIELD_TYPE_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_TYPE
mutate-field 'BAD-TYPE-ORDER 8 schema/WIRE_RSIR_FIELD_TYPE_OFFSET 13
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_TYPE_ORDER
mutate-field 'BAD-FIELD-OFFSET 2 schema/WIRE_RSIR_FIELD_BYTE_OFFSET_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_OFFSET
mutate-field 'NONZERO-FIELD-FLAGS 1 schema/WIRE_RSIR_FIELD_FLAGS_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_FIELD_FLAGS
mutate-field 'BAD-FIELD-ORDINAL 2 schema/WIRE_RSIR_FIELD_ORDINAL_OFFSET 0
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_FIELD_ORDINAL
mutate-field 'BAD-SOURCE-LOCATION 1 schema/WIRE_RSIR_FIELD_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SOURCE_LOCATION
mutate-field 'NONZERO-RESERVED 1 schema/WIRE_RSIR_FIELD_RESERVED_OFFSET 1
	schema/WIRE_TYPE_LAYOUT_ERROR_NONZERO_RESERVED
mutate-type 'BAD-AGGREGATE-ALIGNMENT 10 schema/WIRE_RSIR_TYPE_ALIGNMENT_OFFSET 8
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_ALIGNMENT
mutate-type 'BAD-AGGREGATE-SIZE 10 schema/WIRE_RSIR_TYPE_SIZE_OFFSET 12
	schema/WIRE_TYPE_LAYOUT_ERROR_BAD_SIZE

foreach fixture malformed-type-layouts [
	result: type-layout-verifier/verify fixture/9
	assert not result/valid? [fixture/1 " malformed type layout was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
	]
	assert result/container-error = fixture/3 [fixture/1 " wrong container error"]
	assert result/string-error = fixture/4 [fixture/1 " wrong string error"]
	assert result/file-source-error = fixture/5 [fixture/1 " wrong file/source error"]
	assert result/data-layout-error = fixture/6 [fixture/1 " wrong data-layout error"]
	assert to logic! all [result/error-offset = fixture/7 result/error-section = fixture/8][
		fixture/1 " wrong error location " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout none? result/view
	][fixture/1 " published output views on failure"]
]

covered-errors: reduce [
	schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
	schema/WIRE_TYPE_LAYOUT_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-type-layouts [
	unless find covered-errors fixture/2 [append covered-errors fixture/2]
]
repeat index 27 [
	assert not none? find covered-errors (index - 1) [
		"type-layout error code lacks executable coverage: " index - 1
	]
]

unless value? 'generating-wire-type-layout-fixtures? [
	source-bytes: make binary! 262144
	append source-bytes read %wire-type-layout-test.red
	append source-bytes read %wire-file-source-test.red
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-type-layout-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-type-layout-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System type-layout fixtures are stale"
	print [
		"PASS: RSIR type/layout semantics"
		length? valid-type-layouts "valid"
		length? malformed-type-layouts "malformed"
	]
]
