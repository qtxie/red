Red [
	Title: "Hybrid compiler module lifecycle tests"
]

do %wire-file-source-test.red
do %../../../compiler/wire-module-lifecycle.red

module-verifier: compiler-wire-module-lifecycle

module-string-records: fixture-writer/words [
	0 0
	0 4
	4 7
	11 4
]
module-string-data: to binary! "glueruntimeuser"

rsir-functions: func [count [integer!] /local values][
	values: make block! (count * 10)
	append/dup values 0 (count * 10)
	fixture-writer/words values
]

rscg-symbols: func [origins [block!] /local values origin][
	values: make block! ((length? origins) * 10)
	foreach origin origins [
		repend values [0 0 0 0 0 0 0 0 0 origin]
	]
	fixture-writer/words values
]

build-module-message: func [
	magic [integer!]
	module-records reference-records [binary!]
	/local payloads sections
][
	payloads: make map! 32
	case [
		magic = schema/WIRE_MAGIC_RSIR [
			put payloads schema/WIRE_RSIR_SECTION_MODULE module-records
			put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
			put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS reference-records
		]
		magic = schema/WIRE_MAGIC_RSCG [
			put payloads schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
			put payloads schema/WIRE_RSCG_SECTION_SYMBOLS reference-records
			put payloads schema/WIRE_RSCG_SECTION_MODULES module-records
		]
		true [return none]
	]
	put payloads either magic = schema/WIRE_MAGIC_RSIR [
		schema/WIRE_RSIR_SECTION_STRINGS
	][schema/WIRE_RSCG_SECTION_STRINGS] module-string-records
	put payloads either magic = schema/WIRE_MAGIC_RSIR [
		schema/WIRE_RSIR_SECTION_STRING_DATA
	][schema/WIRE_RSCG_SECTION_STRING_DATA] module-string-data
	sections: fixture-writer/sections-for magic payloads
	fixture-writer/set-section-flags sections either magic = schema/WIRE_MAGIC_RSIR [
		schema/WIRE_RSIR_SECTION_STRINGS
	][schema/WIRE_RSCG_SECTION_STRINGS] string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections either magic = schema/WIRE_MAGIC_RSIR [
		schema/WIRE_RSIR_SECTION_FILES
	][schema/WIRE_RSCG_SECTION_FILES] file-source-verifier/expected-index-flags
	if magic = schema/WIRE_MAGIC_RSIR [
		fixture-writer/set-section-flags sections
			schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
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

rsir-user: build-module-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 2 1 0 0 0 0 0]
	#{}
rsir-runtime-dll: build-module-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [3 1 2 1 1 0 0 0]
	rsir-functions 1
rsir-glue: build-module-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [2 4 1 0 0 1 0 0]
	rsir-functions 1
rscg-support-dll: build-module-message schema/WIRE_MAGIC_RSCG
	fixture-writer/words [0 3 2 0 0 0 0 0]
	#{}
rscg-merged: build-module-message schema/WIRE_MAGIC_RSCG
	fixture-writer/words [
		3 1 1 1 2 0 0 0
		4 2 1 3 0 0 0 0
		2 4 1 0 0 4 0 0
	]
	rscg-symbols [1 1 2 3]

valid-module-lifecycles: make block! 10
add-valid-module-lifecycle: func [name [word!] magic [integer!] data [binary!]][
	append/only valid-module-lifecycles reduce [name magic data]
]
add-valid-module-lifecycle 'RSIR-USER schema/WIRE_MAGIC_RSIR rsir-user
add-valid-module-lifecycle 'RSIR-RUNTIME-DLL schema/WIRE_MAGIC_RSIR rsir-runtime-dll
add-valid-module-lifecycle 'RSIR-GLUE schema/WIRE_MAGIC_RSIR rsir-glue
add-valid-module-lifecycle 'RSCG-SUPPORT-DLL schema/WIRE_MAGIC_RSCG rscg-support-dll
add-valid-module-lifecycle 'RSCG-MERGED schema/WIRE_MAGIC_RSCG rscg-merged

result: module-verifier/verify none schema/WIRE_MAGIC_RSIR
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/file-source-error = schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/files
	none? result/view
] "non-binary module input did not return INVALID_ARGUMENTS"

result: module-verifier/verify rsir-user 'RSIR
assert result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS
	"non-integer module magic did not return INVALID_ARGUMENTS"

foreach fixture valid-module-lifecycles [
	result: module-verifier/verify fixture/3 fixture/2
	assert result/valid? [
		fixture/1 " valid module lifecycle rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/error = schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
		result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		result/file-source-error = schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		result/error-offset = 0
		result/error-section = 0
		object? result/strings
		object? result/files
		object? result/view
	][fixture/1 " valid module lifecycle did not publish complete views"]
]

result: module-verifier/verify rscg-merged schema/WIRE_MAGIC_RSCG
assert to logic! all [
	result/view/module-count = 3
	result/view/reference-count = 4
	result/view/module-record-size = schema/WIRE_RSCG_MODULE_SIZE
	result/view/image-kind = schema/WIRE_IMAGE_KIND_EXECUTABLE
	result/view/glue-module = 3
] "verified merged RSCG module view changed"

module-sections: func [
	data [binary!]
	magic [integer!]
	/local verified module-kind reference-kind
][
	verified: container-verifier/verify/expect data magic
	assert verified/valid? "module fixture is not a valid common container"
	module-kind: module-verifier/module-section-kind magic
	reference-kind: module-verifier/reference-section-kind magic
	reduce [
		container-verifier/find-section verified module-kind
		container-verifier/find-section verified reference-kind
		container-verifier/find-section verified either magic = schema/WIRE_MAGIC_RSIR [
			schema/WIRE_RSIR_SECTION_STRING_DATA
		][schema/WIRE_RSCG_SECTION_STRING_DATA]
		container-verifier/find-section verified either magic = schema/WIRE_MAGIC_RSIR [
			schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		][schema/WIRE_RSCG_SECTION_FILES]
	]
]

rsir-sections: module-sections rsir-user schema/WIRE_MAGIC_RSIR
rsir-modules: rsir-sections/1
rsir-references: rsir-sections/2
rsir-string-data-section: rsir-sections/3
rsir-source-section: rsir-sections/4
rscg-sections: module-sections rscg-merged schema/WIRE_MAGIC_RSCG
rscg-modules: rscg-sections/1
rscg-references: rscg-sections/2

module-offset: func [section [map!] id [integer!]][
	(select section 'payload-offset) + ((id - 1) * (select section 'record-size))
]
symbol-offset: func [id [integer!]][
	(select rscg-references 'payload-offset) + ((id - 1) * schema/WIRE_RSCG_SYMBOL_SIZE)
]

malformed-module-lifecycles: make block! 256
add-malformed-module-lifecycle: func [
	name [word!]
	magic expected-error expected-container expected-string expected-file
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-module-lifecycles reduce [
		name magic expected-error expected-container expected-string expected-file
		expected-offset expected-section data
	]
]

bad: copy rsir-user
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-module-lifecycle 'INVALID-CONTAINER schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

add-malformed-module-lifecycle 'UNSUPPORTED-MESSAGE schema/WIRE_MAGIC_RSDG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_UNSUPPORTED_MESSAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS 0 0 rsdg

bad: copy rsir-user
fixture-mutations/put-bytes bad (select rsir-string-data-section 'payload-offset) #{80}
add-malformed-module-lifecycle 'INVALID-STRINGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_STRINGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
	schema/WIRE_FILE_SOURCE_ERROR_INVALID_STRINGS
	(select rsir-string-data-section 'payload-offset)
	(select rsir-string-data-section 'ordinal) bad

bad: copy rsir-user
fixture-mutations/put-u32 bad
	((select rsir-source-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-module-lifecycle 'INVALID-FILE-SOURCE schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_FILE_SOURCE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_BAD_SOURCE_SECTION_FLAGS
	((select rsir-source-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	(select rsir-source-section 'ordinal) bad

bad: copy rsir-user
fixture-mutations/put-bytes bad
	((module-offset rsir-modules 1) + schema/WIRE_RSIR_MODULE_KIND_OFFSET)
	#{00000080}
add-malformed-module-lifecycle 'SCALAR-RANGE schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SCALAR_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset rsir-modules 1) + schema/WIRE_RSIR_MODULE_KIND_OFFSET)
	(select rsir-modules 'ordinal) bad

bad: copy rsir-user
fixture-mutations/put-u32 bad
	((select rsir-modules 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_SORTED
add-malformed-module-lifecycle 'BAD-MODULE-SECTION-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((select rsir-modules 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	(select rsir-modules 'ordinal) bad

mutate-rsir-module: func [
	name [word!]
	field-offset value expected-error [integer!]
][
	bad: copy rsir-user
	fixture-mutations/put-u32 bad ((module-offset rsir-modules 1) + field-offset) value
	add-malformed-module-lifecycle name schema/WIRE_MAGIC_RSIR expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		((module-offset rsir-modules 1) + field-offset)
		(select rsir-modules 'ordinal) bad
]

mutate-rsir-module 'BAD-NAME-ID schema/WIRE_RSIR_MODULE_NAME_STRING_OFFSET 5
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_NAME_ID
mutate-rsir-module 'EMPTY-NAME schema/WIRE_RSIR_MODULE_NAME_STRING_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_EMPTY_NAME
mutate-rsir-module 'BAD-MODULE-KIND schema/WIRE_RSIR_MODULE_KIND_OFFSET 5
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_MODULE_KIND
mutate-rsir-module 'BAD-IMAGE-KIND schema/WIRE_RSIR_MODULE_IMAGE_KIND_OFFSET 3
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_IMAGE_KIND
mutate-rsir-module 'BAD-INITIALIZER-ID
	schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_INITIALIZER_ID
mutate-rsir-module 'BAD-FINALIZER-ID
	schema/WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_FINALIZER_ID
mutate-rsir-module 'BAD-ENTRY-ID schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_ENTRY_ID
mutate-rsir-module 'BAD-SOURCE-LOCATION
	schema/WIRE_RSIR_MODULE_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_SOURCE_LOCATION
mutate-rsir-module 'NONZERO-FLAGS schema/WIRE_RSIR_MODULE_FLAGS_OFFSET 1
	schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_FLAGS

runtime-sections: module-sections rsir-runtime-dll schema/WIRE_MAGIC_RSIR
runtime-modules: runtime-sections/1
bad: copy rsir-runtime-dll
fixture-mutations/put-u32 bad
	((module-offset runtime-modules 1) + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)
	1
add-malformed-module-lifecycle 'NON-GLUE-ENTRY schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset runtime-modules 1) + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)
	(select runtime-modules 'ordinal) bad

glue-sections: module-sections rsir-glue schema/WIRE_MAGIC_RSIR
glue-modules: glue-sections/1
bad: copy rsir-glue
fixture-mutations/put-u32 bad
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)
	0
add-malformed-module-lifecycle 'GLUE-MISSING-ENTRY schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)
	(select glue-modules 'ordinal) bad

bad: copy rsir-glue
fixture-mutations/put-u32 bad
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET)
	1
add-malformed-module-lifecycle 'GLUE-HAS-INITIALIZER schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_INITIALIZER_FUNCTION_OFFSET)
	(select glue-modules 'ordinal) bad

bad: copy rsir-glue
fixture-mutations/put-u32 bad
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET)
	1
add-malformed-module-lifecycle 'GLUE-HAS-FINALIZER schema/WIRE_MAGIC_RSIR
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_LIFECYCLE_SHAPE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset glue-modules 1) + schema/WIRE_RSIR_MODULE_FINALIZER_FUNCTION_OFFSET)
	(select glue-modules 'ordinal) bad

bad: copy rscg-support-dll
support-sections: module-sections rscg-support-dll schema/WIRE_MAGIC_RSCG
support-modules: support-sections/1
fixture-mutations/put-u32 bad
	((module-offset support-modules 1) + schema/WIRE_RSCG_MODULE_RESERVED_OFFSET) 1
add-malformed-module-lifecycle 'NONZERO-RESERVED schema/WIRE_MAGIC_RSCG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_NONZERO_RESERVED
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset support-modules 1) + schema/WIRE_RSCG_MODULE_RESERVED_OFFSET)
	(select support-modules 'ordinal) bad

bad: copy rscg-merged
fixture-mutations/put-u32 bad
	((module-offset rscg-modules 2) + schema/WIRE_RSCG_MODULE_IMAGE_KIND_OFFSET)
	schema/WIRE_IMAGE_KIND_DYNAMIC_LIBRARY
add-malformed-module-lifecycle 'IMAGE-KIND-MISMATCH schema/WIRE_MAGIC_RSCG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_IMAGE_KIND_MISMATCH
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset rscg-modules 2) + schema/WIRE_RSCG_MODULE_IMAGE_KIND_OFFSET)
	(select rscg-modules 'ordinal) bad

bad: copy rscg-merged
fixture-mutations/put-u32 bad
	((module-offset rscg-modules 2) + schema/WIRE_RSCG_MODULE_KIND_OFFSET)
	schema/WIRE_MODULE_KIND_GLUE
fixture-mutations/put-u32 bad
	((module-offset rscg-modules 2) + schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET) 0
fixture-mutations/put-u32 bad
	((module-offset rscg-modules 2) + schema/WIRE_RSCG_MODULE_ENTRY_SYMBOL_OFFSET) 3
add-malformed-module-lifecycle 'MULTIPLE-GLUE-MODULES schema/WIRE_MAGIC_RSCG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_MULTIPLE_GLUE_MODULES
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset rscg-modules 3) + schema/WIRE_RSCG_MODULE_KIND_OFFSET)
	(select rscg-modules 'ordinal) bad

bad: copy rscg-merged
fixture-mutations/put-u32 bad
	((symbol-offset 1) + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET) 0
add-malformed-module-lifecycle 'BAD-SYMBOL-ORIGIN-MODULE schema/WIRE_MAGIC_RSCG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_BAD_SYMBOL_ORIGIN_MODULE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((symbol-offset 1) + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET)
	(select rscg-references 'ordinal) bad

bad: copy rscg-merged
fixture-mutations/put-u32 bad
	((symbol-offset 1) + schema/WIRE_RSCG_SYMBOL_ORIGIN_MODULE_OFFSET) 2
add-malformed-module-lifecycle 'LIFECYCLE-SYMBOL-OWNER schema/WIRE_MAGIC_RSCG
	schema/WIRE_MODULE_LIFECYCLE_ERROR_LIFECYCLE_SYMBOL_OWNER
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
	((module-offset rscg-modules 1) + schema/WIRE_RSCG_MODULE_INITIALIZER_SYMBOL_OFFSET)
	(select rscg-modules 'ordinal) bad

foreach fixture malformed-module-lifecycles [
	result: module-verifier/verify fixture/9 fixture/2
	assert not result/valid? [fixture/1 " malformed module lifecycle was accepted"]
	assert result/error = fixture/3 [
		fixture/1 " expected error " fixture/3 " got " result/error
	]
	assert result/container-error = fixture/4 [fixture/1 " wrong container error"]
	assert result/string-error = fixture/5 [fixture/1 " wrong string error"]
	assert result/file-source-error = fixture/6 [fixture/1 " wrong file/source error"]
	assert to logic! all [
		result/error-offset = fixture/7
		result/error-section = fixture/8
	][fixture/1 " wrong error location " result/error-offset ":" result/error-section]
	assert to logic! all [
		none? result/strings none? result/files none? result/view
	][fixture/1 " published output views on failure"]
]

covered-errors: reduce [
	schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
	schema/WIRE_MODULE_LIFECYCLE_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-module-lifecycles [
	unless find covered-errors fixture/3 [append covered-errors fixture/3]
]
repeat index 23 [
	assert not none? find covered-errors (index - 1) [
		"module-lifecycle error code lacks executable coverage: " index - 1
	]
]

unless value? 'generating-wire-module-lifecycle-fixtures? [
	source-bytes: make binary! 262144
	append source-bytes read %wire-module-lifecycle-test.red
	append source-bytes read %wire-file-source-test.red
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-module-lifecycle-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-module-lifecycle-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System module-lifecycle fixtures are stale"
	print [
		"PASS: module lifecycle semantics"
		length? valid-module-lifecycles "valid"
		length? malformed-module-lifecycles "malformed"
	]
]
