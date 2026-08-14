Red [
	Title: "Hybrid compiler RSIR exception tests"
]

do %wire-subroutine-test.red
do %../../../compiler/wire-exception.red

exception-verifier: compiler-wire-exception

exception-strings: make-canonical-strings [
	"" "caller" "cond" "external" "lib.dll" "target"
]
exception-id: :symbol-string-id

exception-types: fixture-writer/words [
	; void, logic, signed i32.
	1 0 0 0 0 0 0 0 0 0
	2 0 4 4 0 0 0 0 0 0
	3 1 4 4 0 0 0 0 0 0
]

exception-signatures: fixture-writer/words reduce [
	; caller(logic) -> void, internal throwing target, external throwing target.
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM 0 1 1 1 1 0 0
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_MAY_THROW
		1 0 0 0 0 0
	schema/WIRE_CALLING_CONVENTION_CDECL schema/WIRE_FUNCTION_FLAG_MAY_THROW
		1 0 0 0 0 0
]

exception-parameters: fixture-writer/words reduce [
	1 exception-id exception-strings "cond" 2 0 0
		schema/WIRE_DEBUG_TYPE_CODE_LOGIC 0 0
]

; Symbols are sorted by canonical UTF-8 name.
exception-symbols: fixture-writer/words reduce [
	exception-id exception-strings "caller" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 1 0 0 0
	exception-id exception-strings "external" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_IMPORT schema/WIRE_VISIBILITY_DEFAULT 3 0 0 0
	exception-id exception-strings "target" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 2 0 0 0
]

exception-imports: fixture-writer/words reduce [
	exception-id exception-strings "lib.dll"
		exception-id exception-strings "external"
		2 schema/WIRE_CALLING_CONVENTION_CDECL 0 0
]

exception-constants: fixture-writer/words [
	; type kind flags data-offset data-size first-part part-count auxiliary
	3 2 0 0 4 0 0 0
	3 2 0 4 4 0 0 0
]
exception-constant-data: #{FFFFFFFF0A000000}

exception-functions: fixture-writer/words [
	; symbol signature flags first-block count entry first-local count source reserved
	1 1 0 1 14 1 1 1 0 0
	3 2 0 15 1 15 0 0 0 0
]

exception-locals: fixture-writer/words reduce [
	1 exception-id exception-strings "cond" 2 schema/WIRE_LOCAL_KIND_ARGUMENT
		0 0 0 0
]

exception-values: fixture-writer/words reduce [
	; cond parameter, outer -1 filter, inner 10 filter, direct throw ID.
	schema/WIRE_VALUE_DEFINITION_PARAMETER 1 0 2 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 1 0 3 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 4 0 3 1 schema/WIRE_VALUE_FLAG_NONE
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 14 0 3 1 schema/WIRE_VALUE_FLAG_NONE
]

catch-effects: schema/WIRE_EFFECT_FLAG_CONTROL
throw-effects:
	(schema/WIRE_EFFECT_FLAG_CONTROL + schema/WIRE_EFFECT_FLAG_THROW)
	+ schema/WIRE_EFFECT_FLAG_WRITE
exception-call-effects:
	ordinary-call-effects + schema/WIRE_EFFECT_FLAG_THROW

exception-instructions: fixture-writer/words reduce [
	; block opcode sub flags first-result result-count first-operand operand-count
	; effects alias alias-id source
	1 schema/WIRE_OPCODE_CONSTANT 0 0 2 1 1 1 0 schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_CATCH_ENTER 0 0 0 0 2 2 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	1 schema/WIRE_OPCODE_JUMP 0 0 0 0 4 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	2 schema/WIRE_OPCODE_CONSTANT 0 0 3 1 5 1 0 schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CATCH_ENTER 0 0 0 0 6 2 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 8 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	3 schema/WIRE_OPCODE_CALL 0 0 0 0 9 1 exception-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 10 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	4 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 11 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_JUMP 0 0 0 0 12 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	5 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 13 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	5 schema/WIRE_OPCODE_JUMP 0 0 0 0 14 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	6 schema/WIRE_OPCODE_BRANCH 0 0 0 0 15 3 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	7 schema/WIRE_OPCODE_CONSTANT 0 0 4 1 18 1 0 schema/WIRE_ALIAS_KIND_NONE 0 0
	7 schema/WIRE_OPCODE_THROW 0 0 0 0 19 1 throw-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0

	8 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 20 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	8 schema/WIRE_OPCODE_JUMP 0 0 0 0 21 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	9 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 22 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	9 schema/WIRE_OPCODE_JUMP 0 0 0 0 23 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	10 schema/WIRE_OPCODE_CATCH_ENTER 0 0 0 0 24 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	10 schema/WIRE_OPCODE_JUMP 0 0 0 0 25 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	11 schema/WIRE_OPCODE_CALL 0 0 0 0 26 1 exception-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	11 schema/WIRE_OPCODE_JUMP 0 0 0 0 27 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	12 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 28 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	12 schema/WIRE_OPCODE_JUMP 0 0 0 0 29 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	13 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 30 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	13 schema/WIRE_OPCODE_JUMP 0 0 0 0 31 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0

	14 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	15 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]

exception-operands: fixture-writer/words reduce [
	; Outer catch entry.
	schema/WIRE_OPERAND_KIND_CONSTANT 1 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 9 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_VALUE 2 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 2 0 schema/WIRE_OPERAND_FLAG_NONE
	; Inner catch entry.
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_VALUE 3 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 schema/WIRE_OPERAND_FLAG_NONE
	; Inner throwing call and ordinary exit.
	schema/WIRE_OPERAND_KIND_SYMBOL 3 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 6 0 schema/WIRE_OPERAND_FLAG_NONE
	; Inner handler.
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 6 0 schema/WIRE_OPERAND_FLAG_NONE
	; Branch, explicit throw.
	schema/WIRE_OPERAND_KIND_VALUE 1 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 7 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 8 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_CONSTANT 2 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_VALUE 4 0 schema/WIRE_OPERAND_FLAG_NONE
	; Outer normal leave and handler.
	schema/WIRE_OPERAND_KIND_BLOCK 9 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 10 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 9 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 10 0 schema/WIRE_OPERAND_FLAG_NONE
	; Function catch entry and call.
	schema/WIRE_OPERAND_KIND_BLOCK 13 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 11 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_SYMBOL 3 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 12 0 schema/WIRE_OPERAND_FLAG_NONE
	; Function normal leave and handler.
	schema/WIRE_OPERAND_KIND_BLOCK 13 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 14 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 13 0 schema/WIRE_OPERAND_FLAG_NONE
	schema/WIRE_OPERAND_KIND_BLOCK 14 0 schema/WIRE_OPERAND_FLAG_NONE
]

exception-edges: fixture-writer/words reduce [
	1 2 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	2 3 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 5 schema/WIRE_EDGE_KIND_EXCEPTION 0 1 0
	3 9 schema/WIRE_EDGE_KIND_EXCEPTION 0 2 0
	4 6 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	5 6 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	6 7 schema/WIRE_EDGE_KIND_TRUE 0 0 0
	6 8 schema/WIRE_EDGE_KIND_FALSE 0 1 0
	7 9 schema/WIRE_EDGE_KIND_EXCEPTION 0 0 0
	8 10 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	9 10 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	10 11 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	11 12 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	11 13 schema/WIRE_EDGE_KIND_EXCEPTION 0 1 0
	12 14 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	13 14 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
]

exception-blocks: fixture-writer/words [
	1 0 1 3 1 1 0 0
	1 0 4 3 2 1 0 0
	1 0 7 2 3 3 0 0
	1 0 9 2 6 1 0 0
	1 0 11 2 7 1 0 0
	1 0 13 1 8 2 0 0
	1 0 14 2 10 1 0 0
	1 0 16 2 11 1 0 0
	1 0 18 2 12 1 0 0
	1 0 20 2 13 1 0 0
	1 0 22 2 14 2 0 0
	1 0 24 2 16 1 0 0
	1 0 26 2 17 1 0 0
	1 0 28 1 0 0 0 0
	2 0 29 1 0 0 0 0
]

exception-calls: fixture-writer/words reduce [
	7 2 schema/WIRE_CALL_KIND_DIRECT 9 0 0 0 0
	22 2 schema/WIRE_CALL_KIND_DIRECT 26 0 0 0 0
]

exception-regions: fixture-writer/words reduce [
	; Outer lexical, inner lexical, disjoint function-[catch] call wrapper.
	1 1 6 9 schema/WIRE_EXCEPTION_REGION_KIND_FILTER
		schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
	1 7 1 5 schema/WIRE_EXCEPTION_REGION_KIND_FILTER 0
	1 8 1 13 schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
		schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
]

exception-members: fixture-writer/words [
	1 2  1 3  1 4  1 5  1 6  1 7
	2 3
	3 11
]

build-exception-message: func [
	regions* members* blocks* values* instructions* operands* edges* calls* [binary!]
	/local payloads sections section-kind
][
	payloads: make map! 112
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS exception-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA exception-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES exception-types
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES exception-signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS exception-parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS exception-symbols
	put payloads schema/WIRE_RSIR_SECTION_IMPORTS exception-imports
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS exception-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA exception-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS exception-functions
	put payloads schema/WIRE_RSIR_SECTION_LOCALS exception-locals
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS blocks*
	put payloads schema/WIRE_RSIR_SECTION_EDGES edges*
	put payloads schema/WIRE_RSIR_SECTION_VALUES values*
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instructions*
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operands*
	put payloads schema/WIRE_RSIR_SECTION_CALLS calls*
	put payloads schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS regions*
	put payloads schema/WIRE_RSIR_SECTION_EXCEPTION_BLOCKS members*
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

rich-exception-message: build-exception-message exception-regions exception-members
	exception-blocks exception-values exception-instructions exception-operands
	exception-edges exception-calls

; Exception regions belong to an execution region, not merely to their host
; function. These fixtures keep the host and both compiler-generated
; subroutines in one function while exercising catch and propagation paths.
subexception-signatures: copy subroutine-signatures
append subexception-signatures fixture-writer/words reduce [
	schema/WIRE_CALLING_CONVENTION_RED_SYSTEM schema/WIRE_FUNCTION_FLAG_MAY_THROW
		1 0 0 0 0 0
]
subexception-plain-symbols: fixture-writer/words reduce [
	control-id control-strings "fn-void" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 2 0 0 0
]
subexception-throwing-symbols: fixture-writer/words reduce [
	control-id control-strings "fn-void" schema/WIRE_SYMBOL_KIND_FUNCTION
		schema/WIRE_LINKAGE_INTERNAL schema/WIRE_VISIBILITY_HIDDEN 5 0 0 0
]
subexception-plain-functions: fixture-writer/words [
	1 2 0 1 6 1 0 0 0 0
]
subexception-throwing-functions: fixture-writer/words [
	1 5 0 1 6 1 0 0 0 0
]
subexception-catch-descriptors: fixture-writer/words reduce [
	1 control-id control-strings "fn-main" 2 2 1 4 0 0
	1 control-id control-strings "fn-no-return" 5 6 5 1 0 0
]
subexception-propagating-descriptors: fixture-writer/words reduce [
	1 control-id control-strings "fn-main" 5 2 1 4 0 0
	1 control-id control-strings "fn-no-return" 5 6 5 1 0 0
]
subexception-subroutine-members: fixture-writer/words [
	1 2  1 3  1 4  1 5  2 6
]
subexception-blocks: fixture-writer/words [
	1 0 1 2 0 0 0 0
	1 0 3 3 1 1 0 0
	1 0 6 2 2 2 0 0
	1 0 8 2 0 0 0 0
	1 0 10 2 0 0 0 0
	1 0 12 1 0 0 0 0
]
subexception-edges: fixture-writer/words reduce [
	2 3 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 4 schema/WIRE_EDGE_KIND_NORMAL 0 0 0
	3 5 schema/WIRE_EDGE_KIND_EXCEPTION 0 1 0
]
subexception-values: fixture-writer/words reduce [
	schema/WIRE_VALUE_DEFINITION_INSTRUCTION 3 0 3 1 schema/WIRE_VALUE_FLAG_NONE
]
subexception-catch-instructions: fixture-writer/words reduce [
	1 schema/WIRE_OPCODE_CALL 0 0 0 0 1 1 ordinary-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	1 schema/WIRE_OPCODE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CONSTANT 0 0 1 1 2 1 0
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_CATCH_ENTER 0 0 0 0 3 2 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	2 schema/WIRE_OPCODE_JUMP 0 0 0 0 5 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	3 schema/WIRE_OPCODE_CALL 0 0 0 0 6 1 exception-call-effects
		schema/WIRE_ALIAS_KIND_UNIVERSAL 0 0
	3 schema/WIRE_OPCODE_JUMP 0 0 0 0 7 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 8 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	4 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	5 schema/WIRE_OPCODE_CATCH_LEAVE 0 0 0 0 9 1 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	5 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
	6 schema/WIRE_OPCODE_SUBROUTINE_RETURN 0 0 0 0 0 0 catch-effects
		schema/WIRE_ALIAS_KIND_NONE 0 0
]
subexception-catch-operands: fixture-writer/words reduce [
	schema/WIRE_OPERAND_KIND_SUBROUTINE 1 0 0
	schema/WIRE_OPERAND_KIND_CONSTANT 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 0
	schema/WIRE_OPERAND_KIND_VALUE 1 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 3 0 0
	schema/WIRE_OPERAND_KIND_SUBROUTINE 2 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 4 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 0
	schema/WIRE_OPERAND_KIND_BLOCK 5 0 0
]
subexception-catch-calls: fixture-writer/words reduce [
	1 2 schema/WIRE_CALL_KIND_SUBROUTINE 1 0 0 0 0
	6 5 schema/WIRE_CALL_KIND_SUBROUTINE 6 0 0 0 0
]
subexception-catch-regions: fixture-writer/words reduce [
	1 1 1 5 schema/WIRE_EXCEPTION_REGION_KIND_FILTER
		schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
]
subexception-propagating-regions: fixture-writer/words reduce [
	1 1 1 5 schema/WIRE_EXCEPTION_REGION_KIND_FILTER 0
]
subexception-exception-members: fixture-writer/words [1 3]

subexception-propagating-instructions: copy subexception-catch-instructions
base: ((1 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE) + 1
fixture-mutations/put-u32 subexception-propagating-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
	exception-call-effects
subexception-propagating-operands: copy subexception-catch-operands
base: ((2 - 1) * schema/WIRE_RSIR_OPERAND_SIZE) + 1
fixture-mutations/put-u32 subexception-propagating-operands
	((base - 1) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 2
subexception-propagating-calls: copy subexception-catch-calls
base: ((1 - 1) * schema/WIRE_RSIR_CALL_SIZE) + 1
fixture-mutations/put-u32 subexception-propagating-calls
	((base - 1) + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET) 5

build-subroutine-exception-message: func [
	function-records symbol-records descriptors subroutine-members regions
	exception-members instructions operands calls [binary!]
	/local payloads sections section-kind
][
	payloads: make map! 112
	put payloads schema/WIRE_RSIR_SECTION_MODULE
		fixture-writer/words [0 2 1 0 0 0 0 0]
	put payloads schema/WIRE_RSIR_SECTION_DATA_LAYOUT data-layout
	put payloads schema/WIRE_RSIR_SECTION_STRINGS subroutine-strings/1
	put payloads schema/WIRE_RSIR_SECTION_STRING_DATA subroutine-strings/2
	put payloads schema/WIRE_RSIR_SECTION_TYPES subroutine-types
	put payloads schema/WIRE_RSIR_SECTION_SIGNATURES subexception-signatures
	put payloads schema/WIRE_RSIR_SECTION_PARAMETERS control-parameters
	put payloads schema/WIRE_RSIR_SECTION_SYMBOLS symbol-records
	put payloads schema/WIRE_RSIR_SECTION_CONSTANTS exception-constants
	put payloads schema/WIRE_RSIR_SECTION_CONSTANT_DATA exception-constant-data
	put payloads schema/WIRE_RSIR_SECTION_FUNCTIONS function-records
	put payloads schema/WIRE_RSIR_SECTION_LOCALS subroutine-locals
	put payloads schema/WIRE_RSIR_SECTION_BLOCKS subexception-blocks
	put payloads schema/WIRE_RSIR_SECTION_EDGES subexception-edges
	put payloads schema/WIRE_RSIR_SECTION_VALUES subexception-values
	put payloads schema/WIRE_RSIR_SECTION_INSTRUCTIONS instructions
	put payloads schema/WIRE_RSIR_SECTION_OPERANDS operands
	put payloads schema/WIRE_RSIR_SECTION_CALLS calls
	put payloads schema/WIRE_RSIR_SECTION_SUBROUTINES descriptors
	put payloads schema/WIRE_RSIR_SECTION_SUBROUTINE_BLOCKS subroutine-members
	put payloads schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS regions
	put payloads schema/WIRE_RSIR_SECTION_EXCEPTION_BLOCKS exception-members
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

subroutine-catch-message: build-subroutine-exception-message
	subexception-plain-functions subexception-plain-symbols
	subexception-catch-descriptors subexception-subroutine-members
	subexception-catch-regions subexception-exception-members
	subexception-catch-instructions subexception-catch-operands
	subexception-catch-calls
subroutine-propagation-message: build-subroutine-exception-message
	subexception-throwing-functions subexception-throwing-symbols
	subexception-propagating-descriptors subexception-subroutine-members
	subexception-propagating-regions subexception-exception-members
	subexception-propagating-instructions subexception-propagating-operands
	subexception-propagating-calls

result: exception-verifier/verify rich-exception-message
assert result/valid? [
	"rich exception module rejected with error " result/error
	" call=" result/call-abi-error " at " result/error-offset ":" result/error-section
]
assert to logic! all [
	result/view/region-count = 3
	result/view/block-member-count = 8
	result/call-view/call-count = 2
	result/control-view/edge-count = 17
	result/scalar-view/instruction-count = 29
]["rich exception view changed"]

exception-region-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS
exception-member-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_EXCEPTION_BLOCKS
exception-block-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_BLOCKS
exception-edge-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_EDGES
exception-value-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_VALUES
exception-instruction-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS
exception-operand-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_OPERANDS
exception-call-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_CALLS
exception-signature-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_SIGNATURES
exception-constant-data-section: control-section rich-exception-message
	schema/WIRE_RSIR_SECTION_CONSTANT_DATA

exception-record-offset: func [section [map!] id size [integer!]][
	(select section 'payload-offset) + ((id - 1) * size)
]

malformed-exceptions: make block! 4096
add-malformed-exception: func [
	name [word!]
	expected-error expected-subroutine expected-call expected-control expected-scalar
	expected-container expected-string expected-file expected-layout expected-type
	expected-function expected-module expected-symbol expected-constant
	expected-offset expected-section [integer!]
	data [binary!]
][
	append/only malformed-exceptions reduce [
		name expected-error expected-subroutine expected-call expected-control
		expected-scalar expected-container expected-string expected-file expected-layout
		expected-type expected-function expected-module expected-symbol expected-constant
		expected-offset expected-section data
	]
]

add-exception-semantic-error: func [
	name [word!] expected-error expected-offset expected-section [integer!]
	data [binary!]
][
	add-malformed-exception name expected-error
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

mutate-exception-record: func [
	name [word!] section [map!] id size field value expected-error expected-field [integer!]
	/local bad base
][
	bad: copy rich-exception-message
	base: exception-record-offset section id size
	fixture-mutations/put-u32 bad (base + field) value
	add-exception-semantic-error name expected-error (base + expected-field)
		(select section 'ordinal) bad
]

mutate-exception-region: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-exception-record name exception-region-section id
		schema/WIRE_RSIR_EXCEPTION_REGION_SIZE field value expected-error expected-field
]

mutate-exception-member: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-exception-record name exception-member-section id
		schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE field value expected-error expected-field
]

mutate-exception-instruction: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-exception-record name exception-instruction-section id
		schema/WIRE_RSIR_INSTRUCTION_SIZE field value expected-error expected-field
]

mutate-exception-operand: func [
	name [word!] id field value expected-error expected-field [integer!]
][
	mutate-exception-record name exception-operand-section id
		schema/WIRE_RSIR_OPERAND_SIZE field value expected-error expected-field
]

find-subroutine-exception-fixture: func [name [word!] /local fixture][
	foreach fixture malformed-subroutines [if fixture/1 = name [return fixture]]
	assert false ["missing nested subroutine fixture " name]
]

nested: find-subroutine-exception-fixture 'BAD-SUBROUTINE-SECTION-FLAGS
add-malformed-exception 'INVALID-SUBROUTINE schema/WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14 nested/15 nested/16 nested/17

nested: find-subroutine-exception-fixture 'INVALID-CALL-ABI
add-malformed-exception 'INVALID-CALL-ABI schema/WIRE_EXCEPTION_ERROR_INVALID_CALL_ABI
	nested/2 nested/3 nested/4 nested/5 nested/6 nested/7 nested/8 nested/9
	nested/10 nested/11 nested/12 nested/13 nested/14 nested/15 nested/16 nested/17

bad: copy rich-exception-message
bad-offset: (select exception-region-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
add-exception-semantic-error 'BAD-REGION-SECTION-FLAGS
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_SECTION_FLAGS bad-offset
	(select exception-region-section 'ordinal) bad

bad: copy rich-exception-message
bad-offset: (select exception-member-section 'entry-offset)
	+ schema/WIRE_DIRECTORY_FLAGS_OFFSET
fixture-mutations/put-u32 bad bad-offset schema/WIRE_SECTION_FLAG_SORTED
add-exception-semantic-error 'BAD-MEMBER-SECTION-FLAGS
	schema/WIRE_EXCEPTION_ERROR_BAD_BLOCK_MEMBER_SECTION_FLAGS bad-offset
	(select exception-member-section 'ordinal) bad

bad: copy rich-exception-message
bad-offset: select exception-region-section 'payload-offset
fixture-mutations/put-bytes bad bad-offset #{00000080}
add-exception-semantic-error 'SCALAR-RANGE schema/WIRE_EXCEPTION_ERROR_SCALAR_RANGE
	bad-offset (select exception-region-section 'ordinal) bad

mutate-exception-region 'BAD-REGION-FUNCTION 1
	schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET 0
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_FUNCTION
	schema/WIRE_RSIR_EXCEPTION_REGION_FUNCTION_OFFSET

out-of-order-regions: fixture-writer/words reduce [
	1 1 1 13 schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
		schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
	1 2 6 9 schema/WIRE_EXCEPTION_REGION_KIND_FILTER
		schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
	1 8 1 5 schema/WIRE_EXCEPTION_REGION_KIND_FILTER 0
]
out-of-order-members: fixture-writer/words [
	1 11
	2 2  2 3  2 4  2 5  2 6  2 7
	3 3
]
bad: build-exception-message out-of-order-regions out-of-order-members
	exception-blocks exception-values exception-instructions exception-operands
	exception-edges exception-calls
base: exception-record-offset exception-region-section 2
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
add-exception-semantic-error 'BAD-REGION-ORDER schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ORDER
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
	(select exception-region-section 'ordinal) bad

mutate-exception-region 'BAD-REGION-BLOCK-RANGE 1
	schema/WIRE_RSIR_EXCEPTION_REGION_BLOCK_MEMBER_COUNT_OFFSET 0
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_RANGE
	schema/WIRE_RSIR_EXCEPTION_REGION_FIRST_BLOCK_MEMBER_OFFSET
mutate-exception-member 'BAD-REGION-BLOCK-COVERAGE 1
	schema/WIRE_RSIR_EXCEPTION_BLOCK_REGION_OFFSET 2
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BLOCK_COVERAGE
	schema/WIRE_RSIR_EXCEPTION_BLOCK_REGION_OFFSET
mutate-exception-member 'BAD-REGION-MEMBER 1
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET 0
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
mutate-exception-member 'BAD-REGION-MEMBER-ORDER 2
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_MEMBER_ORDER
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
mutate-exception-member 'DUPLICATE-REGION-MEMBER 2
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET 2
	schema/WIRE_EXCEPTION_ERROR_DUPLICATE_REGION_MEMBER
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
mutate-exception-region 'BAD-REGION-HANDLER 1
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET 0
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_HANDLER
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
bad: copy rich-exception-message
base: exception-record-offset exception-region-section 1
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET) 2
base: exception-record-offset exception-member-section 1
	schema/WIRE_RSIR_EXCEPTION_BLOCK_SIZE
add-exception-semantic-error 'HANDLER-IS-MEMBER
	schema/WIRE_EXCEPTION_ERROR_HANDLER_IS_MEMBER
	(base + schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET)
	(select exception-member-section 'ordinal) bad
mutate-exception-region 'DUPLICATE-HANDLER 2
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET 9
	schema/WIRE_EXCEPTION_ERROR_DUPLICATE_HANDLER
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET
mutate-exception-region 'BAD-REGION-KIND 1
	schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET 3
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_KIND
	schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET
mutate-exception-region 'BAD-REGION-FLAGS 2
	schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET 2
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_FLAGS
	schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET
mutate-exception-region 'BAD-REGION-NESTING 2
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET 14
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_NESTING
	schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET

mutate-exception-instruction 'BAD-CATCH-SUBOPCODE 2
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-exception-instruction 'BAD-CATCH-FLAGS 2
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET
mutate-exception-instruction 'BAD-CATCH-RESULT-COUNT 1
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_CATCH_ENTER
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_RESULT_COUNT
	schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET
mutate-exception-instruction 'BAD-CATCH-OPERAND-COUNT 9
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_CATCH_ENTER
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET

bad: copy rich-exception-message
base: exception-record-offset exception-operand-section 2 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	schema/WIRE_OPERAND_KIND_CONSTANT
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 1
add-exception-semantic-error 'BAD-CATCH-OPERAND-KIND
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_OPERAND_KIND
	(base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	(select exception-operand-section 'ordinal) bad

mutate-exception-operand 'NONZERO-CATCH-OPERAND-AUXILIARY 2
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_NONZERO_CATCH_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-exception-operand 'BAD-CATCH-HANDLER 2
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 14
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_HANDLER
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-exception-operand 'BAD-CATCH-FILTER-TYPE 3
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_FILTER_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
bad: copy rich-exception-message
base: exception-record-offset exception-region-section 1
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET) 0
base: exception-record-offset exception-operand-section 3 schema/WIRE_RSIR_OPERAND_SIZE
add-exception-semantic-error 'BAD-CATCH-ALL-FILTER
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_ALL_FILTER
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET)
	(select exception-operand-section 'ordinal) bad
mutate-exception-instruction 'BAD-CATCH-EFFECTS 2
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET 0
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-exception-instruction 'BAD-CATCH-ALIAS 2
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_UNIVERSAL
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

mutate-exception-instruction 'BAD-THROW-SUBOPCODE 15
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_SUBOPCODE
	schema/WIRE_RSIR_INSTRUCTION_SUBOPCODE_OFFSET
mutate-exception-instruction 'BAD-THROW-FLAGS 15
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_FLAGS
	schema/WIRE_RSIR_INSTRUCTION_FLAGS_OFFSET

bad-throw-result-instructions: copy exception-instructions
base: ((14 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE) + 1
fixture-mutations/put-u32 bad-throw-result-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) schema/WIRE_OPCODE_KEEPALIVE
fixture-mutations/put-u32 bad-throw-result-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET) 0
fixture-mutations/put-u32 bad-throw-result-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) 0
base: ((15 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE) + 1
fixture-mutations/put-u32 bad-throw-result-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_FIRST_RESULT_OFFSET) 4
fixture-mutations/put-u32 bad-throw-result-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET) 1
bad-throw-result-values: copy exception-values
base: ((4 - 1) * schema/WIRE_RSIR_VALUE_SIZE) + 1
fixture-mutations/put-u32 bad-throw-result-values
	((base - 1) + schema/WIRE_RSIR_VALUE_DEFINITION_ID_OFFSET) 15
bad-throw-result-operands: copy exception-operands
base: ((19 - 1) * schema/WIRE_RSIR_OPERAND_SIZE) + 1
fixture-mutations/put-u32 bad-throw-result-operands
	((base - 1) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 1
bad: build-exception-message exception-regions exception-members exception-blocks
	bad-throw-result-values bad-throw-result-instructions bad-throw-result-operands
	exception-edges exception-calls
base: exception-record-offset exception-instruction-section 15
	schema/WIRE_RSIR_INSTRUCTION_SIZE
add-exception-semantic-error 'BAD-THROW-RESULT-COUNT
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_RESULT_COUNT
	(base + schema/WIRE_RSIR_INSTRUCTION_RESULT_COUNT_OFFSET)
	(select exception-instruction-section 'ordinal) bad

mutate-exception-instruction 'BAD-THROW-OPERAND-COUNT 29
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_THROW
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_COUNT
	schema/WIRE_RSIR_INSTRUCTION_OPERAND_COUNT_OFFSET
bad: copy rich-exception-message
base: exception-record-offset exception-operand-section 19 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	schema/WIRE_OPERAND_KIND_CONSTANT
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 2
add-exception-semantic-error 'BAD-THROW-OPERAND-KIND
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_OPERAND_KIND
	(base + schema/WIRE_RSIR_OPERAND_KIND_OFFSET)
	(select exception-operand-section 'ordinal) bad
mutate-exception-operand 'NONZERO-THROW-OPERAND-AUXILIARY 19
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_NONZERO_THROW_OPERAND_AUXILIARY
	schema/WIRE_RSIR_OPERAND_AUXILIARY_OFFSET
mutate-exception-operand 'BAD-THROW-TYPE 19
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_TYPE
	schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET
mutate-exception-instruction 'BAD-THROW-EFFECTS 15
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET catch-effects
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_EFFECTS
	schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET
mutate-exception-instruction 'BAD-THROW-ALIAS 15
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET schema/WIRE_ALIAS_KIND_NONE
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_ALIAS
	schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET

mutate-exception-member 'BAD-REGION-ENTRY 1
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET 1
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_ENTRY
	schema/WIRE_RSIR_EXCEPTION_BLOCK_BLOCK_OFFSET
bad: copy rich-exception-message
base: exception-record-offset exception-instruction-section 11
	schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	schema/WIRE_OPCODE_KEEPALIVE
base: exception-record-offset exception-block-section 5 schema/WIRE_RSIR_BLOCK_SIZE
add-exception-semantic-error 'BAD-HANDLER-ENTRY
	schema/WIRE_EXCEPTION_ERROR_BAD_HANDLER_ENTRY base
	(select exception-block-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-operand-section 12 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 5
base: exception-record-offset exception-edge-section 6 schema/WIRE_RSIR_EDGE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET) 5
base: exception-record-offset exception-block-section 5 schema/WIRE_RSIR_BLOCK_SIZE
add-exception-semantic-error 'HANDLER-HAS-ORDINARY-INCOMING
	schema/WIRE_EXCEPTION_ERROR_HANDLER_HAS_ORDINARY_INCOMING base
	(select exception-block-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-instruction-section 9
	schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	schema/WIRE_OPCODE_KEEPALIVE
; Removing block 4's leave prefix first invalidates edge 3 (block 3 -> block 4).
base: exception-record-offset exception-edge-section 3 schema/WIRE_RSIR_EDGE_SIZE
add-exception-semantic-error 'BAD-REGION-BOUNDARY
	schema/WIRE_EXCEPTION_ERROR_BAD_REGION_BOUNDARY
	(base + schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET)
	(select exception-edge-section 'ordinal) bad

bad-leave-instructions: copy exception-instructions
base: ((7 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE) + 1
fixture-mutations/put-u32 bad-leave-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) schema/WIRE_OPCODE_CATCH_LEAVE
fixture-mutations/put-u32 bad-leave-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET) catch-effects
fixture-mutations/put-u32 bad-leave-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_ALIAS_KIND_OFFSET)
	schema/WIRE_ALIAS_KIND_NONE
bad-leave-operands: copy exception-operands
base: ((9 - 1) * schema/WIRE_RSIR_OPERAND_SIZE) + 1
fixture-mutations/put-u32 bad-leave-operands
	((base - 1) + schema/WIRE_RSIR_OPERAND_KIND_OFFSET) schema/WIRE_OPERAND_KIND_BLOCK
fixture-mutations/put-u32 bad-leave-operands
	((base - 1) + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 5
bad-leave-calls: fixture-writer/words reduce [
	22 2 schema/WIRE_CALL_KIND_DIRECT 26 0 0 0 0
]
bad: build-exception-message exception-regions exception-members exception-blocks
	exception-values bad-leave-instructions bad-leave-operands exception-edges
	bad-leave-calls
; Edge 2 enters a leave-prefixed block without exiting a region; report block 3.
base: exception-record-offset exception-block-section 3 schema/WIRE_RSIR_BLOCK_SIZE
add-exception-semantic-error 'BAD-CATCH-LEAVE-POSITION
	schema/WIRE_EXCEPTION_ERROR_BAD_CATCH_LEAVE_POSITION
	base (select exception-block-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-region-section 2
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET)
	schema/WIRE_EXCEPTION_REGION_FLAG_CATCH_ALL
base: exception-record-offset exception-operand-section 7 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 2
base: exception-record-offset exception-block-section 3 schema/WIRE_RSIR_BLOCK_SIZE
add-exception-semantic-error 'BAD-EXCEPTION-EDGE-COUNT
	schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_COUNT
	(base + schema/WIRE_RSIR_BLOCK_OUTGOING_EDGE_COUNT_OFFSET)
	(select exception-block-section 'ordinal) bad

mutate-exception-record 'BAD-EXCEPTION-EDGE-TARGET exception-edge-section 4
	schema/WIRE_RSIR_EDGE_SIZE schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET 9
	schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_EDGE_TARGET
	schema/WIRE_RSIR_EDGE_TARGET_BLOCK_OFFSET

bad-throwing-opcode-instructions: copy exception-instructions
base: ((7 - 1) * schema/WIRE_RSIR_INSTRUCTION_SIZE) + 1
fixture-mutations/put-u32 bad-throwing-opcode-instructions
	((base - 1) + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	schema/WIRE_OPCODE_KEEPALIVE
bad-throwing-opcode-calls: fixture-writer/words reduce [
	22 2 schema/WIRE_CALL_KIND_DIRECT 26 0 0 0 0
]
bad: build-exception-message exception-regions exception-members exception-blocks
	exception-values bad-throwing-opcode-instructions exception-operands
	exception-edges bad-throwing-opcode-calls
base: exception-record-offset exception-instruction-section 7
	schema/WIRE_RSIR_INSTRUCTION_SIZE
add-exception-semantic-error 'BAD-THROWING-OPCODE
	schema/WIRE_EXCEPTION_ERROR_BAD_THROWING_OPCODE
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select exception-instruction-section 'ordinal) bad

throwing-position-instructions: call-section throwing-call-message
	schema/WIRE_RSIR_SECTION_INSTRUCTIONS
base: call-record-offset throwing-position-instructions
	(select call-instruction-ids 'DIRECT-FIXED) schema/WIRE_RSIR_INSTRUCTION_SIZE
add-exception-semantic-error 'BAD-THROW-POSITION
	schema/WIRE_EXCEPTION_ERROR_BAD_THROW_POSITION
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)
	(select throwing-position-instructions 'ordinal) throwing-call-message

bad: copy rich-exception-message
base: select exception-constant-data-section 'payload-offset
fixture-mutations/put-bytes bad base #{0A000000}
base: exception-record-offset exception-region-section 1
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET) 0
base: exception-record-offset exception-signature-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
add-exception-semantic-error 'BAD-EXCEPTION-DECLARATION
	schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_DECLARATION
	(base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(select exception-signature-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-call-section 1 schema/WIRE_RSIR_CALL_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_CALL_SIGNATURE_OFFSET) 3
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_CALL_CALLEE_KIND_OFFSET)
	schema/WIRE_CALL_KIND_IMPORT
base: exception-record-offset exception-operand-section 9 schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 2
base: exception-record-offset exception-instruction-section 7
	schema/WIRE_RSIR_INSTRUCTION_SIZE
add-exception-semantic-error 'BAD-EXTERNAL-THROW
	schema/WIRE_EXCEPTION_ERROR_BAD_EXTERNAL_THROW
	(base + schema/WIRE_RSIR_INSTRUCTION_EFFECT_FLAGS_OFFSET)
	(select exception-instruction-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-signature-section 1 schema/WIRE_RSIR_SIGNATURE_SIZE
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SIGNATURE_CALLING_CONVENTION_OFFSET)
	schema/WIRE_CALLING_CONVENTION_CDECL
fixture-mutations/put-u32 bad (base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(schema/WIRE_FUNCTION_FLAG_CALLBACK + schema/WIRE_FUNCTION_FLAG_MAY_THROW)
add-exception-semantic-error 'BAD-CALLBACK-THROW
	schema/WIRE_EXCEPTION_ERROR_BAD_CALLBACK_THROW
	(base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(select exception-signature-section 'ordinal) bad

mutate-exception-instruction 'BAD-STACK-INTERACTION 4
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET schema/WIRE_OPCODE_STACK_ALLOC
	schema/WIRE_EXCEPTION_ERROR_BAD_STACK_INTERACTION
	schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET

bad: copy rich-exception-message
base: exception-record-offset exception-region-section 1
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_KIND_OFFSET)
	schema/WIRE_EXCEPTION_REGION_KIND_FUNCTION
base: exception-record-offset exception-region-section 2
	schema/WIRE_RSIR_EXCEPTION_REGION_SIZE
add-exception-semantic-error 'BAD-FUNCTION-REGION-OVERLAP
	schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION base
	(select exception-region-section 'ordinal) bad

bad: copy rich-exception-message
base: exception-record-offset exception-instruction-section 24
	schema/WIRE_RSIR_INSTRUCTION_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET) schema/WIRE_OPCODE_KEEPALIVE
base: exception-record-offset exception-block-section 12 schema/WIRE_RSIR_BLOCK_SIZE
add-exception-semantic-error 'BAD-FUNCTION-REGION-SHAPE
	schema/WIRE_EXCEPTION_ERROR_BAD_FUNCTION_REGION base
	(select exception-block-section 'ordinal) bad

subexception-region-section: control-section subroutine-catch-message
	schema/WIRE_RSIR_SECTION_EXCEPTION_REGIONS
subexception-operand-section: control-section subroutine-catch-message
	schema/WIRE_RSIR_SECTION_OPERANDS
subexception-signature-section: control-section subroutine-catch-message
	schema/WIRE_RSIR_SECTION_SIGNATURES

; A region cannot use a host-main handler for a protected block owned by a
; compiler-generated subroutine, even though both blocks share function 1.
bad: copy subroutine-catch-message
base: select subexception-region-section 'payload-offset
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET) 1
add-exception-semantic-error 'BAD-SUBROUTINE-REGION
	schema/WIRE_EXCEPTION_ERROR_BAD_SUBROUTINE_REGION
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_HANDLER_BLOCK_OFFSET)
	(select subexception-region-section 'ordinal) bad

; A non-catch-all filter may propagate beyond its handler. The declaration
; belongs to the enclosing subroutine signature, not the host function.
bad: copy subroutine-catch-message
base: select subexception-region-section 'payload-offset
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_EXCEPTION_REGION_FLAGS_OFFSET) 0
base: (select subexception-operand-section 'payload-offset)
	+ schema/WIRE_RSIR_OPERAND_SIZE
fixture-mutations/put-u32 bad
	(base + schema/WIRE_RSIR_OPERAND_REFERENCE_OFFSET) 2
base: (select subexception-signature-section 'payload-offset)
	+ schema/WIRE_RSIR_SIGNATURE_SIZE
add-exception-semantic-error 'BAD-SUBROUTINE-EXCEPTION-DECLARATION
	schema/WIRE_EXCEPTION_ERROR_BAD_EXCEPTION_DECLARATION
	(base + schema/WIRE_RSIR_SIGNATURE_FLAGS_OFFSET)
	(select subexception-signature-section 'ordinal) bad

valid-exceptions: reduce [
	reduce ['RICH rich-exception-message]
	reduce ['SUBROUTINE-CATCH subroutine-catch-message]
	reduce ['SUBROUTINE-PROPAGATION subroutine-propagation-message]
	reduce ['EMPTY empty-subroutine-message]
]
foreach fixture valid-exceptions [
	result: exception-verifier/verify fixture/2
	assert result/valid? [
		fixture/1 " valid exception module rejected with " result/error
		" subroutine=" result/subroutine-error " call=" result/call-abi-error
		" at " result/error-offset ":" result/error-section
	]
]

result: exception-verifier/verify none
assert to logic! all [
	not result/valid?
	result/error = schema/WIRE_EXCEPTION_ERROR_INVALID_ARGUMENTS
	result/subroutine-error = schema/WIRE_SUBROUTINE_ERROR_SUCCESS
	result/call-abi-error = schema/WIRE_CALL_ABI_ERROR_SUCCESS
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
	none? result/view
]["non-binary exception input did not fail atomically"]

covered-errors: reduce [
	schema/WIRE_EXCEPTION_ERROR_SUCCESS
	schema/WIRE_EXCEPTION_ERROR_INVALID_ARGUMENTS
]
foreach fixture malformed-exceptions [
	result: exception-verifier/verify fixture/18
	assert not result/valid? [fixture/1 " malformed exception module was accepted"]
	assert result/error = fixture/2 [
		fixture/1 " expected error " fixture/2 " got " result/error
		" call=" result/call-abi-error " at " result/error-offset ":" result/error-section
	]
	assert to logic! all [
		result/subroutine-error = fixture/3
		result/call-abi-error = fixture/4
		result/control-flow-error = fixture/5
		result/scalar-operation-error = fixture/6
		result/container-error = fixture/7
		result/string-error = fixture/8
		result/file-source-error = fixture/9
		result/data-layout-error = fixture/10
		result/type-layout-error = fixture/11
		result/function-signature-error = fixture/12
		result/module-lifecycle-error = fixture/13
		result/symbol-linkage-error = fixture/14
		result/constant-initializer-error = fixture/15
		result/error-offset = fixture/16
		result/error-section = fixture/17
	][
		fixture/1 " nested error or location changed: actual="
		result/error-offset ":" result/error-section " expected="
		fixture/16 ":" fixture/17
	]
	assert to logic! all [
		none? result/strings none? result/files none? result/layout
		none? result/types none? result/functions none? result/modules
		none? result/symbols none? result/constants none? result/scalar-view
		none? result/control-view none? result/call-view
		none? result/subroutine-view none? result/view
	][fixture/1 " published output views on failure"]
	append covered-errors fixture/2
]

repeat code 54 [
	assert not none? find covered-errors (code - 1) [
		"exception error code not covered: " code - 1
	]
]

result: exception-verifier/verify rich-exception-message
assert result/valid? "rich exception module failed after malformed corpus"

unless value? 'generating-wire-exception-fixtures? [
	source-bytes: make binary! 8'388'608
	foreach source-file [
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
	][append source-bytes read source-file]
	append source-bytes to binary! mold schema/WIRE_SCHEMA_FINGERPRINT
	source-digest: enbase/base checksum source-bytes 'SHA256 16
	generated-source: to string! read %wire-exception-reds-test.reds
	assert not none? find generated-source source-digest
		"generated Red/System exception fixtures are stale"
]

print [
	"PASS: Red RSIR exceptions regions=" result/view/region-count
	" members=" result/view/block-member-count
	" valid=" length? valid-exceptions
	" malformed=" length? malformed-exceptions
]
