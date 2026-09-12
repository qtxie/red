Red [
	Title: "Direct ARM64 exception codegen integration"
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

	raise: func [id [integer!]][throw id]
	middle: func [id [integer!]][raise id]

	local-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 3 [throw 2]
		system/thrown = 2
	]

	deep-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 9 [middle 7]
		system/thrown = 7
	]

	nested-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 5 [
			catch 2 [throw 1]
			if system/thrown <> 1 [return false]
			system/thrown: 0
			throw 4
		]
		system/thrown = 4
	]

	mismatch: func [][catch 2 [throw 7]]

	mismatch-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 9 [mismatch]
		system/thrown = 7
	]

	catch-child: func [][throw 11]

	catch-all-value: func [[catch] return: [integer!]][
		system/thrown: 0
		catch-child
		system/thrown
	]

	rethrow: func [[catch]][throw 13]

	rethrow-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 13 [rethrow]
		system/thrown = 13
	]

	leave-by-break: func [][
		loop 1 [catch 2 [catch 1 [break]]]
		throw 1
	]

	break-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 1 [leave-by-break]
		system/thrown = 1
	]

	leave-by-continue: func [][
		loop 1 [catch 1 [continue]]
		throw 1
	]

	continue-catch?: func [return: [logic!]][
		system/thrown: 0
		catch 1 [leave-by-continue]
		system/thrown = 1
	]

	clobber-homes: func [id [integer!] value [float!]][
		value: value + 1.0
		throw id
	]

	homes-catch?: func [
		return: [logic!]
		/local integer-value [integer!] float-value [float!]
	][
		integer-value: 41
		float-value: 2.5
		catch 9 [clobber-homes 7 12.25]
		all [integer-value = 41 float-value = 2.5 system/thrown = 7]
	]

	main: func [return: [integer!]][
		if not local-catch? [return 1]
		if not deep-catch? [return 2]
		if not nested-catch? [return 3]
		if not mismatch-catch? [return 4]
		if catch-all-value <> 11 [return 5]
		if not rethrow-catch? [return 6]
		if not break-catch? [return 7]
		if not continue-catch? [return 8]
		if not homes-catch? [return 9]
		73
	]
}

ir: compiler-rsir-frontend/compile load source 'user
check binary? ir [
	"ARM64 exception frontend failed: " mold compiler-rsir-frontend/last-error
]
change/part ir int-to-bin/to-bin32 3 4
change/part at ir 5 int-to-bin/to-bin32 (word-at ir 16) 4

image: make binary! 262144
status: codegen-module ir image 2 0
check status = 0 ["ARM64 exception codegen status=" status]

job: compiler-system-job/new 'Darwin-ARM64
check object? job "could not create a Darwin ARM64 exception job"
job: construct/with body-of job linker/job-class
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'build-prefix output-dir
compiler-system-job/job-set job 'build-basename %arm64-hybrid-exceptions-integration
compiler-system-job/job-set job 'build-suffix none

check linker/load-codegen job image [
	"Darwin linker rejected ARM64 exception image: " linker/codegen-error
]
output: linker/build job
check all [file? output exists? output][
	"Darwin linker did not write " mold output
]
status: call/wait to-local-file output
check status = 73 [
	"generated ARM64 exception module returned " status " instead of 73"
]

print "PASS: direct ARM64 exception codegen"
