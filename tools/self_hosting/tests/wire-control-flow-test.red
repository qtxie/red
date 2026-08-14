Red [
	Title: "Hybrid compiler RSIR control-flow tests"
]

do %wire-scalar-operation-test.red
do %../../../compiler/wire-control-flow.red

control-flow-verifier: compiler-wire-control-flow

control-strings: make-canonical-strings ["" "cond" "fn-main" "fn-no-return" "fn-void" "merge" "n"]
control-id: :symbol-string-id

control-types: fixture-writer/words [
	; void, logic, signed i32.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
]

control-signatures: fixture-writer/words [
	; main(logic, i32) -> i32, void() -> void, no-return() -> void.
	1 0 3 1 2 2 0 0
	1 0 1 0 0 0 0 0
	1 32 1 0 0 0 0 0
]

control-parameters: fixture-writer/words reduce [
	1 control-id control-strings "cond" 2 0 0 schema/WIRE_DEBUG_TYPE_CODE_LOGIC 0 0
	1 control-id control-strings "n" 3 0 1 schema/WIRE_DEBUG_TYPE_CODE_INTEGER 0 0
]

control-symbols: fixture-writer/words reduce [
	; Symbol records are sorted by canonical UTF-8 name.
	control-id control-strings "fn-main" 1 2 2 1 0 0 0
	control-id control-strings "fn-no-return" 1 2 2 3 0 0 0
	control-id control-strings "fn-void" 1 2 2 2 0 0 0
]

control-constants: fixture-writer/words [
	; Canonical zero plus two scalar encodings of one and zero.
	3 1 0 0 0 0 0 0
	3 2 0 0 4 0 0 0
	3 2 0 4 4 0 0 0
]
control-constant-data: #{0100000000000000}

control-functions: fixture-writer/words [
	1 1 0 1 7 1 1 3 0 0
	2 3 0 8 1 8 0 0 0 0
	3 2 0 9 2 9 0 0 0 0
]

control-locals: fixture-writer/words reduce [
	1 control-id control-strings "cond" 2 1 0 0 0 0
	1 control-id control-strings "n" 3 1 0 0 0 1
	1 control-id control-strings "merge" 3 4 0 0 0 2
]

control-block-values: [
	1 0 1 1 1 2 0 0
	1 0 2 3 3 1 0 0
	1 0 5 2 4 1 0 0
	1 0 7 2 5 3 0 0
	1 0 9 1 0 0 0 0
	1 0 10 1 0 0 0 0
	1 0 11 1 0 0 0 0
	2 0 12 1 0 0 0 0
	3 0 13 1 0 0 0 0
	3 0 14 1 0 0 0 0
]

control-value-values: [
	1 1 0 2 1 0
	1 2 0 3 1 0
	2 2 0 3 1 0
	2 7 0 3 1 0
]

control-instruction-values: [
	; block opcode sub flags first-result result-count first-operand operand-count effects alias alias-id source
	1 38 0 0 0 0 1 3 256 0 0 0
	2 2 0 0 3 1 4 1 0 0 0 0
	2 22 0 0 0 0 5 2 2 1 3 0
	2 39 0 0 0 0 7 1 256 0 0 0
	3 22 0 0 0 0 8 2 2 1 3 0
	3 39 0 0 0 0 10 1 256 0 0 0
	4 21 0 0 4 1 11 1 1 1 3 0
	4 40 0 0 0 0 12 6 256 0 0 0
	5 41 0 0 0 0 18 1 256 0 0 0
	6 41 0 0 0 0 19 1 256 0 0 0
	7 45 0 0 0 0 0 0 256 0 0 0
	8 45 0 0 0 0 0 0 256 0 0 0
	9 41 0 0 0 0 0 0 256 0 0 0
	10 45 0 0 0 0 0 0 256 0 0 0
]

control-operand-values: [
	; branch
	1 1 0 0 4 2 0 0 4 3 0 0
	; branch-true copy, store, jump
	1 2 0 0 5 3 0 0 1 2 0 0 4 4 0 0
	; branch-false store, jump
	5 3 0 0 1 2 0 0 4 4 0 0
	; merge load and switch: selector, (case, target)*, default
	5 3 0 0
	1 4 0 0 2 1 0 0 4 5 0 0 2 2 0 0 4 6 0 0 4 7 0 0
	; returns
	1 2 0 0 1 4 0 0
]

control-edge-values: [
	1 2 2 0 0 0
	1 3 3 0 1 0
	2 4 1 0 0 0
	3 4 1 0 0 0
	4 5 4 1 0 0
	4 6 4 2 1 0
	4 7 5 0 2 0
]

build-control-flow-message: func [
	blocks* values* instructions* operands* edges* [binary!]
	/local payloads sections
][
	payloads: make map! 80
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS control-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA control-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES control-types
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES control-signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS control-parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS control-symbols
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS control-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA control-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS control-functions
	put payloads schema/WIRE_RSIR_SECTION_LOCALS control-locals
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS blocks*
	put payloads schema/WIRE_RSIR_SECTION_EDGES edges*
	put payloads schema/WIRE_RSIR_SECTION_VALUES values*
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instructions*
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operands*
	sections: fixture-writer/sections-for schema/WIRE_MAGIC_RSIR payloads
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_STRINGS
		string-verifier/expected-string-flags
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_FILES
		file-source-verifier/expected-index-flags
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	foreach kind reduce [
		schema/WIRE_RSIR_SECTION_SYMBOLS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
	][
		fixture-writer/set-section-flags sections kind
			symbol-linkage-verifier/expected-index-flags
	]
	fixture-writer/set-section-flags sections
		schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		constant-initializer-verifier/expected-index-flags
	fixture-writer/build schema/WIRE_MAGIC_RSIR schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64 schema/WIRE_ENDIAN_LITTLE 8 sections
]

control-blocks: fixture-writer/words control-block-values
control-values: fixture-writer/words control-value-values
control-instructions: fixture-writer/words control-instruction-values
control-operands: fixture-writer/words control-operand-values
control-edges: fixture-writer/words control-edge-values

rich-control-flow-message: build-control-flow-message control-blocks control-values
	control-instructions control-operands control-edges

control-section: func [data [binary!] kind [integer!]][constant-section data kind]
control-blocks-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_BLOCKS
control-edges-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_EDGES
control-constants-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_CONSTANTS
control-values-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_VALUES
control-instructions-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
control-operands-section:
	control-section rich-control-flow-message schema/WIRE_RSIR_SECTION_OPERANDS

control-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

malformed-control-flows: make block! 2048
add-malformed-control-flow: func [
	name [word!]
	expected-error expected-scalar expected-container expected-string expected-file
	expected-layout expected-type expected-function expected-module expected-symbol
	expected-constant expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-control-flows reduce [
		name expected-error expected-scalar expected-container expected-string
		expected-file expected-layout expected-type expected-function expected-module
		expected-symbol expected-constant expected-offset expected-section data
	]
]

add-control-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-control-flow name expected-error
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

find-scalar-control-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-scalar-operations [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested scalar fixture " name]
]

nested: find-scalar-control-fixture 'BAD-SCALAR-SUBOPCODE
add-malformed-control-flow 'INVALID-SCALAR-OPERATION
	schema/WIRE_CONTROL_FLOW_ERROR_INVALID_SCALAR_OPERATION
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14

mutate-control-record: func [
	name [word!] section [map!] id record-size field value
	expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-control-flow-message
	base: control-record-offset section id record-size
	fixture-mutations/put-u32 bad (base + field) value
	add-control-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

mutate-control-edge: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-control-record name control-edges-section id schema/WIRE_RSIR_EDGE_SIZE
		field value expected-error expected-field
]

mutate-control-block: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-control-record name control-blocks-section id schema/WIRE_RSIR_BLOCK_SIZE
		field value expected-error expected-field
]

mutate-control-instruction: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-control-record name control-instructions-section id
		schema/WIRE_RSIR_INSTRUCTION_SIZE field value expected-error expected-field
]

mutate-control-operand: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-control-record name control-operands-section id schema/WIRE_RSIR_OPERAND_SIZE
		field value expected-error expected-field
]

; Edge decoding and ownership precede all block and terminator semantics.
bad: copy rich-control-flow-message
bad-offset: (select control-edges-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
add-control-semantic-error 'BAD-EDGE-SECTION-FLAGS
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SECTION_FLAGS bad-offset
	(select control-edges-section 'ordinal) bad

bad: copy rich-control-flow-message
bad-offset: (select control-edges-section 'payload-offset)
	+ schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
fixture-mutations/put-bytes bad bad-offset #{00000080}
add-control-semantic-error 'SCALAR-RANGE schema/WIRE_CONTROL_FLOW_ERROR_SCALAR_RANGE
	bad-offset (select control-edges-section 'ordinal) bad

mutate-control-edge 'BAD-EDGE-KIND 1 schema/WIRE_RSIR_EDGE_KIND_OFFSET
	schema/WIRE_EDGE_KIND_UNREACHABLE schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_KIND
	schema/WIRE_RSIR_EDGE_KIND_OFFSET
mutate-control-edge 'NONZERO-EDGE-FLAGS 1 schema/WIRE_RSIR_EDGE_FLAGS_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_NONZERO_EDGE_FLAGS schema/WIRE_RSIR_EDGE_FLAGS_OFFSET
mutate-control-edge 'BAD-EDGE-SOURCE 1 schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET 0
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SOURCE
	schema/WIRE_RSIR_EDGE_SOURCE_BLOCK_OFFSET
mutate-control-edge 'BAD-EDGE-TARGET 1 schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET 11
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_TARGET
	schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
mutate-control-edge 'BAD-EDGE-FUNCTION 1 schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET 8
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_FUNCTION
	schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
mutate-control-edge 'BAD-EDGE-SELECTOR 1
	schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_SELECTOR
	schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
mutate-control-edge 'BAD-EDGE-ORDINAL 2 schema/WIRE_RSIR_EDGE_ORDINAL_OFFSET 0
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_ORDINAL
	schema/WIRE_RSIR_EDGE_ORDINAL_OFFSET
mutate-control-block 'BAD-BLOCK-EDGE-RANGE 2
	schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET 4
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_BLOCK_EDGE_RANGE
	schema/WIRE_RSIR_BLOCK_FIRST_OUTGOING_EDGE_OFFSET

bad: copy rich-control-flow-message
base: control-record-offset control-blocks-section 4 schema/WIRE_RSIR_BLOCK_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET) 2
add-control-semantic-error 'BAD-EDGE-COVERAGE
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EDGE_COVERAGE
	((select control-edges-section 'payload-offset) + (6 * schema/WIRE_RSIR_EDGE_SIZE))
	(select control-edges-section 'ordinal) bad

; Empty blocks and result-bearing terminators need rebuilt scalar-valid tables.
empty-block-values: copy control-block-values
poke empty-block-values 75 0
poke empty-block-values 76 0
empty-instruction-values: copy/part control-instruction-values
	((length? control-instruction-values) - 12)
bad: build-control-flow-message
	fixture-writer/words empty-block-values control-values
	fixture-writer/words empty-instruction-values control-operands control-edges
section: control-section bad schema/WIRE_RSIR_SECTION_BLOCKS
bad-offset: (control-record-offset section 10 schema/WIRE_RSIR_BLOCK_SIZE)
	+ schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET
add-control-semantic-error 'EMPTY-BLOCK schema/WIRE_CONTROL_FLOW_ERROR_EMPTY_BLOCK
	bad-offset (select section 'ordinal) bad

mutate-control-instruction 'BAD-TERMINATOR-POSITION 2
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_JUMP
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_POSITION
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
mutate-control-instruction 'BAD-TERMINATOR 11
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_KEEPALIVE
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
mutate-control-instruction 'BAD-SUBOPCODE 4
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-control-instruction 'BAD-INSTRUCTION-FLAGS 4
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_INSTRUCTION_FLAG_CHECKED
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_INSTRUCTION_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-control-instruction 'BAD-EFFECTS 4
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-control-instruction 'BAD-ALIAS 4
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_UNIVERSAL
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

result-bearing-values: copy control-value-values
append result-bearing-values [2 14 0 3 3 0]
result-bearing-instructions: copy control-instruction-values
poke result-bearing-instructions 161 5
poke result-bearing-instructions 162 1
bad: build-control-flow-message control-blocks
	fixture-writer/words result-bearing-values
	fixture-writer/words result-bearing-instructions control-operands control-edges
section: control-section bad schema/WIRE_RSIR_SECTION_INSTRUCTIONS
bad-offset: (control-record-offset section 14 schema/WIRE_RSIR_INSTRUCTION_SIZE)
	+ schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
add-control-semantic-error 'BAD-RESULT-COUNT
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_RESULT_COUNT bad-offset
	(select section 'ordinal) bad

mutate-control-instruction 'BAD-OPERAND-COUNT 4
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_BRANCH
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
mutate-control-operand 'BAD-OPERAND-KIND 7 schema/WIRE_RSIR_OPERAND_KIND_OFFSET
	schema/WIRE_OPERAND_KIND_VALUE schema/WIRE_CONTROL_FLOW_ERROR_BAD_OPERAND_KIND
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-control-operand 'NONZERO-OPERAND-AUXILIARY 7
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_NONZERO_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET

; Exact type and terminator-to-edge tables.
mutate-control-operand 'BAD-BRANCH-TYPE 1 schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 2
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_BRANCH_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-control-edge 'BAD-TERMINATOR-TARGET 1
	schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET 3
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_TERMINATOR_TARGET
	schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET
mutate-control-operand 'BAD-SWITCH-SELECTOR-TYPE 12
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_SELECTOR_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-control-record 'BAD-SWITCH-CASE-TYPE control-constants-section 1
	schema/WIRE_RSIR_CONSTANT_SIZE schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET 2
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_CASE_TYPE
	schema/WIRE_RSIR_CONSTANT_TYPE_OFFSET
; The verifier reports the switch operand, not the constant record, for type errors.
fixture: last malformed-control-flows
fixture/13: (control-record-offset control-operands-section 13
	schema/WIRE_RSIR_OPERAND_SIZE) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
fixture/14: select control-operands-section 'ordinal

bad: copy rich-control-flow-message
base: control-record-offset control-operands-section 15 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 3
edge-base: control-record-offset control-edges-section 6 schema/WIRE_RSIR_EDGE_SIZE
fixture-mutations/put-u32 bad
	(edge-base + schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET) 3
add-control-semantic-error 'DUPLICATE-SWITCH-CASE
	schema/WIRE_CONTROL_FLOW_ERROR_DUPLICATE_SWITCH_CASE
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
	(select control-operands-section 'ordinal) bad

mutate-control-edge 'BAD-SWITCH-EDGE 5
	schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET 2
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_SWITCH_EDGE
	schema/WIRE_RSIR_EDGE_SELECTOR_CONSTANT_OFFSET
mutate-control-operand 'BAD-RETURN-TYPE 18
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_RETURN_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-control-instruction 'BAD-NO-RETURN 12
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_RETURN
	schema/WIRE_CONTROL_FLOW_ERROR_BAD_NO_RETURN
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET

; A self-contained detached cycle has no virtual-root path and is rejected.
cycle-block-values: copy control-block-values
poke cycle-block-values 77 8
poke cycle-block-values 78 1
cycle-instruction-values: copy control-instruction-values
poke cycle-instruction-values 158 schema/WIRE_OPCODE_JUMP
poke cycle-instruction-values 163 20
poke cycle-instruction-values 164 1
cycle-operand-values: copy control-operand-values
append cycle-operand-values [4 10 0 0]
cycle-edge-values: copy control-edge-values
append cycle-edge-values [10 10 1 0 0 0]
bad: build-control-flow-message
	fixture-writer/words cycle-block-values control-values
	fixture-writer/words cycle-instruction-values
	fixture-writer/words cycle-operand-values fixture-writer/words cycle-edge-values
section: control-section bad schema/WIRE_RSIR_SECTION_BLOCKS
bad-offset: control-record-offset section 10 schema/WIRE_RSIR_BLOCK_SIZE
add-control-semantic-error 'UNROOTED-BLOCK
	schema/WIRE_CONTROL_FLOW_ERROR_UNROOTED_BLOCK bad-offset
	(select section 'ordinal) bad

mutate-control-operand 'USE-BEFORE-DEFINITION 4
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 3
	schema/WIRE_CONTROL_FLOW_ERROR_USE_BEFORE_DEFINITION
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-control-operand 'VALUE-NOT-DOMINATING 12
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 3
	schema/WIRE_CONTROL_FLOW_ERROR_VALUE_NOT_DOMINATING
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

; Exception edge and throw details are intentionally deferred to their owner layer.
throw-instruction-values: copy control-instruction-values
poke throw-instruction-values 134 schema/WIRE_OPCODE_THROW
throw-message: build-control-flow-message control-blocks control-values
	fixture-writer/words throw-instruction-values control-operands control-edges

exception-block-values: copy control-block-values
poke exception-block-values 14 2
poke exception-block-values 21 5
poke exception-block-values 29 6
exception-edge-values: copy/part control-edge-values 18
append exception-edge-values [2 7 6 0 1 0]
append exception-edge-values skip control-edge-values 18
exception-message: build-control-flow-message
	fixture-writer/words exception-block-values control-values control-instructions
	control-operands fixture-writer/words exception-edge-values

valid-control-flows: reduce [
	reduce ['RICH rich-control-flow-message]
	reduce ['THROW-DEFERRED throw-message]
	reduce ['EXCEPTION-EDGE-DEFERRED exception-message]
]

foreach fixture valid-control-flows [
	result: control-flow-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid control-flow module rejected with error " result/error
		" scalar=" result/scalar-operation-error
		" at " result/error-offset ":" result/error-section
	]
]

result: control-flow-verifier/verify rich-control-flow-message
assert to logic! all [
	result/view/edge-count = 7
	result/scalar-view/value-count = 4
	result/scalar-view/instruction-count = 14
	result/scalar-view/operand-count = 19
	result/functions/function-count = 3
	result/functions/block-count = 10
]["rich control-flow view changed"]

result: control-flow-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_CONTROL_FLOW_ERROR_INVALID_ARGUMENTS
	result/scalar-operation-error = schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
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
	none? result/view
]["non-binary control-flow input did not fail atomically"]

covered-errors: make block! 80
append covered-errors schema/WIRE_CONTROL_FLOW_ERROR_SUCCESS
append covered-errors schema/WIRE_CONTROL_FLOW_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-control-flows [
	result: control-flow-verifier/verify fixture/15
	assert not result/valid? [fixture/1 " malformed control-flow module was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/scalar-operation-error = fixture/3
		result/container-error = fixture/4
		result/string-error = fixture/5
		result/file-source-error = fixture/6
		result/data-layout-error = fixture/7
		result/type-layout-error = fixture/8
		result/function-signature-error = fixture/9
		result/module-lifecycle-error = fixture/10
		result/symbol-linkage-error = fixture/11
		result/constant-initializer-error = fixture/12
		result/error-offset = fixture/13
		result/error-section = fixture/14
	][fixture/1 " nested error or location changed"]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants
		none? result/scalar-view none? result/view
	][fixture/1 " published output views on failure"]
	append covered-errors fixture/2
]

; INSUFFICIENT_WORKSPACE is native-call state, not a malformed RSIR status.
repeat code 36 [
	assert not none? find covered-errors (code - 1) [
		"control-flow error code not covered by Red corpus: " code - 1
	]
]

result: control-flow-verifier/verify rich-control-flow-message
assert result/valid? "rich control-flow module failed after malformed corpus"

unless value? 'generating-wire-control-flow-fixtures? [
	source-bytes: make binary! 4'194'304
	foreach source-file [
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
		%../generate-wire-control-flow-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-control-flow-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System control-flow fixtures are stale"
]

print [
	"PASS: Red RSIR control-flow verifier edges=" result/view/edge-count
	" blocks=10 valid=" length? valid-control-flows
	" malformed=" length? malformed-control-flows
]
