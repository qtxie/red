Red [
	Title: "Hybrid compiler RSCF semantic tests"
]

do %wire-container-test.red
do %../../../compiler/wire-rscf.red

rscf-verifier: compiler-wire-rscf

result: rscf-verifier/verify none
assert all [
	not result/valid?
	result/error = schema/WIRE_RSCF_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/config
] "non-binary RSCF input did not return INVALID_ARGUMENTS"

base-container-result: verifier/verify/expect rscf schema/WIRE_MAGIC_RSCF
base-config-section: verifier/find-section
	base-container-result schema/WIRE_RSCF_SECTION_CONFIG
rscf-config-offset: select base-config-section 'payload-offset

put-config: func [
	data [binary!]
	field-offset value [integer!]
][
	fixture-mutations/put-u32 data (rscf-config-offset + field-offset) value
]

valid-rscf: make block! 8
add-valid-rscf: func [name [word!] data [binary!]][
	append/only valid-rscf reduce [name data]
]

add-valid-rscf 'BASE rscf
add-valid-rscf 'UNKNOWN-OPTIONAL rscf-unknown-optional

valid: copy rscf
put-config valid schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET
	schema/WIRE_OPTIMIZATION_LEVEL_O1
put-config valid schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET
	(schema/WIRE_CONFIG_FLAG_DEBUG
	+ schema/WIRE_CONFIG_FLAG_PIC
	+ schema/WIRE_CONFIG_FLAG_DETERMINISTIC)
put-config valid schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET
	schema/WIRE_RELOCATION_MODEL_PIC
put-config valid schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET
	schema/WIRE_DEBUG_FORMAT_RED
add-valid-rscf 'O1-ALL-FLAGS valid

valid: copy rscf
put-config valid schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET
	schema/WIRE_OPTIMIZATION_LEVEL_O2
put-config valid schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET
	schema/WIRE_RSCG_MINIMUM_SIZE
put-config valid schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET
	schema/WIRE_RSDG_MINIMUM_SIZE
add-valid-rscf 'O2-MINIMUM-LIMITS valid

foreach fixture valid-rscf [
	result: rscf-verifier/verify fixture/2
	assert result/valid? [fixture/1 " valid RSCF rejected with error " result/error]
	assert result/error = schema/WIRE_RSCF_ERROR_SUCCESS [
		fixture/1 " valid RSCF returned a nonzero error"
	]
	assert result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS [
		fixture/1 " valid RSCF returned a container error"
	]
	assert all [result/error-offset = 0 result/error-section = 0] [
		fixture/1 " valid RSCF returned an error location"
	]
]

result: rscf-verifier/verify rscf
assert all [
	(select result/config 'optimization-level) = schema/WIRE_OPTIMIZATION_LEVEL_O0
	(select result/config 'flags) = 0
	(select result/config 'code-model) = schema/WIRE_CODE_MODEL_SMALL
	(select result/config 'relocation-model) = schema/WIRE_RELOCATION_MODEL_STATIC
	(select result/config 'debug-format) = schema/WIRE_DEBUG_FORMAT_NONE
	(select result/config 'cpu-baseline) = schema/WIRE_CPU_BASELINE_X86_64_BASE
	(select result/config 'cpu-features-low) = 0
	(select result/config 'cpu-features-high) = 0
	(select result/config 'max-output-bytes) = 1048576
	(select result/config 'max-diagnostic-bytes) = 65536
	(select result/config 'worker-count) = 1
	(select result/config 'deterministic-seed) = 0
	(select result/config 'reserved-0) = 0
	(select result/config 'reserved-1) = 0
	(select result/config 'reserved-2) = 0
	(select result/config 'reserved-3) = 0
] "base RSCF config decode changed"

malformed-rscf: make block! 64
add-malformed-rscf: func [
	name [word!]
	expected-error expected-container-error expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-rscf reduce [
		name expected-error expected-container-error expected-offset expected-section data
	]
]

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-rscf 'INVALID-CONTAINER
	schema/WIRE_RSCF_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy rscf
fixture-mutations/put-bytes bad
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET) #{00000080}
add-malformed-rscf 'SCALAR-RANGE schema/WIRE_RSCF_ERROR_SCALAR_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_OFFSET schema/WIRE_TARGET_ARM64
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET schema/WIRE_ABI_AAPCS64
add-malformed-rscf 'UNSUPPORTED-TARGET schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_TARGET_OFFSET 0 bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_ABI_OFFSET schema/WIRE_ABI_SYSV_X64
add-malformed-rscf 'UNSUPPORTED-ABI schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_ABI_OFFSET 0 bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET schema/WIRE_ENDIAN_BIG
add-malformed-rscf 'UNSUPPORTED-ENDIAN schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_TARGET_ENDIAN_OFFSET 0 bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_POINTER_SIZE_OFFSET 4
add-malformed-rscf 'UNSUPPORTED-POINTER-SIZE schema/WIRE_RSCF_ERROR_UNSUPPORTED_TARGET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_HEADER_POINTER_SIZE_OFFSET 0 bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET 3
add-malformed-rscf 'BAD-OPTIMIZATION-LEVEL
	schema/WIRE_RSCF_ERROR_BAD_OPTIMIZATION_LEVEL schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_OPTIMIZATION_LEVEL_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET 16
add-malformed-rscf 'BAD-CONFIG-FLAGS schema/WIRE_RSCF_ERROR_BAD_CONFIG_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET 0
add-malformed-rscf 'BAD-CODE-MODEL schema/WIRE_RSCF_ERROR_BAD_CODE_MODEL
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CODE_MODEL_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET 0
add-malformed-rscf 'BAD-RELOCATION-MODEL schema/WIRE_RSCF_ERROR_BAD_RELOCATION_MODEL
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET 2
add-malformed-rscf 'BAD-DEBUG-FORMAT schema/WIRE_RSCF_ERROR_BAD_DEBUG_FORMAT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET schema/WIRE_CPU_BASELINE_NONE
add-malformed-rscf 'BAD-CPU-BASELINE schema/WIRE_RSCF_ERROR_BAD_CPU_BASELINE
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_BASELINE_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 1
add-malformed-rscf 'FEATURE-MISMATCH-LOW schema/WIRE_RSCF_ERROR_FEATURE_MISMATCH
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 1
add-malformed-rscf 'FEATURE-MISMATCH-HIGH schema/WIRE_RSCF_ERROR_FEATURE_MISMATCH
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_LOW_OFFSET 1
put-config bad schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET 1
add-malformed-rscf 'UNSUPPORTED-FEATURES-LOW
	schema/WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_LOW_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
fixture-mutations/put-u32 bad schema/WIRE_HEADER_FEATURE_MASK_HIGH_OFFSET 1
put-config bad schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET 1
add-malformed-rscf 'UNSUPPORTED-FEATURES-HIGH
	schema/WIRE_RSCF_ERROR_UNSUPPORTED_CPU_FEATURES schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_CPU_FEATURES_HIGH_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET
	(schema/WIRE_RSCG_MINIMUM_SIZE - 1)
add-malformed-rscf 'BAD-OUTPUT-LIMIT schema/WIRE_RSCF_ERROR_BAD_OUTPUT_LIMIT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_MAX_OUTPUT_BYTES_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET
	(schema/WIRE_RSDG_MINIMUM_SIZE - 1)
add-malformed-rscf 'BAD-DIAGNOSTIC-LIMIT
	schema/WIRE_RSCF_ERROR_BAD_DIAGNOSTIC_LIMIT schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_MAX_DIAGNOSTIC_BYTES_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET 2
add-malformed-rscf 'BAD-WORKER-COUNT schema/WIRE_RSCF_ERROR_BAD_WORKER_COUNT
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_WORKER_COUNT_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET 1
add-malformed-rscf 'BAD-DETERMINISTIC-SEED
	schema/WIRE_RSCF_ERROR_BAD_DETERMINISTIC_SEED schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_DETERMINISTIC_SEED_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

foreach field-offset reduce [
	schema/WIRE_RSCF_CONFIG_RESERVED_0_OFFSET
	schema/WIRE_RSCF_CONFIG_RESERVED_1_OFFSET
	schema/WIRE_RSCF_CONFIG_RESERVED_2_OFFSET
	schema/WIRE_RSCF_CONFIG_RESERVED_3_OFFSET
][
	bad: copy rscf
	put-config bad field-offset 1
	add-malformed-rscf to word! rejoin ["NONZERO-RESERVED-" field-offset]
		schema/WIRE_RSCF_ERROR_NONZERO_RESERVED schema/WIRE_CONTAINER_ERROR_SUCCESS
		(rscf-config-offset + field-offset) schema/WIRE_RSCF_SECTION_CONFIG bad
]

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET schema/WIRE_CONFIG_FLAG_DEBUG
add-malformed-rscf 'DEBUG-FLAG-WITHOUT-FORMAT
	schema/WIRE_RSCF_ERROR_INCONSISTENT_DEBUG schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_DEBUG_FORMAT_OFFSET schema/WIRE_DEBUG_FORMAT_RED
add-malformed-rscf 'DEBUG-FORMAT-WITHOUT-FLAG
	schema/WIRE_RSCF_ERROR_INCONSISTENT_DEBUG schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET schema/WIRE_CONFIG_FLAG_PIC
add-malformed-rscf 'PIC-FLAG-WITH-STATIC-MODEL
	schema/WIRE_RSCF_ERROR_INCONSISTENT_PIC schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

bad: copy rscf
put-config bad schema/WIRE_RSCF_CONFIG_RELOCATION_MODEL_OFFSET
	schema/WIRE_RELOCATION_MODEL_PIC
add-malformed-rscf 'PIC-MODEL-WITHOUT-FLAG
	schema/WIRE_RSCF_ERROR_INCONSISTENT_PIC schema/WIRE_CONTAINER_ERROR_SUCCESS
	(rscf-config-offset + schema/WIRE_RSCF_CONFIG_FLAGS_OFFSET)
	schema/WIRE_RSCF_SECTION_CONFIG bad

foreach fixture malformed-rscf [
	result: rscf-verifier/verify fixture/6
	assert not result/valid? [fixture/1 " malformed RSCF was accepted"]
	assert none? result/config [fixture/1 " malformed RSCF exposed a decoded config"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " but got " result/error
	]
	assert result/container-error = fixture/3 [
		fixture/1 " expected container error " fixture/3
		" but got " result/container-error
	]
	assert all [
		result/error-offset = fixture/4
		result/error-section = fixture/5
	][
		fixture/1 " expected location " fixture/4 ":" fixture/5
		" but got " result/error-offset ":" result/error-section
	]
]

repeat error-code
	(schema/WIRE_RSCF_ERROR_INCONSISTENT_PIC - schema/WIRE_RSCF_ERROR_INVALID_CONTAINER + 1)
[
	expected-error: schema/WIRE_RSCF_ERROR_INVALID_CONTAINER + error-code - 1
	found?: false
	foreach fixture malformed-rscf [
		if fixture/2 = expected-error [found?: true break]
	]
	assert found? ["RSCF error code has no directed Red fixture: " expected-error]
]

generating?: all [
	value? 'generating-wire-rscf-fixtures?
	get 'generating-wire-rscf-fixtures?
]
unless generating? [
	source-bytes: make binary! 65536
	append source-bytes read %wire-rscf-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-rscf-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-rscf-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System RSCF semantic fixtures are stale"
]

print [
	"PASS: RSCF semantics"
	"valid=" length? valid-rscf
	"malformed=" length? malformed-rscf
]
