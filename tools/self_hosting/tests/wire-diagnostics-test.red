Red [
	Title: "Hybrid compiler diagnostic semantic tests"
]

do %wire-string-table-test.red
do %../../../compiler/wire-diagnostics.red

diagnostic-verifier: compiler-wire-diagnostics

diagnostic-record: func [
	status severity phase message-string file line column function-symbol
	instruction flags [integer!]
][
	fixture-writer/words reduce [
		status severity phase message-string file line column function-symbol
		instruction flags
	]
]

build-diagnostic-message: func [
	string-records string-data diagnostics [binary!]
	targeted? [logic!]
	/local payloads sections
][
	payloads: make map! 8
	put payloads schema/WIRE_RSDG_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSDG_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSDG_SECTION_DIAGNOSTICS diagnostics
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSDG payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSDG_SECTION_STRINGS
		string-verifier/expected-string-flags
	either targeted? [
		fixture-writer/build
			schema/WIRE_MAGIC_RSDG
			schema/WIRE_TARGET_X86_64
			schema/WIRE_ABI_WIN64
			schema/WIRE_ENDIAN_LITTLE
			8
			sections
	][
		fixture-writer/build schema/WIRE_MAGIC_RSDG 0 0 0 0 sections
	]
]

diagnostic-section-of: func [
	data [binary!]
	/local result section
][
	result: container-verifier/verify/expect data schema/WIRE_MAGIC_RSDG
	assert result/valid? "diagnostic fixture is not a valid common container"
	section: container-verifier/find-section result
		schema/WIRE_RSDG_SECTION_DIAGNOSTICS
	assert not none? section "diagnostic fixture has no diagnostic section"
	section
]

diagnostic-string-records: fixture-writer/words [0 0 0 5 5 4]
diagnostic-string-data: #{6572726F726E6F7465} ; "error" + "note"

make-records: func [records [block!] /local output record][
	output: make binary! ((length? records) * schema/WIRE_RSDG_DIAGNOSTIC_SIZE)
	foreach record records [append output apply :diagnostic-record record]
	output
]

valid-diagnostics: make block! 32
add-valid-diagnostic: func [
	name [word!]
	status [integer!]
	data [binary!]
][
	append/only valid-diagnostics reduce [name status data]
]

invalid-arguments-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_ARGUMENTS
		schema/WIRE_DIAGNOSTIC_SEVERITY_FATAL
		schema/WIRE_DIAGNOSTIC_PHASE_BRIDGE
		2 0 0 0 0 0 0
	false
add-valid-diagnostic 'INVALID-ARGUMENTS
	schema/WIRE_STATUS_INVALID_ARGUMENTS invalid-arguments-diagnostic

invalid-config-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_CONFIGURATION
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_CONFIGURATION
		2 0 0 0 0 0 0
	false
add-valid-diagnostic 'INVALID-CONFIGURATION
	schema/WIRE_STATUS_INVALID_CONFIGURATION invalid-config-diagnostic

full-context-flags:
	schema/WIRE_DIAGNOSTIC_FLAG_FILE
	+ schema/WIRE_DIAGNOSTIC_FLAG_SOURCE
	+ schema/WIRE_DIAGNOSTIC_FLAG_FUNCTION
	+ schema/WIRE_DIAGNOSTIC_FLAG_INSTRUCTION

invalid-rsir-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_RSIR
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
		2 2 10 3 7 11 full-context-flags
	true
add-valid-diagnostic 'INVALID-RSIR-CONTEXT
	schema/WIRE_STATUS_INVALID_RSIR invalid-rsir-diagnostic

unsupported-target-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_UNSUPPORTED_TARGET
		schema/WIRE_DIAGNOSTIC_SEVERITY_FATAL
		schema/WIRE_DIAGNOSTIC_PHASE_SELECT
		2 0 0 0 0 0 0
	false
add-valid-diagnostic 'UNSUPPORTED-TARGET
	schema/WIRE_STATUS_UNSUPPORTED_TARGET unsupported-target-diagnostic

codegen-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_CODEGEN_FAILURE
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_ALLOCATE
		2 0 0 0 9 0 schema/WIRE_DIAGNOSTIC_FLAG_FUNCTION
	true
add-valid-diagnostic 'CODEGEN-FUNCTION
	schema/WIRE_STATUS_CODEGEN_FAILURE codegen-diagnostic

artifact-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_ARTIFACT
		schema/WIRE_DIAGNOSTIC_SEVERITY_FATAL
		schema/WIRE_DIAGNOSTIC_PHASE_ARTIFACT
		2 3 0 0 0 0 schema/WIRE_DIAGNOSTIC_FLAG_FILE
	true
add-valid-diagnostic 'INVALID-ARTIFACT-FILE
	schema/WIRE_STATUS_INVALID_ARTIFACT artifact-diagnostic

optimize-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_CODEGEN_FAILURE
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_OPTIMIZE
		2 0 0 0 5 0 schema/WIRE_DIAGNOSTIC_FLAG_FUNCTION
	true
add-valid-diagnostic 'CODEGEN-OPTIMIZE
	schema/WIRE_STATUS_CODEGEN_FAILURE optimize-diagnostic

ordered-records: make-records reduce [
	reduce [
		schema/WIRE_STATUS_INVALID_RSIR
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
		3 0 0 0 0 0 0
	]
	reduce [
		schema/WIRE_STATUS_INVALID_RSIR
		schema/WIRE_DIAGNOSTIC_SEVERITY_WARNING
		schema/WIRE_DIAGNOSTIC_PHASE_DECODE
		2 0 0 0 0 0 0
	]
	reduce [
		schema/WIRE_STATUS_INVALID_RSIR
		schema/WIRE_DIAGNOSTIC_SEVERITY_NOTE
		schema/WIRE_DIAGNOSTIC_PHASE_VERIFY
		3 0 0 0 0 0 0
	]
]
ordered-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data ordered-records false
add-valid-diagnostic 'PRODUCER-ORDER
	schema/WIRE_STATUS_INVALID_RSIR ordered-diagnostic

max-context-diagnostic: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_CODEGEN_FAILURE
		schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_ENCODE
		2 2147483647 2147483647 2147483647 2147483647 2147483647
		full-context-flags
	true
add-valid-diagnostic 'MAX-CONTEXT-IDS
	schema/WIRE_STATUS_CODEGEN_FAILURE max-context-diagnostic

result: diagnostic-verifier/verify none schema/WIRE_MAGIC_RSDG
assert all [
	not result/valid?
	result/error = schema/WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/view
] "non-binary diagnostic input did not return INVALID_ARGUMENTS"

result: diagnostic-verifier/verify invalid-arguments-diagnostic 'RSDG
assert result/error = schema/WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS
	"non-integer diagnostic magic did not return INVALID_ARGUMENTS"

result: diagnostic-verifier/verify rsir schema/WIRE_MAGIC_RSIR
assert all [
	not result/valid?
	result/error = schema/WIRE_DIAGNOSTIC_ERROR_UNSUPPORTED_MESSAGE
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/view
] "unsupported diagnostic message kind was accepted"

foreach fixture valid-diagnostics [
	result: diagnostic-verifier/verify fixture/3 schema/WIRE_MAGIC_RSDG
	assert result/valid? [
		fixture/1 " valid diagnostic rejected with error " result/error
	]
	assert result/error = schema/WIRE_DIAGNOSTIC_ERROR_SUCCESS [
		fixture/1 " valid diagnostic returned a nonzero error"
	]
	assert result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS [
		fixture/1 " valid diagnostic returned a container error"
	]
	assert result/string-error = schema/WIRE_STRING_TABLE_ERROR_SUCCESS [
		fixture/1 " valid diagnostic returned a string error"
	]
	assert all [result/error-offset = 0 result/error-section = 0][
		fixture/1 " valid diagnostic returned an error location"
	]
	assert object? result/strings [fixture/1 " exposed no string-table view"]
	assert object? result/view [fixture/1 " exposed no diagnostic view"]
	assert result/view/status = fixture/2 [fixture/1 " returned wrong primary status"]
]

base-section: diagnostic-section-of invalid-arguments-diagnostic
base-offset: select base-section 'payload-offset
base-ordinal: select base-section 'ordinal
base-string-result: container-verifier/verify/expect
	invalid-arguments-diagnostic schema/WIRE_MAGIC_RSDG
base-strings: container-verifier/find-section base-string-result
	schema/WIRE_RSDG_SECTION_STRINGS

result: diagnostic-verifier/verify invalid-arguments-diagnostic schema/WIRE_MAGIC_RSDG
assert all [
	result/view/status = schema/WIRE_STATUS_INVALID_ARGUMENTS
	result/view/record-count = 1
	result/view/records-offset = base-offset
	result/view/records-ordinal = base-ordinal
	result/view/record-size = schema/WIRE_RSDG_DIAGNOSTIC_SIZE
	result/strings/record-count = 3
] "verified diagnostic view changed"

malformed-diagnostics: make block! 192
add-malformed-diagnostic: func [
	name [word!]
	expected-error expected-container expected-string expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-diagnostics reduce [
		name expected-error expected-container expected-string
		expected-offset expected-section data
	]
]

bad: copy invalid-arguments-diagnostic
fixture-mutations/put-u32 bad schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0
add-malformed-diagnostic 'INVALID-CONTAINER
	schema/WIRE_DIAGNOSTIC_ERROR_INVALID_CONTAINER
	schema/WIRE_CONTAINER_ERROR_BAD_SCHEMA_FINGERPRINT
	schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	schema/WIRE_HEADER_SCHEMA_FINGERPRINT_OFFSET 0 bad

bad: copy invalid-arguments-diagnostic
fixture-mutations/put-u32 bad
	((select base-strings 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET) 0
add-malformed-diagnostic 'INVALID-STRINGS
	schema/WIRE_DIAGNOSTIC_ERROR_INVALID_STRINGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS
	schema/WIRE_STRING_TABLE_ERROR_BAD_STRING_SECTION_FLAGS
	((select base-strings 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	(select base-strings 'ordinal) bad

scalar-records: make-records reduce [
	reduce [
		schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_VERIFY 2 0 0 0 0 0 0
	]
	reduce [
		schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_SEVERITY_NOTE
		schema/WIRE_DIAGNOSTIC_PHASE_DECODE 3 0 0 0 0 0 0
	]
]
scalar-before-semantics: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data scalar-records false
scalar-section: diagnostic-section-of scalar-before-semantics
scalar-offset: select scalar-section 'payload-offset
fixture-mutations/put-u32 scalar-before-semantics
	(scalar-offset + schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET) 0
second-flags-offset:
	scalar-offset
	+ schema/WIRE_RSDG_DIAGNOSTIC_SIZE
	+ schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET
fixture-mutations/put-bytes scalar-before-semantics second-flags-offset #{00000080}
add-malformed-diagnostic 'SCALAR-BEFORE-SEMANTICS
	schema/WIRE_DIAGNOSTIC_ERROR_SCALAR_RANGE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	second-flags-offset (select scalar-section 'ordinal) scalar-before-semantics

bad: copy invalid-arguments-diagnostic
fixture-mutations/put-u32 bad
	((select base-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	schema/WIRE_SECTION_FLAG_SORTED
add-malformed-diagnostic 'BAD-DIAGNOSTIC-FLAGS
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_DIAGNOSTIC_SECTION_FLAGS
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select base-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET)
	base-ordinal bad

add-record-mutation: func [
	name [word!]
	source [binary!]
	record-index field-offset value expected-error [integer!]
	/local bad section absolute
][
	bad: copy source
	section: diagnostic-section-of bad
	absolute: (select section 'payload-offset)
		+ (record-index * schema/WIRE_RSDG_DIAGNOSTIC_SIZE)
		+ field-offset
	fixture-mutations/put-u32 bad absolute value
	add-malformed-diagnostic name expected-error
		schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		absolute (select section 'ordinal) bad
]

add-record-mutation 'BAD-STATUS-ZERO invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET schema/WIRE_STATUS_SUCCESS
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_STATUS
add-record-mutation 'BAD-STATUS-HIGH invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET 7
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_STATUS
add-record-mutation 'INCONSISTENT-STATUS ordered-diagnostic 1
	schema/WIRE_RSDG_DIAGNOSTIC_STATUS_OFFSET schema/WIRE_STATUS_CODEGEN_FAILURE
	schema/WIRE_DIAGNOSTIC_ERROR_INCONSISTENT_STATUS
add-record-mutation 'BAD-SEVERITY-ZERO invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_SEVERITY
add-record-mutation 'BAD-SEVERITY-HIGH invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET 5
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_SEVERITY
add-record-mutation 'BAD-PRIMARY-SEVERITY invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_SEVERITY_OFFSET
	schema/WIRE_DIAGNOSTIC_SEVERITY_NOTE
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_PRIMARY_SEVERITY
add-record-mutation 'BAD-PHASE-ZERO invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_PHASE
add-record-mutation 'BAD-PHASE-HIGH invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET 10
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_PHASE
add-record-mutation 'BAD-STATUS-PHASE invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_PHASE_OFFSET schema/WIRE_DIAGNOSTIC_PHASE_ARTIFACT
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_STATUS_PHASE
add-record-mutation 'BAD-MESSAGE-ZERO invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_MESSAGE_STRING
add-record-mutation 'BAD-MESSAGE-HIGH invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET 4
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_MESSAGE_STRING
add-record-mutation 'EMPTY-MESSAGE invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_MESSAGE_STRING_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_EMPTY_MESSAGE
add-record-mutation 'BAD-FLAGS invalid-rsir-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET 16
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_FLAGS

source-without-file: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_VERIFY 2 0 1 1 0 0
		schema/WIRE_DIAGNOSTIC_FLAG_SOURCE
	true
source-without-file-section: diagnostic-section-of source-without-file
add-malformed-diagnostic 'SOURCE-WITHOUT-FILE
	schema/WIRE_DIAGNOSTIC_ERROR_SOURCE_WITHOUT_FILE
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select source-without-file-section 'payload-offset)
		+ schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
	(select source-without-file-section 'ordinal) source-without-file

add-record-mutation 'FILE-WITHOUT-FLAG invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_FILE_ID
add-record-mutation 'FILE-FLAG-WITHOUT-ID artifact-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_FILE_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_FILE_ID
add-record-mutation 'LINE-WITHOUT-SOURCE artifact-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_LINE
add-record-mutation 'SOURCE-WITHOUT-LINE invalid-rsir-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_LINE_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_LINE
add-record-mutation 'COLUMN-WITHOUT-SOURCE artifact-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_COLUMN
add-record-mutation 'SOURCE-WITHOUT-COLUMN invalid-rsir-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_COLUMN_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_COLUMN

instruction-without-function: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_CODEGEN_FAILURE schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_ENCODE 2 0 0 0 0 1
		schema/WIRE_DIAGNOSTIC_FLAG_INSTRUCTION
	true
instruction-without-function-section: diagnostic-section-of instruction-without-function
add-malformed-diagnostic 'INSTRUCTION-WITHOUT-FUNCTION
	schema/WIRE_DIAGNOSTIC_ERROR_INSTRUCTION_WITHOUT_FUNCTION
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select instruction-without-function-section 'payload-offset)
		+ schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
	(select instruction-without-function-section 'ordinal) instruction-without-function

add-record-mutation 'FUNCTION-WITHOUT-FLAG invalid-arguments-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_FUNCTION_ID
add-record-mutation 'FUNCTION-FLAG-WITHOUT-ID codegen-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_FUNCTION_SYMBOL_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_FUNCTION_ID
add-record-mutation 'INSTRUCTION-WITHOUT-FLAG codegen-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET 1
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_INSTRUCTION_ID
add-record-mutation 'INSTRUCTION-FLAG-WITHOUT-ID invalid-rsir-diagnostic 0
	schema/WIRE_RSDG_DIAGNOSTIC_INSTRUCTION_OFFSET 0
	schema/WIRE_DIAGNOSTIC_ERROR_BAD_INSTRUCTION_ID

context-without-target: build-diagnostic-message
	diagnostic-string-records diagnostic-string-data
	diagnostic-record
		schema/WIRE_STATUS_INVALID_RSIR schema/WIRE_DIAGNOSTIC_SEVERITY_ERROR
		schema/WIRE_DIAGNOSTIC_PHASE_DECODE 2 1 0 0 0 0
		schema/WIRE_DIAGNOSTIC_FLAG_FILE
	false
context-without-target-section: diagnostic-section-of context-without-target
add-malformed-diagnostic 'CONTEXT-WITHOUT-TARGET
	schema/WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET
	schema/WIRE_CONTAINER_ERROR_SUCCESS schema/WIRE_STRING_TABLE_ERROR_SUCCESS
	((select context-without-target-section 'payload-offset)
		+ schema/WIRE_RSDG_DIAGNOSTIC_FLAGS_OFFSET)
	(select context-without-target-section 'ordinal) context-without-target

foreach fixture malformed-diagnostics [
	result: diagnostic-verifier/verify fixture/7 schema/WIRE_MAGIC_RSDG
	assert not result/valid? [fixture/1 " malformed diagnostic was accepted"]
	assert none? result/strings [fixture/1 " exposed strings on failure"]
	assert none? result/view [fixture/1 " exposed a diagnostic view on failure"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " but got " result/error
	]
	assert result/container-error = fixture/3 [
		fixture/1 " expected container error " fixture/3
		" but got " result/container-error
	]
	assert result/string-error = fixture/4 [
		fixture/1 " expected string error " fixture/4
		" but got " result/string-error
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
	schema/WIRE_DIAGNOSTIC_ERROR_SUCCESS
	schema/WIRE_DIAGNOSTIC_ERROR_INVALID_ARGUMENTS
	schema/WIRE_DIAGNOSTIC_ERROR_UNSUPPORTED_MESSAGE
]
foreach fixture malformed-diagnostics [append covered-errors fixture/2]
repeat error-index (schema/WIRE_DIAGNOSTIC_ERROR_CONTEXT_WITHOUT_TARGET + 1)[
	expected-error: error-index - 1
	assert not none? find covered-errors expected-error [
		"diagnostic error code has no directed Red test: " expected-error
	]
]

generating?: all [
	value? 'generating-wire-diagnostic-fixtures?
	get 'generating-wire-diagnostic-fixtures?
]
unless generating? [
	source-bytes: make binary! 131072
	append source-bytes read %wire-diagnostics-test.red
	append source-bytes read %wire-string-table-test.red
	append source-bytes read %wire-container-test.red
	append source-bytes read %../generate-wire-diagnostic-fixtures.red
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-diagnostics-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System diagnostic semantic fixtures are stale"
]

print [
	"PASS: diagnostic semantics"
	"valid=" length? valid-diagnostics
	"malformed=" length? malformed-diagnostics
]
