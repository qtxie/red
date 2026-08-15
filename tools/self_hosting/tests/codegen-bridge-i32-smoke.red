Red [
	Title: "Hybrid codegen bridge i32 smoke test"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/wire-schema.red
#include %../../../compiler/rsir-frontend.red
#include %../../../compiler/codegen-bridge.red

base-config: #{52534346010000004000000000000000A000000001000000400000002000000001000000010000000100000008000000000000000000000001000000AD974D6A010000000000000060000000400000000100000040000000040000000000000000000000000000000100000001000000000000000100000000000000000000000000100000000100010000000000000000000000000000000000000000000000}

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check-i32: func [
	kind [word!]
	expected-size [integer!]
	expected-hash [binary!]
	/local source ir artifact diagnostics status
][
	source: compose/deep [
		Red/System []
		fn: func [return: [integer!]] [7]
	]
	ir: compiler-rsir-frontend/compile source none kind 'executable
	unless binary? ir [fail ["frontend rejected " kind " i32 module"]]
	artifact: make binary! 1
	diagnostics: make binary! 1
	status: codegen-module ir copy base-config artifact diagnostics
	unless status = 0 [fail [kind " bridge status=" status]]
	unless empty? diagnostics [fail [kind " emitted diagnostics"]]
	unless (length? artifact) = expected-size [
		fail [kind " RSCG size=" length? artifact " expected=" expected-size]
	]
	unless (checksum artifact 'SHA256) = expected-hash [
		fail [kind " RSCG digest changed"]
	]
]

check-i32 'user 892
	#{B448034016FECE89E66930094461487A42BEA7CBEAD8D841DA5F18054E13A1AA}
check-i32 'glue 1068
	#{A96CDA2A167FCDA4D96525741AFC776DEAA13A5F7EB670FE73BFFA14559D6494}

print "PASS: frontend -> RSIR -> native i32 codegen -> RSCG"
