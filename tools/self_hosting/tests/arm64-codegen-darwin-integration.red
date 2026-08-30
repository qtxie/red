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

print "PASS: direct ARM64 RSIR -> Mach-O -> execution"
