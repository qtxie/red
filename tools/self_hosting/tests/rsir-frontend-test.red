Red [
	Title: "Direct Red/System to RSIR frontend tests"
]

do %../../../compiler/wire-target-intrinsic.red
do %../../../compiler/wire-atomic.red
do %../../../compiler/wire-memory-aggregate.red
do %../../../compiler/rsir-frontend.red

schema: compiler-wire-schema
frontend: compiler-rsir-frontend
container: compiler-wire-container

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

compile-text: func [
	text [string!]
	module-kind [word!]
	/limit max-bytes [integer!]
	/local source
][
	source: load text
	either limit [
		frontend/compile/limit source none module-kind 'executable max-bytes
	][
		frontend/compile source none module-kind 'executable
	]
]

verify-rsir: func [name [string!] data [binary!] /local result][
	result: compiler-wire-target-intrinsic/verify data
	assert result/valid? [name " target verifier error=" result/error]
	result: compiler-wire-atomic/verify data
	assert result/valid? [name " atomic verifier error=" result/error]
	result: compiler-wire-memory-aggregate/verify data
	assert result/valid? [name " memory verifier error=" result/error]
]

void-rsir: compile-text
	{Red/System [] fn: func [][]}
	'user
assert binary? void-rsir [
	"frontend rejected an empty void function: " mold frontend/last-error
]
assert none? frontend/last-error "frontend retained an error after success"
assert (length? void-rsir) = 1396 "empty void RSIR size changed"
assert (checksum void-rsir 'SHA256) =
	#{8353248CDBC69D83181C09D2668C4DF1879503004D23C890B079953F2EEA8DBE}
	"empty void RSIR bytes changed"
verify-rsir "void" void-rsir
assert void-rsir = compile-text
	{Red/System [] fn: function [][]}
	'user
	"func and function spellings produced different RSIR"

glue-rsir: compile-text
	{Red/System [] fn: func [][]}
	'glue
assert binary? glue-rsir "frontend rejected a glue entry"
verify-rsir "glue" glue-rsir
parsed: container/verify/expect glue-rsir schema/WIRE_MAGIC_RSIR
assert parsed/valid? "glue RSIR failed container verification"
module-section: container/find-section parsed schema/WIRE_RSIR_SECTION_MODULE
module-offset: select module-section 'payload-offset
assert (container/read-u32 glue-rsir
	(module-offset + schema/WIRE_RSIR_MODULE_ENTRY_FUNCTION_OFFSET)) = 1
	"glue module lost its entry function"

i32-rsir: compile-text
	{Red/System [] fn: func [return: [integer!]][7]}
	'user
assert binary? i32-rsir "frontend rejected an i32 literal result"
verify-rsir "i32" i32-rsir
assert i32-rsir = compile-text
	{Red/System [] fn: func [return: [int32!]][return 7]}
	'user
	"equivalent i32 source forms produced different RSIR"

parsed: container/verify/expect i32-rsir schema/WIRE_MAGIC_RSIR
assert parsed/valid? "i32 RSIR failed container verification"
types-section: container/find-section parsed schema/WIRE_RSIR_SECTION_TYPES
signature-section: container/find-section parsed schema/WIRE_RSIR_SECTION_SIGNATURES
constant-section: container/find-section parsed schema/WIRE_RSIR_SECTION_CONSTANTS
constant-data-section: container/find-section parsed schema/WIRE_RSIR_SECTION_CONSTANT_DATA
block-section: container/find-section parsed schema/WIRE_RSIR_SECTION_BLOCKS
value-section: container/find-section parsed schema/WIRE_RSIR_SECTION_VALUES
instruction-section: container/find-section parsed schema/WIRE_RSIR_SECTION_INSTRUCTIONS
operand-section: container/find-section parsed schema/WIRE_RSIR_SECTION_OPERANDS
assert all [
	(select types-section 'record-count) = 2
	(select constant-section 'record-count) = 1
	(select value-section 'record-count) = 1
	(select instruction-section 'record-count) = 2
	(select operand-section 'record-count) = 2
]["i32 frontend emitted the wrong table cardinalities"]
assert (container/read-u32 i32-rsir
	((select signature-section 'payload-offset)
		+ schema/WIRE_RSIR_SIGNATURE_RETURN_TYPE_OFFSET)) = 2
	"i32 function signature has the wrong return type"
assert (container/read-u32 i32-rsir
	(select constant-data-section 'payload-offset)) = 7
	"i32 literal bytes changed"
assert (container/read-u32 i32-rsir
	((select block-section 'payload-offset)
		+ schema/WIRE_RSIR_BLOCK_INSTRUCTION_COUNT_OFFSET)) = 2
	"i32 function block does not contain constant and return"
assert (container/read-u32 i32-rsir
	((select instruction-section 'payload-offset)
		+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)) = schema/WIRE_OPCODE_CONSTANT
	"i32 literal did not lower to CONSTANT"
assert (container/read-u32 i32-rsir
	((select instruction-section 'payload-offset)
		+ schema/WIRE_RSIR_INSTRUCTION_SIZE
		+ schema/WIRE_RSIR_INSTRUCTION_OPCODE_OFFSET)) = schema/WIRE_OPCODE_RETURN
	"i32 result did not lower to RETURN"

named-rsir: frontend/compile
	load {Red/System [] fn: func [][]}
	"z-module"
	'support
	'executable
assert binary? named-rsir "frontend rejected a named support module"
verify-rsir "named" named-rsir

assert none? compile-text/limit
	{Red/System [] fn: func [][]}
	'user
	1395
	"frontend ignored its RSIR output limit"
assert frontend/last-error/code = frontend/ERROR-LIMIT
	"frontend reported the wrong output-limit error"

assert none? frontend/compile
	load {Red/System [] fn: func [][]}
	""
	'user
	'executable
	"frontend accepted an empty present module name"
assert frontend/last-error/code = frontend/ERROR-NAME
	"frontend reported the wrong module-name error"

assert none? compile-text
	{Red/System []}
	'user
	"frontend accepted a module without a function"
assert frontend/last-error/code = frontend/ERROR-FUNCTION-COUNT
	"frontend reported the wrong missing-function error"

assert none? compile-text
	{Red/System [] first: func [][] second: func [][]}
	'user
	"frontend accepted a second function outside its current slice"
assert frontend/last-error/code = frontend/ERROR-FUNCTION-COUNT
	"frontend reported the wrong duplicate-function error"

assert none? compile-text
	{Red/System [] fn: func [value [integer!]][]}
	'user
	"frontend accepted an unsupported parameter"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong parameter error"

assert none? compile-text
	{Red/System [] fn: func [][1]}
	'user
	"frontend accepted a value from a void function"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong void-body error"

assert none? compile-text
	{Red/System [] 1}
	'user
	"frontend accepted a root expression"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong root-expression error"

print "PASS: direct Red/System to RSIR frontend"
