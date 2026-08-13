Red [
	Title: "Hybrid compiler RSIR scalar value and operation tests"
]

do %wire-constant-initializer-test.red
do %../../../compiler/wire-scalar-operation.red

scalar-operation-verifier: compiler-wire-scalar-operation

build-scalar-operation-message: func [
	module-records string-records string-data type-records field-records
	signature-records parameter-records symbol-records constant-records
	function-records local-records block-records value-records
	instruction-records operand-records target-fragment-records
	/local payloads sections
][
	payloads: make map! 80
	put payloads schema/WIRE_RSIR_SECTION_MODULE module-records
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS string-records
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA string-data
	put payloads schema/WIRE_RSIR_SECTION_TYPES type-records
	put payloads schema/WIRE_RSIR_SECTION_FIELDS field-records
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES signature-records
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS parameter-records
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS symbol-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS constant-records
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS function-records
	put payloads schema/WIRE_RSIR_SECTION_LOCALS local-records
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS block-records
	put payloads schema/WIRE_RSIR_SECTION_VALUES value-records
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instruction-records
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operand-records
	put payloads schema/WIRE_RSIR_SECTION_TARGET_FRAGMENTS target-fragment-records
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
	fixture-writer/build
		schema/WIRE_MAGIC_RSIR
		schema/WIRE_TARGET_X86_64
		schema/WIRE_ABI_WIN64
		schema/WIRE_ENDIAN_LITTLE
		8
		sections
]

scalar-strings: make-canonical-strings ["" "a" "b" "field" "fn" "fn2"]
scalar-id: :symbol-string-id

scalar-types: fixture-writer/words [
	; void, logic, signed/unsigned integers, floats, two pointers, function,
	; managed i32 handle, and a one-field aggregate used by negative tests.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 1 1 0 0 0 0 0 0
	3 0 1 1 0 0 0 0 0 0
	3 1 2 2 0 0 0 0 0 0
	3 0 2 2 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
	3 0 4 4 0 0 0 0 0 0
	3 1 8 8 0 0 0 0 0 0
	3 0 8 8 0 0 0 0 0 0
	4 0 4 4 0 0 0 0 0 0
	4 0 8 8 0 0 0 0 0 0
	5 0 8 8 0 7 0 0 0 1
	5 0 8 8 0 4 0 0 0 1
	6 0 8 8 0 1 0 0 0 1
	3 1 4 4 0 0 0 0 0 2
	7 0 4 4 0 0 0 1 1 0
]
scalar-fields: fixture-writer/words reduce [
	17 scalar-id scalar-strings "field" 7 0 0 0 0 0
]
scalar-signatures: fixture-writer/words [
	; Red/System, ordinary, i32 return, two parameters.
	1 0 7 1 2 2 0 0
]
scalar-parameters: fixture-writer/words reduce [
	1 scalar-id scalar-strings "a" 7 0 0 2 0 0
	1 scalar-id scalar-strings "b" 16 0 1 2 0 0
]
scalar-symbols: fixture-writer/words reduce [
	scalar-id scalar-strings "fn" 1 2 2 1 0 0 0
	scalar-id scalar-strings "fn2" 1 2 2 1 0 0 0
]

scalar-constants-values: make block! 80
foreach type-id [7 2 11 12 13 14 15 8 16][
	repend scalar-constants-values [type-id schema/WIRE_CONSTANT_KIND_ZERO 0 0 0 0 0 0]
]
scalar-constants: fixture-writer/words scalar-constants-values

scalar-value-values: make block! 512
repend scalar-value-values [
	schema/WIRE_VALUE_DEFINITION_PARAMETER 1 0 7 1 0
	schema/WIRE_VALUE_DEFINITION_PARAMETER 2 0 16 1 0
]
scalar-instruction-values: make block! 1024
scalar-operand-values: make block! 512
scalar-instruction-ids: make map! 80
scalar-next-instruction: 1
scalar-next-value: 3
scalar-next-operand: 1

add-scalar-instruction: func [
	name [word!] opcode subopcode flags effects [integer!]
	operands result-types [block!]
	/local instruction-id first-result first-operand operand-count ordinal result-type
][
	instruction-id: scalar-next-instruction
	first-result: either empty? result-types [0][scalar-next-value]
	first-operand: either empty? operands [0][scalar-next-operand]
	operand-count: (length? operands) / 2
	put scalar-instruction-ids name instruction-id
	repend scalar-instruction-values [
		1 opcode subopcode flags first-result length? result-types
		first-operand operand-count effects schema/WIRE_ALIAS_KIND_NONE 0 0
	]
	foreach [kind reference] operands [
		repend scalar-operand-values [kind reference 0 schema/WIRE_OPERAND_FLAG_NONE]
	]
	ordinal: 0
	foreach result-type result-types [
		repend scalar-value-values [
			schema/WIRE_VALUE_DEFINITION_INSTRUCTION instruction-id ordinal
			result-type 1 schema/WIRE_VALUE_FLAG_NONE
		]
		ordinal: ordinal + 1
	]
	scalar-next-instruction: scalar-next-instruction + 1
	scalar-next-value: scalar-next-value + length? result-types
	scalar-next-operand: scalar-next-operand + operand-count
	first-result
]

v-i32: add-scalar-instruction 'CONSTANT-I32 schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 1] [7]
v-logic: add-scalar-instruction 'CONSTANT-LOGIC schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 2] [2]
v-f32: add-scalar-instruction 'CONSTANT-F32 schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 3] [11]
v-f64: add-scalar-instruction 'CONSTANT-F64 schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 4] [12]
v-pointer-i32: add-scalar-instruction 'CONSTANT-POINTER-I32
	schema/WIRE_OPCODE_CONSTANT 0 0 0 reduce [schema/WIRE_OPERAND_KIND_CONSTANT 5] [13]
v-pointer-u8: add-scalar-instruction 'CONSTANT-POINTER-U8
	schema/WIRE_OPCODE_CONSTANT 0 0 0 reduce [schema/WIRE_OPERAND_KIND_CONSTANT 6] [14]
v-function: add-scalar-instruction 'CONSTANT-FUNCTION schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 7] [15]
v-u32: add-scalar-instruction 'CONSTANT-U32 schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 8] [8]
v-handle: add-scalar-instruction 'CONSTANT-HANDLE schema/WIRE_OPCODE_CONSTANT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_CONSTANT 9] [16]
v-copy: add-scalar-instruction 'COPY schema/WIRE_OPCODE_COPY 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [7]
v-convert: add-scalar-instruction 'CONVERT schema/WIRE_OPCODE_CONVERT 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [12]
v-bitcast: add-scalar-instruction 'BITCAST schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [11]
v-add: add-scalar-instruction 'ADD schema/WIRE_OPCODE_ADD 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-i32
	schema/WIRE_OPERAND_KIND_VALUE v-copy
][7]
v-pointer-subtract: add-scalar-instruction 'POINTER-SUBTRACT
	schema/WIRE_OPCODE_SUBTRACT 0 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32
		schema/WIRE_OPERAND_KIND_VALUE v-u32
	][13]
v-multiply: add-scalar-instruction 'MULTIPLY schema/WIRE_OPCODE_MULTIPLY 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-i32
	schema/WIRE_OPERAND_KIND_VALUE v-copy
][7]
v-divide: add-scalar-instruction 'DIVIDE schema/WIRE_OPCODE_DIVIDE 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-f64
		schema/WIRE_OPERAND_KIND_VALUE v-f64
	][12]
v-remainder: add-scalar-instruction 'REMAINDER schema/WIRE_OPCODE_REMAINDER 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-i32
		schema/WIRE_OPERAND_KIND_VALUE v-copy
	][7]
v-modulo: add-scalar-instruction 'MODULO schema/WIRE_OPCODE_MODULO 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-i32
		schema/WIRE_OPERAND_KIND_VALUE v-copy
	][7]
v-negate: add-scalar-instruction 'NEGATE schema/WIRE_OPCODE_NEGATE 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f32] [11]
v-bit-not: add-scalar-instruction 'BIT-NOT schema/WIRE_OPCODE_BIT_NOT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [7]
v-logic-not: add-scalar-instruction 'LOGIC-NOT schema/WIRE_OPCODE_LOGIC_NOT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-logic] [2]
v-shift-left: add-scalar-instruction 'SHIFT-LEFT schema/WIRE_OPCODE_SHIFT_LEFT 0
	schema/WIRE_INSTRUCTION_FLAG_CHECKED 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-i32
		schema/WIRE_OPERAND_KIND_VALUE v-copy
	][7 2]
v-shift-right: add-scalar-instruction 'SHIFT-RIGHT schema/WIRE_OPCODE_SHIFT_RIGHT 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-i32
	schema/WIRE_OPERAND_KIND_VALUE v-copy
][7]
v-shift-logical: add-scalar-instruction 'SHIFT-RIGHT-LOGICAL
	schema/WIRE_OPCODE_SHIFT_RIGHT_LOGICAL 0 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-u32
		schema/WIRE_OPERAND_KIND_VALUE v-copy
	][8]
v-bit-and: add-scalar-instruction 'BIT-AND schema/WIRE_OPCODE_BIT_AND 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-handle
	schema/WIRE_OPERAND_KIND_VALUE 2
][7]
v-bit-or: add-scalar-instruction 'BIT-OR schema/WIRE_OPCODE_BIT_OR 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-logic
	schema/WIRE_OPERAND_KIND_VALUE v-logic-not
][2]
v-bit-xor: add-scalar-instruction 'BIT-XOR schema/WIRE_OPCODE_BIT_XOR 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-i32
	schema/WIRE_OPERAND_KIND_VALUE v-copy
][7]
v-compare: add-scalar-instruction 'COMPARE schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_LESS 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-u8
	][2]

; Cover every accepted conversion family.
v-i64: add-scalar-instruction 'CONVERT-I32-I64 schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [9]
v-i8: add-scalar-instruction 'CONVERT-I32-I8 schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [3]
v-logic-i8: add-scalar-instruction 'CONVERT-LOGIC-I8 schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-logic] [3]
v-i32-logic: add-scalar-instruction 'CONVERT-I32-LOGIC schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [2]
v-pointer-logic: add-scalar-instruction 'CONVERT-POINTER-LOGIC
	schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32] [2]
v-f64-i32: add-scalar-instruction 'CONVERT-F64-I32 schema/WIRE_OPCODE_CONVERT 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f64] [7]
v-f32-f64: add-scalar-instruction 'CONVERT-F32-F64 schema/WIRE_OPCODE_CONVERT 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f32] [12]
v-f64-f32: add-scalar-instruction 'CONVERT-F64-F32 schema/WIRE_OPCODE_CONVERT 0 0
	schema/WIRE_EFFECT_FLAG_MAY_TRAP
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f64] [11]
v-i32-pointer: add-scalar-instruction 'CONVERT-I32-POINTER
	schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [13]
v-pointer-i32-convert: add-scalar-instruction 'CONVERT-POINTER-I32
	schema/WIRE_OPCODE_CONVERT 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32] [7]

; Cover every accepted representation-preserving cast family.
v-i32-u32: add-scalar-instruction 'BITCAST-I32-U32 schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-i32] [8]
v-pointer-function: add-scalar-instruction 'BITCAST-POINTER-FUNCTION
	schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32] [15]
v-function-pointer: add-scalar-instruction 'BITCAST-FUNCTION-POINTER
	schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-function] [14]
v-pointer-u64: add-scalar-instruction 'BITCAST-POINTER-U64
	schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32] [10]
v-u64-pointer: add-scalar-instruction 'BITCAST-U64-POINTER
	schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-pointer-u64] [14]
v-f32-i32: add-scalar-instruction 'BITCAST-F32-I32 schema/WIRE_OPCODE_BITCAST 0 0 0
	reduce [schema/WIRE_OPERAND_KIND_VALUE v-f32] [7]

; Exercise the remaining arithmetic, comparison, effect, and checked paths.
v-pointer-add-integer: add-scalar-instruction 'POINTER-ADD-INTEGER
	schema/WIRE_OPCODE_ADD 0 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32
		schema/WIRE_OPERAND_KIND_VALUE v-u32
	][13]
v-pointer-add-pointer: add-scalar-instruction 'POINTER-ADD-POINTER
	schema/WIRE_OPCODE_ADD 0 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-i32
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-u8
	][13]
v-handle-add: add-scalar-instruction 'HANDLE-ADD schema/WIRE_OPCODE_ADD 0 0 0 reduce [
	schema/WIRE_OPERAND_KIND_VALUE v-handle
	schema/WIRE_OPERAND_KIND_VALUE 2
][7]
foreach [name opcode] [
	FLOAT-ADD 5 FLOAT-SUBTRACT 6 FLOAT-MULTIPLY 7
][
	add-scalar-instruction name opcode 0 0 schema/WIRE_EFFECT_FLAG_MAY_TRAP reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-f32
		schema/WIRE_OPERAND_KIND_VALUE v-f32
	][11]
]
foreach [name opcode effects] [
	CHECKED-ADD 5 0
	CHECKED-SUBTRACT 6 0
	CHECKED-MULTIPLY 7 0
	CHECKED-DIVIDE 8 32
	CHECKED-REMAINDER 9 32
	CHECKED-MODULO 10 32
][
	add-scalar-instruction name opcode 0 schema/WIRE_INSTRUCTION_FLAG_CHECKED effects reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-i32
		schema/WIRE_OPERAND_KIND_VALUE v-copy
	][7 2]
]
add-scalar-instruction 'COMPARE-INTEGER schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_EQUAL 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-handle
		schema/WIRE_OPERAND_KIND_VALUE 2
	][2]
add-scalar-instruction 'COMPARE-FLOAT schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_NOT_EQUAL 0 schema/WIRE_EFFECT_FLAG_MAY_TRAP reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-f64
		schema/WIRE_OPERAND_KIND_VALUE v-f64
	][2]
add-scalar-instruction 'COMPARE-LOGIC schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_GREATER_EQUAL 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-logic
		schema/WIRE_OPERAND_KIND_VALUE v-logic-not
	][2]
add-scalar-instruction 'COMPARE-FUNCTION schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_LESS_EQUAL 0 0 reduce [
		schema/WIRE_OPERAND_KIND_VALUE v-function
		schema/WIRE_OPERAND_KIND_VALUE v-pointer-function
	][2]

; Opcodes after COMPARE are structurally checked here and semantically deferred.
foreach [name kind reference] reduce [
	'DEFERRED-SYMBOL schema/WIRE_OPERAND_KIND_SYMBOL 1
	'DEFERRED-BLOCK schema/WIRE_OPERAND_KIND_BLOCK 1
	'DEFERRED-LOCAL schema/WIRE_OPERAND_KIND_LOCAL 1
	'DEFERRED-TYPE schema/WIRE_OPERAND_KIND_TYPE 7
	'DEFERRED-FUNCTION schema/WIRE_OPERAND_KIND_FUNCTION 1
	'DEFERRED-TARGET-FRAGMENT schema/WIRE_OPERAND_KIND_TARGET_FRAGMENT 1
][
	add-scalar-instruction name schema/WIRE_OPCODE_KEEPALIVE 0 0 0
		reduce [kind reference] []
]

scalar-function-two-first-value: scalar-next-value
repend scalar-value-values [
	schema/WIRE_VALUE_DEFINITION_PARAMETER 3 0 7 2 0
	schema/WIRE_VALUE_DEFINITION_PARAMETER 4 0 16 2 0
]
scalar-next-value: scalar-next-value + 2

scalar-values: fixture-writer/words scalar-value-values
scalar-instructions: fixture-writer/words scalar-instruction-values
scalar-operands: fixture-writer/words scalar-operand-values
scalar-functions: fixture-writer/words [
	1 1 0 1 1 1 1 2 0 0
	2 1 0 2 1 2 3 2 0 0
]
scalar-locals: fixture-writer/words reduce [
	1 scalar-id scalar-strings "a" 7 1 0 0 0 0
	1 scalar-id scalar-strings "b" 16 1 0 0 0 1
	2 scalar-id scalar-strings "a" 7 1 0 0 0 0
	2 scalar-id scalar-strings "b" 16 1 0 0 0 1
]
scalar-blocks: fixture-writer/words reduce [
	1 0 1 scalar-next-instruction - 1 0 0 0 0
	2 0 0 0 0 0 0 0
]
scalar-target-fragments: fixture-writer/words [0 0 0 0 0 0 0 0]

rich-scalar-message: build-scalar-operation-message
	fixture-writer/words [0 2 1 0 0 0 0 0]
	scalar-strings/1 scalar-strings/2 scalar-types scalar-fields
	scalar-signatures scalar-parameters scalar-symbols scalar-constants
	scalar-functions scalar-locals scalar-blocks scalar-values
	scalar-instructions scalar-operands scalar-target-fragments

scalar-section: func [data [binary!] kind [integer!]][constant-section data kind]
scalar-values-section:
	scalar-section rich-scalar-message schema/WIRE_RSIR_SECTION_VALUES
scalar-instructions-section:
	scalar-section rich-scalar-message schema/WIRE_RSIR_SECTION_INSTRUCTIONS
scalar-operands-section:
	scalar-section rich-scalar-message schema/WIRE_RSIR_SECTION_OPERANDS
scalar-blocks-section:
	scalar-section rich-scalar-message schema/WIRE_RSIR_SECTION_BLOCKS

scalar-record-offset: func [section [map!] id record-size [integer!]][
	(select section 'payload-offset) + ((id - 1) * record-size)
]

scalar-record-value: func [
	data [binary!] section [map!] id record-size field [integer!]
][
	container-verifier/read-i31 data
		((scalar-record-offset section id record-size) + field)
]

build-rich-scalar-message: func [
	blocks* values* instructions* operands* [binary!]
][
	build-scalar-operation-message
		fixture-writer/words [0 2 1 0 0 0 0 0]
		scalar-strings/1 scalar-strings/2 scalar-types scalar-fields
		scalar-signatures scalar-parameters scalar-symbols scalar-constants
		scalar-functions scalar-locals blocks* values* instructions* operands*
		scalar-target-fragments
]

scalar-debug-code: func [type-id [integer!]][
	case [
		type-id = 2 [schema/WIRE_DEBUG_TYPE_CODE_LOGIC]
		type-id = 3 [schema/WIRE_DEBUG_TYPE_CODE_INT8]
		type-id = 4 [schema/WIRE_DEBUG_TYPE_CODE_UINT8]
		type-id = 5 [schema/WIRE_DEBUG_TYPE_CODE_INT16]
		find [6] type-id [schema/WIRE_DEBUG_TYPE_CODE_UINT16]
		find [7 16] type-id [schema/WIRE_DEBUG_TYPE_CODE_INTEGER]
		type-id = 8 [schema/WIRE_DEBUG_TYPE_CODE_UINT32]
		type-id = 9 [schema/WIRE_DEBUG_TYPE_CODE_INT64]
		type-id = 10 [schema/WIRE_DEBUG_TYPE_CODE_UINT64]
		type-id = 11 [schema/WIRE_DEBUG_TYPE_CODE_FLOAT32]
		type-id = 12 [schema/WIRE_DEBUG_TYPE_CODE_FLOAT64]
		type-id = 13 [schema/WIRE_DEBUG_TYPE_CODE_INTEGER_POINTER]
		type-id = 14 [schema/WIRE_DEBUG_TYPE_CODE_BYTE_POINTER]
		type-id = 15 [schema/WIRE_DEBUG_TYPE_CODE_FUNCTION]
		true [schema/WIRE_DEBUG_TYPE_CODE_AGGREGATE]
	]
]

scalar-one-symbol: fixture-writer/words reduce [
	scalar-id scalar-strings "fn" 1 2 2 1 0 0 0
]

build-scalar-case: func [
	opcode subopcode flags effects alias-kind alias-id [integer!]
	parameter-types operand-values result-types [block!]
	/local parameter-records local-records value-records result-type ordinal
		first-result first-operand
][
	assert (length? parameter-types) = 2 "scalar case requires two parameters"
	operand-values: reduce operand-values
	assert zero? ((length? operand-values) // 4)
		"scalar case operand records are not whole"
	parameter-records: make block! 16
	local-records: make block! 16
	foreach [ordinal name] [0 "a" 1 "b"] [
		result-type: pick parameter-types (ordinal + 1)
		repend parameter-records [
			1 scalar-id scalar-strings name result-type 0 ordinal
			scalar-debug-code result-type 0 0
		]
		repend local-records [
			1 scalar-id scalar-strings name result-type
			schema/WIRE_LOCAL_KIND_ARGUMENT 0 0 0 ordinal
		]
	]
	value-records: reduce [
		schema/WIRE_VALUE_DEFINITION_PARAMETER 1 0 parameter-types/1 1 0
		schema/WIRE_VALUE_DEFINITION_PARAMETER 2 0 parameter-types/2 1 0
	]
	ordinal: 0
	foreach result-type result-types [
		repend value-records [
			schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 ordinal result-type 1 0
		]
		ordinal: ordinal + 1
	]
	first-result: either empty? result-types [0][3]
	first-operand: either empty? operand-values [0][1]
	build-scalar-operation-message
		fixture-writer/words [0 2 1 0 0 0 0 0]
		scalar-strings/1 scalar-strings/2 scalar-types scalar-fields
		fixture-writer/words [1 0 7 1 2 2 0 0]
		fixture-writer/words parameter-records
		scalar-one-symbol scalar-constants
		fixture-writer/words [1 1 0 1 1 1 1 2 0 0]
		fixture-writer/words local-records
		fixture-writer/words [1 0 1 1 0 0 0 0]
		fixture-writer/words value-records
		fixture-writer/words reduce [
			1 opcode subopcode flags first-result length? result-types
			first-operand (length? operand-values) / 4
			effects alias-kind alias-id 0
		]
		fixture-writer/words operand-values
		scalar-target-fragments
]

valid-scalar-operations: make block! 32
append/only valid-scalar-operations reduce ['EMPTY empty-constant-message]
append/only valid-scalar-operations reduce ['RICH rich-scalar-message]

append/only valid-scalar-operations reduce [
	'CHECKED-HANDLE-ADD
	build-scalar-case schema/WIRE_OPCODE_ADD 0
		schema/WIRE_INSTRUCTION_FLAG_CHECKED 0 0 0 [16 7] [
			schema/WIRE_OPERAND_KIND_VALUE 1 0 0
			schema/WIRE_OPERAND_KIND_VALUE 2 0 0
		][7 2]
]
append/only valid-scalar-operations reduce [
	'CHECKED-I8-ADD
	build-scalar-case schema/WIRE_OPCODE_ADD 0
		schema/WIRE_INSTRUCTION_FLAG_CHECKED 0 0 0 [3 3] [
			schema/WIRE_OPERAND_KIND_VALUE 1 0 0
			schema/WIRE_OPERAND_KIND_VALUE 2 0 0
		][3 2]
]
append/only valid-scalar-operations reduce [
	'POINTER-POINTER-SUBTRACT
	build-scalar-case schema/WIRE_OPCODE_SUBTRACT 0 0 0 0 0 [13 14] [
		schema/WIRE_OPERAND_KIND_VALUE 1 0 0
		schema/WIRE_OPERAND_KIND_VALUE 2 0 0
	][13]
]
append/only valid-scalar-operations reduce [
	'CONVERT-I32-FUNCTION
	build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [7 7]
		[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [15]
]
append/only valid-scalar-operations reduce [
	'CONVERT-FUNCTION-I32
	build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [15 7]
		[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
]
append/only valid-scalar-operations reduce [
	'COMPARE-GREATER
	build-scalar-case schema/WIRE_OPCODE_COMPARE
		schema/WIRE_COMPARE_KIND_GREATER 0 0 0 0 [13 14] [
			schema/WIRE_OPERAND_KIND_VALUE 1 0 0
			schema/WIRE_OPERAND_KIND_VALUE 2 0 0
		][2]
]

malformed-scalar-operations: make block! 4096
add-malformed-scalar-operation: func [
	name [word!]
	expected-error expected-container expected-string expected-file expected-layout
	expected-type expected-function expected-module expected-symbol expected-constant
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-scalar-operations reduce [
		name expected-error expected-container expected-string expected-file expected-layout
		expected-type expected-function expected-module expected-symbol expected-constant
		expected-offset expected-section data
	]
]

add-scalar-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-scalar-operation name expected-error
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

find-constant-initializer-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-constant-initializers [
		if fixture/1 = name [return fixture]
	]
	assert false ["missing nested constant/initializer fixture " name]
]

foreach [name nested-name expected-error] [
	INVALID-CONTAINER INVALID-CONTAINER 2
	INVALID-STRINGS INVALID-STRINGS 3
	INVALID-FILE-SOURCE INVALID-FILE-SOURCE 4
	INVALID-DATA-LAYOUT INVALID-DATA-LAYOUT 5
	INVALID-TYPE-LAYOUT INVALID-TYPE-LAYOUT 6
	INVALID-FUNCTION-SIGNATURE INVALID-FUNCTION-SIGNATURE 7
	INVALID-MODULE-LIFECYCLE INVALID-MODULE-LIFECYCLE 8
	INVALID-SYMBOL-LINKAGE INVALID-SYMBOL-LINKAGE 9
	INVALID-CONSTANT-INITIALIZER BAD-CONSTANT-TYPE 10
][
	nested: find-constant-initializer-fixture nested-name
	add-malformed-scalar-operation name expected-error
		nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9 nested/10
		nested/2 nested/11 nested/12 nested/13
]

foreach [prefix fields section record-size] reduce [
	"VALUE" scalar-operation-verifier/value-fields
		scalar-values-section schema/WIRE_RSIR_VALUE_SIZE
	"INSTRUCTION" scalar-operation-verifier/instruction-fields
		scalar-instructions-section schema/WIRE_RSIR_INSTRUCTION_SIZE
	"OPERAND" scalar-operation-verifier/operand-fields
		scalar-operands-section schema/WIRE_RSIR_OPERAND_SIZE
][
	foreach [field-name field-relative] fields [
		bad: copy rich-scalar-message
		bad-offset: (select section 'payload-offset) + field-relative
		fixture-mutations/put-bytes bad bad-offset #{00000080}
		add-scalar-semantic-error
			to word! rejoin ["SCALAR-" prefix "-" field-name]
			schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_RANGE
			bad-offset (select section 'ordinal) bad
	]
]

foreach [name section expected-error] reduce [
	'BAD-VALUE-SECTION-FLAGS scalar-values-section
		schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_SECTION_FLAGS
	'BAD-INSTRUCTION-SECTION-FLAGS scalar-instructions-section
		schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SECTION_FLAGS
	'BAD-OPERAND-SECTION-FLAGS scalar-operands-section
		schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_SECTION_FLAGS
][
	bad: copy rich-scalar-message
	bad-offset: (select section 'entry-offset) + schema/WIRE_DIRECTORY_FLAGS_OFFSET
	fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
	add-scalar-semantic-error name expected-error bad-offset
		(select section 'ordinal) bad
]

mutate-rich-scalar-record: func [
	name [word!] section [map!] id record-size field value
	expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-scalar-message
	base: scalar-record-offset section id record-size
	fixture-mutations/put-u32 bad (base + field) value
	add-scalar-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

; Common value, instruction, block, and operand structure.
mutate-rich-scalar-record 'BAD-VALUE-DEFINITION-KIND scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_KIND
	schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET
mutate-rich-scalar-record 'BAD-VALUE-DEFINITION-ID scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_DEFINITION_ID
	schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET
mutate-rich-scalar-record 'BAD-VALUE-RESULT-ORDINAL scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_RESULT_ORDINAL
	schema/WIRE_RSIR_VALUE_RESULT_ORDINAL_OFFSET
mutate-rich-scalar-record 'BAD-VALUE-TYPE scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_TYPE_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_TYPE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET
mutate-rich-scalar-record 'BAD-VALUE-FUNCTION scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_FUNCTION
	schema/WIRE_RSIR_VALUE_FUNCTION_OFFSET
mutate-rich-scalar-record 'NONZERO-VALUE-FLAGS scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_FLAGS_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_VALUE_FLAGS
	schema/WIRE_RSIR_VALUE_FLAGS_OFFSET

mutate-rich-scalar-record 'BAD-BLOCK-INSTRUCTION-RANGE scalar-blocks-section 1
	schema/WIRE_RSIR_BLOCK_SIZE schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET 2
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BLOCK_INSTRUCTION_RANGE
	schema/WIRE_RSIR_BLOCK_FIRST_INSTRUCTION_OFFSET

extra: copy scalar-instructions
append extra fixture-writer/words [1 46 0 0 0 0 0 0 0 0 0 0]
bad: build-rich-scalar-message scalar-blocks scalar-values extra scalar-operands
bad-offset: (select scalar-instructions-section 'payload-offset)
	+ ((scalar-next-instruction - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE)
add-scalar-semantic-error 'BAD-INSTRUCTION-COVERAGE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_COVERAGE
	bad-offset (select scalar-instructions-section 'ordinal) bad

mutate-rich-scalar-record 'BAD-INSTRUCTION-BLOCK scalar-instructions-section 1
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET 2
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_BLOCK
	schema/WIRE_RSIR_INSTRUCTION_BLOCK_OFFSET
mutate-rich-scalar-record 'BAD-OPCODE scalar-instructions-section 1
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPCODE
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET
mutate-rich-scalar-record 'BAD-INSTRUCTION-RESULT-RANGE scalar-instructions-section 1
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_RESULT_RANGE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
mutate-rich-scalar-record 'BAD-INSTRUCTION-OPERAND-RANGE scalar-instructions-section 1
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_OPERAND_RANGE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
mutate-rich-scalar-record 'BAD-INSTRUCTION-SOURCE scalar-instructions-section 1
	schema/WIRE_RSIR_INSTRUCTION_SIZE schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_INSTRUCTION_SOURCE_LOCATION
	schema/WIRE_RSIR_INSTRUCTION_SOURCE_LOCATION_OFFSET

mutate-rich-scalar-record 'BAD-OPERAND-KIND scalar-operands-section 1
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_KIND_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_KIND
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET
mutate-rich-scalar-record 'BAD-OPERAND-REFERENCE scalar-operands-section 1
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 0
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_REFERENCE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

copy-instruction: select scalar-instruction-ids 'COPY
copy-first-operand: scalar-record-value rich-scalar-message scalar-instructions-section
	copy-instruction schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_OPERAND_OFFSET
mutate-rich-scalar-record 'BAD-OPERAND-FUNCTION scalar-operands-section copy-first-operand
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
	scalar-function-two-first-value
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_FUNCTION
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-rich-scalar-record 'NONZERO-OPERAND-FLAGS scalar-operands-section 1
	schema/WIRE_RSIR_OPERAND_SIZE schema/WIRE_RSIR_OPERAND_FLAGS_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_OPERAND_FLAGS
	schema/WIRE_RSIR_OPERAND_FLAGS_OFFSET

extra: copy scalar-operands
append extra fixture-writer/words [3 1 0 0]
bad: build-rich-scalar-message scalar-blocks scalar-values scalar-instructions extra
bad-offset: (select scalar-operands-section 'payload-offset)
	+ ((scalar-next-operand - 1) * schema/WIRE_RSIR_OPERAND_SIZE)
add-scalar-semantic-error 'BAD-OPERAND-COVERAGE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_OPERAND_COVERAGE
	bad-offset (select scalar-operands-section 'ordinal) bad

mutate-rich-scalar-record 'BAD-PARAMETER-VALUE scalar-values-section 1
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET 2
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_PARAMETER_VALUE
	schema/WIRE_RSIR_VALUE_DEFINITION_KIND_OFFSET

extra: copy scalar-values
append extra fixture-writer/words [2 1 0 7 2 0]
bad: build-rich-scalar-message scalar-blocks extra scalar-instructions scalar-operands
bad-offset: (select scalar-values-section 'payload-offset)
	+ ((scalar-next-value - 1) * schema/WIRE_RSIR_VALUE_SIZE)
add-scalar-semantic-error 'BAD-VALUE-COVERAGE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_VALUE_COVERAGE
	bad-offset (select scalar-values-section 'ordinal) bad

compare-function-instruction: select scalar-instruction-ids 'COMPARE-FUNCTION
compare-function-result: scalar-record-value rich-scalar-message scalar-instructions-section
	compare-function-instruction schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET
mutate-rich-scalar-record 'BAD-RESULT-VALUE scalar-values-section compare-function-result
	schema/WIRE_RSIR_VALUE_SIZE schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET 1
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_RESULT_VALUE
	schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET

add-scalar-case-error: func [
	name [word!] expected-error [integer!] data [binary!]
	section-kind record-id record-size field [integer!]
	/local section offset
][
	section: scalar-section data section-kind
	offset: (scalar-record-offset section record-id record-size) + field
	add-scalar-semantic-error name expected-error offset (select section 'ordinal) data
]

case-data: build-scalar-case 5 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
add-scalar-case-error 'BAD-SCALAR-OPERAND-COUNT
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_COUNT case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET

case-data: build-scalar-case 5 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0 schema/WIRE_OPERAND_KIND_VALUE 2 0 0] []
add-scalar-case-error 'BAD-SCALAR-RESULT-COUNT
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_RESULT_COUNT case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET

case-data: build-scalar-case 5 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0 schema/WIRE_OPERAND_KIND_VALUE 2 0 0] [7]
add-scalar-case-error 'BAD-SCALAR-OPERAND-KIND
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_OPERAND_KIND case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 1 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_KIND_OFFSET

case-data: build-scalar-case 5 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 1 0 schema/WIRE_OPERAND_KIND_VALUE 2 0 0] [7]
add-scalar-case-error 'NONZERO-SCALAR-OPERAND-AUXILIARY
	schema/WIRE_SCALAR_OPERATION_ERROR_NONZERO_SCALAR_OPERAND_AUXILIARY case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 1 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET

case-data: build-scalar-case 2 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [8]
add-scalar-case-error 'SCALAR-TYPE-MISMATCH
	schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case 2 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [17]
add-scalar-case-error 'BAD-SCALAR-TYPE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_TYPE case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case 3 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
add-scalar-case-error 'BAD-CONVERSION
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case 4 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [9]
add-scalar-case-error 'BAD-BITCAST
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case 20 0 0 0 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][2]
add-scalar-case-error 'BAD-COMPARE-KIND
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_KIND case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET

case-data: build-scalar-case 20 1 0 0 0 0 [13 15] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][2]
add-scalar-case-error 'BAD-COMPARE-TYPE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_TYPE case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 2 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

case-data: build-scalar-case 2 0 1 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7 2]
add-scalar-case-error 'BAD-CHECKED-OPERATION
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_OPERATION case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET

case-data: build-scalar-case 5 0 1 0 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7 7]
add-scalar-case-error 'BAD-CHECKED-RESULT
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_RESULT case-data
	schema/WIRE_RSIR_SECTION_VALUES 4 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case 14 0 0 0 0 0 [7 16] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SHIFT-COUNT-TYPE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SHIFT_COUNT_TYPE case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 2 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

case-data: build-scalar-case 5 1 0 0 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SCALAR-SUBOPCODE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_SUBOPCODE case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET

case-data: build-scalar-case 5 0 2 0 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SCALAR-INSTRUCTION-FLAGS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_INSTRUCTION_FLAGS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET

case-data: build-scalar-case 5 0 0 32 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SCALAR-EFFECTS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET

case-data: build-scalar-case 5 0 0 0 1 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SCALAR-ALIAS-KIND
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_ALIAS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

case-data: build-scalar-case 5 0 0 0 0 1 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SCALAR-ALIAS-ID
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_ALIAS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_ID_OFFSET

; Exercise distinct rejection branches that intentionally share public errors.
case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [16 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
add-scalar-case-error 'BAD-CONVERT-HANDLE-SOURCE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [16]
add-scalar-case-error 'BAD-CONVERT-HANDLE-TARGET
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [8]
add-scalar-case-error 'BAD-CONVERT-EQUAL-WIDTH-INTEGER
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [13 15]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [15]
add-scalar-case-error 'BAD-CONVERT-ADDRESS-ADDRESS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [10 13]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [13]
add-scalar-case-error 'BAD-CONVERT-EQUAL-WIDTH-ADDRESS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CONVERSION case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_BITCAST 0 0 0 0 0 [16 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
add-scalar-case-error 'BAD-BITCAST-HANDLE-SOURCE
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_BITCAST 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [16]
add-scalar-case-error 'BAD-BITCAST-HANDLE-TARGET
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_BITCAST 0 0 0 0 0 [2 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [7]
add-scalar-case-error 'BAD-BITCAST-LOGIC
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_BITCAST 0 0 0 0 0 [12 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [10]
add-scalar-case-error 'BAD-BITCAST-F64-U64
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_BITCAST case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_COMPARE
	schema/WIRE_COMPARE_KIND_EQUAL 0 schema/WIRE_EFFECT_FLAG_MAY_TRAP 0 0 [11 12] [
		schema/WIRE_OPERAND_KIND_VALUE 1 0 0
		schema/WIRE_OPERAND_KIND_VALUE 2 0 0
	][2]
add-scalar-case-error 'BAD-COMPARE-FLOAT-WIDTH
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_COMPARE_TYPE case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 2 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_ADD 0
	schema/WIRE_INSTRUCTION_FLAG_CHECKED schema/WIRE_EFFECT_FLAG_MAY_TRAP 0 0
	[11 11] [
		schema/WIRE_OPERAND_KIND_VALUE 1 0 0
		schema/WIRE_OPERAND_KIND_VALUE 2 0 0
	][11 2]
add-scalar-case-error 'BAD-CHECKED-FLOAT
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_CHECKED_OPERATION case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_SHIFT_LEFT 0 0 0 0 0 [7 8] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-SHIFT-U32-COUNT
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SHIFT_COUNT_TYPE case-data
	schema/WIRE_RSIR_SECTION_OPERANDS 2 schema/WIRE_RSIR_OPERAND_SIZE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_ADD 0 0 0 0 0 [16 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][16]
add-scalar-case-error 'BAD-HANDLE-RESULT
	schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_ADD 0 0 0 0 0 [13 15] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][13]
add-scalar-case-error 'BAD-POINTER-FUNCTION-ARITHMETIC
	schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_ADD 0 0 0 0 0 [15 15] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][15]
add-scalar-case-error 'BAD-FUNCTION-ARITHMETIC
	schema/WIRE_SCALAR_OPERATION_ERROR_SCALAR_TYPE_MISMATCH case-data
	schema/WIRE_RSIR_SECTION_VALUES 3 schema/WIRE_RSIR_VALUE_SIZE
	schema/WIRE_RSIR_VALUE_TYPE_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_ADD 0 0 0 0 0 [11 11] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][11]
add-scalar-case-error 'BAD-FLOAT-ARITHMETIC-EFFECTS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_DIVIDE 0 0 0 0 0 [7 7] [
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_VALUE 2 0 0
][7]
add-scalar-case-error 'BAD-INTEGER-DIVIDE-EFFECTS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET

case-data: build-scalar-case schema/WIRE_OPCODE_CONVERT 0 0 0 0 0 [7 7]
	[schema/WIRE_OPERAND_KIND_VALUE 1 0 0] [11]
add-scalar-case-error 'BAD-FLOAT-CONVERT-EFFECTS
	schema/WIRE_SCALAR_OPERATION_ERROR_BAD_SCALAR_EFFECTS case-data
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS 1 schema/WIRE_RSIR_INSTRUCTION_SIZE
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET

foreach fixture valid-scalar-operations [
	result: scalar-operation-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid scalar boundary rejected with error " result/error
		" at " result/error-offset ":" result/error-section
	]
]

result: scalar-operation-verifier/verify empty-constant-message
assert result/valid? [
	"empty scalar module rejected with error " result/error
	" at " result/error-offset ":" result/error-section
]
assert all [
	result/error = schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
	result/view/value-count = 0
	result/view/instruction-count = 0
	result/view/operand-count = 0
]["empty scalar module view changed"]

result: scalar-operation-verifier/verify rich-scalar-message
assert result/valid? [
	"rich scalar module rejected with error " result/error
	" (container=" result/container-error
	", strings=" result/string-error
	", file/source=" result/file-source-error
	", layout=" result/data-layout-error
	", types=" result/type-layout-error
	", functions=" result/function-signature-error
	", modules=" result/module-lifecycle-error
	", symbols=" result/symbol-linkage-error
	", constants=" result/constant-initializer-error ")"
	" at " result/error-offset ":" result/error-section
]
assert to logic! all [
	result/error = schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
	result/view/value-count = (scalar-next-value - 1)
	result/view/instruction-count = (scalar-next-instruction - 1)
	result/view/operand-count = (scalar-next-operand - 1)
	result/view/target-fragment-count = 1
	result/functions/function-count = 2
	result/constants/constant-count = 9
]["rich scalar module view changed"]

result: scalar-operation-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS
	result/container-error = schema/WIRE_CONTAINER_ERROR_SUCCESS
	result/constant-initializer-error =
		schema/WIRE_CONSTANT_INITIALIZER_ERROR_SUCCESS
	result/error-offset = 0
	result/error-section = 0
	none? result/strings
	none? result/files
	none? result/layout
	none? result/types
	none? result/functions
	none? result/modules
	none? result/symbols
	none? result/constants
	none? result/view
]["non-binary scalar input did not fail atomically"]

covered-errors: make block! 128
append covered-errors schema/WIRE_SCALAR_OPERATION_ERROR_SUCCESS
append covered-errors schema/WIRE_SCALAR_OPERATION_ERROR_INVALID_ARGUMENTS
foreach fixture malformed-scalar-operations [
	result: scalar-operation-verifier/verify fixture/14
	assert not result/valid? [fixture/1 " malformed scalar operation was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/container-error = fixture/3
		result/string-error = fixture/4
		result/file-source-error = fixture/5
		result/data-layout-error = fixture/6
		result/type-layout-error = fixture/7
		result/function-signature-error = fixture/8
		result/module-lifecycle-error = fixture/9
		result/symbol-linkage-error = fixture/10
		result/constant-initializer-error = fixture/11
		result/error-offset = fixture/12
		result/error-section = fixture/13
	][
		fixture/1 " nested error or location changed; got "
		result/error-offset ":" result/error-section
	]
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

repeat code 53 [
	assert not none? find covered-errors (code - 1) [
		"scalar operation error code not covered: " code - 1
	]
]

result: scalar-operation-verifier/verify rich-scalar-message
assert result/valid? "rich scalar module failed after malformed corpus"

unless value? 'generating-wire-scalar-operation-fixtures? [
	source-bytes: make binary! 4'194'304
	foreach source-file [
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
		%../generate-wire-scalar-operation-fixtures.red
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-scalar-operation-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System scalar operation fixtures are stale"
]

print [
	"PASS: Red RSIR scalar value and operation verifier values="
	result/view/value-count " instructions=" result/view/instruction-count
	" operands=" result/view/operand-count
	" malformed=" length? malformed-scalar-operations
]
