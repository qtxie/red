Red [
	Title: "Hybrid compiler RSIR atomic operation tests"
]

do %wire-scalar-operation-test.red
do %../../../compiler/wire-atomic.red

atomic-verifier: compiler-wire-atomic

atomic-strings: make-canonical-strings ["" "fn"]
atomic-id: :symbol-string-id

atomic-types: fixture-writer/words [
	; void, logic, signed i32, unsigned i32, and ordinary pointers to both integers.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 0 4 4 0 0 0 0 0 0
	5 0 8 8 0 3 0 0 0 1
	5 0 8 8 0 4 0 0 0 1
]

atomic-signatures: fixture-writer/words [
	; Red/System, ordinary, void return, no parameters.
	1 0 1 0 0 0 0 0
]

atomic-symbols: fixture-writer/words reduce [
	atomic-id atomic-strings "fn" 1 2 2 1 0 0 0
]

atomic-constants: fixture-writer/words [
	5 1 0 0 0 0 0 0
	3 1 0 0 0 0 0 0
	2 1 0 0 0 0 0 0
	4 1 0 0 0 0 0 0
	6 1 0 0 0 0 0 0
]

atomic-value-values: make block! 384
atomic-instruction-values: make block! 768
atomic-operand-values: make block! 512
atomic-instruction-ids: make map! 80
atomic-next-instruction: 1
atomic-next-value: 1
atomic-next-operand: 1

add-atomic-record: func [
	name [word!] opcode subopcode flags effects alias-kind [integer!]
	operands result-types [block!]
	/local instruction-id first-result first-operand operand-count ordinal
		kind reference auxiliary result-type
][
	instruction-id: atomic-next-instruction
	first-result: either empty? result-types [0][atomic-next-value]
	first-operand: either empty? operands [0][atomic-next-operand]
	operand-count: (length? operands) / 3
	put atomic-instruction-ids name instruction-id
	repend atomic-instruction-values [
		1 opcode subopcode flags first-result length? result-types
		first-operand operand-count effects alias-kind 0 0
	]
	foreach [kind reference auxiliary] operands [
		repend atomic-operand-values [
			kind reference auxiliary schema/WIRE_OPERAND_FLAG_NONE
		]
	]
	ordinal: 0
	foreach result-type result-types [
		repend atomic-value-values [
			schema/WIRE_VALUE_DEFINITION_INSTRUCTION instruction-id ordinal
			result-type 1 schema/WIRE_VALUE_FLAG_NONE
		]
		ordinal: ordinal + 1
	]
	atomic-next-instruction: atomic-next-instruction + 1
	atomic-next-value: atomic-next-value + length? result-types
	atomic-next-operand: atomic-next-operand + operand-count
	first-result
]

add-atomic-instruction: func [
	name [word!] opcode subopcode flags [integer!] operands result-types [block!]
	/local effects
][
	effects: case [
		opcode = schema/WIRE_OPCODE_ATOMIC_LOAD [
			schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_ATOMIC
		]
		opcode = schema/WIRE_OPCODE_ATOMIC_STORE [
			schema/WIRE_EFFECT_FLAG_WRITE + schema/WIRE_EFFECT_FLAG_ATOMIC
		]
		find reduce [
			schema/WIRE_OPCODE_ATOMIC_RMW
			schema/WIRE_OPCODE_ATOMIC_CAS
		] opcode [
			schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_WRITE
				+ schema/WIRE_EFFECT_FLAG_ATOMIC
		]
		true [schema/WIRE_EFFECT_FLAG_ATOMIC]
	]
	add-atomic-record name opcode subopcode flags effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL operands result-types
]

v-pointer-i32: add-atomic-record 'CONSTANT-POINTER-I32
	schema/WIRE_OPCODE_CONSTANT 0 0 0 schema/WIRE_ALIAS_KIND_NONE
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1 0] [5]
v-i32: add-atomic-record 'CONSTANT-I32
	schema/WIRE_OPCODE_CONSTANT 0 0 0 schema/WIRE_ALIAS_KIND_NONE
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 2 0] [3]
v-logic: add-atomic-record 'CONSTANT-LOGIC
	schema/WIRE_OPCODE_CONSTANT 0 0 0 schema/WIRE_ALIAS_KIND_NONE
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 3 0] [2]
v-u32: add-atomic-record 'CONSTANT-U32
	schema/WIRE_OPCODE_CONSTANT 0 0 0 schema/WIRE_ALIAS_KIND_NONE
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 4 0] [4]
v-pointer-u32: add-atomic-record 'CONSTANT-POINTER-U32
	schema/WIRE_OPCODE_CONSTANT 0 0 0 schema/WIRE_ALIAS_KIND_NONE
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 5 0] [6]

atomic-address: reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32 0]
atomic-address-value: reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32 0
	schema/WIRE_OPERAND_KIND_VALUE v-i32 0
]
atomic-cas-operands: reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32 0
	schema/WIRE_OPERAND_KIND_VALUE v-i32 0
	schema/WIRE_OPERAND_KIND_VALUE v-i32 0
]

; Every legal load and store order.
v-load-relaxed: add-atomic-instruction 'LOAD-RELAXED schema/WIRE_OPCODE_ATOMIC_LOAD 0
	schema/WIRE_ATOMIC_ORDER_RELAXED atomic-address [3]
add-atomic-instruction 'LOAD-ACQUIRE schema/WIRE_OPCODE_ATOMIC_LOAD 0
	schema/WIRE_ATOMIC_ORDER_ACQUIRE atomic-address [3]
add-atomic-instruction 'LOAD-SEQUENTIAL schema/WIRE_OPCODE_ATOMIC_LOAD 0
	schema/WIRE_ATOMIC_ORDER_SEQUENTIAL atomic-address [3]
add-atomic-instruction 'STORE-RELAXED schema/WIRE_OPCODE_ATOMIC_STORE 0
	schema/WIRE_ATOMIC_ORDER_RELAXED atomic-address-value []
add-atomic-instruction 'STORE-RELEASE schema/WIRE_OPCODE_ATOMIC_STORE 0
	schema/WIRE_ATOMIC_ORDER_RELEASE atomic-address-value []
add-atomic-instruction 'STORE-SEQUENTIAL schema/WIRE_OPCODE_ATOMIC_STORE 0
	schema/WIRE_ATOMIC_ORDER_SEQUENTIAL atomic-address-value []

; All RMW operation IDs and all orders. Results cover new, old, and unused forms.
add-atomic-instruction 'RMW-ADD schema/WIRE_OPCODE_ATOMIC_RMW
	schema/WIRE_ATOMIC_RMW_OPERATION_ADD schema/WIRE_ATOMIC_ORDER_RELAXED
	atomic-address-value []
add-atomic-instruction 'RMW-SUBTRACT schema/WIRE_OPCODE_ATOMIC_RMW
	schema/WIRE_ATOMIC_RMW_OPERATION_SUBTRACT schema/WIRE_ATOMIC_ORDER_ACQUIRE
	atomic-address-value [3]
add-atomic-instruction 'RMW-BIT-AND schema/WIRE_OPCODE_ATOMIC_RMW
	schema/WIRE_ATOMIC_RMW_OPERATION_BIT_AND
	(schema/WIRE_ATOMIC_ORDER_RELEASE + schema/WIRE_ATOMIC_FLAG_RETURN_OLD)
	atomic-address-value [3]
add-atomic-instruction 'RMW-BIT-OR schema/WIRE_OPCODE_ATOMIC_RMW
	schema/WIRE_ATOMIC_RMW_OPERATION_BIT_OR schema/WIRE_ATOMIC_ORDER_ACQUIRE_RELEASE
	atomic-address-value []
add-atomic-instruction 'RMW-BIT-XOR schema/WIRE_OPCODE_ATOMIC_RMW
	schema/WIRE_ATOMIC_RMW_OPERATION_BIT_XOR schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
	atomic-address-value [3]

; CAS accepts every order and may omit its success result.
add-atomic-instruction 'CAS-RELAXED schema/WIRE_OPCODE_ATOMIC_CAS 0
	schema/WIRE_ATOMIC_ORDER_RELAXED atomic-cas-operands []
add-atomic-instruction 'CAS-ACQUIRE schema/WIRE_OPCODE_ATOMIC_CAS 0
	schema/WIRE_ATOMIC_ORDER_ACQUIRE atomic-cas-operands [2]
add-atomic-instruction 'CAS-RELEASE schema/WIRE_OPCODE_ATOMIC_CAS 0
	schema/WIRE_ATOMIC_ORDER_RELEASE atomic-cas-operands []
add-atomic-instruction 'CAS-ACQUIRE-RELEASE schema/WIRE_OPCODE_ATOMIC_CAS 0
	schema/WIRE_ATOMIC_ORDER_ACQUIRE_RELEASE atomic-cas-operands [2]
add-atomic-instruction 'CAS-SEQUENTIAL schema/WIRE_OPCODE_ATOMIC_CAS 0
	schema/WIRE_ATOMIC_ORDER_SEQUENTIAL atomic-cas-operands [2]

; A relaxed fence is deliberately absent: it is not a legal synchronization event.
foreach [name order] reduce [
	'FENCE-ACQUIRE schema/WIRE_ATOMIC_ORDER_ACQUIRE
	'FENCE-RELEASE schema/WIRE_ATOMIC_ORDER_RELEASE
	'FENCE-ACQUIRE-RELEASE schema/WIRE_ATOMIC_ORDER_ACQUIRE_RELEASE
	'FENCE-SEQUENTIAL schema/WIRE_ATOMIC_ORDER_SEQUENTIAL
][
	add-atomic-instruction name schema/WIRE_OPCODE_ATOMIC_FENCE 0 order [] []
]

atomic-values: fixture-writer/words atomic-value-values
atomic-instructions: fixture-writer/words atomic-instruction-values
atomic-operands: fixture-writer/words atomic-operand-values
atomic-functions: fixture-writer/words [
	1 1 0 1 1 1 0 0 0 0
]
atomic-blocks: fixture-writer/words reduce [
	1 0 1 atomic-next-instruction - 1 0 0 0 0
]

rich-atomic-message: build-scalar-operation-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	atomic-strings/1 atomic-strings/2 atomic-types #{} atomic-signatures #{}
	atomic-symbols atomic-constants atomic-functions #{} atomic-blocks atomic-values
	atomic-instructions atomic-operands #{}

atomic-section: func [data [binary!] kind [integer!]][constant-section data kind]
atomic-values-section:
	atomic-section rich-atomic-message schema/WIRE_RSIR_SECTION_VALUES
atomic-instructions-section:
	atomic-section rich-atomic-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
atomic-operands-section:
	atomic-section rich-atomic-message schema/WIRE_RSIR_SECTION_OPERANDS

atomic-instruction-id: func [name [word!]][select atomic-instruction-ids name]

atomic-instruction-field: func [name [word!] field [integer!]][
	scalar-record-value rich-atomic-message atomic-instructions-section
		atomic-instruction-id name schema/WIRE_RSIR_INSTRUCTION_SIZE field
]

malformed-atomics: make block! 2048
add-malformed-atomic: func [
	name [word!] expected-error expected-scalar expected-container expected-string
	expected-file expected-layout expected-type expected-function expected-module
	expected-symbol expected-constant expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-atomics reduce [
		name expected-error expected-scalar expected-container expected-string
		expected-file expected-layout expected-type expected-function expected-module
		expected-symbol expected-constant expected-offset expected-section data
	]
]

add-atomic-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-atomic name expected-error
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

find-scalar-operation-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-scalar-operations [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested scalar operation fixture " name]
]

nested: find-scalar-operation-fixture 'BAD-SCALAR-SUBOPCODE
add-malformed-atomic 'INVALID-SCALAR-OPERATION
	schema/WIRE_ATOMIC_ERROR_INVALID_SCALAR_OPERATION
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14

mutate-atomic-record: func [
	name [word!] section [map!] id record-size field value
	expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-atomic-message
	base: scalar-record-offset section id record-size
	fixture-mutations/put-u32 bad (base + field) value
	add-atomic-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

mutate-atomic-instruction: func [
	name instruction-name [word!] field value expected-error expected-field [integer!]
][
	mutate-atomic-record name atomic-instructions-section
		atomic-instruction-id instruction-name schema/WIRE_RSIR_INSTRUCTION_SIZE
		field value expected-error expected-field
]

mutate-atomic-value: func [
	name [word!] value-id field value expected-error expected-field [integer!]
][
	mutate-atomic-record name atomic-values-section value-id schema/WIRE_RSIR_VALUE_SIZE
		field value expected-error expected-field
]

mutate-atomic-operand: func [
	name [word!] operand-id field value expected-error expected-field [integer!]
][
	mutate-atomic-record name atomic-operands-section operand-id schema/WIRE_RSIR_OPERAND_SIZE
		field value expected-error expected-field
]

load-relaxed-operand: atomic-instruction-field 'LOAD-RELAXED
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
load-acquire-operand: atomic-instruction-field 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
store-relaxed-operand: atomic-instruction-field 'STORE-RELAXED
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
cas-acquire-operand: atomic-instruction-field 'CAS-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
cas-acquire-result: atomic-instruction-field 'CAS-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET

mutate-atomic-instruction 'BAD-SUBOPCODE 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_ATOMIC_ERROR_BAD_SUBOPCODE schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-atomic-instruction 'BAD-RMW-OPERATION 'RMW-ADD
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 0
	schema/WIRE_ATOMIC_ERROR_BAD_RMW_OPERATION
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-atomic-instruction 'BAD-INSTRUCTION-FLAGS 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 16
	schema/WIRE_ATOMIC_ERROR_BAD_INSTRUCTION_FLAGS schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-ORDER-DOMAIN 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 6
	schema/WIRE_ATOMIC_ERROR_BAD_ORDER schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-LOAD-ORDER 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_ATOMIC_ORDER_RELEASE
	schema/WIRE_ATOMIC_ERROR_BAD_ORDER schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-STORE-ORDER 'STORE-RELAXED
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_ATOMIC_ORDER_ACQUIRE
	schema/WIRE_ATOMIC_ERROR_BAD_ORDER schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-FENCE-ORDER 'FENCE-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_ATOMIC_ORDER_RELAXED
	schema/WIRE_ATOMIC_ERROR_BAD_ORDER schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-NON-RMW-RETURN-MODE 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
	(schema/WIRE_ATOMIC_ORDER_ACQUIRE + schema/WIRE_ATOMIC_FLAG_RETURN_OLD)
	schema/WIRE_ATOMIC_ERROR_BAD_RETURN_MODE schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-UNUSED-RMW-RETURN-MODE 'RMW-ADD
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
	(schema/WIRE_ATOMIC_ORDER_RELAXED + schema/WIRE_ATOMIC_FLAG_RETURN_OLD)
	schema/WIRE_ATOMIC_ERROR_BAD_RETURN_MODE schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET

mutate-atomic-instruction 'BAD-RESULT-COUNT 'LOAD-RELAXED
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_ATOMIC_STORE
	schema/WIRE_ATOMIC_ERROR_BAD_RESULT_COUNT
	schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
mutate-atomic-instruction 'BAD-OPERAND-COUNT 'CAS-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_ATOMIC_LOAD
	schema/WIRE_ATOMIC_ERROR_BAD_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
mutate-atomic-operand 'BAD-OPERAND-KIND (store-relaxed-operand + 1)
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET schema/WIRE_OPERAND_KIND_CONSTANT
	schema/WIRE_ATOMIC_ERROR_BAD_OPERAND_KIND schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-atomic-operand 'NONZERO-OPERAND-AUXILIARY load-acquire-operand
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_ATOMIC_ERROR_NONZERO_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-atomic-operand 'BAD-ADDRESS-TYPE load-acquire-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-pointer-u32
	schema/WIRE_ATOMIC_ERROR_BAD_ADDRESS_TYPE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-atomic-operand 'BAD-VALUE-TYPE (store-relaxed-operand + 1)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-u32
	schema/WIRE_ATOMIC_ERROR_BAD_VALUE_TYPE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-atomic-value 'BAD-LOAD-RESULT-TYPE v-load-relaxed
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 4
	schema/WIRE_ATOMIC_ERROR_BAD_RESULT_TYPE schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-atomic-value 'BAD-CAS-RESULT-TYPE cas-acquire-result
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 3
	schema/WIRE_ATOMIC_ERROR_BAD_RESULT_TYPE schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-atomic-instruction 'BAD-EFFECTS 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET schema/WIRE_EFFECT_FLAG_READ
	schema/WIRE_ATOMIC_ERROR_BAD_EFFECTS schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-atomic-instruction 'BAD-ALIAS-KIND 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_NONE
	schema/WIRE_ATOMIC_ERROR_BAD_ALIAS schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
mutate-atomic-instruction 'BAD-ALIAS-ID 'LOAD-ACQUIRE
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET 1
	schema/WIRE_ATOMIC_ERROR_BAD_ALIAS schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET

valid-atomics: reduce [
	reduce ['EMPTY empty-constant-message]
	reduce ['RICH rich-atomic-message]
]

foreach fixture valid-atomics [
	result: atomic-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid atomic module rejected with error " result/error
		" scalar=" result/scalar-operation-error
		" at " result/error-offset ":" result/error-section
	]
]

result: atomic-verifier/verify rich-atomic-message
assert to logic! all [
	result/error = schema/WIRE_ATOMIC_ERROR_SUCCESS
	result/view/value-count = (atomic-next-value - 1)
	result/view/instruction-count = (atomic-next-instruction - 1)
	result/view/operand-count = (atomic-next-operand - 1)
	result/types/type-count = 6
	result/functions/function-count = 1
]["rich atomic view changed"]

result: atomic-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_ATOMIC_ERROR_INVALID_ARGUMENTS
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
	none? result/view
]["non-binary atomic input did not fail atomically"]

covered-errors: make block! 64
append covered-errors schema/WIRE_ATOMIC_ERROR_SUCCESS
append covered-errors schema/WIRE_ATOMIC_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-atomics [
	result: atomic-verifier/verify fixture/15
	assert not result/valid? [fixture/1 " malformed atomic module was accepted"]
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
		none? result/strings
		none? result/files
		none? result/layout
		none? result/types
		none? result/functions
		none? result/modules
		none? result/symbols
		none? result/constants
		none? result/view
	][fixture/1 " published output views on failure"]
	append covered-errors fixture/2
]

repeat code 17 [
	assert not none? find covered-errors (code - 1) [
		"atomic error code not covered: " code - 1
	]
]

unless value? 'generating-wire-atomic-fixtures? [
	source-bytes: make binary! 4'194'304
	foreach source-file [
		%wire-atomic-test.red
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
		%../generate-wire-atomic-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-atomic-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System atomic fixtures are stale"
]

print [
	"PASS: Red RSIR atomic verifier values=" (atomic-next-value - 1)
	" instructions=" (atomic-next-instruction - 1)
	" operands=" (atomic-next-operand - 1)
	" malformed=" length? malformed-atomics
]
