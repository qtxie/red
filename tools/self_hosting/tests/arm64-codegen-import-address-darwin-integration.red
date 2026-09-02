Red [
	Title: "Direct ARM64 imported function address integration"
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

root: clean-path system/options/path
unless exists? join root %system/compiler-rsir-core.red [
	root: clean-path to file! rejoin [system/options/path %../../../]
]
check exists? join root %system/compiler-rsir-core.red "could not locate repository root"
output-dir: clean-path join root %build/arm64-hybrid-baseline/

source: {
	Red/System []
	#import [
		"/usr/lib/libSystem.B.dylib" cdecl [
			c-abs: "abs" [value [integer!] return: [integer!]]
		]
	]
	unary!: alias function! [value [integer!] return: [integer!]]
	through-pointer: func [return: [integer!] /local hook [unary!]][
		hook: as unary! :c-abs
		hook -42
	]
	main: func [return: [integer!]][
		through-pointer + (c-abs -7) - 7
	]
}

ir: compiler-rsir-frontend/compile load source 'user
check binary? ir [
	"ARM64 import-address frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part ir int-to-bin/to-bin32 3 4
change/part at ir 5 int-to-bin/to-bin32 (word-at ir 16) 4

image: make binary! 65536
status: codegen-module ir image 2 0
check status = 0 ["ARM64 import-address codegen status=" status]
check all [(word-at image 16) = 1 (word-at image 20) = 2][
	"ARM64 imported function references did not share one import record"
]
check not none? find image #{20023FD6} [
	"ARM64 imported function pointer does not branch through X17"
]

job: compiler-system-job/new 'Darwin-ARM64
check object? job "could not create a Darwin ARM64 import-address job"
job: construct/with body-of job linker/job-class
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename %arm64-hybrid-import-address-integration
compiler-system-job/job-set job 'build-suffix none

check linker/load-codegen job image [
	"Darwin linker rejected ARM64 import-address image: " linker/codegen-error
]
output: linker/build job
check all [file? output exists? output][
	"Darwin linker did not write " mold output
]
status: call/wait to-local-file output
check status = 42 [
	"generated ARM64 import-address module returned " status " instead of 42"
]

print "PASS: direct ARM64 imported function address"
