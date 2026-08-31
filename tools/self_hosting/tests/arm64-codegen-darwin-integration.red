Red [
	Title: "Direct hybrid ARM64 codegen and Darwin linker integration"
]

#include %../../../system/compiler-hybrid-common.red
#include %../../../compiler/system-diagnostics.red
#include %../../../compiler/codegen-bridge.red
#include %../../../compiler/rsir-frontend.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]

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

system-dialect: context [
	compiler: context [
		quit-on-error: does [quit/return 1]
		throw-error: func [message][fail either block? message [message][form message]]
	]
]

source: {
	Red/System []
	identity: func [value [integer!] return: [integer!]][value]
	functions: protect [:identity]
	hot-loop: func [return: [integer!] /local index sum][
		index: 0
		sum: 0
		while [index < 100][
			sum: sum + (index and 15)
			index: index + 1
		]
		sum
	]
	main: func [return: [integer!]][identity hot-loop]
}

root: clean-path system/options/path
unless exists? join root %system/compiler-rsir-core.red [
	root: clean-path to file! rejoin [system/options/path %../../../]
]
check exists? join root %system/compiler-rsir-core.red "could not locate repository root"
output-dir: clean-path join root %build/arm64-hybrid-baseline/

ir: compiler-rsir-frontend/compile load source 'user
check binary? ir ["ARM64 integration frontend failed: " mold compiler-rsir-frontend/last-error]
change/part ir int-to-bin/to-bin32 3 4
change/part at ir 5 int-to-bin/to-bin32 3 4

image: make binary! 65536
status: codegen-module ir image 2 0
check status = 0 ["ARM64 integration codegen status=" status]
check all [
	(word-at image 60) = 28
	(word-at image 64) = 40
	(word-at image 96) = 68
	(word-at image 100) = 68
	(word-at image 132) = 0
	(word-at image 136) = 28
]["ARM64 function layout changed unexpectedly"]
check (copy/part at image ((word-at image 28) + 1) 28) = #{
	FD7BBFA9 FD030091 0F000094 04000094
	BF030091 FD7BC1A8 C0035FD6
} "ARM64 calls do not target function entries"

job: compiler-system-job/new 'Darwin-ARM64
check object? job "could not create a Darwin ARM64 compilation job"
job: construct/with body-of job linker/job-class
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename %arm64-hybrid-loop-integration
compiler-system-job/job-set job 'build-suffix none

check linker/load-codegen job image [
	"Darwin linker rejected ARM64 image: " linker/codegen-error
]
output: linker/build job
check all [file? output exists? output]["Darwin linker did not write " mold output]
status: call/wait to-local-file output
check status = 214 ["generated ARM64 loop returned " status " instead of 214"]

import-source: {
	Red/System []
	#import [
		"/usr/lib/libSystem.B.dylib" cdecl [
			c-abs: "abs" [value [integer!] return: [integer!]]
		]
	]
	main: func [return: [integer!]][c-abs -42]
}

import-ir: compiler-rsir-frontend/compile load import-source 'user
check binary? import-ir [
	"ARM64 import integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part import-ir int-to-bin/to-bin32 3 4
change/part at import-ir 5 int-to-bin/to-bin32 1 4

import-image: make binary! 65536
status: codegen-module import-ir import-image 2 0
check status = 0 ["ARM64 import integration codegen status=" status]
check all [
	(word-at import-image 16) = 1
	(word-at import-image 20) = 1
]["ARM64 import integration image metadata is inconsistent"]

import-job: compiler-system-job/new 'Darwin-ARM64
check object? import-job "could not create a Darwin ARM64 import compilation job"
import-job: construct/with body-of import-job linker/job-class
compiler-system-job/job-set import-job 'runtime? false
compiler-system-job/job-set import-job 'debug? false
compiler-system-job/job-set import-job 'build-prefix output-dir
compiler-system-job/job-set import-job 'build-basename %arm64-hybrid-import-integration
compiler-system-job/job-set import-job 'build-suffix none

check linker/load-codegen import-job import-image [
	"Darwin linker rejected ARM64 import image: " linker/codegen-error
]
import-output: linker/build import-job
check all [file? import-output exists? import-output][
	"Darwin linker did not write " mold import-output
]
status: call/wait to-local-file import-output
check status = 42 ["generated ARM64 import returned " status " instead of 42"]

narrow-source: {
	Red/System []
	compute: func [
		a [int8!]
		b [uint8!]
		return: [integer!]
		/local signed-result [int8!] unsigned-result [uint8!]
			inverted [uint8!] wide [int64!]
	][
		signed-result: a * as int8! 7
		unsigned-result: b + as uint8! 10
		inverted: not b
		wide: signed-result
		(as integer! wide) - (as integer! unsigned-result) - 22
			+ (as integer! inverted) - 5
	]
	main: func [return: [integer!]][compute as int8! -100 as uint8! 250]
}

narrow-ir: compiler-rsir-frontend/compile load narrow-source 'user
check binary? narrow-ir [
	"ARM64 narrow integer integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part narrow-ir int-to-bin/to-bin32 3 4
change/part at narrow-ir 5 int-to-bin/to-bin32 2 4

narrow-image: make binary! 65536
status: codegen-module narrow-ir narrow-image 2 0
check status = 0 ["ARM64 narrow integer integration codegen status=" status]

narrow-job: compiler-system-job/new 'Darwin-ARM64
check object? narrow-job "could not create a Darwin ARM64 narrow integer job"
narrow-job: construct/with body-of narrow-job linker/job-class
compiler-system-job/job-set narrow-job 'runtime? false
compiler-system-job/job-set narrow-job 'debug? false
compiler-system-job/job-set narrow-job 'build-prefix output-dir
compiler-system-job/job-set narrow-job 'build-basename %arm64-hybrid-narrow-integration
compiler-system-job/job-set narrow-job 'build-suffix none

check linker/load-codegen narrow-job narrow-image [
	"Darwin linker rejected ARM64 narrow integer image: " linker/codegen-error
]
narrow-output: linker/build narrow-job
check all [file? narrow-output exists? narrow-output][
	"Darwin linker did not write " mold narrow-output
]
status: call/wait to-local-file narrow-output
check status = 42 [
	"generated ARM64 narrow integer module returned " status " instead of 42"
]

division-source: {
	Red/System []
	signed: func [a [integer!] b [integer!] return: [integer!]][
		(a / b) + (a % b) + (a // b)
	]
	narrow-signed: func [
		a [int8!]
		b [int8!]
		return: [integer!]
		/local quotient [int8!] remainder [int8!] modulo [int8!]
	][
		quotient: a / b
		remainder: a % b
		modulo: a // b
		(as integer! quotient) + (as integer! remainder) + (as integer! modulo)
	]
	wide: func [a [int64!] b [int64!] return: [int64!]][a / b]
	unsigned: func [a [uint32!] b [uint32!] return: [uint32!]][a % b]
	main: func [
		return: [integer!]
		/local value [integer!] wide-value [int64!] unsigned-value [uint32!]
	][
		value: signed -17 -5
		value: value + signed -17 5
		value: value + signed 17 -5
		value: value + signed 17 5
		value: value + narrow-signed as int8! -100 as int8! 7
		wide-value: wide as int64! 82 as int64! 2
		unsigned-value: unsigned as uint32! 17 as uint32! 5
		value: value + as integer! wide-value
		value + as integer! unsigned-value
	]
}

division-ir: compiler-rsir-frontend/compile load division-source 'user
check binary? division-ir [
	"ARM64 integer division integration frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part division-ir int-to-bin/to-bin32 3 4
change/part at division-ir 5 int-to-bin/to-bin32 5 4

division-image: make binary! 65536
status: codegen-module division-ir division-image 2 0
check status = 0 ["ARM64 integer division integration codegen status=" status]

division-job: compiler-system-job/new 'Darwin-ARM64
check object? division-job "could not create a Darwin ARM64 integer division job"
division-job: construct/with body-of division-job linker/job-class
compiler-system-job/job-set division-job 'runtime? false
compiler-system-job/job-set division-job 'debug? false
compiler-system-job/job-set division-job 'build-prefix output-dir
compiler-system-job/job-set division-job 'build-basename %arm64-hybrid-division-integration
compiler-system-job/job-set division-job 'build-suffix none

check linker/load-codegen division-job division-image [
	"Darwin linker rejected ARM64 integer division image: " linker/codegen-error
]
division-output: linker/build division-job
check all [file? division-output exists? division-output][
	"Darwin linker did not write " mold division-output
]
status: call/wait to-local-file division-output
check status = 42 [
	"generated ARM64 integer division module returned " status " instead of 42"
]

global-source: {
	Red/System []
	pair: declare struct! [left [integer!] right [integer!]]
	text: protect "Red"
	total: 14
	main: func [
		return: [integer!]
		/local value [integer!] p [int-ptr!]
	][
		pair/left: 14
		value: 0
		p: :value
		value: value + pair/left
		p/1: value + 14
		total: total + p/1
		value: total
		value
	]
}

global-ir: compiler-rsir-frontend/compile load global-source 'user
check binary? global-ir [
	"ARM64 global integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part global-ir int-to-bin/to-bin32 3 4
change/part at global-ir 5 int-to-bin/to-bin32 1 4

global-image: make binary! 65536
status: codegen-module global-ir global-image 2 0
check status = 0 ["ARM64 global integration codegen status=" status]
check all [
	(word-at global-image 20) = 4
	(word-at global-image 36) = 36
	(word-at global-image 40) = 5
	(word-at global-image 44) = 12
]["ARM64 global integration image metadata is inconsistent"]

global-job: compiler-system-job/new 'Darwin-ARM64
check object? global-job "could not create a Darwin ARM64 global compilation job"
global-job: construct/with body-of global-job linker/job-class
compiler-system-job/job-set global-job 'runtime? false
compiler-system-job/job-set global-job 'debug? false
compiler-system-job/job-set global-job 'build-prefix output-dir
compiler-system-job/job-set global-job 'build-basename %arm64-hybrid-global-integration
compiler-system-job/job-set global-job 'build-suffix none

check linker/load-codegen global-job global-image [
	"Darwin linker rejected ARM64 global image: " linker/codegen-error
]
global-output: linker/build global-job
check all [file? global-output exists? global-output][
	"Darwin linker did not write " mold global-output
]
status: call/wait to-local-file global-output
check status = 42 ["generated ARM64 global update returned " status " instead of 42"]

pointer-source: {
	Red/System []
	wide-cell!: alias struct! [
		a [integer!]
		b [integer!]
		c [integer!]
		d [integer!]
	]
	hot-loop: func [
		base [wide-cell!]
		iterations [integer!]
		return: [wide-cell!]
		/local index [integer!] cursor [wide-cell!]
	][
		index: 0
		cursor: base
		while [index < iterations][
			cursor: cursor + 1
			index: index + 1
		]
		cursor
	]
	main: func [return: [integer!]][
		hot-loop null 1000000000
		0
	]
}

pointer-ir: compiler-rsir-frontend/compile load pointer-source 'user
check binary? pointer-ir [
	"ARM64 pointer integration frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part pointer-ir int-to-bin/to-bin32 3 4
change/part at pointer-ir 5 int-to-bin/to-bin32 2 4

pointer-image: make binary! 65536
status: codegen-module pointer-ir pointer-image 2 0
check status = 0 ["ARM64 pointer integration codegen status=" status]
check not none? find pointer-image #{D6420091B5060011} [
	"ARM64 pointer integration lost its direct pointer and index increments"
]

pointer-job: compiler-system-job/new 'Darwin-ARM64
check object? pointer-job "could not create a Darwin ARM64 pointer compilation job"
pointer-job: construct/with body-of pointer-job linker/job-class
compiler-system-job/job-set pointer-job 'runtime? false
compiler-system-job/job-set pointer-job 'debug? false
compiler-system-job/job-set pointer-job 'build-prefix output-dir
compiler-system-job/job-set pointer-job 'build-basename %arm64-hybrid-pointer-integration
compiler-system-job/job-set pointer-job 'build-suffix none

check linker/load-codegen pointer-job pointer-image [
	"Darwin linker rejected ARM64 pointer image: " linker/codegen-error
]
pointer-output: linker/build pointer-job
check all [file? pointer-output exists? pointer-output][
	"Darwin linker did not write " mold pointer-output
]
status: call/wait to-local-file pointer-output
check status = 0 ["generated ARM64 pointer module returned " status " instead of 0"]

print "PASS: direct ARM64 RSIR -> Mach-O -> execution"
