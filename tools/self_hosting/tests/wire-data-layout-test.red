Red [
	Title: "Hybrid compiler target data-layout semantic tests"
]

do %wire-container-test.red
do %../../../compiler/wire-data-layout.red

layout-verifier: compiler-wire-data-layout

result: layout-verifier/verify none schema/WIRE_MAGIC_RSIR
assert all [
	not result/valid?
	result/error = schema/WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/layout
] "non-binary data-layout input did not return INVALID_ARGUMENTS"

result: layout-verifier/verify rsir 'RSIR
assert result/error = schema/WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS
	"non-integer expected magic did not return INVALID_ARGUMENTS"

result: layout-verifier/verify rsir schema/WIRE_MAGIC_RSCF
assert all [
	not result/valid?
	result/error = schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_MESSAGE
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/layout
] "unsupported data-layout message kind was accepted"

rsir-container-result: verifier/verify/expect rsir schema/WIRE_MAGIC_RSIR
rsir-layout-section: verifier/find-section
	rsir-container-result schema/WIRE_RSIR_SECTION_DATA_LAYOUT
rsir-layout-offset: select rsir-layout-section 'payload-offset
rsir-layout-ordinal: select rsir-layout-section 'ordinal

rscg-container-result: verifier/verify/expect rscg schema/WIRE_MAGIC_RSCG
rscg-layout-section: verifier/find-section
	rscg-container-result schema/WIRE_RSCG_SECTION_DATA_LAYOUT
rscg-layout-offset: select rscg-layout-section 'payload-offset
rscg-layout-ordinal: select rscg-layout-section 'ordinal

rscg-optional-container-result: verifier/verify/expect
	rscg-optional schema/WIRE_MAGIC_RSCG
rscg-optional-layout-section: verifier/find-section
	rscg-optional-container-result schema/WIRE_RSCG_SECTION_DATA_LAYOUT
rscg-optional-layout-offset: select rscg-optional-layout-section 'payload-offset

assert rsir-layout-ordinal = 2 "RSIR data-layout is not directory section 2"
assert rscg-layout-ordinal = 1 "RSCG data-layout is not directory section 1"

put-layout: func [
	data [binary!]
	payload-offset field-offset value [integer!]
][
	fixture-mutations/put-u32 data (payload-offset + field-offset) value
]

valid-data-layouts: make block! 8
add-valid-layout: func [name [word!] magic [integer!] data [binary!]][
	append/only valid-data-layouts reduce [name magic data]
]

add-valid-layout 'RSIR schema/WIRE_MAGIC_RSIR rsir
add-valid-layout 'RSCG schema/WIRE_MAGIC_RSCG rscg
add-valid-layout 'RSCG-OPTIONAL schema/WIRE_MAGIC_RSCG rscg-optional

foreach fixture valid-data-layouts [
	result: layout-verifier/verify fixture/3 fixture/2
	assert result/valid? [fixture/1 " valid data-layout rejected with error " result/error]
	assert result/error = schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS [
		fixture/1 " valid data-layout returned a nonzero error"
	]
	assert result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS [
		fixture/1 " valid data-layout returned a container error"
	]
	assert all [result/error-offset = 0 result/error-section = 0] [
		fixture/1 " valid data-layout returned an error location"
	]
]

result: layout-verifier/verify rsir schema/WIRE_MAGIC_RSIR
assert all [
	(select result/layout 'address-unit) = 1
	(select result/layout 'pointer-size) = 8
	(select result/layout 'pointer-alignment) = 8
	(select result/layout 'stack-alignment) = 16
	(select result/layout 'max-scalar-alignment) = 8
	(select result/layout 'max-aggregate-alignment) = 8
	(select result/layout 'integer-register-width) = 8
	(select result/layout 'flags) = 0
] "Windows x64 data-layout decode changed"

malformed-data-layouts: make block! 64
add-malformed-layout: func [
	name [word!]
	magic expected-error expected-container-error expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-data-layouts reduce [
		name magic expected-error expected-container-error expected-offset expected-section data
	]
]

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-layout 'INVALID-CONTAINER schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

foreach [field-name field-offset] layout-verifier/layout-fields [
	bad: copy rsir
	fixture-mutations/put-bytes bad (rsir-layout-offset + field-offset) #{00000080}
	add-malformed-layout to word! rejoin ["SCALAR-RANGE-" field-name]
		schema/WIRE_MAGIC_RSIR schema/WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE
		schema/WIRE_CONTAINER_ERROR_SUCCESS (rsir-layout-offset + field-offset)
		rsir-layout-ordinal bad
]

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_OFFSET schema/WIRE_TARGET_ARM64
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET schema/WIRE_ABI_AAPCS64
add-malformed-layout 'UNSUPPORTED-TARGET schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_HEADER_TARGET_OFFSET 0 bad

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET schema/WIRE_ABI_SYSV_X64
add-malformed-layout 'UNSUPPORTED-ABI schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_HEADER_ABI_OFFSET 0 bad

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET schema/WIRE_ENDIAN_BIG
add-malformed-layout 'UNSUPPORTED-ENDIAN schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0 bad

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_POINTER_SIZE_OFFSET 4
add-malformed-layout 'UNSUPPORTED-HEADER-POINTER schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_TARGET schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0 bad

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 1
add-malformed-layout 'UNSUPPORTED-FEATURES-LOW schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 0 bad

bad: copy rsir
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 1
add-malformed-layout 'UNSUPPORTED-FEATURES-HIGH schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_CPU_FEATURES
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 0 bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET 0
add-malformed-layout 'BAD-ADDRESS-UNIT schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_ADDRESS_UNIT schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_ADDRESS_UNIT_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET 4
add-malformed-layout 'POINTER-SIZE-MISMATCH schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_POINTER_SIZE_MISMATCH schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_POINTER_SIZE_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET 4
add-malformed-layout 'BAD-POINTER-ALIGNMENT schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_POINTER_ALIGNMENT schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_POINTER_ALIGNMENT_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET 8
add-malformed-layout 'BAD-STACK-ALIGNMENT schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET 16
add-malformed-layout 'BAD-MAX-SCALAR-ALIGNMENT schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_MAX_SCALAR_ALIGNMENT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_MAX_SCALAR_ALIGNMENT_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET 16
add-malformed-layout 'BAD-MAX-AGGREGATE-ALIGNMENT schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_MAX_AGGREGATE_ALIGNMENT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET 4
add-malformed-layout 'BAD-INTEGER-REGISTER-WIDTH schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_INTEGER_REGISTER_WIDTH
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_INTEGER_REGISTER_WIDTH_OFFSET)
	rsir-layout-ordinal bad

bad: copy rsir
put-layout bad rsir-layout-offset schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET 1
add-malformed-layout 'NONZERO-FLAGS schema/WIRE_MAGIC_RSIR
	schema/WIRE_DATA_LAYOUT_ERROR_NONZERO_FLAGS schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rsir-layout-offset + schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET) rsir-layout-ordinal bad

bad: copy rscg
fixture-mutations/put-bytes bad
	(rscg-layout-offset + schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET)
	#{00000080}
add-malformed-layout 'RSCG-SCALAR-RANGE schema/WIRE_MAGIC_RSCG
	schema/WIRE_DATA_LAYOUT_ERROR_SCALAR_RANGE schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscg-layout-offset + schema/WIRE_DATA_LAYOUT_MAX_AGGREGATE_ALIGNMENT_OFFSET)
	rscg-layout-ordinal bad

bad: copy rscg
put-layout bad rscg-layout-offset schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET 8
add-malformed-layout 'RSCG-BAD-STACK-ALIGNMENT schema/WIRE_MAGIC_RSCG
	schema/WIRE_DATA_LAYOUT_ERROR_BAD_STACK_ALIGNMENT schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscg-layout-offset + schema/WIRE_DATA_LAYOUT_STACK_ALIGNMENT_OFFSET)
	rscg-layout-ordinal bad

bad: copy rscg-optional
put-layout bad rscg-optional-layout-offset schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET 1
add-malformed-layout 'RSCG-OPTIONAL-NONZERO-FLAGS schema/WIRE_MAGIC_RSCG
	schema/WIRE_DATA_LAYOUT_ERROR_NONZERO_FLAGS schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscg-optional-layout-offset + schema/WIRE_DATA_LAYOUT_FLAGS_OFFSET) 1 bad

foreach fixture malformed-data-layouts [
	result: layout-verifier/verify fixture/7 fixture/2
	assert not result/valid? [fixture/1 " malformed data-layout was accepted"]
	assert none? result/layout [fixture/1 " malformed data-layout exposed decoded values"]
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
	schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
	schema/WIRE_DATA_LAYOUT_ERROR_INVALID_ARGUMENTS
	schema/WIRE_DATA_LAYOUT_ERROR_UNSUPPORTED_MESSAGE
]
foreach fixture malformed-data-layouts [append covered-errors fixture/3]
repeat error-index (schema/WIRE_DATA_LAYOUT_ERROR_NONZERO_FLAGS + 1) [
	expected-error: error-index - 1
	assert not none? find covered-errors expected-error [
		"data-layout error code has no directed Red test: " expected-error
	]
]

generating?: all [
	value? 'generating-wire-data-layout-fixtures?
	get 'generating-wire-data-layout-fixtures?
]
unless generating? [
	source-bytes: make binary! 65536
	append source-bytes read %wire-data-layout-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-data-layout-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-data-layout-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System data-layout semantic fixtures are stale"
]

print [
	"PASS: target data-layout semantics"
	"valid=" length? valid-data-layouts
	"malformed=" length? malformed-data-layouts
]
