Red [
	Title: "RSIR-core exclusive frontend integration"
]

#include %../../../system/compiler-windows-common.red
#include %../../../compiler/rsir-frontend.red
#include %../../../system/compiler-rsir-core.red

red-compiler-process-get: func [spec code [block!]][false]
red-compiler-process-in: func [path word code [block!]][false]
red-compiler-process-typecheck: func [spec [word! block!]][none]
red-compiler-process-call: func [body [block!] global? [logic!]][none]

fail: func [message [string! block!]][
	print ["FAIL:" either block? message [rejoin message][message]]
	quit/return 1
]

check: func [condition [logic!] message [string! block!]][
	unless condition [fail message]
]

source: all [
	block? system/options/args
	not empty? system/options/args
	clean-path to-red-file to file! system/options/args/1
]
unless source [
	foreach candidate reduce [
		join system/options/path %../fixtures/backend/rsir-empty-void.reds
		join system/options/path %tools/self_hosting/fixtures/backend/rsir-empty-void.reds
		join system/options/path %../../tools/self_hosting/fixtures/backend/rsir-empty-void.reds
	][
		candidate: clean-path candidate
		if exists? candidate [source: candidate break]
	]
]
unless source [fail ["cannot access RSIR integration fixture from: " system/options/path]]
unless exists? source [fail ["cannot access RSIR integration fixture: " source]]

check not value? 'emitter "RSIR core installed the legacy emitter"
check not value? 'rs-o2-ir "RSIR core installed the legacy machine IR"

job: compiler-system-job/new 'Windows-X86-64
unless object? job [fail "could not create the Windows x64 compilation job"]
compiler-system-job/job-set job 'backend-mode 'rsir
compiler-system-job/job-set job 'link? false
compiler-system-job/job-set job 'runtime? false
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'opt-level 1
compiler-system-job/job-set job 'o2-ir-dump none
compiler-system-job/job-set job 'dev-mode? false

system-dialect/compile/options source job
artifact: system-dialect/last-rsir

check binary? artifact "RSIR core did not return RSIR"
artifact-size: length? artifact
artifact-hash: checksum artifact 'SHA256
check artifact-size = 70 ["RSIR core output size changed: " artifact-size]
check artifact-hash =
	#{AEA00B34B356177FA01B36FD521720EBA710DE57E8DBB9008967419FED7633AA}
	["RSIR core bytes differ from the independent fixture: size=" artifact-size
		" hash=" mold artifact-hash]
check none? system-dialect/last-result "RSIR compile published a legacy linker result"
check not value? 'emitter "RSIR compile installed the legacy emitter"
check not value? 'rs-o2-ir "RSIR compile installed the legacy machine IR"

print "PASS: RSIR-core exclusive frontend"
