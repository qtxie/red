Red [
	Title: "Compact Red/System IR frontend tests"
]

do %../../../compiler/rsir-frontend.red

frontend: compiler-rsir-frontend

assert: func [condition [logic!] message [string! block!]][
	unless condition [
		print ["FAIL:" either block? message [rejoin message][message]]
		quit/return 1
	]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ (high * 16777216)
]

compile-text: func [
	text [string!]
	kind [word!]
	/limit max-bytes [integer!]
][
	either limit [
		frontend/compile/limit load text none kind 'executable max-bytes
	][
		frontend/compile load text none kind 'executable
	]
]

void-ir: compile-text {Red/System [] fn: func [][]} 'user
assert binary? void-ir ["frontend rejected void function: " mold frontend/last-error]
assert none? frontend/last-error "frontend retained an error after success"
assert (length? void-ir) = 78 "void RSIR is not compact"
assert all [
	(word-at void-ir 0) = 78
	(word-at void-ir 4) = 1
	(word-at void-ir 8) = 0
	(word-at void-ir 12) = 0
	(word-at void-ir 16) = 0
	(word-at void-ir 20) = 1
	(word-at void-ir 24) = 1
	(word-at void-ir 28) = 2
]["void RSIR header changed"]
assert all [
	(word-at void-ir 32) = 0
	(word-at void-ir 36) = 2
	(word-at void-ir 40) = 0
	(word-at void-ir 44) = 1
	(word-at void-ir 48) = 1
	(word-at void-ir 52) = 0
]["void function record changed"]
assert all [
	(word-at void-ir 56) = 2
	(word-at void-ir 60) = 0
	(word-at void-ir 64) = 0
	(word-at void-ir 68) = 0
	(word-at void-ir 72) = 0
	(copy at void-ir 77) = #{666E}
]["void instructions or name changed"]
assert void-ir = compile-text {Red/System [] fn: function [][]} 'user
	"func and function produced different RSIR"

glue-ir: compile-text {Red/System [] fn: func [][]} 'glue
assert all [(word-at glue-ir 4) = 3 (word-at glue-ir 8) = 1]
	"glue module lost its entry function"

i32-ir: compile-text {Red/System [] fn: func [return: [integer!]][7]} 'user
assert binary? i32-ir "frontend rejected i32 literal"
assert (length? i32-ir) = 98 "i32 RSIR is not compact"
assert all [
	(word-at i32-ir 24) = 2
	(word-at i32-ir 40) = 1
	(word-at i32-ir 48) = 2
	(word-at i32-ir 56) = 1
	(word-at i32-ir 60) = 1
	(word-at i32-ir 64) = 1
	(word-at i32-ir 68) = 0
	(word-at i32-ir 72) = 7
	(word-at i32-ir 76) = 2
	(word-at i32-ir 80) = 1
	(word-at i32-ir 88) = 1
]["i32 literal/return instructions changed"]
assert i32-ir = compile-text
	{Red/System [] fn: func [return: [int32!]][return 7]}
	'user
	"equivalent i32 source forms produced different RSIR"

named-ir: frontend/compile
	load {Red/System [] fn: func [][]}
	"z-module"
	'support
	'executable
assert binary? named-ir "frontend rejected named support module"
assert all [
	(length? named-ir) = 86
	(word-at named-ir 4) = 2
	(word-at named-ir 16) = 8
	(word-at named-ir 32) = 8
	(copy/part at named-ir 77 8) = #{7A2D6D6F64756C65}
	(copy at named-ir 85) = #{666E}
]["named module string layout changed"]

assert none? compile-text/limit
	{Red/System [] fn: func [][]}
	'user
	77
	"frontend ignored its output limit"
assert frontend/last-error/code = frontend/ERROR-LIMIT
	"frontend reported the wrong output-limit error"

assert none? frontend/compile
	load {Red/System [] fn: func [][]}
	""
	'user
	'executable
	"frontend accepted an empty module name"
assert frontend/last-error/code = frontend/ERROR-NAME
	"frontend reported the wrong module-name error"

assert none? compile-text {Red/System []} 'user
	"frontend accepted a module without a function"
assert frontend/last-error/code = frontend/ERROR-FUNCTION-COUNT
	"frontend reported the wrong missing-function error"

multi-ir: compile-text {
	Red/System []
	helper: func [return: [integer!]][41]
	main: func [return: [integer!]][helper]
} 'glue
assert binary? multi-ir ["frontend rejected direct call: " mold frontend/last-error]
assert (length? multi-ir) = 170 "multi-function RSIR size changed"
assert all [
	(word-at multi-ir 0) = 170
	(word-at multi-ir 8) = 2
	(word-at multi-ir 20) = 2
	(word-at multi-ir 24) = 4
	(word-at multi-ir 28) = 10
]["multi-function RSIR header changed"]
assert all [
	(word-at multi-ir 32) = 0
	(word-at multi-ir 36) = 6
	(word-at multi-ir 44) = 1
	(word-at multi-ir 48) = 2
	(word-at multi-ir 56) = 6
	(word-at multi-ir 60) = 4
	(word-at multi-ir 68) = 3
	(word-at multi-ir 72) = 2
]["source-order function records changed"]
assert all [
	(word-at multi-ir 80) = 1
	(word-at multi-ir 96) = 41
	(word-at multi-ir 120) = 3
	(word-at multi-ir 132) = 1
	(copy at multi-ir 161) = #{68656C7065726D61696E}
]["literal/call lowering or function names changed"]

forward-ir: compile-text {
	Red/System []
	main: func [return: [integer!]][helper]
	helper: func [return: [integer!]][41]
} 'user
assert binary? forward-ir "frontend did not resolve a forward function call"
assert (word-at forward-ir 92) = 2 "forward call has the wrong stable function ID"

assert none? compile-text {
	Red/System []
	fn: func [][]
	fn: func [][]
} 'user "frontend accepted a duplicate function"
assert frontend/last-error/code = frontend/ERROR-DUPLICATE
	"frontend reported the wrong duplicate-function error"

assert none? compile-text
	{Red/System [] fn: func [value [integer!]][]}
	'user
	"frontend accepted an unsupported parameter"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong parameter error"

assert none? compile-text {Red/System [] fn: func [][1]} 'user
	"frontend accepted a value from a void function"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong void-body error"

assert none? compile-text {Red/System [] 1} 'user
	"frontend accepted a root expression"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong root-expression error"

print "PASS: compact Red/System IR frontend"
