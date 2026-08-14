Red [
	Title: "Hybrid compiler RSIR call and Win64 ABI tests"
]

do %wire-control-flow-test.red
do %../../../compiler/wire-call-abi.red

call-abi-verifier: compiler-wire-call-abi

call-strings: make-canonical-strings [
	"" "agg" "agg-import" "a" "b" "callback" "caller" "count"
	"custom" "custom-direct" "custom-import" "custom-target" "fixed-direct"
	"format" "large" "lib.dll" "n" "printf" "private-var" "typed-target"
]
call-id: :symbol-string-id

call-types: fixture-writer/words [
	; void, signed i32, u8, c-string, f32, f64.
	1 0 0 0 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	5 4 8 8 0 3 0 0 0 1
	4 0 4 4 0 0 0 0 0 0
	4 0 8 8 0 0 0 0 0 0
	; Two i32 values fit one Win64 integer slot; the larger aggregate is indirect.
	7 0 8 4 0 0 0 1 2 0
	7 0 16 8 0 0 0 3 2 0
	; Exact indirect target types for callback, typed, and custom signatures.
	6 0 8 8 0 3 0 0 0 1
	6 0 8 8 0 7 0 0 0 1
	6 0 8 8 0 8 0 0 0 1
]

call-fields: fixture-writer/words reduce [
	7 call-id call-strings "a" 2 0 0 0 0 0
	7 call-id call-strings "b" 2 4 0 1 0 0
	8 call-id call-strings "n" 2 0 0 0 0 0
	8 call-id call-strings "format" 4 8 0 1 0 0
]

call-signatures: fixture-writer/words reduce [
	; 1 fixed direct, 2 aggregate C import, 3 callback, 4 syscall.
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 2 1 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_CDECL 0 8 2 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_CDECL schema/WIRE_FUNCTION_FLAG_CALLBACK
		2 3 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_SYSCALL 0 2 4 1 1 0 0
	; 5 C variadic, 6 private variadic, 7 typed, 8 custom.
	schema/WIRE_CALLING_CONVENTION_CDECL schema/WIRE_FUNCTION_FLAG_VARIADIC
		1 5 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_VARIADIC
		1 0 0 0 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_TYPED
		1 0 0 0 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_CUSTOM
		1 0 0 0 0 0
	; 9 caller, plus two signatures used by isolated malformed fixtures.
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 6 3 3 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 9 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_SYSCALL 0 7 10 1 1 0 0
]

call-parameters: fixture-writer/words reduce [
	1 call-id call-strings "n" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
	2 call-id call-strings "large" 8 0 0 schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE 0 0
	3 call-id call-strings "n" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
	4 call-id call-strings "n" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
	5 call-id call-strings "format" 4 0 0 schema/WIRE_DEBUG_TYPE_CODE_C_STRING 0 0
	9 call-id call-strings "callback" 9 0 0 schema/WIRE_DEBUG_TYPE_CODE_FUNCTION 0 0
	9 call-id call-strings "typed-target" 10 0 1 schema/WIRE_DEBUG_TYPE_CODE_FUNCTION 0 0
	9 call-id call-strings "custom-target" 11 0 2 schema/WIRE_DEBUG_TYPE_CODE_FUNCTION 0 0
	10 call-id call-strings "n" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
	11 call-id call-strings "n" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
]

; Symbol records are sorted by canonical UTF-8 name.
call-symbols: fixture-writer/words reduce [
	call-id call-strings "agg-import" 1 4 1 2 0 0 0
	call-id call-strings "caller" 1 2 2 9 0 0 0
	call-id call-strings "custom-direct" 1 3 1 8 0 0 0
	call-id call-strings "custom-import" 1 4 1 8 0 0 0
	call-id call-strings "fixed-direct" 1 3 1 1 0 0 0
	call-id call-strings "printf" 1 4 1 5 0 0 0
	call-id call-strings "private-var" 1 3 1 6 0 0 0
]

call-imports: fixture-writer/words reduce [
	call-id call-strings "lib.dll" call-id call-strings "agg" 1
		schema/WIRE_CALLING_CONVENTION_CDECL 0 0
	call-id call-strings "lib.dll" call-id call-strings "custom" 4
		schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 0
	call-id call-strings "lib.dll" call-id call-strings "printf" 6
		schema/WIRE_CALLING_CONVENTION_CDECL 0 0
]

call-constants: fixture-writer/words [
	; type kind flags data-offset data-size first-part part-count auxiliary
	2 1 0 0 0 0 0 0
	2 2 0 0 4 0 0 0
	2 2 0 4 4 0 0 0
	4 1 0 0 0 0 0 0
	6 1 0 0 0 0 0 0
	7 1 0 0 0 0 0 0
	8 1 0 0 0 0 0 0
	5 1 0 0 0 0 0 0
	2 2 0 8 4 0 0 0
]
call-constant-data: #{020000003C000000FFFFFFFF}

call-functions: fixture-writer/words [
	; symbol signature flags first-block count entry first-local count source reserved
	2 9 0 1 1 1 1 3 0 0
]
call-locals: fixture-writer/words reduce [
	1 call-id call-strings "callback" 9 1 0 0 0 0
	1 call-id call-strings "typed-target" 10 1 0 0 0 1
	1 call-id call-strings "custom-target" 11 1 0 0 0 2
]

call-value-values: make block! 128
foreach [local-id type-id] [1 9 2 10 3 11][
	repend call-value-values [
		schema/WIRE_VALUE_DEFINITION_PARAMETER local-id 0 type-id 1
		schema/WIRE_VALUE_FLAG_NONE
	]
]
call-instruction-values: make block! 256
call-operand-values: make block! 384
call-record-values: make block! 160
call-instruction-ids: make map! 40
call-record-ids: make map! 40
call-callee-operands: make map! 40
call-argument-operands: make map! 40
call-result-values: make map! 20
call-next-instruction: 1
call-next-value: 4
call-next-operand: 1
call-next-record: 1

; A materialized positive count exercises the VALUE form of custom forwarding.
repend call-instruction-values [
	1 schema/WIRE_OPCODE_CONSTANT 0 0 call-next-value 1 call-next-operand 1
	0 schema/WIRE_ALIAS_KIND_NONE 0 0
]
repend call-operand-values [
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 schema/WIRE_OPERAND_FLAG_NONE
]
repend call-value-values [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION call-next-instruction 0 2 1
	schema/WIRE_VALUE_FLAG_NONE
]
put call-instruction-ids 'COUNT-CONSTANT call-next-instruction
count-value: call-next-value
call-next-instruction: call-next-instruction + 1
call-next-value: call-next-value + 1
call-next-operand: call-next-operand + 1

add-call: func [
	name [word!]
	signature-id call-kind callee-operand-kind callee-reference effects return-type
		[integer!]
	arguments [block!]
	/local instruction-id record-id first-result result-count first-operand
		first-argument argument-count operand-kind reference auxiliary result-id
][
	instruction-id: call-next-instruction
	record-id: call-next-record
	result-count: either return-type = 0 [0][1]
	first-result: either zero? result-count [0][call-next-value]
	first-operand: call-next-operand
	argument-count: (length? arguments) / 3
	first-argument: either zero? argument-count [0][first-operand + 1]

	repend call-instruction-values [
		1 schema/WIRE_OPCODE_CALL 0 0 first-result result-count first-operand
		(argument-count + 1) effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	]
	repend call-operand-values [
		callee-operand-kind callee-reference 0 schema/WIRE_OPERAND_FLAG_NONE
	]
	foreach [operand-kind reference auxiliary] arguments [
		repend call-operand-values [
			operand-kind reference auxiliary schema/WIRE_OPERAND_FLAG_NONE
		]
	]
	repend call-record-values [
		instruction-id signature-id call-kind first-operand 0
		first-argument argument-count 0
	]
	if result-count = 1 [
		result-id: call-next-value
		repend call-value-values [
			schema/WIRE_VALUE_DEFINITION_INSTRUCTION instruction-id 0 return-type 1
			schema/WIRE_VALUE_FLAG_NONE
		]
		put call-result-values name result-id
		call-next-value: call-next-value + 1
	]
	put call-instruction-ids name instruction-id
	put call-record-ids name record-id
	put call-callee-operands name first-operand
	put call-argument-operands name first-argument
	call-next-instruction: call-next-instruction + 1
	call-next-operand: call-next-operand + argument-count + 1
	call-next-record: call-next-record + 1
	first-result
]

ordinary-call-effects:
	schema/WIRE_EFFECT_FLAG_READ
	+ schema/WIRE_EFFECT_FLAG_WRITE
	+ schema/WIRE_EFFECT_FLAG_CALL
	+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
	+ schema/WIRE_EFFECT_FLAG_SAFEPOINT
throwing-call-effects: ordinary-call-effects + schema/WIRE_EFFECT_FLAG_THROW
custom-call-effects: ordinary-call-effects + schema/WIRE_EFFECT_FLAG_STACK

add-call 'DIRECT-FIXED 1 schema/WIRE_CALL_KIND_DIRECT
	schema/WIRE_OPERAND_KIND_SYMBOL 5 ordinary-call-effects 2
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1 0]
add-call 'IMPORT-AGGREGATE 2 schema/WIRE_CALL_KIND_IMPORT
	schema/WIRE_OPERAND_KIND_SYMBOL 1 ordinary-call-effects 8
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 7 0]
add-call 'INDIRECT-CALLBACK 3 schema/WIRE_CALL_KIND_INDIRECT
	schema/WIRE_OPERAND_KIND_VALUE 1 ordinary-call-effects 2
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1 0]
add-call 'SYSCALL 4 schema/WIRE_CALL_KIND_SYSCALL
	schema/WIRE_OPERAND_KIND_CONSTANT 3 ordinary-call-effects 2
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1 0]
add-call 'C-VARIADIC 5 schema/WIRE_CALL_KIND_IMPORT
	schema/WIRE_OPERAND_KIND_SYMBOL 6 ordinary-call-effects 0 reduce [
		schema/WIRE_OPERAND_KIND_CONSTANT 4 0
		schema/WIRE_OPERAND_KIND_CONSTANT 1 0
		schema/WIRE_OPERAND_KIND_CONSTANT 5 0
		schema/WIRE_OPERAND_KIND_CONSTANT 6 0
	]
add-call 'PRIVATE-VARIADIC 6 schema/WIRE_CALL_KIND_DIRECT
	schema/WIRE_OPERAND_KIND_SYMBOL 7 ordinary-call-effects 0 reduce [
		schema/WIRE_OPERAND_KIND_CONSTANT 1 0
		schema/WIRE_OPERAND_KIND_CONSTANT 4 0
		schema/WIRE_OPERAND_KIND_VALUE 1 0
	]
add-call 'PRIVATE-VARIADIC-EMPTY 6 schema/WIRE_CALL_KIND_DIRECT
	schema/WIRE_OPERAND_KIND_SYMBOL 7 ordinary-call-effects 0 []
add-call 'TYPED 7 schema/WIRE_CALL_KIND_INDIRECT
	schema/WIRE_OPERAND_KIND_VALUE 2 ordinary-call-effects 0 reduce [
		schema/WIRE_OPERAND_KIND_CONSTANT 1 0
		schema/WIRE_OPERAND_KIND_CONSTANT 4 0
		schema/WIRE_OPERAND_KIND_VALUE 1 0
	]
add-call 'CUSTOM-DIRECT 8 schema/WIRE_CALL_KIND_DIRECT
	schema/WIRE_OPERAND_KIND_SYMBOL 3 custom-call-effects 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 2 0]
add-call 'CUSTOM-IMPORT 8 schema/WIRE_CALL_KIND_IMPORT
	schema/WIRE_OPERAND_KIND_SYMBOL 4 custom-call-effects 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 2 0]
add-call 'CUSTOM-INDIRECT 8 schema/WIRE_CALL_KIND_INDIRECT
	schema/WIRE_OPERAND_KIND_VALUE 3 custom-call-effects 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE count-value 0]

return-instruction-id: call-next-instruction
repend call-instruction-values [
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
	schema/WIRE_ALIAS_KIND_NONE 0 0
]
call-next-instruction: call-next-instruction + 1

call-values: fixture-writer/words call-value-values
call-instructions: fixture-writer/words call-instruction-values
call-operands: fixture-writer/words call-operand-values
call-calls: fixture-writer/words call-record-values
call-blocks: fixture-writer/words reduce [
	1 0 1 (call-next-instruction - 1) 0 0 0 0
]

build-call-message: func [call-records [binary!] /local payloads sections section-kind][
	payloads: make map! 96
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS call-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA call-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES call-types
	put payloads schema/WIRE_RSIR_SECTION_FIELDS call-fields
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES call-signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS call-parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS call-symbols
	put payloads schema/WIRE_RSIR_SECTION_IMPORTS call-imports
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS call-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA call-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS call-functions
	put payloads schema/WIRE_RSIR_SECTION_LOCALS call-locals
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS call-blocks
	put payloads schema/WIRE_RSIR_SECTION_VALUES call-values
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS call-instructions
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS call-operands
	put payloads schema/WIRE_RSIR_SECTION_CALLS call-records
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
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

rich-call-message: build-call-message call-calls
call-section: func [data [binary!] kind [integer!]][control-section data kind]
call-calls-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_CALLS
call-instructions-section:
	call-section rich-call-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
call-operands-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_OPERANDS
call-values-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_VALUES
call-symbols-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_SYMBOLS
call-imports-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_IMPORTS
call-signatures-section: call-section rich-call-message schema/WIRE_RSIR_SECTION_SIGNATURES

call-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

malformed-call-abis: make block! 3072
add-malformed-call-abi: func [
	name [word!]
	expected-error expected-control expected-scalar expected-container expected-string
	expected-file expected-layout expected-type expected-function expected-module
	expected-symbol expected-constant expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-call-abis reduce [
		name expected-error expected-control expected-scalar expected-container
		expected-string expected-file expected-layout expected-type expected-function
		expected-module expected-symbol expected-constant expected-offset expected-section data
	]
]

add-call-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!] data [binary!]
][
	add-malformed-call-abi name expected-error
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

find-control-call-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-control-flows [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested control-flow fixture " name]
]

nested: find-control-call-fixture 'BAD-SUBOPCODE
add-malformed-call-abi 'INVALID-CONTROL-FLOW
	schema/WIRE_CALL_ABI_ERROR_INVALID_CONTROL_FLOW
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14 nested/15

mutate-call-record: func [
	name [word!] id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-call-message
	base: call-record-offset call-calls-section id schema/WIRE_RSIR_CALL_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-call-semantic-error name expected-error (base + expected-field)
		(select call-calls-section 'ordinal) bad
]

mutate-call-instruction: func [
	name instruction-name [word!] field value expected-error expected-field [integer!]
	/local bad base instruction-id
][
	bad: copy rich-call-message
	instruction-id: select call-instruction-ids instruction-name
	base: call-record-offset call-instructions-section instruction-id
		schema/WIRE_RSIR_INSTRUCTION_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-call-semantic-error name expected-error (base + expected-field)
		(select call-instructions-section 'ordinal) bad
]

mutate-call-operand: func [
	name [word!] operand-id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-call-message
	base: call-record-offset call-operands-section operand-id schema/WIRE_RSIR_OPERAND_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-call-semantic-error name expected-error (base + expected-field)
		(select call-operands-section 'ordinal) bad
]

mutate-call-value: func [
	name [word!] value-id field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-call-message
	base: call-record-offset call-values-section value-id schema/WIRE_RSIR_VALUE_SIZE
	fixture-mutations/put-u32 bad (base + field) value
	add-call-semantic-error name expected-error (base + expected-field)
		(select call-values-section 'ordinal) bad
]

bad: copy rich-call-message
bad-offset: (select call-calls-section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
add-call-semantic-error 'BAD-CALL-SECTION-FLAGS
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_SECTION_FLAGS bad-offset
	(select call-calls-section 'ordinal) bad

bad: copy rich-call-message
bad-offset: (select call-calls-section 'payload-offset)
	+ schema/WIRE_RSIR_CALL_RESERVED_OFFSET
fixture-mutations/put-bytes bad bad-offset #{00000080}
add-call-semantic-error 'SCALAR-RANGE schema/WIRE_CALL_ABI_ERROR_SCALAR_RANGE
	bad-offset (select call-calls-section 'ordinal) bad

mutate-call-record 'BAD-CALL-INSTRUCTION 1 schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_INSTRUCTION
	schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET

bad: copy rich-call-message
base: call-record-offset call-calls-section 1 schema/WIRE_RSIR_CALL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
	(select call-instruction-ids 'IMPORT-AGGREGATE)
base: call-record-offset call-calls-section 2 schema/WIRE_RSIR_CALL_SIZE
add-call-semantic-error 'BAD-CALL-ORDER schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ORDER
	(base + schema/WIRE_RSIR_CALL_INSTRUCTION_OFFSET)
	(select call-calls-section 'ordinal) bad

short-call-records: copy/part call-calls
	((length? call-calls) - schema/WIRE_RSIR_CALL_SIZE)
bad: build-call-message short-call-records
section: call-section bad schema/WIRE_RSIR_SECTION_INSTRUCTIONS
bad-offset: call-record-offset section
	(select call-instruction-ids 'CUSTOM-INDIRECT)
	schema/WIRE_RSIR_INSTRUCTION_SIZE
add-call-semantic-error 'BAD-CALL-COVERAGE
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_COVERAGE
	(bad-offset + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select section 'ordinal) bad

mutate-call-instruction 'BAD-CALL-SUBOPCODE 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-call-instruction 'BAD-CALL-FLAGS 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_INSTRUCTION_FLAG_CHECKED
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-call-instruction 'BAD-CALL-EFFECTS 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
	(ordinary-call-effects - schema/WIRE_EFFECT_FLAG_READ)
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-call-instruction 'BAD-CALL-ALIAS 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_NONE
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
mutate-call-instruction 'BAD-CALL-ALIAS-ID 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET

bad: copy rich-call-message
base: call-record-offset call-symbols-section 5 schema/WIRE_RSIR_SYMBOL_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_SYMBOL_TYPE_OR_SIGNATURE_OFFSET) 10
base: call-record-offset call-calls-section 1 schema/WIRE_RSIR_CALL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET) 10
instruction-base: call-record-offset call-instructions-section
	(select call-instruction-ids 'DIRECT-FIXED) schema/WIRE_RSIR_INSTRUCTION_SIZE
add-call-semantic-error 'BAD-CALL-RESULT-COUNT
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_COUNT
	(instruction-base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
	(select call-instructions-section 'ordinal) bad

mutate-call-value 'BAD-CALL-RESULT-TYPE
	(select call-result-values 'DIRECT-FIXED) schema/WIRE_RSIR_VALUE_TYPE_OFFSET 6
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_RESULT_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

mutate-call-record 'BAD-CALL-OPERAND-RANGE 1
	schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
	(select call-callee-operands 'DIRECT-FIXED)
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_OPERAND_RANGE
	schema/WIRE_RSIR_CALL_FIRST_ARGUMENT_OPERAND_OFFSET
mutate-call-record 'BAD-CALL-ARGUMENT-COUNT 1
	schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET 0
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_COUNT
	schema/WIRE_RSIR_CALL_ARGUMENT_COUNT_OFFSET
mutate-call-operand 'BAD-CALL-ARGUMENT-KIND
	(select call-argument-operands 'DIRECT-FIXED)
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET schema/WIRE_OPERAND_KIND_SYMBOL
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_KIND
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-call-operand 'BAD-CALL-ARGUMENT-TYPE
	(select call-argument-operands 'DIRECT-FIXED)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-CALL-ARGUMENT-VALUE
	(select call-argument-operands 'CUSTOM-DIRECT)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 9
	schema/WIRE_CALL_ABI_ERROR_BAD_CALL_ARGUMENT_VALUE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

mutate-call-record 'NONZERO-CALL-FLAGS 1 schema/WIRE_RSIR_CALL_FLAGS_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_NONZERO_CALL_FLAGS schema/WIRE_RSIR_CALL_FLAGS_OFFSET
mutate-call-record 'NONZERO-CALL-RESERVED 1 schema/WIRE_RSIR_CALL_RESERVED_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_NONZERO_CALL_RESERVED
	schema/WIRE_RSIR_CALL_RESERVED_OFFSET
mutate-call-record 'BAD-CALLEE-KIND 1 schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET 99
	schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_KIND
	schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
mutate-call-record 'BAD-CALLEE-OPERAND 1
	schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
	(select call-argument-operands 'DIRECT-FIXED)
	schema/WIRE_CALL_ABI_ERROR_BAD_CALLEE_OPERAND
	schema/WIRE_RSIR_CALL_CALLEE_REFERENCE_OFFSET
mutate-call-operand 'BAD-DIRECT-CALLEE
	(select call-callee-operands 'DIRECT-FIXED)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_BAD_DIRECT_CALLEE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-INDIRECT-CALLEE
	(select call-callee-operands 'INDIRECT-CALLBACK)
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET schema/WIRE_OPERAND_KIND_CONSTANT
	schema/WIRE_CALL_ABI_ERROR_BAD_INDIRECT_CALLEE
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-call-operand 'BAD-IMPORT-CALLEE
	(select call-callee-operands 'C-VARIADIC)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_CALL_ABI_ERROR_BAD_IMPORT_CALLEE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-SYSCALL-CALLEE
	(select call-callee-operands 'SYSCALL)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_CALLEE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-record 'BAD-TARGET-SIGNATURE 1 schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET 10
	schema/WIRE_CALL_ABI_ERROR_BAD_TARGET_SIGNATURE
	schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET
mutate-call-record 'BAD-CALLING-CONVENTION 4
	schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET 1
	schema/WIRE_CALL_ABI_ERROR_BAD_CALLING_CONVENTION
	schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET

mutate-call-operand 'BAD-VARIADIC-ARGUMENTS
	((select call-argument-operands 'C-VARIADIC) + 2)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 8
	schema/WIRE_CALL_ABI_ERROR_BAD_VARIADIC_ARGUMENTS
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-TYPED-ARGUMENTS
	(select call-argument-operands 'TYPED)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 6
	schema/WIRE_CALL_ABI_ERROR_BAD_TYPED_ARGUMENTS
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-CUSTOM-ARGUMENTS
	(select call-argument-operands 'CUSTOM-DIRECT)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_CALL_ABI_ERROR_BAD_CUSTOM_ARGUMENTS
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-operand 'BAD-AGGREGATE-ARGUMENT
	(select call-argument-operands 'SYSCALL)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 6
	schema/WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_ARGUMENT
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

bad: copy rich-call-message
base: call-record-offset call-calls-section 4 schema/WIRE_RSIR_CALL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET) 11
base: call-record-offset call-values-section
	(select call-result-values 'SYSCALL) schema/WIRE_RSIR_VALUE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET) 7
add-call-semantic-error 'BAD-AGGREGATE-RETURN
	schema/WIRE_CALL_ABI_ERROR_BAD_AGGREGATE_RETURN
	((call-record-offset call-calls-section 4 schema/WIRE_RSIR_CALL_SIZE)
		+ schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
	(select call-calls-section 'ordinal) bad

mutate-call-operand 'BAD-ABI
	(select call-argument-operands 'SYSCALL)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 5
	schema/WIRE_CALL_ABI_ERROR_BAD_ABI
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-instruction 'BAD-EFFECT-DECLARATION 'CUSTOM-DIRECT
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET ordinary-call-effects
	schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-call-instruction 'UNDECLARED-THROW-EFFECT 'DIRECT-FIXED
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET throwing-call-effects
	schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-call-operand 'BAD-SYSCALL-NUMBER
	(select call-callee-operands 'SYSCALL)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 9
	schema/WIRE_CALL_ABI_ERROR_BAD_SYSCALL_NUMBER
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-call-record 'UNSUPPORTED-CALL-KIND 1 schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
	schema/WIRE_CALL_KIND_CUSTOM schema/WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
	schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET
mutate-call-record 'UNSUPPORTED-SUBROUTINE-KIND 1
	schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET schema/WIRE_CALL_KIND_SUBROUTINE
	schema/WIRE_CALL_ABI_ERROR_UNSUPPORTED_CALL_KIND
	schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET

throwing-call-message: copy rich-call-message
base: call-record-offset call-signatures-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
fixture-mutations/put-u32 throwing-call-message
	(base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	schema/WIRE_FUNCTION_FLAG_MAY_THROW
base: call-record-offset call-instructions-section
	(select call-instruction-ids 'DIRECT-FIXED) schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 throwing-call-message
	(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) throwing-call-effects

bad: copy throwing-call-message
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) ordinary-call-effects
add-call-semantic-error 'MISSING-THROW-EFFECT
	schema/WIRE_CALL_ABI_ERROR_BAD_EFFECT_DECLARATION
	(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
	(select call-instructions-section 'ordinal) bad

valid-call-abis: reduce [
	reduce ['RICH rich-call-message]
	reduce ['EMPTY rich-control-flow-message]
	reduce ['THROWING throwing-call-message]
]
foreach fixture valid-call-abis [
	result: call-abi-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid call module rejected with error " result/error
		" control=" result/control-flow-error
		" at " result/error-offset ":" result/error-section
	]
]

result: call-abi-verifier/verify rich-call-message
assert to logic! all [
	result/view/call-count = 11
	result/scalar-view/instruction-count = 13
	result/scalar-view/value-count = 8
	result/functions/signature-count = 11
	result/types/type-count = 11
]["rich call/ABI view changed"]

result: call-abi-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_CALL_ABI_ERROR_INVALID_ARGUMENTS
	result/control-flow-error = schema/WIRE_CONTROL_FLOW_ERROR_SUCCESS
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
	none? result/control-view
	none? result/scalar-view
	none? result/view
]["non-binary call input did not fail atomically"]

covered-errors: make block! 96
append covered-errors schema/WIRE_CALL_ABI_ERROR_SUCCESS
append covered-errors schema/WIRE_CALL_ABI_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-call-abis [
	result: call-abi-verifier/verify fixture/16
	assert not result/valid? [fixture/1 " malformed call module was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/control-flow-error = fixture/3
		result/scalar-operation-error = fixture/4
		result/container-error = fixture/5
		result/string-error = fixture/6
		result/file-source-error = fixture/7
		result/data-layout-error = fixture/8
		result/type-layout-error = fixture/9
		result/function-signature-error = fixture/10
		result/module-lifecycle-error = fixture/11
		result/symbol-linkage-error = fixture/12
		result/constant-initializer-error = fixture/13
		result/error-offset = fixture/14
		result/error-section = fixture/15
	][
		fixture/1 " nested error or location changed: actual="
		result/error-offset ":" result/error-section " expected="
		fixture/14 ":" fixture/15
	]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants
		none? result/control-view none? result/scalar-view none? result/view
	][fixture/1 " published output views on failure"]
	append covered-errors fixture/2
]

repeat code 38 [
	assert not none? find covered-errors (code - 1) [
		"call/ABI error code not covered: " code - 1
	]
]

result: call-abi-verifier/verify rich-call-message
assert result/valid? "rich call module failed after malformed corpus"

unless value? 'generating-wire-call-abi-fixtures? [
	source-bytes: make binary! 8'388'608
	foreach source-file [
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
		%../generate-wire-call-abi-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-call-abi-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System call/ABI fixtures are stale"
]

print [
	"PASS: Red RSIR calls/Win64 ABI calls=" result/view/call-count
	" valid=" length? valid-call-abis
	" malformed=" length? malformed-call-abis
]
