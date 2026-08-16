Red [
	Title: "RSIR-core exclusive frontend integration"
]

#include %../../../system/compiler-windows-common.red
#include %../../../compiler/rsir-frontend.red
#include %../../../compiler/codegen-bridge.red
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

word-at: func [data [binary!] offset [integer!] /local high][
	high: to integer! pick data (offset + 4)
	(to integer! pick data (offset + 1))
		+ ((to integer! pick data (offset + 2)) * 256)
		+ ((to integer! pick data (offset + 3)) * 65536)
		+ ((either high > 127 [high - 256][high]) * 16777216)
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
check all [
	(length? artifact) >= 32
	(word-at artifact 0) = 3
	(word-at artifact 4) > 0
	(word-at artifact 4) <= word-at artifact 16
	(word-at artifact 16) >= 2
	(word-at artifact 20) >= 2
]["RSIR core returned an invalid executable-module shape"]
check none? system-dialect/last-result "RSIR compile published a legacy linker result"
check not value? 'emitter "RSIR compile installed the legacy emitter"
check not value? 'rs-o2-ir "RSIR compile installed the legacy machine IR"

find-fixture: func [
	name [file!]
	return: [file! none!]
	/local directory candidate
][
	foreach directory reduce [
		join system/options/path %../fixtures/backend/
		join system/options/path %tools/self_hosting/fixtures/backend/
		join system/options/path %../../tools/self_hosting/fixtures/backend/
		join system/options/path %../../../tools/self_hosting/fixtures/backend/
	][
		candidate: clean-path join directory name
		if exists? candidate [return candidate]
	]
	none
]

run-linked-fixture: func [
	source-name output-name [file!]
	label [string!]
	/local fixture root output output-dir job linked status index
][
	fixture: find-fixture source-name
	check all [file? fixture exists? fixture]["cannot access " label " fixture"]
	root: first split-path fixture
	repeat index 4 [root: clean-path join root %../]
	output: clean-path to file! rejoin [root %build/self-hosting/ output-name]
	set [output-dir output-name] split-path output

	job: compiler-system-job/new 'Windows-X86-64
	check object? job ["could not create the " label " linker job"]
	compiler-system-job/job-set job 'backend-mode 'rsir
	compiler-system-job/job-set job 'link? true
	compiler-system-job/job-set job 'runtime? false
	compiler-system-job/job-set job 'debug? false
	compiler-system-job/job-set job 'opt-level 1
	compiler-system-job/job-set job 'o2-ir-dump none
	compiler-system-job/job-set job 'dev-mode? false
	compiler-system-job/job-set job 'build-prefix output-dir
	compiler-system-job/job-set job 'build-basename output-name
	compiler-system-job/job-set job 'build-suffix none

	system-dialect/compile/options fixture job
	linked: system-dialect/last-result/4
	check all [file? linked linked = output exists? linked][
		label " fixture did not produce the requested PE"
	]
	status: call/wait to-local-file linked
	check status = 73 ["linked " label " executable returned " status]
]

run-linked-fixture
	%rsir-selection-exit.reds %rsir-selection-linked.exe "CASE/SWITCH"
run-linked-fixture
	%rsir-fixed-integer-exit.reds %rsir-fixed-integer-linked.exe "fixed integer"
run-linked-fixture
	%rsir-float-scalar-exit.reds %rsir-float-scalar-linked.exe "scalar float"
run-linked-fixture
	%rsir-address-index-exit.reds %rsir-address-index-linked.exe "address/index"
run-linked-fixture
	%rsir-declare-storage-exit.reds %rsir-declare-storage-linked.exe "DECLARE storage"
run-linked-fixture
	%rsir-aggregate-copy-exit.reds %rsir-aggregate-copy-linked.exe "aggregate copy"
run-linked-fixture
	%rsir-tagged-union-exit.reds %rsir-tagged-union-linked.exe "tagged union"

print "PASS: direct RSIR core frontend -> native code -> PE"
