Red [
	Title: "Direct ARM64 portable native intrinsic integration"
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

	wide-ptr!: alias pointer! [int64!]

	automatic-allocation: func [return: [integer!] /local memory [wide-ptr!]][
		memory: as wide-ptr! system/stack/allocate 3
		memory/1: as int64! 73
		73
	]

	log-test: func [return: [integer!]][
		if (log-b as byte! 128) <> 7 [return 1]
		if (log-b as int8! 64) <> 6 [return 2]
		if (log-b as uint16! 32768) <> 15 [return 3]
		if (log-b 40000000h) <> 30 [return 4]
		if (log-b as uint32! 80000000h) <> 31 [return 5]
		if (log-b ((as int64! 1) << 40)) <> 40 [return 6]
		if (log-b ((as uint64! 1) << 63)) <> 63 [return 7]
		0
	]

	push-test: func [
		return: [integer!]
		/local before after [int-ptr!] value bits [integer!]
	][
		before: system/stack/top
		push 42
		value: pop
		if value <> 42 [return 1]
		push as float32! 1.0
		bits: pop
		if bits <> 3F800000h [return 2]
		after: system/stack/top
		if after <> before [return 3]
		0
	]

	stack-test: func [
		return: [integer!]
		/local before after saved aligned frame [int-ptr!]
			memory [wide-ptr!] value [integer!]
	][
		before: system/stack/top
		frame: system/stack/frame
		if any [before = null frame = null before = frame][return 1]
		system/stack/frame: frame
		if system/stack/frame <> frame [return 2]

		memory: as wide-ptr! system/stack/allocate/zero 3
		if any [
			memory/1 <> (as int64! 0)
			memory/2 <> (as int64! 0)
			memory/3 <> (as int64! 0)
		][return 3]
		memory/1: as int64! 41
		value: as integer! memory/1
		if value <> 41 [return 4]
		system/stack/free 3
		if system/stack/top <> before [return 5]

		if automatic-allocation <> 73 [return 6]
		after: system/stack/top
		if after <> before [return 7]

		push 73
		saved: system/stack/align
		aligned: system/stack/top
		if aligned <> (saved - 2) [return 8]
		system/stack/top: saved
		value: pop
		if any [value <> 73 system/stack/top <> before][return 9]
		0
	]

	pc-test: func [return: [integer!] /local first second [byte-ptr!]][
		first: system/pc
		second: system/pc
		either all [first <> null second <> null first <> second][0][1]
	]

	main: func [return: [integer!] /local result [integer!]][
		result: log-test
		if result <> 0 [return 10 + result]
		result: push-test
		if result <> 0 [return 20 + result]
		result: stack-test
		if result <> 0 [return 30 + result]
		result: pc-test
		if result <> 0 [return 40 + result]
		42
	]
}

ir: compiler-rsir-frontend/compile load source 'user
check binary? ir [
	"ARM64 native intrinsic frontend failed: "
	mold compiler-rsir-frontend/last-error
]
change/part ir int-to-bin/to-bin32 3 4
change/part at ir 5 int-to-bin/to-bin32 (word-at ir 16) 4

image: make binary! 262144
status: codegen-module ir image 2 0
check status = 0 ["ARM64 native intrinsic codegen status=" status]

job: compiler-system-job/new 'Darwin-ARM64
check object? job "could not create a Darwin ARM64 native intrinsic job"
job: construct/with body-of job linker/job-class
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename %arm64-hybrid-native-integration
compiler-system-job/job-set job 'build-suffix none

check linker/load-codegen job image [
	"Darwin linker rejected ARM64 native intrinsic image: " linker/codegen-error
]
output: linker/build job
check all [file? output exists? output][
	"Darwin linker did not write " mold output
]
status: call/wait to-local-file output
check status = 42 [
	"generated ARM64 native intrinsic module returned " status " instead of 42"
]

print "PASS: direct ARM64 portable native intrinsics"
