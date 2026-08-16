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
		+ ((either high > 127 [high - 256][high]) * 16777216)
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
assert (length? void-ir) = 74 "void RSIR is not compact"
assert all [
	(word-at void-ir 0) = 1
	(word-at void-ir 4) = 0
	(word-at void-ir 8) = 0
	(word-at void-ir 12) = 0
	(word-at void-ir 16) = 1
	(word-at void-ir 20) = 1
	(word-at void-ir 24) = 0
]["void RSIR header changed"]
assert all [
	(word-at void-ir 28) = 0
	(word-at void-ir 32) = 2
	(word-at void-ir 36) = 0
	(word-at void-ir 40) = 0
	(word-at void-ir 44) = 0
	(word-at void-ir 48) = 0
	(word-at void-ir 52) = 1
	(word-at void-ir 56) = 2
	(word-at void-ir 60) = 0
	(word-at void-ir 64) = 0
	(word-at void-ir 68) = 0
	(copy at void-ir 73) = #{666E}
]["void function stream changed"]
assert void-ir = compile-text {Red/System [] fn: function [][]} 'user
	"func and function produced different RSIR"

glue-ir: compile-text {Red/System [] fn: func [][]} 'glue
assert all [(word-at glue-ir 0) = 3 (word-at glue-ir 4) = 1]
	"glue module lost its entry function"

i32-ir: compile-text {Red/System [] fn: func [return: [integer!]][7]} 'user
assert binary? i32-ir "frontend rejected i32 literal"
assert (length? i32-ir) = 90 "i32 RSIR is not compact"
assert all [
	(word-at i32-ir 20) = 2
	(word-at i32-ir 36) = -5
	(word-at i32-ir 40) = 0
	(word-at i32-ir 48) = 0
	(word-at i32-ir 52) = 2
	(word-at i32-ir 56) = 1
	(word-at i32-ir 60) = 1
	(word-at i32-ir 68) = 7
	(word-at i32-ir 72) = 3
	(word-at i32-ir 80) = 1
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
assert (length? multi-ir) = 158 "multi-function RSIR size changed"
assert all [
	(word-at multi-ir 0) = 3
	(word-at multi-ir 4) = 2
	(word-at multi-ir 8) = 0
	(word-at multi-ir 12) = 0
	(word-at multi-ir 16) = 2
	(word-at multi-ir 20) = 4
	(word-at multi-ir 28) = 0
	(word-at multi-ir 32) = 6
	(word-at multi-ir 36) = -5
	(word-at multi-ir 52) = 2
	(word-at multi-ir 56) = 6
	(word-at multi-ir 60) = 4
	(word-at multi-ir 64) = -5
	(word-at multi-ir 80) = 2
]["multi-function header or records changed"]
assert all [
	(word-at multi-ir 84) = 1
	(word-at multi-ir 96) = 41
	(word-at multi-ir 116) = 4
	(word-at multi-ir 124) = 1
	(copy at multi-ir 149) = #{68656C7065726D61696E}
]["literal/call lowering or function names changed"]

forward-ir: compile-text {
	Red/System []
	main: func [return: [integer!]][helper]
	helper: func [return: [integer!]][41]
} 'user
assert binary? forward-ir "frontend did not resolve a forward function call"
assert (word-at forward-ir 92) = 2 "forward call has the wrong function ID"

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
	(length? context-ir) = 244
	(word-at context-ir 4) = 3
	(word-at context-ir 8) = 0
	(word-at context-ir 12) = 0
	(word-at context-ir 16) = 3
	(word-at context-ir 20) = 6
	(word-at context-ir 28) = 0
	(word-at context-ir 56) = 16
	(word-at context-ir 84) = 32
	(word-at context-ir 152) = 1
	(word-at context-ir 184) = 2
	(copy at context-ir 209) =
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
	(length? with-ir) = 229
	(word-at with-ir 16) = 3
	(word-at with-ir 32) = 11
	(word-at with-ir 60) = 6
	(word-at with-ir 152) = 1
	(word-at with-ir 184) = 2
	(copy at with-ir 209) = #{626173653E68656C706572696E736964656D61696E}
]["WITH changed declaration scope or imported-name resolution"]

parameter-ir: compile-text {
	Red/System []
	node-handle!: alias integer!
	helper: func [value [node-handle!] return: [integer!]][value]
	main: func [return: [integer!]][helper 42]
} 'glue
assert binary? parameter-ir ["frontend rejected scalar alias parameter: " mold frontend/last-error]
assert all [
	(length? parameter-ir) = 186
	(word-at parameter-ir 8) = 1
	(word-at parameter-ir 20) = 4
	(word-at parameter-ir 28) = -1
	(word-at parameter-ir 32) = -5
	(word-at parameter-ir 36) = 0
	(word-at parameter-ir 44) = 0
	(word-at parameter-ir 48) = 0
	(word-at parameter-ir 52) = 6
	(word-at parameter-ir 56) = -5
	(word-at parameter-ir 64) = 0
	(word-at parameter-ir 68) = 1
	(word-at parameter-ir 72) = 1
	(word-at parameter-ir 76) = 6
	(word-at parameter-ir 92) = 1
	(word-at parameter-ir 96) = 0
	(word-at parameter-ir 100) = 3
	(word-at parameter-ir 104) = 1
	(word-at parameter-ir 112) = 3
	(word-at parameter-ir 120) = 1
	(word-at parameter-ir 128) = 1
	(word-at parameter-ir 140) = 42
	(word-at parameter-ir 144) = 4
	(word-at parameter-ir 148) = 2
	(word-at parameter-ir 152) = 1
	(word-at parameter-ir 156) = 1
	(word-at parameter-ir 160) = 3
	(word-at parameter-ir 168) = 2
]["one-parameter direct stream changed"]

logical-types-ir: compile-text {
	Red/System []
	byte-alias!: alias byte!
	small!: alias struct! [
		mark [byte-alias!]
		count [integer!]
		wide [uint64!]
	]
	nested!: alias struct! [
		head [byte!]
		sub [small! value]
		tail [uint16!]
	]
	refs!: alias struct! [
		sub [small!]
		ptr [pointer! [integer!]]
	]
	#enum choice! [CHOICE_ZERO CHOICE_FOUR: 4 CHOICE_FIVE]
	fn: func [][]
} 'user
assert binary? logical-types-ir [
	"frontend rejected logical types: " mold frontend/last-error
]
assert frontend/type-count = 5 "type declarations lost source-order IDs"
assert all [
	(length? logical-types-ir) = 238
	(word-at logical-types-ir 8) = 5
	(word-at logical-types-ir 12) = 0
	(word-at logical-types-ir 16) = 1
	(word-at logical-types-ir 20) = 1
	(word-at logical-types-ir 28) = -1
	(word-at logical-types-ir 32) = -2
	(word-at logical-types-ir 40) = 0
	(word-at logical-types-ir 44) = 0
	(word-at logical-types-ir 48) = -2
	(word-at logical-types-ir 60) = 0
	(word-at logical-types-ir 64) = 3
	(word-at logical-types-ir 68) = -2
	(word-at logical-types-ir 80) = 3
	(word-at logical-types-ir 84) = 3
	(word-at logical-types-ir 88) = -2
	(word-at logical-types-ir 100) = 6
	(word-at logical-types-ir 104) = 2
	(word-at logical-types-ir 108) = 5
	(word-at logical-types-ir 120) = 8
	(word-at logical-types-ir 124) = 0
] "logical type records changed"
assert all [
	(word-at logical-types-ir 128) = 1
	(word-at logical-types-ir 136) = -5
	(word-at logical-types-ir 144) = -8
	(word-at logical-types-ir 152) = -2
	(word-at logical-types-ir 160) = 2
	(word-at logical-types-ir 164) = 1
	(word-at logical-types-ir 168) = -4
	(word-at logical-types-ir 176) = 2
	(word-at logical-types-ir 184) = -12
] "logical member records changed"
byte-alias: frontend/types
small: skip frontend/types 5
nested: skip frontend/types 10
refs: skip frontend/types 15
choice: skip frontend/types 20
assert all [
	(select frontend/type-ids 'byte-alias!) = 1
	(select frontend/type-ids 'small!) = 2
	(select frontend/type-ids 'nested!) = 3
	(select frontend/type-ids 'refs!) = 4
	(select frontend/type-ids 'choice!) = 5
] "type IDs are not source ordered"
assert all [
	byte-alias/2 = 'alias
	byte-alias/3 = 'byte!
	small/2 = 'struct
	small/3 = [
		mark [byte-alias!]
		count [integer!]
		wide [uint64!]
	]
	nested/2 = 'struct
	refs/2 = 'struct
	choice/2 = 'i32
	(frontend/type-kind [byte-alias!] [] []) = 'u8
	(frontend/type-kind [small!] [] []) = 'pointer
	(frontend/type-kind [small! value] [] []) = 'struct
	(frontend/type-kind [pointer! [integer!]] [] []) = 'pointer
	(select frontend/constants 'CHOICE_ZERO) = 0
	(select frontend/constants 'CHOICE_FOUR) = 4
	(select frontend/constants 'CHOICE_FIVE) = 5
] "logical type declarations or aliases changed"

callable-types-ir: compile-text {
	Red/System []
	small!: alias struct! [value [integer!]]
	callback!: alias function! [
		[cdecl]
		input count [integer!]
		state [small! value]
		return: [small! value]
	]
	worker!: alias subroutine! [
		[callback]
		value [uint32!]
	]
	fn: func [][]
} 'user
assert binary? callable-types-ir [
	"frontend rejected callable logical types: " mold frontend/last-error
]
assert all [
	(length? callable-types-ir) = 174
	(word-at callable-types-ir 28) = -2
	(word-at callable-types-ir 40) = 0
	(word-at callable-types-ir 44) = 1
	(word-at callable-types-ir 48) = -4
	(word-at callable-types-ir 52) = 1
	(word-at callable-types-ir 56) = 5
	(word-at callable-types-ir 60) = 1
	(word-at callable-types-ir 64) = 3
	(word-at callable-types-ir 68) = -5
	(word-at callable-types-ir 72) = 0
	(word-at callable-types-ir 76) = 64
	(word-at callable-types-ir 80) = 4
	(word-at callable-types-ir 84) = 1
]["callable type records changed"]
assert all [
	(word-at callable-types-ir 88) = -5
	(word-at callable-types-ir 96) = -5
	(word-at callable-types-ir 104) = -5
	(word-at callable-types-ir 112) = 1
	(word-at callable-types-ir 116) = 1
	(word-at callable-types-ir 120) = -6
]["callable parameter slices changed"]

cdecl-ir: compile-text {
	Red/System []
	fn: func [[cdecl] value [integer!] return: [integer!]][value]
} 'user
assert all [
	binary? cdecl-ir
	(length? cdecl-ir) = 82
	(word-at cdecl-ir 36) = -5
	(word-at cdecl-ir 40) = 1
	(word-at cdecl-ir 44) = 0
	(word-at cdecl-ir 48) = 1
	(word-at cdecl-ir 56) = -5
	(word-at cdecl-ir 60) = 0
]["declared function signature is not direct logical data"]

internal-signature: frontend/read-signature
	[[variadic red-internal] count [integer!]] [] []
assert all [
	internal-signature/1 = 0
	internal-signature/3 = frontend/variadic-flag
	internal-signature/2 = [count -5 0]
]["red-internal import attributes changed logical signature parsing"]

layout-ir: compile-text {
	Red/System []
	byte-alias!: alias byte!
	small!: alias struct! [
		mark [byte-alias!]
		count [integer!]
		wide [uint64!]
	]
	fn: func [return: [integer!]][size? small!]
} 'user
assert binary? layout-ir ["frontend rejected size?: " mold frontend/last-error]
assert all [
	(length? layout-ir) = 154
	(word-at layout-ir 8) = 2
	(word-at layout-ir 20) = 2
	(word-at layout-ir 28) = -1
	(word-at layout-ir 32) = -2
	(word-at layout-ir 48) = -2
	(word-at layout-ir 60) = 0
	(word-at layout-ir 64) = 3
	(word-at layout-ir 120) = 5
	(word-at layout-ir 124) = 1
	(word-at layout-ir 128) = 2
	(word-at layout-ir 132) = 0
	(word-at layout-ir 136) = 3
	(word-at layout-ir 144) = 1
] "size? did not keep target layout behind a logical type reference"

pointer-size-ir: compile-text {
	Red/System []
	fn: func [return: [integer!]][size? pointer! [integer!]]
} 'user
assert all [
	binary? pointer-size-ir
	(length? pointer-size-ir) = 90
	(word-at pointer-size-ir 56) = 5
	(word-at pointer-size-ir 64) = -12
] "parameterized pointer size? did not use the builtin logical type"

assert none? compile-text {
	Red/System []
	fn: func [return: [integer!]][size? 1]
} 'user "frontend accepted a non-type size? operand"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong size? operand error"

recursive-ir: compile-text {
	Red/System []
	node-ref!: alias node!
	node!: alias struct! [next [node-ref!]]
	peer!: alias struct! [node [node!] self [peer!]]
	fn: func [][]
} 'user
assert binary? recursive-ir [
	"frontend rejected recursive logical types: " mold frontend/last-error
]
node-ref: frontend/types
node: skip frontend/types 5
peer: skip frontend/types 10
assert all [
	node-ref/2 = 'alias
	node-ref/3 = 'node!
	node/3 = [next [node-ref!]]
	peer/3 = [node [node!] self [peer!]]
	(frontend/type-kind [node-ref!] [] []) = 'pointer
	(frontend/type-kind [node-ref! value] [] []) = 'struct
] "forward alias or recursive logical type changed"

assert none? compile-text {
	Red/System []
	a!: alias b!
	b!: alias a!
	fn: func [value [a!] return: [integer!]][value]
} 'user "frontend accepted a cyclic alias"
assert frontend/last-error/code = frontend/ERROR-REFERENCE
	"frontend reported the wrong cyclic-alias error"

assert none? compile-text {
	Red/System []
	broken!: alias struct!
	fn: func [][]
} 'user "frontend accepted an aggregate alias without a spec"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong incomplete-alias error"

script-ir: compile-text {
	Red/System []
	#script %expanded-source.reds
	fn: func [][]
} 'user
assert script-ir = void-ir "loader script metadata changed RSIR"

declaration-source: {
	Red/System []
	#script %expanded-source.reds
	node-handle!: alias integer!
	record!: alias struct! [value [integer!]]
	#enum flags! [FLAG_ZERO FLAG_FOUR: 4 FLAG_FIVE]
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
	]]
	root-value: 1
	fn: func [return: [integer!]][1]
}
declaration-ir: compile-text declaration-source 'user
assert binary? declaration-ir [
	"frontend rejected static global declarations: " mold frontend/last-error
]
assert all [
	frontend/function-count = 1
	frontend/import-count = 1
	frontend/global-count = 1
	frontend/type-count = 3
	((length? frontend/constants) / 2) = 3
	(select frontend/constants 'FLAG_ZERO) = 0
	(select frontend/constants 'FLAG_FOUR) = 4
	(select frontend/constants 'FLAG_FIVE) = 5
	(select frontend/import-ids 'native-call) = 1
	(select frontend/globals 'root-value) = 1
]["declaration pass stopped before the complete source block"]
assert all [
	(length? declaration-ir) = 250
	(word-at declaration-ir 24) = 1
	(word-at declaration-ir 128) = 22
	(word-at declaration-ir 132) = 10
	(word-at declaration-ir 136) = -5
	(word-at declaration-ir 140) = 1
	(word-at declaration-ir 144) = 0
]["static global record is not direct logical data"]

static-globals-ir: compile-text {
	Red/System []
	answer: 42
	ready?: true
	fn: func [return: [integer!]][answer]
} 'user
assert binary? static-globals-ir [
	"frontend rejected static scalar globals: " mold frontend/last-error
]
assert all [
	(length? static-globals-ir) = 142
	(word-at static-globals-ir 24) = 2
	(word-at static-globals-ir 28) = 0
	(word-at static-globals-ir 32) = 6
	(word-at static-globals-ir 36) = -5
	(word-at static-globals-ir 40) = 42
	(word-at static-globals-ir 48) = 6
	(word-at static-globals-ir 52) = 6
	(word-at static-globals-ir 56) = -11
	(word-at static-globals-ir 60) = 1
	(word-at static-globals-ir 68) = 12
	(word-at static-globals-ir 96) = 6
	(word-at static-globals-ir 100) = 1
	(word-at static-globals-ir 104) = 1
	(word-at static-globals-ir 112) = 3
	(copy at static-globals-ir 129) = to binary! "answerready?fn"
]["static global stream changed"]

cast-global-ir: compile-text {
	Red/System []
	value: as integer! 1
	fn: func [][]
} 'user
assert binary? cast-global-ir [
	"frontend rejected a static scalar cast: " mold frontend/last-error
]
assert all [
	(length? cast-global-ir) = 99
	(word-at cast-global-ir 24) = 1
	(word-at cast-global-ir 36) = -5
	(word-at cast-global-ir 40) = 1
]["static scalar cast did not become direct global data"]

typed-global-ir: compile-text {
	Red/System []
	cell!: alias struct! [value [integer!]]
	base: as cell! 0
	fn: func [return: [integer!]][7]
} 'user
assert binary? typed-global-ir [
	"frontend rejected a static typed global: " mold frontend/last-error
]
assert all [
	(length? typed-global-ir) = 142
	(word-at typed-global-ir 8) = 1
	(word-at typed-global-ir 24) = 1
	(word-at typed-global-ir 28) = -2
	(word-at typed-global-ir 44) = 1
	(word-at typed-global-ir 48) = -5
	(word-at typed-global-ir 64) = 1
	(copy at typed-global-ir 137) = to binary! "basefn"
]["typed global stream changed"]

assert none? compile-text {
	Red/System []
	value: get-value
	get-value: func [return: [integer!]][1]
} 'user "frontend accepted an unlowered dynamic global initializer"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong dynamic-global error"
assert none? compile-text {
	Red/System []
	value: 1
	value: 2
	fn: func [][]
} 'user "frontend folded a runtime global reassignment into static data"
assert frontend/last-error/code = frontend/ERROR-UNSUPPORTED
	"frontend reported the wrong global-reassignment error"

import-ir: compile-text {
	Red/System []
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
		native-value: "native-value" [integer!]
	]]
	fn: func [return: [integer!]][1]
} 'user
assert binary? import-ir ["frontend rejected direct imports: " mold frontend/last-error]
assert all [
	(length? import-ir) = 196
	(word-at import-ir 12) = 2
	(word-at import-ir 16) = 1
	(word-at import-ir 20) = 2
	(word-at import-ir 28) = 0
	(word-at import-ir 32) = 11
	(word-at import-ir 36) = 11
	(word-at import-ir 40) = 11
	(word-at import-ir 44) = -5
	(word-at import-ir 48) = 2
	(word-at import-ir 52) = 0
	(word-at import-ir 56) = 1
]["import header or function record changed"]
assert all [
	(word-at import-ir 60) = 0
	(word-at import-ir 64) = 11
	(word-at import-ir 68) = 22
	(word-at import-ir 72) = 12
	(word-at import-ir 76) = -5
	(word-at import-ir 80) = 0
	(word-at import-ir 84) = 1
	(word-at import-ir 88) = 0
	(word-at import-ir 92) = 34
	(word-at import-ir 100) = -5
	(word-at import-ir 108) = 1
	(word-at import-ir 120) = -5
	(copy at import-ir 161) = to binary! "fixture.dllnative-callnative-valuefn"
]["direct import grouping, signatures, or names changed"]
assert same? frontend/imports/2 frontend/imports/12
	"one import group duplicated its library value"

import-call-ir: compile-text {
	Red/System []
	#import ["fixture.dll" stdcall [
		native-call: "native-call" [value [integer!] return: [integer!]]
	]]
	fn: func [return: [integer!]][native-call 7]
} 'glue
assert binary? import-call-ir ["frontend rejected an imported call: "
	mold frontend/last-error]
assert all [
	(length? import-call-ir) = 168
	(word-at import-call-ir 12) = 1
	(word-at import-call-ir 16) = 1
	(word-at import-call-ir 20) = 3
	(word-at import-call-ir 44) = -5
	(word-at import-call-ir 48) = 2
	(word-at import-call-ir 56) = 1
	(word-at import-call-ir 88) = -5
	(word-at import-call-ir 96) = 1
	(word-at import-call-ir 112) = 4
	(word-at import-call-ir 120) = -1
	(word-at import-call-ir 124) = 1
	(copy at import-call-ir 145) = to binary! "fixture.dllnative-callfn"
]["imported call did not use the direct negative import ID"]

import-load-ir: compile-text {
	Red/System []
	#import ["fixture.dll" stdcall [native-value: "native-value" [integer!]]]
	fn: func [return: [integer!]][native-value]
} 'user
assert binary? import-load-ir [
	"frontend rejected an imported variable load: " mold frontend/last-error
]
assert all [
	(length? import-load-ir) = 145
	(word-at import-load-ir 16) = 1
	(word-at import-load-ir 20) = 2
	(word-at import-load-ir 44) = -5
	(word-at import-load-ir 48) = 0
	(word-at import-load-ir 88) = 7
	(word-at import-load-ir 92) = 1
	(word-at import-load-ir 96) = 1
	(word-at import-load-ir 104) = 3
	(word-at import-load-ir 112) = 1
	(copy at import-load-ir 121) = to binary! "fixture.dllnative-valuefn"
]["imported variable load did not use its direct import ID"]

import-store-ir: compile-text {
	Red/System []
	red: context [
		#import ["fixture.dll" stdcall [boot?: "boot?" [logic!]]]
	]
	fn: func [][red/boot?: yes]
} 'user
assert binary? import-store-ir [
	"frontend rejected an imported logic store: " mold frontend/last-error
]
assert all [
	(length? import-store-ir) = 138
	(word-at import-store-ir 16) = 1
	(word-at import-store-ir 20) = 2
	(word-at import-store-ir 44) = -11
	(word-at import-store-ir 48) = 0
	(word-at import-store-ir 88) = 8
	(word-at import-store-ir 92) = 0
	(word-at import-store-ir 96) = 1
	(word-at import-store-ir 100) = 1
	(word-at import-store-ir 104) = 2
	(copy at import-store-ir 121) = to binary! "fixture.dllboot?fn"
]["imported logic store did not use its direct import ID"]

context-import-ir: compile-text {
	Red/System []
	base: context [value!: alias integer!]
	with base [
		#import ["fixture.dll" cdecl [
			native-call: "native-call" [value [value!] return: [value!]]
		]]
		fn: func [return: [integer!]][1]
	]
} 'user
assert all [
	binary? context-import-ir
	frontend/imports/8 = 1
	frontend/imports/9 = [value 1 0]
	frontend/imports/10 = 1
]["WITH import lost its shared type-resolution scope"]

assert none? compile-text {
	Red/System []
	#import ["fixture.lib" cdecl []]
	fn: func [][]
} 'user "frontend silently omitted an empty import group"
assert frontend/last-error/message = "empty import group is unsupported"
	"frontend reported the wrong empty-import boundary"

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
