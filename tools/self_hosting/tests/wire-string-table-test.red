Red [
	Title: "Hybrid compiler string-table semantic tests"
]

do %wire-container-test.red
do %../../../compiler/wire-string-table.red

container-verifier: verifier
string-verifier: compiler-wire-string-table

build-string-message: func [
	magic [integer!]
	records bytes [binary!]
	/local payloads kinds sections
][
	payloads: make map! 8
	case [
		magic = schema/WIRE_MAGIC_RSIR [
			put payloads schema/WIRE_RSIR_SECTION_MODULE
				fixture-writer/words [0 2 1 0 0 0 0 0]
			put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
		]
		magic = schema/WIRE_MAGIC_RSCG [
			put payloads schema/WIRE_RSCG_SECTION_DATA_LAYOUT data-layout
			put payloads schema/WIRE_RSCG_SECTION_MODULES
				fixture-writer/words [0 2 1 0 0 0 0 0]
		]
		magic = schema/WIRE_MAGIC_RSDG [
			put payloads schema/WIRE_RSDG_SECTION_DIAGNOSTICS
				fixture-writer/words [3 3 3 1 0 0 0 0 0 0]
		]
		true [return none]
	]
	kinds: string-verifier/section-kinds-for magic
	put payloads kinds/1 records
	put payloads kinds/2 bytes
	sections: fixture-writer/sections-for magic payloads
	fixture-writer/set-section-flags sections kinds/1
		string-verifier/expected-string-flags
	case [
		magic = schema/WIRE_MAGIC_RSIR [
			fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
				string-verifier/expected-string-flags
			fixture-writer/set-section-flags sections
				schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
				string-verifier/expected-string-flags
		]
		magic = schema/WIRE_MAGIC_RSCG [
			fixture-writer/set-section-flags sections schema/WIRE_RSCG_SECTION_FILES
				string-verifier/expected-string-flags
		]
		true [none]
	]
	either magic = schema/WIRE_MAGIC_RSDG [
		fixture-writer/build magic 0 0 0 0 sections
	][
		fixture-writer/build
			magic
			schema/WIRE_TARGET_X86_64
			schema/WIRE_ABI_WIN64
			schema/WIRE_ENDIAN_LITTLE
			8
			sections
	]
]

string-sections: func [
	data [binary!]
	magic [integer!]
	/local result kinds
][
	result: container-verifier/verify/expect data magic
	assert result/valid? "string fixture is not a valid common container"
	kinds: string-verifier/section-kinds-for magic
	reduce [
		container-verifier/find-section result kinds/1
		container-verifier/find-section result kinds/2
	]
]

result: string-verifier/verify none schema/WIRE_MAGIC_RSIR
assert all [
	not result/valid?
	result/error = schema/WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/table
] "non-binary string-table input did not return INVALID_ARGUMENTS"

result: string-verifier/verify rsir 'RSIR
assert result/error = schema/WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS
	"non-integer string-table magic did not return INVALID_ARGUMENTS"

result: string-verifier/verify rscf schema/WIRE_MAGIC_RSCF
assert all [
	not result/valid?
	result/error = schema/WIRE_STRING_TABLE_ERROR_UNSUPPORTED_MESSAGE
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/table
] "unsupported string-table message kind was accepted"

utf8-boundary-records: fixture-writer/words [
	0 0
	0 1
	1 2
	3 2
	5 3
	8 3
	11 3
	14 3
	17 4
	21 4
]
utf8-boundary-data:
	#{7FC280DFBFE0A080ED9FBFEE8080EFBFBFF0908080F48FBFBF}
utf8-boundaries: build-string-message
	schema/WIRE_MAGIC_RSIR utf8-boundary-records utf8-boundary-data
nonempty-rsir: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 5] #{656D707479}

valid-string-tables: make block! 16
add-valid-string-table: func [
	name [word!]
	magic [integer!]
	data [binary!]
][
	append/only valid-string-tables reduce [name magic data]
]

add-valid-string-table 'RSIR schema/WIRE_MAGIC_RSIR nonempty-rsir
add-valid-string-table 'RSCG-EMPTY schema/WIRE_MAGIC_RSCG rscg
add-valid-string-table 'RSDG schema/WIRE_MAGIC_RSDG rsdg
add-valid-string-table 'UTF8-BOUNDARIES schema/WIRE_MAGIC_RSIR utf8-boundaries

foreach fixture valid-string-tables [
	result: string-verifier/verify fixture/3 fixture/2
	assert result/valid? [
		fixture/1 " valid string table rejected with error " result/error
	]
	assert result/error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS [
		fixture/1 " valid string table returned a nonzero error"
	]
	assert result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS [
		fixture/1 " valid string table returned a container error"
	]
	assert all [result/error-offset = 0 result/error-section = 0][
		fixture/1 " valid string table returned an error location"
	]
	assert object? result/table [fixture/1 " valid string table exposed no table"]
]

rsir-string-sections: string-sections nonempty-rsir schema/WIRE_MAGIC_RSIR
rsir-strings-section: rsir-string-sections/1
rsir-data-section: rsir-string-sections/2
rsir-strings-offset: select rsir-strings-section 'payload-offset
rsir-strings-ordinal: select rsir-strings-section 'ordinal
rsir-data-offset: select rsir-data-section 'payload-offset
rsir-data-ordinal: select rsir-data-section 'ordinal

result: string-verifier/verify nonempty-rsir schema/WIRE_MAGIC_RSIR
assert all [
	result/table/record-count = 1
	result/table/records-offset = rsir-strings-offset
	result/table/records-ordinal = rsir-strings-ordinal
	result/table/record-size = schema/WIRE_STRING_SIZE
	result/table/data-offset = rsir-data-offset
	result/table/data-ordinal = rsir-data-ordinal
	result/table/data-size = 5
] "verified RSIR string-table view changed"

malformed-string-tables: make block! 128
add-malformed-string-table: func [
	name [word!]
	magic expected-error expected-container-error expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-string-tables reduce [
		name magic expected-error expected-container-error expected-offset expected-section data
	]
]

bad: copy nonempty-rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-string-table 'INVALID-CONTAINER schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy nonempty-rsir
fixture-mutations/put-u32 bad
	((select rsir-strings-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	0
add-malformed-string-table 'BAD-STRING-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select rsir-strings-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	rsir-strings-ordinal bad

bad: copy nonempty-rsir
fixture-mutations/put-u32 bad
	((select rsir-data-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_SORTED
add-malformed-string-table 'BAD-DATA-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_DATA_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select rsir-data-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	rsir-data-ordinal bad

bad: copy nonempty-rsir
fixture-mutations/put-bytes bad
	(rsir-strings-offset + schema/WIRE_STRING_OFFSET_OFFSET) #{00000080}
add-malformed-string-table 'SCALAR-RANGE-OFFSET schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-strings-offset + schema/WIRE_STRING_OFFSET_OFFSET)
	rsir-strings-ordinal bad

bad: copy nonempty-rsir
fixture-mutations/put-bytes bad
	(rsir-strings-offset + schema/WIRE_STRING_SIZE_OFFSET) #{00000080}
add-malformed-string-table 'SCALAR-RANGE-SIZE schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-strings-offset + schema/WIRE_STRING_SIZE_OFFSET)
	rsir-strings-ordinal bad

bad: copy nonempty-rsir
fixture-mutations/put-u32 bad
	(rsir-strings-offset + schema/WIRE_STRING_SIZE_OFFSET) 6
add-malformed-string-table 'SLICE-RANGE schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_SLICE_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-strings-offset + schema/WIRE_STRING_OFFSET_OFFSET)
	rsir-strings-ordinal bad

bad: copy nonempty-rsir
fixture-mutations/put-u32 bad
	(rsir-strings-offset + schema/WIRE_STRING_OFFSET_OFFSET) 2147483647
fixture-mutations/put-u32 bad
	(rsir-strings-offset + schema/WIRE_STRING_SIZE_OFFSET) 1
add-malformed-string-table 'SLICE-ADD-OVERFLOW schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_SLICE_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-strings-offset + schema/WIRE_STRING_OFFSET_OFFSET)
	rsir-strings-ordinal bad

gap: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 2 1] #{616263}
gap-sections: string-sections gap schema/WIRE_MAGIC_RSIR
gap-strings: gap-sections/1
add-malformed-string-table 'COVERAGE-GAP schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select gap-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select gap-strings 'ordinal) gap

overlap: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 0 1] #{6162}
overlap-sections: string-sections overlap schema/WIRE_MAGIC_RSIR
overlap-strings: overlap-sections/1
add-malformed-string-table 'COVERAGE-OVERLAP schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select overlap-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select overlap-strings 'ordinal) overlap

trailing: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1] #{6162}
trailing-sections: string-sections trailing schema/WIRE_MAGIC_RSIR
trailing-data: trailing-sections/2
add-malformed-string-table 'COVERAGE-TRAILING schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_DATA_COVERAGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select trailing-data 'payload-offset) + 1)
	(select trailing-data 'ordinal) trailing

embedded-nul: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 3] #{610062}
embedded-nul-sections: string-sections embedded-nul schema/WIRE_MAGIC_RSIR
embedded-nul-data: embedded-nul-sections/2
add-malformed-string-table 'EMBEDDED-NUL schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_EMBEDDED_NUL schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select embedded-nul-data 'payload-offset) + 1)
	(select embedded-nul-data 'ordinal) embedded-nul

bad-empty: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 1 0] #{61}
bad-empty-sections: string-sections bad-empty schema/WIRE_MAGIC_RSIR
bad-empty-strings: bad-empty-sections/1
add-malformed-string-table 'BAD-EMPTY-STRING schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_BAD_EMPTY_STRING
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select bad-empty-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select bad-empty-strings 'ordinal) bad-empty

bad-order: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 1 1] #{6261}
bad-order-sections: string-sections bad-order schema/WIRE_MAGIC_RSIR
bad-order-strings: bad-order-sections/1
add-malformed-string-table 'STRING-ORDER schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_STRING_ORDER schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select bad-order-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select bad-order-strings 'ordinal) bad-order

duplicate: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 1 1] #{6161}
duplicate-sections: string-sections duplicate schema/WIRE_MAGIC_RSIR
duplicate-strings: duplicate-sections/1
add-malformed-string-table 'DUPLICATE-STRING schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_DUPLICATE_STRING
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select duplicate-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select duplicate-strings 'ordinal) duplicate

scalar-before-utf8: build-string-message schema/WIRE_MAGIC_RSIR
	fixture-writer/words [0 1 1 1] #{8061}
scalar-before-sections: string-sections scalar-before-utf8 schema/WIRE_MAGIC_RSIR
scalar-before-strings: scalar-before-sections/1
scalar-before-second-size:
	(select scalar-before-strings 'payload-offset)
	+ schema/WIRE_STRING_SIZE
	+ schema/WIRE_STRING_SIZE_OFFSET
fixture-mutations/put-bytes scalar-before-utf8 scalar-before-second-size #{00000080}
add-malformed-string-table 'SCALAR-BEFORE-UTF8 schema/WIRE_MAGIC_RSIR
	schema/WIRE_STRING_TABLE_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
	scalar-before-second-size (select scalar-before-strings 'ordinal) scalar-before-utf8

add-invalid-utf8: func [
	name [word!]
	magic [integer!]
	bytes [binary!]
	bad-relative [integer!]
	/local message sections data-section
][
	message: build-string-message magic
		fixture-writer/words reduce [0 length? bytes] bytes
	sections: string-sections message magic
	data-section: sections/2
	add-malformed-string-table name magic
		schema/WIRE_STRING_TABLE_ERROR_INVALID_UTF8
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		((select data-section 'payload-offset) + bad-relative)
		(select data-section 'ordinal) message
]

add-invalid-utf8 'UTF8-OVERLONG-2 schema/WIRE_MAGIC_RSIR #{C0} 0
add-invalid-utf8 'UTF8-BARE-CONTINUATION schema/WIRE_MAGIC_RSIR #{80} 0
add-invalid-utf8 'UTF8-BAD-CONTINUATION-2 schema/WIRE_MAGIC_RSIR #{C220} 1
add-invalid-utf8 'UTF8-TRUNCATED-2 schema/WIRE_MAGIC_RSIR #{C2} 1
add-invalid-utf8 'UTF8-OVERLONG-3 schema/WIRE_MAGIC_RSIR #{E09F80} 1
add-invalid-utf8 'UTF8-SURROGATE schema/WIRE_MAGIC_RSIR #{EDA080} 1
add-invalid-utf8 'UTF8-BAD-CONTINUATION-3 schema/WIRE_MAGIC_RSIR #{E18020} 2
add-invalid-utf8 'UTF8-TRUNCATED-3 schema/WIRE_MAGIC_RSIR #{E180} 2
add-invalid-utf8 'UTF8-OVERLONG-4 schema/WIRE_MAGIC_RSIR #{F08F8080} 1
add-invalid-utf8 'UTF8-ABOVE-MAX schema/WIRE_MAGIC_RSIR #{F4908080} 1
add-invalid-utf8 'UTF8-BAD-LEAD-4 schema/WIRE_MAGIC_RSIR #{F5} 0
add-invalid-utf8 'UTF8-BAD-CONTINUATION-4 schema/WIRE_MAGIC_RSIR #{F1808020} 3
add-invalid-utf8 'UTF8-TRUNCATED-4 schema/WIRE_MAGIC_RSIR #{F18080} 3
add-invalid-utf8 'RSCG-UTF8 schema/WIRE_MAGIC_RSCG #{80} 0

rsdg-duplicate: build-string-message schema/WIRE_MAGIC_RSDG
	fixture-writer/words [0 1 1 1] #{6161}
rsdg-duplicate-sections: string-sections rsdg-duplicate schema/WIRE_MAGIC_RSDG
rsdg-duplicate-strings: rsdg-duplicate-sections/1
add-malformed-string-table 'RSDG-DUPLICATE schema/WIRE_MAGIC_RSDG
	schema/WIRE_STRING_TABLE_ERROR_DUPLICATE_STRING
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	((select rsdg-duplicate-strings 'payload-offset) + schema/WIRE_STRING_SIZE)
	(select rsdg-duplicate-strings 'ordinal) rsdg-duplicate

foreach fixture malformed-string-tables [
	result: string-verifier/verify fixture/7 fixture/2
	assert not result/valid? [fixture/1 " malformed string table was accepted"]
	assert none? result/table [fixture/1 " malformed string table exposed a table"]
	assert result/error = fixture/3 [
		fixture/1 " expected error " fixture/3 " but got " result/error
	]
	assert result/container-error = fixture/4 [
		fixture/1 " expected container error " fixture/4
		" but got " result/container-error
	]
	assert all [
		result/error-offset = fixture/5
		result/error-section = fixture/6
	][
		fixture/1 " expected location " fixture/5 ":" fixture/6
		" but got " result/error-offset ":" result/error-section
	]
]

covered-errors: reduce [
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_INVALID_ARGUMENTS
	schema/WIRE_STRING_TABLE_ERROR_UNSUPPORTED_MESSAGE
]
foreach fixture malformed-string-tables [append covered-errors fixture/3]
repeat error-index (schema/WIRE_STRING_TABLE_ERROR_DUPLICATE_STRING + 1)[
	expected-error: error-index - 1
	assert not none? find covered-errors expected-error [
		"string-table error code has no directed Red test: " expected-error
	]
]

generating?: all [
	value? 'generating-wire-string-table-fixtures?
	get 'generating-wire-string-table-fixtures?
]
unless generating? [
	source-bytes: make binary! 65536
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-string-table-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-string-table-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System string-table semantic fixtures are stale"
]

print [
	"PASS: string-table semantics"
	"valid=" length? valid-string-tables
	"malformed=" length? malformed-string-tables
]
