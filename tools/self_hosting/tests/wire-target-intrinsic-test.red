Red [
	Title: "Hybrid compiler RSIR target-intrinsic tests"
]

do %wire-stack-test.red
do %../../../compiler/wire-target-intrinsic.red

target-verifier: compiler-wire-target-intrinsic

assert-target: func [condition [logic!] message [string!]][
	unless condition [print ["FAIL:" message] quit/return 1]
]

target-strings: make-canonical-strings ["" "arg" "fn"]
target-id: :symbol-string-id

target-types: fixture-writer/words [
	; void, u8, signed i32, f64, pointer-to-u8, pointer-to-i32.
	1 0 0 0 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	4 0 8 8 0 0 0 0 0 0
	5 0 8 8 0 2 0 0 0 1
	5 0 8 8 0 3 0 0 0 1
]

target-symbols: fixture-writer/words reduce [
	target-id target-strings "fn" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 1 0 0 0
]

target-constants: fixture-writer/words [
	; syscall number/i32, pointer-to-u8, pointer-to-i32, and u8.
	3 2 0 0 4 0 0 0
	5 1 0 0 0 0 0 0
	6 1 0 0 0 0 0 0
	2 1 0 0 0 0 0 0
]

target-constant-prefix: #{01000000}
target-fragment-bytes: #{9031C0660FEFC0}
target-constant-data: append copy target-constant-prefix target-fragment-bytes
target-fragments: fixture-writer/words reduce [
	schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64 4 1 1
		target-verifier/fragment-effects schema/WIRE_TARGET_CLOBBER_CLASS_WIN64_VOLATILE 0
	schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64 5 2 3
		target-verifier/fragment-effects schema/WIRE_TARGET_CLOBBER_CLASS_WIN64_VOLATILE 0
	schema/WIRE_TARGET_X86_64 schema/WIRE_ABI_WIN64 7 4 4
		target-verifier/fragment-effects schema/WIRE_TARGET_CLOBBER_CLASS_WIN64_VOLATILE 0
]

target-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 2 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 3 0 3 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 5 0 5 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 7 0 3 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 8 0 4 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 9 0 6 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 11 0 3 1 schema/WIRE_VALUE_FLAG_NONE
]

target-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_PORT_READ 0 0 1 1 1 1
		target-verifier/port-read-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PORT_WRITE 0 0 0 0 2 2
		target-verifier/port-write-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PORT_READ 0 0 2 1 4 1
		target-verifier/port-read-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PORT_WRITE 0 0 0 0 5 2
		target-verifier/port-write-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_GET_PC 0 0 3 1 0 0
		target-verifier/opaque-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_TARGET_FRAGMENT 0 0 0 0 7 1
		target-verifier/fragment-effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_TARGET_FRAGMENT 0 0 4 1 8 1
		target-verifier/fragment-effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_TARGET_FRAGMENT 0 0 5 1 9 1
		target-verifier/fragment-effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_CPU_REGISTER_READ schema/WIRE_X64_REGISTER_RAX
		0 6 1 0 0 target-verifier/opaque-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_CPU_REGISTER_WRITE schema/WIRE_X64_REGISTER_RBX
		0 0 0 10 1 target-verifier/opaque-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_CALL 0 0 7 1 11 7 ordinary-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
]

target-operand-prefix: reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 4 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0
	schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT 1 0 0
	schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT 2 0 0
	schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0
]

build-target-message: func [
	syscall-argument-count [integer!]
	/local signatures parameter-values parameters instruction-records operand-values operands calls
		functions blocks payloads sections section-kind ordinal
][
	signatures: fixture-writer/words reduce [
		schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 0 0 0 0 0
		schema/WIRE_CALLING_CONVENTION_SYSCALL 0 3 1 syscall-argument-count
			syscall-argument-count 0 0
	]
	parameter-values: make block! (syscall-argument-count * 8)
	ordinal: 0
	repeat parameter-id syscall-argument-count [
		repend parameter-values [
			2 target-id target-strings "arg" 3 0 ordinal
			schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
		]
		ordinal: ordinal + 1
	]
	parameters: fixture-writer/words parameter-values
	instruction-records: copy target-instructions
	fixture-mutations/put-u32 instruction-records
		(((11 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
			+ schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
		(syscall-argument-count + 1)
	operand-values: copy target-operand-prefix
	repeat argument-id syscall-argument-count [
		repend operand-values [schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0]
	]
	operands: fixture-writer/words operand-values
	calls: fixture-writer/words reduce [
		11 2 schema/WIRE_CALL_KIND_SYSCALL 11 0 12 syscall-argument-count 0
	]
	functions: fixture-writer/words [1 1 0 1 1 1 0 0 0 0]
	blocks: fixture-writer/words [1 0 1 12 0 0 0 0]

	payloads: make map! 112
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS target-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA target-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES target-types
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS target-symbols
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS target-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA target-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS functions
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS blocks
	put payloads schema/WIRE_RSIR_SECTION_VALUES target-values
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instruction-records
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operands
	put payloads schema/WIRE_RSIR_SECTION_CALLS calls
	put payloads schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS target-fragments
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	foreach section-kind reduce [
		schema/WIRE_RSIR_SECTION_SYMBOLS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
	][
		fixture-writer/set-section-flags sections section-kind
			symbol-linkage-verifier/expected-index-flags
	]
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		constant-initializer-verifier/expected-index-flags
	fixture-writer/build schema/WIRE_MAGIC_RSIR schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64 schema/WIRE_ENDIAN_LITTLE 8 sections
]

valid-target-message: build-target-message 6
seven-argument-syscall-message: build-target-message 7

valid-targets: reduce [
	reduce ['TARGET-INTRINSICS valid-target-message]
	reduce ['STACK-ADDRESSES stack-address-message]
	reduce ['EMPTY empty-subroutine-message]
]
foreach fixture valid-targets [
	result: target-verifier/verify fixture/2
	assert-target result/valid? rejoin [
		form fixture/1 " valid target module rejected: " result/error
		" stack=" result/stack-error " exception=" result/exception-error
		" at " result/error-offset ":" result/error-section
	]
]

result: target-verifier/verify valid-target-message
assert-target to logic! all [
	result/error = schema/WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	result/view/target-fragment-count = 3
	result/view/target-fragment-record-size = schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE
	result/constants/constant-data-owned-size = length? target-constant-prefix
	result/constants/constant-data-size = length? target-constant-data
	result/scalar-view/instruction-count = 12
	result/call-view/call-count = 1
] "verified target-intrinsic view changed"

target-section: func [data [binary!] kind [integer!]][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSIR
	container-verifier/find-section verified kind
]

target-record-offset: func [section [map!] id size [integer!]][
	(select section 'payload-offset) + ((id - 1) * size)
]

target-fragment-section:
	target-section valid-target-message schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS
target-constant-data-section:
	target-section valid-target-message schema/WIRE_RSIR_SECTION_CONSTANT_DATA
target-instruction-section:
	target-section valid-target-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
target-operand-section:
	target-section valid-target-message schema/WIRE_RSIR_SECTION_OPERANDS
target-value-section:
	target-section valid-target-message schema/WIRE_RSIR_SECTION_VALUES

target-instruction-ids: make map! reduce [
	'PORT-READ-U8 1 'PORT-WRITE-U8 2 'PORT-READ-I32 3 'PORT-WRITE-I32 4
	'GET-PC 5 'FRAGMENT-VOID 6 'FRAGMENT-I32 7 'FRAGMENT-F64 8
	'CPU-READ 9 'CPU-WRITE 10 'SYSCALL 11 'RETURN 12
]

malformed-targets: make block! 2048
add-malformed-target: func [
	name [word!]
	expected-error expected-stack expected-exception expected-subroutine expected-call
	expected-control expected-scalar expected-container expected-string expected-file
	expected-layout expected-type expected-function expected-module expected-symbol
	expected-constant expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-targets reduce [
		name expected-error expected-stack expected-exception expected-subroutine
		expected-call expected-control expected-scalar expected-container expected-string
		expected-file expected-layout expected-type expected-function expected-module
		expected-symbol expected-constant expected-offset expected-section data
	]
]

add-target-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-target name expected-error
		schema/WIRE_STACK_ERROR_SUCCESS
		schema/WIRE_EXCEPTION_ERROR_SUCCESS
		schema/WIRE_SUBROUTINE_ERROR_SUCCESS
		schema/WIRE_CALL_ABI_ERROR_SUCCESS
		schema/WIRE_CONTROL_FLOW_ERROR_SUCCESS
		schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
		schema/WIRE_CONTAINER_ERROR_SUCCESS
		schema/WIRE_STRING_TABLE_ERROR_SUCCESS
		schema/WIRE_FILE_SOURCE_ERROR_SUCCESS
		schema/WIRE_DATA_LAYOUT_ERROR_SUCCESS
		schema/WIRE_TYPE_LAYOUT_ERROR_SUCCESS
		schema/WIRE_FUNCTION_SIGNATURE_ERROR_SUCCESS
		schema/WIRE_MODULE_LIFECYCLE_ERROR_SUCCESS
		schema/WIRE_SYMBOL_LINKAGE_ERROR_SUCCESS
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
		expected-offset expected-section data
]

mutate-target-fragment: func [
	name [word!] id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy valid-target-message
	base: target-record-offset target-fragment-section id
		schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-target-semantic-error name expected-error (base + expected-field)
		(select target-fragment-section 'ordinal) bad
]

mutate-target-instruction: func [
	name instruction-name [word!] field value expected-error expected-field [integer!]
	/local bad base instruction-id
][
	bad: copy valid-target-message
	instruction-id: select target-instruction-ids instruction-name
	base: target-record-offset target-instruction-section instruction-id
		schema/WIRE_RSIR_INSTRUCTION_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-target-semantic-error name expected-error (base + expected-field)
		(select target-instruction-section 'ordinal) bad
]

mutate-target-operand: func [
	name [word!] id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy valid-target-message
	base: target-record-offset target-operand-section id schema/WIRE_RSIR_OPERAND_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-target-semantic-error name expected-error (base + expected-field)
		(select target-operand-section 'ordinal) bad
]

mutate-target-value: func [
	name [word!] id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy valid-target-message
	base: target-record-offset target-value-section id schema/WIRE_RSIR_VALUE_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-target-semantic-error name expected-error (base + expected-field)
		(select target-value-section 'ordinal) bad
]

nested: pick malformed-stacks 1
add-malformed-target 'INVALID-STACK schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_STACK
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14 nested/15 nested/16
	nested/17 nested/18 nested/19

bad: copy valid-target-message
bad-offset: (select target-fragment-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
add-target-semantic-error 'BAD-FRAGMENT-SECTION-FLAGS
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SECTION_FLAGS
	bad-offset (select target-fragment-section 'ordinal) bad

bad: copy valid-target-message
bad-offset: (select target-fragment-section 'payload-offset)
	+ schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET
fixture-mutations/put-bytes bad bad-offset #{00000080}
add-target-semantic-error 'SCALAR-RANGE
	schema/WIRE_TARGET_INTRINSIC_ERROR_SCALAR_RANGE
	bad-offset (select target-fragment-section 'ordinal) bad

mutate-target-fragment 'BAD-FRAGMENT-TARGET 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET schema/WIRE_TARGET_X86
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_TARGET
	schema/WIRE_RSIR_TARGET_FRAGMENT_TARGET_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-ABI 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET schema/WIRE_ABI_WIN32
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_ABI
	schema/WIRE_RSIR_TARGET_FRAGMENT_ABI_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-DATA-OFFSET 2
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET 2
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_OFFSET
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_OFFSET_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-DATA-SIZE 2
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_DATA_SIZE
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET
mutate-target-fragment 'FRAGMENT-DATA-RANGE 3
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET 5
	schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_RANGE
	schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-RETURN-TYPE 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_RETURN_TYPE
	schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-EFFECTS 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_EFFECTS
	schema/WIRE_RSIR_TARGET_FRAGMENT_EFFECT_FLAGS_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-CLOBBER-CLASS 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_CLOBBER_CLASS
	schema/WIRE_RSIR_TARGET_FRAGMENT_CLOBBER_CLASS_OFFSET
mutate-target-fragment 'BAD-FRAGMENT-SOURCE-LOCATION 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_SOURCE_LOCATION
	schema/WIRE_RSIR_TARGET_FRAGMENT_SOURCE_LOCATION_OFFSET

bad: copy valid-target-message
base: target-record-offset target-fragment-section 3
	schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE
	fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_TARGET_FRAGMENT_DATA_SIZE_OFFSET) 3
add-target-semantic-error 'FRAGMENT-DATA-COVERAGE
	schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_DATA_COVERAGE
	((select target-constant-data-section 'payload-offset) + 10)
	(select target-constant-data-section 'ordinal) bad

mutate-target-instruction 'BAD-SUBOPCODE 'PORT-READ-U8
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-target-instruction 'BAD-INSTRUCTION-FLAGS 'PORT-READ-U8
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 1
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_INSTRUCTION_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-target-instruction 'BAD-EFFECTS 'PORT-READ-U8
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-target-instruction 'BAD-ALIAS 'PORT-READ-U8
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_UNIVERSAL
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

; Keep the generic operand partition canonical while making instruction 1 own two.
bad: copy valid-target-message
base: target-record-offset target-instruction-section 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) 2
base2: target-record-offset target-instruction-section 2 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base2 + schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET) 3
fixture-mutations/put-u32 bad
	(base2 + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET) 1
add-target-semantic-error 'BAD-OPERAND-COUNT
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_COUNT
	(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
	(select target-instruction-section 'ordinal) bad

; Reassign the first two value definitions so generic result coverage remains valid.
bad: copy valid-target-message
base: target-record-offset target-instruction-section 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET) 0
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) 0
base2: target-record-offset target-instruction-section 3 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base2 + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET) 1
fixture-mutations/put-u32 bad
	(base2 + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) 2
value-base1: target-record-offset target-value-section 1 schema/WIRE_RSIR_VALUE_SIZE
value-base2: target-record-offset target-value-section 2 schema/WIRE_RSIR_VALUE_SIZE
fixture-mutations/put-u32 bad
	(value-base1 + schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET) 3
fixture-mutations/put-u32 bad
	(value-base2 + schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET) 1
add-target-semantic-error 'BAD-RESULT-COUNT
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_RESULT_COUNT
	(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
	(select target-instruction-section 'ordinal) bad

bad: copy valid-target-message
base: target-record-offset target-operand-section 1 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET) schema/WIRE_OPERAND_KIND_SYMBOL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 1
add-target-semantic-error 'BAD-OPERAND-KIND
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_OPERAND_KIND
	(base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	(select target-operand-section 'ordinal) bad

mutate-target-operand 'NONZERO-OPERAND-AUXILIARY 1
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_TARGET_INTRINSIC_ERROR_NONZERO_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-target-operand 'BAD-PORT-TYPE 1
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_PORT_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-target-value 'PORT-TYPE-MISMATCH 1
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 3
	schema/WIRE_TARGET_INTRINSIC_ERROR_PORT_TYPE_MISMATCH
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-target-value 'BAD-GET-PC-RESULT-TYPE 3
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 6
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_GET_PC_RESULT_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-target-operand 'BAD-FRAGMENT-REFERENCE 7
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 2
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_REFERENCE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
bad: copy valid-target-message
base: target-record-offset target-fragment-section 1
	schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_TARGET_FRAGMENT_RETURN_TYPE_OFFSET) 3
base: target-record-offset target-instruction-section 6 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-target-semantic-error 'FRAGMENT-RETURN-MISMATCH
	schema/WIRE_TARGET_INTRINSIC_ERROR_FRAGMENT_RETURN_MISMATCH
	(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
	(select target-instruction-section 'ordinal) bad

; Replace the third fragment use with a valid port read, leaving descriptor 3 orphaned.
bad: copy valid-target-message
base: target-record-offset target-instruction-section 8 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) schema/WIRE_OPCODE_PORT_READ
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
	target-verifier/port-read-effects
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET) schema/WIRE_ALIAS_KIND_NONE
operand-base1: target-record-offset target-operand-section 9 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(operand-base1 + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	schema/WIRE_OPERAND_KIND_CONSTANT
fixture-mutations/put-u32 bad
	(operand-base1 + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 3
value-base1: target-record-offset target-value-section 5 schema/WIRE_RSIR_VALUE_SIZE
fixture-mutations/put-u32 bad (value-base1 + schema/WIRE_RSIR_VALUE_TYPE_OFFSET) 3
add-target-semantic-error 'BAD-FRAGMENT-COVERAGE
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_FRAGMENT_COVERAGE
	(target-record-offset target-fragment-section 3
		schema/WIRE_RSIR_TARGET_FRAGMENT_SIZE)
	(select target-fragment-section 'ordinal) bad

mutate-target-instruction 'BAD-CPU-REGISTER 'CPU-READ
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 0
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-target-instruction 'BAD-CPU-REGISTER-WRITE 'CPU-WRITE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET schema/WIRE_X64_REGISTER_RSP
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_WRITE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-target-value 'BAD-CPU-REGISTER-TYPE 6
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 5
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_CPU_REGISTER_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

seven-call-section:
	target-section seven-argument-syscall-message schema/WIRE_RSIR_SECTION_CALLS
base: target-record-offset seven-call-section 1 schema/WIRE_RSIR_CALL_SIZE
add-target-semantic-error 'BAD-SYSCALL-ARGUMENT-COUNT
	schema/WIRE_TARGET_INTRINSIC_ERROR_BAD_SYSCALL_ARGUMENT_COUNT
	(base + schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET)
	(select seven-call-section 'ordinal) seven-argument-syscall-message

result: target-verifier/verify 1
assert-target to logic! all [
	not result/valid?
	result/error = schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_ARGUMENTS
	result/stack-error = schema/WIRE_STACK_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/header
	none? result/strings
	none? result/files
	none? result/layout
	none? result/types
	none? result/functions
	none? result/modules
	none? result/symbols
	none? result/constants
	none? result/scalar-view
	none? result/control-view
	none? result/call-view
	none? result/subroutine-view
	none? result/exception-view
	none? result/view
] "non-binary target input did not fail atomically"

covered-target-errors: reduce [
	schema/WIRE_TARGET_INTRINSIC_ERROR_SUCCESS
	schema/WIRE_TARGET_INTRINSIC_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-targets [
	result: target-verifier/verify fixture/20
	assert-target (not result/valid?) rejoin [
		form fixture/1 " malformed target module was accepted"
	]
	assert-target (result/error = fixture/2) rejoin [
		form fixture/1 " expected error " fixture/2 " got " result/error
		" stack=" result/stack-error " at " result/error-offset ":" result/error-section
	]
	assert-target to logic! all [
		result/stack-error = fixture/3
		result/exception-error = fixture/4
		result/subroutine-error = fixture/5
		result/call-abi-error = fixture/6
		result/control-flow-error = fixture/7
		result/scalar-operation-error = fixture/8
		result/container-error = fixture/9
		result/string-error = fixture/10
		result/file-source-error = fixture/11
		result/data-layout-error = fixture/12
		result/type-layout-error = fixture/13
		result/function-signature-error = fixture/14
		result/module-lifecycle-error = fixture/15
		result/symbol-linkage-error = fixture/16
		result/constant-initializer-error = fixture/17
		result/error-offset = fixture/18
		result/error-section = fixture/19
	] rejoin [form fixture/1 " nested error or location changed"]
	assert-target to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants none? result/scalar-view
		none? result/control-view none? result/call-view
		none? result/subroutine-view none? result/exception-view none? result/view
	] rejoin [form fixture/1 " published output views on failure"]
	append covered-target-errors fixture/2
]

repeat code 33 [
	assert-target (not none? find covered-target-errors (code - 1)) rejoin [
		"target-intrinsic error code not covered: " code - 1
	]
]

result: target-verifier/verify valid-target-message
assert-target result/valid? "target fixture failed after malformed corpus"

unless value? 'generating-wire-target-intrinsic-fixtures? [
	source-bytes: make binary! 8'388'608
	foreach source-file [
		%wire-target-intrinsic-test.red
		%wire-stack-test.red
		%wire-exception-test.red
		%wire-subroutine-test.red
		%wire-call-abi-test.red
		%wire-control-flow-test.red
		%wire-scalar-operation-test.red
		%wire-constant-initializer-test.red
		%wire-symbol-linkage-test.red
		%wire-function-signature-test.red
		%wire-module-lifecycle-test.red
		%wire-type-layout-test.red
		%wire-data-layout-test.red
		%wire-file-source-test.red
		%wire-string-table-test.red
		%wire-container-test.red
		%../generate-wire-subroutine-fixtures.red
		%../generate-wire-exception-fixtures.red
		%../generate-wire-stack-fixtures.red
		%../generate-wire-target-intrinsic-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-target-intrinsic-reds-test.reds
	assert-target (not none? find generated-source source-digest)
		"generated Red/System target-intrinsic fixtures are stale"

	print [
		"PASS: Red RSIR target intrinsics valid=" length? valid-targets
		" malformed=" length? malformed-targets
	]
]
