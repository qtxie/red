Red [
	Title: "Hybrid compiler RSIR memory and aggregate operation tests"
]

do %wire-scalar-operation-test.red
do %../../../compiler/wire-memory-aggregate.red

memory-verifier: compiler-wire-memory-aggregate

memory-strings: make-canonical-strings [
	"" "dst" "fn" "gi" "gs" "i" "lh" "li" "lp" "ls" "lt" "lu"
	"p" "src" "t-i" "t-s" "u-f" "u-i"
]
memory-id: :symbol-string-id

memory-types: fixture-writer/words [
	; void, logic, unsigned tag byte, signed i32, managed i32, f64.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 2
	4 0 8 8 0 0 0 0 0 0
	; pointer i32, pointer u8, c-string.
	5 0 8 8 0 4 0 0 0 1
	5 0 8 8 0 3 0 0 0 1
	5 4 8 8 0 3 0 0 0 1
	; struct {i32, c-string}, raw union {i32, f64}, tagged union {i32, struct}.
	7 0 16 8 0 0 0 1 2 0
	8 0 8 8 0 0 0 3 2 0
	8 2 24 8 0 3 0 5 2 0
	; pointers to the three aggregates, pointer to c-string, pointer f64, function.
	5 0 8 8 0 10 0 0 0 1
	5 0 8 8 0 11 0 0 0 1
	5 0 8 8 0 12 0 0 0 1
	5 0 8 8 0 9 0 0 0 1
	5 0 8 8 0 6 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
]

memory-fields: fixture-writer/words reduce [
	10 memory-id memory-strings "i" 4 0 0 0 0 0
	10 memory-id memory-strings "p" 9 8 0 1 0 0
	11 memory-id memory-strings "u-i" 4 0 0 0 0 0
	11 memory-id memory-strings "u-f" 6 0 0 1 0 0
	12 memory-id memory-strings "t-i" 4 8 0 0 0 0
	12 memory-id memory-strings "t-s" 10 8 0 1 0 0
]

memory-signatures: fixture-writer/words [
	; Red/System, ordinary, void return, no parameters.
	1 0 1 0 0 0 0 0
]

memory-symbols: fixture-writer/words reduce [
	memory-id memory-strings "fn" 1 2 2 1 0 0 0
	memory-id memory-strings "gi" 2 3 1 4 0 0 0
	memory-id memory-strings "gs" 2 3 1 10 0 0 0
]

memory-constants: fixture-writer/words [
	4 1 0 0 0 0 0 0
	5 1 0 0 0 0 0 0
	9 1 0 0 0 0 0 0
	6 1 0 0 0 0 0 0
]

memory-value-values: make block! 512
memory-instruction-values: make block! 1024
memory-operand-values: make block! 768
memory-instruction-ids: make map! 80
memory-next-instruction: 1
memory-next-value: 1
memory-next-operand: 1

add-memory-instruction: func [
	name [word!] opcode effects alias-kind alias-id [integer!]
	operands result-types [block!]
	/local instruction-id first-result first-operand operand-count ordinal
		kind reference auxiliary result-type
][
	instruction-id: memory-next-instruction
	first-result: either empty? result-types [0][memory-next-value]
	first-operand: either empty? operands [0][memory-next-operand]
	operand-count: (length? operands) / 3
	put memory-instruction-ids name instruction-id
	repend memory-instruction-values [
		1 opcode 0 0 first-result length? result-types first-operand operand-count
		effects alias-kind alias-id 0
	]
	foreach [kind reference auxiliary] operands [
		repend memory-operand-values [kind reference auxiliary schema/WIRE_OPERAND_FLAG_NONE]
	]
	ordinal: 0
	foreach result-type result-types [
		repend memory-value-values [
			schema/WIRE_VALUE_DEFINITION_INSTRUCTION instruction-id ordinal
			result-type 1 schema/WIRE_VALUE_FLAG_NONE
		]
		ordinal: ordinal + 1
	]
	memory-next-instruction: memory-next-instruction + 1
	memory-next-value: memory-next-value + length? result-types
	memory-next-operand: memory-next-operand + operand-count
	first-result
]

v-i32: add-memory-instruction 'CONSTANT-I32 schema/WIRE_OPCODE_CONSTANT 0
	schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1 0] [4]
v-handle: add-memory-instruction 'CONSTANT-HANDLE schema/WIRE_OPCODE_CONSTANT 0
	schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 2 0] [5]
v-c-string: add-memory-instruction 'CONSTANT-C-STRING schema/WIRE_OPCODE_CONSTANT 0
	schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 3 0] [9]
v-f64: add-memory-instruction 'CONSTANT-F64 schema/WIRE_OPCODE_CONSTANT 0
	schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 4 0] [6]

v-load-local: add-memory-instruction 'LOAD-LOCAL schema/WIRE_OPCODE_LOAD_LOCAL
	schema/WIRE_EFFECT_FLAG_READ schema/WIRE_ALIAS_KIND_LOCAL 1
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 1 0] [4]
add-memory-instruction 'STORE-LOCAL schema/WIRE_OPCODE_STORE_LOCAL
	schema/WIRE_EFFECT_FLAG_WRITE schema/WIRE_ALIAS_KIND_LOCAL 2 reduce [
		schema/WIRE_OPERAND_KIND_LOCAL 2 0
		schema/WIRE_OPERAND_KIND_VALUE v-i32 0
	][]
v-address-struct: add-memory-instruction 'ADDRESS-LOCAL-STRUCT
	schema/WIRE_OPCODE_ADDRESS_LOCAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 4 0] [13]
v-address-i32: add-memory-instruction 'ADDRESS-LOCAL-I32
	schema/WIRE_OPCODE_ADDRESS_LOCAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 1 0] [7]
v-address-tagged: add-memory-instruction 'ADDRESS-LOCAL-TAGGED
	schema/WIRE_OPCODE_ADDRESS_LOCAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 5 0] [15]
v-address-source: add-memory-instruction 'ADDRESS-LOCAL-SOURCE
	schema/WIRE_OPCODE_ADDRESS_LOCAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 7 0] [13]
v-address-destination: add-memory-instruction 'ADDRESS-LOCAL-DESTINATION
	schema/WIRE_OPCODE_ADDRESS_LOCAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_LOCAL 8 0] [13]

v-load-global: add-memory-instruction 'LOAD-GLOBAL schema/WIRE_OPCODE_LOAD_GLOBAL
	schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_VOLATILE
	schema/WIRE_ALIAS_KIND_GLOBAL 2
	reduce [schema/WIRE_OPERAND_KIND_SYMBOL 2 0] [4]
add-memory-instruction 'STORE-GLOBAL schema/WIRE_OPCODE_STORE_GLOBAL
	schema/WIRE_EFFECT_FLAG_WRITE schema/WIRE_ALIAS_KIND_GLOBAL 2 reduce [
		schema/WIRE_OPERAND_KIND_SYMBOL 2 0
		schema/WIRE_OPERAND_KIND_VALUE v-i32 0
	][]
v-address-global: add-memory-instruction 'ADDRESS-GLOBAL
	schema/WIRE_OPCODE_ADDRESS_GLOBAL 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_SYMBOL 3 0] [13]

v-load-indirect: add-memory-instruction 'LOAD-INDIRECT schema/WIRE_OPCODE_LOAD_INDIRECT
	schema/WIRE_EFFECT_FLAG_READ schema/WIRE_ALIAS_KIND_UNIVERSAL 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-i32 0] [4]
add-memory-instruction 'STORE-INDIRECT schema/WIRE_OPCODE_STORE_INDIRECT
	schema/WIRE_EFFECT_FLAG_WRITE + schema/WIRE_EFFECT_FLAG_VOLATILE
	schema/WIRE_ALIAS_KIND_UNIVERSAL 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-address-i32 0
		schema/WIRE_OPERAND_KIND_VALUE v-i32 0
	][]

v-address-field: add-memory-instruction 'ADDRESS-FIELD schema/WIRE_OPCODE_ADDRESS_FIELD
	0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-struct 1] [7]
v-build-struct: add-memory-instruction 'AGGREGATE-BUILD-STRUCT
	schema/WIRE_OPCODE_AGGREGATE_BUILD 0 schema/WIRE_ALIAS_KIND_NONE 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-i32 1
		schema/WIRE_OPERAND_KIND_VALUE v-c-string 2
	][10]
v-build-raw-union: add-memory-instruction 'AGGREGATE-BUILD-RAW-UNION
	schema/WIRE_OPCODE_AGGREGATE_BUILD 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f64 4] [11]
v-build-tagged-union: add-memory-instruction 'AGGREGATE-BUILD-TAGGED-UNION
	schema/WIRE_OPCODE_AGGREGATE_BUILD 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-build-struct 6] [12]
v-copy-aggregate: add-memory-instruction 'AGGREGATE-COPY
	schema/WIRE_OPCODE_AGGREGATE_COPY
	schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_WRITE
	schema/WIRE_ALIAS_KIND_UNIVERSAL 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-address-destination 0
		schema/WIRE_OPERAND_KIND_VALUE v-address-source 0
	][13]

v-union-tag: add-memory-instruction 'LOAD-UNION-TAG
	schema/WIRE_OPCODE_LOAD_UNION_TAG
	schema/WIRE_EFFECT_FLAG_READ + schema/WIRE_EFFECT_FLAG_VOLATILE
	schema/WIRE_ALIAS_KIND_UNIVERSAL 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-tagged 0] [3]
add-memory-instruction 'SET-UNION-VARIANT schema/WIRE_OPCODE_SET_UNION_VARIANT
	schema/WIRE_EFFECT_FLAG_WRITE + schema/WIRE_EFFECT_FLAG_VOLATILE
	schema/WIRE_ALIAS_KIND_UNIVERSAL 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-tagged 6] []
v-address-tagged-field: add-memory-instruction 'ADDRESS-TAGGED-FIELD
	schema/WIRE_OPCODE_ADDRESS_FIELD 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-tagged 6] [13]
v-address-nested-field: add-memory-instruction 'ADDRESS-NESTED-FIELD
	schema/WIRE_OPCODE_ADDRESS_FIELD 0 schema/WIRE_ALIAS_KIND_NONE 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-address-tagged-field 1] [7]

memory-values: fixture-writer/words memory-value-values
memory-instructions: fixture-writer/words memory-instruction-values
memory-operands: fixture-writer/words memory-operand-values

memory-functions: fixture-writer/words reduce [
	1 1 0 1 1 1 1 8 0 0
]
memory-locals: fixture-writer/words reduce [
	1 memory-id memory-strings "li" 4 2 0 0 0 0
	1 memory-id memory-strings "lh" 5 2 0 0 0 1
	1 memory-id memory-strings "lp" 7 2 0 0 0 2
	1 memory-id memory-strings "ls" 10 2 0 0 0 3
	1 memory-id memory-strings "lt" 12 2 0 0 0 4
	1 memory-id memory-strings "lu" 11 2 0 0 0 5
	1 memory-id memory-strings "src" 10 2 0 0 0 6
	1 memory-id memory-strings "dst" 10 2 0 0 0 7
]
memory-blocks: fixture-writer/words reduce [
	1 0 1 memory-next-instruction - 1 0 0 0 0
]
memory-globals: fixture-writer/words [
	2 4 0 0 1 0 0 0
	3 10 0 0 1 0 0 0
]

; Add the common operation sections that are outside the constant-layer builder.
build-memory-message: func [
	value-records instruction-records operand-records [binary!]
	/local payloads sections
][
	payloads: make map! 80
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS memory-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA memory-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES memory-types
	put payloads schema/WIRE_RSIR_SECTION_FIELDS memory-fields
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES memory-signatures
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS memory-symbols
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS memory-constants
	put payloads schema/WIRE_RSIR_SECTION_GLOBALS memory-globals
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS memory-functions
	put payloads schema/WIRE_RSIR_SECTION_LOCALS memory-locals
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS memory-blocks
	put payloads schema/WIRE_RSIR_SECTION_VALUES value-records
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instruction-records
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operand-records
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

rich-memory-message: build-memory-message memory-values memory-instructions memory-operands

memory-values-section:
	scalar-section rich-memory-message schema/WIRE_RSIR_SECTION_VALUES
memory-instructions-section:
	scalar-section rich-memory-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
memory-operands-section:
	scalar-section rich-memory-message schema/WIRE_RSIR_SECTION_OPERANDS

memory-instruction-id: func [name [word!]][select memory-instruction-ids name]

memory-instruction-field: func [name [word!] field [integer!]][
	scalar-record-value rich-memory-message memory-instructions-section
		memory-instruction-id name schema/WIRE_RSIR_INSTRUCTION_SIZE field
]

malformed-memory-aggregates: make block! 2048
add-malformed-memory-aggregate: func [
	name [word!] expected-error expected-scalar expected-container expected-string
	expected-file expected-layout expected-type expected-function expected-module
	expected-symbol expected-constant expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-memory-aggregates reduce [
		name expected-error expected-scalar expected-container expected-string
		expected-file expected-layout expected-type expected-function expected-module
		expected-symbol expected-constant expected-offset expected-section data
	]
]

add-memory-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-memory-aggregate name expected-error
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
add-malformed-memory-aggregate 'INVALID-SCALAR-OPERATION
	schema/WIRE_MEMORY_AGGREGATE_ERROR_INVALID_SCALAR_OPERATION
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14

mutate-memory-record: func [
	name [word!] section [map!] id record-size field value
	expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-memory-message
	base: scalar-record-offset section id record-size
	fixture-mutations/put-u32 bad (base + field) value
	add-memory-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

mutate-memory-instruction: func [
	name instruction-name [word!] field value expected-error expected-field [integer!]
][
	mutate-memory-record name memory-instructions-section
		memory-instruction-id instruction-name schema/WIRE_RSIR_INSTRUCTION_SIZE
		field value expected-error expected-field
]

mutate-memory-value: func [
	name [word!] value-id field value expected-error expected-field [integer!]
][
	mutate-memory-record name memory-values-section value-id schema/WIRE_RSIR_VALUE_SIZE
		field value expected-error expected-field
]

mutate-memory-operand: func [
	name [word!] operand-id field value expected-error expected-field [integer!]
][
	mutate-memory-record name memory-operands-section operand-id schema/WIRE_RSIR_OPERAND_SIZE
		field value expected-error expected-field
]

load-local-operand: memory-instruction-field 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
load-global-operand: memory-instruction-field 'LOAD-GLOBAL
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
load-indirect-operand: memory-instruction-field 'LOAD-INDIRECT
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
address-field-operand: memory-instruction-field 'ADDRESS-FIELD
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
build-struct-operand: memory-instruction-field 'AGGREGATE-BUILD-STRUCT
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
copy-aggregate-operand: memory-instruction-field 'AGGREGATE-COPY
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
load-union-tag-operand: memory-instruction-field 'LOAD-UNION-TAG
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
set-union-variant-operand: memory-instruction-field 'SET-UNION-VARIANT
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET

; Instruction domains and exact common shapes.
mutate-memory-instruction 'BAD-SUBOPCODE 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-memory-instruction 'BAD-INSTRUCTION-FLAGS 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET schema/WIRE_INSTRUCTION_FLAG_CHECKED
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_INSTRUCTION_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-memory-instruction 'BAD-EFFECTS 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-memory-instruction 'BAD-ALIAS 'AGGREGATE-BUILD-STRUCT
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_UNIVERSAL
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET
mutate-memory-instruction 'BAD-OPERAND-COUNT 'AGGREGATE-COPY
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_ADDRESS_LOCAL
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
mutate-memory-instruction 'BAD-RESULT-COUNT 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_STORE_LOCAL
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_RESULT_COUNT
	schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
mutate-memory-operand 'BAD-OPERAND-KIND load-local-operand
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET schema/WIRE_OPERAND_KIND_VALUE
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_OPERAND_KIND
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-memory-operand 'NONZERO-OPERAND-AUXILIARY load-local-operand
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_MEMORY_AGGREGATE_ERROR_NONZERO_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET

; Typed local, global, indirect, and field access.
mutate-memory-value 'TYPE-MISMATCH v-load-local
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 6
	schema/WIRE_MEMORY_AGGREGATE_ERROR_TYPE_MISMATCH
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-memory-value 'BAD-ADDRESS-RESULT-TYPE v-address-struct
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 14
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_ADDRESS_RESULT_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-memory-instruction 'BAD-LOCAL-ALIAS 'LOAD-LOCAL
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET 2
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_LOCAL_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
mutate-memory-operand 'BAD-GLOBAL-SYMBOL load-global-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_SYMBOL
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-memory-instruction 'BAD-GLOBAL-ALIAS 'LOAD-GLOBAL
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET 3
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_GLOBAL_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET
mutate-memory-operand 'BAD-INDIRECT-ADDRESS-TYPE load-indirect-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-i32
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_INDIRECT_ADDRESS_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-memory-operand 'BAD-FIELD-REFERENCE address-field-operand
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 0
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_REFERENCE
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-memory-operand 'BAD-FIELD-OWNER address-field-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-address-tagged
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_OWNER
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-memory-value 'BAD-FIELD-RESULT-TYPE v-address-field
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 16
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_FIELD_RESULT_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

; Aggregate construction and overlap-safe memory copy.
mutate-memory-value 'BAD-AGGREGATE-TYPE v-build-struct
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 4
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
bad: copy rich-memory-message
base: scalar-record-offset memory-values-section v-build-struct
	schema/WIRE_RSIR_VALUE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_VALUE_TYPE_OFFSET) 12
base: scalar-record-offset memory-instructions-section
	(memory-instruction-id 'AGGREGATE-BUILD-STRUCT)
	schema/WIRE_RSIR_INSTRUCTION_SIZE
add-memory-semantic-error 'BAD-AGGREGATE-FIELD-COUNT
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_COUNT
	(base + schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET)
	(select memory-instructions-section 'ordinal) bad
mutate-memory-operand 'BAD-AGGREGATE-FIELD-ORDER build-struct-operand
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 2
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_ORDER
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-memory-operand 'BAD-AGGREGATE-FIELD-TYPE build-struct-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-f64
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_FIELD_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-memory-operand 'BAD-AGGREGATE-COPY-TYPE (copy-aggregate-operand + 1)
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-address-tagged
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_AGGREGATE_COPY_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

; Explicit tagged-union state operations.
mutate-memory-operand 'BAD-UNION-TYPE load-union-tag-operand
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET v-address-struct
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-memory-value 'BAD-UNION-TAG-TYPE v-union-tag
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET 4
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_TAG_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-memory-operand 'BAD-UNION-VARIANT set-union-variant-operand
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 4
	schema/WIRE_MEMORY_AGGREGATE_ERROR_BAD_UNION_VARIANT
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET

valid-memory-aggregates: reduce [
	reduce ['EMPTY empty-constant-message]
	reduce ['RICH rich-memory-message]
]

foreach fixture valid-memory-aggregates [
	result: memory-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid memory module rejected with error " result/error
		" scalar=" result/scalar-operation-error
		" at " result/error-offset ":" result/error-section
	]
]

result: memory-verifier/verify rich-memory-message
assert to logic! all [
	result/error = schema/WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
	result/view/value-count = (memory-next-value - 1)
	result/view/instruction-count = (memory-next-instruction - 1)
	result/view/operand-count = (memory-next-operand - 1)
	result/types/type-count = 18
	result/types/field-count = 6
	result/functions/local-count = 8
	result/symbols/global-count = 2
]["rich memory view changed"]

result: memory-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS
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
]["non-binary memory input did not fail atomically"]

covered-errors: make block! 64
append covered-errors schema/WIRE_MEMORY_AGGREGATE_ERROR_SUCCESS
append covered-errors schema/WIRE_MEMORY_AGGREGATE_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-memory-aggregates [
	result: memory-verifier/verify fixture/15
	assert not result/valid? [fixture/1 " malformed memory module was accepted"]
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

repeat code 28 [
	assert not none? find covered-errors (code - 1) [
		"memory/aggregate error code not covered: " code - 1
	]
]

unless value? 'generating-wire-memory-aggregate-fixtures? [
	source-bytes: make binary! 4'194'304
	foreach source-file [
		%wire-memory-aggregate-test.red
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
		%../generate-wire-memory-aggregate-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-memory-aggregate-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System memory/aggregate fixtures are stale"
]

print [
	"PASS: Red RSIR memory and aggregate verifier values="
	(memory-next-value - 1) " instructions=" (memory-next-instruction - 1)
	" operands=" (memory-next-operand - 1)
	" malformed=" length? malformed-memory-aggregates
]
