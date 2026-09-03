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
	atomic-cell!: alias struct! [
		padding [integer!]
		value [integer!]
	]

	atomic-state: 0

	cpu-register-test: func [
		return: [integer!]
		/local value [int-ptr!]
	][
		system/cpu/x1: as int-ptr! 42
		value: system/cpu/x1
		if value <> (as int-ptr! 42) [return 1]

		system/cpu/x2: as int-ptr! -1
		system/cpu/w2: as int-ptr! 42
		value: system/cpu/x2
		if value <> (as int-ptr! 42) [return 2]

		system/cpu/x9: as int-ptr! (((as int64! 1) << 40) + (as int64! 42))
		value: system/cpu/w9
		if value <> (as int-ptr! 42) [return 3]

		value: system/cpu/x9
		system/cpu/w9: value + 31
		value: system/cpu/x9
		if value <> (as int-ptr! 166) [return 4]

		0
	]

	clobber-x21: func [return: [integer!]][
		system/cpu/x21: as int-ptr! 777
		0
	]

	callee-saved-test: func [
		return: [integer!]
		/local saved observed [int-ptr!] result [integer!]
	][
		saved: system/cpu/x21
		system/cpu/x21: as int-ptr! 123
		result: clobber-x21
		observed: system/cpu/x21
		system/cpu/x21: saved
		if result <> 0 [return 1]
		either observed = (as int-ptr! 123) [0][2]
	]

	sp-register-test: func [
		return: [integer!]
		/local before raw [int-ptr!]
	][
		before: system/stack/top
		raw: system/cpu/sp
		if raw <> before [return 1]
		system/cpu/sp: raw
		either system/cpu/sp = before [0][2]
	]

	sparse-home-test: func [
		return: [integer!]
		/local saved observed [int-ptr!]
			a b c result status [integer!]
	][
		saved: system/cpu/x20
		system/cpu/x20: as int-ptr! 777
		a: 10
		b: 20
		c: 30
		result: (a + b) + c
		observed: system/cpu/x20
		status: 0
		if observed <> (as int-ptr! 777) [status: 1]
		if result <> 60 [status: 2]
		system/cpu/x20: saved
		status
	]

	automatic-allocation: func [return: [integer!] /local memory [wide-ptr!]][
		memory: as wide-ptr! system/stack/allocate 3
		memory/1: as int64! 73
		73
	]

	atomic-test: func [
		return: [integer!]
		/local previous current [integer!] changed? overflowed? [logic!]
			cell [atomic-cell!]
	][
		system/atomic/store :atomic-state 1
		current: system/atomic/load :atomic-state
		if current <> 1 [return 1]

		previous: system/atomic/add/old :atomic-state 2
		if previous <> 1 [return 2]
		if (system/atomic/load :atomic-state) <> 3 [return 3]
		previous: system/atomic/sub/old :atomic-state 1
		if previous <> 3 [return 4]
		if (system/atomic/load :atomic-state) <> 2 [return 5]
		previous: system/atomic/or/old :atomic-state 4
		if previous <> 2 [return 6]
		if (system/atomic/load :atomic-state) <> 6 [return 7]
		previous: system/atomic/xor/old :atomic-state 3
		if previous <> 6 [return 8]
		if (system/atomic/load :atomic-state) <> 5 [return 9]
		previous: system/atomic/and/old :atomic-state 6
		if previous <> 5 [return 10]
		if (system/atomic/load :atomic-state) <> 4 [return 11]

		current: system/atomic/add :atomic-state 2
		if current <> 6 [return 12]
		current: system/atomic/sub :atomic-state 1
		if current <> 5 [return 13]
		current: system/atomic/or :atomic-state 8
		if current <> 13 [return 14]
		current: system/atomic/xor :atomic-state 1
		if current <> 12 [return 15]
		current: system/atomic/and :atomic-state 10
		if current <> 8 [return 16]

		changed?: system/atomic/cas :atomic-state 8 11
		if not changed? [return 17]
		if (system/atomic/load :atomic-state) <> 11 [return 18]
		changed?: system/atomic/cas :atomic-state 8 12
		if changed? [return 19]
		if (system/atomic/load :atomic-state) <> 11 [return 20]

		cell: declare atomic-cell!
		cell/padding: 0
		system/atomic/store :cell/value 73
		if (system/atomic/load :cell/value) <> 73 [return 21]

		system/atomic/store :atomic-state 2147483647
		current: system/atomic/add :atomic-state 1
		system/atomic/fence
		overflowed?: system/cpu/overflow?
		if current <> 80000000h [return 22]
		if not overflowed? [return 23]

		system/atomic/store :atomic-state 0
		previous: system/atomic/sub/old :atomic-state 80000000h
		overflowed?: system/cpu/overflow?
		if previous <> 0 [return 24]
		if (system/atomic/load :atomic-state) <> 80000000h [return 25]
		if not overflowed? [return 26]

		current: system/atomic/or :atomic-state 0
		overflowed?: system/cpu/overflow?
		if overflowed? [return 27]

		system/atomic/store :atomic-state 2147483647
		current: system/atomic/add :atomic-state 1
		changed?: system/atomic/cas :atomic-state 80000000h 0
		overflowed?: system/cpu/overflow?
		if not changed? [return 28]
		if overflowed? [return 29]
		0
	]

	stack-all-test: func [
		return: [integer!]
		/local saved0 saved8 saved28 saved29 saved30 observed [int-ptr!]
			value [integer!]
	][
		saved0: system/cpu/x0
		saved8: system/cpu/x8
		saved28: system/cpu/x28
		saved29: system/cpu/x29
		saved30: system/cpu/x30
		value: 1

		system/stack/push-all
		system/cpu/x0: as int-ptr! 100
		system/cpu/x8: as int-ptr! 108
		system/cpu/x28: as int-ptr! 128
		system/cpu/x30: as int-ptr! 130
		value: 2
		; FP must be the final write before POP-ALL, which restores it using SP.
		system/cpu/x29: as int-ptr! 129
		system/stack/pop-all

		if value <> 2 [return 1]
		observed: system/cpu/x0
		if observed <> saved0 [return 2]
		observed: system/cpu/x8
		if observed <> saved8 [return 3]
		observed: system/cpu/x28
		if observed <> saved28 [return 4]
		observed: system/cpu/x29
		if observed <> saved29 [return 5]
		observed: system/cpu/x30
		if observed <> saved30 [return 6]

		system/cpu/x0: as int-ptr! 11
		system/stack/push-all
		system/cpu/x0: as int-ptr! 22
		system/stack/push-all
		system/cpu/x0: as int-ptr! 33
		system/stack/pop-all
		observed: system/cpu/x0
		if observed <> (as int-ptr! 22) [return 7]
		system/stack/pop-all
		observed: system/cpu/x0
		if observed <> (as int-ptr! 11) [return 8]
		0
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

	overflow-test: func [
		return: [integer!]
		/local x result [integer!] small [int8!] usmall [uint8!]
			unsigned [uint32!] wide [int64!] uwide [uint64!]
			overflowed? [logic!]
	][
		x: 2147483647
		result: x + 1
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 1]

		x: -2000000000
		result: x - 2000000000
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 2]

		x: 1000
		result: x * 2000
		overflowed?: system/cpu/overflow?
		if overflowed? [return 3]

		x: 1000000
		result: x * 2000000
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 4]

		x: 2147483647
		result: x / -1
		overflowed?: system/cpu/overflow?
		if overflowed? [return 5]

		wide: ((as int64! 1) << 62) - 1
		wide: wide + ((as int64! 1) << 62) + 1
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 6]

		wide: as int64! 1000000000
		wide: wide * (as int64! 1000000000)
		overflowed?: system/cpu/overflow?
		if overflowed? [return 7]

		small: as int8! 127
		small: small + (as int8! 1)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 8]

		usmall: as uint8! 255
		usmall: usmall + (as uint8! 1)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 9]

		unsigned: as uint32! 1
		unsigned: unsigned - (as uint32! 2)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 10]

		uwide: (as uint64! 1) << 63
		uwide: uwide + uwide
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 11]

		unsigned: as uint32! 100000
		unsigned: unsigned * (as uint32! 100000)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 12]

		wide: (as int64! 1) << 62
		wide: wide * (as int64! 4)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 13]

		uwide: (as uint64! 1) << 63
		uwide: uwide * (as uint64! 2)
		overflowed?: system/cpu/overflow?
		if not overflowed? [return 14]
		0
	]

	main: func [
		return: [integer!]
		/local result argc [integer!] argv [int-ptr!]
	][
		argc: as integer! system/cpu/x19
		argv: system/cpu/x20
		if any [argc <= 0 argv = null][return 1]
		result: cpu-register-test
		if result <> 0 [return 10 + result]
		result: sparse-home-test
		if result <> 0 [return 20 + result]
		result: callee-saved-test
		if result <> 0 [return 30 + result]
		result: sp-register-test
		if result <> 0 [return 40 + result]
		result: log-test
		if result <> 0 [return 50 + result]
		result: push-test
		if result <> 0 [return 60 + result]
		result: stack-test
		if result <> 0 [return 70 + result]
		result: pc-test
		if result <> 0 [return 80 + result]
		result: overflow-test
		if result <> 0 [return 90 + result]
		result: atomic-test
		if result <> 0 [return 110 + result]
		result: stack-all-test
		if result <> 0 [return 150 + result]
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
