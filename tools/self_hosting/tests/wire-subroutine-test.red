Red [
	Title: "Hybrid compiler RSIR subroutine tests"
]

do %wire-call-abi-test.red
do %../../../compiler/wire-subroutine.red

subroutine-verifier: compiler-wire-subroutine

subroutine-strings: control-strings
subroutine-types: control-types
subroutine-signatures: copy control-signatures
append subroutine-signatures fixture-writer/words [
	; Red/System zero-parameter i32() -> i32.
	1 0 3 0 0 0 0 0
]
subroutine-symbols: fixture-writer/words reduce [
	control-id control-strings "fn-void"
	schema/WIRE_SYMBOL_KIND_FUNCTION
	schema/WIRE_LINKAGE_INTERNAL
	schema/WIRE_VISIBILITY_HIDDEN
	2 0 0 0
]
subroutine-constants: control-constants
subroutine-constant-data: control-constant-data
subroutine-call-effects:
	schema/WIRE_EFFECT_FLAG_READ
	+ schema/WIRE_EFFECT_FLAG_WRITE
	+ schema/WIRE_EFFECT_FLAG_CALL
	+ schema/WIRE_EFFECT_FLAG_MAY_TRAP
	+ schema/WIRE_EFFECT_FLAG_SAFEPOINT

subroutine-functions: fixture-writer/words [
	1 2 0 1 4 1 0 0 0 0
]
subroutine-locals: #{}
subroutine-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 1 2 1 0 0
	1 0 4 1 0 0 0 0
	1 0 5 1 0 0 0 0
]
subroutine-edges: fixture-writer/words reduce [
	1 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	2 3 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
subroutine-values: #{}
subroutine-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1
		subroutine-call-effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 3 1
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
subroutine-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
]
subroutine-calls: fixture-writer/words reduce [
	1 2 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
]
subroutine-descriptors: fixture-writer/words [
	1 6 2 2 1 2 0 0
]
subroutine-members: fixture-writer/words [
	1 2
	1 3
]

build-subroutine-message-with-host: func [
	function-records symbol-records descriptors members blocks edges values
		instructions operands calls [binary!]
	/local payloads sections kind
][
	payloads: make map! 96
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS subroutine-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA subroutine-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES subroutine-types
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES subroutine-signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS control-parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS symbol-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS subroutine-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA subroutine-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS function-records
	put payloads schema/WIRE_RSIR_SECTION_LOCALS subroutine-locals
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
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_SOURCE_LOCATIONS
		file-source-verifier/expected-index-flags
	foreach kind reduce [
		schema/WIRE_RSIR_SECTION_SYMBOLS
		schema/WIRE_RSIR_SECTION_IMPORTS
		schema/WIRE_RSIR_SECTION_EXPORTS
	][
		fixture-writer/set-section-flags sections kind
			symbol-linkage-verifier/expected-index-flags
	]
	fixture-writer/set-section-flags sections schema/WIRE_RSIR_SECTION_CONSTANT_BINDINGS
		constant-initializer-verifier/expected-index-flags
	fixture-writer/build schema/WIRE_MAGIC_RSIR schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64 schema/WIRE_ENDIAN_LITTLE 8 sections
]

build-subroutine-message: func [
	descriptors members blocks edges values instructions operands calls [binary!]
][
	build-subroutine-message-with-host subroutine-functions subroutine-symbols
		descriptors members blocks edges values instructions operands calls
]

subroutine-message: build-subroutine-message
	subroutine-descriptors subroutine-members subroutine-blocks subroutine-edges
	subroutine-values subroutine-instructions subroutine-operands subroutine-calls

assert-subroutine: func [condition [logic!] message [string!]][
	unless condition [print ["FAIL:" message] quit/return 1]
]

result: subroutine-verifier/verify subroutine-message
assert-subroutine result/valid? rejoin [
	"valid subroutine rejected: " result/error
	" call=" result/call-abi-error
	" control=" result/control-flow-error
	" scalar=" result/scalar-operation-error
	" symbol=" result/symbol-linkage-error
	" at " result/error-offset ":" result/error-section
]
assert-subroutine result/view/subroutine-count = 1 "subroutine view count changed"
assert-subroutine result/view/block-member-count = 2 "subroutine member view count changed"

; A second independently rooted subroutine freezes deterministic ordering and
; proves that membership remains a host-function-owned block partition.
two-subroutine-functions: subroutine-functions
two-subroutine-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 1 0 0 0 0
	1 0 4 1 0 0 0 0
	1 0 5 1 0 0 0 0
]
two-subroutine-edges: fixture-writer/words reduce [
	1 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
two-subroutine-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1
		subroutine-call-effects schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
two-subroutine-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
]
two-subroutine-calls: fixture-writer/words reduce [
	1 2 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
]
two-subroutine-descriptors: fixture-writer/words [
	1 6 2 2 1 1 0 0
	1 5 2 3 2 1 0 0
]
two-subroutine-members: fixture-writer/words [1 2 2 3]
two-subroutine-message: build-subroutine-message
	two-subroutine-descriptors two-subroutine-members two-subroutine-blocks
	two-subroutine-edges subroutine-values two-subroutine-instructions
	two-subroutine-operands two-subroutine-calls
result: subroutine-verifier/verify two-subroutine-message
assert-subroutine result/valid? "two independently rooted subroutines rejected"

; Calls are control transfers at the subroutine layer, not ordinary CFG edges.
; Consequently, two subroutines may call each other without violating the
; entry-stub or region-isolation rules.
mutual-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 2 0 0 0 0
	1 0 5 2 0 0 0 0
	1 0 7 1 0 0 0 0
]
mutual-edges: fixture-writer/words reduce [
	1 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
mutual-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CALL 0 0 0 0 3 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_CALL 0 0 0 0 4 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
mutual-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_SUBROUTINE 2 0 0
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
]
mutual-calls: fixture-writer/words reduce [
	1 2 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
	3 2 schema/WIRE_CALL_KIND_SUBROUTINE 3 0 0 0 0
	5 2 schema/WIRE_CALL_KIND_SUBROUTINE 4 0 0 0 0
]
mutual-subroutine-message: build-subroutine-message
	two-subroutine-descriptors two-subroutine-members mutual-blocks mutual-edges
	subroutine-values mutual-instructions mutual-operands mutual-calls

; A non-void subroutine returns a normal SSA value whose type exactly matches
; its zero-parameter Red/System signature.
typed-functions: fixture-writer/words [
	1 2 0 1 2 1 0 0 0 0
]
typed-blocks: fixture-writer/words [
	1 0 1 1 0 0 0 0
	1 0 2 2 0 0 0 0
]
typed-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 2 0 3 1 0
]
typed-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CONSTANT 0 0 1 1 1 1 0
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 2 1
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
typed-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
]
typed-descriptors: fixture-writer/words [
	1 6 4 2 1 1 0 0
]
typed-members: fixture-writer/words [1 2]
typed-subroutine-message: build-subroutine-message-with-host
	typed-functions subroutine-symbols typed-descriptors typed-members
	typed-blocks #{} typed-values typed-instructions typed-operands #{}

; Required empty sections are a valid declaration of a module with no
; compiler-generated subroutines. Keep its host CFG a single entry-rooted
; chain so this case does not inherit unrelated multi-root control fixtures.
empty-blocks: fixture-writer/words [
	1 0 1 1 1 1 0 0
	1 0 2 1 2 1 0 0
	1 0 3 1 3 1 0 0
	1 0 4 1 0 0 0 0
]
empty-edges: fixture-writer/words reduce [
	1 2 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	2 3 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
empty-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 1 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 3 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
empty-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_BLOCK 2 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
]
empty-subroutine-message: build-subroutine-message #{} #{}
	empty-blocks empty-edges #{} empty-instructions empty-operands #{}

valid-subroutines: reduce [
	reduce ['BASIC subroutine-message]
	reduce ['TWO-ROOTS two-subroutine-message]
	reduce ['MUTUAL-RECURSION mutual-subroutine-message]
	reduce ['TYPED-RETURN typed-subroutine-message]
	reduce ['EMPTY empty-subroutine-message]
]
foreach fixture valid-subroutines [
	result: subroutine-verifier/verify fixture/2
	assert-subroutine result/valid? rejoin [
		form fixture/1 " valid subroutine module rejected: " result/error
		" call=" result/call-abi-error " control=" result/control-flow-error
		" at " result/error-offset ":" result/error-section
	]
]

subroutine-section: func [data [binary!] kind [integer!] /local verified][
	verified: container-verifier/verify/expect data schema/WIRE_MAGIC_RSIR
	unless verified/valid? [return none]
	container-verifier/find-section verified kind
]

subroutine-offset: func [data [binary!] kind field [integer!]][
	(select (subroutine-section data kind) 'payload-offset) + field
]

subroutine-directory-flags-offset: func [data [binary!] kind [integer!]][
	(select (subroutine-section data kind) 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
]

malformed-subroutines: make block! 256
add-subroutine-error: func [
	name [word!] expected-error expected-call expected-control expected-scalar
	expected-container expected-string expected-file expected-layout expected-type
	expected-function expected-module expected-symbol expected-constant
	expected-offset expected-section [integer!] data [binary!]
][
	append/only malformed-subroutines reduce [
		name expected-error expected-call expected-control expected-scalar
		expected-container expected-string expected-file expected-layout expected-type
		expected-function expected-module expected-symbol expected-constant
		expected-offset expected-section data
	]
]

add-subroutine-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-subroutine-error name expected-error
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

; An ordinary edge into a subroutine entry violates the entry-stub rule even
; when both endpoints belong to the same host function.
incoming-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 1 0 0 0 0
	1 0 4 1 2 1 0 0
	1 0 5 1 0 0 0 0
]
incoming-edges: fixture-writer/words reduce [
	1 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 2 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
incoming-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 3 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
incoming-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 2 0 0
]
incoming-message: build-subroutine-message subroutine-descriptors subroutine-members
	incoming-blocks incoming-edges subroutine-values incoming-instructions
	incoming-operands subroutine-calls
incoming-descriptor-base: select (subroutine-section incoming-message
	schema/WIRE_RSIR_SECTION_SUBROUTINES) 'payload-offset
add-subroutine-semantic-error 'SUBROUTINE-ENTRY-INCOMING
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
	(incoming-descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
	(select (subroutine-section incoming-message
		schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) incoming-message

; A block in a subroutine region can be a control-flow root for the lower
; verifier, but must still be reachable from that subroutine's declared entry.
unrooted-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 1 0 0 0 0
	1 0 4 1 0 0 0 0
	1 0 5 1 0 0 0 0
]
unrooted-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_UNREACHABLE 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
unrooted-edges: fixture-writer/words reduce [
	1 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]
unrooted-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
]
unrooted-message: build-subroutine-message subroutine-descriptors subroutine-members
	unrooted-blocks unrooted-edges subroutine-values unrooted-instructions
	unrooted-operands subroutine-calls
unrooted-member-offset: select
	(subroutine-section unrooted-message schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS)
	'payload-offset
add-subroutine-semantic-error 'UNROOTED-SUBROUTINE-BLOCK
	schema/WIRE_SUBROUTINE_ERROR_UNROOTED_SUBROUTINE_BLOCK
	(unrooted-member-offset + schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
		+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
	(select (subroutine-section unrooted-message
		schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) unrooted-message

; Extra membership records are rejected instead of being silently ignored.
coverage-members: fixture-writer/words [1 2 1 3 1 4]
coverage-message: build-subroutine-message subroutine-descriptors coverage-members
	subroutine-blocks subroutine-edges subroutine-values subroutine-instructions
	subroutine-operands subroutine-calls
coverage-member-offset: select
	(subroutine-section coverage-message schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS)
	'payload-offset
add-subroutine-semantic-error 'BAD-SUBROUTINE-BLOCK-COVERAGE
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_COVERAGE
	(coverage-member-offset + (schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE * 2))
	(select (subroutine-section coverage-message
		schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) coverage-message

; A subroutine call must remain within its host function.
cross-host-symbols: fixture-writer/words reduce [
	control-id control-strings "fn-main"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_LINKAGE_INTERNAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 0 0
	control-id control-strings "fn-void"
		schema/WIRE_SYMBOL_KIND_FUNCTION schema/WIRE_LINKAGE_INTERNAL
		schema/WIRE_VISIBILITY_HIDDEN 2 0 0 0
]
cross-host-functions: fixture-writer/words [
	1 2 0 1 1 1 0 0 0 0
	2 2 0 2 2 3 0 0 0 0
]
cross-host-blocks: fixture-writer/words [
	1 0 1 2 0 0 0 0
	2 0 3 1 0 0 0 0
	2 0 4 1 0 0 0 0
]
cross-host-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0
		schema/WIRE_EFFECT_FLAG_CONTROL schema/WIRE_ALIAS_KIND_NONE 0 0
]
cross-host-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
]
cross-host-calls: fixture-writer/words reduce [
	1 2 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
]
cross-host-descriptors: fixture-writer/words [2 6 2 2 1 1 0 0]
cross-host-members: fixture-writer/words [1 2]
cross-host-message: build-subroutine-message-with-host
	cross-host-functions cross-host-symbols cross-host-descriptors cross-host-members
	cross-host-blocks #{} subroutine-values cross-host-instructions
	cross-host-operands cross-host-calls
cross-host-operand-offset: select
	(subroutine-section cross-host-message schema/WIRE_RSIR_SECTION_OPERANDS)
	'payload-offset
add-subroutine-semantic-error 'BAD-SUBROUTINE-CALLEE
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALLEE
	(cross-host-operand-offset + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
	(select (subroutine-section cross-host-message
		schema/WIRE_RSIR_SECTION_OPERANDS) 'ordinal) cross-host-message

; A signature-compatible cycle across distinct subroutines remains valid; the
; direct self-recursion case below is the only recursion rejected in v1.
; The call-ABI layer is chained as a nested protocol and must retain its error
; tuple when it rejects before this layer can inspect subroutine sections.
find-call-subroutine-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-call-abis [
		if fixture/1 = name [return fixture]
	]
	assert-subroutine false rejoin ["missing nested call fixture " form name]
]
nested-call-fixture: find-call-subroutine-fixture 'BAD-CALL-SECTION-FLAGS
add-subroutine-error 'INVALID-CALL-ABI
	schema/WIRE_SUBROUTINE_ERROR_INVALID_CALL_ABI
	nested-call-fixture/2 nested-call-fixture/3 nested-call-fixture/4
	nested-call-fixture/5 nested-call-fixture/6 nested-call-fixture/7
	nested-call-fixture/8 nested-call-fixture/9 nested-call-fixture/10
	nested-call-fixture/11 nested-call-fixture/12 nested-call-fixture/13
	nested-call-fixture/14 nested-call-fixture/15 nested-call-fixture/16

; Section and scalar framing errors are owned by this layer.
bad: copy subroutine-message
fixture-mutations/put-u32 bad
	subroutine-directory-flags-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINES
	schema/WIRE_SECTION_FLAG_SORTED
add-subroutine-semantic-error 'BAD-SUBROUTINE-SECTION-FLAGS
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SECTION_FLAGS
	(subroutine-directory-flags-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINES)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	subroutine-directory-flags-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
	schema/WIRE_SECTION_FLAG_SORTED
add-subroutine-semantic-error 'BAD-BLOCK-MEMBER-SECTION-FLAGS
	schema/WIRE_SUBROUTINE_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS
	(subroutine-directory-flags-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-bytes bad
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINES
		schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET) #{00000080}
add-subroutine-semantic-error 'SUBROUTINE-SCALAR-RANGE
	schema/WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINES
		schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-bytes bad
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) #{00000080}
add-subroutine-semantic-error 'MEMBER-SCALAR-RANGE
	schema/WIRE_SUBROUTINE_ERROR_SCALAR_RANGE
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) bad

bad: copy subroutine-message
descriptor-base: select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES)
	'payload-offset
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET) 0
add-subroutine-semantic-error 'BAD-SUBROUTINE-FUNCTION
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_FUNCTION
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_FUNCTION_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET) 1
add-subroutine-semantic-error 'BAD-SUBROUTINE-NAME
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_NAME
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET) 1
add-subroutine-semantic-error 'BAD-SUBROUTINE-SIGNATURE
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SIGNATURE
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET) 1
add-subroutine-semantic-error 'BAD-SUBROUTINE-ENTRY
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ENTRY
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_BLOCK_MEMBER_COUNT_OFFSET) 0
add-subroutine-semantic-error 'BAD-SUBROUTINE-BLOCK-RANGE
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_BLOCK_RANGE
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_FIRST_BLOCK_MEMBER_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET) 0
add-subroutine-semantic-error 'BAD-SUBROUTINE-MEMBER
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_SUBROUTINE_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) 3
fixture-mutations/put-u32 bad
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
		+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) 2
add-subroutine-semantic-error 'BAD-SUBROUTINE-MEMBER-ORDER
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_MEMBER_ORDER
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS
		schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
		+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET) 1
add-subroutine-semantic-error 'BAD-SUBROUTINE-SOURCE-LOCATION
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_SOURCE_LOCATION
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_SOURCE_LOCATION_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET) 1
add-subroutine-semantic-error 'NONZERO-SUBROUTINE-FLAGS
	schema/WIRE_SUBROUTINE_ERROR_NONZERO_SUBROUTINE_FLAGS
	(descriptor-base + schema/WIRE_RSIR_SUBROUTINE_FLAGS_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

; The second valid descriptor set gives isolated name/order/member duplicates.
two-descriptor-base: select (subroutine-section two-subroutine-message
	schema/WIRE_RSIR_SECTION_SUBROUTINES) 'payload-offset
two-member-base: select (subroutine-section two-subroutine-message
	schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'payload-offset
bad: copy two-subroutine-message
fixture-mutations/put-u32 bad
	(two-descriptor-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET
		+ schema/WIRE_RSIR_SUBROUTINE_SIZE) 6
add-subroutine-semantic-error 'DUPLICATE-SUBROUTINE-NAME
	schema/WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_NAME
	(two-descriptor-base + schema/WIRE_RSIR_SUBROUTINE_NAME_STRING_OFFSET
		+ schema/WIRE_RSIR_SUBROUTINE_SIZE)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy two-subroutine-message
fixture-mutations/put-u32 bad
	(two-descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
		+ schema/WIRE_RSIR_SUBROUTINE_SIZE) 2
fixture-mutations/put-u32 bad
	(two-member-base + schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE) 2
add-subroutine-semantic-error 'BAD-SUBROUTINE-ORDER
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_ORDER
	(two-descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
		+ schema/WIRE_RSIR_SUBROUTINE_SIZE)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

bad: copy two-subroutine-message
fixture-mutations/put-u32 bad
	(two-member-base + schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
		+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET) 2
add-subroutine-semantic-error 'DUPLICATE-SUBROUTINE-MEMBER
	schema/WIRE_SUBROUTINE_ERROR_DUPLICATE_SUBROUTINE_MEMBER
	(two-member-base + schema/WIRE_RSIR_SUBROUTINE_BLOCK_SIZE
		+ schema/WIRE_RSIR_SUBROUTINE_BLOCK_BLOCK_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS) 'ordinal) bad

; Cross-region ordinary edges are rejected after both control endpoints are valid.
bad: copy subroutine-message
operand-base: select
	(subroutine-section subroutine-message schema/WIRE_RSIR_SECTION_OPERANDS)
	'payload-offset
fixture-mutations/put-u32 bad
	((operand-base + ((3 - 1) * schema/WIRE_RSIR_OPERAND_SIZE))
		+ schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 4
edge-base: select
	(subroutine-section subroutine-message schema/WIRE_RSIR_SECTION_EDGES)
	'payload-offset
fixture-mutations/put-u32 bad
	(edge-base + schema/WIRE_RSIR_EDGE_SIZE
		+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) 4
add-subroutine-semantic-error 'BAD-SUBROUTINE-EDGE
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_EDGE
	(edge-base + schema/WIRE_RSIR_EDGE_SIZE
		+ schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_EDGES) 'ordinal) bad

; A SUBROUTINE_RETURN in host-main is structurally valid but semantically owned
; by no subroutine.
bad: copy subroutine-message
instruction-base: select (subroutine-section bad schema/WIRE_RSIR_SECTION_INSTRUCTIONS)
	'payload-offset
fixture-mutations/put-u32 bad
	((instruction-base + ((5 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE))
		+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	schema/WIRE_OPCODE_SUBROUTINE_RETURN
add-subroutine-semantic-error 'BAD-SUBROUTINE-RETURN
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
	((instruction-base + ((5 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE))
		+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_INSTRUCTIONS) 'ordinal) bad

; The control layer permits a zero- or one-value SUBROUTINE_RETURN shape. The
; subroutine signature selects the exact shape and type.
bad: copy typed-subroutine-message
typed-descriptor-offset: select
	(subroutine-section typed-subroutine-message schema/WIRE_RSIR_SECTION_SUBROUTINES)
	'payload-offset
typed-instruction-offset: select
	(subroutine-section typed-subroutine-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS)
	'payload-offset
fixture-mutations/put-u32 bad
	(typed-descriptor-offset + schema/WIRE_RSIR_SUBROUTINE_SIGNATURE_OFFSET) 2
add-subroutine-semantic-error 'BAD-TYPED-SUBROUTINE-RETURN
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_RETURN
	((typed-instruction-offset + (schema/WIRE_RSIR_INSTRUCTION_SIZE * 2))
		+ schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_INSTRUCTIONS) 'ordinal) bad

bad: copy subroutine-message
fixture-mutations/put-u32 bad
	((instruction-base + ((4 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE))
		+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	schema/WIRE_OPCODE_UNREACHABLE
add-subroutine-semantic-error 'MISSING-SUBROUTINE-RETURN
	schema/WIRE_SUBROUTINE_ERROR_MISSING_SUBROUTINE_RETURN
	descriptor-base + schema/WIRE_RSIR_SUBROUTINE_ENTRY_BLOCK_OFFSET
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_SUBROUTINES) 'ordinal) bad

; A different zero-parameter void signature is ABI-valid, but does not match
; the descriptor's declared signature.
bad: copy subroutine-message
fixture-mutations/put-u32 bad
	((select (subroutine-section bad schema/WIRE_RSIR_SECTION_CALLS) 'payload-offset)
		+ schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET) 3
add-subroutine-semantic-error 'BAD-SUBROUTINE-CALL
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_CALL
	((select (subroutine-section bad schema/WIRE_RSIR_SECTION_CALLS) 'payload-offset)
		+ schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET)
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_CALLS) 'ordinal) bad

; A subroutine operand is not a general value/address operand.
bad: copy subroutine-message
bad-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 2 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 3 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_KEEPALIVE 0 0 0 0 4 1 0 schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
bad-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
]
bad-blocks: fixture-writer/words [
	1 0 1 2 1 1 0 0
	1 0 3 1 2 1 0 0
	1 0 4 1 0 0 0 0
	1 0 5 2 0 0 0 0
]
bad: build-subroutine-message subroutine-descriptors subroutine-members
	bad-blocks subroutine-edges subroutine-values bad-instructions bad-operands
	subroutine-calls
add-subroutine-semantic-error 'BAD-SUBROUTINE-OPERAND
	schema/WIRE_SUBROUTINE_ERROR_BAD_SUBROUTINE_OPERAND
	(subroutine-offset bad schema/WIRE_RSIR_SECTION_OPERANDS
		(schema/WIRE_RSIR_OPERAND_KIND_OFFSET
			+ (schema/WIRE_RSIR_OPERAND_SIZE * 3)))
	(select (subroutine-section bad schema/WIRE_RSIR_SECTION_OPERANDS) 'ordinal) bad

; Direct self recursion is rejected; mutual calls remain permitted by contract.
self-blocks: fixture-writer/words [
	1 0 1 1 1 1 0 0
	1 0 2 2 2 1 0 0
	1 0 4 1 0 0 0 0
	1 0 5 1 0 0 0 0
]
self-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 1 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CALL 0 0 0 0 2 1 subroutine-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 3 1 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 schema/WIRE_EFFECT_FLAG_CONTROL
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
self-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
]
self-calls: fixture-writer/words reduce [2 2 schema/WIRE_CALL_KIND_SUBROUTINE 2 0 0 0 0]
self: build-subroutine-message subroutine-descriptors subroutine-members
	self-blocks subroutine-edges subroutine-values self-instructions self-operands
	self-calls
add-subroutine-semantic-error 'RECURSIVE-SUBROUTINE-CALL
	schema/WIRE_SUBROUTINE_ERROR_RECURSIVE_SUBROUTINE_CALL
	(subroutine-offset self schema/WIRE_RSIR_SECTION_OPERANDS
		schema/WIRE_RSIR_OPERAND_SIZE + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
	(select (subroutine-section self schema/WIRE_RSIR_SECTION_OPERANDS) 'ordinal) self

foreach fixture malformed-subroutines [
	result: subroutine-verifier/verify fixture/17
	assert-subroutine (to logic! all [
		not result/valid?
		result/error = fixture/2
		result/call-abi-error = fixture/3
		result/control-flow-error = fixture/4
		result/scalar-operation-error = fixture/5
		result/container-error = fixture/6
		result/string-error = fixture/7
		result/file-source-error = fixture/8
		result/data-layout-error = fixture/9
		result/type-layout-error = fixture/10
		result/function-signature-error = fixture/11
		result/module-lifecycle-error = fixture/12
		result/symbol-linkage-error = fixture/13
		result/constant-initializer-error = fixture/14
		result/error-offset = fixture/15
		result/error-section = fixture/16
	]) rejoin [
		form fixture/1 " mismatch: got " result/error "@"
		result/error-offset ":" result/error-section " expected "
		fixture/2 "@" fixture/15 ":" fixture/16
	]
	assert-subroutine to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants none? result/scalar-view
		none? result/control-view none? result/call-view none? result/view
	] rejoin [form fixture/1 " published output views on failure"]
]

result: subroutine-verifier/verify none
assert-subroutine to logic! all [
	not result/valid?
	result/error = schema/WIRE_SUBROUTINE_ERROR_INVALID_ARGUMENTS
	result/call-abi-error = schema/WIRE_CALL_ABI_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/header
	none? result/view
] "non-binary subroutine input did not fail atomically"

covered-errors: reduce [
	schema/WIRE_SUBROUTINE_ERROR_SUCCESS
	schema/WIRE_SUBROUTINE_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-subroutines [append covered-errors fixture/2]
repeat code 27 [
	assert-subroutine not none? find covered-errors (code - 1)
		rejoin ["subroutine error code not covered: " code - 1]
]

result: subroutine-verifier/verify mutual-subroutine-message
assert-subroutine result/valid? "mutual subroutine module failed after malformed corpus"

unless value? 'generating-wire-subroutine-fixtures? [
	source-bytes: make binary! 8'388'608
	foreach source-file [
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
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-subroutine-reds-test.reds
	assert-subroutine not none? find generated-source source-digest
		"generated Red/System subroutine fixtures are stale"
]

print [
	"PASS: Red RSIR subroutines=" result/view/subroutine-count
	" members=" result/view/block-member-count
	" valid=" length? valid-subroutines
	" malformed=" length? malformed-subroutines
]
