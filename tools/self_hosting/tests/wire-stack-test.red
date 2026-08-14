Red [
	Title: "Hybrid compiler RSIR explicit-stack tests"
]

do %wire-exception-test.red
do %../../../compiler/wire-stack.red

stack-verifier: compiler-wire-stack

assert-stack: func [condition [logic!] message [string!]][
	unless condition [print ["FAIL:" message] quit/return 1]
]

result: stack-verifier/verify empty-subroutine-message
assert-stack result/valid? rejoin [
	"empty explicit-stack module rejected: " result/error
	" exception=" result/exception-error
	" at " result/error-offset ":" result/error-section
]

stack-strings: make-canonical-strings ["" "custom-target" "fn" "sub" "x"]
stack-id: :symbol-string-id

stack-types: fixture-writer/words [
	; void, logic, signed i32, pointer-to-i32, struct {i32}.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	5 0 8 8 0 3 0 0 0 1
	7 0 4 4 0 0 0 1 1 0
]
stack-fields: fixture-writer/words reduce [
	5 stack-id stack-strings "x" 3 0 0 0 0 0
]
stack-signatures: fixture-writer/words reduce [
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 0 0 0 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_CUSTOM
		1 0 0 0 0 0
]
stack-symbols: fixture-writer/words reduce [
	stack-id stack-strings "custom-target" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_EXTERNAL schema/WIRE_VISIBILITY_DEFAULT 2 0 0 0
	stack-id stack-strings "fn" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 1 0 0 0
]
stack-constants: fixture-writer/words [
	; zero, 1, 2, 3, -1, INT_MAX, false, and an aggregate zero.
	3 1 0 0 0 0 0 0
	3 2 0 0 4 0 0 0
	3 2 0 4 4 0 0 0
	3 2 0 8 4 0 0 0
	3 2 0 12 4 0 0 0
	3 2 0 16 4 0 0 0
	2 1 0 0 0 0 0 0
	5 1 0 0 0 0 0 0
]
stack-constant-data: #{010000000200000003000000FFFFFFFFFFFFFF7F}

build-stack-message: func [
	functions descriptors members blocks edges values instructions operands calls
		[binary!]
	/local payloads sections section-kind
][
	payloads: make map! 112
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS stack-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA stack-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES stack-types
	put payloads schema/WIRE_RSIR_SECTION_FIELDS stack-fields
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES stack-signatures
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS stack-symbols
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS stack-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA stack-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS functions
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS blocks
	put payloads schema/WIRE_RSIR_SECTION_EDGES edges
	put payloads schema/WIRE_RSIR_SECTION_VALUES values
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instructions
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operands
	put payloads schema/WIRE_RSIR_SECTION_CALLS calls
	put payloads schema/WIRE_RSIR_SECTION_SUBROUTINES descriptors
	put payloads schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS members
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

balanced-functions: fixture-writer/words [2 1 0 1 1 1 0 0 0 0]
balanced-blocks: fixture-writer/words [1 0 1 12 0 0 0 0]
balanced-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 4 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 4 0 3 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 7 0 3 1 schema/WIRE_VALUE_FLAG_NONE
]
balanced-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_STACK_ALLOC schema/WIRE_STACK_ALLOCATION_MODE_ZEROED
		0 1 1 1 1 stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_FREE 0 0 0 0 2 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 3 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_POP 0 0 2 1 0 0
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 4 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_POP 0 0 3 1 0 0
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_POP_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 5 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 6 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 7 2 custom-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
balanced-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
	schema/WIRE_OPERAND_KIND_SYMBOL 1 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 3 0 0
]
balanced-calls: fixture-writer/words reduce [
	11 2 schema/WIRE_CALL_KIND_DIRECT 7 0 8 1 0
]
balanced-stack-message: build-stack-message balanced-functions #{} #{}
	balanced-blocks #{} balanced-values balanced-instructions balanced-operands
	balanced-calls

dynamic-functions: fixture-writer/words [2 1 0 1 4 1 0 0 0 0]
dynamic-blocks: fixture-writer/words [
	1 0 1 2 1 2 0 0
	1 0 3 2 3 1 0 0
	1 0 5 1 4 1 0 0
	1 0 6 2 0 0 0 0
]
dynamic-edges: fixture-writer/words reduce [
	1 2 schema/WIRE_EDGE_KIND_TRUE 0 0 0
	1 3 schema/WIRE_EDGE_KIND_FALSE 0 1 0
	2 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
dynamic-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 2 1 schema/WIRE_VALUE_FLAG_NONE
]
dynamic-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CONSTANT 0 0 1 1 1 1 0
		schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_BRANCH 0 0 0 0 2 3 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 5 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 6 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 7 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_CALL 0 0 0 0 8 1 ordinary-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
dynamic-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 7 0 0
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 2 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_SYMBOL 2 0 0
]
dynamic-calls: fixture-writer/words reduce [
	6 1 schema/WIRE_CALL_KIND_DIRECT 8 0 0 0 0
]
dynamic-join-message: build-stack-message dynamic-functions #{} #{}
	dynamic-blocks dynamic-edges dynamic-values dynamic-instructions dynamic-operands
	dynamic-calls

stack-subroutine-functions: fixture-writer/words [2 1 0 1 2 1 0 0 0 0]
stack-subroutine-blocks: fixture-writer/words [
	1 0 1 2 0 0 0 0
	1 0 3 3 0 0 0 0
]
stack-subroutine-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 4 0 3 1 schema/WIRE_VALUE_FLAG_NONE
]
stack-subroutine-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 ordinary-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 2 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_STACK_POP 0 0 1 1 0 0
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
stack-subroutine-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
]
stack-subroutine-calls: fixture-writer/words reduce [
	1 1 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
]
stack-subroutine-descriptors: fixture-writer/words reduce [
	1 stack-id stack-strings "sub" 1 2 1 1 0 0
]
stack-subroutine-members: fixture-writer/words [1 2]
balanced-subroutine-message: build-stack-message stack-subroutine-functions
	stack-subroutine-descriptors stack-subroutine-members stack-subroutine-blocks #{}
	stack-subroutine-values stack-subroutine-instructions stack-subroutine-operands
	stack-subroutine-calls

host-epilog-functions: fixture-writer/words [2 1 0 1 1 1 0 0 0 0]
host-epilog-blocks: fixture-writer/words [1 0 1 4 0 0 0 0]
host-epilog-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 1 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_POP_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
host-epilog-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
]
host-epilog-message: build-stack-message host-epilog-functions #{} #{}
	host-epilog-blocks #{} #{} host-epilog-instructions host-epilog-operands #{}

stack-address-functions: fixture-writer/words [2 1 0 1 1 1 0 0 0 0]
stack-address-blocks: fixture-writer/words [1 0 1 3 0 0 0 0]
stack-address-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 4 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 2 0 4 1 schema/WIRE_VALUE_FLAG_NONE
]
stack-address-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_STACK_TOP 0 0 1 1 0 0
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_FRAME 0 0 2 1 0 0
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
stack-address-message: build-stack-message stack-address-functions #{} #{}
	stack-address-blocks #{} stack-address-values stack-address-instructions #{} #{}

valid-stacks: reduce [
	reduce ['BALANCED balanced-stack-message]
	reduce ['DYNAMIC-JOIN dynamic-join-message]
	reduce ['SUBROUTINE balanced-subroutine-message]
	reduce ['HOST-EPILOG host-epilog-message]
	reduce ['STACK-ADDRESSES stack-address-message]
	reduce ['EMPTY empty-subroutine-message]
]
foreach fixture valid-stacks [
	result: stack-verifier/verify fixture/2
	assert-stack result/valid? rejoin [
		form fixture/1 " valid explicit-stack module rejected: " result/error
		" exception=" result/exception-error
		" subroutine=" result/subroutine-error
		" call=" result/call-abi-error
		" control=" result/control-flow-error
		" scalar=" result/scalar-operation-error
		" at " result/error-offset ":" result/error-section
	]
]

stack-section: func [data [binary!] kind [integer!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSIR
	unless verified/valid? [return none]
	container-verifier/find-section verified kind
]

stack-record-offset: func [section [map!] id size [integer!]][
	(select section 'payload-offset) + ((id - 1) * size)
]

stack-type-section: stack-section balanced-stack-message schema/WIRE_RSIR_SECTION_TYPES
stack-block-section: stack-section balanced-stack-message schema/WIRE_RSIR_SECTION_BLOCKS
stack-value-section: stack-section balanced-stack-message schema/WIRE_RSIR_SECTION_VALUES
stack-instruction-section:
	stack-section balanced-stack-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
stack-operand-section: stack-section balanced-stack-message schema/WIRE_RSIR_SECTION_OPERANDS

malformed-stacks: make block! 2048
add-malformed-stack: func [
	name [word!]
	expected-error expected-exception expected-subroutine expected-call expected-control
	expected-scalar expected-container expected-string expected-file expected-layout
	expected-type expected-function expected-module expected-symbol expected-constant
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-stacks reduce [
		name expected-error expected-exception expected-subroutine expected-call
		expected-control expected-scalar expected-container expected-string expected-file
		expected-layout expected-type expected-function expected-module expected-symbol
		expected-constant expected-offset expected-section data
	]
]

add-stack-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-stack name expected-error
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

stack-address-value-section:
	stack-section stack-address-message schema/WIRE_RSIR_SECTION_VALUES
bad: copy stack-address-message
base: stack-record-offset stack-address-value-section 1 schema/WIRE_RSIR_VALUE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET) 3
add-stack-semantic-error 'BAD-STACK-ADDRESS-TYPE
	schema/WIRE_STACK_ERROR_BAD_STACK_ADDRESS_TYPE
	(base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
	(select stack-address-value-section 'ordinal) bad

mutate-balanced-stack-record: func [
	name [word!] section [map!] id size field value expected-error expected-field
		[integer!]
	/local bad base
][
	bad: copy balanced-stack-message
	base: stack-record-offset section id size
	fixture-mutations/put-u32 bad (base + field) value
	add-stack-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

find-exception-stack-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-exceptions [if fixture/1 = name [return fixture]]
	assert-stack false rejoin ["missing nested exception fixture " form name]
]

nested: find-exception-stack-fixture 'INVALID-SUBROUTINE
add-malformed-stack 'INVALID-EXCEPTION schema/WIRE_STACK_ERROR_INVALID_EXCEPTION
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14 nested/15 nested/16 nested/17
	nested/18

; INT_MAX slots followed by one push overflows the exact abstract depth.
bad: copy balanced-stack-message
base: stack-record-offset stack-operand-section 1 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 6
base: stack-record-offset stack-instruction-section 2 schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) schema/WIRE_OPCODE_STACK_PUSH
add-stack-semantic-error 'SCALAR-RANGE schema/WIRE_STACK_ERROR_SCALAR_RANGE
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select stack-instruction-section 'ordinal) bad

mutate-balanced-stack-record 'BAD-SUBOPCODE stack-instruction-section 2
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_STACK_ERROR_BAD_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-balanced-stack-record 'BAD-INSTRUCTION-FLAGS stack-instruction-section 2
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 1
	schema/WIRE_STACK_ERROR_BAD_INSTRUCTION_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-balanced-stack-record 'BAD-EFFECTS stack-instruction-section 2
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_STACK_ERROR_BAD_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-balanced-stack-record 'BAD-ALIAS stack-instruction-section 2
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
	schema/WIRE_ALIAS_KIND_UNIVERSAL schema/WIRE_STACK_ERROR_BAD_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

; Reinterpreting a valid deferred stack instruction preserves lower ownership
; while exposing the stack layer's exact operand/result arity checks.
mutate-balanced-stack-record 'BAD-OPERAND-COUNT stack-instruction-section 3
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
	schema/WIRE_OPCODE_STACK_POP schema/WIRE_STACK_ERROR_BAD_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
mutate-balanced-stack-record 'BAD-RESULT-COUNT stack-instruction-section 3
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
	schema/WIRE_OPCODE_STACK_ALLOC schema/WIRE_STACK_ERROR_BAD_RESULT_COUNT
	schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
mutate-balanced-stack-record 'BAD-OPERAND-KIND stack-operand-section 2
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_KIND_OFFSET
	schema/WIRE_OPERAND_KIND_SYMBOL schema/WIRE_STACK_ERROR_BAD_OPERAND_KIND
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-balanced-stack-record 'NONZERO-OPERAND-AUXILIARY stack-operand-section 2
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_STACK_ERROR_NONZERO_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-balanced-stack-record 'BAD-COUNT-TYPE stack-operand-section 2
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 7
	schema/WIRE_STACK_ERROR_BAD_COUNT_TYPE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-balanced-stack-record 'NEGATIVE-COUNT stack-operand-section 2
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_STACK_ERROR_NEGATIVE_COUNT schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-balanced-stack-record 'BAD-PUSH-TYPE stack-operand-section 3
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 8
	schema/WIRE_STACK_ERROR_BAD_PUSH_TYPE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

; The pointer itself remains canonical, but its pointee no longer matches the
; language-level pointer! [integer!] result of system/stack/allocate.
bad: copy balanced-stack-message
base: stack-record-offset stack-type-section 4 schema/WIRE_RSIR_TYPE_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_TYPE_DETAIL_ID_OFFSET) 2
base: stack-record-offset stack-value-section 1 schema/WIRE_RSIR_VALUE_SIZE
add-stack-semantic-error 'BAD-ALLOC-TYPE schema/WIRE_STACK_ERROR_BAD_ALLOC_TYPE
	(base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET)
	(select stack-value-section 'ordinal) bad

mutate-balanced-stack-record 'BAD-POP-TYPE stack-value-section 2
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_TYPE_OFFSET 2
	schema/WIRE_STACK_ERROR_BAD_POP_TYPE schema/WIRE_RSIR_VALUE_TYPE_OFFSET

; Allocating zero slots before freeing one exposes exact underflow.
bad: copy balanced-stack-message
base: stack-record-offset stack-operand-section 1 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 1
base: stack-record-offset stack-instruction-section 2 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'STACK-UNDERFLOW schema/WIRE_STACK_ERROR_STACK_UNDERFLOW
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select stack-instruction-section 'ordinal) bad

; A custom call consumes its explicit count operand from the same state.
bad: copy balanced-stack-message
base: stack-record-offset stack-operand-section 8 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 4
base: stack-record-offset stack-instruction-section 11 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'CUSTOM-STACK-UNDERFLOW
	schema/WIRE_STACK_ERROR_STACK_UNDERFLOW
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select stack-instruction-section 'ordinal) bad

mismatch-functions: fixture-writer/words [2 1 0 1 4 1 0 0 0 0]
mismatch-blocks: fixture-writer/words [
	1 0 1 2 1 2 0 0
	1 0 3 2 3 1 0 0
	1 0 5 1 4 1 0 0
	1 0 6 1 0 0 0 0
]
mismatch-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 2 1 schema/WIRE_VALUE_FLAG_NONE
]
mismatch-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CONSTANT 0 0 1 1 1 1 0
		schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_BRANCH 0 0 0 0 2 3 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 5 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 6 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
mismatch-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 7 0 0
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 2 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
]
stack-state-mismatch-message: build-stack-message mismatch-functions #{} #{}
	mismatch-blocks dynamic-edges mismatch-values mismatch-instructions
	mismatch-operands #{}
mismatch-block-section:
	stack-section stack-state-mismatch-message schema/WIRE_RSIR_SECTION_BLOCKS
base: stack-record-offset mismatch-block-section 4 schema/WIRE_RSIR_BLOCK_SIZE
add-stack-semantic-error 'STACK-STATE-MISMATCH
	schema/WIRE_STACK_ERROR_STACK_STATE_MISMATCH base
	(select mismatch-block-section 'ordinal) stack-state-mismatch-message

nested-functions: fixture-writer/words [2 1 0 1 1 1 0 0 0 0]
nested-blocks: fixture-writer/words [1 0 1 4 0 0 0 0]
nested-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_POP_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
nested-push-all-message: build-stack-message nested-functions #{} #{}
	nested-blocks #{} #{} nested-instructions #{} #{}
nested-instruction-section:
	stack-section nested-push-all-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
base: stack-record-offset nested-instruction-section 2 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'NESTED-PUSH-ALL schema/WIRE_STACK_ERROR_NESTED_PUSH_ALL
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select nested-instruction-section 'ordinal) nested-push-all-message

unmatched-blocks: fixture-writer/words [1 0 1 2 0 0 0 0]
unmatched-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_POP_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
unmatched-pop-all-message: build-stack-message nested-functions #{} #{}
	unmatched-blocks #{} #{} unmatched-instructions #{} #{}
unmatched-instruction-section:
	stack-section unmatched-pop-all-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
base: stack-record-offset unmatched-instruction-section 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'UNMATCHED-POP-ALL
	schema/WIRE_STACK_ERROR_UNMATCHED_POP_ALL
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select unmatched-instruction-section 'ordinal) unmatched-pop-all-message

unbalanced-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_PUSH_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 1 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_POP_ALL 0 0 0 0 0 0
		stack-verifier/opaque-stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
unbalanced-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
]
unbalanced-push-all-message: build-stack-message nested-functions #{} #{}
	nested-blocks #{} #{} unbalanced-instructions unbalanced-operands #{}
unbalanced-instruction-section:
	stack-section unbalanced-push-all-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
base: stack-record-offset unbalanced-instruction-section 3 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'UNBALANCED-PUSH-ALL
	schema/WIRE_STACK_ERROR_UNBALANCED_PUSH_ALL
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select unbalanced-instruction-section 'ordinal) unbalanced-push-all-message

depth-subroutine-blocks: fixture-writer/words [
	1 0 1 2 0 0 0 0
	1 0 3 2 0 0 0 0
]
depth-subroutine-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 ordinary-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_STACK_PUSH 0 0 0 0 2 1
		stack-verifier/stack-effects schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
depth-subroutine-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 0
]
bad-subroutine-depth-message: build-stack-message stack-subroutine-functions
	stack-subroutine-descriptors stack-subroutine-members depth-subroutine-blocks #{}
	#{} depth-subroutine-instructions depth-subroutine-operands stack-subroutine-calls
depth-instruction-section:
	stack-section bad-subroutine-depth-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
base: stack-record-offset depth-instruction-section 4 schema/WIRE_RSIR_INSTRUCTION_SIZE
add-stack-semantic-error 'BAD-SUBROUTINE-STACK-DEPTH
	schema/WIRE_STACK_ERROR_BAD_SUBROUTINE_STACK_DEPTH
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select depth-instruction-section 'ordinal) bad-subroutine-depth-message

result: stack-verifier/verify none
assert-stack (to logic! all [
	not result/valid?
	result/error = schema/WIRE_STACK_ERROR_INVALID_ARGUMENTS
	result/exception-error = schema/WIRE_EXCEPTION_ERROR_SUCCESS
	result/subroutine-error = schema/WIRE_SUBROUTINE_ERROR_SUCCESS
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
]) "non-binary stack input did not fail atomically"

covered-stack-errors: reduce [
	schema/WIRE_STACK_ERROR_SUCCESS
	schema/WIRE_STACK_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-stacks [
	result: stack-verifier/verify fixture/19
	assert-stack (not result/valid?) rejoin [
		form fixture/1 " malformed stack module was accepted"
	]
	assert-stack (result/error = fixture/2) rejoin [
		form fixture/1 " expected error " fixture/2 " got " result/error
		" exception=" result/exception-error
		" at " result/error-offset ":" result/error-section
	]
	assert-stack (to logic! all [
		result/exception-error = fixture/3
		result/subroutine-error = fixture/4
		result/call-abi-error = fixture/5
		result/control-flow-error = fixture/6
		result/scalar-operation-error = fixture/7
		result/container-error = fixture/8
		result/string-error = fixture/9
		result/file-source-error = fixture/10
		result/data-layout-error = fixture/11
		result/type-layout-error = fixture/12
		result/function-signature-error = fixture/13
		result/module-lifecycle-error = fixture/14
		result/symbol-linkage-error = fixture/15
		result/constant-initializer-error = fixture/16
		result/error-offset = fixture/17
		result/error-section = fixture/18
	]) rejoin [
		form fixture/1 " nested error or location changed: actual="
		result/error-offset ":" result/error-section " expected="
		fixture/17 ":" fixture/18
	]
	assert-stack (to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants none? result/scalar-view
		none? result/control-view none? result/call-view
		none? result/subroutine-view none? result/exception-view
	]) rejoin [form fixture/1 " published output views on failure"]
	append covered-stack-errors fixture/2
]

; INSUFFICIENT_WORKSPACE is native-only; Red covers every semantic status.
repeat code 25 [
	error-code: code - 1
	if error-code <> schema/WIRE_STACK_ERROR_INSUFFICIENT_WORKSPACE [
		assert-stack (not none? find covered-stack-errors error-code) rejoin [
			"stack error code not covered: " error-code
		]
	]
]

result: stack-verifier/verify host-epilog-message
assert-stack result/valid? "host epilog fixture failed after malformed corpus"

unless value? 'generating-wire-stack-fixtures? [
	source-bytes: make binary! 8'388'608
	foreach source-file [
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
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-stack-reds-test.reds
	assert-stack (not none? find generated-source source-digest)
		"generated Red/System stack fixtures are stale"

	print [
		"PASS: Red RSIR explicit stack valid=" length? valid-stacks
		" malformed=" length? malformed-stacks
	]
]
