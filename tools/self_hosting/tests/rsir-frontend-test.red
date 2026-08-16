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
		frontend/compile/limit load text kind max-bytes
	][
		frontend/compile load text kind
	]
]

void-ir: compile-text {Red/System [] fn: func [][]} 'user
assert binary? void-ir ["frontend rejected void function: " mold frontend/last-error]
assert none? frontend/last-error "frontend retained an error after success"
assert (length? void-ir) = 50 "void RSIR is not compact"
assert all [
	(word-at void-ir 0) = 1
	(word-at void-ir 4) = 0
	(word-at void-ir 8) = 1
	(word-at void-ir 12) = 1
]["void RSIR header changed"]
assert all [
	(word-at void-ir 16) = 0
	(word-at void-ir 20) = 2
	(word-at void-ir 24) = 0
	(word-at void-ir 28) = 1
	(word-at void-ir 32) = 2
	(word-at void-ir 36) = 0
	(word-at void-ir 40) = 0
	(word-at void-ir 44) = 0
	(copy at void-ir 49) = #{666E}
]["void function stream changed"]
assert void-ir = compile-text {Red/System [] fn: function [][]} 'user
	"func and function produced different RSIR"

glue-ir: compile-text {Red/System [] fn: func [][]} 'glue
assert all [(word-at glue-ir 0) = 3 (word-at glue-ir 4) = 1]
	"glue module lost its entry function"

i32-ir: compile-text {Red/System [] fn: func [return: [integer!]][7]} 'user
assert binary? i32-ir "frontend rejected i32 literal"
assert (length? i32-ir) = 66 "i32 RSIR is not compact"
assert all [
	(word-at i32-ir 12) = 2
	(word-at i32-ir 24) = 1
	(word-at i32-ir 28) = 2
	(word-at i32-ir 32) = 1
	(word-at i32-ir 36) = 1
	(word-at i32-ir 40) = 0
	(word-at i32-ir 44) = 7
	(word-at i32-ir 48) = 3
	(word-at i32-ir 56) = 1
]["i32 literal/return stream changed"]
assert i32-ir = compile-text
	{Red/System [] fn: func [return: [int32!]][return 7]}
	'user
	"equivalent i32 source forms produced different RSIR"

assert none? compile-text/limit {Red/System [] fn: func [][]} 'user 49
	"frontend ignored its output limit"
assert frontend/last-error/code = frontend/ERROR-LIMIT
	"frontend reported the wrong output-limit error"

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
assert (length? multi-ir) = 122 "multi-function RSIR size changed"
assert all [
	(word-at multi-ir 0) = 3
	(word-at multi-ir 4) = 2
	(word-at multi-ir 8) = 2
	(word-at multi-ir 12) = 4
	(word-at multi-ir 16) = 0
	(word-at multi-ir 20) = 6
	(word-at multi-ir 24) = 1
	(word-at multi-ir 28) = 2
	(word-at multi-ir 32) = 6
	(word-at multi-ir 36) = 4
]["multi-function header or records changed"]
assert all [
	(word-at multi-ir 48) = 1
	(word-at multi-ir 60) = 41
	(word-at multi-ir 80) = 4
	(word-at multi-ir 88) = 1
	(copy at multi-ir 113) = #{68656C7065726D61696E}
]["literal/call lowering or function names changed"]

forward-ir: compile-text {
	Red/System []
	main: func [return: [integer!]][helper]
	helper: func [return: [integer!]][41]
} 'user
assert binary? forward-ir "frontend did not resolve a forward function call"
assert (word-at forward-ir 56) = 2 "forward call has the wrong function ID"

assert none? compile-text {
	Red/System []
	fn: func [][]
	fn: func [][]
} 'user "frontend accepted a duplicate function"
assert frontend/last-error/code = frontend/ERROR-DUPLICATE
	"frontend reported the wrong duplicate-function error"

context-ir: compile-text {
	Red/System []
	qualified: context [
		helper: func [return: [integer!]][42]
		inside: func [return: [integer!]][helper]
	]
	main: func [return: [integer!]][qualified/inside]
} 'glue
assert binary? context-ir ["frontend rejected context calls: " mold frontend/last-error]
assert all [
	(length? context-ir) = 196
	(word-at context-ir 4) = 3
	(word-at context-ir 8) = 3
	(word-at context-ir 12) = 6
	(word-at context-ir 16) = 0
	(word-at context-ir 32) = 16
	(word-at context-ir 48) = 32
	(word-at context-ir 104) = 1
	(word-at context-ir 136) = 2
	(copy at context-ir 161) =
		#{7175616C69666965643E68656C7065727175616C69666965643E696E736964656D61696E}
]["context naming, resolution, or source-order IDs changed"]

assert none? compile-text {
	Red/System []
	with missing [fn: func [][]]
} 'user "frontend accepted an unknown WITH context"
assert frontend/last-error/code = frontend/ERROR-CONTEXT
	"frontend reported the wrong WITH-context error"

with-ir: compile-text {
	Red/System []
	base: context [helper: func [return: [integer!]][43]]
	with base [inside: func [return: [integer!]][helper]]
	main: func [return: [integer!]][inside]
} 'glue
assert binary? with-ir ["frontend rejected WITH resolution: " mold frontend/last-error]
assert all [
	(length? with-ir) = 181
	(word-at with-ir 8) = 3
	(word-at with-ir 20) = 11
	(word-at with-ir 36) = 6
	(word-at with-ir 104) = 1
	(word-at with-ir 136) = 2
	(copy at with-ir 161) = #{626173653E68656C706572696E736964656D61696E}
]["WITH changed declaration scope or imported-name resolution"]

parameter-ir: compile-text {
	Red/System []
	node-handle!: alias integer!
	helper: func [value [node-handle!] return: [integer!]][value]
	main: func [return: [integer!]][helper 42]
} 'glue
assert binary? parameter-ir ["frontend rejected scalar alias parameter: " mold frontend/last-error]
assert all [
	(length? parameter-ir) = 122
	(word-at parameter-ir 12) = 4
	(word-at parameter-ir 24) = 2
	(word-at parameter-ir 28) = 1
	(word-at parameter-ir 40) = 1
	(word-at parameter-ir 44) = 3
	(word-at parameter-ir 48) = 3
	(word-at parameter-ir 56) = 1
	(word-at parameter-ir 64) = 1
	(word-at parameter-ir 76) = 42
	(word-at parameter-ir 80) = 4
	(word-at parameter-ir 84) = 2
	(word-at parameter-ir 88) = 1
	(word-at parameter-ir 92) = 1
	(word-at parameter-ir 96) = 3
	(word-at parameter-ir 104) = 2
]["one-parameter direct stream changed"]

assert none? compile-text
	{Red/System [] fn: func [value [integer!]][]}
	'user
	"frontend accepted an unsupported void parameter"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong void-parameter error"

assert none? compile-text {
	Red/System []
	fn: func [a [integer!] b [integer!] return: [integer!]][a]
} 'user "frontend accepted two parameters"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong multi-parameter error"

assert none? compile-text {Red/System [] fn: func [][1]} 'user
	"frontend accepted a value from a void function"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong void-body error"

assert none? compile-text {Red/System [] 1} 'user
	"frontend accepted a root expression"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong root-expression error"

print "PASS: compact Red/System IR frontend"
