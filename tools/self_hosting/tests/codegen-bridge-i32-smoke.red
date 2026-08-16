Red [
	Title: "Compact hybrid codegen routine smoke test"
]

#include %../../../compiler/int-to-bin.red
#include %../../../compiler/rsir-frontend.red
#include %../../../compiler/codegen-bridge.red

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic! none!] message [string! block!]][
	unless condition [fail message]
]

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ (high * 16777216)
]

generate: func [kind [word!] result [word!] /local source ir artifact status][
	source: either result = 'void [
		[Red/System [] fn: func [][]]
	][
		[Red/System [] fn: func [return: [integer!]][7]]
	]
	ir: compiler-rsir-frontend/compile source none kind 'executable
	unless binary? ir [fail ["frontend rejected " kind " " result]]
	artifact: make binary! 4096
	status: codegen-module ir artifact 0
	unless status = 0 [fail [kind " " result " codegen status=" status]]
	reduce [ir artifact]
]

check-image: func [
	kind result [word!]
	expected-size expected-code-size expected-code-offset expected-exit-ref [integer!]
	/local pair ir artifact entry? metadata-size names-start code-offset
][
	pair: generate kind result
	ir: pair/1
	artifact: pair/2
	entry?: kind = 'glue
	check (length? artifact) = expected-size [kind " " result " image size changed"]
	check all [
		(word-at artifact 0) = expected-size
		(word-at artifact 4) = either entry? [3][1]
		(word-at artifact 8) = either entry? [1][0]
		(word-at artifact 12) = 1
		(word-at artifact 16) = either entry? [1][0]
		(word-at artifact 20) = either entry? [1][0]
		(word-at artifact 28) = expected-code-offset
		(word-at artifact 32) = expected-code-size
		(word-at artifact 36) = 16
	][kind " " result " image header changed"]
	check all [
		(word-at artifact 40) = 0
		(word-at artifact 44) = 2
		(word-at artifact 48) = 0
		(word-at artifact 52) = expected-code-size
		(word-at artifact 56) = 32
		(word-at artifact 60) = 0
		(word-at artifact 64) = 16
		(word-at artifact 68) = 0
		(word-at artifact 72) = 0
	][kind " " result " function record changed"]
	metadata-size: either entry? [104][76]
	names-start: metadata-size
	check (copy/part at artifact (names-start + 1) 2) = #{666E}
		[kind " " result " function name changed"]
	if entry? [
		check all [
			(word-at artifact 76) = 2
			(word-at artifact 80) = 12
			(word-at artifact 84) = 14
			(word-at artifact 88) = 11
			(word-at artifact 92) = 1
			(word-at artifact 96) = 1
			(word-at artifact 100) = expected-exit-ref
			(copy/part at artifact 107 12) = #{6B65726E656C33322E646C6C}
			(copy/part at artifact 119 11) = #{4578697450726F63657373}
		][kind " " result " import record changed"]
	]
	code-offset: word-at artifact 28
	check (word-at artifact (code-offset + 9)) = 0
		[kind " " result " bitmap word offset changed"]
	if result = 'i32 [
		check (word-at artifact (code-offset + 16)) = 7
			[kind " i32 literal changed"]
	]
	if entry? [
		check (word-at artifact (code-offset + expected-exit-ref)) = 0
			[kind " " result " exit relocation placeholder changed"]
	]
	check (copy at artifact (expected-size - 15)) =
		#{00000000000000000000000000000000}
		[kind " " result " bitmap is not zero initialized"]
	artifact
]

check-image 'user 'void 116 17 80 0
check-image 'glue 'void 192 31 144 23
check-image 'user 'i32 120 22 80 0
glue-i32: check-image 'glue 'i32 196 34 144 26

call-source: [
	Red/System []
	helper: func [return: [integer!]][41]
	main: func [return: [integer!]][helper]
]
call-ir: compiler-rsir-frontend/compile call-source none 'glue 'executable
check binary? call-ir ["frontend rejected multi-function call: "
	mold compiler-rsir-frontend/last-error]
call-image: make binary! 4096
check (codegen-module call-ir call-image 0) = 0 "multi-function codegen failed"
check all [
	(length? call-image) = 252
	(word-at call-image 8) = 2
	(word-at call-image 12) = 2
	(word-at call-image 20) = 1
	(word-at call-image 24) = 33
	(word-at call-image 28) = 176
	(word-at call-image 32) = 58
]["multi-function image header changed"]
check all [
	(word-at call-image 40) = 0
	(word-at call-image 44) = 6
	(word-at call-image 48) = 36
	(word-at call-image 52) = 22
	(word-at call-image 76) = 6
	(word-at call-image 80) = 4
	(word-at call-image 84) = 0
	(word-at call-image 88) = 36
]["multi-function code layout changed"]
check all [
	(word-at call-image 112) = 10
	(word-at call-image 120) = 22
	(word-at call-image 136) = 28
	(copy/part at call-image 141 10) = #{68656C7065726D61696E}
	(word-at call-image (176 + 16)) = 16
	(word-at call-image (176 + 36 + 16)) = 41
]["direct call encoding or names changed"]

context-source: [
	Red/System []
	qualified: context [
		helper: func [return: [integer!]][42]
		inside: func [return: [integer!]][helper]
	]
	main: func [return: [integer!]][qualified/inside]
]
context-ir: compiler-rsir-frontend/compile context-source none 'glue 'executable
check binary? context-ir ["frontend rejected context calls: "
	mold compiler-rsir-frontend/last-error]
context-image: make binary! 4096
check (codegen-module context-ir context-image 0) = 0 "context codegen failed"
check all [
	(length? context-image) = 336
	(word-at context-image 8) = 3
	(word-at context-image 12) = 3
	(word-at context-image 24) = 59
	(word-at context-image 28) = 240
	(word-at context-image 32) = 80
	(word-at context-image 48) = 36
	(word-at context-image 84) = 58
	(word-at context-image 120) = 0
	(word-at context-image 172) = 28
	(word-at context-image (240 + 16)) = 38
	(word-at context-image (240 + 36 + 16)) = 42
	(copy/part at context-image (240 + 58 + 16 + 1) 4) = #{D6FFFFFF}
]["context code layout or relative calls changed"]

ir: first generate 'glue 'i32
small: make binary! 64
check (codegen-module ir small 0) = 4 "bounded output was accepted"
check empty? small "bounded-output failure committed bytes"

bad: copy ir
change/part bad int-to-bin/to-bin32 1 4
artifact: make binary! 4096
check (codegen-module bad artifact 0) = 2 "invalid RSIR size was accepted"
check empty? artifact "invalid RSIR committed bytes"

artifact: make binary! 4096
check (codegen-module ir artifact 2) = 3 "unsupported opt level was accepted"
check empty? artifact "unsupported opt level committed bytes"

artifact: make binary! 4096
append artifact 1
before: copy artifact
check (codegen-module ir artifact 0) = 1 "nonempty output was accepted"
check artifact = before "invalid output mutation was not atomic"

print "PASS: compact RSIR -> native x64 codegen -> linker image"
