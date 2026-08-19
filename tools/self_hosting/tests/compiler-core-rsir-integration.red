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
red-compiler-expand-call: func [body [block!] global? [logic!]][copy []]

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
only-fixture: all [
	block? system/options/args
	(length? system/options/args) >= 2
	to file! system/options/args/2
]
source-runtime?: all [
	block? system/options/args
	(length? system/options/args) >= 3
	system/options/args/3 = "runtime"
]
unless source [
	foreach candidate reduce [
		join system/options/path %../fixtures/backend/rsir-empty-void.reds
		join system/options/path %../tools/self_hosting/fixtures/backend/rsir-empty-void.reds
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

resources: make block! 8
system-dialect/collect-resources [
	Title: "RSIR resource test"
	Version: 1.2.3
] resources source
icons: select resources 'icon
check all [
	block? icons
	(length? icons) = 1
	binary? icons/1
	(select resources 'version) = [Title "RSIR resource test" Version 1.2.3]
]["RSIR core did not preserve the Windows resource model"]

job: compiler-system-job/new 'Windows-X86-64
unless object? job [fail "could not create the Windows x64 compilation job"]
compiler-system-job/job-set job 'backend-mode 'rsir
compiler-system-job/job-set job 'link? false
compiler-system-job/job-set job 'runtime? to logic! source-runtime?
compiler-system-job/job-set job 'debug? false
compiler-system-job/job-set job 'opt-level 0
compiler-system-job/job-set job 'o2-ir-dump none
compiler-system-job/job-set job 'dev-mode? false

system-dialect/compile/options source job
artifact: system-dialect/last-rsir

check binary? artifact "RSIR core did not return RSIR"
check all [
	(length? artifact) >= 36
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
		join system/options/path %../tools/self_hosting/fixtures/backend/
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
	/runtime
	/local fixture root output output-dir job linked status index
][
	if all [only-fixture source-name <> only-fixture][return none]
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
	compiler-system-job/job-set job 'runtime? to logic! runtime
	compiler-system-job/job-set job 'debug? false
	compiler-system-job/job-set job 'opt-level 0
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
	%rsir-condition-statement-exit.reds %rsir-condition-statement-linked.exe "ANY/ALL statements"
run-linked-fixture
	%rsir-fixed-integer-exit.reds %rsir-fixed-integer-linked.exe "fixed integer"
run-linked-fixture
	%rsir-float-scalar-exit.reds %rsir-float-scalar-linked.exe "scalar float"
run-linked-fixture
	%rsir-address-index-exit.reds %rsir-address-index-linked.exe "address/index"
run-linked-fixture
	%rsir-namespace-exit.reds %rsir-namespace-linked.exe "namespace"
run-linked-fixture
	%rsir-size-exit.reds %rsir-size-linked.exe "SIZE?"
run-linked-fixture
	%rsir-declare-storage-exit.reds %rsir-declare-storage-linked.exe "DECLARE storage"
run-linked-fixture
	%rsir-pointer-declare-exit.reds %rsir-pointer-declare-linked.exe "pointer DECLARE"
run-linked-fixture
	%rsir-aggregate-copy-exit.reds %rsir-aggregate-copy-linked.exe "aggregate copy"
run-linked-fixture
	%rsir-tagged-union-exit.reds %rsir-tagged-union-linked.exe "tagged union"
run-linked-fixture
	%rsir-literal-array-exit.reds %rsir-literal-array-linked.exe "literal array"
run-linked-fixture/runtime
	%rsir-cstring-write-exit.reds %rsir-cstring-write-linked.exe "writable c-string literal"
run-linked-fixture/runtime
	%rsir-logic-cast-exit.reds %rsir-logic-cast-linked.exe "logic casts"
run-linked-fixture
	%rsir-protect-exit.reds %rsir-protect-linked.exe "protected data"
run-linked-fixture
	%rsir-aggregate-abi-exit.reds %rsir-aggregate-abi-linked.exe "aggregate ABI"
run-linked-fixture
	%rsir-win64-stack-slot-exit.reds %rsir-win64-stack-slot-linked.exe "Win64 stack slots"
run-linked-fixture
	%rsir-typed-call-exit.reds %rsir-typed-call-linked.exe "typed call"
run-linked-fixture
	%rsir-use-subroutine-exit.reds %rsir-use-subroutine-linked.exe "USE/subroutine"
run-linked-fixture
	%rsir-infix-exit.reds %rsir-infix-linked.exe "infix functions"
run-linked-fixture
	%rsir-push-pop-exit.reds %rsir-push-pop-linked.exe "PUSH/POP"
run-linked-fixture
	%rsir-stack-system-exit.reds %rsir-stack-system-linked.exe "system/stack"
run-linked-fixture
	%rsir-cpu-system-exit.reds %rsir-cpu-system-linked.exe "system/pc and system/cpu"
run-linked-fixture
	%rsir-overflow-exit.reds %rsir-overflow-linked.exe "overflow?"
run-linked-fixture
	%rsir-exceptions-exit.reds %rsir-exceptions-linked.exe "exceptions"
run-linked-fixture
	%rsir-atomic-exit.reds %rsir-atomic-linked.exe "system/atomic"
run-linked-fixture
	%rsir-custom-call-exit.reds %rsir-custom-call-linked.exe "custom call"
run-linked-fixture/runtime
	%rsir-runtime-exit.reds %rsir-runtime-linked.exe "Red/System runtime"

print "PASS: direct RSIR core frontend -> native code -> PE"
